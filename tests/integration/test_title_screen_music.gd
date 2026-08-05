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


func test_start_leaves_the_theme_playing() -> void:
	# The brief, in one assertion. The fade used to fire here, back when Start
	# opened the game; it now fires on the menu's Play, because the theme is
	# supposed to carry across the menu and step aside as the bay opens. A title
	# card that faded the music on its way into a menu would announce an ending
	# at the point a player was still choosing.
	#
	# The [Bandstand] hangs off the host, not off this screen, so it survives the
	# swap that frees this one and there is nothing here that has to hand it
	# over. `tests/integration/test_main_menu.gd` is where the fade is asserted
	# now.
	(_screen.get_node("%Start") as Button).pressed.emit()
	assert_eq(_faded.size(), 0, "Start took the music with it into the menu")


func test_a_press_that_started_the_music_leaves_it_playing_too() -> void:
	# Somebody who clicks Start as their very first act: the press starts the
	# theme on the way down and hands over on the way up, with the theme still
	# going. The same as above and worth its own line, because "the press that
	# unlocked the audio" and "the press that leaves" are the same press here and
	# only here.
	await _send(_click())
	assert_eq(_asked, 1, "the premise")
	(_screen.get_node("%Start") as Button).pressed.emit()
	assert_eq(_faded.size(), 0, "the theme must carry into the menu it just unlocked")
