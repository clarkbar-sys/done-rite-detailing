## Unit tests for [TutorialTakeGameState] — the same facts
## [code]tests/unit/test_how_to_play_game_state.gd[/code] pins, for the screen a
## capture harness boots the game into.
extends GutTest


func test_it_is_a_game_state() -> void:
	var state: GameState = TutorialTakeGameState.new()
	assert_true(state is TutorialTakeGameState, "the machine only deals in GameStates")


func test_it_reports_the_tutorial_take_id() -> void:
	assert_eq(TutorialTakeGameState.new().id, TutorialTakeGameState.ID)


func test_its_scene_exists() -> void:
	var state: TutorialTakeGameState = TutorialTakeGameState.new()
	assert_eq(state.scene_path, TutorialTakeGameState.SCENE_PATH)
	assert_true(ResourceLoader.exists(state.scene_path), "no scene at %s" % state.scene_path)


func test_it_is_a_state_of_its_own() -> void:
	# Every screen in this game instances the same garage, so "this is a different
	# screen" is a claim about the scene path and the id and nothing else. It matters
	# here more than usual: the take screen is the one the game can boot straight
	# into, and booting into the title card by accident would film the wrong thing.
	for other: GameState in [
		TitleScreenGameState.new(),
		MainMenuGameState.new(),
		HowToPlayGameState.new(),
		PlayGameState.new()
	]:
		assert_ne(TutorialTakeGameState.SCENE_PATH, other.scene_path)
		assert_ne(TutorialTakeGameState.ID, other.id)
