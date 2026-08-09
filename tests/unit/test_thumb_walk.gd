## Unit tests for [ThumbWalk] — the arithmetic and the one flag behind "a thumb
## drawn far enough toward a screen edge stops the tool and walks".
##
## Everything here is a call on two vectors and a bool, which is the point of
## the class being node-free: the boundary, the hysteresis, the veto and the
## walk vector are pinned without a scene, a camera or a finger. Whether a real
## drag on the real screen reaches this arithmetic is
## [code]tests/integration/test_play_screen_walk.gd[/code]'s job.
extends GutTest

## A landscape screen's half-extents, deliberately asymmetric so any test that
## accidentally treated the ellipse as a circle would fail on the short axis.
## The design resolution's own shape, halved.
const HALF: Vector2 = Vector2(640.0, 360.0)

## The same screen held the other way up, for the tests where the orientation
## is the point.
const PORTRAIT: Vector2 = Vector2(360.0, 640.0)

const TOLERANCE: float = 0.0001

## The aim is not landing on the car — the veto at rest.
const OFF_PANEL: bool = false

## The aim is landing on the car, so the walk may not start.
const ON_PANEL: bool = true


## A point at [param rho] of the way to the right edge — the axis a landscape
## screen is generous on.
func _right(at: float) -> Vector2:
	return Vector2(HALF.x * at, 0.0)


## A fresh gesture with the class's own thresholds.
func _walk() -> ThumbWalk:
	return ThumbWalk.new()


## One already read as a walk, parked safely past the entry band.
func _walking() -> ThumbWalk:
	var walk: ThumbWalk = _walk()
	walk.begin(_right(ThumbWalk.WALK_ENTER), HALF)
	return walk


# ---- rho: the ellipse in the screen's own shape ------------------------------


func test_the_middle_of_the_screen_is_rho_zero() -> void:
	assert_eq(ThumbWalk.rho(Vector2.ZERO, HALF), 0.0)


func test_the_edge_of_each_axis_is_rho_one() -> void:
	# The whole reason the boundary is an ellipse and not a circle: the middle of
	# the short edge and the middle of the long edge are the same fraction of the
	# way out, even though they are different distances in pixels.
	assert_almost_eq(ThumbWalk.rho(Vector2(HALF.x, 0.0), HALF), 1.0, TOLERANCE)
	assert_almost_eq(ThumbWalk.rho(Vector2(0.0, -HALF.y), HALF), 1.0, TOLERANCE)


func test_rho_reads_the_same_in_portrait() -> void:
	# The same fraction of the way out is the same rho held either way up, which
	# is the property a fixed pixel radius does not have.
	var fraction: float = 0.7
	assert_almost_eq(
		ThumbWalk.rho(Vector2(HALF.x * fraction, 0.0), HALF),
		ThumbWalk.rho(Vector2(PORTRAIT.x * fraction, 0.0), PORTRAIT),
		TOLERANCE
	)


func test_a_screen_with_no_size_reads_as_the_middle() -> void:
	# Degenerate half-extents cannot happen once anything is laid out and would
	# divide by zero if they did. The middle is the harmless answer: nothing ever
	# walks on it.
	assert_eq(ThumbWalk.rho(Vector2(100.0, 100.0), Vector2.ZERO), 0.0)
	assert_eq(ThumbWalk.rho(Vector2(100.0, 100.0), Vector2(640.0, 0.0)), 0.0)


# ---- the boundary, and which side a touch starts on --------------------------


func test_a_fresh_touch_inside_the_band_is_an_aim() -> void:
	var walk: ThumbWalk = _walk()
	assert_false(walk.begin(Vector2.ZERO, HALF), "the middle of the screen is an aim")
	assert_false(walk.walking())


func test_a_fresh_touch_past_the_band_walks_immediately() -> void:
	# A press near an edge is a fair request to move: there is no aim yet for the
	# veto to protect, and no centre-out drag should be required.
	var walk: ThumbWalk = _walk()
	assert_true(walk.begin(_right(ThumbWalk.WALK_ENTER), HALF), "the band itself is inside it")
	assert_true(walk.walking())


func test_a_drag_past_the_band_becomes_a_walk() -> void:
	var walk: ThumbWalk = _walk()
	walk.begin(Vector2.ZERO, HALF)
	assert_false(walk.update(_right(ThumbWalk.WALK_ENTER - 0.01), HALF, OFF_PANEL))
	assert_true(walk.update(_right(ThumbWalk.WALK_ENTER), HALF, OFF_PANEL))


func test_the_veto_keeps_a_scrub_an_aim_at_any_length() -> void:
	# The hard case the boundary alone cannot tell apart: a long stroke across a
	# door panel can cross any band. While the aim is landing on the car, the
	# walk may not start, however far the finger travels.
	var walk: ThumbWalk = _walk()
	walk.begin(Vector2.ZERO, HALF)
	assert_false(walk.update(_right(1.0), HALF, ON_PANEL), "still scrubbing, not walking")
	assert_false(walk.walking())
	# And the moment the stroke runs off the paint, the same position walks.
	assert_true(walk.update(_right(1.0), HALF, OFF_PANEL))


func test_the_veto_does_not_pull_a_walk_back() -> void:
	# There is no aim in a walk, so an on-panel reading there can only be stale —
	# the way back in is rho, not the veto.
	var walk: ThumbWalk = _walking()
	assert_true(walk.update(_right(ThumbWalk.WALK_ENTER), HALF, ON_PANEL), "a walk stays a walk")


# ---- hysteresis --------------------------------------------------------------


func test_between_the_thresholds_the_finger_keeps_its_reading() -> void:
	# The band between EXIT and ENTER answers "whichever you already were" — the
	# property that stops a resting thumb's millimetre of wander flapping the
	# tool up and down at the boundary.
	var between: Vector2 = _right((ThumbWalk.WALK_EXIT + ThumbWalk.WALK_ENTER) * 0.5)
	var aiming: ThumbWalk = _walk()
	aiming.begin(Vector2.ZERO, HALF)
	assert_false(aiming.update(between, HALF, OFF_PANEL), "an aim in the band stays an aim")
	var walking: ThumbWalk = _walking()
	assert_true(walking.update(between, HALF, OFF_PANEL), "and a walk in the band stays a walk")


func test_pulling_back_inside_the_exit_becomes_an_aim_again() -> void:
	var walk: ThumbWalk = _walking()
	assert_false(walk.update(_right(ThumbWalk.WALK_EXIT), HALF, OFF_PANEL))
	assert_false(walk.walking())


func test_release_ends_the_walk() -> void:
	# A held walk is a flag, and a flag that never clears is a camera that walks
	# forever — the lesson the old pad paid for twice, kept paid.
	var walk: ThumbWalk = _walking()
	walk.release()
	assert_false(walk.walking())
	assert_eq(walk.input(_right(1.0), HALF), Vector2.ZERO, "and a released walk asks for nothing")


# ---- the walk vector ---------------------------------------------------------


func test_an_aiming_finger_asks_for_nothing() -> void:
	var walk: ThumbWalk = _walk()
	walk.begin(Vector2.ZERO, HALF)
	assert_eq(walk.input(_right(0.5), HALF), Vector2.ZERO)


func test_the_boundary_itself_asks_for_almost_nothing() -> void:
	# The rescale from the band rather than from the centre: the first millimetre
	# past the boundary is the slow setting, which is what "nudge round the wing"
	# needs now that the stick's analog low end is gone.
	var walk: ThumbWalk = _walking()
	assert_almost_eq(walk.input(_right(ThumbWalk.WALK_ENTER), HALF).x, 0.0, TOLERANCE)


func test_full_speed_lives_at_full_speed_rho() -> void:
	var walk: ThumbWalk = _walking()
	assert_almost_eq(
		walk.input(_right(ThumbWalk.FULL_SPEED), HALF).x, ThumbWalk.FULL_INPUT, TOLERANCE
	)


func test_past_full_speed_is_pinned_at_full() -> void:
	# A thumb hard against the bezel keeps walking at full rather than asking for
	# more than a key can — the same clamp the stick's rim had.
	var walk: ThumbWalk = _walking()
	assert_almost_eq(walk.input(_right(1.0), HALF).x, ThumbWalk.FULL_INPUT, TOLERANCE)
	assert_lte(walk.input(_right(2.0), HALF).x, ThumbWalk.FULL_INPUT)


func test_the_strength_climbs_between_the_band_and_full() -> void:
	var walk: ThumbWalk = _walking()
	var midway: float = (ThumbWalk.WALK_ENTER + ThumbWalk.FULL_SPEED) * 0.5
	var asked: float = walk.input(_right(midway), HALF).x
	assert_between(asked, 0.4, 0.6, "half the band asks for about half")


func test_up_the_glass_raises_the_eye_and_left_walks_left() -> void:
	# The Y flip, at the seam: screen space has up at -Y, input space — what
	# [method OrbitDrive.steer] reads — has up at +1.
	var walk: ThumbWalk = _walk()
	walk.begin(Vector2(0.0, -HALF.y), HALF)
	assert_almost_eq(walk.input(Vector2(0.0, -HALF.y), HALF).y, 1.0, TOLERANCE, "up raises")
	var leftward: ThumbWalk = _walk()
	leftward.begin(Vector2(-HALF.x, 0.0), HALF)
	assert_almost_eq(leftward.input(Vector2(-HALF.x, 0.0), HALF).x, -1.0, TOLERANCE, "left is left")


func test_the_direction_is_the_fingers_own_not_the_ellipses() -> void:
	# The strength is measured on the ellipse but the direction is the raw pixel
	# vector from the centre — a drag toward the middle of the right edge walks
	# right, with no aspect-ratio lean.
	var offset: Vector2 = Vector2(HALF.x, -HALF.y * 0.1)
	var walk: ThumbWalk = _walk()
	walk.begin(offset, HALF)
	var asked: Vector2 = walk.input(offset, HALF)
	assert_almost_eq(
		asked.normalized().angle_to(Vector2(offset.x, -offset.y).normalized()),
		0.0,
		TOLERANCE,
		"the walk goes the way the finger went"
	)


func test_the_exported_thresholds_are_honoured() -> void:
	# The thresholds are exports on the play screen for #179's tuning pass, so
	# the constructor's numbers have to be the ones that answer.
	var walk: ThumbWalk = ThumbWalk.new(0.5, 0.3, 0.9)
	walk.begin(Vector2.ZERO, HALF)
	assert_true(walk.update(_right(0.5), HALF, OFF_PANEL), "a retuned band enters where it was put")
	assert_true(walk.update(_right(0.31), HALF, OFF_PANEL), "and holds above its own exit")
	assert_false(walk.update(_right(0.3), HALF, OFF_PANEL), "and lets go at it")
