## Integration test for the title screen's half of the music: when the theme is
## asked for, and what Start does to it.
##
## Its own file rather than more tests in
## [code]tests/integration/test_title_screen.gd[/code], which is already the
## lockup and the labels — the same split
## [code]test_title_screen_attract.gd[/code] is.
##
## [b]Signals, not a [Bandstand].[/b] Everything below watches
## [signal GameScreen.music_requested] and
## [signal GameScreen.music_stop_requested], because that is the whole of what
## this screen is responsible for: it asks, and the host — which owns the player
## and outlives this screen — answers. That the host is wired to those signals at
## all is [code]tests/integration/test_main_scene.gd[/code]'s assertion, and what
## happens on the other end of them is
## [code]tests/integration/test_bandstand.gd[/code]'s.
extends GutTest

const TITLE_SCREEN: String = "res://src/screens/title_screen.tscn"

var _screen: GameScreen = null
var _asked: int = 0
var _faded: Array[float] = []


func before_each() -> void:
	var packed: PackedScene = load(TITLE_SCREEN) as PackedScene
	assert_not_null(packed, "could not load %s" % TITLE_SCREEN)
	if packed == null:
		return
	# Instantiated into a typed local first: GUT's helpers are untyped, and
	# assigning a Variant straight into a typed field is an `unsafe_cast` error
	# under this project's warning levels. test_main_scene.gd has the same note.
	var instance: Node = packed.instantiate()
	_screen = instance as GameScreen
	_asked = 0
	_faded = []
	_screen.music_requested.connect(_on_music_requested)
	_screen.music_stop_requested.connect(_on_music_stop_requested)
	add_child_autofree(_screen)
	await wait_process_frames(1)


func _on_music_requested() -> void:
	_asked += 1


func _on_music_stop_requested(seconds: float) -> void:
	_faded.append(seconds)


## Sends [param event] the way the engine would, so the screen's
## [method Node._input] sees it.
##
## [method Viewport.push_input] rather than reaching into the screen and calling
## `_input` directly: the thing being tested is that this screen is listening on
## the pass that a press on the Start button also travels down, and calling the
## method by hand would pass whether or not it was ever wired up.
func _send(event: InputEvent) -> void:
	get_tree().root.push_input(event)
	await wait_process_frames(1)


## A left mouse button going down, which is what a click and a tap both arrive
## as.
func _click() -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func test_the_theme_is_not_asked_for_until_the_screen_is_touched() -> void:
	# The rule the whole design turns on. A browser drops any sound a page makes
	# before somebody has touched it — silently — so a theme started in
	# `_ready()` would simply not exist for most of the people who see this game.
	assert_eq(_asked, 0, "the title screen asked for music nobody had unlocked yet")


func test_a_click_starts_the_theme() -> void:
	await _send(_click())
	assert_eq(_asked, 1, "the first press did not start the music")


func test_a_key_starts_the_theme() -> void:
	# Start takes focus on open, so a keyboard player's first event is a key.
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = true
	await _send(event)
	assert_eq(_asked, 1, "a keypress did not start the music")


func test_a_touch_starts_the_theme() -> void:
	# The one that actually matters: this game is played on a phone, in a
	# browser, where the touch is both the gesture and the unlock.
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.pressed = true
	await _send(event)
	assert_eq(_asked, 1, "a touch did not start the music")


func test_moving_the_mouse_does_not_count_as_touching_the_page() -> void:
	# Moving a pointer over a page does not unlock its audio. Starting the theme
	# on it would burn the screen's one flag on an event that cannot make a
	# sound, and the music would then never play at all.
	await _send(InputEventMouseMotion.new())
	assert_eq(_asked, 0, "mouse motion was treated as a gesture")


func test_letting_go_does_not_count_either() -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	await _send(event)
	assert_eq(_asked, 0, "a mouse button coming back up was treated as a press")


func test_the_theme_is_only_ever_asked_for_once() -> void:
	# The host makes a second start harmless anyway ([Bandstand] is idempotent),
	# but a screen that asked on every click would be asking the host to make a
	# decision it should not have to make.
	await _send(_click())
	await _send(_click())
	await _send(_click())
	assert_eq(_asked, 1, "the screen kept asking")


func test_start_asks_for_a_fade_rather_than_a_stop() -> void:
	# The brief, in one assertion: the music steps aside over three seconds
	# instead of being cut off on the press.
	(_screen.get_node("%Start") as Button).pressed.emit()
	assert_eq(_faded.size(), 1, "Start did not ask for the music to go")
	assert_almost_eq(_faded[0], Bandstand.FADE_SECONDS, 0.001, "Start cut the music dead")


func test_start_asks_for_the_fade_before_it_asks_to_leave() -> void:
	# The ordering in `_on_start_pressed`. `request_transition` frees this screen
	# synchronously, so a fade asked for afterwards would be emitted from a node
	# on its way out — it survives either way, because the host is already
	# connected, but the version that does not rely on that is the one that
	# should stay.
	var order: Array[String] = []
	_screen.music_stop_requested.connect(func(_seconds: float) -> void: order.append("fade"))
	_screen.transition_requested.connect(func(_state: GameState) -> void: order.append("leave"))
	(_screen.get_node("%Start") as Button).pressed.emit()
	assert_eq(order, ["fade", "leave"] as Array[String])


func test_a_press_that_never_started_the_music_still_asks_for_the_fade() -> void:
	# Somebody who clicks Start as their very first act: the press starts the
	# theme on the way down and ends it on the way up. The fade is asked for
	# unconditionally and the host no-ops it if there is nothing playing, which
	# is one rule instead of two.
	assert_eq(_asked, 0)
	(_screen.get_node("%Start") as Button).pressed.emit()
	assert_eq(_faded.size(), 1)
