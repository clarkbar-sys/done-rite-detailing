## Base for the [Control] that a [GameState] presents.
##
## Every screen shares exactly one thing: a way to hand control back. It asks
## for the state it wants next and stops there — the host
## ([code]src/main/main.gd[/code]) owns the [GameStateMachine] and does the
## swapping, so no screen ever loads, frees or even names another screen.
class_name GameScreen
extends Control

## Emitted when this screen asks the host to move to [param state].
signal transition_requested(state: GameState)

## Emitted when this screen wants [param voice] rung. The host owns the [Chime]
## — see that class for why a screen cannot own the thing making the noise.
signal bell_requested(voice: Bell.Voice)

## Emitted when this screen wants the title theme playing. The host owns the
## [Bandstand] for the same reason it owns the [Chime], only more so: a screen
## that owned the music would take it with it when it was freed, and being freed
## is exactly when this screen asks for the music to be faded rather than cut.
signal music_requested

## Emitted when this screen wants the theme taken away over [param seconds].
signal music_stop_requested(seconds: float)


## Asks the host to enter [param state].
##
## A method rather than subclasses emitting the signal themselves: Godot's
## [code]unused_signal[/code] warning — level 2, so an error here — only counts
## uses inside the script that declares the signal, so a base-class signal
## emitted only from subclasses fails to compile. Verified against this engine
## by deleting this wrapper: [code]make check[/code] goes red on the signal.
func request_transition(state: GameState) -> void:
	transition_requested.emit(state)


## Asks the host to ring [param voice].
##
## A method rather than subclasses emitting the signal themselves, for the same
## compiler reason [method request_transition] is one: [code]unused_signal[/code]
## is an error here and only counts uses inside the declaring script.
func ring_bell(voice: Bell.Voice) -> void:
	bell_requested.emit(voice)


## Asks the host to play the theme.
##
## A method rather than subclasses emitting the signal themselves, for the same
## compiler reason [method request_transition] is one.
func request_music() -> void:
	music_requested.emit()


## Asks the host to fade the theme out over [param seconds].
##
## A method rather than subclasses emitting the signal themselves, for the same
## compiler reason [method request_transition] is one.
func stop_music(seconds: float = Bandstand.FADE_SECONDS) -> void:
	music_stop_requested.emit(seconds)
