## Integration test for the viewmodel — the five tool proxies in the player's
## hands.
##
## Under tests/integration/ because there is nothing here to construct on its
## own: [ViewModel] builds its meshes in `_ready()`, hangs them off a camera, and
## the interesting facts are all about where they ended up in that camera's
## frame. [ToolBelt]'s own rules — never empty, silent re-equip, refusing an
## unknown id — are unit-tested in tests/unit/test_tool_belt.gd and are not
## repeated here; what is tested here is that a belt change reaches the meshes.
##
## The garage is instantiated with [member Garage.first_person] set rather than
## through the play screen, so a failure points at the room and the viewmodel
## instead of at whatever else a screen is doing.
extends GutTest

const GARAGE: String = "res://src/world/garage.tscn"

## Close enough for sizes in metres — a tenth of a millimetre.
const TOLERANCE: float = 0.0001

## How square-on the rag has to be. A plane's normal is perpendicular to the view
## when the plane is edge-on, and edge-on it is zero pixels wide; 0.5 is 60° of
## slack either side of face-on, which no plausible retune of its angle crosses.
const NOT_EDGE_ON: float = 0.5

## How far off the view axis a cylinder has to lie before it stops reading as a
## disc pointed at the lens. cos 30°, so a tool aimed within 30° of straight down
## the barrel fails — that is the "floating dead centre pointing at the camera"
## look the issue asked us not to ship.
const NOT_AIMED_AT_THE_LENS: float = 0.866

var _garage: Garage = null


func before_each() -> void:
	var packed: PackedScene = load(GARAGE) as PackedScene
	assert_not_null(packed, "could not load %s" % GARAGE)
	if packed == null:
		return
	# Set before `add_child`, because `_ready()` is what reads it — this is the
	# same switch the play screen throws in its own scene file.
	var garage: Garage = packed.instantiate() as Garage
	garage.first_person = true
	_garage = garage
	add_child_autofree(_garage)
	await wait_process_frames(1)


func _view_model() -> ViewModel:
	return _garage.get_node("%ViewModel") as ViewModel


func _camera() -> Camera3D:
	return _garage.get_node("%Camera") as Camera3D


func _car_box() -> AABB:
	var car: MeshInstance3D = _garage.get_node("%Car") as MeshInstance3D
	return car.global_transform * car.get_aabb()


func _material(proxy: MeshInstance3D) -> StandardMaterial3D:
	return proxy.material_override as StandardMaterial3D


## Every proxy that is currently drawing. The list, not the count, so a failure
## says which two are on screen together rather than just that two are.
func _showing() -> Array[MeshInstance3D]:
	var showing: Array[MeshInstance3D] = []
	for child: Node in _view_model().get_children():
		var proxy: MeshInstance3D = child as MeshInstance3D
		if proxy != null and proxy.visible:
			showing.append(proxy)
	return showing


## The eight corners of [param proxy]'s own bounding box, in the camera's space.
##
## The mesh's local box transformed corner by corner rather than a world-space
## [AABB]: a world [AABB] around a cylinder lying on a diagonal bulges well past
## the cylinder, and every clearance below would then be measured against empty
## air instead of against the tool.
func _corners_in_view(proxy: MeshInstance3D) -> Array[Vector3]:
	var camera: Camera3D = _camera()
	var box: AABB = proxy.get_aabb()
	var corners: Array[Vector3] = []
	for corner: int in 8:
		corners.append(camera.to_local(proxy.global_transform * box.get_endpoint(corner)))
	return corners


func _world_corners(proxy: MeshInstance3D) -> Array[Vector3]:
	var box: AABB = proxy.get_aabb()
	var corners: Array[Vector3] = []
	for corner: int in 8:
		corners.append(proxy.global_transform * box.get_endpoint(corner))
	return corners


# ---- one in your hands, always ----------------------------------------------


func test_the_anchor_holds_one_proxy_per_tool() -> void:
	var belt: ToolBelt = _view_model().belt()
	assert_eq(_view_model().get_child_count(), belt.size(), "one mesh per tool, no more, no fewer")
	for tool: DetailingTool in belt.tools():
		assert_not_null(_view_model().proxy_for(tool.id), "%s has no proxy" % tool.display_name)


func test_something_is_already_in_your_hands_before_anything_is_equipped() -> void:
	# The first frame, with nobody having touched the belt. [ToolBelt] has no
	# empty-handed state precisely so this frame exists, and a viewmodel that
	# waited for `equipped_changed` before showing anything would open the game
	# with five invisible tools and no error anywhere.
	var showing: Array[MeshInstance3D] = _showing()
	assert_eq(showing.size(), 1, "exactly one tool is held before anything is equipped")
	if showing.size() != 1:
		return
	var held: DetailingTool = _view_model().belt().equipped()
	assert_eq(showing[0], _view_model().proxy_for(held.id), "and it is the one the belt says")


func test_equipping_each_tool_in_turn_shows_exactly_that_one() -> void:
	# Walked in belt order starting from the power wash, which is what the belt
	# already holds — so the first pass through is also the silent-re-equip case,
	# where `equip` returns false and emits nothing and the right mesh had better
	# still be the one on screen.
	var view_model: ViewModel = _view_model()
	for tool: DetailingTool in view_model.belt().tools():
		view_model.belt().equip(tool.id)
		var showing: Array[MeshInstance3D] = _showing()
		assert_eq(showing.size(), 1, "%s: exactly one tool is held" % tool.display_name)
		if showing.size() != 1:
			continue
		assert_eq(showing[0], view_model.proxy_for(tool.id), "%s must be it" % tool.display_name)


func test_equipping_backwards_down_the_belt_swaps_just_as_cleanly() -> void:
	# The same walk in reverse, because "show the new one" and "hide the old one"
	# can be written so that they only agree in one direction.
	var view_model: ViewModel = _view_model()
	var tools: Array[DetailingTool] = view_model.belt().tools()
	for step: int in tools.size():
		var tool: DetailingTool = tools[tools.size() - 1 - step]
		view_model.belt().equip(tool.id)
		var showing: Array[MeshInstance3D] = _showing()
		assert_eq(showing.size(), 1, "%s: exactly one tool is held" % tool.display_name)
		if showing.size() != 1:
			continue
		assert_eq(showing[0], view_model.proxy_for(tool.id), "%s must be it" % tool.display_name)


# ---- built from the catalogue and nowhere else -------------------------------


func test_every_proxy_is_the_shape_and_size_the_catalogue_gives_it() -> void:
	# The point of the catalogue carrying extents: written out here a second time,
	# the two would agree until somebody edited one of them.
	for tool: DetailingTool in DetailingTool.catalogue():
		var proxy: MeshInstance3D = _view_model().proxy_for(tool.id)
		match tool.shape:
			DetailingTool.Shape.CYLINDER:
				var cylinder: CylinderMesh = proxy.mesh as CylinderMesh
				assert_not_null(cylinder, "%s is a cylinder" % tool.display_name)
				if cylinder == null:
					continue
				assert_almost_eq(cylinder.height, tool.extent.y, TOLERANCE, tool.display_name)
				assert_almost_eq(
					cylinder.top_radius, tool.extent.x * 0.5, TOLERANCE, "x is a width"
				)
			DetailingTool.Shape.BOX:
				var box: BoxMesh = proxy.mesh as BoxMesh
				assert_not_null(box, "%s is a box" % tool.display_name)
				if box == null:
					continue
				assert_almost_eq(
					box.size.distance_to(tool.extent), 0.0, TOLERANCE, "all three axes"
				)
			DetailingTool.Shape.PLANE:
				var plane: PlaneMesh = proxy.mesh as PlaneMesh
				assert_not_null(plane, "%s is a plane" % tool.display_name)
				if plane == null:
					continue
				var flat: Vector2 = Vector2(tool.extent.x, tool.extent.z)
				assert_almost_eq(plane.size.distance_to(flat), 0.0, TOLERANCE, "x and z, not y")


func test_every_proxy_wears_the_catalogues_surface() -> void:
	for tool: DetailingTool in DetailingTool.catalogue():
		var material: StandardMaterial3D = _material(_view_model().proxy_for(tool.id))
		assert_not_null(material, "%s needs a material of its own" % tool.display_name)
		if material == null:
			continue
		assert_eq(material.albedo_color, tool.albedo, "%s: colour" % tool.display_name)
		assert_almost_eq(material.metallic, tool.metallic, TOLERANCE, tool.display_name)
		assert_almost_eq(material.roughness, tool.roughness, TOLERANCE, tool.display_name)


func test_the_power_wash_is_the_only_metal_on_the_belt() -> void:
	# Silver is a material, not a colour: at metallic 0 the same grey cylinder is
	# light plastic. The room's red toolboxes sit at 0.2, so "more than that" is
	# the bar, and everything else on the belt is a bottle or a rag and is not
	# metal at all.
	for tool: DetailingTool in DetailingTool.catalogue():
		var metallic: float = _material(_view_model().proxy_for(tool.id)).metallic
		if tool.id == DetailingTool.Id.POWER_WASH:
			assert_gt(metallic, 0.5, "the wand has to read as metal")
		else:
			assert_almost_eq(metallic, 0.0, TOLERANCE, "%s is not metal" % tool.display_name)


# ---- the rag, which has one side --------------------------------------------


func test_the_rag_is_double_sided() -> void:
	# Without this, the rag is invisible from behind — and "behind" is decided by
	# an angle nobody will remember is load-bearing the next time it is retuned.
	var rag: MeshInstance3D = _view_model().proxy_for(DetailingTool.Id.DRYING_RAG)
	var cull: BaseMaterial3D.CullMode = _material(rag).cull_mode
	assert_eq(cull, BaseMaterial3D.CULL_DISABLED, "a cloth has no back to cull")


func test_the_rag_never_presents_its_edge() -> void:
	# The other half. A plane seen edge-on is literally zero pixels, so the pose
	# has to keep its normal well away from perpendicular to the view. Measured
	# at 0.68 — about 47° off square — with 0.5 as the fence.
	var rag: MeshInstance3D = _view_model().proxy_for(DetailingTool.Id.DRYING_RAG)
	var normal: Vector3 = rag.global_transform.basis.y.normalized()
	var view: Vector3 = -_camera().global_transform.basis.z
	assert_gt(absf(normal.dot(view)), NOT_EDGE_ON, "the rag must not be held edge-on to the eye")


# ---- held, rather than floating in front of your face ------------------------


func test_the_tools_are_held_off_to_one_side_and_low() -> void:
	# In the camera's own space: +X is the right of the frame, -Y the bottom of
	# it. Every proxy inherits this from the anchor — the hand is one place, and
	# what changes per tool is the angle.
	for tool: DetailingTool in DetailingTool.catalogue():
		var held: Vector3 = _camera().to_local(_view_model().proxy_for(tool.id).global_position)
		assert_gt(held.x, 0.0, "%s must be off to one side" % tool.display_name)
		assert_lt(held.y, 0.0, "%s must sit low in the frame" % tool.display_name)
		assert_lt(held.z, 0.0, "%s must be in front of the eye" % tool.display_name)


func test_no_tool_is_pointed_straight_down_the_barrel() -> void:
	# A cylinder aimed at the lens is a circle. The long axis of every cylinder on
	# the belt has to lie at least 30° off the view direction to read as a wand or
	# a bottle rather than as a disc.
	for tool: DetailingTool in DetailingTool.catalogue():
		if tool.shape != DetailingTool.Shape.CYLINDER:
			continue
		var proxy: MeshInstance3D = _view_model().proxy_for(tool.id)
		var axis: Vector3 = proxy.global_transform.basis.y.normalized()
		var view: Vector3 = -_camera().global_transform.basis.z
		var aim: float = absf(axis.dot(view))
		assert_lt(aim, NOT_AIMED_AT_THE_LENS, "%s points at the lens" % tool.display_name)


# ---- the clipping decision, per proxy ----------------------------------------


func test_no_proxy_crosses_the_near_plane() -> void:
	# The viewmodel has no camera of its own — src/world/garage.gd records why —
	# so it lives inside this camera's near plane and every corner of every tool
	# has to stay in front of it. The tight one is the butt of the power wash wand
	# at 0.11 m against a 0.05 m near plane, and that corner is four times the
	# frame's half-width off the bottom-right of the screen besides.
	var near: float = _camera().near
	for tool: DetailingTool in DetailingTool.catalogue():
		for corner: Vector3 in _corners_in_view(_view_model().proxy_for(tool.id)):
			assert_lt(corner.z, -near, "%s clips the near plane" % tool.display_name)


func test_no_proxy_reaches_into_the_car() -> void:
	# The reason the second viewport is not built: with the eye parked, nothing in
	# the room ever gets between the lens and the tool. The car is the only
	# candidate — the walls are metres away — and the nearest any proxy comes to
	# it is 0.50 m, the tip of the power wash wand.
	var car: AABB = _car_box()
	for tool: DetailingTool in DetailingTool.catalogue():
		for corner: Vector3 in _world_corners(_view_model().proxy_for(tool.id)):
			assert_false(car.has_point(corner), "%s reaches into the car" % tool.display_name)


func test_no_proxy_leaves_the_room() -> void:
	# The other geometry that could swallow a held tool. Read off the walls rather
	# than written down again, so it keeps meaning "the room" if the room changes.
	var wall: Node3D = _garage.get_node("View/World/Room/WallLeft") as Node3D
	var half_width: float = absf(wall.position.x) - wall.scale.x * 0.5
	var ceiling: Node3D = _garage.get_node("View/World/Room/Ceiling") as Node3D
	var underside: float = ceiling.position.y - ceiling.scale.y * 0.5
	for tool: DetailingTool in DetailingTool.catalogue():
		for corner: Vector3 in _world_corners(_view_model().proxy_for(tool.id)):
			assert_lt(absf(corner.x), half_width, "%s is in a wall" % tool.display_name)
			assert_between(
				corner.y, 0.0, underside, "%s is in the floor or the roof" % tool.display_name
			)
