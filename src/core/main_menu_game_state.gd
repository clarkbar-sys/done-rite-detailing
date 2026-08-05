## Where Start leads now: the menu between the title card and the bay.
##
## The title screen used to open the game directly, on the argument that a player
## who has seen the title has nothing left to decide. That argument holds right
## up until there is a second thing to decide, and there is one now — the rules
## screen — so the title card stops being a door into the game and becomes a door
## into the menu, and this is the room behind it.
##
## Same shape as every other state and deliberately no more: an id and a scene
## path. See [GameState] for why that is all a screen costs.
class_name MainMenuGameState
extends GameState

## See [member GameState.id].
const ID: String = "main_menu"

## See [member GameState.scene_path].
const SCENE_PATH: String = "res://src/screens/main_menu.tscn"


func _init() -> void:
	super(ID, SCENE_PATH)
