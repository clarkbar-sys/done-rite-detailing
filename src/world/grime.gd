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
## [b]All three layers, and one of them knows what the panel is made of.[/b]
## [method wash] and [method buff] work anywhere; [method foam] is the middle step
## and the only one that cares, because a sponge is for paint and a bottle of
## glass cleaner is not. Which cleaner goes with which panel is [Surface], and
## which panel is which kind is [method Car.kind_of] — neither is decided here,
## and neither is the rule about which tool the player is holding, because
## [Garage] holds the trigger and this takes the instruction. What this class
## knows is a texture and the panel it is stretched over.
##
## [b]And it lights the patch it just rang for.[/b] Alongside every map is a
## [PatchFlash] — a small decaying picture of which patches have finished
## something and which pass finished it, sampled by the same overlay through the
## same atlas coordinates. It is fed from exactly where [signal patch_finished] is
## emitted, so the square that lights and the bell that rings can never be about
## different patches, and it is dimmed in [method Node._process] because a fading
## light is the one thing in this class that is about time rather than about the
## last press.
class_name Grime
extends Node3D

## A patch of a panel has just finished a step of the job. Carries the panel it
## was on, which patch, and which step — so a listener can ring, score it, or
## ignore all three and just count.
##
## Per patch and not per panel: a bonnet is a lot of washing to do for one piece
## of feedback, and the size of a patch is [member patches_per_tile] rather than
## a decision taken here — how often this fires is a matter of taste.
##
## One signal carrying a stage rather than three signals, because everything
## listening so far wants the same thing from all three — a small noise saying
## "that worked" — and a listener that wants to tell them apart has the argument
## to do it with.
signal patch_finished(panel: String, patch: int, stage: GrimeMap.Stage)

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
var _flashes: Array[PatchFlash] = []
var _panels: Array[CSGShape3D] = []


## Dims every panel's finished-patch flashes.
##
## [b]The one thing here that runs on a clock.[/b] Everything else in this class
## happens because a tool was held; a flash happens because one was held a moment
## ago, and something has to take it away again. It is a loop over twelve panels
## doing a single integer comparison each while nothing is lit — [method
## PatchFlash.fade] returns early and uploads nothing — so an untouched car costs
## a dozen branches a frame rather than a dozen texture uploads.
func _process(delta: float) -> void:
	for flash: PatchFlash in _flashes:
		flash.fade(delta)


## Puts mud on every panel of [param car].
##
## Must be called after the car has had a frame to build its CSG — see the class
## docs. Calling it twice replaces what was there, which is what a "reset the
## car" would want and is otherwise nobody's business.
func lay_on(car: Car) -> void:
	_panels = car.panels()
	_maps = []
	_flashes = []
	var shader: Shader = load(SHADER) as Shader
	for panel: CSGShape3D in _panels:
		var map: GrimeMap = GrimeMap.new(panel.get_aabb(), tile_pixels, patches_per_tile)
		# Sized from the map rather than from `patches_per_tile` and
		# `BoxProjection.COLUMNS`, which is the same arithmetic in a second place —
		# see [method GrimeMap.patch_grid].
		var flash: PatchFlash = PatchFlash.new(map.patch_grid())
		_maps.append(map)
		_flashes.append(flash)
		panel.material_overlay = _overlay(shader, map, flash, panel.get_aabb(), car.kind_of(panel))


## Whether [method lay_on] has run. False on a room that never took up grime —
## the title screen's showcase circuit has nobody to wash the car.
func is_laid() -> bool:
	return not _maps.is_empty()


## Every panel that has mud on it, in the order [method map_of] indexes them.
func panels() -> Array[CSGShape3D]:
	return _panels


## The map for one panel, or [code]null[/code] if that node is not a panel of the
## car this grime was laid on.
## Cast on the way in rather than taken as given. [member _panels] is an
## [code]Array[CSGShape3D][/code], and searching a typed array for something that
## is not of its type is an engine error rather than a miss — so a stray hit on
## the driveway, which is a normal thing for a player to produce, would print
## rather than answer.
func map_of(panel: Node) -> GrimeMap:
	var index: int = _panels.find(panel as CSGShape3D)
	if index < 0:
		return null
	return _maps[index]


## The finished-patch flashes for one panel, or [code]null[/code] for a node that
## is not a panel of this car.
##
## Public alongside [method map_of] rather than kept private, because "did that
## patch light up" is a question a test should be able to ask of the thing the
## shader actually samples. Asserting on the mask instead would only prove the
## patch finished, which is the half that was already covered.
##
## Cast on the way in for the reason [method map_of] is.
func flash_of(panel: Node) -> PatchFlash:
	var index: int = _panels.find(panel as CSGShape3D)
	if index < 0:
		return null
	return _flashes[index]


## Every panel a brush of [param radius_metres] held at [param world_point] can
## reach, in the order [method map_of] indexes them.
##
## [b]A press works more than one panel, and this is what says which.[/b] A car's
## panels sit against each other and a tool is a ball of a radius in metres — so a
## jet held on the seam between a door and a wing is on both of them, and one held
## in a wheel arch is on the arch and the wheel. Answering with the single panel a
## ray happened to hit is what left those seams permanently half done: the mud a
## centimetre the other side of the gap belonged to a map the press never opened,
## and no amount of aiming at it helped, because the aim was never the part that
## was wrong. [method GrimeMap._brush] is the same fix one level down, across the
## faces of one panel.
##
## [b]Sphere against grown box, which is the cheap over-answer.[/b]
## [method AABB.grow] pushes every face out by the radius and the test is then a
## point in a box, so a ball near a corner of a panel counts as reaching it when
## it is really up to a corner's worth further away. That is deliberate: the
## panels this over-collects are the ones whose maps then paint nothing, because
## [method GrimeMap._brush] measures the real distance to every texel it
## considers. Being generous here costs an empty loop over one map; being tight
## would risk dropping a panel that had work on it, and the cost of that is a seam
## nobody can finish.
##
## [b]In world space, unlike everything else this class takes.[/b] The three tools
## below convert into a panel's own space because a brush has one panel to be in;
## this is the question asked [i]before[/i] there is a panel to convert into, so
## the boxes come out to meet the point rather than the other way round.
func panels_within(world_point: Vector3, radius_metres: float) -> Array[CSGShape3D]:
	var reached: Array[CSGShape3D] = []
	for panel: CSGShape3D in _panels:
		var box: AABB = panel.global_transform * panel.get_aabb()
		if box.grow(radius_metres).has_point(world_point):
			reached.append(panel)
	return reached


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


## How much of the car is under product right now, as [code]0..1[/code]. Goes up
## under the cleaners and back down under the rag — see [method GrimeMap.product].
func product() -> float:
	if _maps.is_empty():
		return 0.0
	var on: float = 0.0
	for map: GrimeMap in _maps:
		on += map.product()
	return on / float(_maps.size())


## How much of the car is buffed to a shine, as [code]0..1[/code].
##
## The progress number, and the one a bar should be reading: it only ever rises,
## and unlike [method remaining] it does not call a car finished when the mud
## comes off. Unweighted for the same reason [method remaining] is.
func shine() -> float:
	if _maps.is_empty():
		return 0.0
	var buffed: float = 0.0
	for map: GrimeMap in _maps:
		buffed += map.shine()
	return buffed / float(_maps.size())


## How much work the whole car has had done on it in [param stage], ever,
## measured in patches' worth — see [method GrimeMap.worked].
##
## [b]Summed and not averaged[/b], which is the one place this differs from the
## three readings above it. Those answer "how far through is the car", so a
## panel-average is the honest shape and a car with one spotless wing is not
## finished. This answers "how much has been done", and half a patch of washing
## is half a patch of washing whichever panel it happened on — dividing by twelve
## would make the same stroke worth less on a car with more pieces.
##
## Monotonic, so a caller reads it twice and pays for the difference. That is the
## whole intended use: cleaning is a thing that is true across frames rather than
## an event, so it is polled once a frame the way the walk is, and not signalled
## the way a finished patch is. [code]src/screens/play_screen.gd[/code] has the
## longer version of that distinction.
func worked(stage: GrimeMap.Stage) -> float:
	var done: float = 0.0
	for map: GrimeMap in _maps:
		done += map.worked(stage)
	return done


## Takes [param amount] of mud off [param panel] at [param world_point], over a
## brush of [param radius_metres], for a surface facing [param world_normal].
##
## Takes the hit in world space because that is what a raycast hands back, and
## converts here rather than making every caller do it: the panel's own transform
## is the only thing that knows how, and a caller that got it wrong would wash a
## spot the mark is not on.
##
## Returns how many patches it finished, and emits [signal patch_finished] once
## for each. Zero for a panel that is not part of this car, so a stray hit on the
## driveway is not an error.
func wash(
	panel: Node, world_point: Vector3, world_normal: Vector3, radius_metres: float, amount: float
) -> int:
	return _work(panel, world_point, world_normal, radius_metres, amount, GrimeMap.Stage.WASHED)


## Lays [param amount] of product onto the bare paint of [param panel], the same
## way [method wash] takes mud off it.
##
## [b]It does not check what the panel is made of or what the player is holding.[/b]
## That rule lives with the trigger — see [method Garage._spend_the_trigger] —
## because "the window cleaner is for glass" is a decision about the game and this
## class is about a texture. What stops a bottle working on a muddy panel is not a
## rule at all: there is no bare paint to cover, so nothing moves.
func foam(
	panel: Node, world_point: Vector3, world_normal: Vector3, radius_metres: float, amount: float
) -> int:
	return _work(panel, world_point, world_normal, radius_metres, amount, GrimeMap.Stage.FOAMED)


## Wipes [param amount] of product off [param panel], turning it into shine.
##
## Works on any panel, and does nothing at all on one that has no product on it —
## which is the whole of "you have to soap it before you buff it", and is again
## arithmetic rather than a refusal.
func buff(
	panel: Node, world_point: Vector3, world_normal: Vector3, radius_metres: float, amount: float
) -> int:
	return _work(panel, world_point, world_normal, radius_metres, amount, GrimeMap.Stage.BUFFED)


## One tool, one press: finds the panel's map, puts the hit into the panel's own
## space, and runs [param stage] over it.
##
## The three public methods above differ in nothing but which stage they name, so
## the world-to-panel conversion — the part that is easy to get subtly wrong —
## exists exactly once.
func _work(
	panel: Node,
	world_point: Vector3,
	world_normal: Vector3,
	radius_metres: float,
	amount: float,
	stage: GrimeMap.Stage
) -> int:
	var shape: CSGShape3D = panel as CSGShape3D
	var index: int = _panels.find(shape)
	if index < 0:
		return 0
	var map: GrimeMap = _maps[index]
	var into: Transform3D = shape.global_transform.affine_inverse()
	# The normal is turned by the basis alone — it is a direction, and putting it
	# through the full transform would add the panel's position to it and send
	# every touch to whichever face the car happens to be parked toward.
	var facing: Vector3 = (into.basis * world_normal).normalized()
	var at: Vector3 = into * world_point
	var finished: PackedInt32Array
	match stage:
		GrimeMap.Stage.WASHED:
			finished = map.wash(at, facing, radius_metres, amount)
		GrimeMap.Stage.FOAMED:
			finished = map.foam(at, facing, radius_metres, amount)
		_:
			finished = map.buff(at, facing, radius_metres, amount)
	# Lit here rather than on the signal, so the square and the ding are two things
	# done with the same list instead of two listeners that could come apart. A
	# flash is not a reaction to the event; it is the event, drawn.
	var flash: PatchFlash = _flashes[index]
	for patch: int in finished:
		flash.flare(patch, stage)
		patch_finished.emit(String(shape.name), patch, stage)
	return finished.size()


## The overlay material for one panel: the shader, its mask, its flashes, the box
## the projection measures in, and what the cleaner for this kind of panel looks
## like.
##
## The two textures are handed over once and never again — both are updated in
## place by whoever owns them, so a material that has been given them stays
## current without anything here watching.
##
## The product colour is set once, here, and never again — which is how one
## channel of the mask carries white suds on the paint, blue on the glass and
## green on the tyres without the mask having anywhere to record which. A panel
## does not change what it is made of. [method Surface.product_colour] has the
## argument at length.
func _overlay(
	shader: Shader, map: GrimeMap, flash: PatchFlash, box: AABB, kind: Surface.Kind
) -> ShaderMaterial:
	var paint: ShaderMaterial = ShaderMaterial.new()
	paint.shader = shader
	paint.set_shader_parameter("grime_mask", map.texture())
	paint.set_shader_parameter("patch_flash", flash.texture())
	paint.set_shader_parameter("box_origin", box.position)
	paint.set_shader_parameter("box_size", box.size)
	paint.set_shader_parameter("product_colour", Surface.product_colour(kind))
	return paint
