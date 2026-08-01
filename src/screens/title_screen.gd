## The title screen: the project's name, which build this is, and Start —
## played over the same detailing bay the play screen shows, rather than a
## blank background, so the car is the first thing a player sees instead of
## something they wait a screen for.
##
## Start leads straight into [PlayGameState] — there is no menu screen between
## the title card and the game, on purpose. A player who has already seen the
## title has nothing left to decide before the room they're about to work in.
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


## The bell first, then the game.
##
## The order does not matter to the sound — the host owns the [Chime] and it
## outlives this screen, which is the reason the bell is asked for rather than
## played here — but it matters to what the press is [i]for[/i]. A browser will
## not let a page make a noise until somebody has touched it, so this is the
## press that unlocks audio for the whole game as well as the one that starts it.
## [Chime] has the rest of that argument.
func _on_start_pressed() -> void:
	ring_bell(Bell.Voice.START)
	request_transition(PlayGameState.new())
