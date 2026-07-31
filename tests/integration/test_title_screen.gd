## Integration test for the title screen.
##
## Under tests/integration/ because every one of these facts is established in
## `_ready()` — the labels are filled and the button is wired only once the
## scene is in a tree. Nothing here can be asserted by loading the script alone.
##
## The two label assertions moved here from the entry-scene test when the title
## card became a state of its own; they are the same promise as before, made
## where the text now lives.
extends GutTest

const TITLE_SCREEN: String = "res://src/screens/title_screen.tscn"

var _screen: GameScreen = null
var _requested: Array[GameState] = []


func before_each() -> void:
	_requested = []
	var packed: PackedScene = load(TITLE_SCREEN) as PackedScene
	assert_not_null(packed, "could not load %s" % TITLE_SCREEN)
	if packed == null:
		return
	# Instantiate into a typed local before handing it to add_child_autofree —
	# GUT's helper is untyped, and autofree is what keeps a failing assertion
	# below from being reported as a leak against whichever test runs next.
	var screen: GameScreen = packed.instantiate() as GameScreen
	_screen = screen
	add_child_autofree(_screen)
	_screen.transition_requested.connect(_record)
	# `_ready()` has already fired inside add_child; the frame is only here to
	# let layout settle before the labels are read.
	await wait_process_frames(1)


func _record(state: GameState) -> void:
	_requested.append(state)


func _start_button() -> Button:
	return _screen.get_node("%Start") as Button


func test_the_screen_is_a_game_screen() -> void:
	# The host casts to [GameScreen] and refuses anything else, so a scene that
	# lost its script would boot to an empty window.
	assert_not_null(_screen, "the title screen must instantiate as a GameScreen")


func test_title_shows_the_project_name() -> void:
	var title: Label = _screen.get_node("%Title") as Label
	assert_eq(title.text, str(ProjectSettings.get_setting("application/config/name")))


func test_build_label_shows_the_build_identity() -> void:
	# The on-screen build line and the stdout line CI greps must agree; if this
	# drifts, the "I can see which commit this build is" promise quietly dies.
	var build: Label = _screen.get_node("%Build") as Label
	assert_eq(build.text, BuildInfo.describe())


func test_it_offers_a_start_button() -> void:
	assert_not_null(_start_button(), "the title screen must have a Start button")


func test_start_asks_for_the_main_menu() -> void:
	# Through the button's own signal rather than by calling the handler, so a
	# connection dropped in `_ready()` fails here rather than in the browser.
	_start_button().pressed.emit()
	assert_eq(_requested.size(), 1, "Start must request exactly one transition")
	if _requested.size() != 1:
		return
	assert_true(_requested[0] is MainMenuGameState, "Start must lead to the main menu")


func test_it_asks_for_nothing_on_its_own() -> void:
	assert_eq(_requested.size(), 0, "the title screen must wait for the player")
