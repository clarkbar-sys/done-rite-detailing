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
##
## [b]Nothing here presses anything[/b], so every tool is at rest and every
## measurement below is of the resting pose. That is deliberate now that the
## power wash moves in the hand: what a wand does while it is being aimed needs a
## finger on real glass and lives in
## [code]tests/integration/test_play_screen_aim.gd[/code], and what it does to
## the resting frame — which is nothing at all — is exactly what this suite is
## for.
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

## Where metal starts, for anything on the belt that is not the wand. The room's
## own red toolboxes sit at 0.2 and read as painted steel, so this is the bar
## already in use for the same judgement one scene away. Measured on the belt: the
## tyre bottle's body is the only non-wand surface above zero at all, at 0.05.
const NOT_METAL: float = 0.2

## Every eighth texel each way when a metallic map is averaged — 1,024 samples of
## a 256 px map, which is plenty for a mean and is not 65,536 `get_pixel` calls
## per surface in a test that runs six of them.
const METAL_STRIDE: int = 8

var _garage: Garage = null

## What the belt was holding before any test touched it, so [method before_each]
## can put it back — see there.
var _equipped_before: DetailingTool.Id = DetailingTool.Id.POWER_WASH


## One room for the whole file. Nothing here presses anything — the class docs
## say so, and it is why this suite is measurements of a resting pose — so
## twenty-one first-person rooms were twenty-one copies of one arrangement of
## five meshes hanging off a camera.
##
## [b]The one thing that moves is which tool is held, and [method before_each]
## puts it back.[/b] That is the condition on sharing a fixture: a test that
## leaves the room changed couples the suite into an order-dependent one, which
## passes in file order and fails in any other. Two tests below walk the belt end
## to end on purpose, and the walk is the whole assertion. Checked by running the
## file with its tests in reverse.
##
## Measured on a four-core box with this suite run on its own: 14.9 s to 2.3 s,
## of which about 0.9 s is Godot starting up either way.
##
## [method add_child] rather than [method GutTest.add_child_autofree]: GUT empties
## its autofree list after every *test*, so a fixture registered with it here
## would be freed out from under test two.
func before_all() -> void:
	_garage = _a_first_person_room()
	if _garage == null:
		return
	add_child(_garage)
	await wait_process_frames(1)
	_equipped_before = _view_model().belt().equipped().id


## [method Node.free] and not [method Node.queue_free]: GUT counts the test
## script's children the moment `after_all` returns, and a queued free has not
## happened yet — the room would be reported as a leak on its way out.
func after_all() -> void:
	if _garage != null:
		_garage.free()
		_garage = null


## The explicit reset the shared room is worth, and deliberately only this: the
## belt is the whole of what the tests below write to it.
func before_each() -> void:
	if _garage != null:
		_view_model().belt().equip(_equipped_before)


## A first-person room, instanced but not yet in a tree — the caller adds it and
## decides how long it lives, which is the whole reason this hands one back
## rather than parenting it. [method before_all]'s room outlives every test in
## the file and so cannot go through GUT's autofree; the one test that builds its
## own wants exactly the opposite.
##
## [member Garage.first_person] is set before the node is added, because
## `_ready()` is what reads it — the same switch the play screen throws in its
## own scene file.
func _a_first_person_room() -> Garage:
	var packed: PackedScene = load(GARAGE) as PackedScene
	assert_not_null(packed, "could not load %s" % GARAGE)
	if packed == null:
		return null
	var garage: Garage = packed.instantiate() as Garage
	garage.first_person = true
	return garage


func _view_model() -> ViewModel:
	return _garage.get_node("%ViewModel") as ViewModel


func _camera() -> Camera3D:
	return _garage.get_node("%Camera") as Camera3D


## The car's bounding box in world space. [Car.bounds] rather than an [AABB] off
## a mesh: a car is a handful of separate panels, and an axis-aligned box round
## one is wider than the bodywork because every car in the pack tapers at the
## nose and the tail — which only makes the clearances below more conservative.
## Deliberately not "the mirrors": the blockout had them and were the widest
## thing on it, and no car in the pack has any.
func _car_box() -> AABB:
	var car: Car = _garage.get_node("%Car") as Car
	return car.bounds()


func _material(proxy: MeshInstance3D) -> StandardMaterial3D:
	return proxy.material_override as StandardMaterial3D


## Every material actually painting [param proxy], wherever they came from: the
## catalogue's one override for a tool built out of a primitive, and the import's
## own for a tool built out of a model. What a question about how a tool
## [i]looks[/i] has to ask, now that those are two different places.
##
## All of a model's surfaces and not just the first, because the tyre bottle is
## six of them — body, neck, nozzle, two caps and a trigger — and a claim about
## how a tool looks that only ever read the body would be true of a sixth of it.
func _paintings(proxy: MeshInstance3D) -> Array[StandardMaterial3D]:
	var override: StandardMaterial3D = _material(proxy)
	if override != null:
		return [override]
	var skins: Array[StandardMaterial3D] = []
	for surface: int in proxy.mesh.get_surface_count():
		skins.append(proxy.mesh.surface_get_material(surface) as StandardMaterial3D)
	return skins


## What [param skin] renders as metal, taking its metallic map into account.
##
## [member BaseMaterial3D.metallic] is a multiplier over that map rather than the
## answer on its own, and glTF's default for the factor is 1.0 — so a material
## that carries a map and says nothing about the factor reads as "solid metal" to
## anybody who only asks the property, and renders as whatever the map says. The
## tyre bottle's body is exactly that: factor 1.0 over a map averaging 0.05, which
## is a plastic bottle with a few specks of foil on the label.
##
## The mean of the map and not its maximum, for the same reason: what is being
## asked is whether the tool reads as metal, and a handful of bright texels on a
## label does not make a bottle a spanner.
func _metallic_of(skin: StandardMaterial3D) -> float:
	if skin.metallic_texture == null:
		return skin.metallic
	var map: Image = skin.metallic_texture.get_image()
	if map == null:
		return skin.metallic
	# Imported textures may arrive VRAM-compressed depending on the import
	# settings the asset ended up with, and a compressed image cannot be sampled.
	if map.is_compressed():
		map.decompress()
	var total: float = 0.0
	var samples: int = 0
	for down: int in range(0, map.get_height(), METAL_STRIDE):
		for across: int in range(0, map.get_width(), METAL_STRIDE):
			total += _channel(map.get_pixel(across, down), skin.metallic_texture_channel)
			samples += 1
	return skin.metallic * total / maxf(float(samples), 1.0)


## One channel of [param texel], named the way [BaseMaterial3D] names it.
func _channel(texel: Color, channel: BaseMaterial3D.TextureChannel) -> float:
	match channel:
		BaseMaterial3D.TEXTURE_CHANNEL_RED:
			return texel.r
		BaseMaterial3D.TEXTURE_CHANNEL_GREEN:
			return texel.g
		BaseMaterial3D.TEXTURE_CHANNEL_BLUE:
			return texel.b
		BaseMaterial3D.TEXTURE_CHANNEL_ALPHA:
			return texel.a
	return texel.v


## Every proxy of [param view_model] that is currently drawing. The list, not the
## count, so a failure says which two are on screen together rather than just
## that two are.
##
## Takes the viewmodel rather than reaching for the shared room's, because one
## test below runs on a room of its own — see
## [method test_something_is_already_in_your_hands_before_anything_is_equipped].
func _showing_in(view_model: ViewModel) -> Array[MeshInstance3D]:
	var showing: Array[MeshInstance3D] = []
	for child: Node in view_model.get_children():
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
	#
	# ON A ROOM OF ITS OWN, and it is the only test in this file that gets one.
	# "Before anything is equipped" is a claim about a belt nobody has touched, and
	# the shared room's belt is walked end to end by the two tests below — a reset
	# in [method before_each] puts the right tool back in its hands but cannot make
	# it untouched again. One extra room out of twenty-one is what the claim costs,
	# and a claim about a first frame that is not made on a first frame is not the
	# claim.
	var fresh: Garage = _a_first_person_room()
	assert_not_null(fresh, "could not build a room nobody has touched")
	if fresh == null:
		return
	add_child_autofree(fresh)
	await wait_process_frames(1)
	var view_model: ViewModel = fresh.get_node("%ViewModel") as ViewModel
	var showing: Array[MeshInstance3D] = _showing_in(view_model)
	assert_eq(showing.size(), 1, "exactly one tool is held before anything is equipped")
	if showing.size() != 1:
		return
	var held: DetailingTool = view_model.belt().equipped()
	assert_eq(showing[0], view_model.proxy_for(held.id), "and it is the one the belt says")


func test_equipping_each_tool_in_turn_shows_exactly_that_one() -> void:
	# Walked in belt order starting from the power wash, which is what the belt
	# already holds — so the first pass through is also the silent-re-equip case,
	# where `equip` returns false and emits nothing and the right mesh had better
	# still be the one on screen.
	var view_model: ViewModel = _view_model()
	for tool: DetailingTool in view_model.belt().tools():
		view_model.belt().equip(tool.id)
		var showing: Array[MeshInstance3D] = _showing_in(view_model)
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
		var showing: Array[MeshInstance3D] = _showing_in(view_model)
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
				# Measured off the mesh's own box, because all three cylinders on the
				# belt are modelled now rather than a [CylinderMesh] — see
				# [ToolModel], which fits one into exactly this box. The box is the
				# question worth asking of both: it is what the clearances further down
				# are measured against, and a [CylinderMesh] of this extent fills it
				# exactly.
				var barrel: AABB = proxy.get_aabb()
				assert_almost_eq(barrel.size.y, tool.extent.y, TOLERANCE, tool.display_name)
				assert_almost_eq(barrel.size.x, tool.extent.x, TOLERANCE, "x is a width")
				assert_almost_eq(barrel.size.z, tool.extent.z, TOLERANCE, "z is a depth")
				if not tool.model.is_empty():
					continue
				# And a tool with no model is still built from the primitive the
				# catalogue names, rather than from whatever else happens to fit the box.
				var cylinder: CylinderMesh = proxy.mesh as CylinderMesh
				assert_not_null(cylinder, "%s is a cylinder" % tool.display_name)
				if cylinder == null:
					continue
				assert_almost_eq(cylinder.height, tool.extent.y, TOLERANCE, tool.display_name)
				assert_almost_eq(
					cylinder.top_radius, tool.extent.x * 0.5, TOLERANCE, "x is a width"
				)
			DetailingTool.Shape.BOX:
				# Measured off the mesh's own box for the same reason the cylinders
				# are: the sponge is a modelled mesh fitted into this extent rather
				# than a [BoxMesh] of it, and the box is what everything downstream
				# reads either way.
				var solid: AABB = proxy.get_aabb()
				assert_almost_eq(solid.size.x, tool.extent.x, TOLERANCE, "x is a width")
				assert_almost_eq(solid.size.y, tool.extent.y, TOLERANCE, "y is a thickness")
				assert_almost_eq(solid.size.z, tool.extent.z, TOLERANCE, "z is a depth")
				if not tool.model.is_empty():
					continue
				var box: BoxMesh = proxy.mesh as BoxMesh
				assert_not_null(box, "%s is a box" % tool.display_name)
				if box == null:
					continue
				assert_almost_eq(
					box.size.distance_to(tool.extent), 0.0, TOLERANCE, "all three axes"
				)
			DetailingTool.Shape.PLANE:
				# Measured off the mesh's own box rather than off a [PlaneMesh]'s own
				# `size`, because the rag is a [ClothRag] and builds its geometry point
				# by point — see that class on why it is still exactly the rectangle
				# the catalogue asked for. A box is the honest question to ask of a
				# mesh that could have been built any shape at all.
				var flat: AABB = proxy.get_aabb()
				assert_almost_eq(flat.size.x, tool.extent.x, TOLERANCE, "x is a width")
				assert_almost_eq(flat.size.z, tool.extent.z, TOLERANCE, "z is a depth")
				assert_almost_eq(flat.size.y, 0.0, TOLERANCE, "and a cloth at rest is flat")


func test_every_proxy_wears_the_catalogues_surface() -> void:
	for tool: DetailingTool in DetailingTool.catalogue():
		if not tool.model.is_empty():
			continue
		var material: StandardMaterial3D = _material(_view_model().proxy_for(tool.id))
		assert_not_null(material, "%s needs a material of its own" % tool.display_name)
		if material == null:
			continue
		assert_eq(material.albedo_color, tool.albedo, "%s: colour" % tool.display_name)
		assert_almost_eq(material.metallic, tool.metallic, TOLERANCE, tool.display_name)
		assert_almost_eq(material.roughness, tool.roughness, TOLERANCE, tool.display_name)


func test_a_modelled_tool_wears_its_own_skin_instead() -> void:
	# The one thing a modelled tool does not take from the catalogue. An override
	# is what [method ViewModel._build] would otherwise paint on, and painting a
	# flat catalogue colour over a texture is throwing away the entire reason the
	# bottle was modelled. Asserted from both sides: no override, and a real
	# texture underneath where the override would have been.
	for tool: DetailingTool in DetailingTool.catalogue():
		if tool.model.is_empty():
			continue
		var proxy: MeshInstance3D = _view_model().proxy_for(tool.id)
		assert_null(_material(proxy), "%s must not be painted over" % tool.display_name)
		var skin: StandardMaterial3D = proxy.mesh.surface_get_material(0) as StandardMaterial3D
		assert_not_null(skin, "%s: the import's own material" % tool.display_name)
		if skin == null:
			continue
		assert_not_null(skin.albedo_texture, "%s: and its texture" % tool.display_name)


func test_the_power_wash_is_the_only_metal_on_the_belt() -> void:
	# Silver is a material, not a colour: at metallic 0 the same grey cylinder is
	# light plastic. The room's red toolboxes sit at 0.2, so "more than that" is
	# the bar for the wand, and everything else on the belt is a bottle or a rag
	# and has to stay under it.
	#
	# Under it rather than at zero, and measured through the map rather than off
	# the property, because a modelled tool's metalness is not one number any more
	# — see [method _metallic_of]. The worst surface of each tool, so a metal cap
	# on an otherwise plastic bottle is caught.
	for tool: DetailingTool in DetailingTool.catalogue():
		var metallic: float = 0.0
		for skin: StandardMaterial3D in _paintings(_view_model().proxy_for(tool.id)):
			metallic = maxf(metallic, _metallic_of(skin))
		if tool.id == DetailingTool.Id.POWER_WASH:
			assert_gt(metallic, 0.5, "the wand has to read as metal")
		else:
			assert_lt(metallic, NOT_METAL, "%s is not metal" % tool.display_name)


# ---- the rag, which has one side --------------------------------------------


func test_the_rag_is_double_sided() -> void:
	# Without this, the rag is invisible from behind — and "behind" is decided by
	# an angle nobody will remember is load-bearing the next time it is retuned.
	var rag: MeshInstance3D = _view_model().proxy_for(DetailingTool.Id.DRYING_RAG)
	var cull: BaseMaterial3D.CullMode = _material(rag).cull_mode
	assert_eq(cull, BaseMaterial3D.CULL_DISABLED, "a cloth has no back to cull")


func test_the_rag_is_made_of_cloth_rather_than_painted_one_colour() -> void:
	# The pair of it: [ClothRag] makes the rag move like a sheet and [Microfiber]
	# makes it made of something. Asserted here because this is where the two meet
	# — a rag that quietly went back to a flat [StandardMaterial3D] would pass every
	# other test in this file, colour, roughness and all, and would be a blue card
	# again. What the weave itself is, is tests/unit/test_microfiber.gd's.
	var rag: MeshInstance3D = _view_model().proxy_for(DetailingTool.Id.DRYING_RAG)
	assert_true(rag is ClothRag, "the rag is a simulated sheet")
	assert_true(_material(rag) is Microfiber, "and it is woven rather than painted")


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


# ---- the two ends of the wand ------------------------------------------------


func test_the_power_wash_carries_a_marker_at_each_of_its_ends() -> void:
	# What the jet will hang off, and what the alignment is measured between. Found
	# through the viewmodel's own accessors rather than by node path, so a test is
	# not the thing that decides what they are called.
	var view_model: ViewModel = _view_model()
	assert_not_null(view_model.muzzle(), "the wand has an end the water comes out of")
	assert_not_null(view_model.butt(), "and one the hose goes into")


func test_the_markers_sit_at_the_two_ends_of_the_wand_and_nowhere_else() -> void:
	# Half a wand either side of its middle, measured off the mesh's own box rather
	# than off the catalogue — a marker parked at the centre would satisfy "there
	# are two nodes" and quietly emit the water out of the middle of the barrel.
	var wand: MeshInstance3D = _view_model().proxy_for(DetailingTool.Id.POWER_WASH)
	var half: float = wand.get_aabb().size.y * 0.5
	assert_almost_eq(_view_model().muzzle().position.distance_to(Vector3.ZERO), half, TOLERANCE)
	assert_almost_eq(_view_model().butt().position.distance_to(Vector3.ZERO), half, TOLERANCE)
	assert_almost_eq(
		_view_model().muzzle().position.distance_to(_view_model().butt().position),
		half * 2.0,
		TOLERANCE,
		"and at opposite ends rather than both at the same one"
	)


func test_the_muzzle_faces_out_of_the_nozzle() -> void:
	# A [GPUParticles3D] emits down its own -Z, and a [CylinderMesh] is built along
	# +Y — so a marker that inherited the mesh's rotation unturned would spray the
	# water out of the side of the wand. Asserted as the direction from one end to
	# the other, which is the wand itself and not a basis this test could get wrong
	# in the same way the code did.
	var muzzle: Marker3D = _view_model().muzzle()
	var along: Vector3 = _view_model().butt().global_position.direction_to(muzzle.global_position)
	assert_almost_eq(-muzzle.global_basis.z.normalized().dot(along), 1.0, TOLERANCE)


func test_only_the_tools_that_spray_have_grown_ends() -> void:
	# Ends are for emitting something out of, so the three tools that emit have
	# them and the two that are pressed against the paint do not. A sponge with a
	# muzzle would be the first sign that "the tools that spray" had quietly become
	# "all of them", and the room would then be spraying suds out of the middle of
	# a block of foam.
	for tool: DetailingTool in DetailingTool.catalogue():
		var proxy: MeshInstance3D = _view_model().proxy_for(tool.id)
		var sprays: bool = tool.shape == DetailingTool.Shape.CYLINDER
		assert_eq(
			proxy.get_child_count(),
			2 if sprays else 0,
			"%s has the wrong number of ends" % tool.display_name
		)
		assert_eq(
			_view_model().muzzle_of(tool.id) != null,
			sprays,
			"%s: a nozzle the room can stand an effect on" % tool.display_name
		)


func test_every_nozzle_sits_at_the_far_end_of_its_own_tool() -> void:
	# The same rule the wand's own markers keep, now that two more tools carry
	# them: half a bottle from its middle, measured off the mesh's box rather than
	# off the catalogue, so a marker parked at the centre would fail rather than
	# quietly emit product out of the side of the can.
	for tool: DetailingTool in DetailingTool.catalogue():
		if tool.shape != DetailingTool.Shape.CYLINDER:
			continue
		var proxy: MeshInstance3D = _view_model().proxy_for(tool.id)
		var half: float = proxy.get_aabb().size.y * 0.5
		var nozzle: Marker3D = _view_model().muzzle_of(tool.id)
		assert_almost_eq(
			nozzle.position.distance_to(Vector3.ZERO), half, TOLERANCE, tool.display_name
		)
		# A [GPUParticles3D] emits down its own -Z and a [CylinderMesh] is built along
		# +Y, so a marker that inherited the mesh's rotation unturned would spray out
		# of the side. Asserted per tool now rather than for the wand alone.
		assert_almost_eq(
			-nozzle.global_basis.z.normalized().dot(proxy.global_basis.y.normalized()),
			1.0,
			TOLERANCE,
			"%s: the nozzle faces out of the tool" % tool.display_name
		)


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


func test_no_proxy_leaves_the_ground() -> void:
	# The other geometry that could swallow a held tool. Read off the ground rather
	# than written down again, so it keeps meaning "the ground" if the ground
	# changes — which it has: three scaled boxes became one modeled driveway, and
	# this line is the whole of what that cost here.
	var box: AABB = (_garage.get_node("%Ground") as Ground).extent()
	var half_width: float = minf(absf(box.position.x), box.end.x)
	for tool: DetailingTool in DetailingTool.catalogue():
		for corner: Vector3 in _world_corners(_view_model().proxy_for(tool.id)):
			assert_lt(
				absf(corner.x), half_width, "%s is off the edge of the ground" % tool.display_name
			)
			assert_gt(corner.y, 0.0, "%s is in the floor" % tool.display_name)
