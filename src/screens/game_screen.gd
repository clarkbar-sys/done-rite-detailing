## Base for the [Control] that a [GameState] presents.
##
## Every screen shares one thing above all: a way to hand control back. It asks
## for the state it wants next and stops there — the host
## ([code]src/main/main.gd[/code]) owns the [GameStateMachine] and does the
## swapping, so no screen ever loads, frees or even names another screen.
##
## [b]And, since there are three screens with buttons on them, one way to dress
## a button.[/b] [method dress_loud] and [method dress_quiet] are here rather
## than repeated per screen because the rule they encode is a trap and not a
## preference: Godot falls back to the theme's stylebox for any button state it
## is not given, so a screen that overrides only [code]normal[/code] leaves hover
## and pressed wearing the default grey — the two moments the button is actually
## being used. Written out once, that is a rule; written out three times, it is
## three chances to forget one.
##
## They live on the screen tier rather than in [Brand] deliberately.
## [code]src/core/[/code] is the Node-free tier (STANDARDS.md "Coverage", R3) and
## [Brand] is the shapes and the colours — things a unit test can build and
## measure with no [SceneTree] anywhere. Putting a [Button] in its signature
## would be the first Node in that file. What [Brand] hands out is still every
## colour and every corner below; this only puts them on.
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


## Dresses [param button] as the answer to the screen it is on: the red pill,
## white type, and a face for every state.
##
## There is at most one of these per screen, and that is the whole point of the
## colour — [constant Brand.RED] is the site's one accent, worn by the thing the
## visitor is meant to press and by nothing else.
static func dress_loud(button: Button) -> void:
	var height: float = button.custom_minimum_size.y
	_wear(
		button,
		Brand.pill(Brand.RED, height),
		Brand.pill(Brand.RED.lightened(Brand.HOVER_LIFT), height),
		Brand.pill(Brand.RED_DARK, height)
	)


## Dresses [param button] as the other thing on the screen: the card's colour in
## the pill's shape, so it reads as a button without competing with the red one.
##
## Pressed goes to [constant Brand.INK] rather than lightening, because a dark
## button that brightens under the thumb is a dark button that looks like it is
## turning on. Hover lifts and press sinks, which is the direction the red pill
## already moves in.
static func dress_quiet(button: Button) -> void:
	var height: float = button.custom_minimum_size.y
	_wear(
		button,
		Brand.quiet_pill(Brand.PANEL, height),
		Brand.quiet_pill(Brand.PANEL.lightened(Brand.HOVER_LIFT), height),
		Brand.quiet_pill(Brand.INK, height)
	)


## Puts [param normal], [param hover] and [param pressed] on [param button],
## along with the focus ring and white type, and leaves nothing to the theme.
##
## The height every shape is cut to is [member Control.custom_minimum_size], not
## [member Control.size]: this runs in [method Node._ready], before the first
## layout pass, where a button's real size is still zero. The scene states the
## size it wants and this reads that — which is also why the scene files below
## give every button a [code]custom_minimum_size[/code] even where a container
## would have stretched it anyway.
static func _wear(
	button: Button, normal: StyleBoxFlat, hover: StyleBoxFlat, pressed: StyleBoxFlat
) -> void:
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", Brand.focus_ring(button.custom_minimum_size.y))
	for role: String in [
		"font_color", "font_hover_color", "font_pressed_color", "font_focus_color"
	]:
		button.add_theme_color_override(role, Brand.WHITE)
