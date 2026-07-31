## The title screen: the project's name, which build this is, and Start.
##
## The two labels are the day-0 screen this project started as, moved intact
## into a state of its own — the same text CI's smoke run and the integration
## tests read to confirm a build boots and knows which commit it is.
extends GameScreen

@onready var _title: Label = %Title
@onready var _build: Label = %Build
@onready var _start: Button = %Start


func _ready() -> void:
	_title.text = str(ProjectSettings.get_setting("application/config/name"))
	_build.text = BuildInfo.describe()
	_start.pressed.connect(_on_start_pressed)
	# So the screen is playable from the keyboard or a pad the moment it opens,
	# rather than only by whoever brought a mouse.
	_start.grab_focus()


func _on_start_pressed() -> void:
	request_transition(MainMenuGameState.new())
