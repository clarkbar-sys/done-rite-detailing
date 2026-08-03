## Integration test for the [Grove] — the trees around the edge of the lawn, and
## the promises the room makes about where they are allowed to be.
##
## Under tests/integration/ because a tree is only a tree once `_ready()` has run
## and turned a [TreeShape] into nodes. The roll itself is
## [code]tests/unit/test_tree_shape.gd[/code] and a row is
## [code]tests/unit/test_grove_plan.gd[/code]; neither is repeated here.
##
## What is here is the join between the wood and the driveway, and it is checked
## against the driveway rather than against numbers copied out of it: the grass
## says how big the lawn is, the garage says how far the camera swings, and both
## halves of the arrangement go red if either one moves.
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
	var garage: Garage = packed.instantiate() as Garage
	_garage = garage
	add_child_autofree(_garage)
	await wait_process_frames(1)


func _grove() -> Grove:
	return _garage.get_node("View/World/Ground/Grove") as Grove


## The strip of grass on the right, which is the one the numbers are read off —
## the left is its mirror image and the scene file is what says so.
func _grass() -> Node3D:
	return _garage.get_node("View/World/Ground/GrassRight") as Node3D


## How many trees the grove was asked for: one row down each long side, and one
## across each of the four ends.
func _wanted() -> int:
	return 2 * _grove().trees_per_edge + 4 * _grove().trees_per_end


func test_the_driveway_has_a_wood_on_it() -> void:
	assert_not_null(_grove(), "the garage needs a grove under its ground")
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


func test_the_trunk_stands_on_the_grass() -> void:
	# A cylinder is authored about its own middle, so a trunk is raised by half
	# its height. Getting that wrong buries every tree to the waist, and it is
	# the kind of thing that looks fine from the one angle you checked.
	for tree: Node3D in _grove().trees():
		var trunk: MeshInstance3D = tree.get_node(Grove.TRUNK) as MeshInstance3D
		var foot: float = trunk.global_position.y - trunk.scale.y * 0.5
		assert_almost_eq(foot, 0.0, TOLERANCE, "a trunk that does not meet the ground")


func test_every_tree_is_planted_on_grass() -> void:
	# Read off the grass rather than written down again: the strip runs from its
	# own middle out by half its width, and a trunk has to be inside that. This
	# is the test that fails if the lawn is narrowed without moving the rows in.
	var grass: Node3D = _grass()
	var inner: float = grass.position.x - grass.scale.x * 0.5
	var outer: float = grass.position.x + grass.scale.x * 0.5
	var along: float = grass.scale.z * 0.5
	for tree: Node3D in _grove().trees():
		var across: float = absf(tree.position.x)
		assert_between(across, inner, outer, "a tree standing off the grass")
		assert_between(tree.position.z, -along, along, "a tree past the end of the grass")


func test_the_long_sides_are_planted_the_whole_way_down() -> void:
	# The thing the wider lawn bought. When the grass stopped at 6.2 m the disc
	# the camera sweeps ate the middle of both long edges and the trees could
	# only go at the corners; now each side is a row from one end to the other,
	# so a tree stands level with the car as well as behind and in front of it.
	var abreast: int = 0
	var behind: int = 0
	var ahead: int = 0
	for tree: Node3D in _grove().trees():
		if absf(tree.position.x) < _grove().edge_x - 1.0:
			continue  # an end row; this test is about the two long sides
		if absf(tree.position.z) < 2.0:
			abreast += 1
		elif tree.position.z < 0.0:
			behind += 1
		else:
			ahead += 1
	assert_gt(abreast, 0, "nothing planted level with the car")
	assert_gt(behind, 0, "nothing planted down the near end")
	assert_gt(ahead, 0, "nothing planted down the far end")


func test_the_ends_of_the_lawn_are_planted_too() -> void:
	# The four short rows that close the boundary off. They are the ones the disc
	# still bites into, so as well as being planted at all, the corner nearest
	# the car has to be the bit left bare.
	var ends: int = 0
	for tree: Node3D in _grove().trees():
		if absf(tree.position.x) >= _grove().edge_x - 1.0:
			continue  # a long row
		ends += 1
		assert_almost_eq(
			absf(tree.position.z),
			_grove().z_limit,
			GrovePlan.WOBBLE_ACROSS + TOLERANCE,
			"an end row that wandered off its line"
		)
		assert_gt(absf(tree.position.x), _grove().inner_x, "a tree planted next to the tarmac")
	assert_eq(ends, 4 * _grove().trees_per_end, "one row across each end of each lawn")


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
	for tree: Node3D in _grove().trees():
		var flat: float = Vector2(tree.position.x, tree.position.z).length()
		var leaf: float = flat - TreeShape.MAX_REACH - _garage.orbit_radius
		assert_gte(leaf, Grove.MARGIN, "a tree %.2f m into the camera's circle" % -leaf)


func test_no_two_trees_are_planted_in_each_other() -> void:
	# Spacing inside a row is GrovePlan's slots, and that is a unit test. What
	# only exists once the whole wood is stood up is spacing *between* rows —
	# specifically at the four corners, where a long side and an end run past
	# each other and Grove.CORNER_GAP is what keeps them apart.
	var standing: Array[Node3D] = _grove().trees()
	for tree: int in standing.size():
		for other: int in range(tree + 1, standing.size()):
			var gap: float = standing[tree].position.distance_to(standing[other].position)
			assert_gt(gap, 1.0, "two trees %.2f m apart, and a crown reaches 1 m" % gap)


func test_nothing_in_the_wood_is_something_a_ray_can_hit() -> void:
	# Trees are scenery. The room casts rays for the camera's standoff and for
	# the aim mark, and both are questions about the car — a collider out here
	# would let a finger on the horizon mark a trunk, and would give the walk
	# something to hug that is not paint.
	for tree: Node3D in _grove().trees():
		for part: Node in tree.get_children():
			assert_null(part as CollisionObject3D, "a tree grew a collider")


func test_the_wood_is_the_same_wood_every_load() -> void:
	# Fixed seeds, checked the only way that means anything: build a second
	# grove from the same scene and stand it beside the first.
	var packed: PackedScene = load(GROVE) as PackedScene
	assert_not_null(packed, "could not load %s" % GROVE)
	if packed == null:
		return
	var again: Grove = packed.instantiate() as Grove
	add_child_autofree(again)
	await wait_process_frames(1)
	var planted: Array[Node3D] = _grove().trees()
	var replanted: Array[Node3D] = again.trees()
	assert_eq(replanted.size(), planted.size(), "the same number of trees")
	for tree: int in planted.size():
		assert_almost_eq(
			replanted[tree].transform.origin,
			planted[tree].transform.origin,
			Vector3.ONE * TOLERANCE,
			"tree %d moved between loads" % tree
		)


func test_replanting_a_bigger_wood_keeps_every_promise() -> void:
	# The rules are meant to hold for the arrangement rather than for the
	# fourteen trees that ship. Twenty-two is more than TreeShape.SEEDS has twice
	# over, so this also exercises the wrap that lets a shape be planted again.
	var grove: Grove = _grove()
	grove.trees_per_edge = 9
	grove.trees_per_end = 1
	grove.plant()
	# A frame, so the wood it replaced is actually gone rather than queued —
	# without it the felled trees are still alive at the end of the test and GUT
	# reports them as orphans.
	await wait_process_frames(1)
	assert_eq(grove.trees().size(), _wanted(), "twenty-two asked for, twenty-two planted")
	for tree: Node3D in grove.trees():
		var flat: float = Vector2(tree.position.x, tree.position.z).length()
		var leaf: float = flat - TreeShape.MAX_REACH - _garage.orbit_radius
		assert_gte(leaf, Grove.MARGIN, "a tree %.2f m into the camera's circle" % -leaf)
