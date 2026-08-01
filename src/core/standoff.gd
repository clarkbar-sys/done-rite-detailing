## How far off the car the eye should stand, kept true by moving the orbit in
## and out as it goes round.
##
## [b]The problem this solves.[/b] A car is not a cylinder. The one in the bay is
## 4.3 m long and 1.9 m wide, so a camera circling it at one fixed radius is
## either scraping the doors or standing a metre and a half off the bumper — the
## same number cannot be both. What a person walking around a car actually keeps
## constant is the gap between them and the paint, so that is what is held
## constant here and the radius is what gives.
##
## [b]It is a servo, not a solve.[/b] It is handed how far the car actually is
## this frame — measured by a ray, out in the scene where rays live — and it
## eases the radius toward the gap it wants at a limited rate. Snapping straight
## to the answer would be one line shorter and would read as the camera being
## yanked every time the ray crossed a corner of the bodywork; the rate limit is
## what makes a 4.3 m box feel like something being walked around.
##
## [b]Node-free[/b] (STANDARDS.md "Coverage" R3): the ray belongs to
## [code]src/world/garage.gd[/code], and the arithmetic that decides what to do
## with what it hit belongs here, where converging on a target is a `for` loop in
## a unit test rather than a camera somebody watched.
class_name Standoff
extends RefCounted

## How much clear air to keep between the eye and the nearest bodywork, in
## metres, measured square on to the panel — the reading a tape held at right
## angles to a door would give, not the length of a sightline running in at an
## angle. Whoever does the measuring has to agree;
## [code]src/world/garage.gd[/code] says why it is that one.
var clearance: float = 0.0

## The tightest the orbit may be pulled in. The fence that stops a ray which hit
## something unexpected — or nothing sensible — from walking the camera into the
## car it is supposed to be looking at.
var min_radius: float = 0.0

## The furthest the orbit may be pushed out, which is what keeps the eye off the
## walls of a room this class has otherwise never heard of.
var max_radius: float = 0.0

## How fast the radius is allowed to correct, in metres per second. The whole
## difference between a camera that eases around a corner and one that jumps.
var metres_per_second: float = 0.0


## No defaults — see [CameraOrbit]. These are the scene's numbers, not this
## class's opinion.
func _init(
	wanted_clearance: float, closest: float, furthest: float, correction_speed: float
) -> void:
	clearance = wanted_clearance
	min_radius = closest
	max_radius = furthest
	metres_per_second = correction_speed


## The radius [param radius] should become, given that the nearest bodywork is
## [param car_distance] metres away across the floor and [param delta] seconds
## have passed.
##
## [b]The sign, because it is the easy half to get backwards.[/b] A car further
## away than [member clearance] means the eye is standing too far off it, so the
## radius comes [i]down[/i]. Hence the subtraction.
##
## [b]Why the correction is the whole error and not a fraction of it.[/b] Square
## on to a panel, a metre off the radius is a metre off the gap exactly, because
## the surface does not move when the eye does. Down at a corner the eye comes in
## at an angle to the panel it is measuring against, so the same metre buys
## rather less than a metre and the correction lands short — and the next tick
## takes the rest. That is a servo converging rather than an error, which is what
## the rate limit already made this.
func correct(radius: float, car_distance: float, delta: float) -> float:
	var error: float = car_distance - clearance
	var budget: float = metres_per_second * maxf(delta, 0.0)
	return clampf(radius - clampf(error, -budget, budget), min_radius, max_radius)
