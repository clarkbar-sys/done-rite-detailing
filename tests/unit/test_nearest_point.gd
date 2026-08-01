## Unit tests for [NearestPoint] — the arithmetic that answers "which bit of the
## car did I come closest to missing" when a press lands beside it.
##
## Under tests/unit/ because it is static maths on an [AABB] and a ray, with no
## scene tree anywhere near it. The boxes below are made up rather than read off
## a car on purpose: a test that asked the real [Car] for its panels would go red
## when somebody reshaped a wing, and it would be reporting a change to the car
## rather than a bug in this. That the real panels really are found, and that the
## point really lands on paint, is
## [code]tests/integration/test_play_screen_aim.gd[/code]'s job.
extends GutTest

## A tenth of a millimetre, in metres — the same slack the rest of the suite
## gives a position.
const TOLERANCE: float = 0.0001

## A metre cube sitting on the origin, used by most of what follows.
const CUBE: AABB = AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)


## Two metres back down +Z, looking at the origin — the shape of every aim in the
## game: an eye outside the car, a ray pointed somewhere near it.
func _from() -> Vector3:
	return Vector3(0.0, 0.0, 2.0)


# ---- clamping a point into a box ---------------------------------------------


func test_a_point_inside_the_box_is_already_where_it_belongs() -> void:
	var inside: Vector3 = Vector3(0.1, -0.2, 0.3)
	assert_almost_eq(NearestPoint.in_box(CUBE, inside), inside, Vector3.ONE * TOLERANCE)


func test_a_point_outside_comes_back_on_the_nearest_face() -> void:
	assert_almost_eq(
		NearestPoint.in_box(CUBE, Vector3(4.0, 0.0, 0.0)),
		Vector3(0.5, 0.0, 0.0),
		Vector3.ONE * TOLERANCE
	)


func test_a_point_past_a_corner_comes_back_on_the_corner() -> void:
	# Per-axis clamping, which is the whole function — but it is worth pinning
	# that all three axes clamp rather than the first one that is out.
	assert_almost_eq(
		NearestPoint.in_box(CUBE, Vector3(9.0, 9.0, 9.0)), CUBE.end, Vector3.ONE * TOLERANCE
	)


# ---- projecting onto the ray -------------------------------------------------


func test_a_point_beside_the_ray_projects_onto_it() -> void:
	var on_ray: Vector3 = NearestPoint.on_ray(
		Vector3.ZERO, Vector3.FORWARD, Vector3(3.0, 0.0, -5.0)
	)
	assert_almost_eq(on_ray, Vector3(0.0, 0.0, -5.0), Vector3.ONE * TOLERANCE)


func test_a_point_behind_the_player_is_nearest_to_the_player() -> void:
	# A ray and not a line — see [method NearestPoint.on_ray]. Press near the
	# horizon and the far end of the car really is behind the aim, and the answer
	# has to be the eye rather than a stretch of ray that does not exist.
	var behind: Vector3 = NearestPoint.on_ray(Vector3.ZERO, Vector3.FORWARD, Vector3(0.0, 0.0, 8.0))
	assert_almost_eq(behind, Vector3.ZERO, Vector3.ONE * TOLERANCE)


func test_a_direction_of_nothing_does_not_produce_a_nan() -> void:
	var nowhere: Vector3 = NearestPoint.on_ray(Vector3.ONE, Vector3.ZERO, Vector3(4.0, 0.0, 0.0))
	assert_almost_eq(nowhere, Vector3.ONE, Vector3.ONE * TOLERANCE)


# ---- the closest point on a box to a ray -------------------------------------


## A ray through the box has no gap to close, so "closest point" is any point
## the two share — here the box's own middle, because that is where the loop
## starts and the first pass finds nothing to improve.
##
## Not the near face, which is what this test originally asserted and what an
## intuition about raycasts expects. Worth pinning as the answer it really gives
## rather than quietly wishing for the other one: the room never asks this
## question of a ray that hits (a raycast already answered it), so being right
## about the gap matters and being on the surface does not.
func test_a_ray_straight_through_the_box_has_no_gap_to_it() -> void:
	var found: Vector3 = NearestPoint.in_box_from_ray(CUBE, _from(), Vector3.FORWARD)
	assert_true(CUBE.has_point(found), "the point it found is on or in the box")
	assert_almost_eq(NearestPoint.gap_to_ray(CUBE, _from(), Vector3.FORWARD), 0.0, TOLERANCE)


func test_a_ray_passing_above_the_box_lands_on_its_top() -> void:
	# The press this is really for: a finger on the sky just above the roof. The
	# answer has to be the top of the car and not its middle.
	var above: Vector3 = Vector3(0.0, 0.4, -1.0).normalized()
	var found: Vector3 = NearestPoint.in_box_from_ray(CUBE, _from(), above)
	assert_almost_eq(found.y, 0.5, TOLERANCE, "on the top face")
	assert_gt(NearestPoint.gap_to_ray(CUBE, _from(), above), 0.0, "and the ray missed it")


func test_a_ray_passing_beside_the_box_lands_on_its_flank() -> void:
	var beside: Vector3 = Vector3(0.4, 0.0, -1.0).normalized()
	var found: Vector3 = NearestPoint.in_box_from_ray(CUBE, _from(), beside)
	assert_almost_eq(found.x, 0.5, TOLERANCE, "on the +X face")


func test_the_point_it_finds_is_the_closest_one_there_is() -> void:
	# The claim the class docs make about alternating projection, checked against
	# brute force rather than taken on trust: nothing on the box's surface is
	# nearer the ray than what the loop returned.
	var facing: Vector3 = Vector3(0.7, 0.55, -1.0).normalized()
	var found: Vector3 = NearestPoint.in_box_from_ray(CUBE, _from(), facing)
	var best: float = found.distance_to(NearestPoint.on_ray(_from(), facing, found))
	var steps: int = 12
	for x: int in steps + 1:
		for y: int in steps + 1:
			for z: int in steps + 1:
				var walked: Vector3 = (
					CUBE.position
					+ (
						CUBE.size
						* Vector3(
							float(x) / float(steps),
							float(y) / float(steps),
							float(z) / float(steps)
						)
					)
				)
				var gap: float = walked.distance_to(NearestPoint.on_ray(_from(), facing, walked))
				assert_gte(gap, best - TOLERANCE, "a grid point at %v beat the answer" % walked)


func test_a_ray_pointed_away_from_the_box_is_nearest_at_the_eye() -> void:
	# Press behind you and the whole car is behind the aim. Not reachable through
	# the game's own controls — the eye cannot turn — but this is the branch that
	# stops the maths inventing a point out in front of the player.
	var away: Vector3 = Vector3.BACK
	var found: Vector3 = NearestPoint.in_box_from_ray(CUBE, _from(), away)
	assert_almost_eq(found, Vector3(0.0, 0.0, 0.5), Vector3.ONE * TOLERANCE)


# ---- picking one box out of several ------------------------------------------


func test_the_nearest_of_several_boxes_is_the_one_the_ray_goes_by() -> void:
	var boxes: Array[AABB] = [
		AABB(Vector3(-3.5, -0.5, -0.5), Vector3.ONE),
		AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE),
		AABB(Vector3(2.5, -0.5, -0.5), Vector3.ONE),
	]
	assert_eq(NearestPoint.nearest_box(boxes, _from(), Vector3.FORWARD), 1, "the middle one")
	var leftward: Vector3 = Vector3(-1.0, 0.0, -0.6).normalized()
	assert_eq(NearestPoint.nearest_box(boxes, _from(), leftward), 0, "the left one")


func test_a_ray_through_two_boxes_picks_one_of_them() -> void:
	# Both gaps are zero, so this is about not returning -1 rather than about
	# which one wins. The room only reaches for any of this after a raycast came
	# back empty, so an overlapping pair cannot actually arrive here.
	var boxes: Array[AABB] = [CUBE, AABB(Vector3(-0.5, -0.5, -1.5), Vector3.ONE)]
	assert_gte(NearestPoint.nearest_box(boxes, _from(), Vector3.FORWARD), 0)


func test_no_boxes_at_all_is_answered_and_not_guessed() -> void:
	# A car with no panels is not a state the game can reach, and -1 is what stops
	# it being an index into an empty array if it ever does.
	var none: Array[AABB] = []
	assert_eq(NearestPoint.nearest_box(none, _from(), Vector3.FORWARD), -1)
