## The dirt on the car: a [GrimeMap] per panel, the overlay that draws them, and
## the one function a tool calls to take some off.
##
## Built by [Garage] beside the car, for the same reason the [AimMarker] is built
## there: it is a thing about the car rather than a part of it, and hanging it
## inside would put it in the way of everything that walks the car's children
## looking for panels ([method Car.panels]).
##
## [b]It is laid on a frame late, on purpose — while the car is CSG.[/b] Every
## map is sized from its panel's box, and CSG meshes are built deferred: a panel
## asked during [method Node._ready] reports a zero box, and a zero box is a
## projection that divides by nothing. [Car] documents that at length and its own
## [method Car.bounds] carries the same warning, along with the note that it is
## the blockout's tax and not the panel contract's — a panel skinned with a
## [MeshInstance3D] is exact immediately. So [method lay_on] is called after a
## frame has passed and [method is_laid] is how a caller finds out whether it has
## happened yet.
##
## [b]It reads a panel through [method Car.skin_of].[/b] What it needs off a panel
## is a box and an overlay slot, and neither is on the panel's root once the root
## is a [StaticBody3D] rather than a [CSGShape3D] — [Car]'s class docs have the
## whole shape. Nothing else here changes: a panel is still whatever the raycast
## handed back, which is what [method map_of] is keyed on.
##
## [b]Each map is sized off its own panel, not off one flat number.[/b]
## [method lay_on] asks [PanelResolution] for a tile resolution per panel rather
## than handing every one of them the same [code]tile_pixels[/code] — a fixed
## number tuned for a CSG blockout's dozen similar-sized doors and wings put a
## [MeshCar]'s [code]Body[/code], which is most of the car, at the same texel
## density as its wheels, roughly doubling the effective texel size on the panel
## a player looks at most. [PanelResolution]'s class docs have the density target
## and the clamps; what matters here is that the wheels do not get any coarser
## for it — the floor is the old flat number, so the only panel this can move is
## the one big enough to want it.
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

## How finely each face is diced for the ding. Five is twenty-five patches a
## face and a hundred and fifty a panel — tuned against seven [MeshCar] panels
## rather than the twelve the blockout had, so a full car still rings roughly
## the same number of times overall: 12 panels x 4 x 4 x 6 = 1,152 patches on
## the blockout against 7 x 5 x 5 x 6 = 1,050 on a mesh car, about 91% of the
## old total and the same ballpark of dings across a job. [method
## GrimeMap.patches] is the exact arithmetic.
##
## The knob for how the whole thing feels: at 1 it rings once a face, at 8 it
## rings constantly. Nothing about correctness changes with it.
@export var patches_per_tile: int = 5

var _maps: Array[GrimeMap] = []
var _flashes: Array[PatchFlash] = []
var _panels: Array[Node3D] = []
var _skins: Array[GeometryInstance3D] = []


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
##
## The skins are kept alongside the maps rather than looked up again on every
## press: the arrays are already parallel, one more of them costs a pointer per
## panel, and it means [method _work] does no tree-walking on a physics tick.
func lay_on(car: Car) -> void:
	_panels = car.panels()
	_skins = []
	_maps = []
	_flashes = []
	var shader: Shader = load(SHADER) as Shader
	for panel: Node3D in _panels:
		var skin: GeometryInstance3D = car.skin_of(panel)
		var box: AABB = skin.get_aabb()
		var pixels: int = PanelResolution.tile_pixels_for(box)
		var map: GrimeMap = GrimeMap.new(box, pixels, patches_per_tile)
		# Sized from the map rather than from `patches_per_tile` and
		# `BoxProjection.COLUMNS`, which is the same arithmetic in a second place —
		# see [method GrimeMap.patch_grid].
		var flash: PatchFlash = PatchFlash.new(map.patch_grid())
		_skins.append(skin)
		_maps.append(map)
		_flashes.append(flash)
		skin.material_overlay = _overlay(shader, map, flash, box, car.kind_of(panel))


## Whether [method lay_on] has run. False on a room that never took up grime —
## the title screen's showcase circuit has nobody to wash the car.
func is_laid() -> bool:
	return not _maps.is_empty()


## Every panel that has mud on it, in the order [method map_of] indexes them.
func panels() -> Array[Node3D]:
	return _panels


## The map for one panel, or [code]null[/code] if that node is not a panel of the
## car this grime was laid on.
## Cast on the way in rather than taken as given. [member _panels] is an
## [code]Array[Node3D][/code], and searching a typed array for something that is
## not of its type is an engine error rather than a miss — so a stray hit on the
## driveway, which is a normal thing for a player to produce, would print rather
## than answer.
func map_of(panel: Node) -> GrimeMap:
	var index: int = _panels.find(panel as Node3D)
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
	var index: int = _panels.find(panel as Node3D)
	if index < 0:
		return null
	return _flashes[index]


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
##
## [b]The hit is put into the [i]skin's[/i] space and not the root's.[/b] They are
## one node on the CSG car and two on a mesh one, and the map was measured off the
## skin's box — so converting through the root would wash a spot the mask is not
## on the moment an importer leaves a mesh sitting at an offset inside its body.
func _work(
	panel: Node,
	world_point: Vector3,
	world_normal: Vector3,
	radius_metres: float,
	amount: float,
	stage: GrimeMap.Stage
) -> int:
	var part: Node3D = panel as Node3D
	var index: int = _panels.find(part)
	if index < 0:
		return 0
	var map: GrimeMap = _maps[index]
	var into: Transform3D = _skins[index].global_transform.affine_inverse()
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
		patch_finished.emit(String(part.name), patch, stage)
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
