## Integration test for the panel contract — what [method Car.panels] promises
## about what it hands back, held by a car with no CSG anywhere in it.
##
## [b]Why this file exists at all.[/b] Everything about a panel used to be true
## by accident: a [CSGShape3D] is geometry [i]and[/i] its own collider, so one
## node answered all four of the things the game does with a panel and the whole
## chain could be typed [CSGShape3D] without anybody deciding it should be.
## [code]src/world/car.gd[/code]'s class docs list those four and take the
## decision. This is the part that cannot be taken in a doc comment: a panel
## rooted in a [StaticBody3D] with a [MeshInstance3D] under it — which is what
## every car built from [code]assets/models/cars/*.glb[/code] will be — going
## through [method Car.panels], [method Car.kind_of], [method Car.bounds], a
## raycast and [Grime] with nothing changed anywhere to let it.
##
## On [code]tests/fixtures/mesh_car.tscn[/code], whose own header has the shape
## and why its glass sits at an offset inside its body. Nothing here depends on
## the car pack: the fixture is four boxes.
##
## [b]And there is no [code]await[/code] in [method before_each][/b], which is
## the one thing in this file that is an assertion rather than a convenience.
## Every other suite that measures a car waits a frame first, because CSG meshes
## are built deferred — and that is CSG's tax and not the contract's. A mesh
## panel has its box the moment it is in the tree, and the two tests below that
## measure one on arrival are what pins that claim.
extends GutTest

const MESH_CAR: String = "res://tests/fixtures/mesh_car.tscn"

## The CSG fixture, here for one test: the blockout has to keep satisfying the
## widened contract without a line of its scene file changing.
const CSG_CAR: String = "res://tests/fixtures/plain_car.tscn"

## Positions in metres — a tenth of a millimetre. The fixture is authored at round
## numbers precisely so these can be exact.
const TOLERANCE: float = 0.0001

## What the fixture is, in one place: every panel it has, and nothing else.
const PANELS: Array[String] = ["Body", "Glass", "Optics", "Wheel1"]

var _car: Car = null


func before_each() -> void:
	var packed: PackedScene = load(MESH_CAR) as PackedScene
	assert_not_null(packed, "could not load %s" % MESH_CAR)
	if packed == null:
		return
	# Into a typed local first: GUT's add_child_autofree is untyped.
	var car: Car = packed.instantiate() as Car
	_car = car
	add_child_autofree(_car)


func _panel(named: String) -> Node3D:
	for panel: Node3D in _car.panels():
		if String(panel.name) == named:
			return panel
	return null


func _names() -> Array[String]:
	var names: Array[String] = []
	for panel: Node3D in _car.panels():
		names.append(String(panel.name))
	return names


## The grime, laid on this car with no frame waited first — see the class docs.
func _grime_on_it() -> Grime:
	var grime: Grime = Grime.new()
	add_child_autofree(grime)
	grime.lay_on(_car)
	return grime


# ---- which nodes are panels ---------------------------------------------------


func test_a_body_with_a_mesh_under_it_is_a_panel() -> void:
	# The whole widening, in one assertion. Before it, a car made of meshes had no
	# panels at all: `panels()` collected CSGShape3Ds, and a StaticBody3D is not
	# one, so this car would have been an empty list and a silently unwashable car.
	var names: Array[String] = _names()
	for expected: String in PANELS:
		assert_has(names, expected, "the car is missing its %s" % expected)
	assert_eq(_car.panels().size(), PANELS.size(), "and nothing else is a panel")


func test_the_mesh_and_the_collider_inside_a_panel_are_not_panels_of_their_own() -> void:
	# The recursion has to stop at the panel, exactly as it stops at a CSG root
	# rather than descending into the brushes that shape it. A mesh counted as a
	# panel of its own would give the car two maps for one piece of glass and hand
	# the second one to a node no raycast can ever return.
	var names: Array[String] = _names()
	for inside: String in ["BodyMesh", "BodyShape", "GlassMesh", "GlassShape"]:
		assert_does_not_have(names, inside, "%s is part of a panel, not a panel" % inside)


func test_a_collider_with_no_geometry_under_it_is_not_a_panel() -> void:
	# The half of the test in `panels()` that is about geometry. A bare body is a
	# perfectly good thing to have in a car scene — a towbar nobody models, a
	# trigger volume — and it has no box to size a map from and nowhere to hang an
	# overlay, so handing it to Grime would be a crash rather than a panel.
	var before: int = _car.panels().size()
	var bare: StaticBody3D = StaticBody3D.new()
	bare.name = "Towbar"
	_car.add_child(bare)
	assert_eq(_car.panels().size(), before, "a body with nothing to paint is not a panel")
	bare.queue_free()


func test_geometry_with_no_collider_is_not_a_panel_either() -> void:
	# And the half that is about physics. A loose MeshInstance3D is what a glTF
	# import gives you before anybody puts a body round it; counting it would put a
	# panel in the running order that no tool could ever hit, so the demo would
	# walk the eye round to something the player cannot work on.
	var before: int = _car.panels().size()
	var loose: MeshInstance3D = MeshInstance3D.new()
	loose.name = "Badge"
	loose.mesh = BoxMesh.new()
	_car.add_child(loose)
	assert_eq(_car.panels().size(), before, "geometry a ray cannot find is not a panel")
	loose.queue_free()


func test_the_trim_group_hides_a_mesh_panel_the_same_way() -> void:
	# The group has to keep working on a shape it was not written for. The
	# fixture's trim is a panel in every respect except the group, so this fails if
	# the exclusion ever ends up keyed on anything else.
	assert_not_null(_car.get_node_or_null(^"Undertray"), "the fixture has no trim")
	assert_does_not_have(_names(), "Undertray", "trim must not be a panel")


# ---- the skin: where the box and the overlay actually are ----------------------


func test_the_skin_of_a_mesh_panel_is_the_mesh_under_it() -> void:
	# Point 1 and point 2 of the contract, on the node that carries them. The
	# lookup is by shape and not by name — an importer names the mesh whatever it
	# likes — which is why the fixture's are named after their panels rather than
	# uniformly, so a `get_node("Mesh")` would not pass this.
	for named: String in PANELS:
		var skin: GeometryInstance3D = _car.skin_of(_panel(named))
		assert_not_null(skin, "%s has no skin" % named)
		if skin != null:
			assert_true(skin is MeshInstance3D, "%s's skin must be its mesh" % named)
			assert_eq(skin.get_parent(), _panel(named), "%s's skin sits inside it" % named)


func test_the_skin_of_a_csg_panel_is_the_panel_itself() -> void:
	# The blockout keeps satisfying the widened contract unchanged — which is the
	# claim the whole rest of the suite is leaning on, since every other test in
	# this repo still runs on a CSG car. Identity, not a special case: a CSGShape3D
	# is a GeometryInstance3D, so there is nothing to look up.
	var csg: Car = (load(CSG_CAR) as PackedScene).instantiate() as Car
	add_child_autofree(csg)
	assert_gt(csg.panels().size(), 0, "the CSG fixture has no panels")
	for panel: Node3D in csg.panels():
		assert_eq(csg.skin_of(panel), panel, "%s is its own skin" % panel.name)


func test_what_a_panel_is_made_of_is_read_off_the_root_a_ray_hands_back() -> void:
	# Point 3 and point 4 have to be true of the same node or a hit cannot be
	# named: the ray comes back holding the body, so the body is what carries the
	# group. Optics is in the glass group under a name that is not "glass", which
	# is the half of Car.kind_of a fixture with one window cannot demonstrate.
	assert_eq(_car.kind_of(_panel("Body")), Surface.Kind.BODY, "Body")
	assert_eq(_car.kind_of(_panel("Glass")), Surface.Kind.GLASS, "Glass")
	assert_eq(_car.kind_of(_panel("Optics")), Surface.Kind.GLASS, "Optics")
	assert_eq(_car.kind_of(_panel("Wheel1")), Surface.Kind.WHEEL, "Wheel1")
	# And explicitly not on the skin, so this cannot pass by the group having been
	# put on both. A mesh a ray cannot return is not somewhere a group can live.
	assert_false(
		_car.skin_of(_panel("Glass")).is_in_group(Surface.GLASS_GROUP),
		"the group belongs on the node the raycast answers with"
	)


# ---- measuring one, on the frame it arrives -----------------------------------


func test_the_bounds_are_exact_without_waiting_a_frame() -> void:
	# No await anywhere above this line — see the class docs. It is also the
	# sharpest test of "the transform comes off the same node the box did": the
	# glass's mesh sits a metre above the body that carries it, so a bounds built
	# from the skin's box and the root's transform stops a metre short.
	var box: AABB = _car.bounds()
	assert_almost_eq(box.end.y, 3.5, TOLERANCE, "the glass's skin is a metre above its body")
	assert_almost_eq(box.position.y, -2.5, TOLERANCE, "and the wheel is the bottom of the car")
	assert_almost_eq(box.position.x, -1.0, TOLERANCE, "the tub is the widest thing on it")
	assert_almost_eq(box.end.z, 2.7, TOLERANCE, "and the lamps are the front of it")


func test_the_trim_is_outside_the_bounds_it_is_not_part_of() -> void:
	# Trim is the one geometry on a car that can grow past the envelope without
	# anything noticing, because bounds() is built from panels(). The fixture's
	# undertray hangs below the wheel on purpose, so this fails loudly if trim ever
	# starts being collected rather than quietly returning a slightly bigger car.
	assert_lt(_car.bounds().position.y, 0.0, "the fixture's bounds go below the origin")
	assert_almost_eq(_car.bounds().position.y, -2.5, TOLERANCE, "the undertray is not in them")


# ---- point 4: what a ray comes back holding -----------------------------------


func test_a_ray_is_handed_the_panel_itself_and_not_a_mesh_or_an_anonymous_body() -> void:
	# The point the whole two-node arrangement exists for. `intersect_ray` answers
	# with a CollisionObject3D, so the panel has to *be* one — and what makes this
	# a test rather than a tautology is that it is checked against `panels()`
	# rather than against a type: the hit has to be a member of the very list Grime
	# keyed its maps on, or a tool would land on the car and find nothing to clean.
	await wait_physics_frames(1)
	var focus: Vector3 = _car.global_position
	var probe: Vector3 = focus + Vector3(5.0, 0.0, 0.0)
	var space: PhysicsDirectSpaceState3D = _car.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(probe, focus))
	assert_false(hit.is_empty(), "a ray at the car's mid-height must find the car")
	if hit.is_empty():
		return
	var struck: Object = hit["collider"]
	var panel: Node3D = struck as Node3D
	assert_not_null(panel, "what a ray hits must be a node in the room")
	assert_true(_car.panels().has(panel), "what a ray hits must be a panel of the car")
	if panel != null:
		assert_eq(panel.name, &"Body", "level at mid-height, side on, the ray meets the tub")


# ---- and the grime, which is what all of it is for ----------------------------


func test_the_grime_lays_on_a_car_with_no_csg_in_it() -> void:
	# End to end, and on the frame the car arrived: a map per panel, keyed on the
	# node a raycast answers with, sized from the node the geometry is on.
	var grime: Grime = _grime_on_it()
	assert_true(grime.is_laid(), "no grime was laid at all")
	assert_eq(grime.panels().size(), PANELS.size(), "one map per panel, no more and no less")
	for panel: Node3D in _car.panels():
		var map: GrimeMap = grime.map_of(panel)
		assert_not_null(map, "%s has no map" % panel.name)
		if map == null:
			continue
		assert_gt(map.box().size.length(), 0.0, "%s got a zero-sized map" % panel.name)
		assert_eq(
			map.box(), _car.skin_of(panel).get_aabb(), "%s's map is not its own box" % panel.name
		)
	assert_almost_eq(grime.remaining(), 1.0, TOLERANCE, "a fresh car is entirely filthy")


func test_the_overlay_goes_on_the_skin_because_that_is_where_a_material_can_go() -> void:
	# A StaticBody3D has no material_overlay to set — it is not a
	# GeometryInstance3D at all — so a Grime that hung the shader on the node it
	# was handed would silently paint nothing on a mesh car. Checked per panel
	# rather than on one, because it is the loop that would be wrong.
	var grime: Grime = _grime_on_it()
	assert_true(grime.is_laid(), "no grime was laid at all")
	for panel: Node3D in _car.panels():
		var skin: GeometryInstance3D = _car.skin_of(panel)
		assert_not_null(skin.material_overlay, "%s's skin has no grime on it" % panel.name)
		assert_null(skin.material_override, "%s's own material was replaced" % panel.name)


func test_the_trim_gets_no_map_and_so_can_never_be_cleaned() -> void:
	# What the group cashes out to at the far end of the chain: no map, so no
	# overlay, so nothing for a tool to take off — and a hit on it washes nothing
	# rather than erroring, which is what `map_of` returning null is for.
	var grime: Grime = _grime_on_it()
	var trim: Node = _car.get_node_or_null(^"Undertray")
	assert_not_null(trim, "the fixture has no trim")
	assert_null(grime.map_of(trim), "trim must have no grime map")
	assert_eq(grime.wash(trim, Vector3.ZERO, Vector3.UP, 0.2, 1.0), 0, "and nothing to wash")


func test_a_wash_lands_where_the_skin_is_and_not_where_its_body_is() -> void:
	# The conversion in Grime._work, on the panel built to catch it getting this
	# wrong. The glass's mesh sits a metre above the body that carries it, so a hit
	# put through the root's transform lands a metre up the face — clamped to its
	# top edge — and the middle of the face, which is where the player aimed, stays
	# filthy. A side face and not the top, because a face is picked by the normal
	# and only the other two axes are measured: on the top face a Y error would not
	# show at all.
	var grime: Grime = _grime_on_it()
	var glass: Node3D = _panel("Glass")
	var skin: GeometryInstance3D = _car.skin_of(glass)
	var map: GrimeMap = grime.map_of(glass)
	assert_not_null(map, "the glass has no map")
	if map == null:
		return
	var outward: Vector3 = Vector3.BACK
	var middle: Vector3 = Vector3(0.0, 0.0, skin.get_aabb().end.z)
	var before: float = map.mud_at(middle, outward)
	assert_gt(before, 0.0, "the glass started clean, so this test proves nothing")
	grime.wash(glass, skin.global_transform * middle, outward, 0.15, 0.9)
	assert_lt(map.mud_at(middle, outward), before, "the water missed the glass it was aimed at")


func test_a_wash_a_metre_off_the_glass_leaves_it_alone() -> void:
	# The other half, and the reason the first one means anything: aimed where the
	# root's own frame would have put that point — a metre below the glass, in
	# mid-air — the middle of the face does not move.
	var grime: Grime = _grime_on_it()
	var glass: Node3D = _panel("Glass")
	var skin: GeometryInstance3D = _car.skin_of(glass)
	var map: GrimeMap = grime.map_of(glass)
	assert_not_null(map, "the glass has no map")
	if map == null:
		return
	var outward: Vector3 = Vector3.BACK
	var middle: Vector3 = Vector3(0.0, 0.0, skin.get_aabb().end.z)
	var before: float = map.mud_at(middle, outward)
	var below: Vector3 = skin.global_transform * middle - Vector3(0.0, 1.0, 0.0)
	grime.wash(glass, below, outward, 0.15, 0.9)
	assert_almost_eq(map.mud_at(middle, outward), before, TOLERANCE, "the water went wide")


func test_every_panel_of_a_mesh_car_has_a_cleaner_for_it() -> void:
	# The property that matters more than any individual assignment: there is no
	# panel on this shape of car that a player cannot finish because no bottle
	# claims it. Which is the whole point of the widening — the rules of the job
	# have to reach a mesh car with nothing about them changed.
	var belt: ToolBelt = ToolBelt.new()
	for panel: Node3D in _car.panels():
		var cleaner: DetailingTool.Id = Surface.cleaner_for(_car.kind_of(panel))
		assert_true(belt.index_of(cleaner) >= 0, "%s has no cleaner on the belt" % panel.name)
