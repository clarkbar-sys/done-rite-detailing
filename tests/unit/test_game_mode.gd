## Unit test for [GameMode] — the two games, and the one number that is the
## whole difference between them.
##
## Under [code]tests/unit/[/code] because the mode is a static field and two
## static functions with no [SceneTree] anywhere near them, which is the same
## shape [code]tests/unit/test_car_choice.gd[/code] covers and for the same
## reason. What the menu does with it is
## [code]tests/integration/test_main_menu.gd[/code]'s, what the bay does with it
## is [code]tests/integration/test_play_screen_clock.gd[/code]'s, and what the
## board does with it is [code]tests/integration/test_job_done.gd[/code]'s.
##
## [b]The choice is put back after every test.[/b] It is process-wide by design,
## so a suite that set one and left it would hand it to whichever suite runs
## next — the same trap [CarChoice] and [RunResult] are already restored for.
extends GutTest

var _chosen_before: GameMode.Kind = GameMode.Kind.ARCADE


func before_each() -> void:
	_chosen_before = GameMode.chosen


func after_each() -> void:
	GameMode.choose(_chosen_before)


func test_the_game_starts_in_the_arcade() -> void:
	# Not an "unset" third value: the title card and the rules screen both lead
	# into a run, and the run they have always led into is the timed one.
	GameMode.forget()
	assert_eq(GameMode.chosen, GameMode.Kind.ARCADE)


func test_choosing_one_remembers_it() -> void:
	GameMode.choose(GameMode.Kind.SIMULATION)
	assert_eq(GameMode.chosen, GameMode.Kind.SIMULATION)


func test_forgetting_puts_it_back_to_the_arcade() -> void:
	GameMode.choose(GameMode.Kind.SIMULATION)
	GameMode.forget()
	assert_eq(GameMode.chosen, GameMode.Kind.ARCADE, "a suite must be able to leave no trace")


func test_the_arcade_is_the_clock_the_rest_of_the_game_is_written_around() -> void:
	assert_eq(GameMode.seconds_for(GameMode.Kind.ARCADE), RunClock.SECONDS)


func test_the_simulation_has_no_clock_on_it() -> void:
	assert_eq(GameMode.seconds_for(GameMode.Kind.SIMULATION), RunClock.UNTIMED)


func test_the_two_modes_are_not_the_same_length() -> void:
	# The claim the whole feature rests on. If these two ever agree there is one
	# game on the menu wearing two pills.
	assert_ne(
		GameMode.seconds_for(GameMode.Kind.ARCADE), GameMode.seconds_for(GameMode.Kind.SIMULATION)
	)


func test_only_the_arcade_is_played_against_a_clock() -> void:
	assert_true(GameMode.is_timed(GameMode.Kind.ARCADE))
	assert_false(GameMode.is_timed(GameMode.Kind.SIMULATION))


func test_being_timed_is_read_off_the_length_rather_than_written_down_twice() -> void:
	# Every mode the enum has, held to the one table. A third mode added to
	# `seconds_for` and forgotten in `is_timed` fails here rather than shipping as
	# a run that cannot end.
	for kind: GameMode.Kind in [GameMode.Kind.ARCADE, GameMode.Kind.SIMULATION]:
		assert_eq(
			GameMode.is_timed(kind),
			GameMode.seconds_for(kind) != RunClock.UNTIMED,
			"mode %d disagrees with its own length" % kind
		)


func test_a_length_a_clock_can_actually_be_built_with() -> void:
	# The one caller that matters: the play screen hands `seconds_for` straight to
	# RunClock. Both answers have to come back out of it unchanged, which is what
	# says neither is being floored or clamped on the way in.
	for kind: GameMode.Kind in [GameMode.Kind.ARCADE, GameMode.Kind.SIMULATION]:
		var clock: RunClock = RunClock.new(GameMode.seconds_for(kind))
		assert_eq(clock.left(), GameMode.seconds_for(kind))
		assert_eq(clock.is_timed(), GameMode.is_timed(kind))
