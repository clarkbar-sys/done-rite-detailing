## Where the trees stand: a row of [Transform3D]s down one long edge of the
## lawn, spaced, wobbled and turned from a seed so the line reads as planting
## rather than as fence posts.
##
## [b]The hole in the middle is the whole design.[/b] The camera circles the car
## at [member Garage.orbit_radius] and the walk holds a standoff off the
## bodywork, so there is a disc in the middle of this driveway the player's eye
## sweeps through — and a tree grown inside it is a tree the camera flies through
## the leaves of. So a row is not laid down the whole edge: [method clear_of]
## works out how far down the lawn a tree has to be before it is [param
## keep_clear] metres from the middle of the driveway, and the row is dealt into
## the two stretches beyond that, one at each end. What comes out is trees at the
## corners of the lawn framing the drive, which is where a real one would plant
## them anyway.
##
## [b]The gap is measured against the crown, not the trunk.[/b] Callers pass a
## [param keep_clear] that already has [constant TreeShape.MAX_REACH] in it —
## that constant exists so this can be arithmetic instead of a guess, and
## [code]tests/integration/test_grove.gd[/code] checks the sum against the
## garage's own orbit rather than against a number written down twice.
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

## How far a tree wanders in or out of the edge line it was given, in metres.
## Small: the row is meant to read as planted along a boundary, and the caller
## has to keep both extremes on the grass.
const WOBBLE_ACROSS: float = 0.15

## How far a tree wanders along the lawn inside its own slot, as a fraction of
## that slot. Under a half in both directions, so two neighbours can lean toward
## each other without swapping places or touching.
const WOBBLE_ALONG: float = 0.3


## The nearest a tree standing at [param x] may come to the middle of the
## driveway, measured along the lawn — the [code]z[/code] at which it is exactly
## [param keep_clear] metres from the origin, and zero when its own distance
## across already clears that.
##
## Pythagoras, with the negative case answered rather than left to [method sqrt]:
## an edge further out than [param keep_clear] has no forbidden stretch at all.
static func clear_of(x: float, keep_clear: float) -> float:
	var across: float = keep_clear * keep_clear - x * x
	if across <= 0.0:
		return 0.0
	return sqrt(across)


## [param count] trees down the edge at [param edge_x], between the ends of the
## lawn at ±[param z_limit], all of them at least [param keep_clear] metres from
## the middle of the driveway, rolled from [param plan_seed].
##
## Returns them in order along the lawn, from the far negative end to the far
## positive one — and returns nothing at all when the two forbidden stretches
## meet, which is the honest answer to "plant trees where there is no room" and
## the one thing here a caller could get wrong by asking.
static func down_the_edge(
	edge_x: float, z_limit: float, count: int, keep_clear: float, plan_seed: int
) -> Array[Transform3D]:
	var stands: Array[Transform3D] = []
	if count <= 0:
		return stands
	# The band is worked out from the innermost a tree can wobble to, not from
	# the line it was given, so the clearance holds for every tree in the row
	# rather than for the average one.
	var inner: float = maxf(absf(edge_x) - WOBBLE_ACROSS, 0.0)
	var start: float = clear_of(inner, keep_clear)
	if start >= z_limit:
		return stands
	var band: float = z_limit - start
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = plan_seed
	for tree: int in count:
		var slot: float = float(tree) + 0.5 + rng.randf_range(-WOBBLE_ALONG, WOBBLE_ALONG)
		var along: float = slot / float(count) * band * 2.0
		var down_the_lawn: float = (-z_limit + along) if along < band else (start + along - band)
		var across: float = edge_x + rng.randf_range(-WOBBLE_ACROSS, WOBBLE_ACROSS)
		var turned: Basis = Basis(Vector3.UP, rng.randf_range(0.0, TAU))
		stands.append(Transform3D(turned, Vector3(across, 0.0, down_the_lawn)))
	return stands
