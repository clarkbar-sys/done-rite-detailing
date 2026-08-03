## Unit tests for [AttractWalk] — the push the title screen's demo puts on the
## walk to bring the eye round to whatever it is about to work on.
##
## Under tests/unit/ because both functions are arithmetic on two numbers and a
## band: there is no camera here, no orbit and no frame. That a real eye really
## does end up beside the panel being washed is
## [code]tests/integration/test_title_screen_attract.gd[/code]'s job.
extends GutTest

## A tenth of a millimetre, and a thousandth of a degree.
const TOLERANCE: float = 0.0001

## Stand-ins for the garage's two easing exports, deliberately different numbers
## so a swapped argument fails instead of cancelling out.
const TURN_EASE: float = 40.0
const LIFT_EASE: float = 0.6

# ---- the turn ----------------------------------------------------------------


func test_an_eye_already_there_is_pushed_nowhere() -> void:
	assert_eq(AttractWalk.turn_toward(90.0, 90.0, TURN_EASE), 0.0, "there is nothing to walk")


func test_work_ahead_of_the_eye_pushes_it_forward() -> void:
	# The sign, which is the easy half to get backwards: this number is multiplied
	# by [member Garage.turn_degrees_per_second] and added to the orbit's angle, so
	# a target at a higher angle has to come out positive.
	assert_gt(AttractWalk.turn_toward(0.0, 90.0, TURN_EASE), 0.0)


func test_work_behind_the_eye_pushes_it_back() -> void:
	assert_lt(AttractWalk.turn_toward(90.0, 0.0, TURN_EASE), 0.0)


func test_a_long_way_off_is_a_flat_out_walk() -> void:
	# Outside the band there is nothing to be proportional about: the eye is simply
	# somewhere else and should be walking at the speed a held button buys.
	assert_eq(AttractWalk.turn_toward(0.0, 120.0, TURN_EASE), AttractWalk.FULL_INPUT)
	assert_eq(AttractWalk.turn_toward(0.0, -120.0, TURN_EASE), -AttractWalk.FULL_INPUT)


func test_it_eases_off_as_it_arrives() -> void:
	# The whole reason there is a band. A bang-bang push would sit on the target
	# juddering between full left and full right, which is the most obvious way a
	# camera can announce it is being driven by a script.
	var far: float = AttractWalk.turn_toward(0.0, TURN_EASE, TURN_EASE)
	var near: float = AttractWalk.turn_toward(0.0, TURN_EASE * 0.25, TURN_EASE)
	assert_almost_eq(far, AttractWalk.FULL_INPUT, TOLERANCE, "the edge of the band is full push")
	assert_almost_eq(near, 0.25, TOLERANCE, "and it falls off in proportion inside it")


func test_it_takes_the_short_way_round() -> void:
	# An eye at 350° sent to 10° walks 20° forward, not 340° back. Without the wrap
	# the demo would occasionally take the long way round the car for no reason a
	# viewer could see, which reads as the camera losing its place.
	assert_gt(AttractWalk.turn_toward(350.0, 10.0, TURN_EASE), 0.0, "20° forward, not 340° back")
	assert_lt(AttractWalk.turn_toward(10.0, 350.0, TURN_EASE), 0.0)


func test_the_short_way_is_the_same_push_wherever_the_wrap_falls() -> void:
	# The wrap must not change how hard the walk is pushed, only which way. These
	# two are the same 20° gap, one of them across the seam.
	assert_almost_eq(
		AttractWalk.turn_toward(350.0, 10.0, TURN_EASE),
		AttractWalk.turn_toward(100.0, 120.0, TURN_EASE),
		TOLERANCE
	)


func test_angles_outside_a_single_turn_are_still_understood() -> void:
	# [method CameraOrbit.advance] keeps its own angle inside one turn, but the
	# target is computed from an `atan2` and arrives in -180..180. The two have to
	# meet without a special case at either end.
	assert_almost_eq(
		AttractWalk.turn_toward(350.0, -170.0, TURN_EASE),
		AttractWalk.turn_toward(350.0, 190.0, TURN_EASE),
		TOLERANCE
	)


func test_the_far_side_of_the_car_is_a_full_push_either_way() -> void:
	# Dead opposite is the one place a shortest-path controller has no answer. Both
	# signs are correct there and neither is a stall, which is what this pins: the
	# eye must set off rather than sitting still because the maths could not choose.
	assert_eq(absf(AttractWalk.turn_toward(0.0, 180.0, TURN_EASE)), AttractWalk.FULL_INPUT)


# ---- the lift ----------------------------------------------------------------


func test_an_eye_at_the_right_height_is_pushed_nowhere() -> void:
	assert_eq(AttractWalk.lift_toward(1.0, 1.0, LIFT_EASE), 0.0)


func test_work_above_the_eye_raises_it() -> void:
	# Same sign convention as the turn, and for the same reason: this is multiplied
	# by [member Garage.lift_metres_per_second] and added to the orbit's height.
	assert_gt(AttractWalk.lift_toward(0.4, 1.2, LIFT_EASE), 0.0)


func test_work_below_the_eye_lowers_it() -> void:
	assert_lt(AttractWalk.lift_toward(1.2, 0.4, LIFT_EASE), 0.0)


func test_the_lift_saturates_and_eases_like_the_turn() -> void:
	assert_eq(AttractWalk.lift_toward(0.0, LIFT_EASE * 3.0, LIFT_EASE), AttractWalk.FULL_INPUT)
	assert_almost_eq(
		AttractWalk.lift_toward(0.0, LIFT_EASE * 0.5, LIFT_EASE), 0.5, TOLERANCE, "half a band"
	)


# ---- the band itself ---------------------------------------------------------


func test_a_band_of_nothing_is_full_push_right_up_to_the_target() -> void:
	# The honest reading of "no easing at all", and emphatically not a division by
	# zero. A caller can ask for it — it is what a demo with no patience would want
	# — and what it must get is a push, not an infinity.
	assert_eq(AttractWalk.turn_toward(0.0, 0.001, 0.0), AttractWalk.FULL_INPUT)
	assert_eq(AttractWalk.turn_toward(0.0, -0.001, 0.0), -AttractWalk.FULL_INPUT)


func test_a_band_of_nothing_still_stops_on_the_target() -> void:
	# [method signf] answers 0 on 0 rather than picking a side, which is what keeps
	# an unbanded walk from creeping past what it was sent to.
	assert_eq(AttractWalk.turn_toward(90.0, 90.0, 0.0), 0.0)
	assert_eq(AttractWalk.lift_toward(1.0, 1.0, 0.0), 0.0)


func test_a_negative_band_is_treated_as_no_band_rather_than_inverted() -> void:
	# A band is a width, so a negative one is nonsense rather than a direction. It
	# must not come back with the sign flipped — a walk that sped up as it arrived
	# and turned round on the target is the one failure here that would look like a
	# camera bug rather than a bad number.
	assert_eq(AttractWalk.turn_toward(0.0, 20.0, -TURN_EASE), AttractWalk.FULL_INPUT)


func test_the_push_never_exceeds_what_a_thumb_can_ask_for() -> void:
	# [OrbitDrive] clamps what it is handed, so this is belt and braces — and it is
	# worth having on this side too, because a caller reading this class should be
	# able to trust the range without knowing what happens to the number next.
	for target: float in [1.0, 45.0, 179.0, -179.0, 1000.0]:
		assert_lte(absf(AttractWalk.turn_toward(0.0, target, TURN_EASE)), OrbitDrive.FULL_INPUT)


func test_half_a_turn_is_half_of_the_one_full_turn_this_project_knows_about() -> void:
	# The constant is derived from [constant CameraOrbit.FULL_TURN] rather than
	# written as 180, so that there is exactly one place in the project saying how
	# many degrees a circle has. This is what stops that from quietly becoming two.
	assert_eq(AttractWalk.HALF_TURN * 2.0, CameraOrbit.FULL_TURN)
