## Unit tests for [AttractRoutine] — the running order the title screen's demo
## works the car in.
##
## Under tests/unit/ because the routine is a [RefCounted] that has never heard of
## a panel, a camera or a frame: it is handed a list of surfaces and a clock, so a
## full lap of a twelve-panel car is a `for` loop here rather than two minutes of
## somebody watching a title screen. That the car really does come clean under it
## is [code]tests/integration/test_title_screen_attract.gd[/code]'s job.
extends GutTest

## Long enough that a tick is plainly a fraction of a pass, short enough that a
## whole lap is a few dozen calls.
const PASS_SECONDS: float = 4.0

## One physics tick at the engine's default rate — the delta this is really
## called with.
const TICK: float = 1.0 / 60.0

## A running order with all three surfaces in it, so the tool the middle pass
## reaches for is a different answer at each stop rather than the same one three
## times.
const ORDER: Array[Surface.Kind] = [Surface.Kind.BODY, Surface.Kind.GLASS, Surface.Kind.WHEEL]

## A box a metre and a half long, half a metre deep and a metre tall, offset from
## the origin so a sweep that forgot the centre fails instead of landing on it.
const PANEL: AABB = AABB(Vector3(2.0, 1.0, -0.25), Vector3(1.5, 1.0, 0.5))

var _routine: AttractRoutine = null
var _laps: int = 0


func before_each() -> void:
	_laps = 0
	_routine = AttractRoutine.new(ORDER, PASS_SECONDS)
	_routine.lapped.connect(_count_lap)


func _count_lap() -> void:
	_laps += 1


## Runs the clock for [param seconds] a tick at a time, the way the room does,
## and then half a tick further.
##
## The half tick is the point. A sum of sixtieths lands on either side of a pass
## boundary depending on rounding nobody controls, so a call asking for exactly one
## pass would tick the pass over on some machines and not on others. Landing
## deliberately just past the boundary makes "run a pass" mean one thing; half a
## tick is far too small for anything below to be about.
func _run(seconds: float) -> void:
	var ticks: int = int(seconds / TICK)
	for _tick: int in range(ticks):
		_routine.advance(TICK)
	_routine.advance(seconds - float(ticks) * TICK + TICK * 0.5)


## Every (stop, tool) the routine passes through over [param seconds].
func _watch(seconds: float) -> Array[String]:
	var seen: Array[String] = []
	for _tick: int in range(int(seconds / TICK)):
		var now: String = "%d:%d" % [_routine.stop(), _routine.tool()]
		if seen.is_empty() or seen[-1] != now:
			seen.append(now)
		_routine.advance(TICK)
	return seen


# ---- the running order: what is being worked, and with what --------------------


func test_it_starts_on_the_first_panel_with_the_water() -> void:
	# The order the whole thing depends on. Starting anywhere else — on the rag, on
	# the second panel — would still look like a demo and would be showing the job
	# being done in an order the game refuses.
	assert_eq(_routine.stop(), 0, "the demo starts at the top of the running order")
	assert_eq(_routine.stage(), GrimeMap.Stage.WASHED, "and mud comes off first")
	assert_eq(_routine.tool(), DetailingTool.Id.POWER_WASH)


func test_the_three_passes_are_water_then_a_bottle_then_the_rag() -> void:
	# The order [GrimeMap]'s buckets already force on a player. A demo that soaped a
	# muddy panel would move nothing and look broken, and it would look broken in
	# the one place nobody is around to press anything.
	_run(PASS_SECONDS)
	assert_eq(_routine.stage(), GrimeMap.Stage.FOAMED, "product goes on the paint the water left")
	_run(PASS_SECONDS)
	assert_eq(_routine.stage(), GrimeMap.Stage.BUFFED, "and the rag turns it into a shine")


func test_the_middle_pass_reaches_for_the_bottle_the_surface_wants() -> void:
	# The reason the demo swaps tools at all, and the reason the running order
	# carries surfaces rather than panel names: three stops of three different kinds
	# are three different bottles, without anybody scripting a tour of the belt.
	for kind: Surface.Kind in ORDER:
		_run(PASS_SECONDS)
		assert_eq(_routine.tool(), Surface.cleaner_for(kind), "the wrong bottle does nothing")
		_run(PASS_SECONDS * 2.0)


func test_the_water_and_the_rag_do_not_care_what_the_panel_is() -> void:
	# [Surface] deliberately has no entry for either — see its class docs — so the
	# first and last pass have to be the same tool at every stop.
	for _stop: int in range(ORDER.size()):
		assert_eq(_routine.tool(), DetailingTool.Id.POWER_WASH)
		_run(PASS_SECONDS * 2.0)
		assert_eq(_routine.tool(), DetailingTool.Id.DRYING_RAG)
		_run(PASS_SECONDS)


func test_it_moves_on_to_the_next_panel_after_three_passes() -> void:
	_run(PASS_SECONDS * 3.0)
	assert_eq(_routine.stop(), 1, "a panel is three passes and then the next one")
	assert_eq(_routine.stage(), GrimeMap.Stage.WASHED, "which starts with the water again")


func test_it_swaps_tools_between_every_pass() -> void:
	# The arcade half of the ask: something in the player's hands changes often
	# enough that a glance at the screen catches it. Three passes over three stops
	# is nine states and no two neighbours alike.
	var seen: Array[String] = _watch(PASS_SECONDS * ORDER.size() * AttractRoutine.PASSES)
	assert_eq(seen.size(), ORDER.size() * AttractRoutine.PASSES, "one state per pass, no repeats")


# ---- the lap: what happens when the car is finished ----------------------------


func test_a_full_lap_wraps_back_to_the_first_panel() -> void:
	_run(PASS_SECONDS * ORDER.size() * AttractRoutine.PASSES)
	assert_eq(_routine.stop(), 0, "an attract mode that ran out is a title screen again")
	assert_eq(_routine.stage(), GrimeMap.Stage.WASHED)


func test_it_says_so_when_a_lap_ends() -> void:
	# What the room puts the mud back on. A flag polled instead would be true for
	# one tick, and a room that missed that tick would show a clean car for a
	# whole lap.
	_run(PASS_SECONDS * ORDER.size() * AttractRoutine.PASSES)
	assert_eq(_laps, 1, "the end of a lap must be announced exactly once")


func test_it_says_nothing_until_the_last_panel_is_buffed() -> void:
	# One pass short. The car still has product on the last panel here, and a demo
	# that reset now would be showing a wash that never finished.
	_run(PASS_SECONDS * ORDER.size() * AttractRoutine.PASSES - PASS_SECONDS)
	assert_eq(_laps, 0, "the lap is not over until the rag has been over everything")


func test_it_keeps_going_round() -> void:
	_run(PASS_SECONDS * ORDER.size() * AttractRoutine.PASSES * 3.0)
	assert_eq(_laps, 3, "the demo loops rather than stopping on a clean car")


# ---- the clock ---------------------------------------------------------------


func test_progress_runs_from_nothing_to_all_of_it_across_a_pass() -> void:
	assert_almost_eq(_routine.progress(), 0.0, TICK, "a pass starts at its beginning")
	_run(PASS_SECONDS * 0.5)
	assert_almost_eq(_routine.progress(), 0.5, TICK, "and is half done halfway through")


func test_a_frame_long_enough_to_cover_two_passes_advances_by_two() -> void:
	# The web build's first frame back from a backgrounded tab really is seconds
	# long. Consuming one pass per call instead would leave the demo falling further
	# behind the longer it ran, which looks like a demo that has stopped.
	_routine.advance(PASS_SECONDS * 2.0)
	assert_eq(_routine.stage(), GrimeMap.Stage.BUFFED, "two passes' worth of time is two passes")


func test_a_frame_that_took_no_time_moves_nothing() -> void:
	_routine.advance(0.0)
	assert_eq(_routine.stage(), GrimeMap.Stage.WASHED)
	assert_almost_eq(_routine.progress(), 0.0, TICK)


func test_time_running_backwards_moves_nothing_either() -> void:
	# Not a thing the engine hands out, and not a thing worth crashing on: a
	# negative delta must not walk the demo back through a pass it already did.
	_routine.advance(-PASS_SECONDS)
	assert_eq(_routine.stage(), GrimeMap.Stage.WASHED)


func test_a_pass_of_no_length_is_refused_rather_than_looped_on() -> void:
	# The fence, and the reason it is a fence. [method AttractRoutine.advance]
	# consumes whole passes in a `while`, so a length of zero is not a very fast
	# demo — it is that loop never ending, inside one frame, with a black screen
	# and no error. Reaching the assertion at all is most of the test.
	var frozen: AttractRoutine = AttractRoutine.new(ORDER, 0.0)
	frozen.advance(TICK)
	assert_lt(frozen.progress(), 1.0, "a zero-length pass must be clamped to something positive")


func test_an_empty_running_order_holds_still() -> void:
	# A room with no car in it is a thing a test can build, and it should not have
	# to be special-cased by everything that drives one.
	var nothing: AttractRoutine = AttractRoutine.new([] as Array[Surface.Kind], PASS_SECONDS)
	nothing.advance(PASS_SECONDS * 10.0)
	assert_eq(nothing.stop(), 0, "there is nothing to work and nowhere to move on to")


# ---- the sweep: where on the panel the tool is pointed -------------------------


func test_the_aim_stays_on_the_panel() -> void:
	# The sweep wanders a bounding box, and a bounding box is bigger than the panel
	# inside it — so running to the edges would spend a good part of every pass
	# pointed at the air beside the bodywork. Every sample, across a whole pass.
	for _tick: int in range(int(PASS_SECONDS / TICK)):
		assert_true(PANEL.has_point(_routine.aim_over(PANEL)), "the aim must be on the panel")
		_routine.advance(TICK)


func test_the_aim_moves_while_the_pass_runs() -> void:
	# A tool held on one spot for four seconds cleans a coin-sized patch and reads
	# as a demo that has frozen.
	var started: Vector3 = _routine.aim_over(PANEL)
	_run(PASS_SECONDS * 0.25)
	assert_gt(_routine.aim_over(PANEL).distance_to(started), 0.0, "the hand has to move")


func test_it_works_down_the_panel_as_the_pass_goes() -> void:
	# Side to side while coming down, which is the motion a person makes. The
	# vertical half is the one that guarantees coverage: without it the sweep would
	# rub the same stripe for the whole pass however fast it crossed.
	var top: float = _routine.aim_over(PANEL).y
	_run(PASS_SECONDS * 0.9)
	assert_lt(_routine.aim_over(PANEL).y, top, "the pass must end lower than it started")


func test_it_crosses_the_long_way_along_the_panel() -> void:
	# A door's box is long in x or in z depending on which panel it is and which way
	# the car is parked; sweeping along the short one would rub a stripe. The box
	# above is long in x, so x is the axis that must be spending its width.
	var reached: Vector2 = Vector2(PANEL.get_center().x, PANEL.get_center().x)
	for _tick: int in range(int(PASS_SECONDS / TICK)):
		var at: Vector3 = _routine.aim_over(PANEL)
		reached = Vector2(minf(reached.x, at.x), maxf(reached.y, at.x))
		assert_almost_eq(at.z, PANEL.get_center().z, 0.0001, "the short axis stays at the middle")
		_routine.advance(TICK)
	assert_gt(reached.y - reached.x, PANEL.size.x * 0.5, "the sweep must cover the panel's length")
