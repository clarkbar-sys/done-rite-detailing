## Unit tests for [TreeShape] — the roll that turns a number into a trunk and a
## crown of spheres.
##
## Under tests/unit/ because it is arithmetic on a [RandomNumberGenerator] with
## no scene tree anywhere near it. What the shapes look like as meshes is
## [code]tests/integration/test_grove.gd[/code]'s job.
##
## The two things worth testing here are the two things the rest of the game
## leans on: that a seed is a promise (the same number is the same tree, every
## load, forever) and that [constant TreeShape.MAX_REACH] is a promise too — the
## grove uses it to keep crowns out of the camera's way, and a roll that broke it
## would put leaves in front of the lens on some load nobody could reproduce.
extends GutTest

## Close enough for a length in metres — a tenth of a millimetre, the same slack
## the rest of the suite gives a position.
const TOLERANCE: float = 0.0001

## How many arbitrary seeds the promises below are checked against. Far more
## than the seven the game ships, because the point is that the guarantee is
## structural rather than true of the seven by luck.
const ROLLS: int = 400


func test_a_seed_is_the_same_tree_twice() -> void:
	# The whole contract. Without this the level is different every load and
	# every screenshot in the README goes stale on its own.
	var once: TreeShape = TreeShape.new(271)
	var again: TreeShape = TreeShape.new(271)
	assert_almost_eq(once.trunk_height, again.trunk_height, TOLERANCE)
	assert_almost_eq(once.trunk_radius, again.trunk_radius, TOLERANCE)
	assert_eq(once.crown.size(), again.crown.size(), "the same number of spheres")
	for blob: int in once.crown.size():
		assert_almost_eq(once.crown[blob], again.crown[blob], Vector4.ONE * TOLERANCE)


func test_two_seeds_are_two_trees() -> void:
	# Cheap to satisfy and expensive to lose: a bug that ignored the seed would
	# pass every other test in this file.
	var one: TreeShape = TreeShape.new(TreeShape.SEEDS[0])
	var other: TreeShape = TreeShape.new(TreeShape.SEEDS[1])
	assert_ne(one.trunk_height, other.trunk_height, "two seeds, two trunks")


func test_the_frozen_seeds_are_seven_different_trees() -> void:
	# The wood the level ships with, and the reason TreeShape.SEEDS is a set that
	# was searched for rather than seven numbers somebody typed. Twins would load
	# just as consistently as anything else, so nothing else in the suite would
	# notice — the player would simply find the same tree by two corners.
	#
	# A tenth of a metre, against the 15 cm the set was chosen at: enough slack
	# that a small change to the ranges above does not fail here, tight enough
	# that a genuine pair does.
	var heights: Array[float] = []
	for tree: TreeShape in TreeShape.variants():
		for grown: float in heights:
			assert_gt(absf(tree.height() - grown), 0.1, "two variants came out the same height")
		heights.append(tree.height())
	assert_eq(heights.size(), TreeShape.SEEDS.size(), "one tree per frozen seed")


func test_a_trunk_is_a_trunk_and_not_a_pole_or_a_stump() -> void:
	for roll: int in ROLLS:
		var tree: TreeShape = TreeShape.new(roll * 7919)
		assert_between(tree.trunk_height, TreeShape.TRUNK_HEIGHT.x, TreeShape.TRUNK_HEIGHT.y)
		assert_between(tree.trunk_radius, TreeShape.TRUNK_RADIUS.x, TreeShape.TRUNK_RADIUS.y)


func test_no_crown_reaches_further_than_it_promised() -> void:
	# What GrovePlan's keep_clear is arithmetic against. See the class docs: this
	# is arranged by construction, and this is the test that says so.
	#
	# The tolerance is not slack in the promise, it is the promise being kept
	# exactly: a satellite pushed right out to its cap has a reach of MAX_REACH
	# by construction, and measuring it back with a square root returns it 30
	# nanometres over on a third of the rolls. Asserting on the bare constant
	# fails on those and on nothing else, which would be a test about float
	# arithmetic rather than about trees.
	for roll: int in ROLLS:
		var tree: TreeShape = TreeShape.new(roll * 104_729)
		assert_lte(tree.reach(), TreeShape.MAX_REACH + TOLERANCE, "roll %d grew too wide" % roll)


func test_a_crown_is_a_handful_of_spheres() -> void:
	for roll: int in ROLLS:
		var tree: TreeShape = TreeShape.new(roll * 31)
		assert_between(tree.crown.size(), TreeShape.CROWN_BLOBS.x, TreeShape.CROWN_BLOBS.y)


func test_every_sphere_overlaps_the_one_in_the_middle() -> void:
	# The blocked-together look, as a number: a satellite whose centre is further
	# from the core than the two radii together is a ball floating beside the
	# tree rather than part of its crown.
	for roll: int in ROLLS:
		var tree: TreeShape = TreeShape.new(roll * 6151)
		var core: Vector4 = tree.crown[0]
		var middle: Vector3 = Vector3(core.x, core.y, core.z)
		for blob: int in range(1, tree.crown.size()):
			var sphere: Vector4 = tree.crown[blob]
			var gap: float = middle.distance_to(Vector3(sphere.x, sphere.y, sphere.z))
			assert_lt(gap, core.w + sphere.w, "sphere %d of roll %d is adrift" % [blob, roll])


func test_the_leaves_keep_off_the_grass() -> void:
	# A crown that dipped to the ground would be a bush growing through a trunk,
	# and on a lawn the camera walks past it would be the first thing seen.
	for roll: int in ROLLS:
		var tree: TreeShape = TreeShape.new(roll * 1543)
		for blob: Vector4 in tree.crown:
			var underside: float = blob.y - blob.w
			assert_gte(underside, tree.trunk_height * TreeShape.BARE_TRUNK, "roll %d droops" % roll)


func test_the_crown_sits_on_top_of_the_trunk() -> void:
	# The other half of the same picture: a tree is taller than its own trunk,
	# and the sphere in the middle is up at the top of it rather than halfway
	# down, which is what a scale applied in the wrong order would produce.
	for roll: int in ROLLS:
		var tree: TreeShape = TreeShape.new(roll * 389)
		assert_gt(tree.height(), tree.trunk_height, "roll %d has no crown above its trunk" % roll)
		assert_gte(tree.crown[0].y, tree.trunk_height, "roll %d wears its crown low" % roll)


func test_the_trunk_stands_on_the_ground() -> void:
	# Nothing in the class puts the trunk anywhere, which is the point: a tree is
	# planted by giving it a transform and the shape is authored from y = 0 up.
	# Pinned because a crown authored about its own middle instead would plant
	# every tree half-buried and the fix would be spread across three files.
	var tree: TreeShape = TreeShape.new(TreeShape.SEEDS[3])
	assert_gt(tree.trunk_height, 0.0, "the trunk goes up from the ground")
	assert_almost_eq(Vector2(tree.crown[0].x, tree.crown[0].z).length(), 0.0, TOLERANCE)
