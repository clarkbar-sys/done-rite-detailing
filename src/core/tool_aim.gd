## Where the tool in the player's hands is pointed, as two angles that ease
## toward what the player asked for and fall back to rest when they let go.
##
## The player presses somewhere on the glass, the room turns that into a
## direction in the camera's own space, and this turns the direction into a yaw
## and a pitch for the hand to swing through. Nothing here has heard of a
## camera, a mesh or a finger — it is two angles, a fence around them and a
## speed limit — which is what lets a whole swing be a unit test instead of a
## second and a half of real frames. Same tier rule as [CameraOrbit] and
## [Standoff]: STANDARDS.md "Coverage" (R3).
##
## [b]The hand swings; it does not teleport.[/b] A press across the screen is an
## instantaneous jump in the direction asked for, and a tool that snapped to it
## would read as a glitch rather than as an arm moving. So the target is set at
## once and [method advance] walks the held angles toward it at
## [member swing_degrees_per_second] — the same servo shape [Standoff] uses for
## the camera's radius, and for the same reason.
##
## [b]The fence is not decoration.[/b] The held tool hangs 0.45 m off the lens
## and the room keeps the eye [member Garage.standoff_metres] off the bodywork
## partly to stop that tool ending up inside the paint — a clearance the garage's
## own docs record as measured rather than hoped for. Swinging the hand moves
## every one of those corners, so an unfenced aim would quietly re-open a
## question that was expensive to close. [member yaw_limit_degrees] and
## [member pitch_limit_degrees] are what keep the swing inside the budget, and
## [code]tests/integration/test_play_screen_aim.gd[/code] holds the clearance at
## the corners of the cone rather than at the rest pose.
##
## [b]Rest is straight ahead, and rest is a target like any other.[/b] Letting go
## does not snap the hand back either — [method lower] just aims it at
## [constant REST] and the same servo carries it home. One code path for "aim
## there" and "stop aiming", so a release can never leave the hand somewhere
## [method advance] will not take it out of.
class_name ToolAim
extends RefCounted

## Degrees to radians, for [method orientation]. Degrees on the outside because
## that is what a person tuning a swing thinks in — exactly like
## [member ViewModel.PER_DEGREE] and [member Garage.start_angle_degrees].
const PER_DEGREE: float = PI / 180.0

## Where the hand points when nobody is aiming it: straight down the camera's
## own [code]-Z[/code], which is the pose [code]garage.tscn[/code] parks the
## anchor in.
const REST: Vector3 = Vector3(0.0, 0.0, -1.0)

## How far the hand may swing left or right of [constant REST], in degrees.
var yaw_limit_degrees: float

## How far it may swing up or down. Tighter than the yaw on purpose: a car is
## wide and low, so the useful spread is horizontal, and pitch is the axis that
## puts a wand through the roof or into the tarmac.
var pitch_limit_degrees: float

## How fast the hand swings toward what it was asked for, in degrees per second.
var swing_degrees_per_second: float

var _held: Vector2 = Vector2.ZERO
var _wanted: Vector2 = Vector2.ZERO


func _init(yaw_limit: float, pitch_limit: float, swing_speed: float) -> void:
	yaw_limit_degrees = absf(yaw_limit)
	pitch_limit_degrees = absf(pitch_limit)
	swing_degrees_per_second = maxf(swing_speed, 0.0)


## The yaw and pitch, in degrees, that point a hand along [param direction] —
## which is read in the camera's own space, where [code]-Z[/code] is into the
## screen, [code]+X[/code] is the right of the frame and [code]+Y[/code] is up.
##
## Static and fenceless: this is the arithmetic of turning a direction into two
## angles, and it is separately useful to a test that wants to know what a
## direction [i]would[/i] ask for before the limits below have had their say.
## A zero-length direction asks for nothing rather than for a NaN.
static func angles_for(direction: Vector3) -> Vector2:
	var facing: Vector3 = direction.normalized()
	if facing == Vector3.ZERO:
		return Vector2.ZERO
	# `atan2(-x, -z)` rather than the usual `(y, x)`: yaw here turns the -Z of
	# [constant REST] toward the direction, so both arguments are negated. Pitch
	# is an `asin` of the height because the direction is already unit length,
	# and the clamp is against float drift pushing it a hair past 1.
	return Vector2(
		rad_to_deg(atan2(-facing.x, -facing.z)), rad_to_deg(asin(clampf(facing.y, -1.0, 1.0)))
	)


## Asks the hand to point along [param direction], in the camera's space.
##
## Recorded as a want and not as a fact: [method advance] is what moves the hand,
## so a finger dragged across the glass keeps re-stating the target while the
## swing chases it, which is exactly the behaviour a drag should have.
func aim_toward(direction: Vector3) -> void:
	_wanted = fenced(angles_for(direction))


## Lets go: the hand is asked for [constant REST] and gets there at the same
## speed it left.
func lower() -> void:
	_wanted = Vector2.ZERO


## Moves the held angles [param delta] seconds' worth toward what was asked for.
##
## [method Vector2.move_toward] rather than a per-axis step, so the pair travels
## in a straight line through angle-space and the hand takes one path to the
## target instead of finishing its yaw before starting its pitch — which reads
## as a hand that shrugs and then nods.
func advance(delta: float) -> void:
	_held = _held.move_toward(_wanted, swing_degrees_per_second * delta)


## The angles the hand is actually at, as [code](yaw, pitch)[/code] in degrees.
func held_angles() -> Vector2:
	return _held


## The angles it is on its way to. Equal to [method held_angles] once the swing
## has arrived.
func wanted_angles() -> Vector2:
	return _wanted


## Whether the swing has arrived, so a caller can stop paying for it.
func is_settled() -> bool:
	return _held.is_equal_approx(_wanted)


## Whether the hand is pointed anywhere other than straight ahead — which is the
## honest test for "is this thing aiming", since [method lower] is only a target
## like any other and the hand is still swinging home for a moment after it.
func is_raised() -> bool:
	return not _held.is_zero_approx()


## The held angles as a rotation for the hand's anchor.
##
## [code]YXZ[/code] is [method Basis.from_euler]'s own default order, and it is
## the one [method angles_for] inverts: yaw about [code]Y[/code] first, then
## pitch about the yawed [code]X[/code]. Any other order would send the hand
## somewhere other than where the finger is, and only off-axis — which is the
## kind of wrong that looks like a tuning problem for a week.
func orientation() -> Basis:
	return Basis.from_euler(Vector3(_held.y, _held.x, 0.0) * PER_DEGREE)


## Where the hand currently points, in the camera's space. The inverse of
## [method angles_for], and what a test asserts on rather than trusting the two
## numbers to mean what they say.
##
## Not [code]direction()[/code], which is what it wants to be called: every
## function above takes a parameter by that name, and a parameter that shadows a
## method in the same class is a compile error under this project's warning
## levels rather than a style note.
func pointing() -> Vector3:
	return orientation() * REST


## [param angles], brought inside the fence.
##
## Per-axis rather than by shrinking the pair toward zero: the two limits are
## different numbers because they are answers to different questions (see
## [member pitch_limit_degrees]), and scaling both by whichever one bound first
## would make a hard-left press also aim high.
func fenced(angles: Vector2) -> Vector2:
	return Vector2(
		clampf(angles.x, -yaw_limit_degrees, yaw_limit_degrees),
		clampf(angles.y, -pitch_limit_degrees, pitch_limit_degrees)
	)
