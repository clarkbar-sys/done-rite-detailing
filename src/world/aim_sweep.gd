## The press that missed by a hair: a fan of rays as wide as the tool in the
## player's hand, cast down the aim, so a ray that went just over the roof still
## lands on the roof — on real paint, with the paint's own normal.
##
## [b]What was wrong before this tier, and it is not what it looks like.[/b] The
## room has never had trouble [i]finding[/i] the car when a press misses it:
## [NearestPoint] answers "which panel did I come closest to" for any aim
## whatsoever, and [method Garage._nearest_on_the_car] then plants a post at the
## nearest point on that panel's box and casts a second ray at it. What that pair
## cannot always produce is a place with a [i]measured normal[/i] — and a measured
## normal is the one thing [method Garage._spend_the_trigger] cannot do without,
## because [BoxProjection] picks which face of a panel to write to by reading it.
## So when the post's probe misses too, the answer comes back flagged
## [code]surface: false[/code], the tool draws its water and its foam on the mark,
## and the grime is never touched. A tool that visibly runs and cleans nothing is
## the same failure [method Garage._spend_the_trigger] already has a paragraph
## about — it just arrives down a different path.
##
## [b]So the win here is narrow and worth stating exactly.[/b] This does not find
## the car more often. It converts misses that would have been answered
## [code]surface: false[/code] into real hits that can be worked. The press it was
## built for is the one the game creates for itself: [ThumbLift] deliberately
## takes the aim a thumb's width up the glass from the finger, and a thumb on the
## flank of a low car routinely sends the ray just over the roofline — a sport car
## is 1.04 m tall and the blockout this was measured on was 1.4 m. The wheel
## arches and the gap between a tyre and its sill are the same shape of problem
## from the other direction — geometry thin enough for a zero-width ray to
## thread.
##
## [b]It is not the primary query, and that is deliberate.[/b] A widened aim
## answers with the first thing inside its window, which is not the same as the
## thing you were pointing at: aim at a door from slightly above and the window
## clips the roof edge on the way past, and the mark lands on the roof. Run as
## the only query it would be strictly worse than the exact ray at every grazing
## angle. So [method Garage._under_the_finger] keeps [method
## PhysicsDirectSpaceState3D.intersect_ray] first and reaches for this only once
## that has come back empty — which is to say, only when there is no exact answer
## to steal from.
##
## [b]Why the radius is the tool's own[/b] rather than a tuning constant of its
## own. The window the fan opens is exactly the window the player can already
## see: [member Garage.wash_radius_metres] is the patch [WashJet]'s water lands
## on, and [member Garage.scrub_radius_metres] is the ring [SpongeSuds]'s foam is
## squeezed out to. Forgiving the aim by the width of the brush is a rule a player
## can read off the screen without being told it. A separate number would be a
## second opinion about how big a tool is, in the one place it could disagree with
## the picture.
##
## [b]A fan of rays and not a swept sphere, and the change is a performance fix
## with a number on it.[/b] This tier shipped as [method
## PhysicsDirectSpaceState3D.cast_motion] plus [method
## PhysicsDirectSpaceState3D.get_rest_info]: sweep a tool-wide sphere down the
## aim, park it where it first touched, ask what it was resting on. Correct, and
## measured in [AimHold]'s table at 3,600–3,800 µs a call against the car pack,
## because [method MeshCar._collider_for] builds a seven-thousand-triangle
## concave trimesh per part and conservative advancement against concave
## geometry is where a sweep's time goes. [AimHold] cut how [i]often[/i] a held
## press pays that; nothing cut the price, and a [i]dragged[/i] press — washing
## around a wheel, which is exactly where a zero-width ray threads gaps and this
## tier answers every tick — still paid it in full, on a phone, on the one
## thread the web build has (STANDARDS.md "Threads"). The fan is the same
## question re-asked with the query from the cheap rows of that table: twelve
## [method PhysicsDirectSpaceState3D.intersect_ray] calls at 3.4–4.2 µs a landed
## hit and half a microsecond a miss is some tens of microseconds a call,
## roughly a hundred times cheaper, through the identical query the exact tier
## and the reach mask already trust.
##
## [b]Parallel to the aim, not fanned out from the eye.[/b] Every ray is the
## exact ray slid sideways, up to the tool's radius off the line — so the window
## is [param radius] wide at every depth, which is what the swept sphere's was. A
## cone through the same ring would forgive almost nothing at arm's length and
## several tool-widths at the far end of the reach.
##
## [b]A fixed ring, not a scatter.[/b] [constant OUTER_RAYS] directions around
## the aim at the full radius, and [constant INNER_RAYS] more at
## [constant INNER_SCALE] of it, rotated to sit between them. Deterministic on
## purpose: a jittered fan answers the same press differently on different
## ticks, which is a mark that flickers and a test that flakes. The inner ring
## is for the middle of the window — a panel edge a whole radius off the aim is
## the outer ring's to catch, and one just inside the window would otherwise sit
## between the outer rays' lines and be threaded the same way the exact ray
## threaded it.
##
## [b]What a fan gives up against a sphere, said plainly.[/b] Nothing a fan hits
## is outside the sphere's window — every ray lies within the radius of the aim,
## so this tier still answers only where the sweep would have — but the reverse
## is not true: a sliver of geometry can sit between twelve rays where a solid
## sphere would have brushed it. The sliver has to be thinner than the gap
## between neighbouring rays, which at the wash's 0.4 m is under a third of a
## metre on the outer ring — a wing mirror stalk, not a wing. The press this
## tier exists for is a roofline or a wheel arch, bodywork the size of the
## window that several rays land on at once, and the stalk still has the
## nearest-panel tier underneath. Losing it from this tier to win back four
## milliseconds a tick on a phone is the whole trade.
##
## [b]Which hit answers: the nearest along the aim.[/b] The sphere stopped at
## its first contact along the travel; the fan keeps the hit whose landing sits
## least far down the direction of aim, which is the same reading — the first
## thing the press reaches — asked of twelve rays instead of one shape.
##
## [b]An instance and not a static, unlike [NearestPoint][/b], which is the one
## place these two differ in shape. How far the aim carries is the room's
## [member Garage.aim_reach], fixed when the room is built, and the ring's
## twelve directions never change at all — so both are taken once here rather
## than carried into every call or recomputed inside it.
##
## [b]In [code]src/world/[/code] and not [code]src/core/[/code][/b], because it
## queries a physics space and a space state only exists in a running scene. That
## is the R3 line in STANDARDS.md "Coverage" drawn where it is meant to be: this
## is tested at the integration tier, against a real car, in
## [code]tests/integration/test_play_screen_sweep.gd[/code].
class_name AimSweep
extends RefCounted

## How many rays ring the aim at the full radius of the window. Eight is the
## coarsest ring whose gaps stay under a tool-width at the wash's radius, and
## the whole fan is twelve rays at [AimHold]'s measured 3.4–4.2 µs a hit — a
## ring twice as fine would still be cheap, and buys nothing the nearest-panel
## tier does not already cover.
const OUTER_RAYS: int = 8

## How many more rays sit inside the ring, and how far in they sit. Four at
## half the radius, rotated half a step so they face the outer ring's gaps —
## see the class docs for what the inner ring is for.
const INNER_RAYS: int = 4
const INNER_SCALE: float = 0.5

## When the aim is too near the reference axis to build the ring's basis
## against. Squared length of a cross product, so about a quarter of a degree of
## parallelism — reached only by an aim pointed straight up or straight down,
## which the camera's own pitch rules out; here so that a caller without one
## cannot produce a zero-width ring. The same fence, at the same number, that
## [method WashJet.spray] keeps for the same construction.
const TOO_PARALLEL: float = 0.0001

var _reach: float

## The ring's twelve spokes, worked out once: [code]x[/code] and [code]y[/code]
## are where each ray sits around the aim, as fractions of the two axes the
## basis is built from per call, and [code]z[/code] is how far out it rides —
## 1.0 on the outer ring, [constant INNER_SCALE] on the inner.
var _spokes: PackedVector3Array = PackedVector3Array()


## Built with how far the aim carries, in metres — [member Garage.aim_reach], the
## same distance the exact ray is cast, because this is the same aim asked a wider
## question rather than a different one.
func _init(reach: float) -> void:
	_reach = reach
	for step: int in OUTER_RAYS:
		var angle: float = TAU * float(step) / float(OUTER_RAYS)
		_spokes.append(Vector3(cos(angle), sin(angle), 1.0))
	for step: int in INNER_RAYS:
		var angle: float = TAU * (float(step) + 0.5) / float(INNER_RAYS)
		_spokes.append(Vector3(cos(angle), sin(angle), INNER_SCALE))


## Where a fan of rays [param radius] wide from [param origin] along
## [param direction] first lands on the world, or an empty [Dictionary] if every
## ray misses.
##
## Shaped like the engine's own [method PhysicsDirectSpaceState3D.intersect_ray]
## result — [code]position[/code], [code]normal[/code], [code]collider[/code] —
## plus the [code]surface[/code] key [method Garage._under_the_finger] reads, so
## that all three of its tiers hand back one shape and a caller cannot forget
## which one it is holding. It is set here rather than by the caller, and it is
## always true: every field of this answer is the engine's own reading of real
## geometry, which is the entire reason the tier exists.
##
## [b]A radius of nothing is refused rather than cast[/b], because a fan of no
## width is the ray that has already been cast and missed: the engine would
## answer the same nothing twelve more times, and a tool whose reach was
## misconfigured to zero would silently get the old behaviour instead of an
## obviously wrong one.
func onto(
	space: PhysicsDirectSpaceState3D, origin: Vector3, direction: Vector3, radius: float
) -> Dictionary:
	if radius <= 0.0:
		return {}
	var facing: Vector3 = direction.normalized()
	var across: Vector3 = facing.cross(Vector3.UP)
	if across.length_squared() < TOO_PARALLEL:
		across = facing.cross(Vector3.RIGHT)
	across = across.normalized()
	var upward: Vector3 = across.cross(facing)
	var nearest: Dictionary = {}
	var closest: float = 0.0
	for spoke: Vector3 in _spokes:
		var from: Vector3 = origin + (across * spoke.x + upward * spoke.y) * (radius * spoke.z)
		var hit: Dictionary = space.intersect_ray(
			PhysicsRayQueryParameters3D.create(from, from + facing * _reach)
		)
		if hit.is_empty():
			continue
		# Read out into a typed local rather than used in place: a [Dictionary]
		# hands back [Variant], and this project's warning levels treat handing one
		# to a typed parameter as an error rather than as a cast.
		var landed: Vector3 = hit["position"]
		var along: float = (landed - origin).dot(facing)
		if nearest.is_empty() or along < closest:
			nearest = hit
			closest = along
	if nearest.is_empty():
		return {}
	nearest["surface"] = true
	return nearest
