## The dirt on the car: a [GrimeMap] per panel, the overlay that draws them, and
## the one function a tool calls to take some off.
##
## Built by [Garage] beside the car, for the same reason the [AimMarker] is built
## there: it is a thing about the car rather than a part of it, and hanging it
## inside would put it in the way of everything that walks the car's children
## looking for panels ([method Car.panels]).
##
## [b]It is laid on a frame late, on purpose.[/b] Every map is sized from its
## panel's [method CSGShape3D.get_aabb], and CSG meshes are built deferred — a
## panel asked during [method Node._ready] reports a zero box, and a zero box is
## a projection that divides by nothing. [Car] documents that at length and its
## own [method Car.bounds] carries the same warning. So [method lay_on] is called
## after a frame has passed and [method is_laid] is how a caller finds out
## whether it has happened yet.
##
## [b]An overlay and not an override.[/b] [member GeometryInstance3D.material_overlay]
## draws this over the panel's real material instead of replacing it, so the
## green paint, the near-black tyres and the silver rims are all still there
## underneath and washing is alpha going to zero rather than a colour being
## put back. An override would have flattened every wheel to one colour — a tyre
## and a rim are one CSG tree with two materials in it — and it would have needed
## this class to know what every panel is painted, which is a copy of the car's
## own scene file waiting to go stale.
##
## [b]Only the power wash, and only the red channel.[/b] This is the first tool
## of five and the first of three layers; see [GrimeMap] for what green and blue
## are held back for. What a tool does is not decided here — [Garage] holds the
## trigger and this takes the instruction — because "the sponge works on film,
## and only where the mud is already off" is a rule about the game, and this
## class is about a texture.
class_name Grime
extends Node3D

## A patch of a panel has just been washed clean. Carries the panel it was on and
## which patch, so a listener can ring, score it, or ignore the panel name
## entirely and just count.
##
## Per patch and not per panel: a bonnet is a lot of washing to do for one piece
## of feedback, and the size of a patch is [member patches_per_tile] rather than
## a decision taken here — how often this fires is a matter of taste.
signal patch_cleared(panel: String, patch: int)

## Where the overlay comes from.
const SHADER: String = "res://src/world/grime.gdshader"

## The resolution of one face of a panel's atlas, so its mask is three of these
## across and two down.
##
## 64 is about 3 cm a texel on the side of the car, which is finer than the jet
## of water that writes into it and coarse enough that the whole car is a
## megabyte or so. It is a blockout's number: the thing that will want raising is
## a real mesh with panel gaps and badge recesses to keep the water out of.
@export var tile_pixels: int = 64

## How finely each face is diced for the ding. Four is sixteen patches a face and
## ninety-six a panel — a car's worth of small, frequent rewards rather than
## twelve big ones.
##
## The knob for how the whole thing feels: at 1 it rings once a face, at 8 it
## rings constantly. Nothing about correctness changes with it.
@export var patches_per_tile: int = 4

var _maps: Array[GrimeMap] = []
var _panels: Array[CSGShape3D] = []


## Puts mud on every panel of [param car].
##
## Must be called after the car has had a frame to build its CSG — see the class
## docs. Calling it twice replaces what was there, which is what a "reset the
## car" would want and is otherwise nobody's business.
func lay_on(car: Car) -> void:
	_panels = car.panels()
	_maps = []
	var shader: Shader = load(SHADER) as Shader
	for panel: CSGShape3D in _panels:
		var map: GrimeMap = GrimeMap.new(panel.get_aabb(), tile_pixels, patches_per_tile)
		_maps.append(map)
		panel.material_overlay = _overlay(shader, map, panel.get_aabb())


## Whether [method lay_on] has run. False on a room that never took up grime —
## the title screen's showcase circuit has nobody to wash the car.
func is_laid() -> bool:
	return not _maps.is_empty()


## Every panel that has mud on it, in the order [method map_of] indexes them.
func panels() -> Array[CSGShape3D]:
	return _panels


## The map for one panel, or [code]null[/code] if that node is not a panel of the
## car this grime was laid on.
func map_of(panel: Node) -> GrimeMap:
	var index: int = _panels.find(panel)
	if index < 0:
		return null
	return _maps[index]


## How much of the car's mud is still on it, as [code]0..1[/code], across every
## panel equally rather than weighted by area.
##
## Unweighted deliberately: a mask is the same number of texels whatever size the
## panel is, so "half the car" here means half the texels, and a wing mirror
## counts as much as a door. That is the wrong answer for a score and the right
## one for a progress bar over a fixed amount of work, which is what this is
## while there is nothing spending it.
func remaining() -> float:
	if _maps.is_empty():
		return 0.0
	var left: float = 0.0
	for map: GrimeMap in _maps:
		left += map.remaining()
	return left / float(_maps.size())


## Takes [param amount] of mud off [param panel] at [param world_point], over a
## brush of [param radius_metres], for a surface facing [param world_normal].
##
## Takes the hit in world space because that is what a raycast hands back, and
## converts here rather than making every caller do it: the panel's own transform
## is the only thing that knows how, and a caller that got it wrong would wash a
## spot the crosshair is not on.
##
## Returns how many patches it finished, and emits [signal patch_cleared] once
## for each. Zero for a panel that is not part of this car, so a stray hit on the
## driveway is not an error.
func wash(
	panel: Node, world_point: Vector3, world_normal: Vector3, radius_metres: float, amount: float
) -> int:
	var shape: CSGShape3D = panel as CSGShape3D
	var map: GrimeMap = map_of(shape)
	if map == null:
		return 0
	var into: Transform3D = shape.global_transform.affine_inverse()
	# The normal is turned by the basis alone — it is a direction, and putting it
	# through the full transform would add the panel's position to it and send
	# every wash to whichever face the car happens to be parked toward.
	var facing: Vector3 = (into.basis * world_normal).normalized()
	var finished: PackedInt32Array = map.wash(into * world_point, facing, radius_metres, amount)
	for patch: int in finished:
		patch_cleared.emit(String(shape.name), patch)
	return finished.size()


## The overlay material for one panel: the shader, its mask, and the box the
## projection measures in.
func _overlay(shader: Shader, map: GrimeMap, box: AABB) -> ShaderMaterial:
	var paint: ShaderMaterial = ShaderMaterial.new()
	paint.shader = shader
	paint.set_shader_parameter("mud_mask", map.texture())
	paint.set_shader_parameter("box_origin", box.position)
	paint.set_shader_parameter("box_size", box.size)
	return paint
