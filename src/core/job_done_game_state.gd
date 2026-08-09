## The end of a run: the car is finished, and the board wants to know who did it.
##
## A state of its own rather than a panel the play screen raises, for the reason
## [HowToPlayGameState] is one: the host owns what is on screen, screens ask to
## be replaced, and nothing in the project knows about two screens at once. It
## also happens to be the honest description — a player at this screen cannot
## walk, aim or clean anything, so "still on the play screen with something over
## it" would be a lie about what the game is doing.
##
## What the run was worth crosses in [RunResult], because a state carries an id
## and a scene path and nothing else. See that class for why it is not carried
## here.
class_name JobDoneGameState
extends GameState

## See [member GameState.id].
const ID: String = "job_done"

## See [member GameState.scene_path].
const SCENE_PATH: String = "res://src/screens/job_done.tscn"


func _init() -> void:
	super(ID, SCENE_PATH)
