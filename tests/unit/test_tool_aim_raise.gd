## Unit tests for the other half of [ToolAim]: whether the tool is being aimed at
## all, and how long it takes to come up.
##
## [b]A second suite rather than six more tests in
## [code]test_tool_aim.gd[/code][/b], which is at [code].gdlintrc[/code]'s
## public-method cap — the same reason the play screen's suites are split by
## subject. The split falls in a sensible place: everything over there is about
## the two angles and the fence around them, and everything here is about the one
## number that says a finger is on the glass.
##
## [b]Why the number exists.[/b] "Aimed straight ahead" and "not aiming" are the
## same pair of zeroes, so [method ToolAim.is_raised] cannot tell them apart —
## which was fine while every tool was held at a fixed angle and is not fine now
## that [WandCarry] changes shape between the two. What is asserted below is that
## the raise knows the difference, and that it takes time to cross it: a tool that
## snapped between poses would read as a glitch for exactly the reason a hand that
## teleported to the touch would.
extends GutTest

## A ten-thousandth of a fraction. The servo lands exactly on its target, so this
## is float noise rather than slack.
const TOLERANCE: float = 0.0001

## Stand-ins for the room's exports, deliberately unlike the shipped numbers.
const YAW_LIMIT: float = 30.0
const PITCH_LIMIT: float = 20.0
const SWING_SPEED: float = 300.0

## One frame at 60 Hz — the delta [method ToolAim.advance] is really called with.
const FRAME: float = 1.0 / 60.0

var _aim: ToolAim = null


func before_each() -> void:
	_aim = ToolAim.new(YAW_LIMIT, PITCH_LIMIT, SWING_SPEED)


## Runs the aim for [param seconds] of frames.
func _run(seconds: float) -> void:
	for _frame: int in range(int(seconds / FRAME)):
		_aim.advance(FRAME)


## A direction in the camera's space at [param yaw] and [param pitch] degrees off
## straight ahead, built from the trig rather than asked of the class under test.
func _facing(yaw: float, pitch: float) -> Vector3:
	var yawed: float = deg_to_rad(yaw)
	var pitched: float = deg_to_rad(pitch)
	return Vector3(-sin(yawed) * cos(pitched), sin(pitched), -cos(yawed) * cos(pitched))


func test_a_new_aim_is_not_brought_up_at_all() -> void:
	assert_almost_eq(_aim.raise_amount(), 0.0, TOLERANCE, "nobody has pressed anything")
	assert_true(_aim.is_settled(), "and there is nothing for it to be on the way to")


func test_a_press_brings_the_tool_up_over_time_rather_than_at_once() -> void:
	# The whole reason this is a fraction and not a boolean: a tool that changed
	# shape between two frames reads as a glitch, exactly like a hand that teleports.
	_aim.aim_toward(_facing(0.0, 0.0))
	assert_almost_eq(_aim.raise_amount(), 0.0, TOLERANCE, "the press does not move it")
	_aim.advance(FRAME)
	var started: float = _aim.raise_amount()
	assert_gt(started, 0.0, "the frame after does")
	assert_lt(started, 1.0, "and it is not there yet")


func test_the_tool_arrives_fully_up_and_the_hand_settles() -> void:
	_aim.aim_toward(_facing(YAW_LIMIT, PITCH_LIMIT))
	_run(1.0)
	assert_almost_eq(_aim.raise_amount(), 1.0, TOLERANCE)
	assert_true(_aim.is_settled(), "a second is long enough for both")


func test_a_press_straight_ahead_still_brings_the_tool_up() -> void:
	# The case [method ToolAim.is_raised] cannot see, and the one this exists for:
	# aiming dead ahead is the same two angles as aiming at nothing, so a viewmodel
	# reading the angles alone would leave the tool lowered for the most common
	# press there is — the one at the middle of the car.
	_aim.aim_toward(ToolAim.REST)
	assert_eq(_aim.wanted_angles(), Vector2.ZERO, "no angle to swing through")
	assert_false(_aim.is_settled(), "and still something to do about it")
	_run(1.0)
	assert_almost_eq(_aim.raise_amount(), 1.0, TOLERANCE, "the tool came up anyway")
	assert_false(_aim.is_raised(), "which the angles alone would have called lowered")


func test_letting_go_puts_the_tool_back_down() -> void:
	_aim.aim_toward(_facing(YAW_LIMIT, 0.0))
	_run(1.0)
	_aim.lower()
	assert_almost_eq(_aim.raise_amount(), 1.0, TOLERANCE, "still up on the frame it lifted")
	assert_false(_aim.is_settled(), "and on its way down")
	_run(1.0)
	assert_almost_eq(_aim.raise_amount(), 0.0, TOLERANCE, "back down")
	assert_true(_aim.is_settled())


func test_letting_go_half_way_up_turns_round_where_it_is() -> void:
	# The same servo shape as the angles: one code path for up and down, so a
	# release mid-raise cannot leave the tool somewhere [method ToolAim.advance]
	# will not take it out of.
	_aim.aim_toward(_facing(0.0, 0.0))
	_aim.advance(FRAME * 3.0)
	var mid_raise: float = _aim.raise_amount()
	_aim.lower()
	_aim.advance(FRAME)
	assert_lt(_aim.raise_amount(), mid_raise, "it turned round rather than carrying on up")
	assert_gt(_aim.raise_amount(), 0.0, "and did not snap down either")
