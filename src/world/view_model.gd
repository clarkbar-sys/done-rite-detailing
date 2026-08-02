## The five tools as primitives in the player's hands, exactly one of them at a
## time.
##
## This is the [ViewModel] anchor from #41 with something in it: a
## [MeshInstance3D] per tool hanging off the play camera, and a [ToolBelt] saying
## which one you can see. Swapping tools is a visibility flip and nothing else —
## the meshes are built once and never rebuilt, because a swap that allocates is
## a swap that can hitch.
##
## [b]Built in code from [method DetailingTool.catalogue], not written out as
## five nodes in the scene file.[/b] The catalogue already carries every tool's
## shape, extent, albedo, metallic and roughness, and it carries them precisely
## so the roll-up icon and the thing in your hands cannot disagree about what a
## sponge looks like. Typing those numbers into a [code].tscn[/code] a second
## time would recreate the drift the catalogue exists to prevent, and it would
## recreate it in the least visible place — a scene file diff nobody reads. So
## the shape, the size and the material come from the catalogue, and what lives
## here is only the part the catalogue has no opinion about: how a hand holds the
## thing.
##
## [b]The hand is one place; the tool turns in it.[/b] The offset into the corner
## of the frame belongs to the anchor and is set in [code]garage.tscn[/code] — it
## is where your hand is, and your hand does not move when you swap tools. What
## changes per tool is the angle, in [method _held_pose] below, and a grip
## distance along the tool's own long axis so a 0.72 m wand is held near its butt
## like a wand instead of balanced at its middle like a baton.
##
## [b]The hand can now be pointed, and it still does not move.[/b] Press the
## glass and the anchor swings to face where you pressed — [ToolAim] owns how far
## and how fast, this owns applying it. A rotation of the anchor about its own
## origin and emphatically not a new position for it: the hand stays 0.45 m off
## the lens in the corner of the frame, exactly where the scene file put it, and
## the tool sweeps around that point the way a wrist turns. Sliding the anchor
## toward the touch instead would have been a hand that drifts across the screen
## and out of the corner it is framed in, and it would have spent the clearance
## budget the room's standoff exists to protect. The five poses below are
## untouched by it: they are how a hand holds a thing, the swing is where the
## hand is pointed, and the two compose because the swing is applied to the
## anchor and the poses hang off it.
##
## [b]How a tool is held is now a thing tools can differ in.[/b] Four of them are
## held the way the table below says and never move in the hand; the power wash
## lies along the line from the hand to whatever is being aimed at, so that the
## water can leave the nozzle and land on the crosshair without bending in
## mid-air to get there. That difference is a [ToolCarry] per tool — the
## default one hands back its pose and ignores everything, [WandCarry] is the
## power wash's — and it is a class rather than an `if` in [method _process]
## because it will not be the last tool that wants to know where the aim is, and
## a viewmodel with five special cases in it is one function nobody can change
## one tool inside of. The poses in [method _held_pose] are unchanged and are
## still where every tool starts: a carry is handed its resting pose and decides
## what to do about it.
##
## [b]The wand has an end, and the end is a node.[/b] [code]Muzzle[/code] and
## [code]Butt[/code] are [Marker3D]s at the two ends of the power wash proxy,
## with their [code]-Z[/code] pointed out of the nozzle — which is the axis a
## [GPUParticles3D] emits along, so [WashJet] is stood on the first one every tick
## and throws water down it with no arithmetic of its own. They are also what a
## test measures the alignment
## with: the line between them is the wand, and asserting on two nodes is
## honest in a way that re-deriving the wand's axis from the same [Basis] the
## code posed it with is not.
##
## [b]The drying rag is a plane, and a plane has one side.[/b] Two ways to lose
## it entirely, and it needs both fixed. Edge-on it is zero pixels, so the angle
## in [method _held_pose] keeps its normal 47° off face-on and never anywhere
## near perpendicular to the view — asserted, in
## [code]tests/integration/test_view_model.gd[/code], as a dot product rather
## than as a screenshot somebody remembers taking. Back-on it is invisible under
## default culling, so its material is [code]CULL_DISABLED[/code]. The angle
## alone would be enough right up until the day the hand or the eye moves and
## flips it, which is the kind of bug that gets filed as "the rag disappeared
## sometimes". A very flat [BoxMesh] would dodge both, and is rejected because
## the catalogue says [constant DetailingTool.Shape.PLANE] and a viewmodel that
## quietly renders something else is a viewmodel the roll-up will disagree with.
##
## [b]Silver is a material, not a colour.[/b] The power wash is the only metal on
## the belt, and the only metal in the scene at all, and it comes out of the
## catalogue at [code]metallic = 0.9[/code], [code]roughness = 0.25[/code].
## Worth knowing what that buys here: the scene's [WorldEnvironment] hands it no
## radiance map at all, so its specular comes entirely from the two strip lights
## and the directional fill. That reads as dark metal with hard highlights
## rather than as chrome, which is right for a pressure washer and is
## emphatically not the light-grey plastic a [code]metallic = 0[/code] cylinder
## would have been.
##
## That used to be true by accident — the background was a flat colour, so there
## was nothing to mirror. It is now true [i]on purpose[/i]: the room has a real
## sky over it (see [code]src/world/sky.gdshader[/code]) and the environment
## sets [code]reflected_light_source[/code] to
## [constant Environment.REFLECTION_SOURCE_DISABLED] to keep it out of here.
## Left on, a bright cloudy sky is precisely the radiance map that turns this
## cylinder to chrome. Rendered rather than predicted: with reflections switched
## to the sky, the wand goes pale blue end to end and the single hard highlight
## this paragraph is about is gone. The change that added the sky was not the
## change to relight the wand. One line in [code]garage.tscn[/code] undoes it,
## and that line says so.
##
## [b]The belt lives here for now.[/b] Nothing else has asked for one yet. When
## the roll-up lands it needs [i]this[/i] belt and not one of its own — two belts
## means a UI that highlights one tool while you hold another — so it reads it
## from [method belt], or belt ownership gets hoisted somewhere both can see it.
## That is a decision for the change that brings the second listener, not a seam
## invented before there is anything to put through it.
class_name ViewModel
extends Node3D

## Degrees to radians, for [method _held_pose]'s table. Degrees because that is
## what a person tuning a pose actually thinks in, exactly like
## [member Garage.start_angle_degrees].
const PER_DEGREE: float = PI / 180.0

## What the wand's end markers are called, and what [method muzzle] and
## [method butt] look them up by. Named rather than found by index so a jet
## parented to one in a scene file is parented to something with a name.
const MUZZLE: String = "Muzzle"
const BUTT: String = "Butt"

## The turn that takes a marker's [code]-Z[/code] onto the wand's [code]+Y[/code]
## — a quarter turn about [code]X[/code]. Particles are emitted down a node's
## [code]-Z[/code] and a [CylinderMesh] is built along its [code]+Y[/code], so
## without this the water would come out of the side of the nozzle.
const OUT_OF_THE_NOZZLE: float = PI * 0.5

## How far down the aim to assume the paint is until a ray has said otherwise, in
## metres. A shade past [member Garage.standoff_metres], which is where the
## bodywork is once the eye has settled — so a tool brought up on the first frame
## of a press, before the room has answered, is pointed a few centimetres off
## rather than at its own hand.
const REST_RANGE: float = 2.5

var _belt: ToolBelt = null
var _proxies: Array[MeshInstance3D] = []
var _carries: Array[ToolCarry] = []
var _aim: ToolAim = null
var _rest: Vector3 = Vector3.ZERO

## Where the scene file parked the hand, before any lens was fitted to it — the
## fixed point [method fit_to_lens] recomputes [member _rest] from. Scaling
## [member _rest] in place instead would ratchet the hand further into the corner
## on every resize.
var _framed: Vector3 = Vector3.ZERO
var _mark: Vector3 = Vector3.ZERO
var _marked: bool = false


func _ready() -> void:
	# Where the scene file parked the hand, kept because every swing below
	# rebuilds the anchor's transform and has to put it back exactly. Read rather
	# than written down again here: the number that frames the hand lives in
	# `garage.tscn` (see [member Garage._view_model]) and a second copy of it here
	# would be a hand that jumps to a stale corner the first time somebody
	# retunes the shot.
	_rest = position
	_framed = position
	_belt = ToolBelt.new()
	for tool: DetailingTool in _belt.tools():
		var carry: ToolCarry = _carry_for(tool)
		var proxy: MeshInstance3D = _build(tool, carry)
		_carries.append(carry)
		_proxies.append(proxy)
		add_child(proxy)
	_belt.equipped_changed.connect(_on_equipped_changed)
	# Before any frame and before anybody has equipped anything: the belt starts
	# holding something rather than nothing (see [ToolBelt]), so there is never a
	# first frame with empty hands and never a five-tools-at-once frame either.
	_show_only(_belt.equipped_index())


## Swings the hand [param delta] seconds' worth toward wherever it was last
## pointed, and does nothing at all until somebody has handed it a [ToolAim].
##
## On the frame clock and not the physics one, unlike everything else about
## where the hand ends up. Deliberate, and the split is the usual one: the room
## decides what the hand is pointed at while physics is stepping, because that is
## the only time it is allowed to cast the ray that answers the question, and
## this is the visible motion between those decisions. A swing stepped at 60 Hz
## while the screen runs faster is a swing that judders.
##
## Skipped entirely once the swing has arrived, which is most frames — including
## every frame of the title screen, where nothing ever hands this an aim. The one
## exception is a tool that follows the aim by itself: the power wash is pointed
## at a place and not in a direction, and the place moves while the player walks
## even on a frame where the two angles have stopped.
func _process(delta: float) -> void:
	if _aim == null:
		return
	if _aim.is_settled() and not _carries[_belt.equipped_index()].tracks_the_aim():
		return
	_aim.advance(delta)
	transform = Transform3D(_aim.orientation(), _rest)
	_carry_the_equipped()


## The belt driving this viewmodel. See the class docs — the roll-up will want
## this one and not a second one.
func belt() -> ToolBelt:
	return _belt


## Hands this viewmodel the aim it swings on, and with it the whole ability to be
## pointed at anything.
##
## Given rather than built, because the limits and the speed are the room's
## numbers — they are about how far a tool may swing before it is in the paint,
## which is a fact about a car and a standing distance, not about a mesh. Handed
## over once, from [method Garage._ready], and only in first person: the title
## screen's camera has no player behind it to press anything.
func take_up_aiming(swing: ToolAim) -> void:
	_aim = swing


## The aim this viewmodel swings on, or [code]null[/code] on a screen that never
## took one up. What a test asserts the swing against, and what tells the room
## whether there is anything to point.
func aim() -> ToolAim:
	return _aim


## Points the hand along [param direction], read in the camera's own space.
func aim_toward(direction: Vector3) -> void:
	if _aim == null:
		return
	_aim.aim_toward(direction)


## Tells the hand where the crosshair actually landed, as a point in the world.
##
## [b]A place and not a direction, and that is the entire difference between a
## jet that lands on the mark and one that lands near it.[/b] The hand is not the
## eye — it hangs 0.45 m in front of the lens and off to one side — so a tool
## turned merely parallel to the aim points past the crosshair by that offset,
## which is a fifth of a metre at the range a car is washed from. Only
## [WandCarry] reads it; the four tools that are held at a fixed angle neither
## know nor care.
##
## [b]The mark and not the finger[/b], which is the one place this deliberately
## disagrees with [method aim_toward]. The room aims the hand at wherever the
## player pressed, and marks the nearest bodywork to it — normally the same
## point, and not the same point at all when a thumb on a low car sends the ray
## over the roof, which [ThumbLift] makes routine rather than rare. The water
## goes to the crosshair in that case ([method Garage._spend_the_trigger] records
## why at length), so the wand that is going to be spraying it has to be pointed
## there too. A jet leaving a wand aimed at the sky while the mud comes off the
## roof is the same broken tool that paragraph is about.
func mark_at(point: Vector3) -> void:
	_mark = point
	_marked = true


## Re-frames the hand for a lens that is no longer the one the shot was framed at.
##
## [b]The scene file's offset is a fraction dressed up as a distance.[/b] The
## anchor hangs 0.45 m down the camera's own -Z and 0.17 m to the right of it, and
## that 0.17 was chosen because at the design lens it is halfway to the edge of
## the frame — see [member Garage._view_model], where the arithmetic is written
## out. Halfway is the decision; the metres are only how it was written down. So
## when [Lens] narrows the lens on a portrait phone, leaving the metres alone
## slides the hand out of shot: measured, at the 70° ceiling the anchor lands at
## 1.05 of the frame's width, which is past the right-hand edge of it.
##
## [b]The two lateral offsets scale and the depth does not.[/b] How far in front
## of the lens the hand hangs is what the near plane and the car's clearance were
## both measured against, and neither of those has anything to do with how wide
## the lens is. Only where it sits across the frame does.
##
## [b]It writes [member _rest] rather than [member Node3D.position][/b], because
## [method _process] rebuilds the anchor's transform from [member _rest] every
## frame — a position set from outside would be overwritten before it was ever
## drawn. That is not a guess: it is what the first version of this did, and the
## integration test caught the hand still sitting at 1.05.
func fit_to_lens(design_fov_degrees: float, fov_degrees: float) -> void:
	var depth: float = absf(_framed.z)
	var design: float = LensFit.half_frame(design_fov_degrees, depth)
	if design <= 0.0:
		return
	var fitted: float = LensFit.half_frame(fov_degrees, depth) / design
	_rest = Vector3(_framed.x * fitted, _framed.y * fitted, _framed.z)
	position = _rest


## Lets the hand fall back to rest. The player has lifted their finger, and a
## hand still pointed at the last thing they touched would say the tool is aimed
## at something when nothing is aimed at all.
func lower() -> void:
	if _aim == null:
		return
	_aim.lower()


## The mesh standing in for [param id], or `null` if the belt doesn't carry it.
##
## Looked up through the belt rather than by node name so that a caller — a
## test, mostly — can ask about a tool without knowing what the node ended up
## being called.
func proxy_for(id: DetailingTool.Id) -> MeshInstance3D:
	var index: int = _belt.index_of(id)
	if index < 0:
		return null
	return _proxies[index]


## The end of the power wash wand, where the water comes out: a [Marker3D] whose
## [code]-Z[/code] points down the jet, for the effect to hang off and for a test
## to measure the alignment from.
func muzzle() -> Marker3D:
	return _wand_end(MUZZLE)


## The other end of it, where the hose goes. The pair is what makes the wand's
## axis something you can read off two nodes instead of re-deriving it.
func butt() -> Marker3D:
	return _wand_end(BUTT)


func _on_equipped_changed(tool: DetailingTool) -> void:
	_show_only(_belt.index_of(tool.id))
	# The tool that has just come up has been sitting in whatever pose it was last
	# left in, which for the power wash is wherever the aim was pointed the last
	# time it was held. Posing it here rather than waiting for `_process` means a
	# swap made while the hand is settled — which is most swaps — does not show a
	# frame of the old aim.
	_carry_the_equipped()


## Shows the proxy at [param index] and hides the other four.
##
## Every proxy is assigned on every swap rather than just the two that changed.
## Five booleans is nothing, and "hide the old one, show the new one" is the
## shape of bug that leaves two tools on screen the first time a caller manages
## to change the equipped tool twice without this hearing about it once.
func _show_only(index: int) -> void:
	for slot: int in _proxies.size():
		_proxies[slot].visible = slot == index


## Assembles one tool's proxy: catalogue for what it is, [param carry] for how it
## is held.
func _build(tool: DetailingTool, carry: ToolCarry) -> MeshInstance3D:
	var proxy: MeshInstance3D = MeshInstance3D.new()
	# "Tire & Engine Cleaner" -> "TireEngineCleaner". Named after the tool rather
	# than numbered, so the remote scene tree during a debug session says which
	# one is showing without anybody counting children.
	proxy.name = tool.display_name.replace("&", "").replace(" ", "")
	proxy.mesh = _mesh_for(tool)
	proxy.material_override = _material_for(tool)
	proxy.transform = carry.rest_pose()
	var wand: WandCarry = carry as WandCarry
	if wand != null:
		proxy.add_child(_end_marker(MUZZLE, wand.nozzle()))
		proxy.add_child(_end_marker(BUTT, wand.butt()))
	return proxy


## How [param tool] is carried: the default for four of them, and the aimed wand
## for the power wash.
##
## The one place a tool is singled out by id for something other than framing,
## and deliberately a single line rather than a field on [DetailingTool] — see
## [ToolCarry] for why the catalogue is the wrong home for it. Every carry is
## built with the same [method _held_pose] the table has always given it, so the
## four that ignore the aim are held exactly where they were before any of this
## existed.
func _carry_for(tool: DetailingTool) -> ToolCarry:
	if tool.id == DetailingTool.Id.POWER_WASH:
		return WandCarry.new(_held_pose(tool.id), tool.extent.y)
	return ToolCarry.new(_held_pose(tool.id))


## One of the wand's two ends: a [Marker3D] at [param at] in the proxy's own
## space, turned so its [code]-Z[/code] runs out of the nozzle.
func _end_marker(named: String, at: Vector3) -> Marker3D:
	var marker: Marker3D = Marker3D.new()
	marker.name = named
	marker.transform = Transform3D(Basis.from_euler(Vector3(OUT_OF_THE_NOZZLE, 0.0, 0.0)), at)
	return marker


## The named end of the power wash proxy, or [code]null[/code] on a belt that
## does not carry one. Through [method proxy_for] rather than by node path, for
## the reason that method exists: a caller should not have to know what the mesh
## ended up being called.
func _wand_end(named: String) -> Marker3D:
	var proxy: MeshInstance3D = proxy_for(DetailingTool.Id.POWER_WASH)
	if proxy == null:
		return null
	return proxy.get_node_or_null(NodePath(named)) as Marker3D


## Puts the tool in the player's hands where its carry says it goes this frame.
##
## Only the equipped one. The other four are not on screen, and the one that
## comes up next is posed by [method _on_equipped_changed] on the frame it does —
## so nothing is ever drawn in a stale pose, and nothing is computed for a mesh
## nobody can see.
##
## Does nothing at all without an aim, which is the title screen: there is nobody
## behind that camera to point anything, so every proxy stays in the resting pose
## it was built in.
func _carry_the_equipped() -> void:
	if _aim == null:
		return
	var index: int = _belt.equipped_index()
	_proxies[index].transform = _carries[index].pose(_pointed_at(), _aim.raise_amount())


## The point the hand is aimed at, in the hand's own space — which is what a
## [ToolCarry] is handed, and the only form of the aim that is any use for
## pointing something [i]at[/i] the mark rather than along the ray to it.
##
## The crosshair once there is one, read back into the hand's frame every frame
## rather than converted once: the eye walks, so a point that is 20° to the left
## of the hand now is somewhere else in a second's time, and the wand has to
## follow it there without the room saying anything further.
##
## [b]Until then, a guess, and one that is never seen.[/b] A tool at the very
## start of a press — or one aimed by a caller with no room behind it, which is
## every test that drives [method aim_toward] directly — has nothing marked yet,
## so the target is [constant REST_RANGE] down the aim: the same arithmetic, with
## the paint assumed to be where the standoff usually puts it. It is only ever
## read while the raise is still near zero, which is to say while the tool is
## still in the pose the guess cannot move it out of.
func _pointed_at() -> Vector3:
	if _marked:
		return to_local(_mark)
	return _aim.orientation().inverse() * (_aim.pointing() * REST_RANGE - _rest)


## The primitive [param tool] renders as, at the size the catalogue gives it.
##
## The per-shape reading of [member DetailingTool.extent] is the contract that
## class documents: a [CylinderMesh] takes `x` as a diameter and `y` as a height,
## a [PlaneMesh] takes `x` and `z`. Getting that wrong makes a 6 cm wand 12 cm
## thick, which looks like a scaling bug rather than like the mistake it is.
func _mesh_for(tool: DetailingTool) -> Mesh:
	match tool.shape:
		DetailingTool.Shape.CYLINDER:
			var cylinder: CylinderMesh = CylinderMesh.new()
			cylinder.top_radius = tool.extent.x * 0.5
			cylinder.bottom_radius = tool.extent.x * 0.5
			cylinder.height = tool.extent.y
			return cylinder
		DetailingTool.Shape.BOX:
			var box: BoxMesh = BoxMesh.new()
			box.size = tool.extent
			return box
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(tool.extent.x, tool.extent.z)
	return plane


## [param tool]'s surface, straight off the catalogue.
##
## A [code]material_override[/code] rather than a surface material, matching the
## room's boxes: one material per proxy, visible in one place, and no chance of a
## mesh resource carrying a colour of its own that disagrees.
func _material_for(tool: DetailingTool) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = tool.albedo
	material.metallic = tool.metallic
	material.roughness = tool.roughness
	if tool.shape == DetailingTool.Shape.PLANE:
		# Half of what keeps the rag on screen; the other half is its angle. See
		# the class docs — a cloth has no back, so refusing to draw one is the
		# renderer being right about a mesh that is wrong.
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## How [param id] sits in the hand: an angle, and how far down its own long axis
## the hand grips it.
##
## Read in the anchor's space, which is the camera's: `-Z` is into the screen,
## `+X` is the right of the frame, `+Y` is up. The anchor is already parked in
## the bottom-right corner of the shot, so every pose here is about turning the
## tool so its business end swings up and left into frame while whatever a fist
## would be wrapped around runs off the bottom of the screen. That is the whole
## difference between "held" and "floating in front of your face".
##
## A [code]match[/code] over the ids rather than a table hung off the catalogue:
## these are five hand-tuned numbers about framing, and framing is not something
## [DetailingTool] should have an opinion about — it is data the roll-up reads
## too, and a roll-up icon is not held by anybody.
func _held_pose(id: DetailingTool.Id) -> Transform3D:
	match id:
		DetailingTool.Id.POWER_WASH:
			# A wand: gripped 6 cm below its middle so two thirds of it reaches up
			# and away, tip finishing near the centre of the frame like something
			# aimed at the car rather than at the viewer.
			return _pose(Vector3(-55.0, 0.0, 25.0), -0.06)
		DetailingTool.Id.SPONGE:
			# Palm-up: tipped 30° toward the viewer so the broad 24x17 cm face is
			# what you see, not the 10 cm edge. A sponge read edge-on is a brick.
			return _pose(Vector3(30.0, -20.0, 12.0), 0.0)
		DetailingTool.Id.DRYING_RAG:
			# 65° from flat, which lands its normal 47° off face-on — a long way
			# from the edge-on angle that would render it as nothing at all, and
			# far enough off square that it reads as cloth in a hand rather than
			# as a poster stuck to the lens.
			return _pose(Vector3(65.0, -25.0, 15.0), 0.0)
		DetailingTool.Id.WINDOW_CLEANER:
			# A bottle held near its base and tilted left, so the two blue tools
			# differ in silhouette and posture as well as in colour.
			return _pose(Vector3(-20.0, 0.0, 22.0), -0.05)
	# Tire & engine cleaner: the same idea as the window bottle, leaned further
	# over so a glance at the corner of the screen tells them apart even before
	# the near-black registers as a colour.
	return _pose(Vector3(-14.0, 0.0, 30.0), -0.05)


## One entry of [method _held_pose]'s table: [param euler_degrees] of rotation,
## then slid [param grip] metres along the tool's [i]own[/i] `+Y` — which is the
## long axis of a cylinder and the height of a box. Local rather than in the
## anchor's space so a pose stays meaningful after its angle is retuned; in the
## anchor's space, changing the angle would silently move the tool as well.
func _pose(euler_degrees: Vector3, grip: float) -> Transform3D:
	var orientation: Basis = Basis.from_euler(euler_degrees * PER_DEGREE)
	return Transform3D(orientation, Vector3.ZERO).translated_local(Vector3(0.0, grip, 0.0))
