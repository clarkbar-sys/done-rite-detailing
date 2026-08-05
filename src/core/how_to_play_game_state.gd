## The rules, on one screen, hung off the menu.
##
## A state rather than a panel the menu shows and hides, for the reason every
## other screen here is one: the host owns what is on screen, screens ask to be
## replaced, and nothing in the project knows about two screens at once. A
## toggled panel would make the menu the first exception to that, and it would
## make "which screen am I on" a property of a node instead of a state.
class_name HowToPlayGameState
extends GameState

## See [member GameState.id].
const ID: String = "how_to_play"

## See [member GameState.scene_path].
const SCENE_PATH: String = "res://src/screens/how_to_play.tscn"


func _init() -> void:
	super(ID, SCENE_PATH)
