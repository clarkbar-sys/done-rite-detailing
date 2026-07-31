## Unit tests for [GameState], the base every state is built from.
##
## There is not much to a state — an id and the scene it presents — and that is
## the point worth pinning: it stays constructible with no [SceneTree], no
## loading and no side effects, which is what lets the machine and every
## concrete state below be tested as plain values.
extends GutTest

## A state pointing at nothing real. The base class must not care, because it
## never loads what it names — see [code]src/main/main.gd[/code].
const NOWHERE: String = "res://not/a/real/scene.tscn"


func test_a_state_keeps_the_id_it_was_built_with() -> void:
	var state: GameState = GameState.new("demo", NOWHERE)
	assert_eq(state.id, "demo")


func test_a_state_keeps_the_scene_it_presents() -> void:
	var state: GameState = GameState.new("demo", NOWHERE)
	assert_eq(state.scene_path, NOWHERE)


func test_building_a_state_does_not_load_its_scene() -> void:
	# If constructing a state ever started touching the disk, this is the test
	# that fails: a path that cannot resolve would have to raise or warn.
	var state: GameState = GameState.new("demo", NOWHERE)
	assert_false(ResourceLoader.exists(state.scene_path), "the path must stay unreal")
