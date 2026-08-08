## Integration test for the [Grove] — the trees around the driveway, and the
## promises the room makes about where they are allowed to be.
##
## Under tests/integration/ because a tree is only a tree once `_ready()` has run
## and turned a [TreeShape] into nodes, and because every height in it comes off
## the imported mesh through [method Ground.settle]. The roll itself is
## [code]tests/unit/test_tree_shape.gd[/code] and a row is
## [code]tests/unit/test_grove_plan.gd[/code]; neither is repeated here.
##
## What is here is the join between the wood and the driveway, and it is checked
## against the driveway rather than against numbers copied out of it: the ground
## says how high the grass is and how far it reaches, the garage says how far the
## camera swings, and all of it goes red if any one of them moves.
extends GutTest

const GARAGE: String = "res://src/world/garage.tscn"
const GROVE: String = "res://src/world/grove.tscn"

## Close enough for a length in metres — a tenth of a millimetre.
const TOLERANCE: float = 0.0001

var _garage: Garage = null


func before_each() -> void:
	var packed: PackedScene = load(GARAGE) as PackedScene
	assert_not_null(packed, "could not load %s" % GARAGE)
	if packed == null:
		return
	# Into a typed local first, for the reason tests/integration/test_garage.gd
	# gives: add_child_autofree is untyped, and autofree is what stops a failure
	# here being reported as a leak against the next test.
	var garage: Garage = packed.instantiate() as Garage
	_garage = garage
	add_child_autofree(_garage)
	await wait_process_frames(1)


func _grove() -> Grove:
	return _garage.get_node("View/World/Grove") as Grove


func _ground() -> Ground:
	return _garage.get_node("%Ground") as Ground


## How many trees the grove was asked for: one row down each long bank, and one
## across the lawn that closes the far end.
func _wanted() -> int:
	return 2 * _grove().trees_per_side + _grove().trees_across_back


## Every tree's world position, which is what nearly every rule below is about.
func _standing() -> Array[Vector3]:
	var spots: Array[Vector3] = []
	for tree: Node3D in _grove().trees():
		spots.append(tree.global_position)
	return spots


func test_the_driveway_has_a_wood_on_it() -> void:
	assert_not_null(_grove(), "the garage needs a grove beside its ground")
	assert_eq(_grove().trees().size(), _wanted(), "one tree per tree asked for")


func test_a_tree_is_a_trunk_and_a_pile_of_leaves() -> void:
	# The shape of one tree as nodes: the trunk by name, and the rest of the
	# children being the crown. Nothing here says how many spheres, because that
	# is the roll's business.
	var tree: Node3D = _grove().trees()[0]
	var trunk: MeshInstance3D = tree.get_node(Grove.TRUNK) as MeshInstance3D
	assert_not_null(trunk, "a tree needs a trunk")
	assert_not_null(trunk.mesh, "and the trunk needs a mesh on it")
	assert_gte(tree.get_child_count(), TreeShape.CROWN_BLOBS.x + 1, "a trunk and a crown")


func test_every_trunk_stands_on_the_grass_it_was_planted_on() -> void:
	# The one the modeled ground made necessary, and the whole reason
	# Ground.settle() exists. The blockout's lawn was a box with a flat top and
	# every tree could be stood at y = 0; this one climbs to 1.17 m out of the
	# drive and does it unevenly, so a wood planted at any single height has some
	# trees buried to the waist and others hanging in the air. Checked against the
	# ground's own answer rather than against a list of heights, so re-scaling the
	# model moves the trees with it and this stays true.
	#
	# A cylinder is authored about its own middle, so the foot of a trunk is half
	# its height below where the node sits.
	var grass: PackedFloat32Array = _ground().settle(PackedVector3Array(_standing()))
	var trees: Array[Node3D] = _grove().trees()
	for tree: int in trees.size():
		var trunk: MeshInstance3D = trees[tree].get_node(Grove.TRUNK) as MeshInstance3D
		var foot: float = trunk.global_position.y - trunk.scale.y * 0.5
		assert_false(is_nan(grass[tree]), "a tree planted where there is no ground")
		assert_almost_eq(foot, grass[tree], TOLERANCE, "a trunk that does not meet the ground")


func test_every_tree_is_planted_inside_the_modeled_ground() -> void:
	# Read off the ground rather than written down again. The model's outer edge
	# is a hard edge with sky past it — there is no backdrop behind it and nothing
	# under it — so a row that wandered off would put a tree in mid-air, and this
	# is the test that fails if the ground is re-scaled without moving the rows.
	var box: AABB = _ground().extent()
	for spot: Vector3 in _standing():
		assert_between(spot.x, box.position.x, box.end.x, "a tree standing off the ground")
		assert_between(spot.z, box.position.z, box.end.z, "a tree past the end of the ground")


func test_no_crown_can_reach_the_camera_as_it_orbits() -> void:
	# The load-bearing one, and the reason Grove.keep_clear is a number at all.
	# The title screen sweeps a circle of Garage.orbit_radius around the car and
	# the walk holds its standoff inside the same circle, so a crown that came
	# nearer than its own reach to that circle would be leaves across the lens.
	# Both numbers are read off the room, so raising either one fails here rather
	# than in a build.
	assert_gte(
		_grove().keep_clear,
		_garage.orbit_radius + TreeShape.MAX_REACH + Grove.MARGIN,
		"the trees are planted inside the camera's circle"
	)
	for spot: Vector3 in _standing():
		var flat: float = Vector2(spot.x, spot.z).length()
		var leaf: float = flat - TreeShape.MAX_REACH - _garage.orbit_radius
		assert_gte(leaf, Grove.MARGIN, "a tree %.2f m into the camera's circle" % -leaf)


func test_each_long_side_is_planted_at_both_ends_and_bare_in_the_middle() -> void:
	# The shape the model forces on the two long rows, stated as a rule rather
	# than as four coordinates. The banks stand 5.8 m out and the camera's disc is
	# 7.2, so the middle of each side is inside the circle and cannot be planted —
	# what is left is a stretch at either end, and GrovePlan deals the row into
	# both of them rather than putting every tree in whichever it reached first.
	#
	# This is also the test that notices if the model ever grows: a lawn wide
	# enough to clear the disc down its whole length would start planting level
	# with the car, and the "nothing beside the car" line below would go red and
	# want rewriting rather than deleting.
	for side: int in Grove.SIDES:
		var behind: int = 0
		var ahead: int = 0
		for spot: Vector3 in _standing():
			if signf(spot.x) != float(side) or absf(spot.x) < _grove().side_x - 1.0:
				continue  # the back row, or the other bank
			if spot.z < 0.0:
				behind += 1
			else:
				ahead += 1
		assert_gt(behind, 0, "nothing planted down the closed end of one bank")
		assert_gt(ahead, 0, "nothing planted down the open end of one bank")
	for spot: Vector3 in _standing():
		var beside: bool = absf(spot.x) >= _grove().side_x - 1.0 and absf(spot.z) < 2.0
		assert_false(beside, "a tree planted level with the car, where the camera goes")


func test_the_back_row_is_planted_end_to_end() -> void:
	# The one row the disc does not reach — it stands nine metres out and the
	# circle is seven — so unlike the sides it gets every tree it asked for, in
	# one line across the lawn that closes the drive off.
	var back: Array[Vector3] = []
	for spot: Vector3 in _standing():
		if spot.z < _grove().back_z + 1.0:
			back.append(spot)
	assert_eq(back.size(), _grove().trees_across_back, "the back row lost trees to the disc")
	for spot: Vector3 in back:
		assert_almost_eq(
			spot.z,
			_grove().back_z,
			GrovePlan.WOBBLE_ACROSS + TOLERANCE,
			"a back row that wandered off its line"
		)


func test_the_end_the_car_drives_in_from_is_left_open() -> void:
	# Not an accident of where the rows stop — it is the point of the arrangement.
	# The lawn wraps three sides of the pad and the fourth is open in the mesh
	# itself, which is what makes the place read as a driveway rather than as a
	# walled yard. Planting it shut is the one change here a player would notice
	# as wrong, so it is written down as a rule.
	var mouth: float = _ground().extent().end.z
	for spot: Vector3 in _standing():
		assert_lt(spot.z, mouth - 1.0, "a tree planted across the mouth of the drive")


func test_no_two_trees_are_planted_in_each_other() -> void:
	# Spacing inside a row is GrovePlan's slots, and that is a unit test. What
	# only exists once the whole wood is stood up is spacing *between* rows —
	# specifically at the corners, where a long side and the back row run past
	# each other.
	var standing: Array[Vector3] = _standing()
	for tree: int in standing.size():
		for other: int in range(tree + 1, standing.size()):
			var gap: float = standing[tree].distance_to(standing[other])
			assert_gt(gap, 1.0, "two trees %.2f m apart, and a crown reaches 1 m" % gap)


func test_nothing_in_the_wood_is_something_a_ray_can_hit() -> void:
	# Trees are scenery. The room casts rays for the camera's standoff and for
	# the aim mark, and both are questions about the car — a collider out here
	# would let a finger on the horizon mark a trunk, and would give the walk
	# something to hug that is not paint. The same promise Ground is held to in
	# tests/integration/test_ground.gd.
	for tree: Node3D in _grove().trees():
		for part: Node in tree.find_children("*", "", true, false):
			assert_null(part as CollisionObject3D, "a tree grew a collider")
			assert_null(part as CollisionShape3D, "a tree grew a collision shape")


func test_the_wood_does_not_move_the_fence_the_room_is_measured_by() -> void:
	# Why the grove is a sibling of the ground and not a child of it.
	# Ground.extent() is the merged box of every mesh under whatever node it is
	# called on, and five test files read the room's fence off it — so a wood
	# parented in there would add its crowns to the room's own extent and quietly
	# push that fence out past the modeled edge. Measured against the model rather
	# than against a constant: the trees stand up to 1.17 m of bank plus four
	# metres of tree above the ground, so a grove counted into this would be
	# obvious in the height alone.
	var box: AABB = _ground().extent()
	assert_lt(box.end.y, 2.0, "the ground's extent has grown a tree in it")
	for tree: Node3D in _grove().trees():
		assert_false(_ground().is_ancestor_of(tree), "a tree is parented into the ground")


func test_the_wood_is_the_same_wood_every_load() -> void:
	# Fixed seeds, checked the only way that means anything: build a second grove
	# from the same scene and stand it beside the first. It is given the same
	# ground as the one that shipped, because a grove with nothing to stand on
	# plants nothing at all and would pass this by being empty twice.
	var packed: PackedScene = load(GROVE) as PackedScene
	assert_not_null(packed, "could not load %s" % GROVE)
	if packed == null:
		return
	var again: Grove = packed.instantiate() as Grove
	again.ground = NodePath("../Ground")
	_garage.get_node("View/World").add_child(again)
	await wait_process_frames(1)
	var planted: Array[Vector3] = _standing()
	assert_eq(again.trees().size(), planted.size(), "the same number of trees")
	for tree: int in planted.size():
		assert_almost_eq(
			again.trees()[tree].global_position,
			planted[tree],
			Vector3.ONE * TOLERANCE,
			"tree %d moved between loads" % tree
		)


func test_a_wood_with_no_ground_under_it_plants_nothing() -> void:
	# The honest answer to having no measurement, and the same one Ground gives a
	# caller that asks a scene with no concrete in it where the floor is. It
	# matters because the alternative is a wood standing at y = 0 in mid-air over
	# a driveway it never found — which looks like a level rather than like a bug.
	var lost: Grove = (load(GROVE) as PackedScene).instantiate() as Grove
	lost.ground = NodePath("NoSuchNode")
	add_child_autofree(lost)
	await wait_process_frames(1)
	assert_eq(lost.trees().size(), 0, "a grove with no ground planted a wood anyway")


func test_replanting_a_bigger_wood_keeps_every_promise() -> void:
	# The rules are meant to hold for the arrangement rather than for the nine
	# trees that ship. Fifteen is more than TreeShape.SEEDS has twice over, so
	# this also exercises the wrap that lets a shape be planted again.
	var grove: Grove = _grove()
	grove.trees_per_side = 5
	grove.trees_across_back = 5
	grove.plant()
	# A frame, so the wood it replaced is actually gone rather than queued —
	# without it the felled trees are still alive at the end of the test and GUT
	# reports them as orphans.
	await wait_process_frames(1)
	assert_eq(grove.trees().size(), _wanted(), "fifteen asked for, fifteen planted")
	var grass: PackedFloat32Array = _ground().settle(PackedVector3Array(_standing()))
	for tree: int in grove.trees().size():
		var spot: Vector3 = grove.trees()[tree].global_position
		var flat: float = Vector2(spot.x, spot.z).length()
		var leaf: float = flat - TreeShape.MAX_REACH - _garage.orbit_radius
		assert_gte(leaf, Grove.MARGIN, "a tree %.2f m into the camera's circle" % -leaf)
		assert_almost_eq(spot.y, grass[tree], TOLERANCE, "a tree that missed the ground")
