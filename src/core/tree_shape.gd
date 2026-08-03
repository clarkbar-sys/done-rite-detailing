## One tree, rolled from a seed: a trunk of a certain height and thickness, and
## a crown made of overlapping spheres.
##
## [b]Why a seed and not a scene.[/b] A tree drawn once and instanced eight times
## is eight copies of the same tree, and a driveway lined with the same tree
## eight times reads as wallpaper. Rolling the shape from a number gets variety
## for the price of an [RandomNumberGenerator] — and because the number is chosen
## rather than sampled, the variety is the same variety on every load. That is
## [constant SEEDS]: the wood is a handful of frozen rolls, so the level a player
## opens today is the level they closed yesterday, and a screenshot still matches
## the game a week later.
##
## [b]What comes out of it.[/b] [member trunk_height] and [member trunk_radius]
## are a cylinder; [member crown] is a list of spheres given as [Vector4], centre
## in [code]xyz[/code] and radius in [code]w[/code]. Packing a sphere into a
## vector is a graphics idiom rather than a shortcut around a class — it keeps
## the crown a value that can be compared, copied and asserted on whole, which is
## most of what the tests below do with it.
##
## Everything is in the tree's own space, in metres: the trunk stands on
## [code]y = 0[/code] and +Y is up, so a tree is planted by putting a
## [Transform3D] under it and nothing else. See [GrovePlan] for where they stand
## and [code]src/world/grove.gd[/code] for what turns this into meshes.
##
## [b]The crown is spheres that overlap on purpose.[/b] Every satellite sits
## closer to the trunk's axis than the core sphere's own radius, so the crown is
## one lumpy mass rather than a constellation of separate balls — the blocked-out
## look, made of the cheapest primitive there is.
##
## [b]It promises how far it sticks out.[/b] No crown reaches further from the
## trunk than [constant MAX_REACH], and that is arranged by construction rather
## than hoped for: a satellite's radius is drawn first and its distance from the
## axis is then capped at whatever is left of the promise. The room needs that promise to keep
## the camera clear of the leaves — see [GrovePlan]'s [code]keep_clear[/code] —
## and [code]tests/unit/test_tree_shape.gd[/code] holds it to it across every
## seed, not just the frozen ones.
##
## Node-free, so the whole thing is a unit test — STANDARDS.md "Coverage" (R3).
class_name TreeShape
extends RefCounted

## The rolls the level is built from: seven trees, frozen.
##
## [b]Chosen rather than picked out of the air.[/b] A seed says nothing about the
## tree it grows, so seven numbers written down by hand can perfectly well
## contain a pair of twins — which would be a poor advertisement for rolling the
## shapes at all. These are the first seven from 11 upward that come out at least
## 15 cm apart in overall height, which also spreads their crowns (five spheres
## to nine) and their trunks. [code]tests/unit/test_tree_shape.gd[/code] holds
## them to a tenth of a metre, so swapping one for a number somebody likes better
## fails there rather than in a screenshot.
##
## What matters after that is only that they never change, because changing one
## replants that tree.
##
## Seven and not five: the grove plants fourteen trees by default (see
## [code]src/world/grove.gd[/code]), so this is the number of them a player can
## tell apart — every shape stands twice, in two different corners of the lawn,
## turned a different way.
const SEEDS: Array[int] = [11, 13, 15, 19, 63, 121, 139]

## How far from the trunk's axis any part of any crown can be, in metres. The
## room stands its trees this far clear of anything the camera can reach.
const MAX_REACH: float = 1.0

## How tall a trunk can be, in metres — a young street tree rather than
## something a driveway would be in the shade of all day.
const TRUNK_HEIGHT: Vector2 = Vector2(1.9, 2.9)

## How thick a trunk can be, in metres of radius — about a fifteenth of the
## height above, which is what stops a tall roll reading as a broom handle and a
## short one as a stump. Looked at rather than guessed: the first pass was two
## thirds of this and every tree in the wood came out a lollipop.
const TRUNK_RADIUS: Vector2 = Vector2(0.12, 0.19)

## How many spheres a crown is made of, core included. Five is a recognisable
## clump; nine is as many as reads as one canopy before the lumps stop being
## legible at the distance these are seen from.
const CROWN_BLOBS: Vector2i = Vector2i(5, 9)

## How big the sphere in the middle of the crown can be, in metres of radius.
## The satellites are drawn smaller than this on purpose — a crown wants one
## mass and some lumps on it, not a bag of equal balls.
const CORE_RADIUS: Vector2 = Vector2(0.66, 0.94)

## How big a satellite sphere can be, in metres of radius.
const BLOB_RADIUS: Vector2 = Vector2(0.38, 0.58)

## How far out a satellite's near edge can sit, as a fraction of the core's
## radius. Well under one at both ends, which is what makes the crown overlap
## into a single mass instead of scattering.
const BLOB_HUG: Vector2 = Vector2(0.25, 0.72)

## How far a satellite's centre can sit above or below the core's, as a fraction
## of the core's radius. Deeper up than down, so the crown grows a top rather
## than a skirt.
const BLOB_LIFT: Vector2 = Vector2(-0.42, 0.68)

## Where the core sphere's centre sits above the top of the trunk, as a fraction
## of its own radius. A third, so the crown swallows the top of the trunk
## instead of balancing on it.
const CROWN_SIT: float = 0.34

## How much of the trunk is left bare under the crown, as a fraction of its
## height — half, so leaves never end up brushing the grass.
##
## Unlike [constant MAX_REACH] this is not clamped anywhere: it falls out of the
## ranges above, which put the lowest underside any roll can produce at about
## seven tenths of the way up. It is written down because that is a fact about
## the numbers rather than about the code, and the kind of fact that quietly
## stops being true when somebody widens a range —
## [code]tests/unit/test_tree_shape.gd[/code] is what notices.
const BARE_TRUNK: float = 0.5

## How tall the trunk is, in metres, from the ground to the top of the cylinder.
var trunk_height: float = 0.0

## How thick the trunk is, in metres of radius, measured at its base.
var trunk_radius: float = 0.0

## The crown, as spheres: centre in [code]xyz[/code] and radius in [code]w[/code],
## in the tree's own space. The first one is the core the rest are hung off.
var crown: Array[Vector4] = []


## Rolls a tree from [param tree_seed]. The same number always gives the same
## tree — that is the whole contract, and the reason the level can be built out
## of [constant SEEDS] rather than out of saved geometry.
func _init(tree_seed: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = tree_seed
	trunk_height = rng.randf_range(TRUNK_HEIGHT.x, TRUNK_HEIGHT.y)
	trunk_radius = rng.randf_range(TRUNK_RADIUS.x, TRUNK_RADIUS.y)
	var core: float = rng.randf_range(CORE_RADIUS.x, CORE_RADIUS.y)
	var middle: Vector3 = Vector3(0.0, trunk_height + core * CROWN_SIT, 0.0)
	crown = [Vector4(middle.x, middle.y, middle.z, core)]
	var blobs: int = rng.randi_range(CROWN_BLOBS.x, CROWN_BLOBS.y)
	# Satellites are dealt one per slice of a full turn with the angle jittered
	# inside its own slice, rather than each taking a free angle: free angles
	# clump, and a crown with three lumps on one side and none on the other is
	# the failure this avoids without any rejection loop.
	var slice: float = TAU / float(blobs - 1)
	for blob: int in blobs - 1:
		var around: float = slice * float(blob) + rng.randf_range(0.0, slice)
		crown.append(_satellite(rng, middle, core, around))


## How far the crown sticks out from the trunk's axis, in metres — the radius of
## the circle this tree needs to be given on the grass.
##
## Never more than [constant MAX_REACH]; see the class docs for why that is a
## promise rather than an observation.
func reach() -> float:
	var out: float = trunk_radius
	for blob: Vector4 in crown:
		out = maxf(out, Vector2(blob.x, blob.z).length() + blob.w)
	return out


## How tall the tree is overall, in metres — the top of the highest sphere, which
## is above the trunk by more than the crown's radius on most rolls.
func height() -> float:
	var top: float = trunk_height
	for blob: Vector4 in crown:
		top = maxf(top, blob.y + blob.w)
	return top


## Every tree the level is built from, one per entry in [constant SEEDS], in that
## order.
##
## Built fresh on each call rather than cached in a [code]static var[/code]: the
## grove asks once at [code]_ready[/code], the roll is a few dozen floats, and a
## shared cache would hand every caller the same mutable objects.
static func variants() -> Array[TreeShape]:
	var trees: Array[TreeShape] = []
	for tree_seed: int in SEEDS:
		trees.append(TreeShape.new(tree_seed))
	return trees


## One sphere of the crown, hung off the core at [param around] radians.
##
## The distance from the axis is what keeps [method reach] under
## [constant MAX_REACH]: the radius is drawn first, and the distance is then
## capped at what is left of the promise once that radius has been given away.
func _satellite(rng: RandomNumberGenerator, middle: Vector3, core: float, around: float) -> Vector4:
	var radius: float = rng.randf_range(BLOB_RADIUS.x, BLOB_RADIUS.y)
	var out: float = minf(rng.randf_range(BLOB_HUG.x * core, BLOB_HUG.y * core), MAX_REACH - radius)
	var lift: float = rng.randf_range(BLOB_LIFT.x * core, BLOB_LIFT.y * core)
	return Vector4(
		middle.x + cos(around) * out, middle.y + lift, middle.z + sin(around) * out, radius
	)
