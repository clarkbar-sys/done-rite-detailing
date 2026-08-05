## Unit tests for [MainMenuGameState] — the same facts
## [code]tests/unit/test_play_game_state.gd[/code] pins, for the state Start
## leads to now.
extends GutTest


func test_it_is_a_game_state() -> void:
	var state: GameState = MainMenuGameState.new()
	assert_true(state is MainMenuGameState, "the machine only deals in GameStates")


func test_it_reports_the_main_menu_id() -> void:
	assert_eq(MainMenuGameState.new().id, MainMenuGameState.ID)


func test_its_scene_exists() -> void:
	# The state names its scene by string, so renaming or moving `main_menu.tscn`
	# is a runtime failure — on the screen Start now opens — that nothing else
	# would catch until someone ran it.
	var state: MainMenuGameState = MainMenuGameState.new()
	assert_eq(state.scene_path, MainMenuGameState.SCENE_PATH)
	assert_true(ResourceLoader.exists(state.scene_path), "no scene at %s" % state.scene_path)


func test_it_is_a_state_of_its_own() -> void:
	# The menu shows the same lockup over the same bay as the title card, which
	# is exactly why this is worth asserting: the two are distinct because they
	# name different scenes, and a copy-paste that left SCENE_PATH pointing at
	# the title screen would strand the player on a card whose Start reloads it
	# forever.
	for other: GameState in [TitleScreenGameState.new(), PlayGameState.new()]:
		assert_ne(MainMenuGameState.SCENE_PATH, other.scene_path)
		assert_ne(MainMenuGameState.ID, other.id)
