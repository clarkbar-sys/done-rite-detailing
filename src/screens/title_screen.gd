## The title screen: the business's logo, the project's name, which build this
## is, and Start — played over the same detailing bay the play screen shows,
## rather than a blank background, so the car is the first thing a player sees
## instead of something they wait a screen for.
##
## Start leads straight into [PlayGameState] — there is no menu screen between
## the title card and the game, on purpose. A player who has already seen the
## title has nothing left to decide before the room they're about to work in.
##
## The two labels are the day-0 screen this project started as, moved intact
## into a state of its own — the same text CI's smoke run and the integration
## tests read to confirm a build boots and knows which commit it is.
##
## [b]The lockup is the site's, not a new one.[/b] Card, then name, then a red
## pill: that is the order Done Rite's own page introduces itself in, and this
## screen is the first thing anyone sees of either. The picture and the shapes
## come from the same two places every time — the logo from
## [code]assets/brand/[/code], the colours and corners from [Brand] — so
## restyling the game is a diff in one file rather than a hunt through scenes.
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

@onready var _title: Label = %Title
@onready var _build: Label = %Build
@onready var _start: Button = %Start
@onready var _logo_card: PanelContainer = %LogoCard


func _ready() -> void:
	_title.text = str(ProjectSettings.get_setting("application/config/name"))
	_build.text = BuildInfo.describe()
	_dress()
	_start.pressed.connect(_on_start_pressed)
	# So the screen is playable from the keyboard or a pad the moment it opens,
	# rather than only by whoever brought a mouse.
	_start.grab_focus()


## Puts the brand on: the frame around the logo, the name under it, and the four
## faces of the pill.
##
## Every [Button] state gets its own box because Godot falls back to the theme's
## for any it is not given, so styling only `normal` would leave a hover and a
## press wearing the default grey — the one moment the button is being used.
func _dress() -> void:
	_logo_card.add_theme_stylebox_override("panel", Brand.card())
	# Secondary type under the wordmark, the same demotion the site's own
	# `.brand-text small` is: the logo says the name loudly once already. The
	# shadow is the difference between a page and a room — checked in the web
	# build, where grey-on-daylight was legible and not much more than that.
	_title.add_theme_color_override("font_color", Brand.MUTED)
	_title.add_theme_color_override("font_shadow_color", Color(Brand.INK, Brand.TYPE_SHADOW_ALPHA))
	_title.add_theme_constant_override("shadow_offset_y", Brand.TYPE_SHADOW_DROP)
	_title.add_theme_constant_override("shadow_outline_size", Brand.TYPE_SHADOW_SPREAD)
	var height: float = _start.custom_minimum_size.y
	_start.add_theme_stylebox_override("normal", Brand.pill(Brand.RED, height))
	_start.add_theme_stylebox_override(
		"hover", Brand.pill(Brand.RED.lightened(Brand.HOVER_LIFT), height)
	)
	_start.add_theme_stylebox_override("pressed", Brand.pill(Brand.RED_DARK, height))
	_start.add_theme_stylebox_override("focus", Brand.focus_ring(height))
	for role: String in [
		"font_color", "font_hover_color", "font_pressed_color", "font_focus_color"
	]:
		_start.add_theme_color_override(role, Brand.WHITE)


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
