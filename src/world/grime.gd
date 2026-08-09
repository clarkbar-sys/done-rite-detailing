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
## Where a tool can be got onto each panel, parallel to [member _panels] and empty
## on a car nobody measured. Kept after [method lay_on] has spent it, so a car that
## is dirtied again does not pay to be looked at twice — see [method _reach_across].
var _reaches: Array[PanelReach] = []
## The eye poses [member _reaches] was measured from, for the same reason: it is
## how "the same question as last time" is recognised.
var _eyes: PackedVector3Array = PackedVector3Array()


## Dims every panel's finished-patch flashes.
##
## [b]The one thing here that runs on a clock.[/b] Everything else in this class
## happens because a tool was held; a flash happens because one was held a moment
## ago, and something has to take it away again. It is a loop over the car's
## panels doing a single integer comparison each while nothing is lit — [method
## PatchFlash.fade] returns early and uploads nothing — so an untouched car costs
## a handful of branches a frame rather than a handful of texture uploads.
func _process(delta: float) -> void:
	for flash: PatchFlash in _flashes:
		flash.fade(delta)


## Puts mud on every panel of [param car] — on the parts of every panel the player
## can get a tool onto, when there is a way to find out which those are.
##
## Must be called after the car has had a frame to build its CSG — see the class
## docs. Calling it twice replaces what was there, which is what a "reset the
## car" would want and is otherwise nobody's business.
##
## [param eyes] is every pose the player's eye may take up around this car
## ([method PanelReach.eyes]) and [param brush_metres] is how wide the narrowest
## tool reaches. Given both, this looks at the car from each of those poses through
## the same [method PhysicsDirectSpaceState3D.intersect_ray] the trigger is spent
## with, and each panel's map is seeded only where something was seen — which is
## the whole of [code]#144[/code], and the reason a car has an underside that is
## not muddy and a percentage that can reach a hundred.
##
## [b]Both default to nothing, and that default is the old behaviour exactly.[/b]
## A caller with no physics world to cast in — every unit test, the fixtures, the
## panel-contract suite — gets a full panel, which is what those want and what this
## did before. Nothing here decides the band the eye is allowed into: that is the
## room's, and it arrives already sampled, so this class never has to know a
## [Garage] exists.
##
## The skins are kept alongside the maps rather than looked up again on every
## press: the arrays are already parallel, one more of them costs a pointer per
## panel, and it means [method _work] does no tree-walking on a physics tick.
func lay_on(
	car: Car, eyes: PackedVector3Array = PackedVector3Array(), brush_metres: float = 0.0
) -> void:
	var parts: Array[Node3D] = car.panels()
	var skins: Array[GeometryInstance3D] = []
	for panel: Node3D in parts:
		skins.append(car.skin_of(panel))
	# Before the arrays below are replaced, because the answer may be the one
	# already in them — see [method _reach_across].
	var reaches: Array[PanelReach] = _reach_across(car, parts, skins, eyes, brush_metres)
	_panels = parts
	_skins = skins
	_reaches = reaches
	_eyes = eyes
	_maps = []
	_flashes = []
	var shader: Shader = load(SHADER) as Shader
	for index: int in _panels.size():
		var skin: GeometryInstance3D = _skins[index]
		var box: AABB = skin.get_aabb()
		var pixels: int = PanelResolution.tile_pixels_for(box)
		var reach: PanelReach = null if _reaches.is_empty() else _reaches[index]
		var map: GrimeMap = GrimeMap.new(box, pixels, patches_per_tile, reach)
		# Sized from the map rather than from `patches_per_tile` and
		# `BoxProjection.COLUMNS`, which is the same arithmetic in a second place —
		# see [method GrimeMap.patch_grid].
		var flash: PatchFlash = PatchFlash.new(map.patch_grid())
		_maps.append(map)
		_flashes.append(flash)
		skin.material_overlay = _overlay(shader, map, flash, box, car.kind_of(_panels[index]))


## Where a tool can be got onto each panel of [param car], measured by looking at
## it from every pose in [param eyes] and growing what was seen by
## [param brush_metres] — or an empty array when there is nothing to measure with,
## which [method lay_on] reads as "all of it".
##
## [b]This is the physics half, and it is here rather than in [PanelReach] because
## a space state belongs to a node in a tree.[/b] Everything that can be worked out
## without one — where to stand, what to aim at, where a hit lands in the atlas,
## how far to grow it — is in that class, where a unit test can reach it. What is
## left here is the loop and the query, and the query is deliberately the same
## [method PhysicsDirectSpaceState3D.intersect_ray] [method AimProbe.under_the_finger]
## spends the trigger through: reachability is then defined by the code that
## actually decides what a press lands on, rather than by a second model of the car
## that can disagree with it.
##
## [b]Cast on the physics clock.[/b] A space state may only be queried while
## physics is stepping, which is why [method Garage._lay_on_the_grime] waits for a
## physics frame rather than an idle one before calling in here.
##
## [b]Measured on this hardware, against the pack's own trimesh colliders.[/b] The
## sedan the bay parks comes out at 78 eye poses — 96 sampled, eighteen dropped for
## standing on the car — against a 312-point lattice, which is 24,336 rays at the
## 3.6 µs a landed [method PhysicsDirectSpaceState3D.intersect_ray] costs on these
## colliders ([code]scripts/perf-probe.gd[/code] has that number and how it was
## taken). The whole of [method lay_on] — the rays, the dilation, and seven maps
## seeded and cut back — is 140-150 ms on the sedan and 185 ms on the pickup, which
## is the longest style in the pack at 35,100 rays. Seeding the maps alone, which
## is what a re-lay off the cached mask costs, is 15 ms of that.
##
## It is paid once, on the frame after the room is ready, against a load that is
## already building ten thousand triangles of collider — [MeshCar]'s class docs
## have that at 2.8-3.4 ms a car. Nothing about it is per frame.
##
## [b]And it is not paid twice for the same car.[/b] The attract loop dirties the
## car again every time the demo finishes it ([method Garage._on_lapped]), which is
## the same panels seen from the same band — so the answer from last time is handed
## back when both are unchanged. Recomputing would be a quarter-second hitch behind
## the title card for a mask that cannot have moved.
func _reach_across(
	car: Car,
	parts: Array[Node3D],
	skins: Array[GeometryInstance3D],
	eyes: PackedVector3Array,
	brush_metres: float
) -> Array[PanelReach]:
	if eyes.is_empty() or brush_metres <= 0.0:
		return []
	if parts == _panels and eyes == _eyes and _reaches.size() == parts.size():
		return _reaches
	var grid: Vector2i = GrimeMap.patch_grid_for(patches_per_tile)
	var found: Array[PanelReach] = []
	var into: Array[Transform3D] = []
	var index_of: Dictionary = {}
	for index: int in parts.size():
		found.append(PanelReach.new(skins[index].get_aabb(), grid))
		into.append(skins[index].global_transform.affine_inverse())
		index_of[parts[index]] = index
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for target: Vector3 in PanelReach.targets(car.bounds()):
		for eye: Vector3 in eyes:
			var hit: Dictionary = space.intersect_ray(
				PhysicsRayQueryParameters3D.create(eye, target)
			)
			if hit.is_empty():
				continue
			var landed: Node = hit["collider"]
			if not index_of.has(landed):
				continue
			var found_at: int = index_of[landed]
			var where: Vector3 = hit["position"]
			var outward: Vector3 = hit["normal"]
			# Into the skin's own space and not the panel root's, and the normal by the
			# basis alone — the same conversion [method _work] does on every press, and
			# for the same two reasons it gives.
			var to_panel: Transform3D = into[found_at]
			found[found_at].saw(to_panel * where, (to_panel.basis * outward).normalized())
	for reach: PanelReach in found:
		reach.spread(brush_metres)
	return found


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
## panel is, so "half the car" here means half the texels, and a wheel counts as
## much as the whole shell. That is the wrong answer for a score and the right
## one for a progress bar over a fixed amount of work, which is what this is
## while there is nothing spending it.
##
## [b]A panel with nothing reachable on it is left out of the average
## entirely[/b], rather than counted as a zero — see [method GrimeMap.has_reach].
## Counted, it would be a panel that is permanently spotless and permanently
## unpolished at the same time, dragging one average down and holding the other up,
## and neither reading would be about anything a player did.
func remaining() -> float:
	var left: float = 0.0
	var counted: int = 0
	for map: GrimeMap in _maps:
		if not map.has_reach():
			continue
		left += map.remaining()
		counted += 1
	if counted == 0:
		return 0.0
	return left / float(counted)


## How much of the car is under product right now, as [code]0..1[/code]. Goes up
## under the cleaners and back down under the rag — see [method GrimeMap.product].
func product() -> float:
	var on: float = 0.0
	var counted: int = 0
	for map: GrimeMap in _maps:
		if not map.has_reach():
			continue
		on += map.product()
		counted += 1
	if counted == 0:
		return 0.0
	return on / float(counted)


## How much of the car is buffed to a shine, as [code]0..1[/code].
##
## The progress number, and the one a bar should be reading: it only ever rises,
## and unlike [method remaining] it does not call a car finished when the mud
## comes off. Unweighted, and blind to panels with nothing reachable on them, for
## the reasons [method remaining] gives.
##
## [b]It reaches one now.[/b] Before [PanelReach] there was no way to buff the
## underside of a shell or the air inside a panel's box, so this asymptoted
## somewhere under a half and there was no honest percentage to show anybody. It is
## what [code]src/ui/score_hud.gd[/code] prints as the done readout.
func shine() -> float:
	var buffed: float = 0.0
	var counted: int = 0
	for map: GrimeMap in _maps:
		if not map.has_reach():
			continue
		buffed += map.shine()
		counted += 1
	if counted == 0:
		return 0.0
	return buffed / float(counted)


## How much work the whole car has had done on it in [param stage], ever,
## measured in patches' worth — see [method GrimeMap.worked].
##
## [b]Summed and not averaged[/b], which is the one place this differs from the
## three readings above it. Those answer "how far through is the car", so a
## panel-average is the honest shape and a car with one spotless wing is not
## finished. This answers "how much has been done", and half a patch of washing
## is half a patch of washing whichever panel it happened on — dividing by the
## panel count would make the same stroke worth less on a car with more pieces,
## which is exactly the trap the swap from a twelve-panel blockout to a
## seven-panel model would have sprung.
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
