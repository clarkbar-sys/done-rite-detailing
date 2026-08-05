## The title screen: the business's logo, which build this is, and Start —
## played over the same detailing bay the play screen shows, rather than a
## blank background, so the car is the first thing a player sees instead of
## something they wait a screen for.
##
## [b]And the bay is being worked while you read it.[/b] What is behind the card is
## the game playing itself — a filthy car, a power wash taking the mud off a panel,
## a bottle of the right cleaner going onto the paint it left, a rag buffing that
## out to a shine, and the eye walking round to whatever is being worked on. Twelve
## seconds a panel, and when the last one is done the mud goes back on and it starts
## again. It is a cabinet's attract mode, and it is the honest kind: not a recording
## of the game but the game, driven through [method Garage.steer],
## [method Garage.aim_at] and the [ToolBelt] — the three controls a player has.
## [member Garage.attracting] is the switch and [AttractRoutine] is what it decides.
##
## [b]Which is why this screen is now first person.[/b] The showcase circuit it used
## to run — a camera orbiting a clean car from outside — could not show a tool
## working, because there is nobody in that shot to hold one. The scene file
## therefore sets the same three exports the play screen sets, plus the demo, and
## the difference between the title card and the game is once again nothing but what
## is switched on in one [Garage] instance.
##
## [b]The bay works in silence; the theme is separate.[/b]
## [signal Grime.patch_finished] is left unconnected here deliberately — the play
## screen rings a bell on it, and a title screen that dinged its way through a car
## wash on its own would be both annoying and, in a browser, impossible: audio is
## locked until the first press. [Chime] has that argument.
##
## What this screen does play is [Fanfare], and [method _input] is the whole of
## when. Not [method _ready]: a browser drops any sound a page makes before
## somebody has touched it, and it drops it silently, so a theme started when the
## screen opens would simply not exist for most of the people who see this game.
## The first press, key or touch anywhere on the screen is both the gesture the
## browser is waiting for and the earliest moment the music is allowed to exist,
## so it is the moment it starts — on every platform, not only in a browser,
## because one path that always works beats two that disagree about when.
##
## The cost of that, stated rather than hidden: somebody who opens the page and
## watches the attract mode without touching anything hears nothing. That is the
## same bargain the bell already made and the same one the README already
## describes the game as making.
##
## Start does not cut it off, and no longer asks for it to go at all. The theme
## is meant to carry across the menu and fade as the game opens, so the fade
## moved to the press that opens the game — see [code]src/screens/main_menu.gd[/code].
## The [Bandstand] hangs off the host, so it plays straight through the swap
## that frees this screen.
##
## The counter bell moved with it, for the plainer reason: it is
## [constant Bell.Voice.START], it means the job starts, and pressing Start no
## longer starts a job. What this press still does is unlock the audio — that is
## [method _input] above, on the same press, and it is why the theme coming up is
## the answer the player gets rather than silence.
##
## [b]Start leads to [MainMenuGameState], not to the game.[/b] It used to lead
## straight into [PlayGameState], on the argument that a player who has seen the
## title has nothing left to decide. That was true while there was nothing else
## to offer them; there is now a screen of rules, and a title card is the wrong
## place to hang a second door off. So the card became a door into the menu, and
## the menu is where the choice lives.
##
## The build label is the day-0 screen this project started as, moved intact
## into a state of its own — the same text CI's smoke run and the integration
## tests read to confirm a build boots and knows which commit it is.
##
## [b]The lockup is the site's, not a new one.[/b] Card, then a red pill: that
## is the order Done Rite's own page introduces itself in, and this screen is
## the first thing anyone sees of either. The picture and the shapes come from
## the same two places every time — the logo from [code]assets/brand/[/code],
## the colours and corners from [Brand] — so restyling the game is a diff in
## one file rather than a hunt through scenes.
##
## The logo is imported with mipmaps and drawn with a mipmapped filter, which is
## not this project's default for a 2D texture. It has to be: the design is
## scaled to roughly a third on a phone (see [TouchTarget] for where that number
## comes from), so a 500-pixel-wide picture is minified to about 127 there, and
## an unmipmapped minification is where fine artwork turns to shimmer.
##
## The split between this script and the scene is deliberate and worth stating,
## since both could do either job: the [code].tscn[/code] owns [b]layout[/b] —
## what is on screen, how big, in what order — and this script owns [b]brand[/b],
## every colour and corner, sourced from [Brand]. A stylebox baked into the
## scene would be a second copy of the palette that no test reads and no
## grep finds.
extends GameScreen

## Whether the theme has been asked for yet. The title screen only gets one first
## touch and the music only starts on it — see [method _input].
var _sounded: bool = false

@onready var _build: Label = %Build
@onready var _start: Button = %Start
@onready var _logo_card: PanelContainer = %LogoCard


func _ready() -> void:
	_build.text = BuildInfo.describe()
	_dress()
	_start.pressed.connect(_on_start_pressed)
	# So the screen is playable from the keyboard or a pad the moment it opens,
	# rather than only by whoever brought a mouse.
	_start.grab_focus()


## Starts the theme on the first press, key or touch this screen sees.
##
## [method Node._input] rather than [method Node._unhandled_input]: a click that
## lands on Start is consumed by the button and never reaches the unhandled pass,
## and the press that starts the game is exactly the press somebody who came here
## to play makes first. Nothing is marked handled here, so Start still works —
## this listens to the input, it does not take it.
##
## [b]Which events count.[/b] Only the four that a browser accepts as a gesture:
## a mouse button going down, a touch, a key, a pad button. Not mouse motion —
## moving the pointer over a page does not unlock its audio, so starting the
## theme on it would burn the one flag this screen has on an event that cannot
## make a sound and the music would never play at all.
func _input(event: InputEvent) -> void:
	if _sounded or not _is_gesture(event):
		return
	_sounded = true
	# Nothing left to listen for, and this runs on every event the game sees.
	set_process_input(false)
	request_music()


## Whether [param event] is the kind of thing a browser unlocks audio on: a
## press, rather than a release or a movement.
##
## Static and pure so [code]tests/integration/test_title_screen_music.gd[/code]
## can ask it about an event directly, instead of only through the screen's own
## flag.
static func _is_gesture(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventKey:
		return (event as InputEventKey).pressed
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).pressed
	return false


## Puts the brand on: the frame around the logo, and the pill.
##
## The four faces of the pill are [method GameScreen.dress_loud]'s job, and it is
## on the base class rather than here because there are three screens with
## buttons on them now — see that method for the fallback this project keeps
## walking into.
func _dress() -> void:
	_logo_card.add_theme_stylebox_override("panel", Brand.card())
	dress_loud(_start)


## Straight to the menu, with the theme left playing and nothing rung.
##
## [b]Both of the things this used to do went with the game.[/b] The bell and the
## fade now fire on the menu's Play, because that is where the job starts and
## where the music is supposed to step aside; a title card that dinged and then
## faded the theme on its way into a menu would announce an ending at the point a
## player was still choosing.
##
## What is left is one line, and the press it sits on is still the important one:
## a browser will not let a page make a noise until somebody has touched it, so
## this is where audio is unlocked for the whole game. That happens in
## [method _input], on the same press, and it is the reason the theme comes up as
## the menu opens rather than into silence. [Chime] has the rest of that argument.
func _on_start_pressed() -> void:
	request_transition(MainMenuGameState.new())
