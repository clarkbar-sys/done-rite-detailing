## Unit tests for [MainMenuGameState] — the same three facts
## [code]tests/unit/test_title_screen_game_state.gd[/code] pins, for the state
## Start leads to.
extends GutTest


func test_it_is_a_game_state() -> void:
	var state: GameState = MainMenuGameState.new()
	assert_true(state is MainMenuGameState, "the machine only deals in GameStates")


func test_it_reports_the_main_menu_id() -> void:
	assert_eq(MainMenuGameState.new().id, MainMenuGameState.ID)


func test_its_scene_exists() -> void:
	var state: MainMenuGameState = MainMenuGameState.new()
	assert_eq(state.scene_path, MainMenuGameState.SCENE_PATH)
	assert_true(ResourceLoader.exists(state.scene_path), "no scene at %s" % state.scene_path)


func test_it_is_a_different_state_from_the_title_screen() -> void:
	# Two states are distinct because they name different scenes, not because
	# of any registry — nothing anywhere maps an id back to a class.
	assert_ne(MainMenuGameState.SCENE_PATH, TitleScreenGameState.SCENE_PATH)
	assert_ne(MainMenuGameState.ID, TitleScreenGameState.ID)
