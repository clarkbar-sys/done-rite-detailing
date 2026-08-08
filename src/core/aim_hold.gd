## The answer a press is holding onto, and the rule for when it stops being one:
## keep what the last expensive query said, and hand it back for as long as the
## aim it was asked about has not moved.
##
## [b]The measurement this exists for.[/b] [code]scripts/perf-probe.gd[/code] times
## each query [method Garage._under_the_finger] makes, one at a time, against the
## CSG blockout the game was tuned on and two of the car pack's ten styles.
## Measured on this hardware, headless, microseconds per call:
##
## [codeblock]
##                          blockout    sedan      suv
##   intersect_ray, hit         4.20     3.44     3.80
##   intersect_ray, miss        0.49     0.50     0.43
##   cast_motion, near miss   355.10  3828.57  3645.22
##   cast_motion, open sky      0.70     0.69     0.70
##   GrimeMap.wash            977.79  1000.43   887.33
## [/codeblock]
##
## Read the third row against the second. A press that misses the car by a hair
## costs half a microsecond in the exact-ray tier and [b]nearly four
## milliseconds[/b] in the swept-sphere tier below it — a factor of about seven
## thousand — and it is four milliseconds rather than the blockout's third of one
## because [method MeshCar._collider_for] builds a seven-thousand-triangle concave
## trimesh per part, and [method PhysicsDirectSpaceState3D.cast_motion] against a
## concave shape is conservative advancement. Split further with the same probe:
## the sweep's own [method PhysicsDirectSpaceState3D.get_rest_info] half is 28 µs
## of that 3,714, and excluding every panel but [code]Body[/code] still costs
## 3,493 — so it is that one call on that one panel and nothing around it. At 60 Hz
## it is a quarter of the frame on a desktop with nothing else running, and this is
## a game played on a phone.
##
## [b]And it was being paid on every tick of a press that missed, which is not a
## rare press.[/b] [ThumbLift] takes the aim a thumb's width up the glass on
## purpose, so a thumb on the flank of a low car sits just over the roofline and
## misses for as long as it is held — sixty sweeps a second, all of them asking the
## identical question and getting the identical answer.
##
## [b]So the fix is how often and not how much, and this class is the "how
## often".[/b] Nothing here makes a sweep faster; it makes a held press take one
## instead of sixty. A dragged aim still pays per tick and that is correct — the aim
## really has moved and the old answer really is stale. Making the query itself
## cheap was a different job with a different shape, and it has since been done:
## the table above is the record of the swept-sphere tier this class was built
## against, and the [code]cast_motion[/code] rows in it are why [AimSweep] is now
## a fan of [method PhysicsDirectSpaceState3D.intersect_ray] calls priced off the
## ray rows instead — its class docs carry that change. The hold stays because
## the two fixes compose rather than compete: a dragged press pays the fan's tens
## of microseconds, and a held press still pays nothing at all.
##
## [b]It holds the answer as well as the key[/b], rather than leaving the caller a
## [Dictionary] to keep beside it. The two are one fact — "this is what was found,
## and this is the aim it was found for" — and split across two owners they are two
## facts that can disagree, which is a stale mark on the paint and the exact bug
## this class is here to make impossible.
##
## [b]Node-free[/b] (STANDARDS.md "Coverage" R3), for the reason [Standoff] gives:
## the query belongs to [code]src/world/garage.gd[/code], where a space state
## exists, and the arithmetic deciding whether to make it again is a handful of
## comparisons that a unit test can walk through without a camera, a car or a
## physics tick.
class_name AimHold
extends RefCounted

## How far the eye may drift, in metres, before the answer stops being about where
## the player is pointing now.
##
## Two millimetres, and it is a jitter budget rather than slack anybody is meant to
## feel. A finger held still on the glass produces a bit-identical ray from a
## bit-identical camera, so on the press this class exists for the comparison is
## exact and this number is never reached. What it actually absorbs is [Standoff]:
## the servo eases the radius toward the gap it wants and converges asymptotically,
## so a camera that has settled is still moving by amounts with several zeroes in
## front of them, forever. Without a budget every one of those would buy a fresh
## four-millisecond sweep and the class would do nothing at all.
const HELD_METRES: float = 0.002

## How square the aim has to stay, as a dot product between the direction the
## answer was found down and the direction being asked about now.
##
## [b]0.99999 is a quarter of a degree[/b], which at the 2.2 m the walk stands off
## a car ([member Garage.standoff_metres]) is about a centimetre across the paint.
## Sized against what the query it is holding can itself resolve rather than
## against the screen: a swept answer lands up to a whole tool-radius off the
## line it was asked about — 0.4 m for the power wash — so a centimetre is two
## orders of magnitude inside the approximation the answer already is. Nothing exact is
## held this way; [method Garage._under_the_finger] casts its exact ray every tick
## regardless, so every press that lands on the car is as sharp as it ever was.
##
## Comfortably clear of the noise floor, too: a [Vector3] holds 32-bit floats,
## whose dot product is good to about 1e-7, and this sits 1e-5 away from 1.
const HELD_COSINE: float = 0.99999

var _answer: Dictionary = {}
var _panel: int = 0
var _from: Vector3 = Vector3.ZERO
var _facing: Vector3 = Vector3.ZERO
var _reach: float = 0.0
var _taken: bool = false


## Whether what is being held is still an answer to the aim from [param from] along
## [param facing] with a tool that works [param reach] metres wide.
##
## [b]An empty answer is held too[/b], and that is not an oversight. "A window this
## wide down this line touches nothing" costs as much to find out as a hit does —
## it is the same fan of rays, every one of them cast to the full reach — and it is
## what the press this class exists for produces most of the time, because a thumb
## parked in the sky beside a car misses every tier but the last. Holding only the
## hits would leave that case uncached, which is most of what a hovering press pays.
##
## [b][param reach] is part of the aim[/b] and not a detail of the query, because
## how wide the tool in hand works is how wide a miss the room forgives — see
## [method Garage._reach_of]. A tool swapped while the finger is down is therefore a
## different question about the same line, and gets asked afresh.
##
## [b]The collider is checked for still existing.[/b] Nothing in the game frees a
## panel while a finger is on the glass today, and an answer that outlives what it
## points at is a failure a room finds out about by crashing rather than by being
## slightly wrong — so the one branch that makes it impossible is worth what it
## costs. A held answer with a dead panel in it is simply not held.
##
## [b]Asked of the id and not of the [Object][/b], which is a real constraint and
## not a preference: reading a freed instance out of a [Dictionary] into a typed
## local is itself an engine error ("Trying to assign invalid previously freed
## instance"), so the check that is supposed to make the dead panel harmless would
## be the thing that reported it. Measured — [method keep] takes the instance id
## while the panel is demonstrably alive, and [method @GlobalScope.is_instance_id_valid]
## answers for it afterwards without ever touching the object again.
func holds(from: Vector3, facing: Vector3, reach: float) -> bool:
	if not _taken or not is_equal_approx(reach, _reach):
		return false
	if _from.distance_squared_to(from) > HELD_METRES * HELD_METRES:
		return false
	if _facing.dot(facing) < HELD_COSINE:
		return false
	return _panel == 0 or is_instance_id_valid(_panel)


## Keeps [param found] as what the sweep answered for the aim from [param from]
## along [param facing] at [param reach].
##
## Takes the aim as three arguments rather than reading it off the answer, because
## the answer does not carry it: a swept hit says where the sphere came to rest,
## which is a tool's radius off the line, and an empty answer says nothing at all.
## The key has to be the question.
##
## The panel's instance id is taken here, now, while the panel is alive — see
## [method holds] for why that reading cannot be left until it is needed. Zero
## stands for "this answer names nobody", which is every empty answer and is the
## one case there is nothing to outlive.
func keep(found: Dictionary, from: Vector3, facing: Vector3, reach: float) -> void:
	_answer = found
	_panel = 0
	if found.has("collider"):
		# Read out into a typed local rather than used in place: a [Dictionary] hands
		# back [Variant], and this project's warning levels treat handing one to a
		# typed parameter as an error rather than as a cast.
		var panel: Object = found["collider"]
		if panel != null:
			_panel = panel.get_instance_id()
	_from = from
	_facing = facing
	_reach = reach
	_taken = true


## What is being held — an empty [Dictionary] both when nothing was found and when
## nothing has been asked yet, which are the same thing to a caller that has just
## been told [method holds] is false and gone and found out.
func answer() -> Dictionary:
	return _answer


## Forgets everything, so the next aim is asked afresh.
##
## What makes "the press just started" a case needing no flag of its own: the room
## drops the hold when the finger comes off the glass ([method Garage.release_aim]),
## so a finger coming back down finds nothing held. Dropped rather than merely
## marked stale because the answer holds a reference to a panel, and keeping one
## between presses is keeping a node alive on behalf of a finger that has left.
func drop() -> void:
	_answer = {}
	_panel = 0
	_taken = false
