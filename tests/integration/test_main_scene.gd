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
##
## [b]The walk is four screens long now, and this is the only suite that takes
## it.[/b] Each screen's own suite instantiates that screen alone and asserts
## what it [i]asks[/i] for, because a screen on its own has no host to answer it.
## Whether the ask is answered — whether the host is wired to those signals at
## all, and whether the scene it swaps in is the one the state named — is only
## visible from here.
extends GutTest

const MAIN_SCENE: String = "res://src/main/main.tscn"
const TITLE_SCREEN: String = "res://src/screens/title_screen.tscn"
const MAIN_MENU: String = "res://src/screens/main_menu.tscn"
const HOW_TO_PLAY: String = "res://src/screens/how_to_play.tscn"
const PLAY_SCREEN: String = "res://src/screens/play_screen.tscn"

var _main: Control = null

## The state [Sound] was in before this suite touched it, so a run that boots
## the scene muted (see below) still hands the next suite an unmuted game
## rather than whatever this one last left the settings file at.
var _muted_before: bool = false


func before_each() -> void:
	_muted_before = Sound.muted
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


func after_each() -> void:
	Sound.set_muted(_muted_before)


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


## Presses the button called [param unique_name] on whatever is on screen, and
## lets the swap happen.
##
## Through the button's own [signal BaseButton.pressed] and through the real
## mounted screen, so a handler that was never connected fails here — and by
## unique name, so the press is aimed at the control the scene file marked rather
## than at a node path this file would have to keep in step with three layouts.
func _press(unique_name: String) -> void:
	var host: Control = _main.get_node("%ScreenHost") as Control
	var button: Button = host.get_child(0).get_node("%%%s" % unique_name) as Button
	button.pressed.emit()
	await wait_process_frames(1)


## Title card to menu: the first press of every walk below.
func _press_start() -> void:
	await _press("Start")


## Menu to game, which is where the bell and the fade live now.
##
## Arcade rather than Play since #214 split that pill into the two modes. These
## walks are about the host swapping screens rather than about which clock the
## run gets, so they take the pill the menu opens focused; what each mode is
## worth is [code]tests/unit/test_game_mode.gd[/code]'s and
## [code]tests/integration/test_play_screen_clock.gd[/code]'s.
func _press_arcade() -> void:
	await _press("Arcade")


## The rules screen's own way into the game, which is still one button called
## Play — see [code]src/screens/how_to_play.gd[/code] on why the split stayed on
## the menu.
func _press_play_on_the_rules() -> void:
	await _press("Play")


func test_the_scene_instantiates_as_a_control() -> void:
	assert_not_null(_main, "the entry scene must instantiate")


func test_it_boots_into_the_title_screen() -> void:
	assert_eq(_current_screen_path(), TITLE_SCREEN)
	assert_eq(_current_screen_path(), TitleScreenGameState.SCENE_PATH, "the state decides this")


func test_start_swaps_the_title_screen_for_the_menu() -> void:
	await _press_start()
	assert_eq(_current_screen_path(), MAIN_MENU)
	assert_eq(_current_screen_path(), MainMenuGameState.SCENE_PATH, "the state decides this")


func test_the_walk_from_the_title_card_to_the_game() -> void:
	# The short way through, press by press, on the real host: title -> menu ->
	# game. Each screen's own suite proves it asks for the next state; this is
	# the only place that proves the asking gets answered.
	await _press_start()
	assert_eq(_current_screen_path(), MAIN_MENU, "Start must open the menu")
	await _press_arcade()
	assert_eq(_current_screen_path(), PLAY_SCREEN)
	assert_eq(_current_screen_path(), PlayGameState.SCENE_PATH, "the state decides this")


func test_the_long_way_round_through_the_rules_and_back() -> void:
	# The other half of the flow, and the only loop in it: a player who reads
	# first has to be able to get back to where they were.
	await _press_start()
	await _press("HowToPlay")
	assert_eq(_current_screen_path(), HOW_TO_PLAY)
	assert_eq(_current_screen_path(), HowToPlayGameState.SCENE_PATH, "the state decides this")
	await _press("MainMenu")
	assert_eq(_current_screen_path(), MAIN_MENU, "Main Menu must lead back to the menu")


func test_the_rules_screen_can_start_the_game_itself() -> void:
	# The reason that screen has a Play on it at all: somebody who came to learn
	# starts from where they are rather than walking back to press the same word
	# again.
	await _press_start()
	await _press("HowToPlay")
	await _press_play_on_the_rules()
	assert_eq(_current_screen_path(), PLAY_SCREEN, "Play on the rules screen must open the game")


func test_the_game_is_silent_until_it_is_touched() -> void:
	# A browser drops any sound a page makes before the person on it has touched
	# it, so a game that rang on boot would be spending its one unlock on nothing.
	assert_eq(_bell().rings(), 0, "the game made a noise on its own")


func test_the_title_card_no_longer_rings_on_its_own_press() -> void:
	# The bell means the job starts, and Start no longer starts a job. What that
	# press still does is unlock the browser's audio — answered by the theme, two
	# tests below, rather than by the counter bell.
	await _press_start()
	assert_eq(_current_screen_path(), MAIN_MENU, "the swap must have happened")
	assert_eq(_bell().rings(), 0, "the menu was opened with a ding on it")


func test_play_rings_and_keeps_ringing_after_the_screen_it_was_pressed_on_is_gone() -> void:
	# The failure this whole arrangement exists to prevent, and the one a
	# screenshot cannot show: the menu is removed *and freed* on the press that
	# starts the game, so a bell owned by that screen would be freed mid-ding and
	# Play would sound like a click. The host outlives every screen — which is
	# also why moving the ding one screen down the flow cost nothing here.
	await _press_start()
	await _press_arcade()
	assert_eq(_current_screen_path(), PLAY_SCREEN, "the swap must have happened")
	assert_eq(_bell().rings(), 1, "Play rang no bell")
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


func test_the_theme_carries_across_the_menu() -> void:
	# The brief, end to end through the real player: the theme is unlocked on the
	# title card and is still going while the player is choosing. This is the
	# whole reason the fade moved off Start — and the reason it costs nothing to
	# move it is that the [Bandstand] hangs off the host, so it survives both
	# swaps without either screen handing it over.
	await _touch()
	assert_true(_music().playing(), "the title screen never got its music")
	await _press_start()
	assert_eq(_current_screen_path(), MAIN_MENU, "the swap must have happened")
	assert_true(_music().playing(), "the theme was left behind on the title card")
	assert_false(_music().fading(), "the menu is not the end of anything")


func test_play_fades_the_music_and_it_keeps_playing_after_the_screen_is_gone() -> void:
	# The failure this arrangement exists to prevent, and the sharper twin of the
	# bell's: the menu is removed *and freed* on the press that starts the game,
	# so a fade owned by that screen would be killed on the first frame of itself
	# and Play would cut the music dead instead of easing it out.
	await _touch()
	assert_true(_music().playing(), "nothing to fade")
	await _press_start()
	await _press_arcade()
	assert_eq(_current_screen_path(), PLAY_SCREEN, "the swap must have happened")
	assert_true(_music().playing(), "the music was cut off with the screen that asked for it")
	assert_true(_music().fading(), "the music is playing on into the game instead of fading")


func test_the_theme_survives_the_long_way_round_as_well() -> void:
	# Three swaps instead of one. Nothing on the way to the rules and back asks
	# the music for anything, so a player who reads first should arrive at the
	# game with the same theme still playing that a player who did not heard.
	await _touch()
	await _press_start()
	await _press("HowToPlay")
	assert_true(_music().playing(), "the rules screen stopped the theme")
	assert_false(_music().fading(), "reading is not leaving")
	await _press_play_on_the_rules()
	assert_eq(_current_screen_path(), PLAY_SCREEN, "the swap must have happened")
	assert_true(_music().fading(), "the rules screen's Play left the theme running into the game")


func test_a_saved_mute_is_applied_before_the_title_screen_shows() -> void:
	# `before_each` already booted `_main` off whatever `_muted_before` was, so
	# proving main.gd reads a *saved* mute back means saving one and booting a
	# second instance — the only way to tell "read the setting on the way in"
	# apart from "happened to start unmuted".
	Settings.save_muted(true)
	var packed: PackedScene = load(MAIN_SCENE) as PackedScene
	var instance: Node = packed.instantiate()
	var second_main: Control = instance as Control
	add_child_autofree(second_main)
	await wait_process_frames(1)
	assert_true(Sound.muted, "a fresh boot did not read the saved setting")
	assert_true(
		AudioServer.is_bus_mute(AudioServer.get_bus_index(Sound.BUS_NAME)),
		"the bus was not silenced to match"
	)


func test_only_one_screen_is_mounted_at_a_time() -> void:
	# The helper above already returns "" for any child count but one, so this
	# is spelled out because of the bug it prevents: `queue_free()` without
	# `remove_child()` leaves the outgoing screen drawn over the incoming one
	# for the rest of the frame. Checked after every press of the walk, because
	# there are three of them now and the bug only needs one to go wrong.
	var host: Control = _main.get_node("%ScreenHost") as Control
	await _press_start()
	assert_eq(host.get_child_count(), 1, "after Start")
	await _press("HowToPlay")
	assert_eq(host.get_child_count(), 1, "after How to Play")
	await _press("MainMenu")
	assert_eq(host.get_child_count(), 1, "after Main Menu")
	await _press_arcade()
	assert_eq(host.get_child_count(), 1, "after Play")


func test_no_screen_comes_along_into_the_game() -> void:
	# The outgoing screen is removed *and* freed — see `main.gd`. A menu still
	# mounted would be drawn over the room and still be taking taps, which is the
	# bug `test_only_one_screen_is_mounted_at_a_time` catches from the other side.
	await _press_start()
	await _press_arcade()
	var host: Control = _main.get_node("%ScreenHost") as Control
	assert_eq(host.get_child_count(), 1)
	assert_false(host.get_child(0).has_node("%Start"), "the game has no Start button on it")
	assert_false(host.get_child(0).has_node("%HowToPlay"), "nor a way back to the rules")
