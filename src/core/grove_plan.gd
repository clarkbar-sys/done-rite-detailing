## Where the trees stand: a row of [Transform3D]s along one straight run of the
## lawn's boundary, spaced, wobbled and turned from a seed so the line reads as
## planting rather than as fence posts.
##
## [b]A line and not an edge.[/b] [method along] takes the two ends of a run and
## deals trees down it, and that is the whole interface — see
## [code]src/world/grove.gd[/code], which calls it three times. There used to be
## a [code]down_the_edge()[/code] beside it that wrote the two ends for a run
## straight down the lawn, back when the lawn was two mirrored strips either
## side of the drive and every row was one of them. The modeled ground is not
## that shape: it is a lawn wrapping three sides of a sunken pad, open at the
## end the car drives in from, so the rows are two long sides and one back that
## crosses them at a right angle. A helper that only wrote one of those three
## would have to be read past to find out which, so the caller writes all six
## coordinates and the asymmetry is visible where the decision is made.
##
## [b]Flat runs, and the ground is put back under them afterwards.[/b] Every
## [Vector3] here keeps the Y it was handed, which for the caller is zero: this
## file is about where a tree stands on the map, not about how high the grass is
## under it. The modeled ground rises up to 1.17 m out of the drive, so
## something has to answer that — it is [method Ground.settle], asked by
## [Grove] once the row has been dealt.
##
## [b]Every row has a hole cut out of it.[/b] The camera circles the car at
## [member Garage.orbit_radius] and the walk holds a standoff off the bodywork,
## so there is a disc in the middle of this driveway the player's eye sweeps
## through — and a tree grown inside it is a tree the camera flies through the
## leaves of. So [method blocked_span] solves the line against that disc and the
## row is dealt into whatever is left, which is up to two open stretches with the
## forbidden middle taken out.
##
## [i]Whether the hole bites at all is the lawn's business, not this file's.[/i]
## A run that never comes within [param keep_clear] of the middle has nothing
## taken out and gets trees end to end, which is what the back row across the
## far lawn gets — it is nine metres out and the disc is seven. The two long
## sides are the other case: they pass 5.8 m from the car at their closest, well
## inside it, so the middle of each is eaten and what is left is a stretch at
## either end. Both cases are the same three lines of arithmetic, and both are
## tested.
##
## [i]That the sides come out as two short stretches is the model's doing and
## not a taste.[/i] The blockout lawn this planting was first written for ran to
## 7.8 m and cleared the disc down its whole length; the modeled ground reaches
## 6.30, so there is no arrangement of it that puts a tree beside the car. The
## honest answer is to plant the ends of those runs and leave the middle bare,
## which is what the arithmetic below already did for the old lawn's short ends.
##
## [b]The gap is measured against the crown, not the trunk.[/b] Callers pass a
## [param keep_clear] that already has [constant TreeShape.MAX_REACH] in it —
## that constant exists so this can be arithmetic instead of a guess, and
## [code]tests/integration/test_grove.gd[/code] checks the sum against the
## garage's own orbit rather than against a number written down twice. The wobble
## is given away on top of it, so a tree that wanders toward the car still clears.
##
## [b]Everything wobbles inside its own slot.[/b] A tree takes a fixed share of
## the planting band and is jittered within it, and never takes anyone else's, so
## the row keeps a minimum spacing no matter what the seed rolls. Free positions
## would clump — three trees in a bunch and a bare stretch beside them — and the
## usual fix for that is a rejection loop that can, in principle, not terminate.
##
## Node-free, so the layout is a unit test — STANDARDS.md "Coverage" (R3).
class_name GrovePlan
extends RefCounted

## How far a tree wanders to either side of the line it was given, in metres.
## Small: the row is meant to read as planted along a boundary, and the caller
## has to keep both extremes on the grass.
const WOBBLE_ACROSS: float = 0.15

## How far a tree wanders along its run inside its own slot, as a fraction of
## that slot. Under a half in both directions, so two neighbours can lean toward
## each other without swapping places or touching.
const WOBBLE_ALONG: float = 0.3


## Which stretch of the line from [param from] along [param heading] for
## [param length] metres passes within [param keep_clear] of the middle of the
## driveway, as the two distances along it where it crosses in and out.
##
## [constant Vector2.ZERO] when the line never comes that close, which is the
## answer an outer edge of this lawn gets and the one that leaves a row
## untouched. The span is not clamped to the line: a caller gets the crossings
## even when they are behind its start or past its end, and clamps them itself.
##
## [b]Flat, and a disc rather than a sphere.[/b] Everything it is asked about
## stands on the ground and the thing being kept clear of is a camera on a
## circle, so height does not enter into it. The [Vector3]s are the caller's own
## coordinates rather than a promise about Y.
static func blocked_span(
	from: Vector3, heading: Vector3, length: float, keep_clear: float
) -> Vector2:
	# Where the line meets the circle: |from + heading * t| = keep_clear, with
	# heading a unit vector, so the quadratic loses its leading coefficient and
	# what is left is a square root of the half-discriminant.
	var toward: float = from.dot(heading)
	var outside: float = from.length_squared() - keep_clear * keep_clear
	var under: float = toward * toward - outside
	if under <= 0.0 or length <= 0.0:
		return Vector2.ZERO
	var crossing: float = sqrt(under)
	return Vector2(-toward - crossing, -toward + crossing)


## [param count] trees down the run from [param from] to [param to], all of them
## at least [param keep_clear] metres from the middle of the driveway, rolled
## from [param plan_seed].
##
## Returns them in order from one end of the run to the other — and returns
## nothing at all when the disc swallows the whole run, which is the honest
## answer to "plant trees where there is no room" and the one thing here a caller
## could get wrong by asking.
static func along(
	from: Vector3, to: Vector3, count: int, keep_clear: float, plan_seed: int
) -> Array[Transform3D]:
	var stands: Array[Transform3D] = []
	var length: float = from.distance_to(to)
	if count <= 0 or length <= 0.0:
		return stands
	var heading: Vector3 = (to - from) / length
	# The wobble is handed to the disc up front, so the clearance holds for a tree
	# that has wandered toward the car rather than for the line it wandered off.
	var blocked: Vector2 = blocked_span(from, heading, length, keep_clear + WOBBLE_ACROSS)
	var near: float = clampf(blocked.x, 0.0, length)
	var far: float = clampf(blocked.y, 0.0, length)
	var band: float = near + (length - far)
	if band <= 0.0:
		return stands
	var sideways: Vector3 = Vector3(-heading.z, 0.0, heading.x)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = plan_seed
	for tree: int in count:
		var slot: float = float(tree) + 0.5 + rng.randf_range(-WOBBLE_ALONG, WOBBLE_ALONG)
		var into: float = slot / float(count) * band
		# The two open stretches walked as one: past the end of the near one, the
		# next step lands on the far side of the hole.
		var walked: float = into if into < near else far + into - near
		var wander: float = rng.randf_range(-WOBBLE_ACROSS, WOBBLE_ACROSS)
		var turned: Basis = Basis(Vector3.UP, rng.randf_range(0.0, TAU))
		stands.append(Transform3D(turned, from + heading * walked + sideways * wander))
	return stands
