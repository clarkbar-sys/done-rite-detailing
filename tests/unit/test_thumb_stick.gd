## Unit tests for [ThumbStick] — the arithmetic behind "a thumb somewhere in a
## circle is a direction and a speed".
##
## Everything the on-screen stick promises that is not about pixels or fingers is
## here: that the middle asks for nothing, that the rim asks for everything, that
## the two are joined by a ramp with no step in it, and that a diagonal is a
## diagonal rather than a direction asking for 1.41 of itself. Whether a real
## touch reaches this at all is
## [code]tests/integration/test_motion_pad.gd[/code]'s job, and whether the
## numbers move a camera is
## [code]tests/unit/test_orbit_drive.gd[/code]'s — neither is repeated here.
extends GutTest

## Close enough for a fraction of full deflection.
const TOLERANCE: float = 0.0001

## A radius to measure against. Round, and deliberately not the pad's — these are
## arithmetic tests with worked numbers beside them, and a test that only ever saw
## the shipping radius would keep passing if the mapping started depending on it.
const RADIUS: float = 100.0

## How many samples the ramp sweep takes. Fine enough to catch a step in the
## middle of it, coarse enough to stay a unit test.
const SAMPLES: int = 200


## A point [param reach] px to the right of the middle — the direction with the
## simplest arithmetic, since it puts the whole answer in [code]turn[/code].
func _right(reach: float) -> Vector2:
	return Vector2(reach, 0.0)


## The dead middle, in pixels, for [constant RADIUS].
func _dead() -> float:
	return ThumbStick.dead_radius(RADIUS)


# ---- the dead middle ---------------------------------------------------------


func test_a_thumb_in_the_middle_asks_for_nothing() -> void:
	# The state a stick is in the instant it is grabbed, and the reason the dead
	# middle exists at all: a thumb resting on the glass must not walk the camera.
	assert_eq(ThumbStick.input_from(Vector2.ZERO, RADIUS), Vector2.ZERO)


func test_a_thumb_anywhere_inside_the_dead_middle_asks_for_nothing() -> void:
	# Every direction, not just one: a deadzone that was a square, or that was
	# applied per axis, would let a diagonal nudge through.
	for step: int in 16:
		var angle: float = TAU * float(step) / 16.0
		var inside: Vector2 = Vector2.from_angle(angle) * (_dead() * 0.99)
		assert_eq(
			ThumbStick.input_from(inside, RADIUS),
			Vector2.ZERO,
			"%s is inside the dead middle" % inside
		)


func test_just_outside_the_dead_middle_is_the_slowest_ask_there_is() -> void:
	# The bug this pins is the naive deadzone: zero below the threshold and
	# `reach / radius` above it, which jumps straight to a fifth of full speed the
	# instant the thumb clears the middle. A stick with no slow setting is the
	# thing the four arrows already were.
	var barely: Vector2 = _right(_dead() * 1.01)
	var asked: float = ThumbStick.input_from(barely, RADIUS).x
	assert_gt(asked, 0.0, "clearing the dead middle must ask for something")
	assert_lt(asked, 0.05, "but only just — it is the start of the ramp, not a step onto it")


# ---- the ramp, and the rim ---------------------------------------------------


func test_a_thumb_at_the_rim_asks_for_everything() -> void:
	assert_almost_eq(
		ThumbStick.input_from(_right(RADIUS), RADIUS).x, ThumbStick.FULL_INPUT, TOLERANCE
	)


func test_a_thumb_dragged_past_the_rim_still_asks_for_everything() -> void:
	# A thumb slides off the circle constantly — it is a 25 mm target under a
	# moving hand. Dropping the input there would stop the camera for a movement
	# the player did not mean as a stop, which is worse than the alternative in
	# every way.
	var far: Vector2 = _right(RADIUS * 10.0)
	assert_almost_eq(ThumbStick.input_from(far, RADIUS).x, ThumbStick.FULL_INPUT, TOLERANCE)


func test_the_ramp_between_them_only_ever_goes_up() -> void:
	# The property that makes the stick feel like a stick: further out is never
	# slower. A sweep rather than three points, because the failure this catches —
	# a step, a dip, an overshoot past full — lives between whatever points anybody
	# would have picked.
	var previous: float = -1.0
	for step: int in SAMPLES + 1:
		var reach: float = RADIUS * float(step) / float(SAMPLES)
		var asked: float = ThumbStick.input_from(_right(reach), RADIUS).x
		assert_gte(asked, previous, "the ramp went backwards at %s px" % reach)
		assert_lte(asked, ThumbStick.FULL_INPUT, "and it must never ask for more than full")
		previous = asked


func test_half_the_travel_asks_for_a_quarter_not_half() -> void:
	# The ramp is squared, not straight — the curve behind [OrbitDrive]'s raised
	# top speed. A thumb halfway across the travel outside the dead middle asks
	# for a quarter of full, so raising the speed at the rim does not also speed
	# up the nudge that was already fine at the old, lower number.
	var reach: float = _dead() + (RADIUS - _dead()) * 0.5
	var asked: float = ThumbStick.input_from(_right(reach), RADIUS).x
	assert_almost_eq(asked, 0.25, TOLERANCE, "half the travel is a quarter of full, not half")


# ---- which way is which ------------------------------------------------------


func test_the_axes_are_the_ones_the_pad_names() -> void:
	# Y flips between screen space and input space, and a stick that got that
	# backwards would be a camera that goes down when the thumb goes up — the
	# mirrored-control bug, invisible to any test that only checks that something
	# moved.
	var up: Vector2 = ThumbStick.input_from(Vector2(0.0, -RADIUS), RADIUS)
	assert_almost_eq(up.y, ThumbStick.FULL_INPUT, TOLERANCE, "up the glass must raise the eye")
	assert_almost_eq(up.x, 0.0, TOLERANCE, "and must not walk you round the car")
	var left: Vector2 = ThumbStick.input_from(Vector2(-RADIUS, 0.0), RADIUS)
	assert_almost_eq(left.x, -ThumbStick.FULL_INPUT, TOLERANCE, "left of the middle is left")
	assert_almost_eq(left.y, 0.0, TOLERANCE)


func test_a_corner_asks_for_both_at_once_and_for_no_more_than_full() -> void:
	# The whole reason this is a circle and not four buttons — and the trap that
	# comes with it. Clamping the components instead of the length would let a
	# diagonal ask for 1.41 times what an axis alone can, so the corners of the
	# stick would be faster than its edges.
	var corner: Vector2 = Vector2.ONE.normalized() * RADIUS
	var asked: Vector2 = ThumbStick.input_from(corner, RADIUS)
	assert_gt(asked.x, 0.0, "the corner walks you")
	assert_lt(asked.y, 0.0, "and lowers your eye, because +Y on the glass is down")
	assert_almost_eq(asked.length(), ThumbStick.FULL_INPUT, TOLERANCE, "at full and no more")


# ---- the grab area -----------------------------------------------------------


func test_the_circle_claims_a_touch_inside_it_and_leaves_the_rest() -> void:
	# The rule that decides whether a press is a walk or an aim. Getting it wrong
	# in one direction puts a crosshair on the car every time the player takes a
	# step; in the other it walks the camera every time they aim near the corner.
	assert_true(ThumbStick.holds(Vector2.ZERO, RADIUS), "the middle is on the stick")
	assert_true(ThumbStick.holds(_right(RADIUS), RADIUS), "and so is the rim itself")
	assert_false(ThumbStick.holds(_right(RADIUS * 1.01), RADIUS), "just outside it is not")


func test_the_knob_follows_the_thumb_and_stops_at_the_rim() -> void:
	var inside: Vector2 = Vector2(30.0, -40.0)
	assert_eq(
		ThumbStick.knob_from(inside, RADIUS), inside, "inside the circle it is under the thumb"
	)
	var outside: Vector2 = Vector2(300.0, -400.0)
	var knob: Vector2 = ThumbStick.knob_from(outside, RADIUS)
	assert_almost_eq(knob.length(), RADIUS, TOLERANCE, "outside it, it stops at the rim")
	assert_almost_eq(
		knob.normalized().dot(outside.normalized()), 1.0, TOLERANCE, "still pointing at the thumb"
	)


# ---- the degenerate case -----------------------------------------------------


func test_a_circle_with_no_radius_asks_for_nothing_rather_than_dividing_by_zero() -> void:
	# Cannot happen in a laid-out pad; would be a NaN steering a camera if it did,
	# and a NaN in a transform takes the whole view with it rather than failing
	# where it was made.
	assert_eq(ThumbStick.input_from(Vector2(10.0, 10.0), 0.0), Vector2.ZERO)
	assert_eq(ThumbStick.knob_from(Vector2(10.0, 10.0), 0.0), Vector2.ZERO)
	assert_false(ThumbStick.holds(Vector2.ZERO, 0.0), "and nothing can grab it")
