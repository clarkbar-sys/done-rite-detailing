## Integration test for the car — the CSG blockout that replaced the green box.
##
## Under tests/integration/ because every assertion here needs a frame to have
## happened: CSG meshes are built deferred, so a panel has no [AABB] to give
## until the build has run, and every measurement below would otherwise be taken
## against a car that does not exist yet. That is the fact most likely to turn
## this scene into a flaky one somewhere else, so it is stated in `before_each`
## and pinned by its own test rather than left to be rediscovered.
extends GutTest

const CAR: String = "res://src/world/car.tscn"

## Close enough for a blockout: a centimetre. The shape is a design decision
## being asserted, not arithmetic — the tolerances elsewhere are 0.0001 because
## they are checking a formula, and this is checking that a car is car-shaped.
const TOLERANCE: float = 0.01

## What the green box was, and what the room, the camera's standing distance and
## every clearance in the suite were tuned against. The blockout is allowed to be
## any shape it likes inside this; it is not allowed to grow.
const LENGTH: float = 4.3
const WIDTH: float = 1.9
const HEIGHT: float = 1.4

var _car: Car = null


func before_each() -> void:
	var packed: PackedScene = load(CAR) as PackedScene
	assert_not_null(packed, "could not load %s" % CAR)
	if packed == null:
		return
	var car: Car = packed.instantiate() as Car
	_car = car
	add_child_autofree(_car)
	await wait_process_frames(1)


func _panel(named: String) -> Node3D:
	for panel: Node3D in _car.panels():
		if panel.name == named:
			return panel
	return null


## The panel's own box, off its skin — which on this car is the panel itself, and
## on a mesh one would be the [MeshInstance3D] under it. Through [method
## Car.skin_of] rather than off the node, because that is the contract every
## consumer reads a panel's box through and a test that reached past it would go
## on passing after the contract stopped holding.
func _box(named: String) -> AABB:
	return _car.skin_of(_panel(named)).get_aabb()


## The same box, where it actually is in the room.
func _world_box(named: String) -> AABB:
	var skin: GeometryInstance3D = _car.skin_of(_panel(named))
	return skin.global_transform * skin.get_aabb()


func test_the_car_instantiates() -> void:
	assert_not_null(_car, "the car must instantiate as a Car")


func test_the_bounds_are_only_trustworthy_once_a_frame_has_passed() -> void:
	# CSG meshes are built deferred, so a panel has no AABB to give until the
	# build has run. What that is worth asserting is the half that is reliable:
	# one frame after the car enters the tree, the bounds are the car. The other
	# half — that they are empty beforehand — is true of a car instanced into an
	# idle tree and not of one instanced alongside a build that is already
	# flushing, so pinning it here would only produce a test that fails on
	# whichever machine ran the suite in a different order.
	var fresh: Car = (load(CAR) as PackedScene).instantiate() as Car
	add_child_autofree(fresh)
	await wait_process_frames(1)
	assert_almost_eq(fresh.bounds().size.z, LENGTH, TOLERANCE, "a frame later, the car exists")


func test_it_is_made_of_panels_a_detailer_would_name() -> void:
	# The panels are the unit of collision, of the glTF export, and of whatever
	# the grime system ends up storing per surface. Naming them here is what stops
	# a rename in the editor from silently breaking a raycast that asked for
	# "Hood" — the failure would otherwise be a tool that quietly cleans nothing.
	var named: Array[String] = []
	for panel: Node3D in _car.panels():
		named.append(panel.name)
	for expected: String in [
		"Body",
		"Hood",
		"Deck",
		"Roof",
		"Cabin",
		"Windshield",
		"RearGlass",
		"SideGlass",
		"WheelFrontLeft",
		"WheelFrontRight",
		"WheelRearLeft",
		"WheelRearRight",
	]:
		assert_has(named, expected, "the car is missing its %s" % expected)


func test_panels_are_csg_roots_and_not_the_brushes_inside_them() -> void:
	# The distinction Car.panels() exists to make. The cutting boxes that rake the
	# windscreen and shape the arches are CSGShape3Ds too, and they sit metres
	# outside the car — counting one as a panel would give it a collider it must
	# not have and would blow the bounds out to the size of a cutting box.
	for panel: Node3D in _car.panels():
		var parent: CSGShape3D = panel.get_parent() as CSGShape3D
		assert_null(parent, "%s is a brush inside another panel, not a panel" % panel.name)
	assert_gt(_car.get_node("Cabin").get_child_count(), 1, "the cabin is shaped by brushes")


func test_it_still_fits_the_envelope_the_green_box_had() -> void:
	# Everything else in the game was measured against the box this replaced: the
	# camera's standing distance, the standoff, the reach of a held tool, the
	# height fences on the walk. The shape inside is free to change; the envelope
	# is load-bearing, and growing it is how all of those quietly stop being true.
	#
	# Width is the exception and it is deliberate: the wing mirrors reach past the
	# bodywork, the way wing mirrors do.
	var box: AABB = _car.bounds()
	assert_almost_eq(box.size.z, LENGTH, TOLERANCE, "the car must stay 4.3 m long")
	assert_almost_eq(box.size.y, HEIGHT, TOLERANCE, "and 1.4 m tall")
	assert_between(box.size.x, WIDTH, WIDTH + 0.2, "and no wider than its mirrors")


func test_it_sits_on_the_ground_it_is_placed_on() -> void:
	# The origin is the car's mid-height rather than its floor, because the garage
	# aims its camera and casts its standoff ray through this node's own position.
	# Which means "the wheels touch the ground" is a claim about where the bottom
	# of the bounds is relative to the origin, and it is the claim that stops the
	# car from being parked hovering or buried when it is dropped into the room.
	var box: AABB = _car.bounds()
	assert_almost_eq(box.position.y, -HEIGHT * 0.5, TOLERANCE, "the wheels reach the ground")
	assert_almost_eq(box.end.y, HEIGHT * 0.5, TOLERANCE, "and the roof is the top of it")


func test_the_greenhouse_is_narrower_than_the_body() -> void:
	# Tumblehome — the thing that makes a blockout read as a car rather than as a
	# van. Asserted because it is produced by two rotated subtraction brushes whose
	# angle is easy to get backwards, and getting it backwards flares the roof out
	# instead, which looks wrong in a way that is hard to name in a screenshot.
	var cabin: AABB = _box("Cabin")
	var body: AABB = _box("Body")
	assert_lt(cabin.size.x, body.size.x, "the greenhouse must be inset from the flanks")
	assert_lt(cabin.size.z, body.size.z, "and shorter than the car")


func test_the_wheels_are_under_the_arches_and_not_beside_them() -> void:
	# Four separate panels positioned by hand, so a sign error puts a wheel inside
	# the sill or a metre out in the room. Checked against the body's own width
	# rather than a number written here, so it survives the car being reshaped.
	var body: AABB = _world_box("Body")
	var ground: float = _car.bounds().position.y
	for named: String in ["WheelFrontLeft", "WheelFrontRight", "WheelRearLeft", "WheelRearRight"]:
		var box: AABB = _world_box(named)
		assert_almost_eq(box.position.y, ground, TOLERANCE, "%s must reach the floor" % named)
		assert_gt(box.end.y, body.position.y, "%s must reach up into its arch" % named)
		assert_lt(absf(box.get_center().x), body.size.x * 0.5, "%s is tucked in" % named)
		assert_gt(absf(box.get_center().z), 0.9, "%s is at an axle, not amidships" % named)


func test_the_glass_is_not_the_same_material_as_the_paint() -> void:
	# Cheap, and it catches the copy-paste that would otherwise ship a car with a
	# green windscreen. It also matters downstream: the materials are what become
	# separate slots when this is exported for a real mesh to be built from.
	var windshield: CSGBox3D = _panel("Windshield").get_child(0) as CSGBox3D
	var hood: CSGBox3D = _panel("Hood").get_child(0) as CSGBox3D
	assert_not_null(windshield.material, "the windscreen needs a material of its own")
	assert_not_null(hood.material, "and so does the bonnet")
	assert_ne(windshield.material, hood.material, "glass is not paint")


func test_the_car_starts_painted_one_of_the_thirteen_colors() -> void:
	assert_has(
		Car.PAINT_COLORS,
		_car.paint.albedo_color,
		"the car must start in one of the thirteen colours"
	)


func test_every_body_panel_shares_the_cars_paint() -> void:
	# Body, Hood, Deck, Roof and Cabin are five separate CSG roots that all read
	# as "the car's colour" to a detailer. Forcing the colour here and checking
	# every panel that carries it is what catches one of the six being missed,
	# rather than trusting that they all point at the same sub-resource.
	_car.paint.albedo_color = Color(0.5, 0.5, 0.5)
	for path: String in ["Body/Profile", "Body/Plan"]:
		var panel: CSGPolygon3D = _car.get_node(path) as CSGPolygon3D
		assert_eq(panel.material, _car.paint, "%s must be painted the car's colour" % path)
	for path: String in ["Hood/Panel", "Deck/Panel", "Roof/Panel", "Cabin/Shell"]:
		var panel: CSGBox3D = _car.get_node(path) as CSGBox3D
		assert_eq(panel.material, _car.paint, "%s must be painted the car's colour" % path)


func test_each_car_gets_its_own_paint() -> void:
	# The paint material is marked local-to-scene precisely so two cars never
	# share one StandardMaterial3D — without that, repainting one car in the
	# garage would repaint every car ever instantiated, including this test's.
	var other: Car = (load(CAR) as PackedScene).instantiate() as Car
	add_child_autofree(other)
	await wait_process_frames(1)
	other.paint.albedo_color = Color(0.5, 0.5, 0.5)
	assert_ne(
		_car.paint.albedo_color, other.paint.albedo_color, "two cars must not share one paint job"
	)


func test_a_panel_can_be_baked_to_a_real_mesh() -> void:
	# The exit ramp, asserted so it stays one. CSG is the blockout's whole reason
	# for existing and none of it is meant to survive to the finished game; this is
	# the one line that turns a panel into an ArrayMesh a MeshInstance3D can carry,
	# and it is worth knowing the day it stops working rather than the day somebody
	# needs it.
	var baked: ArrayMesh = (_panel("Hood") as CSGShape3D).bake_static_mesh()
	assert_not_null(baked, "a panel must bake down to a real mesh")
	if baked != null:
		assert_gt(baked.get_surface_count(), 0, "and the mesh must have something in it")


# ---- what each panel is made of ------------------------------------------------


func test_the_glass_panels_are_glass() -> void:
	# Read off groups set in `car.tscn` rather than off panel names — see
	# [method Car.kind_of]. What this pins is that the groups are actually on the
	# nodes, which is the half of that arrangement a script cannot check itself.
	for named: String in ["Windshield", "RearGlass", "SideGlass"]:
		var panel: Node3D = _panel(named)
		assert_not_null(panel, "the car has no %s" % named)
		if panel != null:
			assert_eq(_car.kind_of(panel), Surface.Kind.GLASS, named)


func test_the_wheels_are_wheels() -> void:
	for named: String in ["WheelFrontLeft", "WheelFrontRight", "WheelRearLeft", "WheelRearRight"]:
		var panel: Node3D = _panel(named)
		assert_not_null(panel, "the car has no %s" % named)
		if panel != null:
			assert_eq(_car.kind_of(panel), Surface.Kind.WHEEL, named)


func test_everything_else_is_bodywork() -> void:
	# The default, which is what makes adding a panel safe: a new wing gets the
	# sponge without anybody remembering to say so.
	for named: String in ["Body", "Hood", "Deck", "Roof", "Cabin"]:
		var panel: Node3D = _panel(named)
		assert_not_null(panel, "the car has no %s" % named)
		if panel != null:
			assert_eq(_car.kind_of(panel), Surface.Kind.BODY, named)


func test_every_panel_of_the_car_has_a_cleaner_for_it() -> void:
	# The property that matters more than any individual assignment above: there
	# is no panel a player cannot finish because no bottle claims it.
	var belt: ToolBelt = ToolBelt.new()
	for panel: Node3D in _car.panels():
		var cleaner: DetailingTool.Id = Surface.cleaner_for(_car.kind_of(panel))
		assert_true(belt.index_of(cleaner) >= 0, "%s has no cleaner on the belt" % panel.name)


func test_the_real_car_carries_every_kind_the_fixture_stands_in_for() -> void:
	# THE CONTRACT BETWEEN THE FIXTURE AND REALITY, and the reason this file stays
	# on `src/world/car.tscn` while `test_grime.gd` moved off it.
	#
	# The rules of the job are tested against `tests/fixtures/plain_car.tscn`,
	# which has a slab of each kind and always will. That is only safe while the
	# real car also has one of each — the day somebody re-models the glass and the
	# group does not come with it, every test over there goes on passing and the
	# window cleaner stops working in the game. This is what fails instead.
	#
	# By kind and not by name on purpose: renaming a panel is allowed, losing a
	# whole surface is not.
	for kind: Surface.Kind in [Surface.Kind.BODY, Surface.Kind.GLASS, Surface.Kind.WHEEL]:
		var found: int = 0
		for panel: Node3D in _car.panels():
			if _car.kind_of(panel) == kind:
				found += 1
		assert_gt(found, 0, "the real car has no panel of kind %d left" % kind)


# ---- trim: seen, never cleaned -------------------------------------------------


func test_the_trim_is_on_the_car_but_is_not_a_panel() -> void:
	# The whole of what the group buys, in one assertion each way: the nodes are
	# really there in the scene, and Car.panels() really does not report them.
	# Asserting only the second half would pass just as well on a car that had
	# lost its underside altogether.
	var named: Array[String] = []
	for panel: Node3D in _car.panels():
		named.append(panel.name)
	for trim: String in ["Undercarriage", "WheelWells"]:
		assert_not_null(_car.get_node_or_null(NodePath(trim)), "the car has no %s" % trim)
		assert_does_not_have(named, trim, "%s is trim and must not be a panel" % trim)


func test_marking_a_node_trim_covers_everything_under_it() -> void:
	# The property that lets `car.tscn` put the group on two combiners instead of
	# on sixteen brushes. Built here rather than read off the car, because what is
	# being pinned is _gather's behaviour and not the scene's current shape: a
	# plain Node3D holding CSG is a grouping somebody could add in the editor
	# tomorrow, and it has to be coverable by one group too.
	var before: int = _car.panels().size()
	var holder: Node3D = Node3D.new()
	holder.add_to_group(Car.TRIM_GROUP)
	var shape: CSGBox3D = CSGBox3D.new()
	holder.add_child(shape)
	_car.add_child(holder)
	assert_eq(_car.panels().size(), before, "a trim node hides its children as well as itself")
	holder.queue_free()


func test_the_trim_has_no_collider_for_a_tool_to_find() -> void:
	# Every panel sets use_collision because a panel is a thing a tool has to be
	# able to hit. Trim is the exact opposite and the flag is how it says so — a
	# collider here would let the jet find the exhaust and then have nothing to do
	# about it, since nothing downstream will give it a map.
	for trim: String in ["Undercarriage", "WheelWells"]:
		var node: CSGShape3D = _car.get_node_or_null(NodePath(trim)) as CSGShape3D
		assert_not_null(node, "the car has no %s" % trim)
		if node != null:
			assert_false(node.use_collision, "%s must not be something a tool can hit" % trim)


func test_the_trim_stays_inside_the_car_the_rest_of_the_game_measured() -> void:
	# Car.bounds() is built from panels(), so it cannot see any of this — which
	# means trim is the one geometry on the car that can grow past the envelope
	# without a single existing test noticing. The camera's standoff and the
	# walk's clearances are all cut against that envelope. So it is checked here,
	# explicitly, rather than left to the test above that only measures panels.
	var envelope: AABB = _car.bounds()
	for trim: String in ["Undercarriage", "WheelWells"]:
		var node: CSGShape3D = _car.get_node_or_null(NodePath(trim)) as CSGShape3D
		assert_not_null(node, "the car has no %s" % trim)
		if node != null:
			var box: AABB = node.global_transform * node.get_aabb()
			assert_true(envelope.encloses(box), "%s pokes out past the bodywork" % trim)


func test_the_grime_does_not_lay_on_the_trim() -> void:
	# The end the group exists for, asserted at the far end of the chain rather
	# than at Car.panels() where it is arranged. Grime takes panels() as the whole
	# of the car, so this is what "can never be cleaned" actually cashes out to:
	# no map, and so no overlay, and so nothing for a tool to take off.
	var grime: Grime = Grime.new()
	add_child_autofree(grime)
	grime.lay_on(_car)
	for trim: String in ["Undercarriage", "WheelWells"]:
		var node: Node = _car.get_node_or_null(NodePath(trim))
		assert_not_null(node, "the car has no %s" % trim)
		if node != null:
			assert_null(grime.map_of(node), "%s must have no grime map" % trim)


func test_something_that_is_not_a_panel_is_treated_as_bodywork() -> void:
	# The caller is [method Garage._spend_the_trigger], holding whatever a raycast
	# handed back. A null there should pick a tool nobody can use on it, not crash
	# a physics tick.
	assert_eq(_car.kind_of(null), Surface.Kind.BODY)
