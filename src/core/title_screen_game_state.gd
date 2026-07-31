## The state the game boots into: the title card, the build identity, and the
## button that moves the player on.
class_name TitleScreenGameState
extends GameState

## See [member GameState.id].
const ID: String = "title_screen"

## See [member GameState.scene_path].
const SCENE_PATH: String = "res://src/screens/title_screen.tscn"


func _init() -> void:
	super(ID, SCENE_PATH)
