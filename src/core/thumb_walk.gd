## A thumb drawn from the middle of the screen toward an edge, turned into the
## decision the play screen has to make sixty times a second: is this finger
## still aiming the tool, or has it left to walk?
##
## This replaces the motion pad — the circle that used to own the bottom-right
## corner — with no furniture at all: the same finger that scrubs a panel walks
## the eye, by travelling far enough from the centre of the screen. What this
## class owns is the boundary between those two readings and the walk vector on
## the far side of it; the events, the vetos and the pixels stay in
## [code]src/screens/play_screen.gd[/code] — the same split the stick's
## arithmetic (a class called ThumbStick, deleted with the pad) used to make
## against the circle that drew it, with the rescale idiom carried over (see
## [method input]).
##
## [b]The boundary is an ellipse in the screen's own shape, not a circle in
## pixels.[/b] Everything is measured as [method rho]: the finger's offset from
## the screen centre with each axis divided by its half-extent, so
## [code]rho[/code] is 0 in the middle and 1 on the ellipse through the screen's
## corners. A fixed pixel radius is a different fraction of the glass in
## portrait and landscape — [code]window/stretch/aspect[/code] is
## [code]expand[/code], so the viewport really does change shape under a running
## game — where "70% of the way to the edge" means the same thing held either
## way up.
##
## [b]The band has hysteresis, and the two thresholds are the reason the state
## lives here rather than being recomputed.[/b] A single threshold turns the
## contact patch's millimetre of centroid wander ([TouchTarget] has where the
## contact-patch numbers come from) into a tool
## that flaps up and down at the boundary. Entering the walk takes
## [constant WALK_ENTER]; leaving it takes coming all the way back to
## [constant WALK_EXIT], and the gap between them is about 7 mm on the
## narrowest screen this game targets — an order of magnitude above the wander.
##
## [b]The veto is the caller's fact and this class's rule.[/b] While the aim is
## landing on a panel of the car, [method update] may not enter the walk,
## whatever [code]rho[/code] says: a long scrub across a door can cross any
## band, and the room already knows the difference between "still on the paint"
## and "slid off the end of the bumper" — see [method Garage.aim_on_panel]. The
## veto only guards the way in. A walk in progress is left alone, because there
## is no aim to protect once the tool is down.
##
## [b]And the veto ends at the bezel.[/b] Past [constant VETO_END] the walk
## starts whatever the aim is landing on, because a thumb pressed out to the
## last stretch of glass is plainly asking to move — and because in portrait
## the car's flank runs all the way to the screen edge ([LensFit] fills the
## width with car), so a veto that ran all the way out made a direct sideways
## walk impossible: every horizontal drag stayed on paint forever and the
## player had to detour through a corner. Found by a hand on a phone within the
## hour (#196); no scrub stroke lives in the last millimetres before the bezel,
## which is what makes the override safe where it is.
##
## [b]Node-free on purpose[/b] — the STANDARDS.md "Coverage" R3 rule, the same
## one [ThumbLift] and [TouchTarget] are here for. Every rule above is
## arithmetic on two vectors and a flag, so it is a unit test rather than sixty
## frames of a scene with a finger dragged across it.
class_name ThumbWalk
extends RefCounted

## How far out an aim becomes a walk, as a [method rho] fraction. Far enough
## that the car's flanks stay inside it on a portrait phone — [LensFit] fills
## most of the width with car there, which is why the veto and not this number
## carries the scrub protection — and near enough that a walk zone is left on
## the axis that needs it most.
const WALK_ENTER: float = 0.70

## How far back in a walk becomes an aim again. The gap below
## [constant WALK_ENTER] is the hysteresis band the class docs measure.
const WALK_EXIT: float = 0.55

## Where the walk reaches full speed. Rescaled from [constant WALK_ENTER] the
## way the old stick rescaled from its dead zone: the first millimetre past the
## boundary asks for almost nothing, so "nudge round the wing" survives the
## stick it replaces.
const FULL_SPEED: float = 0.95

## Where the veto stops holding the walk back — see the class docs. Under
## [constant FULL_SPEED] so the override still has analog travel left in it,
## and far enough past [constant WALK_ENTER] that the whole scrub-protected
## band stays wider than the hysteresis under it.
const VETO_END: float = 0.90

## The strongest a single axis can ask for — [constant OrbitDrive.FULL_INPUT]
## at the other end of the chain, which is what keeps a thumb at the screen
## edge and a held arrow key exactly as fast as each other.
const FULL_INPUT: float = 1.0

## The thresholds this instance was built with. Fields rather than the
## constants read directly so the play screen can export them for the tuning
## pass #179 asks for; the constants above are the one set of defaults.
var _enter: float = WALK_ENTER
var _exit: float = WALK_EXIT
var _full: float = FULL_SPEED
var _veto_end: float = VETO_END

## Whether the finger is currently read as a walk. The one piece of state, and
## it is state on purpose: hysteresis is the property that the answer depends
## on which side the finger came from.
var _walking: bool = false


## The thresholds belong to the screen's exports, for the reason [OrbitDrive]
## takes its speeds from the scene: one set of answers, where somebody can see
## and change them. The defaults are this class's own constants.
func _init(
	enter: float = WALK_ENTER,
	exit_at: float = WALK_EXIT,
	full: float = FULL_SPEED,
	veto_end: float = VETO_END
) -> void:
	_enter = enter
	_exit = exit_at
	_full = full
	_veto_end = veto_end


## How far toward the edge a finger [param offset] from the screen centre is,
## on a screen of [param half] half-extents: 0 in the middle, 1 on the ellipse
## through the corners. Degenerate half-extents — a screen with no size, which
## cannot happen once anything is laid out — read as the middle, so nothing
## downstream ever walks on them.
##
## Spelled out in floats rather than through a [Vector2], which is float32: a
## finger put exactly on the band would round to a hair inside it and the
## boundary tests would fail by one part in ten million.
static func rho(offset: Vector2, half: Vector2) -> float:
	if half.x <= 0.0 or half.y <= 0.0:
		return 0.0
	var across: float = offset.x / half.x
	var down: float = offset.y / half.y
	return sqrt(across * across + down * down)


## Whether the finger is currently a walk rather than an aim.
func walking() -> bool:
	return _walking


## A fresh touch at [param offset] from the centre: past the band it walks
## immediately — a press near an edge is a fair request to move, and there is
## no aim yet for the veto to protect — inside it, it aims as every touch
## always has. Returns what [method walking] now says, so the caller can decide
## whether to raise the tool at all.
func begin(offset: Vector2, half: Vector2) -> bool:
	_walking = rho(offset, half) >= _enter
	return _walking


## The held finger read again, at [param offset] from the centre of a screen of
## [param half] half-extents, with the caller's veto: [param on_panel] is
## whether the aim is currently landing on the car ([method Garage.aim_on_panel]).
##
## The three rules of the state diagram on #179, in their entirety: an aim
## becomes a walk past [constant WALK_ENTER] [i]unless the aim is on a panel[/i]
## — and unconditionally past [constant VETO_END], where the bezel outranks the
## paint (see the class docs); a walk becomes an aim again inside
## [constant WALK_EXIT], whatever the veto says — there is no aim in a walk, so
## [param on_panel] can only be stale there; and between the two thresholds the
## finger keeps whichever reading it had. Returns what [method walking] now
## says.
func update(offset: Vector2, half: Vector2, on_panel: bool) -> bool:
	var at: float = rho(offset, half)
	if _walking:
		if at <= _exit:
			_walking = false
	elif at >= _enter and (not on_panel or at >= _veto_end):
		_walking = true
	return _walking


## The finger has left the glass — or the screen stopped being the thing in
## front of the player, which means the same thing. The next touch starts as an
## aim unless [method begin] says otherwise.
func release() -> void:
	_walking = false


## What a walking finger [param offset] from the centre is asking for:
## [code](turn, lift)[/code], each in [code]-1..1[/code] — the same two numbers
## the motion pad used to hand over, so nothing downstream of the screen
## changes. Zero while aiming: an aiming finger asks the camera for nothing.
##
## The direction is the unit vector from the screen centre to the finger — in
## raw pixels, not [method rho]'s normalized space, so a drag toward the middle
## of the right edge walks right rather than acquiring an aspect-ratio lean.
## The strength rescales [method rho] over the band from [constant WALK_ENTER]
## to [constant FULL_SPEED], clamped at full past it — a thumb hard against the
## bezel keeps walking, for the reason a thumb dragged off the old stick kept
## it. Y flips on the way out: screen space has up at [code]-Y[/code], input
## space — what [method OrbitDrive.steer] reads — has up at [code]+1[/code].
func input(offset: Vector2, half: Vector2) -> Vector2:
	if not _walking:
		return Vector2.ZERO
	var reach: float = offset.length()
	if reach <= 0.0 or _full <= _enter:
		return Vector2.ZERO
	var strength: float = clampf((rho(offset, half) - _enter) / (_full - _enter), 0.0, FULL_INPUT)
	var facing: Vector2 = offset / reach
	return Vector2(facing.x, -facing.y) * strength
