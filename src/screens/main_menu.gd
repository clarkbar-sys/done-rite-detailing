## The menu: the same lockup the title card shows, with two things to press
## under it instead of none.
##
## [b]It is the title screen with one more pill, and that is on purpose.[/b]
## Same card, same logo, same build label in the same corner, and the same bay
## playing itself behind all of it — [Garage] with
## [member Garage.attracting] set, exactly as
## [code]src/screens/title_screen.tscn[/code] sets it. A menu drawn as a flat
## panel would be a screen the attract mode disappears behind, and the attract
## mode is the best argument this game makes for itself. The only thing that
## moves between the two screens is the logo card, which gives up a little height
## so a second button fits under it.
##
## [b]One of the two buttons is red and the other is not.[/b] [constant Brand.RED]
## is the site's one accent — the thing you are meant to press — so Play wears it
## and How to Play wears [method Brand.quiet_pill], the card's colour in the
## pill's shape. Two red pills would be defensible, and the site itself does it,
## but on a screen whose whole job is to be chosen from it leaves the eye with
## nowhere to land.
##
## [b]The music carries and the bell does not.[/b] The theme is started by the
## title screen's first gesture and is [i]not[/i] faded on the way in here — the
## [Bandstand] hangs off the host, so it plays straight through the swap, and
## this screen never asks it for anything until Play. That is the whole reason
## the fade moved off the title card's Start: a menu the music stops for is a
## menu that sounds like the end of something. The counter bell moved with it,
## and for the plainer reason: [constant Bell.Voice.START] means the job starts,
## and the job now starts here.
##
## [b]What this screen does not have to do is unlock the audio.[/b] The title
## card's [method Node._input] already spent the browser's first gesture — see
## [code]src/screens/title_screen.gd[/code] — so by the time anybody is looking
## at this, sound is allowed and the theme is already playing. Nothing here
## listens for a press on its own account.
##
## [b]And the credit for the cars is on this screen[/b], along the bottom. The ten
## models in [code]assets/models/cars/[/code] are CC-BY 4.0, which makes
## attribution a condition of using them rather than a courtesy, and a licence is
## not satisfied by a file in a repository the player never sees. This is the
## screen everybody passes through on the way to the bay, so this is where the
## line goes; [code]README.md[/code] and
## [code]assets/models/cars/ATTRIBUTION.txt[/code] carry the same words for
## whoever clones the repo. The wording lives in
## [code]src/screens/main_menu.tscn[/code] with the rest of what is on screen —
## what is done here is the colour, because grey type over a lit driveway needs
## the shadow [constant Brand.INK] gives it.
##
## Same split as every screen: the [code].tscn[/code] owns layout — what is on
## screen, how big, in what order — and this owns brand, sourced from [Brand].
extends GameScreen

## How dark the shadow under the credit line is. The same 0.7 the score's pops
## wear over the same room — see [code]src/ui/score_hud.gd[/code] — because it is
## the same problem: muted grey is legible over tarmac and vanishes over the sky.
const CREDIT_SHADOW_ALPHA: float = 0.7

## How thick that shadow is, in design pixels. Enough to survive the third-scale
## a phone renders this design at, which is what the panel readout's outline was
## picked at.
const CREDIT_OUTLINE: int = 6

@onready var _build: Label = %Build
@onready var _play: Button = %Play
@onready var _how_to_play: Button = %HowToPlay
@onready var _logo_card: PanelContainer = %LogoCard
@onready var _credits: Label = %Credits


func _ready() -> void:
	_build.text = BuildInfo.describe()
	_logo_card.add_theme_stylebox_override("panel", Brand.card())
	_credits.add_theme_color_override("font_color", Brand.MUTED)
	_credits.add_theme_color_override("font_outline_color", Color(Brand.INK, CREDIT_SHADOW_ALPHA))
	_credits.add_theme_constant_override("outline_size", CREDIT_OUTLINE)
	dress_loud(_play)
	dress_quiet(_how_to_play)
	_play.pressed.connect(_on_play_pressed)
	_how_to_play.pressed.connect(_on_how_to_play_pressed)
	# So the menu is playable from the keyboard or a pad the moment it opens,
	# rather than only by whoever brought a mouse — and on the button that is
	# already drawn as the answer, so the focus ring agrees with the colour.
	_play.grab_focus()


## The bell, the theme stepping aside, then the game — the three things Start
## used to do, doing them one screen later.
##
## The fade is asked for [i]before[/i] the transition, and that ordering is worth
## not moving: [method request_transition] frees this screen synchronously, so a
## fade requested after it would be emitted from a node on its way out. It
## survives either way, because the host is already connected to the signal, but
## the version that reads correctly is the one that does not rely on that.
func _on_play_pressed() -> void:
	ring_bell(Bell.Voice.START)
	stop_music()
	request_transition(PlayGameState.new())


## Off to the rules, with the theme left playing.
##
## No bell and no fade: nothing has started yet, and a player who wanted to read
## first should not be able to tell from the sound that they took the long way
## round.
func _on_how_to_play_pressed() -> void:
	request_transition(HowToPlayGameState.new())
