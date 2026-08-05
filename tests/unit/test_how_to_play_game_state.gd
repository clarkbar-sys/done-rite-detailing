## Unit tests for [HowToPlayGameState] — the same facts
## [code]tests/unit/test_play_game_state.gd[/code] pins, for the screen the menu
## hangs the rules off.
extends GutTest


func test_it_is_a_game_state() -> void:
	var state: GameState = HowToPlayGameState.new()
	assert_true(state is HowToPlayGameState, "the machine only deals in GameStates")


func test_it_reports_the_how_to_play_id() -> void:
	assert_eq(HowToPlayGameState.new().id, HowToPlayGameState.ID)


func test_its_scene_exists() -> void:
	var state: HowToPlayGameState = HowToPlayGameState.new()
	assert_eq(state.scene_path, HowToPlayGameState.SCENE_PATH)
	assert_true(ResourceLoader.exists(state.scene_path), "no scene at %s" % state.scene_path)


func test_it_is_a_state_of_its_own() -> void:
	# Same argument as the menu's: three of the four screens instance the same
	# garage, so "these are different screens" is a claim about the scene paths
	# and nothing else.
	for other: GameState in [
		TitleScreenGameState.new(), MainMenuGameState.new(), PlayGameState.new()
	]:
		assert_ne(HowToPlayGameState.SCENE_PATH, other.scene_path)
		assert_ne(HowToPlayGameState.ID, other.id)
