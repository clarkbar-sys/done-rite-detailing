## Integration test for the main menu.
##
## The shape of this file is deliberately
## [code]tests/integration/test_title_screen.gd[/code]'s: the menu is now the
## second screen with a button on it, and the promises worth making about a
## button — it exists, it is wired, a finger can hit it, and nothing else on
## screen quietly acts like one — are the same promises in the same order.
extends GutTest

const MAIN_MENU: String = "res://src/screens/main_menu.tscn"

var _screen: GameScreen = null
var _requested: Array[GameState] = []
var _window_size_before: Vector2i = Vector2i.ZERO


func before_each() -> void:
	_requested = []
	# A headless window is 64x64, which is smaller than the button — small
	# enough that a tap at the button's own coordinates lands outside the layout
	# entirely and the touch tests below pass or fail for a reason that has
	# nothing to do with the game. See test_title_screen.gd, where this was
	# found. Put back in after_each: every suite shares this window.
	var root: Window = get_tree().root
	_window_size_before = root.size
	root.size = root.content_scale_size
	var packed: PackedScene = load(MAIN_MENU) as PackedScene
	assert_not_null(packed, "could not load %s" % MAIN_MENU)
	if packed == null:
		return
	var screen: GameScreen = packed.instantiate() as GameScreen
	_screen = screen
	add_child_autofree(_screen)
	_screen.transition_requested.connect(_record)
	await wait_process_frames(1)


func after_each() -> void:
	get_tree().root.size = _window_size_before


func _record(state: GameState) -> void:
	_requested.append(state)


func _start_button() -> Button:
	return _screen.get_node("%Start") as Button


func _garage() -> Garage:
	return _screen.get_node("Garage") as Garage


func test_the_screen_is_a_game_screen() -> void:
	# The host casts to [GameScreen] and refuses anything else, so a scene that
	# lost its script would boot to an empty window.
	assert_not_null(_screen, "the main menu must instantiate as a GameScreen")


func test_it_shows_the_garage_behind_the_menu() -> void:
	assert_not_null(_garage(), "the menu is played over the real room, not a picture of it")


func test_the_menu_camera_circles_the_car() -> void:
	# The difference between this screen and the play screen, asserted where it
	# is actually set: a property on the instance in this scene's file.
	assert_true(_garage().orbiting, "the menu shows the car off")


func test_it_offers_a_start_game_button() -> void:
	var start: Button = _start_button()
	assert_not_null(start, "the menu must have a button to start the game")
	assert_string_contains(start.text, "Start")


func test_start_game_asks_for_the_play_state() -> void:
	# Through the button's own signal rather than by calling the handler, so a
	# connection dropped in `_ready()` fails here rather than in the browser.
	_start_button().pressed.emit()
	assert_eq(_requested.size(), 1, "Start Game must request exactly one transition")
	if _requested.size() != 1:
		return
	assert_true(_requested[0] is PlayGameState, "Start Game must lead into the game")


func test_it_asks_for_nothing_on_its_own() -> void:
	assert_eq(_requested.size(), 0, "the menu must wait for the player")


# ---- touch: the phone-shaped half of "does the button work" ------------------


## Taps the screen at [param at] the way a finger does — see
## [code]tests/integration/test_title_screen.gd[/code], which explains at length
## why this goes through `Input` rather than straight at the viewport.
func _tap(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var touch: InputEventScreenTouch = InputEventScreenTouch.new()
		touch.position = at
		touch.pressed = pressed
		Input.parse_input_event(touch)
	Input.flush_buffered_events()


func test_a_tap_on_start_game_asks_for_the_play_state() -> void:
	_tap(_start_button().get_global_rect().get_center())
	await wait_process_frames(1)
	assert_eq(_requested.size(), 1, "a tap on Start Game must start the game")


func test_start_game_is_big_enough_for_a_finger() -> void:
	# Same gate the title screen's Start is held to. [TouchTarget] has the
	# arithmetic and the sources; the short version is that a button that looks
	# generous at 1280x720 is about a third of that in a hand.
	var start: Button = _start_button()
	var minimum: float = TouchTarget.min_design_size()
	assert_gte(start.size.x, minimum, "Start Game is too narrow to hit on a phone")
	assert_gte(start.size.y, minimum, "Start Game is too short to hit on a phone")


func test_a_tap_on_the_room_behind_the_button_asks_for_nothing() -> void:
	# The garage fills the screen underneath the menu, so most of a phone screen
	# is now room rather than button. A tap out there has to do nothing at all —
	# a full-screen control that quietly swallowed or acted on taps would be
	# found by players long before it was found by anyone reading the scene.
	var start: Button = _start_button()
	var above: Vector2 = start.get_global_rect().get_center() - Vector2(0, start.size.y)
	_tap(above)
	await wait_process_frames(1)
	assert_eq(_requested.size(), 0, "only Start Game starts the game")
