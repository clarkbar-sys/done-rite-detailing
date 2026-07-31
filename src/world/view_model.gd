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
## the belt and it comes out of the catalogue at [code]metallic = 0.9[/code],
## [code]roughness = 0.25[/code] — four and a half times the room's red
## toolboxes, which sit at 0.2. Worth knowing what that buys in this room: the
## bay's [WorldEnvironment] has a flat colour background and no sky or reflection
## probe, so a metal here has no radiance map to mirror and its specular comes
## entirely from the two strip lights and the directional fill. That reads as
## dark metal with hard highlights rather than as chrome, which is right for a
## pressure washer and is emphatically not the light-grey plastic a
## [code]metallic = 0[/code] cylinder would have been. Giving it a reflection
## probe to chew on would mean changing the room, and the room is also the title
## screen's.
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

var _belt: ToolBelt = null
var _proxies: Array[MeshInstance3D] = []


func _ready() -> void:
	_belt = ToolBelt.new()
	for tool: DetailingTool in _belt.tools():
		var proxy: MeshInstance3D = _build(tool)
		_proxies.append(proxy)
		add_child(proxy)
	_belt.equipped_changed.connect(_on_equipped_changed)
	# Before any frame and before anybody has equipped anything: the belt starts
	# holding something rather than nothing (see [ToolBelt]), so there is never a
	# first frame with empty hands and never a five-tools-at-once frame either.
	_show_only(_belt.equipped_index())


## The belt driving this viewmodel. See the class docs — the roll-up will want
## this one and not a second one.
func belt() -> ToolBelt:
	return _belt


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


func _on_equipped_changed(tool: DetailingTool) -> void:
	_show_only(_belt.index_of(tool.id))


## Shows the proxy at [param index] and hides the other four.
##
## Every proxy is assigned on every swap rather than just the two that changed.
## Five booleans is nothing, and "hide the old one, show the new one" is the
## shape of bug that leaves two tools on screen the first time a caller manages
## to change the equipped tool twice without this hearing about it once.
func _show_only(index: int) -> void:
	for slot: int in _proxies.size():
		_proxies[slot].visible = slot == index


## Assembles one tool's proxy: catalogue for what it is, [method _held_pose] for
## how it is held.
func _build(tool: DetailingTool) -> MeshInstance3D:
	var proxy: MeshInstance3D = MeshInstance3D.new()
	# "Tire & Engine Cleaner" -> "TireEngineCleaner". Named after the tool rather
	# than numbered, so the remote scene tree during a debug session says which
	# one is showing without anybody counting children.
	proxy.name = tool.display_name.replace("&", "").replace(" ", "")
	proxy.mesh = _mesh_for(tool)
	proxy.material_override = _material_for(tool)
	proxy.transform = _held_pose(tool.id)
	return proxy


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
