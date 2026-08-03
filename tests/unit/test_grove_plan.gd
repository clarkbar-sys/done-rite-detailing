## Unit tests for [GrovePlan] — where the trees stand along the edge of the lawn.
##
## Under tests/unit/ because a row of [Transform3D]s needs no scene tree to be
## right or wrong. The numbers below are made up rather than read off the
## driveway on purpose: a test that used the room's own edges would go red when
## somebody widened the grass and would be reporting a change to the level rather
## than a bug in this. That the real rows land on the real grass, and clear the
## real camera, is [code]tests/integration/test_grove.gd[/code]'s job.
extends GutTest

## Close enough for a length in metres — a tenth of a millimetre.
const TOLERANCE: float = 0.0001

## The edge the rows below are planted along, and the ends of that lawn: roughly
## the driveway's own shape without being tied to it.
const EDGE: float = 6.0

## See [constant EDGE].
const LIMIT: float = 6.5

## The disc the trees have to stay out of, as a radius from the middle.
const CLEAR: float = 7.0

## An arbitrary seed. Every test that does not care which roll it got uses this
## one, so a failure is always the same row.
const SEED: int = 90_210


func _row(count: int) -> Array[Transform3D]:
	return GrovePlan.down_the_edge(EDGE, LIMIT, count, CLEAR, SEED)


# ---- the forbidden stretch in the middle --------------------------------------


func test_an_edge_inside_the_gap_has_to_start_further_down() -> void:
	# Pythagoras: a tree 3 m out across has to be 4 m down the lawn to be 5 m
	# from the car.
	assert_almost_eq(GrovePlan.clear_of(3.0, 5.0), 4.0, TOLERANCE)


func test_an_edge_already_clear_of_the_gap_may_start_anywhere() -> void:
	# The branch that stops a square root being asked for a negative number, and
	# the answer a lawn further out than the gap should get: no forbidden stretch
	# at all.
	assert_almost_eq(GrovePlan.clear_of(9.0, 5.0), 0.0, TOLERANCE)


# ---- the row itself -----------------------------------------------------------


func test_it_plants_what_it_was_asked_for() -> void:
	assert_eq(_row(4).size(), 4)


func test_none_of_them_stand_in_the_gap() -> void:
	# The reason any of this is arithmetic rather than seven positions typed into
	# a scene file. A tree inside this radius is a tree the camera orbits
	# through, and the wobble is exactly the thing that could sneak one in.
	for stand: Transform3D in _row(6):
		var flat: Vector2 = Vector2(stand.origin.x, stand.origin.z)
		assert_gte(flat.length(), CLEAR - TOLERANCE, "a tree at %v is in the camera's way" % flat)


func test_they_stand_on_the_lawn_and_not_past_the_end_of_it() -> void:
	for stand: Transform3D in _row(6):
		assert_between(stand.origin.z, -LIMIT, LIMIT, "past the end of the grass")
		assert_between(
			stand.origin.x,
			EDGE - GrovePlan.WOBBLE_ACROSS,
			EDGE + GrovePlan.WOBBLE_ACROSS,
			"wandered off its edge"
		)
	assert_almost_eq(_row(6)[0].origin.y, 0.0, TOLERANCE, "and on the ground, not above it")


func test_the_row_comes_back_in_order_down_the_lawn() -> void:
	# What the slots buy: a wobble that could reorder two neighbours would also
	# be a wobble that could put them on top of each other.
	var last: float = -LIMIT - 1.0
	for stand: Transform3D in _row(8):
		assert_gt(stand.origin.z, last, "the row doubled back on itself")
		last = stand.origin.z


func test_no_two_of_them_grow_out_of_each_other() -> void:
	# A row of six over two stretches of about two and a half metres each. The
	# floor is the slot a tree gets minus the two wobbles that could bring a pair
	# together — which for this row works out just over a third of a metre, so a
	# free-position layout that happened to look fine on this seed would still
	# fail here on another.
	var row: Array[Transform3D] = _row(6)
	for tree: int in range(1, row.size()):
		var gap: float = row[tree].origin.distance_to(row[tree - 1].origin)
		assert_gt(gap, 0.3, "two trees %.2f m apart" % gap)


func test_it_uses_both_ends_of_the_lawn() -> void:
	# The row is dealt across the two stretches the gap leaves, so a plan that
	# quietly used one of them would look like a garden with a bald side.
	var near: int = 0
	var far: int = 0
	for stand: Transform3D in _row(6):
		if stand.origin.z < 0.0:
			near += 1
		else:
			far += 1
	assert_gt(near, 0, "nothing planted at the near end")
	assert_gt(far, 0, "nothing planted at the far end")


func test_they_are_not_all_facing_the_same_way() -> void:
	# Two trees rolled from the same seed are the same tree; the turn is what
	# stops the repeat being visible once the wood is bigger than TreeShape.SEEDS.
	var row: Array[Transform3D] = _row(4)
	var facing: Vector3 = row[0].basis.z
	var turned: bool = false
	for stand: Transform3D in row:
		if stand.basis.z.distance_to(facing) > 0.01:
			turned = true
	assert_true(turned, "every tree in the row faces the same way")


func test_a_left_hand_edge_is_planted_down_the_left() -> void:
	# The row the driveway's other strip of grass gets. Negative in, negative
	# out — worth pinning because the clearance maths squares the x and would
	# not notice a sign lost on the way through.
	for stand: Transform3D in GrovePlan.down_the_edge(-EDGE, LIMIT, 4, CLEAR, SEED):
		assert_lt(stand.origin.x, 0.0, "planted on the wrong side of the drive")
		var flat: Vector2 = Vector2(stand.origin.x, stand.origin.z)
		assert_gte(flat.length(), CLEAR - TOLERANCE, "a tree at %v is in the camera's way" % flat)


# ---- the seed ------------------------------------------------------------------


func test_a_seed_is_the_same_row_twice() -> void:
	var once: Array[Transform3D] = _row(5)
	var again: Array[Transform3D] = _row(5)
	for tree: int in once.size():
		assert_almost_eq(once[tree].origin, again[tree].origin, Vector3.ONE * TOLERANCE)


func test_two_seeds_are_two_rows() -> void:
	# What the two plan seeds in the grove buy: the strip of grass on the left
	# and the one on the right are not mirror images of each other.
	var other: Array[Transform3D] = GrovePlan.down_the_edge(EDGE, LIMIT, 5, CLEAR, SEED + 1)
	assert_ne(_row(5)[0].origin.z, other[0].origin.z, "two seeds, two rows")


# ---- asking for the impossible -------------------------------------------------


func test_no_room_plants_nothing_rather_than_guessing() -> void:
	# A gap wider than the lawn is long. Answering with an empty row is the whole
	# of the contract here: the alternative is a tree in the middle of the
	# driveway, planted because the arithmetic had nowhere legal to put it.
	assert_eq(GrovePlan.down_the_edge(EDGE, LIMIT, 4, 40.0, SEED).size(), 0)


func test_nothing_asked_for_is_nothing_planted() -> void:
	assert_eq(GrovePlan.down_the_edge(EDGE, LIMIT, 0, CLEAR, SEED).size(), 0)
	assert_eq(GrovePlan.down_the_edge(EDGE, LIMIT, -3, CLEAR, SEED).size(), 0)
