## Unit tests for [TitleScreenGameState].
##
## The assertion that earns its line count is [method
## test_its_scene_exists]: the state names its scene by string, so renaming or
## moving `title_screen.tscn` is a runtime failure — on the screen the game
## boots into — that nothing else would catch until someone ran it.
extends GutTest


func test_it_is_a_game_state() -> void:
	var state: GameState = TitleScreenGameState.new()
	assert_true(state is TitleScreenGameState, "the machine only deals in GameStates")


func test_it_reports_the_title_screen_id() -> void:
	assert_eq(TitleScreenGameState.new().id, TitleScreenGameState.ID)


func test_its_scene_exists() -> void:
	var state: TitleScreenGameState = TitleScreenGameState.new()
	assert_eq(state.scene_path, TitleScreenGameState.SCENE_PATH)
	assert_true(ResourceLoader.exists(state.scene_path), "no scene at %s" % state.scene_path)
