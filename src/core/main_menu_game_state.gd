## Where Start leads. The menu itself doesn't exist yet — the screen says so —
## but the state does, so the transition it will hang off is real and tested
## from the day the flow has two states in it.
class_name MainMenuGameState
extends GameState

## See [member GameState.id].
const ID: String = "main_menu"

## See [member GameState.scene_path].
const SCENE_PATH: String = "res://src/screens/main_menu.tscn"


func _init() -> void:
	super(ID, SCENE_PATH)
