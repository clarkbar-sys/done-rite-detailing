## Unit tests for [GameStateMachine].
##
## The whole flow of the game runs through this class, and none of it needs a
## scene: the machine is a [RefCounted], so a transition can be driven here
## rather than through a button in a scene tree. What a scene *does* with the
## announcement is [code]tests/integration/test_main_scene.gd[/code]'s job.
##
## The listener below is a plain typed method rather than GUT's `watch_signals`
## helpers: those return [Variant], which this project's warning levels make
## awkward to consume, and recording the states directly asserts the payload —
## the thing the host actually uses — instead of just the fact of an emission.
extends GutTest

var _machine: GameStateMachine = null
var _announced: Array[GameState] = []


func before_each() -> void:
	_machine = GameStateMachine.new()
	_announced = []
	_machine.changed.connect(_record)


func _record(state: GameState) -> void:
	_announced.append(state)


func test_it_starts_in_no_state_at_all() -> void:
	assert_null(_machine.current(), "nothing is current until someone enters a state")
	assert_eq(_announced.size(), 0, "and nothing has been announced")


func test_entering_a_state_makes_it_current() -> void:
	var title: TitleScreenGameState = TitleScreenGameState.new()
	_machine.enter(title)
	assert_eq(_machine.current(), title)


func test_entering_a_state_announces_it() -> void:
	var title: TitleScreenGameState = TitleScreenGameState.new()
	_machine.enter(title)
	var expected: Array[GameState] = [title]
	assert_eq(_announced, expected)


func test_the_state_is_already_current_when_the_change_is_announced() -> void:
	# The host swaps scenes from this signal and reads `current()` from
	# elsewhere; if those two ever disagreed, the bug would surface a frame
	# later and somewhere else entirely.
	_machine.changed.connect(_assert_current_matches)
	_machine.enter(MainMenuGameState.new())


func _assert_current_matches(state: GameState) -> void:
	assert_eq(_machine.current(), state)


func test_it_walks_from_the_title_screen_to_the_menu() -> void:
	var title: TitleScreenGameState = TitleScreenGameState.new()
	var menu: MainMenuGameState = MainMenuGameState.new()
	_machine.enter(title)
	_machine.enter(menu)
	assert_eq(_machine.current(), menu)
	var expected: Array[GameState] = [title, menu]
	assert_eq(_announced, expected)


func test_re_entering_a_state_announces_it_again() -> void:
	# Documented behaviour, not an accident: re-entering means "rebuild that
	# screen", so the host has to hear about it. See [method
	# GameStateMachine.enter].
	var title: TitleScreenGameState = TitleScreenGameState.new()
	_machine.enter(title)
	_machine.enter(title)
	assert_eq(_announced.size(), 2)
