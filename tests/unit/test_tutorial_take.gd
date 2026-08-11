## Unit tests for [TutorialTake] — the running order, the lengths and the ending of
## one tutorial clip.
##
## Under tests/unit/ for [code]tests/unit/test_attract_routine.gd[/code]'s reason,
## which is the whole argument for the take being a [RefCounted] at all: a take is a
## clock and three answers, so the entire catalogue is checked here in a few dozen
## calls rather than by watching four minutes of footage. That the room really does
## come clean under one is
## [code]tests/integration/test_tutorial_take_screen.gd[/code]'s job.
extends GutTest

## One physics tick at the engine's default rate — the delta a take is really
## advanced by.
const TICK: float = 1.0 / 60.0

## A box a metre and a half long, half a metre deep and a metre tall, offset from
## the origin so a sweep that forgot the centre fails instead of landing on it. The
## same panel [code]tests/unit/test_attract_routine.gd[/code] sweeps, deliberately:
## the two classes share the sweep and should be asked about it in the same terms.
const PANEL: AABB = AABB(Vector3(2.0, 1.0, -0.25), Vector3(1.5, 1.0, 0.5))


## Runs [param take] on for [param seconds], a tick at a time the way the room does,
## and then half a tick further.
##
## The half tick is [code]test_attract_routine.gd[/code]'s and is here for the same
## reason: a sum of sixtieths lands on either side of a beat boundary depending on
## rounding nobody controls, so "run a beat" has to mean deliberately just past it.
func _run(take: TutorialTake, seconds: float) -> void:
	var ticks: int = int(seconds / TICK)
	for _tick: int in range(ticks):
		take.advance(TICK)
	take.advance(seconds - float(ticks) * TICK + TICK * 0.5)


## Every tool [param take] holds over its whole length, in order, with repeats
## collapsed — which is the sequence a viewer actually sees in its hands.
func _tools(take: TutorialTake) -> Array[int]:
	var seen: Array[int] = []
	for _tick: int in range(int(take.seconds() / TICK)):
		if seen.is_empty() or seen[-1] != int(take.tool()):
			seen.append(int(take.tool()))
		take.advance(TICK)
	return seen


# ---- the catalogue: which takes there are and how they are asked for -----------


func test_every_take_in_the_catalogue_can_be_built() -> void:
	# The catalogue is what the command line is checked against and what it prints
	# back at somebody who typed a name wrong, so a name in it with no take behind it
	# would be advice to run something that does not exist.
	for asked: String in TutorialTake.catalogue():
		assert_not_null(TutorialTake.named(asked), "no take behind catalogue entry '%s'" % asked)


func test_the_catalogue_is_the_five_beats() -> void:
	assert_eq(
		TutorialTake.catalogue(),
		PackedStringArray(
			[
				TutorialTake.WATER,
				TutorialTake.SPONGE,
				TutorialTake.GLASS,
				TutorialTake.RAG,
				TutorialTake.FULL
			]
		),
		"one take per tutorial beat, plus the whole job on one panel"
	)


func test_a_take_nobody_has_filmed_is_refused_rather_than_guessed_at() -> void:
	# The caller is a command line. Handing back a fallback take would film the wrong
	# clip under the right filename, which is the one failure a capture harness cannot
	# see in its own artifact.
	assert_null(TutorialTake.named("rinse"), "an unknown take must be nothing at all")
	assert_null(TutorialTake.named(""))


func test_it_reads_the_take_off_the_command_line() -> void:
	assert_eq(
		TutorialTake.asked_for(PackedStringArray(["--take=sponge"])),
		TutorialTake.SPONGE,
		"--take= is how the harness says which clip it wants"
	)


func test_a_command_line_with_no_take_on_it_asks_for_nothing() -> void:
	# Which is every command line a player ever uses, and the branch that has to leave
	# the title screen alone.
	assert_eq(TutorialTake.asked_for(PackedStringArray()), "")
	assert_eq(TutorialTake.asked_for(PackedStringArray(["--headless", "--take"])), "")


func test_the_first_take_on_the_line_wins() -> void:
	# Two of them is a mistake either way; picking the first is the answer that does
	# not depend on how the harness happened to build its arguments.
	assert_eq(
		TutorialTake.asked_for(PackedStringArray(["--take=water", "--take=rag"])),
		TutorialTake.WATER
	)


# ---- the beats: what is on screen, and with what -------------------------------


func test_the_water_take_is_one_pass_and_starts_on_the_wand() -> void:
	# The only take with no lead-in: mud is what a panel starts as, so there is
	# nothing to do to it first.
	var take: TutorialTake = TutorialTake.named(TutorialTake.WATER)
	assert_eq(take.beats(), 1, "one beat, because the subject is the first pass")
	assert_eq(take.stage(), GrimeMap.Stage.WASHED)
	assert_eq(take.tool(), DetailingTool.Id.POWER_WASH)


func test_the_sponge_take_washes_first_and_then_soaps() -> void:
	# The lead-in, and the whole reason there is one: a sponge on a muddy panel moves
	# nothing, so a take that opened on the subject would film six seconds of a tool
	# doing exactly what the game says it should — which is nothing.
	var take: TutorialTake = TutorialTake.named(TutorialTake.SPONGE)
	assert_eq(take.beats(), 2)
	assert_eq(take.tool(), DetailingTool.Id.POWER_WASH, "the water goes first")
	_run(take, TutorialTake.LEAD_SECONDS)
	assert_eq(take.stage(), GrimeMap.Stage.FOAMED)
	assert_eq(take.tool(), DetailingTool.Id.SPONGE, "and the subject is what is left")


func test_the_glass_take_reaches_for_the_blue_bottle() -> void:
	# The take that stands in for the rinse the game does not have — see the class
	# docs — and it earns its place by being the one where the belt matters.
	var take: TutorialTake = TutorialTake.named(TutorialTake.GLASS)
	assert_eq(take.kind(), Surface.Kind.GLASS)
	_run(take, TutorialTake.LEAD_SECONDS)
	assert_eq(take.tool(), Surface.cleaner_for(Surface.Kind.GLASS))


func test_the_rag_take_plays_the_whole_job_with_the_shine_last() -> void:
	var take: TutorialTake = TutorialTake.named(TutorialTake.RAG)
	assert_eq(take.beats(), 3, "a rag needs both of the other passes to have happened")
	assert_eq(
		_tools(take),
		(
			[
				int(DetailingTool.Id.POWER_WASH),
				int(DetailingTool.Id.SPONGE),
				int(DetailingTool.Id.DRYING_RAG)
			]
			as Array[int]
		),
		"water, then the bottle, then the cloth — the order the buckets force"
	)


func test_the_full_take_gives_all_three_passes_the_same_room() -> void:
	# The difference between this and the rag take, and the only difference: the same
	# three passes, none of them a lead-in for another.
	var take: TutorialTake = TutorialTake.named(TutorialTake.FULL)
	for beat: int in range(take.beats()):
		assert_eq(take.seconds_of(beat), TutorialTake.BEAT_SECONDS, "beat %d is short" % beat)


func test_a_lead_in_is_shorter_than_the_pass_the_take_is_about() -> void:
	# What tells a viewer which of the passes they were meant to be watching. If these
	# were the same length the sponge clip would be half a wash clip.
	var take: TutorialTake = TutorialTake.named(TutorialTake.RAG)
	assert_lt(take.seconds_of(0), take.seconds_of(take.beats() - 1))
	assert_eq(take.seconds_of(0), TutorialTake.LEAD_SECONDS)


# ---- the clock: how long a take is, and how it ends -----------------------------


func test_a_take_is_its_beats_plus_the_tail() -> void:
	# The number a capture harness records for, and it is known before a frame is
	# drawn — which is the whole of "fixed running time".
	var take: TutorialTake = TutorialTake.named(TutorialTake.RAG)
	assert_almost_eq(
		take.seconds(),
		TutorialTake.LEAD_SECONDS * 2.0 + TutorialTake.BEAT_SECONDS + TutorialTake.HOLD_SECONDS,
		0.0001
	)


func test_every_take_ends_on_the_clock_and_not_before() -> void:
	for asked: String in TutorialTake.catalogue():
		var take: TutorialTake = TutorialTake.named(asked)
		_run(take, take.seconds() - TICK * 2.0)
		assert_false(take.finished(), "'%s' ended early" % asked)
		_run(take, TICK * 2.0)
		assert_true(take.finished(), "'%s' has to end on time" % asked)


func test_the_trigger_comes_off_for_the_tail() -> void:
	# So the last frame of a clip is the finished panel rather than the panel behind a
	# faceful of water. See [constant TutorialTake.HOLD_SECONDS].
	var take: TutorialTake = TutorialTake.named(TutorialTake.WATER)
	assert_true(take.working(), "a take opens working")
	_run(take, take.seconds() - TutorialTake.HOLD_SECONDS)
	assert_false(take.working(), "the trigger is off for the whole tail")
	assert_false(take.finished(), "which is not the same thing as being over")


func test_the_tail_holds_the_subject_rather_than_running_past_it() -> void:
	# An index past the end of the film would be a stage nothing has a tool for.
	var take: TutorialTake = TutorialTake.named(TutorialTake.SPONGE)
	_run(take, take.seconds())
	assert_eq(take.stage(), take.subject(), "the shot holds on what the take was about")
	assert_eq(take.beat(), take.beats() - 1)


func test_a_frame_long_enough_to_cover_two_beats_lands_in_the_right_one() -> void:
	# The web build's first frame back from a backgrounded tab really is seconds long,
	# and a take is timed rather than stepped, so this must be arithmetic rather than
	# a beat consumed per call.
	var take: TutorialTake = TutorialTake.named(TutorialTake.RAG)
	take.advance(TutorialTake.LEAD_SECONDS * 2.0 + TICK)
	assert_eq(take.stage(), GrimeMap.Stage.BUFFED, "two beats' worth of time is two beats")


func test_time_running_backwards_moves_nothing() -> void:
	var take: TutorialTake = TutorialTake.named(TutorialTake.FULL)
	take.advance(-TutorialTake.BEAT_SECONDS)
	assert_eq(take.elapsed(), 0.0, "a film does not run backwards")
	assert_eq(take.stage(), GrimeMap.Stage.WASHED)


func test_progress_runs_from_nothing_to_all_of_it_inside_each_beat() -> void:
	var take: TutorialTake = TutorialTake.named(TutorialTake.SPONGE)
	assert_almost_eq(take.progress(), 0.0, TICK, "a beat starts at its beginning")
	_run(take, TutorialTake.LEAD_SECONDS * 0.5)
	assert_almost_eq(take.progress(), 0.5, TICK, "and is half done halfway through")
	_run(take, TutorialTake.LEAD_SECONDS * 0.5)
	assert_almost_eq(take.progress(), 0.0, TICK, "the next beat starts at its own beginning")


func test_progress_stops_at_the_end_of_the_last_beat() -> void:
	# Not at the end of the take: the hand has finished its sweep when the trigger
	# comes off, and the tail is a held shot rather than a sweep off the panel.
	var take: TutorialTake = TutorialTake.named(TutorialTake.WATER)
	_run(take, take.seconds())
	assert_eq(take.progress(), 1.0)


func test_a_beat_of_no_length_is_refused_rather_than_divided_by() -> void:
	# The fence [constant AttractRoutine.MIN_SECONDS] already draws, borrowed rather
	# than redrawn: a take of zero length is not a very fast film, it is a division by
	# nothing in [method TutorialTake.beat]. Reaching the assertion is most of it.
	var frozen: TutorialTake = TutorialTake.new(
		"frozen", Surface.Kind.BODY, GrimeMap.Stage.BUFFED, 0.0, 0.0
	)
	frozen.advance(TICK)
	assert_gt(frozen.seconds(), 0.0, "a zero-length beat must be clamped to something positive")


# ---- the hand: where the tool is pointed ---------------------------------------


func test_the_aim_is_the_demo_s_own_sweep() -> void:
	# Not a similar sweep. The tutorial footage is of the hand people have already
	# watched on the title screen, and the day the two drifted apart it would stop
	# being.
	var take: TutorialTake = TutorialTake.named(TutorialTake.WATER)
	_run(take, TutorialTake.BEAT_SECONDS * 0.3)
	assert_eq(take.aim_over(PANEL), AttractRoutine.sweep_over(PANEL, take.progress()))


func test_the_aim_stays_on_the_panel_for_the_whole_take() -> void:
	# Every sample, tail included: a take that pointed off the panel would film the
	# air beside the bodywork with the trigger down.
	var take: TutorialTake = TutorialTake.named(TutorialTake.SPONGE)
	for _tick: int in range(int(take.seconds() / TICK)):
		assert_true(PANEL.has_point(take.aim_over(PANEL)), "the aim must be on the panel")
		take.advance(TICK)
