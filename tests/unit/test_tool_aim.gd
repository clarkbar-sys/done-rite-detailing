## Unit tests for [ToolAim] — the two angles the held tool swings through when
## the player presses the glass.
##
## Under tests/unit/ because a [ToolAim] is a [RefCounted] that has never heard
## of a camera, a mesh or a finger: it is handed a direction and returns a
## rotation, so a full swing across the cone is a `for` loop here instead of a
## fifth of a second of real frames. That a real press really does produce a real
## direction, and that the hand it turns really does stay out of the paint, is
## [code]tests/integration/test_play_screen_aim.gd[/code]'s job.
extends GutTest

## A ten-thousandth of a degree, or of a component of a unit vector. Angles here
## are the results of trig round trips, so this is float64 noise rather than
## slack for a wrong answer.
const TOLERANCE: float = 0.0001

## Stand-ins for the room's exports, deliberately different from each other and
## from the shipped numbers, so a swapped argument fails instead of cancelling
## out.
const YAW_LIMIT: float = 30.0
const PITCH_LIMIT: float = 20.0
const SWING_SPEED: float = 300.0

## One frame at 60 Hz — the delta [method ToolAim.advance] is really called with.
const FRAME: float = 1.0 / 60.0

var _aim: ToolAim = null


func before_each() -> void:
	_aim = ToolAim.new(YAW_LIMIT, PITCH_LIMIT, SWING_SPEED)


## Runs the swing for [param seconds] and hands back where it got to.
func _swing(seconds: float) -> Vector2:
	var frames: int = int(seconds / FRAME)
	for _frame: int in range(frames):
		_aim.advance(FRAME)
	return _aim.held_angles()


## A direction in the camera's space at [param yaw] and [param pitch] degrees off
## straight ahead. Built by hand from the trig rather than by asking [ToolAim]
## for it, so the tests below are not checking a function against itself.
func _facing(yaw: float, pitch: float) -> Vector3:
	var yawed: float = deg_to_rad(yaw)
	var pitched: float = deg_to_rad(pitch)
	return Vector3(
		-sin(yawed) * cos(pitched),
		sin(pitched),
		-cos(yawed) * cos(pitched),
	)


# ---- what it starts as -------------------------------------------------------


func test_it_starts_where_it_was_built() -> void:
	assert_eq(_aim.yaw_limit_degrees, YAW_LIMIT)
	assert_eq(_aim.pitch_limit_degrees, PITCH_LIMIT)
	assert_eq(_aim.swing_degrees_per_second, SWING_SPEED)


func test_a_new_aim_is_at_rest() -> void:
	assert_eq(_aim.held_angles(), Vector2.ZERO, "nobody has pressed anything yet")
	assert_true(_aim.is_settled(), "and there is nothing for it to be on the way to")
	assert_false(_aim.is_raised(), "so the hand is down")


func test_rest_points_straight_down_the_lens() -> void:
	# The pose `garage.tscn` parks the anchor in. If this is ever not the identity
	# the five held poses in [ViewModel] are all being applied on top of a turn
	# nobody asked for.
	assert_almost_eq(_aim.pointing(), ToolAim.REST, Vector3.ONE * TOLERANCE)


## A negative limit is a limit, not a fence that excludes everything. Worth
## pinning because the alternative — clamping between +30 and -30, in that order
## — silently returns the wrong bound rather than erroring.
func test_the_limits_are_read_as_magnitudes() -> void:
	var backwards: ToolAim = ToolAim.new(-YAW_LIMIT, -PITCH_LIMIT, -SWING_SPEED)
	assert_eq(backwards.yaw_limit_degrees, YAW_LIMIT)
	assert_eq(backwards.pitch_limit_degrees, PITCH_LIMIT)
	assert_eq(backwards.swing_degrees_per_second, 0.0, "a speed cannot be negative")


# ---- turning a direction into two angles -------------------------------------


func test_straight_ahead_asks_for_nothing() -> void:
	assert_almost_eq(ToolAim.angles_for(ToolAim.REST), Vector2.ZERO, Vector2.ONE * TOLERANCE)


## The sign that is easiest to get backwards, and the one whose failure looks
## like a bug in the raycast: a tool swinging to the opposite side of the car
## from the finger.
##
## Rightward is a [i]negative[/i] yaw, and that is the engine's convention rather
## than a choice made here — a positive rotation about [code]+Y[/code] turns
## anticlockwise seen from above, which takes the camera's [code]-Z[/code] toward
## [code]-X[/code], which is the left of the frame.
func test_a_direction_to_the_right_of_the_frame_asks_for_a_negative_yaw() -> void:
	assert_lt(ToolAim.angles_for(Vector3(1.0, 0.0, -1.0)).x, 0.0, "+X is the right of the frame")
	assert_gt(ToolAim.angles_for(Vector3(-1.0, 0.0, -1.0)).x, 0.0, "and -X is the left of it")


func test_a_direction_upward_asks_for_a_positive_pitch() -> void:
	assert_gt(ToolAim.angles_for(Vector3(0.0, 1.0, -1.0)).y, 0.0)
	assert_lt(ToolAim.angles_for(Vector3(0.0, -1.0, -1.0)).y, 0.0)


func test_every_angle_in_the_cone_survives_the_round_trip() -> void:
	# The pair of conversions is the whole contract: a direction becomes two
	# angles, the angles become a rotation, and the rotation had better point back
	# where it came from. Swept rather than sampled once, because a wrong Euler
	# order agrees with the right one on both axes separately and only diverges
	# when they are used together.
	for yaw: float in [-30.0, -12.0, 0.0, 7.0, 25.0]:
		for pitch: float in [-20.0, -5.0, 0.0, 11.0, 19.0]:
			var wanted: Vector3 = _facing(yaw, pitch)
			_aim.aim_toward(wanted)
			_swing(1.0)
			assert_almost_eq(
				_aim.pointing(),
				wanted,
				Vector3.ONE * TOLERANCE,
				"aimed at yaw %.0f pitch %.0f" % [yaw, pitch]
			)


func test_a_direction_of_nothing_asks_for_nothing() -> void:
	# Not a real press — but `project_ray_normal` is a normalisation away from
	# this, and the alternative to answering is a NaN that propagates into a
	# transform and takes the whole viewmodel off screen.
	assert_eq(ToolAim.angles_for(Vector3.ZERO), Vector2.ZERO)


# ---- the fence ---------------------------------------------------------------


func test_the_fence_holds_on_both_sides_of_both_axes() -> void:
	_aim.aim_toward(_facing(80.0, 0.0))
	assert_almost_eq(_aim.wanted_angles().x, YAW_LIMIT, TOLERANCE, "just past the edge")
	# And a long way past it, on every side. A clamp written the wrong way round
	# passes the gentle case and returns the opposite bound for these.
	for yaw: float in [-170.0, 170.0]:
		for pitch: float in [-70.0, 70.0]:
			_aim.aim_toward(_facing(yaw, pitch))
			var wanted: Vector2 = _aim.wanted_angles()
			assert_almost_eq(absf(wanted.x), YAW_LIMIT, TOLERANCE, "yaw %.0f" % yaw)
			assert_almost_eq(absf(wanted.y), PITCH_LIMIT, TOLERANCE, "pitch %.0f" % pitch)


## The two axes are fenced independently — see [method ToolAim.fenced]. A press
## hard left and barely up must not come back aimed hard left and hard up.
func test_one_axis_hitting_its_limit_leaves_the_other_alone() -> void:
	_aim.aim_toward(_facing(80.0, 5.0))
	var wanted: Vector2 = _aim.wanted_angles()
	assert_almost_eq(wanted.x, YAW_LIMIT, TOLERANCE, "the yaw is fenced")
	assert_almost_eq(wanted.y, 5.0, TOLERANCE, "and the pitch is left where it was asked for")


func test_the_hand_never_leaves_the_cone_mid_swing() -> void:
	# Not just where it lands: every frame on the way there is a frame the player
	# can see, and the clearance the cone protects is a clearance at all of them.
	_aim.aim_toward(_facing(80.0, 70.0))
	for _frame: int in range(60):
		_aim.advance(FRAME)
		var held: Vector2 = _aim.held_angles()
		assert_lte(absf(held.x), YAW_LIMIT + TOLERANCE)
		assert_lte(absf(held.y), PITCH_LIMIT + TOLERANCE)


# ---- the swing ---------------------------------------------------------------


func test_asking_does_not_move_the_hand() -> void:
	_aim.aim_toward(_facing(YAW_LIMIT, 0.0))
	assert_eq(_aim.held_angles(), Vector2.ZERO, "the target is set")
	assert_false(_aim.is_settled(), "and the hand has not arrived at it")


func test_the_hand_arrives_at_what_was_asked_for() -> void:
	_aim.aim_toward(_facing(YAW_LIMIT, PITCH_LIMIT))
	_swing(1.0)
	assert_true(_aim.is_settled(), "a second is long enough for a 300 deg/s swing")
	assert_almost_eq(_aim.held_angles(), _aim.wanted_angles(), Vector2.ONE * TOLERANCE)


func test_the_swing_takes_the_time_the_speed_says() -> void:
	# `move_toward` travels the straight line between the two angle pairs at a
	# constant rate, so the distance covered is the speed times the time — and at
	# 300 deg/s, three frames of 60 Hz is 15 degrees of a 30 degree swing.
	#
	# Counted in whole frames rather than in seconds: [method _swing] can only run
	# an integer number of them, so asking for "a quarter of the time" gets a
	# quarter rounded down to the nearest frame, and the test would be measuring
	# its own rounding.
	_aim.aim_toward(_facing(YAW_LIMIT, 0.0))
	var halfway: float = SWING_SPEED * FRAME * 3.0
	assert_almost_eq(_swing(FRAME * 3.0).x, halfway, TOLERANCE, "three frames in")
	assert_almost_eq(halfway, YAW_LIMIT * 0.5, TOLERANCE, "which is half of this swing")
	assert_false(_aim.is_settled(), "and not there yet")


func test_a_drag_is_a_target_that_keeps_moving() -> void:
	# What a finger sliding across the glass actually does: re-state the target
	# every tick while the swing is still chasing the last one.
	_aim.aim_toward(_facing(-YAW_LIMIT, 0.0))
	_swing(0.02)
	_aim.aim_toward(_facing(YAW_LIMIT, 0.0))
	assert_almost_eq(_aim.wanted_angles().x, YAW_LIMIT, TOLERANCE, "the target moved")
	_swing(1.0)
	assert_almost_eq(_aim.held_angles().x, YAW_LIMIT, TOLERANCE, "and the hand followed it")


# ---- letting go --------------------------------------------------------------


func test_letting_go_brings_the_hand_home() -> void:
	_aim.aim_toward(_facing(YAW_LIMIT, PITCH_LIMIT))
	_swing(1.0)
	_aim.lower()
	_swing(1.0)
	assert_almost_eq(_aim.held_angles(), Vector2.ZERO, Vector2.ONE * TOLERANCE)
	assert_false(_aim.is_raised(), "the hand is down")


func test_letting_go_does_not_snap_the_hand_home() -> void:
	# The release is a target like any other — see the class docs. A hand that
	# teleported back to rest on release would read as the tool being dropped.
	_aim.aim_toward(_facing(YAW_LIMIT, PITCH_LIMIT))
	_swing(1.0)
	_aim.lower()
	assert_true(_aim.is_raised(), "still up on the frame the finger lifted")
	assert_false(_aim.is_settled(), "and on its way down rather than already there")


func test_letting_go_before_the_hand_arrived_is_not_a_jump() -> void:
	_aim.aim_toward(_facing(YAW_LIMIT, 0.0))
	_swing(0.02)
	var mid_swing: Vector2 = _aim.held_angles()
	_aim.lower()
	_aim.advance(FRAME)
	assert_lt(absf(_aim.held_angles().x), absf(mid_swing.x), "it turned round where it was")
