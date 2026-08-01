## Unit tests for [OrbitDrive] — a thumb on a button, as movement.
##
## Under tests/unit/ because an [OrbitDrive] and the [CameraOrbit] it drives are
## both [RefCounted]: holding right for a second is one call here rather than
## sixty frames of a real scene. That the play screen's camera is actually
## [i]moved[/i] by these numbers is
## [code]tests/integration/test_play_screen.gd[/code]'s job.
extends GutTest

## A tenth of a millimetre, and a ten-thousandth of a degree. Every number below
## comes out of a float multiply, so exact equality is not on offer.
const TOLERANCE: float = 0.0001

## Stand-ins for the numbers the garage exports, deliberately distinct from each
## other so a swapped argument fails instead of cancelling out.
const TURN_SPEED: float = 40.0
const LIFT_SPEED: float = 0.9
const LOWEST: float = 0.4
const HIGHEST: float = 2.6

## The orbit the drive is pointed at. Distinct from the numbers above for the
## same reason.
const RADIUS: float = 2.2
const START_HEIGHT: float = 1.0

var _drive: OrbitDrive = null
var _orbit: CameraOrbit = null


func before_each() -> void:
	_drive = OrbitDrive.new(TURN_SPEED, LIFT_SPEED, LOWEST, HIGHEST)
	_orbit = CameraOrbit.new(RADIUS, START_HEIGHT, 0.0)


func test_it_starts_where_it_was_built() -> void:
	assert_eq(_drive.turn_degrees_per_second, TURN_SPEED)
	assert_eq(_drive.lift_metres_per_second, LIFT_SPEED)
	assert_eq(_drive.min_height, LOWEST)
	assert_eq(_drive.max_height, HIGHEST)


func test_a_fresh_drive_is_asking_for_nothing() -> void:
	# The state a player who has not touched the screen is in, and the state the
	# first frame of the game happens in.
	assert_eq(_drive.turn, 0.0, "nothing is held yet")
	assert_eq(_drive.lift, 0.0, "nothing is held yet")


func test_nothing_held_moves_nothing() -> void:
	_drive.drive(_orbit, 1.0)
	assert_eq(_orbit.angle_degrees, 0.0, "an untouched pad must not walk the camera")
	assert_eq(_orbit.height, START_HEIGHT, "or lift it")


func test_holding_right_turns_at_the_stated_rate() -> void:
	_drive.steer(1.0, 0.0)
	_drive.drive(_orbit, 1.0)
	assert_almost_eq(_orbit.angle_degrees, TURN_SPEED, TOLERANCE)


func test_holding_left_goes_the_other_way() -> void:
	# The sign convention, pinned once. `+1` sweeps from +Z toward +X, which is
	# the camera's own right — so "right" on the pad has to be the positive one or
	# the whole thing is mirrored.
	_drive.steer(-1.0, 0.0)
	_drive.drive(_orbit, 1.0)
	assert_almost_eq(_orbit.angle_degrees, CameraOrbit.FULL_TURN - TURN_SPEED, TOLERANCE)


func test_letting_go_stops_it_dead() -> void:
	# The bug this pins: writing the speed onto the orbit only when something is
	# held leaves the camera coasting at whatever it was last told, and a camera
	# that keeps walking after the thumb comes off reads as a stuck button.
	_drive.steer(1.0, 0.0)
	_drive.drive(_orbit, 1.0)
	_drive.steer(0.0, 0.0)
	_drive.drive(_orbit, 1.0)
	assert_almost_eq(_orbit.angle_degrees, TURN_SPEED, TOLERANCE, "the second second moved nothing")


func test_the_speed_is_per_second_and_not_per_frame() -> void:
	# Frame times are not a fixed thing, so a camera whose speed depended on how
	# the deltas happened to land would walk slower on a slower phone.
	var stepped: CameraOrbit = CameraOrbit.new(RADIUS, START_HEIGHT, 0.0)
	_drive.steer(1.0, 1.0)
	for _frame: int in range(60):
		_drive.drive(stepped, 1.0 / 60.0)
	_drive.drive(_orbit, 1.0)
	assert_almost_eq(stepped.angle_degrees, _orbit.angle_degrees, TOLERANCE)
	assert_almost_eq(stepped.height, _orbit.height, TOLERANCE)


func test_holding_up_raises_the_eye_at_the_stated_rate() -> void:
	_drive.steer(0.0, 1.0)
	_drive.drive(_orbit, 0.5)
	assert_almost_eq(_orbit.height, START_HEIGHT + LIFT_SPEED * 0.5, TOLERANCE)


func test_holding_down_lowers_it() -> void:
	_drive.steer(0.0, -1.0)
	_drive.drive(_orbit, 0.5)
	assert_almost_eq(_orbit.height, START_HEIGHT - LIFT_SPEED * 0.5, TOLERANCE)


func test_the_eye_cannot_be_driven_through_the_roof() -> void:
	_drive.steer(0.0, 1.0)
	for _frame: int in range(120):
		_drive.drive(_orbit, 1.0 / 60.0)
	assert_almost_eq(_orbit.height, HIGHEST, TOLERANCE, "two seconds of up is still the ceiling")


func test_the_eye_cannot_be_driven_through_the_floor() -> void:
	_drive.steer(0.0, -1.0)
	for _frame: int in range(120):
		_drive.drive(_orbit, 1.0 / 60.0)
	assert_almost_eq(_orbit.height, LOWEST, TOLERANCE)


func test_an_eye_that_starts_out_of_range_is_pulled_back_in() -> void:
	# The height is fenced every frame and not only when it changes: a scene that
	# hands the drive a camera already above the roof should be corrected by the
	# first frame rather than left up there until somebody presses something.
	var high: CameraOrbit = CameraOrbit.new(RADIUS, HIGHEST + 5.0, 0.0)
	_drive.drive(high, 1.0 / 60.0)
	assert_almost_eq(high.height, HIGHEST, TOLERANCE)


func test_two_sources_asking_for_the_same_thing_is_still_one_speed() -> void:
	# The pad's button and the keyboard's arrow are summed before they get here,
	# so a player holding both asks for 2.0. Walking twice as fast because you
	# used two hands is not a feature.
	_drive.steer(2.0, 0.0)
	assert_eq(_drive.turn, OrbitDrive.FULL_INPUT, "input is clamped, not trusted")
	_drive.drive(_orbit, 1.0)
	assert_almost_eq(_orbit.angle_degrees, TURN_SPEED, TOLERANCE)


func test_the_clamp_holds_in_both_directions_and_on_both_axes() -> void:
	_drive.steer(-9.0, -9.0)
	assert_eq(_drive.turn, -OrbitDrive.FULL_INPUT)
	assert_eq(_drive.lift, -OrbitDrive.FULL_INPUT)


func test_a_half_press_is_half_the_speed() -> void:
	# Nothing emits a fractional input today — the pad's buttons are on or off —
	# but the drive is the thing a stick or a swipe would arrive through later,
	# and it should already be a rate rather than a direction.
	_drive.steer(0.5, 0.5)
	_drive.drive(_orbit, 1.0)
	assert_almost_eq(_orbit.angle_degrees, TURN_SPEED * 0.5, TOLERANCE)
	assert_almost_eq(_orbit.height, START_HEIGHT + LIFT_SPEED * 0.5, TOLERANCE)


func test_the_radius_is_none_of_its_business() -> void:
	# The drive walks and lifts; how far off the car that leaves the eye is
	# [Standoff]'s job, and the two only meet in the garage. A drive that took the
	# radius on as well would be the class that has to know what shape a car is.
	_drive.steer(1.0, 1.0)
	_drive.drive(_orbit, 1.0)
	assert_eq(_orbit.radius, RADIUS, "the drive must not touch the radius")
