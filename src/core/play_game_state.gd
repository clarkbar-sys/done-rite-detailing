## Where Start leads: the garage with nothing over it.
##
## The title screen and this show the same room and the same car — the
## difference is that the title screen shows it *off*, with a slowly circling
## camera and a button on top, and this is the game, holding still and
## waiting for a player who cannot do anything yet. That "cannot do anything
## yet" is the honest state of it, and it is a state rather than a flag on
## the title screen so the things that come next (a car to walk up to, a tool
## to pick) hang off something real.
class_name PlayGameState
extends GameState

## See [member GameState.id].
const ID: String = "play"

## See [member GameState.scene_path].
const SCENE_PATH: String = "res://src/screens/play_screen.tscn"


func _init() -> void:
	super(ID, SCENE_PATH)
