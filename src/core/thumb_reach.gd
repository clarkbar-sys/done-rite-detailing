## A press somewhere on the glass, turned into the two numbers a walk is made of
## — or into nothing at all, because it landed on the car and it is cleaning.
##
## [b]There is no stick on the screen any more, and this is what stands in its
## place.[/b] The frame is cut into two regions: a band one tap target thick all
## the way round the edge, and everything inside it. A press that lands in the
## band steers — the further out, the faster, and the corners of the frame walk
## and lift at once. A press that lands inside the middle aims the tool and holds
## the trigger, exactly as it always did, and moves the camera not at all.
##
## [b]The stick was a 328 px circle on a 720 px design[/b], parked in the
## bottom-right corner of every frame, on top of the room the player is trying to
## look at — and it cost some 490 lines of drawing and touch plumbing to hand over
## two floats. The band costs no pixels at all: the thing a thumb reaches for is
## the edge of the screen, which is the one landmark on a phone nobody has to be
## shown. It reports itself the only way that matters, by moving the camera.
##
## [b]The idea this is a specific version of is "press off-centre and go that
## way", and the reason it is a split rather than one field is worth writing
## down.[/b] The tempting version has every press do both at once: aim there
## [i]and[/i] drift that way. It does not work, because aim is a position and
## movement is a rate. Hold the wash on the rear quarter — over at the right-hand
## edge of the frame — and the camera turns right, which slides that panel toward
## the middle and out from under the finger; the finger cannot follow it, because
## the finger is the thing setting the speed. So the panel sails past centre and
## off the other side, and lining up on it becomes a rhythm of taps. That is the
## exact failure the four arrow buttons were retired for, in a new costume. Split
## in two, a steering press never fires and a firing press never steers, and
## neither one can chase the other.
##
## [b]Which job a press has is decided where it lands and then kept for the whole
## life of that finger.[/b] The band eats the outer edge of the frame, so a press
## cannot [i]start[/i] on the sill or the roofline — but a press that started in
## the middle can be dragged anywhere, including through the band and off the
## glass, and it goes on cleaning the whole way. Only the first instant has to be
## inside. The same rule the other way round is what makes "reach out, then come
## back" a gesture: a steering finger dragged into the middle goes quiet without
## letting go, so the player pulls the shot toward them and settles it without
## lifting a thumb.
##
## [b]That is also why there is no off switch, and why an empty tool would have
## been the wrong answer to the question.[/b] A press that both moved and fired
## would need one: the power wash takes product off as well as mud
## ([method Grime.wash]), so repositioning across a foamed wing would undo work
## the player had already been paid for. An empty slot on the belt would make
## that two taps out and two taps back, which is worse than the stick it replaced.
## Splitting the two jobs deletes the question instead of answering it.
##
## [b]The region is a rectangle and the ramp is per axis, which is the opposite of
## the rule the circle used, on purpose.[/b] A round stick has to measure its dead
## middle as a length and its direction before its strength, or a diagonal nudges
## through the deadzone and the corners ask for 1.41 of what an edge can. Here the
## quiet region genuinely is a rectangle — it is the frame inset by a border of
## even thickness — so each axis has its own dead extent and its own travel, and
## measuring them separately is the honest description rather than the bug. What
## does carry over is the clamp: the length is limited after the fact, so the
## corner of the frame asks for both axes at full and for no more in total than
## one axis alone could.
##
## [b]Node-free on purpose[/b] — the STANDARDS.md "Coverage" R3 rule, the same one
## [ThumbLift] and [TouchTarget] are here for. Every rule that decides what a
## press means — which region it is in, how the speed ramps out of the quiet one,
## the flip between screen space and input space — is arithmetic on two vectors,
## so it is a unit test rather than sixty frames of a scene with a finger dragged
## across it.
class_name ThumbReach
extends RefCounted

## The strongest a single axis can ask for. [constant OrbitDrive.FULL_INPUT] is
## the same number at the other end of the chain, which is what makes a thumb at
## the edge of the glass and a held arrow key exactly as fast as each other.
const FULL_INPUT: float = 1.0

## Walk left around the car. The vector is [code](turn, lift)[/code], the same
## pair [method input_from] returns, so a direction is literally the input it asks
## for rather than a code that has to be looked up somewhere else. The four outlive
## the stick that used to name them: they are still what a caller means by "left",
## and [method steer_point] turns one into a place on the glass.
const LEFT: Vector2i = Vector2i(-1, 0)

## Walk right around the car.
const RIGHT: Vector2i = Vector2i(1, 0)

## Raise the eye.
const UP: Vector2i = Vector2i(0, 1)

## Lower the eye.
const DOWN: Vector2i = Vector2i(0, -1)

## The four sides of the frame, in reading order for the pairs they make: the two
## that walk you round the car, then the two that move your eye. A corner of the
## screen is any two of them at once, which is a direction this control can express
## and four buttons never could.
const DIRECTIONS: Array[Vector2i] = [LEFT, RIGHT, UP, DOWN]

## How much of each axis stays a trigger no matter how thick the band is, as a
## fraction of the half-extent.
##
## The band is measured in pixels and the screen is not: a browser window can be
## short enough that a border a tap target thick from the top and another from the
## bottom would meet in the middle, leaving nothing to aim at and a camera that
## walks whenever the player touches the car. The floor keeps the middle half of
## every axis a trigger and lets the band be the thinner of the two things
## instead, which is the failure worth having — a shorter reach to full speed,
## rather than a game with no trigger in it.
const MIN_TRIGGER_FRACTION: float = 0.5


## How thick the steering band is, in design pixels.
##
## [method TouchTarget.min_design_size] — 164 design px today, about 13 mm on the
## narrowest screen the game targets. The same number the stick's radius was, and
## for the same reason: it is what this project has already decided "a finger can
## reliably hit this" means, and a movement control nobody can hit reads as a game
## that has frozen.
##
## [b]It is the one number here worth playing with.[/b] Thicker is a band that is
## easier to reach and less of the frame you can start a press in; thinner is the
## reverse, and the failure it buys is worse — a press meant for the mud near the
## edge of the car that walks the camera instead reads as a game that ignored you.
## So it errs on the generous side, and the drag rule above is what pays for it.
static func steer_band() -> float:
	return TouchTarget.min_design_size()


## How far from the middle of the glass a press can land and still be a trigger,
## per axis, given a screen [param half] the size of and a band [param band]
## thick.
##
## [param half] is half the screen, so these are half-extents too: the quiet
## region is the box they describe, centred on the glass. Public because it is the
## boundary every other function here is defined against, and because a caller
## that wants to know whether the band has been squeezed by
## [constant MIN_TRIGGER_FRACTION] can compare the two.
static func trigger_axes(half: Vector2, band: float) -> Vector2:
	return Vector2(_trigger_axis(half.x, band), _trigger_axis(half.y, band))


## Whether a press [param offset] from the middle of the glass is asking to move
## rather than to clean.
##
## The rule that decides which job a finger has, in one place, because two answers
## to "is this press mine" is the bug where the camera walks on the press that was
## meant to wash a wing. Outside the quiet box on [i]either[/i] axis: the band is a
## border, so its corners belong to it as much as its sides do.
##
## Exclusive at the boundary — a press exactly on the edge of the quiet box is a
## trigger — which is the friendlier way to round a line nobody can see: the worse
## mistake of the two is walking the camera on a press meant for the car.
##
## A screen with no width or no height has no band and no middle; nothing steers,
## which is the harmless answer for a control that has not been laid out yet.
static func steers(offset: Vector2, half: Vector2, band: float) -> bool:
	if half.x <= 0.0 or half.y <= 0.0:
		return false
	var trigger: Vector2 = trigger_axes(half, band)
	return absf(offset.x) > trigger.x or absf(offset.y) > trigger.y


## What a press [param offset] from the middle of the glass is asking for:
## [code](turn, lift)[/code], each in [code]-1..1[/code], the same pair the stick
## used to hand over and the same pair [method OrbitDrive.steer] reads.
##
## [b]The strength is measured from the edge of the quiet box, not from the middle
## of the screen.[/b] The naive version — distance over half the screen — would
## have the camera already moving at three quarters speed the instant a thumb
## crossed into the band, so there would be no slow setting at all. Rescaling the
## band's own thickness over the whole [code]0..1[/code] range means the first
## movement into it asks for almost nothing, which is what "nudge the shot round a
## bit" needs.
##
## [b]Both axes, then the clamp.[/b] Each is ramped over its own band, so a press
## in the middle of the right-hand edge is pure turn and one at the top is pure
## lift, and then the pair is limited as a vector: the corner of the frame walks
## and lifts at once, both at full, and cannot ask for more than an axis alone
## could. Clamping the components instead would make the corners of the screen
## faster than its sides.
##
## Dragging past the edge of the glass keeps the direction and pins the strength,
## which is not a curiosity: a thumb reaching for the edge of a phone goes off it
## constantly, and a control that fell quiet there would stop the camera for a
## movement the player did not mean as a stop.
##
## Y flips on the way out. Screen space has up at [code]-Y[/code]; input space —
## what [method OrbitDrive.steer] reads — has up at [code]+1[/code].
static func input_from(offset: Vector2, half: Vector2, band: float) -> Vector2:
	# Gated on `steers` rather than on the ramps falling to zero by themselves,
	# which they also would. One rule decides what a press is for, and this is a
	# reading of that rule rather than a second copy of it.
	if not steers(offset, half, band):
		return Vector2.ZERO
	var trigger: Vector2 = trigger_axes(half, band)
	var asked: Vector2 = Vector2(
		_ramp(offset.x, trigger.x, half.x), -_ramp(offset.y, trigger.y, half.y)
	)
	return asked.limit_length(FULL_INPUT)


## Where on the glass a press has to land to ask, at full strength, to go
## [param direction] — as an offset from the middle, on a screen [param half] the
## size of.
##
## The replacement for the stick's own [code]point_for()[/code], and the inverse
## of [method input_from]: full deflection is the edge of the frame itself, so
## [constant RIGHT] is the middle of the right-hand edge and
## [code]Vector2i(1, 1)[/code] is the top-right corner of the screen. Needs no
## band, because where the ramp [i]ends[/i] does not depend on where it started.
##
## [b]It names a place a press cannot quite land[/b], and that is the honest
## answer rather than an oversight: a [Control]'s rectangle excludes its far edge,
## so the outermost press the GUI will actually route is a pixel inside this. A
## drag can reach it and go past it, where [method input_from] pins the strength.
## Anything that needs a point a press can land on wants
## [method steer_point] instead.
##
## [constant Vector2i.ZERO] is the middle of the glass: no direction, which is the
## honest place to put a finger that is asking for nothing.
static func point_for(direction: Vector2i, half: Vector2) -> Vector2:
	return Vector2(float(direction.x) * half.x, -float(direction.y) * half.y)


## Where in the band a press asking to go [param direction] comfortably lands — an
## offset from the middle, halfway across the band on every axis
## [param direction] uses and dead centre on the ones it does not.
##
## What a caller that wants to steer for real should aim at, and what the tests
## press. Halfway rather than at the edge for two reasons: it is a place the GUI
## will route a press to, and it is where a player's thumb actually goes when they
## reach for the side of a screen — nobody aims at the last pixel of the glass.
## The axes the direction leaves alone stay at zero, so asking to turn is a turn
## and not a turn with a drift in it.
static func steer_point(direction: Vector2i, half: Vector2, band: float) -> Vector2:
	var across: Vector2 = (trigger_axes(half, band) + half) * 0.5
	return Vector2(float(direction.x) * across.x, -float(direction.y) * across.y)


## One axis of [method trigger_axes]: how far out the quiet region reaches on an
## axis that is [param half] long from the middle, with a band [param band] thick
## taken off it.
##
## A negative band is treated as none rather than as a band that grows the quiet
## region past the screen, which would put full deflection somewhere a finger
## cannot reach.
static func _trigger_axis(half: float, band: float) -> float:
	if half <= 0.0:
		return 0.0
	return maxf(half - maxf(band, 0.0), half * MIN_TRIGGER_FRACTION)


## One axis of the ask: how hard [param reach] from the middle is pushing, given
## that the quiet region ends at [param dead] and full deflection is at
## [param full], both measured from the middle and both positive.
##
## Signed by [param reach], so the direction comes out of the same arithmetic as
## the strength rather than out of a second branch that could disagree with it. A
## band with no thickness asks for nothing instead of dividing by zero — a NaN
## steering a camera takes the whole view with it rather than failing where it was
## made.
static func _ramp(reach: float, dead: float, full: float) -> float:
	var travel: float = full - dead
	if travel <= 0.0:
		return 0.0
	return clampf((absf(reach) - dead) / travel, 0.0, FULL_INPUT) * signf(reach)
