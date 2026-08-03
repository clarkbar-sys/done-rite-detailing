## Integration test for the entry scene — the host that turns a [GameState]
## into something on screen.
##
## Lives under tests/integration/ rather than tests/unit/ because a swap only
## happens in a real scene tree: `main.gd` enters the first state in `_ready()`,
## and the screens it puts up do their own work in theirs.
##
## This overlaps `make smoke` on purpose but is not the same gate. Smoke boots
## the whole project and fails on any logged error — it proves the game starts.
## This proves it starts *on the title screen* and walks from there into the
## game, which a clean boot says nothing about.
extends GutTest

const MAIN_SCENE: String = "res://src/main/main.tscn"
const TITLE_SCREEN: String = "res://src/screens/title_screen.tscn"
const PLAY_SCREEN: String = "res://src/screens/play_screen.tscn"

var _main: Control = null


func before_each() -> void:
	var packed: PackedScene = load(MAIN_SCENE) as PackedScene
	assert_not_null(packed, "could not load %s" % MAIN_SCENE)
	if packed == null:
		return
	# GUT's helpers are untyped, so their return is a Variant and assigning it
	# straight to `_main` is an `unsafe_cast` error under this project's
	# warning levels. Instantiate into a typed local, then hand that to
	# add_child_autofree — which frees the scene even if a test below fails,
	# so a leak isn't reported against whichever test runs next.
	var instance: Node = packed.instantiate()
	_main = instance as Control
	add_child_autofree(_main)
	# `_ready()` fires synchronously inside add_child, so this frame is only
	# here to let layout settle before the screen is read. Deliberately
	# wait_process_frames and not wait_frames: GUT 9.7.1 still accepts the
	# latter but logs it as deprecated, and a suite that prints deprecation
	# noise on every green run trains people to stop reading the output.
	await wait_process_frames(1)


## The scene file behind whatever the host is showing, or "" if it is not
## showing exactly one thing. `scene_file_path` is the instance's own record of
## where it came from, so this asserts the screen *is that scene* rather than
## trusting a node name anyone could reuse.
func _current_screen_path() -> String:
	var host: Control = _main.get_node("%ScreenHost") as Control
	if host.get_child_count() != 1:
		return ""
	return host.get_child(0).scene_file_path


## The host's bell — the one thing in the game that makes a noise, and the whole
## reason it hangs off the host rather than off a screen.
func _bell() -> Chime:
	return _main.get_node("%Bell") as Chime


## The host's music, which hangs off the host for the same reason the bell does
## and with a sharper edge on it: the title screen asks for a three-second fade
## and is freed on the next line.
func _music() -> Bandstand:
	return _main.get_node("%Music") as Bandstand


## Touches the screen the way a player would, which is what unlocks audio in a
## browser and what the title screen starts the theme on.
func _touch() -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	get_tree().root.push_input(event)
	await wait_process_frames(1)


## Presses Start on whatever is on screen and lets the swap happen.
func _press_start() -> void:
	var host: Control = _main.get_node("%ScreenHost") as Control
	var start: Button = host.get_child(0).get_node("%Start") as Button
	start.pressed.emit()
	await wait_process_frames(1)


func test_the_scene_instantiates_as_a_control() -> void:
	assert_not_null(_main, "the entry scene must instantiate")


func test_it_boots_into_the_title_screen() -> void:
	assert_eq(_current_screen_path(), TITLE_SCREEN)
	assert_eq(_current_screen_path(), TitleScreenGameState.SCENE_PATH, "the state decides this")


func test_start_swaps_the_title_screen_for_the_game() -> void:
	# The whole walk, through the real button: title -> game. There is no menu
	# screen in between — Start leads straight into play.
	await _press_start()
	assert_eq(_current_screen_path(), PLAY_SCREEN)
	assert_eq(_current_screen_path(), PlayGameState.SCENE_PATH, "the state decides this")


func test_the_game_is_silent_until_it_is_touched() -> void:
	# A browser drops any sound a page makes before the person on it has touched
	# it, so a game that rang on boot would be spending its one unlock on nothing.
	assert_eq(_bell().rings(), 0, "the game made a noise on its own")


func test_start_rings_and_keeps_ringing_after_the_screen_it_was_pressed_on_is_gone() -> void:
	# The failure this whole arrangement exists to prevent, and the one a
	# screenshot cannot show: the title screen is removed *and freed* on the press
	# that starts the game, so a bell owned by that screen would be freed
	# mid-ding and Start would sound like a click. The host outlives every screen.
	await _press_start()
	assert_eq(_current_screen_path(), PLAY_SCREEN, "the swap must have happened")
	assert_eq(_bell().rings(), 1, "Start rang no bell")
	assert_true(_bell().is_ringing(), "the bell was cut off with the screen that asked for it")


func test_the_music_is_silent_until_the_screen_is_touched() -> void:
	# Same bargain as the bell above, and the same reason: a browser drops any
	# sound a page makes before somebody has touched it.
	assert_false(_music().playing(), "the game started playing music on its own")


func test_touching_the_title_screen_starts_the_theme() -> void:
	# The whole wiring, end to end through the real host: the screen sees a
	# press, the host owns the player, and neither reaches for the other.
	await _touch()
	assert_true(_music().playing(), "the title screen never got its music")


func test_start_fades_the_music_and_it_keeps_playing_after_the_screen_is_gone() -> void:
	# The failure this arrangement exists to prevent, and the sharper twin of the
	# bell's: the title screen is removed *and freed* on the press that starts
	# the game, so a fade owned by that screen would be killed on the first frame
	# of itself and Start would cut the music dead instead of easing it out.
	await _touch()
	assert_true(_music().playing(), "nothing to fade")
	await _press_start()
	assert_eq(_current_screen_path(), PLAY_SCREEN, "the swap must have happened")
	assert_true(_music().playing(), "the music was cut off with the screen that asked for it")
	assert_true(_music().fading(), "the music is playing on into the game instead of fading")


func test_only_one_screen_is_mounted_at_a_time() -> void:
	# The helper above already returns "" for any child count but one, so this
	# is spelled out because of the bug it prevents: `queue_free()` without
	# `remove_child()` leaves the outgoing screen drawn over the incoming one
	# for the rest of the frame.
	await _press_start()
	var host: Control = _main.get_node("%ScreenHost") as Control
	assert_eq(host.get_child_count(), 1)


func test_the_title_screen_does_not_come_along_into_the_game() -> void:
	# The outgoing screen is removed *and* freed — see `main.gd`. A title screen
	# still mounted would be drawn over the room and still be taking taps, which
	# is the bug `test_only_one_screen_is_mounted_at_a_time` catches from the
	# other side.
	await _press_start()
	var host: Control = _main.get_node("%ScreenHost") as Control
	assert_eq(host.get_child_count(), 1)
	assert_false(host.get_child(0).has_node("%Start"), "the game has no Start button on it")
