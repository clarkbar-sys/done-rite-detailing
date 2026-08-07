## Unit test for [CarChoice] — which of the ten cars the player asked for, and
## what each of them is called on screen.
##
## Under tests/unit/ because none of it needs a [SceneTree]: the list of styles
## it is asked about arrives as an argument, so every claim here is about a
## static field and a table. What happens when a screen actually uses it — the
## arrows on the menu, the car that turns up in the bay — is
## [code]tests/integration/test_main_menu.gd[/code]'s.
##
## [b]Every test here puts the choice back.[/b] It is process-wide by design, so
## a suite that set one and walked away would hand it to whichever suite runs
## next — and the symptom would be a play-screen test measuring a pickup for
## reasons nothing in its own file mentions. The same care
## [code]test_main_menu.gd[/code] already takes over [member Sound.muted].
extends GutTest

## A list that is deliberately not the pack's: what these functions do with a
## list is not supposed to depend on which list, and a fixture makes the wrap
## cases readable — four is short enough to count.
const FOUR: Array[String] = ["one", "two", "three", "four"]

## Enough draws that a broken random path shows up as membership failing rather
## than as luck. Asserted as membership and never as variety, for
## [code]tests/integration/test_mesh_car.gd[/code]'s reason: a test that demanded
## a spread would fail once in a very long while for no reason.
const DRAWS: int = 12

var _chosen_before: String = ""


func before_each() -> void:
	_chosen_before = CarChoice.chosen
	CarChoice.forget()


func after_each() -> void:
	CarChoice.choose(_chosen_before)


# ---- what is remembered -------------------------------------------------------


func test_nobody_has_chosen_when_a_run_starts() -> void:
	assert_eq(CarChoice.chosen, "", "a fresh run must not claim the player picked something")


func test_a_choice_is_remembered() -> void:
	CarChoice.choose("pickup")
	assert_eq(CarChoice.chosen, "pickup", "the pick must survive the screen that made it")


func test_the_last_choice_is_the_one_that_counts() -> void:
	CarChoice.choose("pickup")
	CarChoice.choose("minivan")
	assert_eq(CarChoice.chosen, "minivan", "flicking through must not stack up answers")


func test_forgetting_puts_it_back_to_nobody() -> void:
	CarChoice.choose("sport")
	CarChoice.forget()
	assert_eq(CarChoice.chosen, "", "forget must mean what a run start means")


# ---- the car the next room should park ----------------------------------------


func test_a_car_nobody_has_chosen_is_still_a_draw_from_the_list() -> void:
	# The branch that keeps the game's original behaviour alive rather than
	# replacing it: the title card is up before any screen has offered a choice,
	# and the car it shows is one of the ten exactly as it always was.
	#
	# Forgotten between draws, because one draw is all a run gets — see below.
	for _each: int in range(DRAWS):
		CarChoice.forget()
		assert_has(FOUR, CarChoice.for_the_next_car(FOUR), "an unasked-for car is off the list")


func test_the_first_draw_of_a_run_is_the_run_s_car() -> void:
	# Every screen builds its own room, so a draw taken per car is a car that
	# changes shape as the player presses Start. The draw is taken once and
	# remembered, which is what makes the bay behind the menu the bay the title
	# card was showing.
	var drawn: String = CarChoice.for_the_next_car(FOUR)
	assert_eq(CarChoice.chosen, drawn, "a drawn car must become the run's car")
	for _each: int in range(DRAWS):
		assert_eq(CarChoice.for_the_next_car(FOUR), drawn, "the car changed between screens")


func test_a_chosen_car_beats_the_draw() -> void:
	# The whole point of the class. Asked against a list the choice is not even in,
	# because "the player said so" is not a fact about any list.
	CarChoice.choose("pickup")
	assert_eq(CarChoice.for_the_next_car(FOUR), "pickup", "the player's car must win the draw")


func test_a_run_with_no_cars_to_draw_from_has_no_answer() -> void:
	# Not a case the game can reach — the pack has ten — but the honest answer to
	# "pick one of none" is nothing, and the alternative is an index into an empty
	# array. `MeshCar._build` already reports an unloadable style loudly.
	assert_eq(CarChoice.for_the_next_car([] as Array[String]), "", "picked a car out of nowhere")


# ---- stepping through them ----------------------------------------------------


func test_stepping_moves_one_place_in_the_direction_asked() -> void:
	assert_eq(CarChoice.stepped("two", 1, FOUR), "three", "forward must go forward")
	assert_eq(CarChoice.stepped("two", -1, FOUR), "one", "back must go back")


func test_stepping_wraps_at_both_ends() -> void:
	# The list is the pack's file names, so it is alphabetical and its ends mean
	# nothing to a player. An arrow that stopped at one of them would read as
	# broken rather than as an edge.
	assert_eq(CarChoice.stepped("four", 1, FOUR), "one", "the far end must come round")
	assert_eq(CarChoice.stepped("one", -1, FOUR), "four", "and so must the near one")


func test_stepping_all_the_way_round_comes_back_to_where_it_started() -> void:
	var at: String = "one"
	for _each: int in FOUR.size():
		at = CarChoice.stepped(at, 1, FOUR)
	assert_eq(at, "one", "a full circuit must land back on the same car")


func test_stepping_from_a_car_nobody_recognises_starts_at_the_beginning() -> void:
	assert_eq(CarChoice.stepped("hovercraft", 1, FOUR), "one", "an unknown car must not wedge")


func test_stepping_through_no_cars_at_all_changes_nothing() -> void:
	assert_eq(CarChoice.stepped("two", 1, [] as Array[String]), "two", "stepped off an empty list")


# ---- what each one is called --------------------------------------------------


func test_every_car_in_the_pack_has_a_name() -> void:
	# The gate on the table itself, and the reason it is a table: this is what
	# fails on the day an eleventh model lands in assets/models/cars/ with nothing
	# to call it. [constant MeshCar.STYLES] is a constant and no car is built to
	# read it, so this stays a unit test.
	for style: String in MeshCar.STYLES:
		assert_true(CarChoice.NAMES.has(style), "the pack's %s has no name to show" % style)
		assert_false(CarChoice.label_for(style).is_empty(), "the %s is named nothing" % style)


func test_the_names_are_not_just_the_file_names_capitalised() -> void:
	# Which is the reason there is a table rather than a call to `capitalize`, and
	# these are the four it gets wrong: an SUV is not a "Suv" and a sport is not a
	# car anybody has ever asked for by that name.
	assert_eq(CarChoice.label_for("suv"), "SUV", "an initialism must survive being labelled")
	assert_eq(CarChoice.label_for("offroad"), "Off-Roader")
	assert_eq(CarChoice.label_for("sport"), "Sports Car")
	assert_eq(CarChoice.label_for("coupe"), "Coupe")


func test_a_car_with_no_name_is_still_labelled_something_readable() -> void:
	# A model the table has not caught up with. An empty label under the lockup is
	# worse than a guess, and the test above is what stops the guess shipping.
	assert_eq(CarChoice.label_for("hovercraft"), "Hovercraft", "an unknown car must still read")
