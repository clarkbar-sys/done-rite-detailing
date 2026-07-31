## Holds which [GameState] the game is in, and announces every change.
##
## The whole flow of the game lives here rather than in the scene that happens
## to be on screen: a screen asks for the next state, this decides it's current,
## and whoever is listening reacts. Nothing polls, and no screen has to know
## what any other screen is.
##
## A [RefCounted] and not a [Node] — see STANDARDS.md "Beyond the compiler". It
## needs no frame callbacks and no place in the tree, and staying out of the
## tree is what lets [code]tests/unit/test_game_state_machine.gd[/code] drive a
## whole transition with no scene at all.
class_name GameStateMachine
extends RefCounted

## Emitted once [method enter] has made [param state] the current one. The
## listener is the host that swaps scenes; the state is already current by the
## time it runs, so [method current] agrees with the argument.
signal changed(state: GameState)

var _current: GameState = null


## The state the game is in, or [code]null[/code] before the first
## [method enter].
func current() -> GameState:
	return _current


## Makes [param state] current and announces it.
##
## Re-entering the state you're already in is allowed and does the same thing:
## a state is a plain value, so "enter it again" honestly means "rebuild that
## screen" rather than nothing at all.
func enter(state: GameState) -> void:
	_current = state
	changed.emit(state)
