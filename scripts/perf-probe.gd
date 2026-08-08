## What the aim actually costs, one query at a time, against the cars the bay
## actually parks.
##
## [b]Why this exists.[/b] [code]#145[/code] opened with "perf sucks with real car
## meshes" and a ranked list of suspects, and every entry on that list was a guess
## about which of three or four engine calls the physics tick is really spending
## its time in. A guess is a bad thing to refactor a room on: the three tiers of
## [method Garage._under_the_finger] look about equally expensive written down, and
## they are not remotely equally expensive when run. So this script runs each of
## them on its own, thousands of times, against the blockout the game was tuned on
## and against two of the ten pack styles, and prints the microseconds. The fix in
## [code]src/world/garage.gd[/code] is argued from this table and the numbers are
## quoted in its doc comments.
##
## [b]Run it, do not trust the numbers in the comments.[/b] They were taken on one
## headless Linux box and a phone is not that:
## [codeblock]
## .godot-sdk/bin/godot --headless --path . -s res://scripts/perf-probe.gd
## [/codeblock]
##
## [b]A [SceneTree] and not a [GutTest], deliberately.[/b] Timings flake — a shared
## CI runner will hand you a 3x outlier for no reason connected to the code — so
## there is nothing here for [code]make gut[/code] to fail on and nothing here it
## runs. It lives in [code]scripts/[/code] beside the other build tools rather than
## under [code]src/[/code], which also keeps it out of
## [code]scripts/check-test-map.sh[/code]'s R1: it is not game code and it has no
## business being reached by a test. It is still type-checked and linted, because
## [code]make check[/code] and [code]make lint[/code] walk every
## [code].gd[/code] in the tree and a measuring tool that does not compile measures
## nothing.
##
## [b]What is measured, and why each one is on the list.[/b]
## [codeblock]
## intersect_ray, hit     the common press: the exact ray, landing on the car
## intersect_ray, miss    the same ray when it goes over the roof — the tick
##                        that then reaches for the tiers below
## AimSweep, near         the ray fan down a near miss: twelve offset rays,
##                        several of them landing on the bodywork
## AimSweep, sky          the ray fan at the open sky: twelve rays the whole
##                        aim_reach, answering nothing
## GrimeMap.wash          one tick of held trigger on the biggest panel
## [/codeblock]
## The sky sweep is on the list because it is the one the room pays most often and
## the one nobody thinks about: a press that misses the car entirely still runs the
## middle tier, and a fan that finds nothing has cast every ray the full
## [constant AIM_REACH] before it can say so. The two rows measured a swept sphere
## when this tier was one — 355 µs on the blockout and 3,700–3,800 µs against the
## pack, the numbers [code]src/core/aim_hold.gd[/code] keeps as its record — and
## the fan that replaced it is priced here by the same two rows under their new
## names, so the before and the after sit in the same table.
##
## [b]The brush walks along the panel rather than staying put[/b], which is the one
## measurement here that had to be arranged rather than simply taken. A jet held on
## one spot clears the mud under it in a dozen ticks and every tick after that is a
## loop over pixels with nothing left to move — so a stationary brush would measure
## the cheap half of the work and report it as the cost. Walking the brush across
## the face keeps fresh mud under it for the whole run, which is a player dragging
## the jet along a door and is the expensive case a frame budget has to survive.
extends SceneTree

## The CSG car the whole game was designed and tuned against, kept as a fixture
## since [code]#139[/code] — the "before" column of every row below.
const BLOCKOUT: String = "res://tests/fixtures/blockout_car.tscn"

## The bay's own car scene, whose [member MeshCar.style] this script overrides
## exactly the way [code]tests/integration/test_garage_styles.gd[/code] does: set
## on the instance before it enters the tree, because [method MeshCar._ready] reads
## it once and builds the model from it.
const MESH_CAR: String = "res://src/world/mesh_car.tscn"

## What gets measured, in order. The blockout first so every mesh row has
## something to be read against, then two pack styles — the sedan because it is
## what [code]src/world/mesh_car.tscn[/code] pins and the middle of the range in
## every direction, and the SUV because it is the heavier of the two in triangles
## (7,951 against 7,122) and the taller.
##
## Two styles and not ten: the question this answers is "does the shape of the
## collider change the shape of the cost", and a second mesh car is what makes that
## answerable. Ten would be nine copies of the same answer and a minute of runtime.
const SUBJECTS: Array[String] = ["blockout", "sedan", "suv"]

## Physics ticks between a car entering the tree and being measured. The CSG
## blockout does not have a collider at all until its brushes have been built —
## which is the same wait [method Garage._lay_on_the_grime] documents — so a probe
## that measured on the tick it added the car would time an empty world and call it
## fast.
const SETTLE_TICKS: int = 8

## How many times each query is run. Different per query because they are orders of
## magnitude apart and the run should take seconds rather than minutes: a ray is
## cheap enough that a thousand of them is still noise unless there are a few
## thousand, and a sweep is dear enough that a few hundred is already a stable
## number.
const RAY_CALLS: int = 4000
const SWEEP_CALLS: int = 400
const BRUSH_CALLS: int = 400

## Calls thrown away before the clock starts, so the first query's broadphase
## warm-up is not divided into the average.
const WARMUP_CALLS: int = 8

## How far over the roofline the near-miss aim passes, in metres — the same
## quarter of a metre [code]tests/integration/test_play_screen_sweep.gd[/code]
## measured as clearing the exact ray on all ten styles while staying inside a
## 0.4 m sweep's window.
const NEAR_MISS_METRES: float = 0.25

## Where the eye stands to take these measurements: [constant EYE_STANDOFF] metres
## off the car's own flank at [constant EYE_HEIGHT] metres up.
##
## The standoff is [member Garage.standoff_metres], which is the gap the walk
## actually holds. The height is deliberately near the bottom of the room's own
## band ([member Garage.eye_height_min] is 1.1) rather than in the middle of it,
## and that is what makes the near-miss row a near miss at all: an eye above the
## aim point sends the ray down onto the far side of the roof, which is a hit and
## is a different measurement wearing this one's name. Low, the ray rises over the
## roofline and out into the sky on all three subjects — which the run asserts out
## loud rather than assuming.
const EYE_STANDOFF: float = 2.2
const EYE_HEIGHT: float = 1.2

## [member Garage.aim_reach] and [member Garage.wash_radius_metres]: how far the
## aim carries and how wide the power wash works. Copied rather than read off a
## [Garage], because building the whole room to get two floats would put the
## room's own per-tick work inside the thing measuring it.
const AIM_REACH: float = 40.0
const WASH_RADIUS: float = 0.4

## One tick of held trigger at [member Garage.wash_per_second] on a 60 Hz physics
## clock — the amount [method Garage._spend_the_trigger] actually hands the mask.
const WASH_PER_TICK: float = 5.0 / 60.0

## [member Grime.patches_per_tile], so the map built here is the size the game's is.
const PATCHES_PER_TILE: int = 5

var _subject: int = 0
var _ticks: int = 0
var _car: Car = null

## Somewhere for every answer to go, so nothing measured here is a call whose
## result was thrown away on the line it was made. It is printed at the end for the
## same reason — a total nobody reads is a total a future engine is free to notice
## nobody reads.
var _sink: int = 0


func _initialize() -> void:
	print(
		"perf-probe: %s calls a ray, %s a sweep, %s a brush" % [RAY_CALLS, SWEEP_CALLS, BRUSH_CALLS]
	)
	print("%-10s %-22s %12s" % ["car", "query", "usec/call"])


## One subject per pass: add it, let it settle, measure it, throw it away.
##
## On the physics clock because [member Viewport.world_3d] hands out a space state
## that may only be queried while physics is stepping — the same constraint that
## put [method Garage._resolve_aim] on this clock — and the whole point of this
## script is to make those queries where the game makes them.
func _physics_process(_delta: float) -> bool:
	if _car == null:
		if _subject >= SUBJECTS.size():
			print("perf-probe: done (%s)" % _sink)
			return true
		_car = _car_for(SUBJECTS[_subject])
		if _car == null:
			_subject += 1
			return false
		root.add_child(_car)
		_ticks = 0
		return false
	_ticks += 1
	if _ticks < SETTLE_TICKS:
		return false
	_measure(SUBJECTS[_subject], _car)
	root.remove_child(_car)
	_car.queue_free()
	_car = null
	_subject += 1
	return false


## The car named by [param subject]: the blockout fixture, or the bay's own scene
## with its style pinned to one of the pack's ten.
func _car_for(subject: String) -> Car:
	if subject == "blockout":
		var fixture: PackedScene = load(BLOCKOUT) as PackedScene
		return null if fixture == null else fixture.instantiate() as Car
	var packed: PackedScene = load(MESH_CAR) as PackedScene
	if packed == null:
		return null
	var car: MeshCar = packed.instantiate() as MeshCar
	if car != null:
		car.style = subject
	return car


## Every row for one car.
func _measure(subject: String, car: Car) -> void:
	var box: AABB = car.bounds()
	var middle: Vector3 = box.get_center()
	var eye: Vector3 = Vector3(box.end.x + EYE_STANDOFF, EYE_HEIGHT, middle.z)
	var at_the_car: Vector3 = middle
	var over_the_roof: Vector3 = Vector3(middle.x, box.end.y + NEAR_MISS_METRES, middle.z)
	var onto: Vector3 = (at_the_car - eye).normalized()
	var past: Vector3 = (over_the_roof - eye).normalized()
	var space: PhysicsDirectSpaceState3D = root.world_3d.direct_space_state
	_check_the_aims(subject, space, eye, onto, past)
	_row(subject, "intersect_ray, hit", _ray_usec(space, eye, onto))
	_row(subject, "intersect_ray, miss", _ray_usec(space, eye, past))
	_row(subject, "AimSweep, near", _sweep_usec(space, eye, past))
	_row(subject, "AimSweep, sky", _sweep_usec(space, eye, Vector3.UP))
	_row(subject, "GrimeMap.wash", _brush_usec(car))


## Says out loud whether the two aims are the presses they are named for, because
## every row below them means something different if they are not: a "miss" that
## quietly lands on the bodywork measures the cheap path and reports it as the
## expensive one, which is exactly the trap
## [code]tests/integration/test_play_screen_sweep.gd[/code] guards its own presses
## against.
func _check_the_aims(
	subject: String, space: PhysicsDirectSpaceState3D, eye: Vector3, onto: Vector3, past: Vector3
) -> void:
	var hit: Dictionary = space.intersect_ray(
		PhysicsRayQueryParameters3D.create(eye, eye + onto * AIM_REACH)
	)
	var missed: Dictionary = space.intersect_ray(
		PhysicsRayQueryParameters3D.create(eye, eye + past * AIM_REACH)
	)
	var sweep: AimSweep = AimSweep.new(AIM_REACH)
	var swept: Dictionary = sweep.onto(space, eye, past, WASH_RADIUS)
	print(
		(
			"; %s: the aim at the car %s, the aim over the roof %s, a %s m sweep down it %s"
			% [
				subject,
				"hits" if not hit.is_empty() else "MISSES (the hit row is wrong)",
				"misses" if missed.is_empty() else "HITS (the miss rows are wrong)",
				WASH_RADIUS,
				"lands" if not swept.is_empty() else "finds nothing (the near row is wrong)",
			]
		)
	)


## Microseconds per [method PhysicsDirectSpaceState3D.intersect_ray] down
## [param facing] from [param origin], query object and all — the room builds a
## fresh [PhysicsRayQueryParameters3D] on every tick and so does this.
func _ray_usec(space: PhysicsDirectSpaceState3D, origin: Vector3, facing: Vector3) -> float:
	for _warm: int in range(WARMUP_CALLS):
		_sink += (
			space
			. intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + facing * AIM_REACH))
			. size()
		)
	var began: int = Time.get_ticks_usec()
	for _call: int in range(RAY_CALLS):
		_sink += (
			space
			. intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + facing * AIM_REACH))
			. size()
		)
	return float(Time.get_ticks_usec() - began) / float(RAY_CALLS)


## Microseconds per [method AimSweep.onto] — which is the fan of twelve
## [method PhysicsDirectSpaceState3D.intersect_ray] calls that class rings the
## aim with. Measured through [AimSweep] rather than as one ray times twelve
## because the fan is what the room actually calls, and how many of its rays
## land — the dear case — depends on the aim in a way a single ray cannot say.
func _sweep_usec(space: PhysicsDirectSpaceState3D, origin: Vector3, facing: Vector3) -> float:
	var sweep: AimSweep = AimSweep.new(AIM_REACH)
	for _warm: int in range(WARMUP_CALLS):
		_sink += sweep.onto(space, origin, facing, WASH_RADIUS).size()
	var began: int = Time.get_ticks_usec()
	for _call: int in range(SWEEP_CALLS):
		_sink += sweep.onto(space, origin, facing, WASH_RADIUS).size()
	return float(Time.get_ticks_usec() - began) / float(SWEEP_CALLS)


## Microseconds per [method GrimeMap.wash] on the biggest panel of [param car],
## which is the [code]Body[/code] on a mesh car and the largest map the game builds.
##
## The map is made the way [method Grime.lay_on] makes one — the skin's own box,
## [method PanelResolution.tile_pixels_for] and [constant PATCHES_PER_TILE] — so
## the pixel count under the brush is the game's and not a number chosen here.
func _brush_usec(car: Car) -> float:
	var skin: GeometryInstance3D = car.skin_of(_biggest_panel(car))
	if skin == null:
		return 0.0
	var box: AABB = skin.get_aabb()
	var pixels: int = PanelResolution.tile_pixels_for(box)
	var map: GrimeMap = GrimeMap.new(box, pixels, PATCHES_PER_TILE)
	print("; the biggest panel is %s px a tile over %v" % [pixels, box.size])
	var began: int = Time.get_ticks_usec()
	for step: int in range(BRUSH_CALLS):
		# Walked across the top of the panel rather than held still — see the class
		# docs. `call + 1` over `calls + 1` so neither end of the drag sits exactly on
		# a corner of the box, where a brush is half off the face.
		var along: float = float(step + 1) / float(BRUSH_CALLS + 1)
		var at: Vector3 = Vector3(
			box.position.x + box.size.x * along, box.end.y, box.get_center().z
		)
		_sink += map.wash(at, Vector3.UP, WASH_RADIUS, WASH_PER_TICK).size()
	return float(Time.get_ticks_usec() - began) / float(BRUSH_CALLS)


## The panel of [param car] with the largest box — the one a player spends the most
## of the job looking at, and the map every other panel's is cheaper than.
func _biggest_panel(car: Car) -> Node3D:
	var biggest: Node3D = null
	var largest: float = -1.0
	for panel: Node3D in car.panels():
		var skin: GeometryInstance3D = car.skin_of(panel)
		if skin == null:
			continue
		var size: float = skin.get_aabb().size.length()
		if size > largest:
			largest = size
			biggest = panel
	return biggest


func _row(subject: String, query: String, usec: float) -> void:
	print("%-10s %-22s %12.2f" % [subject, query, usec])
