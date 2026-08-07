## The closest point on a box to a ray, and which of several boxes is closest —
## the arithmetic behind "mark the nearest bit of the car to where I pressed".
##
## A press that lands on the car is answered by a raycast and this is not
## involved. This is for the other press: the one at the sky above the roof, the
## tarmac beside a sill, or the gap between a wheel and an arch, where the ray
## hits nothing and the honest answer is still supposed to be a red mark on the
## paint. So the question stops being "what did I hit" and becomes "what part of
## the car did I come closest to missing", which a raycast cannot answer at all.
##
## [b]Boxes and not the bodywork, said plainly.[/b] What the room feeds this is
## one [AABB] per panel of the [Car], and a box around a wheel is a great deal
## bigger than the wheel — most of it is the empty corners of the arch. So the
## point this returns is close to the car rather than on it, and the room casts
## one more ray at it to land the mark on a real surface with a real normal — see
## [method Garage._nearest_on_the_car]. The boxes only have to be right about
## [i]which panel[/i] and roughly where, and for that they are exact enough while
## costing a clamp per panel instead of a mesh query per panel.
##
## [b]How the closest point is found.[/b] Alternating projection, which is worth
## naming because it looks like a loop that hopes: put a point at the middle of
## the box, slide it onto the ray, clamp it back into the box, repeat. Both a ray
## and a box are convex, so each half of that step can only shorten the gap, and
## the pair converges on the closest point of the two sets — in three or four
## passes for shapes this well behaved, which is why [constant STEPS] is small
## and why the loop leaves early when a pass stops moving. The closed-form
## alternative is a six-case quadratic program per box; this is eight lines and
## its failure mode is being a hair off rather than being wrong.
##
## Node-free and static throughout, so the whole thing is a unit test —
## STANDARDS.md "Coverage" (R3).
class_name NearestPoint
extends RefCounted

## How many times [method in_box_from_ray] refines its guess. Eight is roughly
## double what convergence takes for a car-sized box at arm's length, measured by
## printing the step the loop actually leaves on; the spare passes cost nothing
## because the loop stops the moment a pass fails to move the point.
const STEPS: int = 8


## [param point] brought inside [param box], per axis. Already inside means
## unchanged, which is what makes this safe to call on a point that may or may
## not be in there.
static func in_box(box: AABB, point: Vector3) -> Vector3:
	return Vector3(
		clampf(point.x, box.position.x, box.end.x),
		clampf(point.y, box.position.y, box.end.y),
		clampf(point.z, box.position.z, box.end.z)
	)


## The point on the ray from [param origin] along [param direction] that is
## closest to [param point].
##
## A ray and not a line: the projection is clamped at zero, so something behind
## the player is nearest to the player rather than to a stretch of ray that does
## not exist. That matters here — press near the horizon and the far end of the
## car really is behind the aim.
static func on_ray(origin: Vector3, direction: Vector3, point: Vector3) -> Vector3:
	var facing: Vector3 = direction.normalized()
	if facing == Vector3.ZERO:
		return origin
	return origin + facing * maxf((point - origin).dot(facing), 0.0)


## The point on [param box] closest to the ray from [param origin] along
## [param direction]. See the class docs for why this is a loop.
##
## A ray that passes through the box converges on a point on the ray inside it,
## which is the right answer to "closest point" and is also never asked for —
## the room only reaches for this after a raycast has already come back empty.
static func in_box_from_ray(box: AABB, origin: Vector3, direction: Vector3) -> Vector3:
	var point: Vector3 = box.get_center()
	for _step: int in STEPS:
		var stepped: Vector3 = in_box(box, on_ray(origin, direction, point))
		if stepped.is_equal_approx(point):
			break
		point = stepped
	return point


## The gap between [param box] and the ray from [param origin] along
## [param direction], and zero if the ray runs through the box.
static func gap_to_ray(box: AABB, origin: Vector3, direction: Vector3) -> float:
	var point: Vector3 = in_box_from_ray(box, origin, direction)
	return point.distance_to(on_ray(origin, direction, point))


## Which of [param boxes] the ray from [param origin] along [param direction]
## comes closest to, as an index into the array — or [code]-1[/code] if there are
## no boxes at all.
##
## An index rather than the box itself, because the caller has a panel per box
## and wants the panel: an [AABB] handed back on its own could not be traced to
## the thing it came from without searching the array again for it.
static func nearest_box(boxes: Array[AABB], origin: Vector3, direction: Vector3) -> int:
	var nearest: int = -1
	var closest: float = 0.0
	for index: int in boxes.size():
		var gap: float = gap_to_ray(boxes[index], origin, direction)
		if nearest < 0 or gap < closest:
			nearest = index
			closest = gap
	return nearest
