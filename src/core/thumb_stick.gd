## A thumb somewhere inside a circle, turned into the two numbers a walk is made
## of.
##
## This is the whole of the on-screen stick once the drawing and the touch
## plumbing are out of the way: given where the finger is relative to the middle
## of the circle, how hard is the player asking to walk and to lift. [MotionPad]
## owns the circle, the finger and the pixels; this owns the mapping.
##
## [b]It replaces four buttons, and the shape of the answer is why.[/b] The pad
## used to be four hold-to-move arrows, and four arrows can only ever say
## [code]-1[/code], [code]0[/code] or [code]+1[/code] — full speed or nothing, one
## axis at a time unless two thumbs are on the glass. A circle says every value in
## between, and says both axes at once from one thumb, which is what makes
## "shuffle a few degrees round the wing" a thing a player can do at all.
## [OrbitDrive] already took its input as [code]-1..1[/code] rather than as
## button presses, so nothing downstream of here had to change to gain that.
##
## [b]Node-free on purpose[/b] — the STANDARDS.md "Coverage" R3 rule, the same one
## [ThumbLift] and [TouchTarget] are here for. Every rule that decides what the
## stick reports — the dead middle, the clamp at the rim, the flip between screen
## space and input space — is arithmetic on two vectors, so it is a unit test
## rather than sixty frames of a scene with a finger dragged across it.
class_name ThumbStick
extends RefCounted

## The strongest a single axis can ask for. [constant OrbitDrive.FULL_INPUT] is
## the same number at the other end of the chain, which is what makes a thumb at
## the rim and a held arrow key exactly as fast as each other.
const FULL_INPUT: float = 1.0

## How much of the middle of the circle asks for nothing, as a fraction of the
## radius.
##
## [b]A resting thumb is not a still thumb.[/b] The contact patch is about 10 mm
## across ([TouchTarget] has where that number comes from), the reported point is
## its centroid, and that centroid wanders by a millimetre or two while a hand
## does nothing in particular. Without a dead middle the camera creeps whenever a
## thumb is parked on the glass, and creeping is the exact failure the arrows were
## built to be immune to — so the circle has to buy that immunity back somewhere,
## and here is the cheap place.
##
## A fifth of the radius is about 2.5 mm on the narrowest screen this game
## targets, which covers the wander with room to spare and still leaves four
## fifths of the travel to be analogue in. It is a fraction rather than a
## millimetre count because the radius is itself derived from
## [method TouchTarget.min_design_size] — one number moves and the dead middle
## moves with it, in proportion, rather than becoming most of a smaller stick.
const DEAD_FRACTION: float = 0.2


## How far from the middle a finger has to get before the stick hears it, in the
## same units [param radius] is in.
static func dead_radius(radius: float) -> float:
	return radius * DEAD_FRACTION


## Whether a finger [param offset] from the middle of a circle of [param radius]
## has landed on the stick at all.
##
## The grab rule, in one place, because two answers to "is this touch mine" is the
## bug where the pad claims a press the screen also aims with. Inclusive at the
## rim: a touch exactly on the edge belongs to the stick, which is the friendlier
## way to round a boundary nobody can see the far side of.
static func holds(offset: Vector2, radius: float) -> bool:
	return radius > 0.0 and offset.length() <= radius


## What a finger [param offset] from the middle of a circle of [param radius] is
## asking for: [code](turn, lift)[/code], each in [code]-1..1[/code], the same pair
## the four arrows used to hand over.
##
## [b]The strength is measured from the edge of the dead middle, not from the
## centre.[/b] The naive version — [code]reach / radius[/code], zeroed below the
## deadzone — jumps from nothing to a fifth of full speed the instant the thumb
## clears the dead middle, and a control that starts at a fifth of full speed is a
## control with no slow setting. Rescaling the remaining travel over the whole
## [code]0..1[/code] range means the first movement out of the middle asks for
## almost nothing, which is what "nudge it round a bit" needs.
##
## [b]That rescaled travel is then squared, not handed over straight.[/b]
## [OrbitDrive]'s top speed ([member OrbitDrive.turn_degrees_per_second] and
## [member OrbitDrive.lift_metres_per_second]) is tuned for a thumb at the rim, and
## raising that number to make the rim faster would, on a straight
## [code]reach / radius[/code] line, make every partial deflection faster by the
## same fraction — the fine end of "line up on a wing" getting less fine every time
## the top end gets more urgent. Squaring the normalised strength instead means a
## thumb halfway out asks for a quarter of full, not half, so raising the number at
## the rim can raise the rim's speed without also speeding up the nudge that was
## already fine at the old number.
##
## [b]The direction is taken before the strength is clamped[/b], so a diagonal is
## a diagonal at full strength rather than at [code]1.41[/code]: the corner of the
## circle asks to walk and lift at once, both at full, and cannot ask for more
## than an axis alone can. Dragging past the rim keeps the direction and pins the
## strength, so the thumb can leave the circle without the stick going quiet — a
## stick that dropped to nothing when the finger slid off its edge is the same
## camera-stops-for-no-reason failure as a press that never arrives.
##
## Y flips on the way out. Screen space has up at [code]-Y[/code]; input space —
## what [method OrbitDrive.steer] reads, and what [constant MotionPad.UP] says —
## has up at [code]+1[/code].
##
## A radius of zero or less cannot happen in a laid-out pad and would divide by
## zero if it did, so it asks for nothing: the camera holds still, which is the
## harmless answer.
static func input_from(offset: Vector2, radius: float) -> Vector2:
	var dead: float = dead_radius(radius)
	var reach: float = offset.length()
	if radius <= 0.0 or reach <= dead:
		return Vector2.ZERO
	var linear: float = minf((reach - dead) / (radius - dead), FULL_INPUT)
	var strength: float = linear * linear
	var facing: Vector2 = offset / reach
	return Vector2(facing.x, -facing.y) * strength


## Where the knob is drawn for a finger [param offset] from the middle, in screen
## space and still relative to the middle.
##
## The knob follows the finger rather than the input: inside the circle it sits
## exactly under the thumb, including inside the dead middle, where the stick is
## reporting nothing. That looks like a lie and is the opposite — the player can
## see the knob has moved and the camera has not, which is how a dead middle
## explains itself without a word of UI text. Past the rim it stops at the rim,
## because that is where the input stopped too.
static func knob_from(offset: Vector2, radius: float) -> Vector2:
	if radius <= 0.0:
		return Vector2.ZERO
	return offset.limit_length(radius)
