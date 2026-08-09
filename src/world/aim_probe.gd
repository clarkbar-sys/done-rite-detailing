## What a press landed on: the stack of three answers to "which bit of car is
## under the player's finger", asked widest-last so the cheap exact answer is the
## one that nearly always gets given.
##
## [b]Why this is its own file.[/b] [code].gdlintrc[/code] says it, and it named
## this concern when it did: [Garage] is the driveway, the camera, the walk, the
## aiming, the mud and the attract loop, and the file had grown to three times
## the length of anything else in the repo on the strength of being all six. The
## aiming is the piece that comes off cleanest — it is a question asked of the
## world with a ray and a car, it already composes three units that live
## elsewhere ([AimSweep], [AimHold], [NearestPoint]), and nothing in it has heard
## of a viewmodel, a tool belt or a signal. So it is the one that came off first.
##
## The room still owns the tunables. [member Garage.aim_reach] and the three
## tool radii are exports on the scene, because how far a tool reaches is a fact
## about the game rather than about the query — this is handed them at
## construction and at each call, the same way [ToolSight] is handed the two
## radii it draws.
##
## [b]Shaped like the engine's own[/b] [method
## PhysicsDirectSpaceState3D.intersect_ray] result — [code]position[/code],
## [code]normal[/code], [code]collider[/code] — including when it is assembled by
## hand below, so the caller has one shape to read rather than four and cannot
## forget which case it is in.
##
## Plus two keys the engine does not set: [code]surface[/code], true when the
## position and the normal came off real geometry and false when they were
## reconstructed from a bounding box; and [code]on_panel[/code], true when the
## answer came from the exact or swept tier — the player really is pointing at
## the car — and absent from the nearest-panel fallback, which answers for a
## press that is plainly pointed somewhere else. The walk gesture's veto reads
## the second through [method Garage.aim_on_panel]; they are different
## questions, because the fallback's second probe ray can land on real
## geometry ([code]surface[/code] true) that the player was not aiming at.
##
## It is not "did the ray hit" — three of the four answers below come off real
## geometry and all three set it. It is "is this a place on the car, with the
## car's own normal", which is the only question anything writing to a texture
## can use: everything that draws is happy with an approximation and says so by
## ignoring this, and a projection fed an invented normal picks the wrong face of
## the wrong panel. See [method Garage._spend_the_trigger], which had this rule
## wrong once.
class_name AimProbe
extends RefCounted

## How far past the nearest-point post [method _nearest_on_the_car] casts its
## second ray, as a fraction of the distance to it. A tenth over, because the
## post sits on a box that is slightly larger than the panel inside it — a ray
## stopped exactly at the post would land just short of the paint on every panel
## whose box is loose, which is all of them.
const PAST_THE_POST: float = 1.1

var _car: Car = null
var _reach: float = 0.0
var _sweep: AimSweep = null
var _held: AimHold = AimHold.new()


## Takes the car every tier below measures against, and [param reach] — how far
## down the aim a press is allowed to look at all, which is
## [member Garage.aim_reach].
##
## The sweep is built here rather than per press for the reason [AimSweep] gives:
## it owns two engine objects that would otherwise be allocated twice a tick for
## as long as a finger is dragging across the sky. Given the same reach the exact
## ray is cast at, because it is the same aim asked a wider question.
func _init(car: Car, reach: float) -> void:
	_car = car
	_reach = reach
	_sweep = AimSweep.new(reach)


## The panel the ray hit, the panel a tool-wide sphere swept down the same line
## touched, or failing both the nearest bit of car to it — see the class docs for
## the shape of the answer and for what [code]surface[/code] means.
##
## [b]Three tiers, each strictly wider than the one above it, in that order for a
## reason.[/b] The exact ray is first because where it hits it is exactly right,
## and it answers nearly every press. [AimSweep] is second and not first because a
## swept sphere stops at the first thing it touches, which at a grazing angle is
## the roof edge rather than the door being pointed at — asked only after the ray
## came back empty, it has no exact answer left to steal. [param reach] is how wide
## the tool in hand works ([method Garage._reach_of]), which is the window it
## forgives by.
##
## [b]And the middle tier is the one that is not cast every tick.[/b] It goes
## through [AimHold], which hands back what the last sweep down this aim found for
## as long as the aim has not moved — the whole of [code]#145[/code]'s fix, and a
## statement about how often rather than about what. That class carries the
## numbers; the short of it is four milliseconds a sweep against the car pack's
## trimeshes, bought sixty times a second by a thumb hovering over a roofline to be
## told the same thing every time. The other two tiers are cast every tick exactly
## as they were, and the hold is dropped by the smallest movement of eye or aim
## that could change the answer — so a moving press is as exact as it ever was.
##
## The nearest-panel fallback stays underneath both, unchanged, because it is the
## only one of the three that always answers: a sphere the width of a sponge is
## bounded by definition, and a press at the horizon should still put the mark on
## the car rather than nowhere. What the sweep took off it is the cases where it
## was reduced to inventing a normal — see [method _nearest_on_the_car].
func under_the_finger(
	space: PhysicsDirectSpaceState3D, from: Vector3, facing: Vector3, reach: float
) -> Dictionary:
	var hit: Dictionary = space.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, from + facing * _reach)
	)
	if not hit.is_empty():
		hit["surface"] = true
		hit["on_panel"] = true
		return hit
	if not _held.holds(from, facing, reach):
		_held.keep(_sweep.onto(space, from, facing, reach), from, facing, reach)
	var swept: Dictionary = _held.answer()
	if not swept.is_empty():
		# Also on the panel: the sweep only forgives by the width of the tool in
		# hand, so its answer is "aiming at the panel's edge", not "pointed away".
		# Set here rather than in [AimSweep] because on-panel is this file's
		# distinction — the tier the answer came from, which the sweep cannot know.
		swept["on_panel"] = true
		return swept
	return _nearest_on_the_car(space, from, facing)


## The finger has come off the glass, so the swept answer goes with it and the
## next press starts by asking rather than by inheriting — see
## [method AimHold.drop], which has why that is a release-time job and not a
## press-time one.
func release() -> void:
	_held.drop()


## The nearest bit of car to a ray that hit nothing.
##
## [b]Two passes, because a box is not a car.[/b] [NearestPoint] works on one
## [AABB] per panel, which is cheap and is enough to answer "which panel, and
## roughly where on it" — but a box around a wing mirror is much bigger than the
## mirror, so the point it returns is beside the bodywork rather than on it, and
## it has no surface normal at all. So the answer is used as an aiming post: a
## second ray goes from the eye to just past that point, and if it hits, the mark
## goes on the real surface with the real panel's real normal.
##
## [b]When even that misses[/b] the box point is used as-is, faced at the player.
## It is the honest answer to "nearest bit of car" and it is visibly approximate,
## which beats showing nothing at all — but it is also the one answer nothing may
## clean, because its normal was invented rather than measured, so a press that
## lands here draws a working tool that moves no mud.
##
## [b]That last case is rarer than it was, and [AimSweep] is why.[/b] The presses
## it used to catch were mostly near misses — a thumb-lifted aim just over the
## roofline, or a ray threading the gap between a wheel and its arch — and those
## are now answered a tier above this with a real normal off real paint. What is
## left down here is the genuinely distant press: the sky well above the car, the
## tarmac metres to one side. Which is the right shape for it. A last resort that
## fires on a near miss is a bug wearing a fallback's clothes; a last resort that
## fires when the player is plainly not pointing at the car is doing its job.
func _nearest_on_the_car(
	space: PhysicsDirectSpaceState3D, from: Vector3, facing: Vector3
) -> Dictionary:
	var panels: Array[Node3D] = _car.panels()
	var boxes: Array[AABB] = []
	for panel: Node3D in panels:
		boxes.append(_car.box_around(panel))
	var nearest: int = NearestPoint.nearest_box(boxes, from, facing)
	if nearest < 0:
		return {}
	var post: Vector3 = NearestPoint.in_box_from_ray(boxes[nearest], from, facing)
	var reach: Vector3 = post - from
	var probe: Dictionary = space.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, from + reach * PAST_THE_POST)
	)
	# The probe really did hit the car, so it carries the car's own normal and is
	# somewhere a tool can be used — it only needed a post put in front of it to
	# be found. The box point below did not: it is a corner of a bounding box with
	# a normal pointed back at the player because there was nothing to measure one
	# from, and that is the one answer nothing may write to.
	if not probe.is_empty():
		probe["surface"] = true
		return probe
	return {
		"position": post,
		"normal": (from - post).normalized(),
		"collider": panels[nearest],
		"surface": false,
	}
