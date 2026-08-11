## The state the game boots into when the command line asked for a tutorial take:
## the bay with nothing over it, filming one step of the job and then quitting.
##
## [b]A state rather than a scene the harness names.[/b] It would be shorter to
## point Godot straight at a scene file — and it would be the one place in this
## project where something other than [code]src/main/main.gd[/code] decides what is
## on screen. A take is a mode the game can be in, so it is a [GameState] like every
## other mode, and the only thing unusual about it is what puts it on: not a button,
## but [constant TutorialTake.ARG] on the way in.
##
## Nothing leads out of it. Every other state hands over to another one when the
## player presses something; this one is watched by a capture harness and ends by
## ending the process — see [code]src/screens/tutorial_take_screen.gd[/code].
class_name TutorialTakeGameState
extends GameState

## See [member GameState.id].
const ID: String = "tutorial_take"

## See [member GameState.scene_path].
const SCENE_PATH: String = "res://src/screens/tutorial_take_screen.tscn"


func _init() -> void:
	super(ID, SCENE_PATH)
