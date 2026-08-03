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


# ---- the stretch of a run the camera's disc eats -------------------------------


func test_a_run_through_the_gap_is_blocked_where_it_crosses() -> void:
	# A line 3 m out across, walked up the lawn from 8 m back: it enters the 5 m
	# disc 4 m short of the nearest point and leaves it 4 m past, so the blocked
	# stretch is the 8 m in the middle of the run. Pythagoras, as a span.
	var blocked: Vector2 = GrovePlan.blocked_span(Vector3(3.0, 0.0, -8.0), Vector3.BACK, 16.0, 5.0)
	assert_almost_eq(blocked, Vector2(4.0, 12.0), Vector2.ONE * TOLERANCE)


func test_a_run_that_never_comes_near_is_not_blocked_at_all() -> void:
	# The answer both outer edges of the driveway get, and the branch that stops
	# a square root being asked for a negative number. Zero span, not zero
	# trees — this is what lets a row be planted end to end.
	var blocked: Vector2 = GrovePlan.blocked_span(Vector3(9.0, 0.0, -8.0), Vector3.BACK, 16.0, 5.0)
	assert_almost_eq(blocked, Vector2.ZERO, Vector2.ONE * TOLERANCE)


func test_a_run_grazing_the_gap_is_not_blocked_either() -> void:
	# Exactly tangent. Worth pinning as its own case: it is the boundary between
	# the two above, and a `< 0` where the code has `<= 0` would return a span of
	# zero width here and take a slot out of the row for nothing.
	var blocked: Vector2 = GrovePlan.blocked_span(Vector3(5.0, 0.0, -8.0), Vector3.BACK, 16.0, 5.0)
	assert_almost_eq(blocked, Vector2.ZERO, Vector2.ONE * TOLERANCE)


# ---- a run in any direction ----------------------------------------------------


func test_a_run_across_the_end_of_the_lawn_is_planted_too() -> void:
	# What the ends of the grass need, and the reason `along` takes two points
	# rather than an edge and a limit: this run goes across the lawn rather than
	# down it, and the disc eats the end of it nearest the car instead of its
	# middle.
	var row: Array[Transform3D] = GrovePlan.along(
		Vector3(2.0, 0.0, 6.0), Vector3(7.0, 0.0, 6.0), 3, CLEAR, SEED
	)
	assert_eq(row.size(), 3)
	var last: float = 0.0
	for stand: Transform3D in row:
		assert_almost_eq(stand.origin.z, 6.0, GrovePlan.WOBBLE_ACROSS + TOLERANCE, "off its line")
		assert_gte(Vector2(stand.origin.x, stand.origin.z).length(), CLEAR - TOLERANCE)
		assert_gt(stand.origin.x, last, "the run doubled back on itself")
		last = stand.origin.x
	assert_lte(row[row.size() - 1].origin.x, 7.0 + TOLERANCE, "past the end of the run")


func test_a_run_of_no_length_plants_nothing_rather_than_dividing_by_it() -> void:
	var nowhere: Array[Transform3D] = GrovePlan.along(
		Vector3(4.0, 0.0, 9.0), Vector3(4.0, 0.0, 9.0), 3, CLEAR, SEED
	)
	assert_eq(nowhere.size(), 0)


# ---- the row itself -----------------------------------------------------------


func test_it_plants_what_it_was_asked_for() -> void:
	assert_eq(_row(4).size(), 4)


func test_a_run_clear_of_the_gap_is_planted_end_to_end() -> void:
	# The shape both long edges of the driveway now have: nothing forbidden, so
	# the row uses the whole run rather than huddling at the two ends of it. The
	# outermost slots reach within a slot's width of each end.
	var row: Array[Transform3D] = GrovePlan.down_the_edge(9.0, LIMIT, 4, CLEAR, SEED)
	assert_lt(row[0].origin.z, -LIMIT * 0.5, "nothing planted down the near half")
	assert_gt(row[3].origin.z, LIMIT * 0.5, "nothing planted down the far half")


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
