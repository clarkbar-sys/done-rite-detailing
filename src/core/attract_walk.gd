## The demo's thumb: how hard to push the walk to bring the eye round to the bit
## of car the attract mode is about to work on.
##
## [b]It pushes the stick rather than moving the camera[/b], and that is the whole
## design. A player walks around the car by handing [method Garage.steer] two
## numbers in [code]-1..1[/code]; so does this, through the same call, into the
## same [OrbitDrive], onto the same [CameraOrbit], with the same [Standoff]
## hugging the same bodywork. Nothing about the camera behaves differently
## because nobody is watching — the attract mode is not allowed to show a shot the
## game cannot produce, and the way to guarantee that is to give it no way of
## asking for one.
##
## [b]Proportional inside an easing band, saturated outside it.[/b] Full push
## until the eye is within [code]ease[/code] of where it is going, then a push
## that falls off to nothing as it arrives. A bang-bang controller — full one way
## or full the other — would be one line shorter and would sit on the target
## juddering left and right forever, which is the single most obvious way for a
## camera to announce that it is being driven by a script.
##
## [b]It has no memory and no clock.[/b] Every answer is a function of where the
## eye is now and where the work is now, so there is nothing to reset when the
## demo skips to another panel and nothing to drift when a frame is long. The
## seconds belong to [OrbitDrive], which is already the thing that turns a held
## push into metres and degrees.
##
## Node-free (STANDARDS.md "Coverage" R3), so easing onto a target is a loop in a
## unit test rather than a camera somebody watched.
class_name AttractWalk
extends RefCounted

## The hardest either axis can be pushed, and the same number
## [constant OrbitDrive.FULL_INPUT] clamps to at the other end of the chain. The
## clamp is done here as well as there because a caller should be able to trust
## what comes out of this class without knowing what happens to it next.
const FULL_INPUT: float = 1.0

## Half a turn, in degrees — the furthest apart two angles on a circle can be
## once you are allowed to go either way round. Derived from
## [constant CameraOrbit.FULL_TURN] rather than written as 180, because there is
## exactly one place in this project that says how many degrees a circle has.
const HALF_TURN: float = CameraOrbit.FULL_TURN * 0.5


## How hard to walk to bring an eye at [param angle_degrees] round to
## [param target_degrees], easing off inside [param ease_degrees] of it.
##
## [b]The short way round, always.[/b] The error is wrapped into
## [code]±[/code][constant HALF_TURN] before it is used, so an eye at 350° sent to
## 10° walks 20° forward rather than 340° back. Without that the demo would
## occasionally take the long way round the car for no reason a viewer could see,
## which reads as the camera losing its place.
static func turn_toward(angle_degrees: float, target_degrees: float, ease_degrees: float) -> float:
	return _push(wrapf(target_degrees - angle_degrees, -HALF_TURN, HALF_TURN), ease_degrees)


## How hard to raise or lower an eye at [param height] to bring it to
## [param target_height], easing off inside [param ease_metres].
##
## Both heights are measured the way [member CameraOrbit.height] is — above the
## thing being circled, not above the floor — because that is what the number
## being steered actually means. Converting from floor height is the room's job,
## and it is the room that has the floor.
static func lift_toward(height: float, target_height: float, ease_metres: float) -> float:
	return _push(target_height - height, ease_metres)


## [param error] turned into a push, easing off over the last [param ease] of it.
##
## A band of zero or less is not an error and does not divide by anything: it is
## the honest request for "no easing at all", and what that means is full push
## right up to the target and nothing on it. [method signf] is exactly that, and
## it answers [code]0[/code] on the target rather than picking a side.
static func _push(error: float, ease: float) -> float:
	if ease <= 0.0:
		return signf(error)
	return clampf(error / ease, -FULL_INPUT, FULL_INPUT)
