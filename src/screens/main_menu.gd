## The main menu: the car, slowly turning, and the one thing you can do about it.
##
## The room behind the button is the real one — [code]src/world/garage.tscn[/code],
## the same scene the play screen shows — rather than a picture of it, so the
## menu cannot drift away from the game it is a menu for. Nothing here reaches
## into that scene: whether the camera circles is a property set on the instance
## in this screen's own file, and that is the whole of the difference between
## this screen and the next one.
extends GameScreen

@onready var _start: Button = %Start


func _ready() -> void:
	_start.pressed.connect(_on_start_pressed)
	# Same reason as the title screen: playable from a keyboard or a pad the
	# moment it opens, not only by whoever brought a mouse.
	_start.grab_focus()


func _on_start_pressed() -> void:
	request_transition(PlayGameState.new())
