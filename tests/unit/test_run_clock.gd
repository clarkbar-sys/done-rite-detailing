## Unit test for [RunClock] — the three minutes a run gets, and how they read.
##
## Under [code]tests/unit/[/code] because the clock is driven by [param delta]
## rather than by a timestamp, which is exactly what makes a whole three-minute
## run one call and no waiting. What the screen does with it — starting it once
## the mud is on, and ending the run when it is out — is
## [code]tests/integration/test_play_screen_clock.gd[/code]'s.
extends GutTest

## One frame at 60 Hz, for the tests that care what a frame does rather than what
## a minute does.
const FRAME: float = 1.0 / 60.0

# ---- where it starts ------------------------------------------------------------


func test_a_fresh_clock_has_the_whole_run_on_it() -> void:
	assert_eq(RunClock.new().left(), RunClock.SECONDS)


func test_a_fresh_clock_is_not_running() -> void:
	# The reason it is not: laying the mud on is the longest frame the room will
	# ever have, and a clock counting through it charges the player for a load.
	assert_false(RunClock.new().is_running())


func test_a_fresh_clock_is_not_up() -> void:
	assert_false(RunClock.new().is_up())


func test_a_fresh_clock_is_not_warning() -> void:
	assert_false(RunClock.new().is_warning(), "three minutes is not nearly out of time")


func test_a_clock_can_be_built_shorter_for_a_test() -> void:
	assert_eq(RunClock.new(5.0).left(), 5.0)


func test_a_clock_cannot_be_built_with_less_than_nothing_on_it() -> void:
	assert_eq(RunClock.new(-10.0).left(), RunClock.UP)


# ---- ticking ---------------------------------------------------------------------


func test_a_stopped_clock_does_not_count() -> void:
	var clock: RunClock = RunClock.new()
	clock.tick(10.0)
	assert_eq(clock.left(), RunClock.SECONDS, "the meter ran before the run did")


func test_a_started_clock_counts_down() -> void:
	var clock: RunClock = RunClock.new()
	clock.start()
	clock.tick(10.0)
	assert_almost_eq(clock.left(), RunClock.SECONDS - 10.0, 0.0001)


func test_starting_a_running_clock_does_not_put_the_time_back() -> void:
	# What a second `grimed` would do. It must not be a free minute.
	var clock: RunClock = RunClock.new()
	clock.start()
	clock.tick(10.0)
	clock.start()
	assert_almost_eq(clock.left(), RunClock.SECONDS - 10.0, 0.0001)


func test_a_whole_run_spent_a_frame_at_a_time_runs_out() -> void:
	# The claim the delta-driven design is for: a three-minute run is a loop in a
	# unit test rather than three minutes of CI.
	var clock: RunClock = RunClock.new()
	clock.start()
	for _frame: int in ceili(RunClock.SECONDS / FRAME):
		clock.tick(FRAME)
	assert_true(clock.is_up(), "the run never ended")


func test_the_clock_stops_at_zero_rather_than_going_negative() -> void:
	var clock: RunClock = RunClock.new()
	clock.start()
	clock.tick(RunClock.SECONDS * 10.0)
	assert_eq(clock.left(), RunClock.UP, "a readout cannot print a negative minute")


func test_a_clock_that_has_run_out_is_up() -> void:
	var clock: RunClock = RunClock.new(1.0)
	clock.start()
	assert_false(clock.is_up())
	clock.tick(1.0)
	assert_true(clock.is_up())


# ---- the warning ------------------------------------------------------------------


func test_the_warning_comes_on_at_the_threshold() -> void:
	var clock: RunClock = RunClock.new()
	clock.start()
	clock.tick(RunClock.SECONDS - RunClock.WARNING_SECONDS - 1.0)
	assert_false(clock.is_warning(), "a second before the threshold is not the threshold")
	clock.tick(1.0)
	assert_true(clock.is_warning())


func test_the_warning_stays_on_once_the_time_is_up() -> void:
	var clock: RunClock = RunClock.new(1.0)
	clock.start()
	clock.tick(1.0)
	assert_true(clock.is_warning())


# ---- how it reads -------------------------------------------------------------------


func test_a_full_clock_reads_as_the_whole_run() -> void:
	assert_eq(RunClock.spell(RunClock.SECONDS), "3:00")


func test_the_seconds_are_zero_padded_and_the_minutes_are_not() -> void:
	assert_eq(RunClock.spell(65.0), "1:05")
	assert_eq(RunClock.spell(9.0), "0:09")


func test_the_reading_rounds_up() -> void:
	# The arcade convention, and the reason: a clock counting down shows the time
	# you have left, so 3:00 is on screen for the whole of the first second and
	# 0:00 arrives exactly when there is nothing left rather than a second early.
	assert_eq(RunClock.spell(RunClock.SECONDS - 0.001), "3:00")
	assert_eq(RunClock.spell(0.001), "0:01")


func test_nothing_left_reads_as_zero() -> void:
	assert_eq(RunClock.spell(RunClock.UP), "0:00")


func test_a_negative_reading_still_reads_as_zero() -> void:
	# Unreachable through `tick`, which floors — this is the belt to that braces.
	assert_eq(RunClock.spell(-5.0), "0:00")


func test_whole_seconds_is_what_a_readout_compares_against() -> void:
	assert_eq(RunClock.whole_seconds(2.4), 3)
	assert_eq(RunClock.whole_seconds(3.0), 3, "a whole second is already whole")


func test_the_reading_never_skips_a_second_over_a_whole_run() -> void:
	# The property a readout actually depends on: stepped a frame at a time, the
	# printed second goes down by exactly one each time it changes. A ceil that
	# disagreed with the floor at either end would show up here as a jump.
	var clock: RunClock = RunClock.new()
	clock.start()
	var last: int = RunClock.whole_seconds(clock.left())
	for _frame: int in ceili(RunClock.SECONDS / FRAME):
		clock.tick(FRAME)
		var now: int = RunClock.whole_seconds(clock.left())
		assert_true(now == last or now == last - 1, "the clock jumped from %d to %d" % [last, now])
		last = now
	assert_eq(last, 0, "and it has to arrive at zero")
