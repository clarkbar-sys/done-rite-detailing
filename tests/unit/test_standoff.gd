## Unit tests for [Standoff] — the servo that keeps the walking camera the same
## distance off a car that is not round.
##
## Under tests/unit/ because a [Standoff] is a [RefCounted] that has never heard
## of a ray: it is handed a distance and returns a radius, so converging on a
## target is a `for` loop here. That a real ray really does find the car, and
## that the camera really does end up beside it, is
## [code]tests/integration/test_play_screen.gd[/code]'s job.
extends GutTest

## A tenth of a millimetre.
const TOLERANCE: float = 0.0001

## Stand-ins for the garage's exports, deliberately distinct from each other so
## a swapped argument fails instead of cancelling out.
const CLEARANCE: float = 1.2
const MIN_RADIUS: float = 1.6
const MAX_RADIUS: float = 5.6
const SPEED: float = 1.5

## One physics tick at the engine's default rate — the delta this is really
## called with.
const TICK: float = 1.0 / 60.0

## Somewhere comfortably inside the fences, so a test about correction is not
## secretly a test about clamping.
const SETTLED_RADIUS: float = 2.2

var _standoff: Standoff = null


func before_each() -> void:
	_standoff = Standoff.new(CLEARANCE, MIN_RADIUS, MAX_RADIUS, SPEED)


## Runs the servo for [param seconds] against a car whose surface stays put — a
## flank, where moving the eye a metre in takes a metre off the gap. Returns
## where the radius ended up.
##
## [param surface] is how far the bodywork is from the middle of the car along
## the line being measured, so the gap the ray reports is the radius minus it.
func _settle(radius: float, surface: float, seconds: float) -> float:
	var ticks: int = int(seconds / TICK)
	for _tick: int in range(ticks):
		radius = _standoff.correct(radius, radius - surface, TICK)
	return radius


func test_it_starts_where_it_was_built() -> void:
	assert_eq(_standoff.clearance, CLEARANCE)
	assert_eq(_standoff.min_radius, MIN_RADIUS)
	assert_eq(_standoff.max_radius, MAX_RADIUS)
	assert_eq(_standoff.metres_per_second, SPEED)


func test_a_car_at_exactly_the_right_distance_moves_nothing() -> void:
	var held: float = _standoff.correct(SETTLED_RADIUS, CLEARANCE, TICK)
	assert_almost_eq(held, SETTLED_RADIUS, TOLERANCE, "there is nothing to correct")


func test_a_car_too_far_away_pulls_the_camera_in() -> void:
	# The sign, which is the easy half to get backwards: a bigger gap than we
	# want means standing too far off, so the radius comes down.
	var pulled: float = _standoff.correct(SETTLED_RADIUS, CLEARANCE + 0.5, TICK)
	assert_lt(pulled, SETTLED_RADIUS, "too far off the car means come closer")


func test_a_car_too_close_pushes_the_camera_out() -> void:
	var pushed: float = _standoff.correct(SETTLED_RADIUS, CLEARANCE - 0.5, TICK)
	assert_gt(pushed, SETTLED_RADIUS, "too near the paint means back off")


func test_it_corrects_no_faster_than_it_was_told_to() -> void:
	# The whole difference between easing around the corner of a bumper and being
	# yanked. A servo handed a two-metre error must still only move a tick's worth.
	var moved: float = absf(
		_standoff.correct(SETTLED_RADIUS, CLEARANCE + 2.0, TICK) - SETTLED_RADIUS
	)
	assert_almost_eq(moved, SPEED * TICK, TOLERANCE)


func test_the_rate_limit_holds_in_the_other_direction_too() -> void:
	var moved: float = absf(
		_standoff.correct(SETTLED_RADIUS, CLEARANCE - 2.0, TICK) - SETTLED_RADIUS
	)
	assert_almost_eq(moved, SPEED * TICK, TOLERANCE)


func test_a_small_error_is_closed_in_one_tick_rather_than_rationed() -> void:
	# Under the tick's budget the whole error goes, so the servo actually arrives
	# instead of halving the remainder forever.
	var error: float = SPEED * TICK * 0.5
	var closed: float = _standoff.correct(SETTLED_RADIUS, CLEARANCE + error, TICK)
	assert_almost_eq(closed, SETTLED_RADIUS - error, TOLERANCE)


func test_it_converges_from_too_far_out() -> void:
	# A flank 0.95 m from the middle of the car — the one in the bay — approached
	# from the showcase circuit's radius. Two seconds is longer than the eye ever
	# has to cross that gap at the speed above.
	var landed: float = _settle(MAX_RADIUS, 0.95, 4.0)
	assert_almost_eq(landed - 0.95, CLEARANCE, TOLERANCE, "it must arrive, not approach")


func test_it_converges_from_too_close_in() -> void:
	var landed: float = _settle(MIN_RADIUS, 0.95, 4.0)
	assert_almost_eq(landed - 0.95, CLEARANCE, TOLERANCE)


func test_it_settles_further_out_at_the_ends_of_a_long_car() -> void:
	# The entire point of the class. The car is 4.3 m long and 1.9 m wide, so the
	# radius that holds the same gap at its nose is not the one that holds it at
	# the door — a fixed circle cannot be both, and this is the pair of numbers
	# that proves it isn't being asked to.
	var flank: float = _settle(SETTLED_RADIUS, 0.95, 4.0)
	var nose: float = _settle(SETTLED_RADIUS, 2.15, 4.0)
	assert_almost_eq(flank, 0.95 + CLEARANCE, TOLERANCE)
	assert_almost_eq(nose, 2.15 + CLEARANCE, TOLERANCE)
	assert_gt(nose, flank, "the long way round has to stand further out")


func test_it_never_pulls_in_past_its_fence() -> void:
	# What a ray that hit something unexpected — or the inside of the car — would
	# otherwise do. The fence is the backstop, not the mechanism.
	var crushed: float = _settle(SETTLED_RADIUS, -100.0, 10.0)
	assert_almost_eq(crushed, MIN_RADIUS, TOLERANCE)


func test_it_never_pushes_out_past_its_fence() -> void:
	# And the other side: the far fence is the room's own walls, so a ray that
	# reported the car as being right on top of the lens must not walk the camera
	# out through the brickwork.
	var flung: float = _settle(SETTLED_RADIUS, 100.0, 10.0)
	assert_almost_eq(flung, MAX_RADIUS, TOLERANCE)


func test_a_frame_that_took_no_time_moves_nothing() -> void:
	# A zero delta is a real thing to be handed — a paused tree, the first tick
	# after a stall — and it has to buy zero correction rather than the whole
	# error at once.
	var held: float = _standoff.correct(SETTLED_RADIUS, CLEARANCE + 2.0, 0.0)
	assert_eq(held, SETTLED_RADIUS)


func test_a_radius_outside_the_fences_is_brought_back_inside() -> void:
	# The clamp is on the answer rather than on the correction, so a radius that
	# somehow started out of bounds is returned in bounds on the first tick even
	# when the correction itself was nothing.
	var rescued: float = _standoff.correct(MAX_RADIUS + 3.0, CLEARANCE, TICK)
	assert_almost_eq(rescued, MAX_RADIUS, TOLERANCE)
