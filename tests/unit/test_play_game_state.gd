## Unit tests for [PlayGameState] — the same facts
## [code]tests/unit/test_main_menu_game_state.gd[/code] pins, for the state
## Start Game leads to.
extends GutTest


func test_it_is_a_game_state() -> void:
	var state: GameState = PlayGameState.new()
	assert_true(state is PlayGameState, "the machine only deals in GameStates")


func test_it_reports_the_play_id() -> void:
	assert_eq(PlayGameState.new().id, PlayGameState.ID)


func test_its_scene_exists() -> void:
	var state: PlayGameState = PlayGameState.new()
	assert_eq(state.scene_path, PlayGameState.SCENE_PATH)
	assert_true(ResourceLoader.exists(state.scene_path), "no scene at %s" % state.scene_path)


func test_it_is_a_different_state_from_the_menu() -> void:
	# The two screens show the same garage, which is exactly why this is worth
	# asserting: they are distinct because they name different scenes, and a
	# copy-paste that left SCENE_PATH pointing at the menu would strand the
	# player on a screen whose Start Game button reloads it forever.
	assert_ne(PlayGameState.SCENE_PATH, MainMenuGameState.SCENE_PATH)
	assert_ne(PlayGameState.ID, MainMenuGameState.ID)
