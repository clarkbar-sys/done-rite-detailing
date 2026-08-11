## Where to stand to film a panel: one spot on the driveway, worked out from the
## panel's own box, the car's, and the lens the room is actually looking through.
##
## [b]Framing matters more here than it does for the attract mode, and that is the
## whole reason this exists.[/b] The title screen's demo walks the eye round to
## whatever is being worked and is watched out of the corner of an eye; a tutorial
## clip is watched on purpose, by somebody who is being shown what a sponge does,
## and a shot that drifts or that films the panel from across the drive teaches
## nothing. So a take gets one position, held for its whole length — no walk, no
## [Standoff] easing a radius, nothing that can be a different number on a different
## machine.
##
## [b]It is a stand and not a zoom[/b], which is [LensFit]'s distinction and is
## borrowed rather than restated: the lens is whatever [Lens] has fitted to the
## glass, and what is decided here is where the eye goes so that the panel fills
## [constant FILL] of the frame [i]through[/i] that lens. On the phone shape this
## footage is framed for that lens is narrow — a 70° vertical cap on a 9:16 viewport
## is about 43° across — so the answer is a good deal further back than the same sum
## on a desktop would give, and it has to be, or the take would film the inside of a
## door.
##
## [b]The clearance fence is the car's own box, and it is deliberately
## conservative.[/b] A walking eye keeps its distance by casting a ray at the
## bodywork every tick ([Standoff]); a fixed one has no ray and no tick, so what
## keeps a take out of the paint is the box around the whole car plus
## [constant CLEARANCE] — which is more room than a panel that sticks out actually
## needs. Every take in [method TutorialTake.named] is filmed on a panel that is
## most of the car (the shell, the windows), where the box is the right measure. The
## day one of them is filmed on a wheel, this is the line that has to learn to
## measure rather than assume, and it will be visibly too far away rather than
## quietly inside the arch.
##
## Node-free (STANDARDS.md "Coverage" R3): every shot in the catalogue is a row in
## a unit test rather than a screenshot somebody looked at.
class_name TutorialFraming
extends RefCounted

## The window a take is filmed in, in pixels: 9:16, which is the shape of the phone
## this game is played on and the shape [LensFit] exists because of. Fixed rather
## than "whatever the harness opened", because the framing below is computed from
## the lens and the lens is computed from this.
const FRAME: Vector2i = Vector2i(720, 1280)

## How much of the frame's width the panel is meant to take up.
##
## Short of all of it on purpose, and the same argument [constant
## AttractRoutine.REACH] makes: the box is bigger than the panel inside it, and a
## shot framed to the box's edges crops the bodywork. Four fifths leaves the panel
## large with the car it belongs to still readable around it, which is what a person
## being taught where the sponge goes needs to see.
const FILL: float = 0.8

## How far off the middle of the car a panel has to sit before the eye is placed on
## its side rather than on the fixed quarter — [constant Garage.NO_SIDE_TO_IT]'s
## number and its argument, restated rather than reached for because
## [code]src/core/[/code] does not get to know that a [Garage] exists.
##
## The shell and the windows are both centred on the car, so in practice every take
## in the catalogue is filmed from the quarter below. That is the right answer for
## them and not a shortcut: the angle of a point at the middle of a circle flips
## from one side of the car to the other over a centimetre.
const NO_SIDE_TO_IT: float = 0.35

## Where the eye stands for a panel that has no side to it: the front quarter, the
## same three-quarter view [member Garage.eye_position] parks the game's own
## standing shot at. A car photographed square-on from the side is a rectangle; from
## the quarter it is a car.
const QUARTER: Vector2 = Vector2(0.75, 0.66)

## How much clear air to leave between the car's box and the eye, in metres.
##
## Not [member Garage.standoff_metres], which is a shot decision for a walking
## camera. This is a fence: it is what stops the framing sum below walking the lens
## into the bodywork when it is handed a small panel, and it is comfortably past the
## 0.45 m a held tool reaches in front of the eye.
const CLEARANCE: float = 1.2

## The furthest the eye may be stood from the middle of the car, in metres. Inside
## [member Garage.orbit_radius], which is already the number that keeps a camera on
## the modeled driveway rather than out on the grass.
const FURTHEST: float = 5.0

## How far above the middle of the panel the eye stands, in metres —
## [member Garage.attract_eye_rise_metres]'s number and its argument: the camera
## looks at the panel whatever height it is at, and an eye level with a sill is
## lying on the tarmac.
const RISE: float = 0.5

## The lowest the eye may be, in metres above the floor the car is parked on. Higher
## than [member Garage.eye_height_min], which is a crouch a player can choose: a take
## is filmed by somebody standing up.
const LOWEST: float = 1.4

## The highest. [member Garage.eye_height_max]'s reason applies unchanged — past
## about here the shot leans in over the roof rather than standing beside the car.
const HIGHEST: float = 2.0


## Where to stand to film [param panel], on a car whose whole box is [param car],
## through a lens [param fov_degrees] wide across the frame.
##
## A world position, ready to be handed to [method Garage.stand_at]. Both boxes are
## world-space, which is what [method Car.box_around] and [method Car.bounds]
## already answer in, so nothing here has to know how a car is parked.
static func eye_for(panel: AABB, car: AABB, fov_degrees: float) -> Vector3:
	var facing: Vector2 = facing_for(panel, car)
	var out: float = stand_off(panel, car, facing, fov_degrees)
	var middle: Vector3 = car.get_center()
	return Vector3(middle.x + facing.x * out, height_for(panel, car), middle.z + facing.y * out)


## Which way off the middle of the car the eye goes for [param panel], as a unit
## vector on the floor. See [constant NO_SIDE_TO_IT] for the panel that has no
## answer of its own.
static func facing_for(panel: AABB, car: AABB) -> Vector2:
	var off: Vector3 = panel.get_center() - car.get_center()
	var flat: Vector2 = Vector2(off.x, off.z)
	if flat.length() <= NO_SIDE_TO_IT:
		return QUARTER.normalized()
	return flat.normalized()


## How far from the middle of the car the eye stands, in metres, along
## [param facing].
##
## Three numbers added and then fenced: how far along that line the panel's own
## middle already is, how far the panel reaches past it, and how far back a lens
## [param fov_degrees] wide has to be for [constant FILL] of its frame to be the
## panel. The fence is [constant CLEARANCE] past the car at the near end and
## [constant FURTHEST] at the far one.
##
## A lens with no width to it is not something to measure against — it happens, on a
## viewport that has not been laid out yet, where [method Lens._fit] leaves the
## camera alone for the same reason — so the answer is the near fence, which is a
## shot of the car rather than a division by nothing.
static func stand_off(panel: AABB, car: AABB, facing: Vector2, fov_degrees: float) -> float:
	var least: float = reach_along(car, facing) + CLEARANCE
	var half_frame: float = LensFit.half_frame(fov_degrees, 1.0)
	if half_frame <= 0.0:
		return least
	var off: Vector3 = panel.get_center() - car.get_center()
	var along: float = Vector2(off.x, off.z).dot(facing)
	var across: float = maxf(panel.size.x, panel.size.z) * 0.5
	return clampf(along + reach_along(panel, facing) + across / FILL / half_frame, least, FURTHEST)


## How far [param box] reaches from its own middle in direction [param facing],
## along the floor — the support of the box, which is the honest answer to "how much
## of this is in the way" for a direction that is not one of its axes.
static func reach_along(box: AABB, facing: Vector2) -> float:
	return absf(facing.x) * box.size.x * 0.5 + absf(facing.y) * box.size.z * 0.5


## How high the eye stands, in metres, to film [param panel] on a car sitting in
## [param car].
##
## Measured from the floor the car is parked on — the bottom of its own box, which
## is where [method Garage._park_the_car] has just put it — so the fences mean the
## same thing on a sport car and on a minivan.
static func height_for(panel: AABB, car: AABB) -> float:
	return clampf(panel.get_center().y + RISE, car.position.y + LOWEST, car.position.y + HIGHEST)
