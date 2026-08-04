## Unit tests for [Scoring] — what a patch pays, and what a run of them does to
## it.
##
## [b]What is worth pinning here is the shape, not the tariff.[/b] The three
## point values are taste and are meant to be turned the first time somebody
## plays this for ten minutes; a test asserting that a wash pays exactly 100
## would be a test that goes red for a tuning commit and teaches nobody anything.
## What cannot be allowed to drift is the ordering the game's own rules imply —
## a buff is a pass over ground that was washed and foamed first, so it pays more
## than either — and the run behaviour, which is shared with the pitch of the
## bell and is the one thing here that can come apart from something else in the
## project.
##
## Under tests/unit/ because none of it needs a scene tree: the clock is a number
## handed to [method Scoring.score_at], which is exactly why the run is testable
## at all. A scorer reading [method Time.get_ticks_msec] internally could only be
## tested by a suite that waits [constant Bell.RUN_RESET_MSEC] in real seconds,
## once per assertion.
extends GutTest

## A time far enough from zero that a test cannot pass by accident on the
## first-patch special case in [method Scoring.score_at].
const NOW: int = 90_000

## A gap short enough to keep a run alive, in milliseconds.
const QUICK: int = 100

var _score: Scoring = null


func before_each() -> void:
	_score = Scoring.new()


## The three stages, in the order the job goes in.
func _stages() -> Array[GrimeMap.Stage]:
	return [GrimeMap.Stage.WASHED, GrimeMap.Stage.FOAMED, GrimeMap.Stage.BUFFED]


## Scores [param count] patches of [param stage] in quick succession from
## [constant NOW], so they are all one run, and hands back what the last one
## paid.
func _sweep(count: int, stage: GrimeMap.Stage) -> int:
	var paid: int = 0
	for index: int in count:
		paid = _score.score_at(stage, NOW + index * QUICK)
	return paid


func test_starts_at_nothing() -> void:
	assert_eq(_score.total(), 0, "a game nobody has played has a score")
	assert_eq(_score.patches(), 0, "and patches nobody has cleaned")
	assert_eq(_score.run(), Scoring.NO_RUN, "and a run nobody is on")
	assert_eq(_score.last_award(), 0, "and an award nobody earned")


## The ordering the layering makes true — see the file docs on why this and not
## the numbers themselves.
func test_a_later_pass_pays_more_than_an_earlier_one() -> void:
	var wash: int = Scoring.points_for(GrimeMap.Stage.WASHED)
	var foam: int = Scoring.points_for(GrimeMap.Stage.FOAMED)
	var buff: int = Scoring.points_for(GrimeMap.Stage.BUFFED)
	assert_gt(foam, wash, "foaming a patch pays no more than washing it did")
	assert_gt(buff, foam, "buffing a patch pays no more than foaming it did")


func test_every_stage_pays_something() -> void:
	for stage: GrimeMap.Stage in _stages():
		assert_gt(Scoring.points_for(stage), 0, "stage %d pays nothing" % stage)


func test_the_first_patch_of_a_run_pays_face_value() -> void:
	var paid: int = _score.score_at(GrimeMap.Stage.WASHED, NOW)
	assert_eq(paid, Scoring.points_for(GrimeMap.Stage.WASHED), "the first patch was multiplied")
	assert_eq(_score.multiplier(), 1, "and it was on a multiplier it should not have been")


func test_the_total_is_what_was_paid() -> void:
	var first: int = _score.score_at(GrimeMap.Stage.WASHED, NOW)
	var second: int = _score.score_at(GrimeMap.Stage.FOAMED, NOW + QUICK)
	assert_eq(_score.total(), first + second, "the total is not the sum of the awards")
	assert_eq(_score.patches(), 2, "two patches were scored and the count disagrees")
	assert_eq(_score.last_award(), second, "the last award is not the last one")


func test_a_run_climbs_and_pays_more_each_step() -> void:
	var paid: Array[int] = []
	for index: int in Scoring.MAX_MULTIPLIER:
		paid.append(_score.score_at(GrimeMap.Stage.WASHED, NOW + index * QUICK))
	for index: int in paid.size() - 1:
		assert_gt(paid[index + 1], paid[index], "step %d of a run paid no more" % index)
	assert_eq(_score.run(), Scoring.MAX_MULTIPLIER, "the run did not count every patch")


## The cap, and that it is a cap rather than a wrap or an error.
func test_a_run_holds_at_the_top_rather_than_climbing_past_it() -> void:
	var at_the_top: int = _sweep(Scoring.MAX_MULTIPLIER, GrimeMap.Stage.WASHED)
	var past_it: int = _sweep(Scoring.MAX_MULTIPLIER + 6, GrimeMap.Stage.WASHED)
	assert_eq(past_it, at_the_top, "a long run kept climbing past the cap")
	assert_eq(_score.multiplier(), Scoring.MAX_MULTIPLIER, "and reports a multiplier past it")


## The tie the whole feature rests on: the score's ceiling is the bell's ladder,
## so the pitch and the multiplier top out on the same patch. A change to one
## without the other is what this catches.
func test_the_multiplier_caps_where_the_bell_stops_climbing() -> void:
	assert_eq(
		Scoring.MAX_MULTIPLIER,
		Bell.PATCH_RUN_RATIOS.size(),
		"the multiplier and the ding no longer top out together"
	)


func test_a_long_enough_gap_ends_the_run() -> void:
	_sweep(Scoring.MAX_MULTIPLIER, GrimeMap.Stage.WASHED)
	var after: int = _score.score_at(
		GrimeMap.Stage.WASHED, NOW + Scoring.MAX_MULTIPLIER * QUICK + Bell.RUN_RESET_MSEC
	)
	assert_eq(after, Scoring.points_for(GrimeMap.Stage.WASHED), "the run survived the gap")
	assert_eq(_score.run(), 1, "and the run length says so")


func test_a_gap_just_inside_the_reset_keeps_the_run() -> void:
	_score.score_at(GrimeMap.Stage.WASHED, NOW)
	_score.score_at(GrimeMap.Stage.WASHED, NOW + Bell.RUN_RESET_MSEC - 1)
	assert_eq(_score.run(), 2, "a gap inside the reset ended the run anyway")


## The case the [member Scoring._started] flag exists for: a game that has been
## sitting on a loading screen for longer than the reset must not treat its very
## first patch as the continuation of a run that never happened.
func test_the_first_patch_of_a_late_game_starts_a_run() -> void:
	var paid: int = _score.score_at(GrimeMap.Stage.BUFFED, Bell.RUN_RESET_MSEC * 10)
	assert_eq(paid, Scoring.points_for(GrimeMap.Stage.BUFFED), "the first patch was multiplied")
	assert_eq(_score.run(), 1, "and it did not read as the start of a run")


func test_the_multiplier_is_never_zero_or_negative() -> void:
	assert_eq(Scoring.multiplier_for(Scoring.NO_RUN), 1, "a run of nothing wipes out an award")
	assert_eq(Scoring.multiplier_for(-5), 1, "a negative run wipes out an award")


## Nothing is scored twice by asking about it. The getters are the readout's only
## view of this class and a scoreboard that could move the score by drawing it
## would be a bug nobody would look for here.
func test_reading_the_score_does_not_change_it() -> void:
	_score.score_at(GrimeMap.Stage.FOAMED, NOW)
	var total: int = _score.total()
	for _index: int in 3:
		_score.total()
		_score.run()
		_score.multiplier()
		_score.last_award()
		_score.patches()
	assert_eq(_score.total(), total, "reading the score changed it")
