## A thumb on the glass, turned into movement around a [CameraOrbit].
##
## The mobile-first control scheme is one thumb on the glass — reach toward the
## left or right edge to walk around the car, toward the top or bottom to raise and
## lower your eye — and this is everything that scheme means once the geometry is
## out of the way: two numbers in [code]-1..1[/code], and what a second of holding
## them does to an orbit. It was a drawn thumb stick before that and four
## hold-to-move buttons before that, and this file did not change for either, which
## is the point of it taking numbers rather than presses.
##
## [b]Node-free on purpose[/b] — the STANDARDS.md "Coverage" R3 rule. Holding
## right for a second is a single call here rather than sixty frames of a real
## scene, so the things worth pinning (that the speed is per-second and not
## per-frame, that the eye cannot be driven through the roof, that letting go
## stops it dead) are unit tests.
##
## [b]Why it drives a [CameraOrbit] rather than being one.[/b] The orbit already
## knows how to advance an angle and where that puts an eye, and the title
## screen's slow circuit uses exactly that with nobody's thumb involved. What is
## new here is only that the speed now comes from a player, so this sets the
## speed and lets the orbit do the arithmetic it already had.
class_name OrbitDrive
extends RefCounted

## The strongest a single axis of input can be, and the same number
## [constant ThumbReach.FULL_INPUT] is at the other end of the chain. Two opposing
## asks — the left arrow key held while a thumb is in the right-hand band — cancel
## to zero rather than fighting, which falls out of the sum the screen hands over
## and is asserted rather than assumed.
const FULL_INPUT: float = 1.0

## How fast holding left or right walks the eye around the car, in degrees per
## second at full input.
var turn_degrees_per_second: float = 0.0

## How fast holding up or down raises or lowers the eye, in metres per second at
## full input.
var lift_metres_per_second: float = 0.0

## The lowest the eye may be driven, measured the way [member CameraOrbit.height]
## is — above the point being circled, not above the floor.
var min_height: float = 0.0

## The highest the eye may be driven, same units.
var max_height: float = 0.0

## Which way the player is asking to walk: [code]-1[/code] for hard left,
## [code]+1[/code] for hard right, [code]0[/code] for a thumb that is off the
## glass or resting in the middle of it, and anything in between for one that has
## reached part way out.
var turn: float = 0.0

## Which way the player is asking to move their eye: [code]+1[/code] up,
## [code]-1[/code] down.
var lift: float = 0.0


## No defaults, for the same reason [CameraOrbit] has none: the tuning numbers
## belong to the scene that owns the camera, where they are [code]@export[/code]s
## somebody can see and change. A second set of answers here would drift from
## the first.
func _init(
	turn_speed: float, lift_speed: float, lowest_height: float, highest_height: float
) -> void:
	turn_degrees_per_second = turn_speed
	lift_metres_per_second = lift_speed
	min_height = lowest_height
	max_height = highest_height


## Takes the player's current intent, clamped so no input source can ask to go
## faster than a button can.
##
## Clamped rather than trusted because the intents are summed before they get
## here — a thumb in the steering band and the keyboard's arrows are two ways to
## ask for the same thing, and a player holding both should walk at one speed
## rather than at two.
func steer(turn_input: float, lift_input: float) -> void:
	turn = clampf(turn_input, -FULL_INPUT, FULL_INPUT)
	lift = clampf(lift_input, -FULL_INPUT, FULL_INPUT)


## Moves [param orbit] by [param delta] seconds of whatever is being held.
##
## Zero input is a real answer and not a special case: it writes a speed of zero
## onto the orbit, so letting go stops the camera on the frame it happened
## instead of leaving it coasting at whatever it was last told.
##
## The height is clamped every frame rather than only when it changes, because
## the fence is about where the eye may [i]be[/i] — an orbit handed a starting
## height outside the range should be pulled back into the room by the first
## frame, not left out there until somebody presses something.
func drive(orbit: CameraOrbit, delta: float) -> void:
	orbit.degrees_per_second = turn * turn_degrees_per_second
	orbit.advance(delta)
	orbit.height = clampf(
		orbit.height + lift * lift_metres_per_second * delta, min_height, max_height
	)
