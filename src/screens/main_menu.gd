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
## [b]And the bay behind it is a showroom.[/b] The pack has ten cars in it and
## [code]#142[/code] had pinned the game to one of them, which is nine models
## nobody could reach without editing a scene file. This screen is where that is
## paid back: the arrows either side step through [constant MeshCar.STYLES], the
## room parks whichever one they land on ([method Garage.show_style]), the name
## goes under the lockup, and [CarChoice] remembers it so Play opens with the car
## the player was just looking at.
##
## [b]The car in the bay is the choice, rather than a picture of it.[/b] Nothing
## on this screen keeps a style of its own: what is parked is asked of the room
## and stepped from there. A picker that held its own idea of the answer is a
## picker that can disagree with the room it is standing in, and the version of
## that bug nobody would catch is the one where the label is right and the car is
## not.
##
## [b]Which also settles what happens before anybody has chosen.[/b] The first
## menu of a run is opened over the car the title card was already showing —
## [CarChoice] draws once and remembers, so the room behind Start is the room
## behind the menu. This screen reads that car on the way in and names it, rather
## than choosing one of its own: the first car a player is offered is the first
## car they were shown.
##
## [b]And the credit for the models is on this screen[/b], along the bottom. The
## ten cars in [code]assets/models/cars/[/code] and the driveway they are parked
## on in [code]assets/models/driveway/[/code] are both CC-BY 4.0, which makes
## attribution a condition of using them rather than a courtesy, and a licence is
## not satisfied by a file in a repository the player never sees. This is the
## screen everybody passes through on the way to the bay, so this is where the
## lines go; [code]README.md[/code] and the [code]ATTRIBUTION.txt[/code] beside
## each model carry the same words for whoever clones the repo. The wording lives
## in [code]src/screens/main_menu.tscn[/code] with the rest of what is on screen —
## what is done here is the colour, because grey type over a lit driveway needs
## the shadow [constant Brand.INK] gives it.
##
## Same split as every screen: the [code].tscn[/code] owns layout — what is on
## screen, how big, in what order — and this owns brand, sourced from [Brand].
extends GameScreen

## How dark the shadow under type laid over the room is. The same 0.7 the score's
## pops wear over the same room — see [code]src/ui/score_hud.gd[/code] — because
## it is the same problem: type is legible over tarmac and vanishes over the sky.
const SHADOW_ALPHA: float = 0.7

## How thick that shadow is, in design pixels. Enough to survive the third-scale
## a phone renders this design at, which is what the panel readout's outline was
## picked at.
const OUTLINE_PX: int = 6

@onready var _build: Label = %Build
@onready var _play: Button = %Play
@onready var _how_to_play: Button = %HowToPlay
@onready var _logo_card: PanelContainer = %LogoCard
@onready var _credits: Label = %Credits
@onready var _car_name: Label = %CarName
@onready var _previous_car: CarArrow = %PreviousCar
@onready var _next_car: CarArrow = %NextCar

## The room this screen is played over, which is also the showroom the car is
## picked out of. By node name and not by a unique name, because the room is
## instanced into this scene rather than authored in it — the same way
## [code]tests/integration/test_main_menu.gd[/code] reaches it.
@onready var _garage: Garage = $Garage


func _ready() -> void:
	_build.text = BuildInfo.describe()
	_logo_card.add_theme_stylebox_override("panel", Brand.card())
	_over_the_bay(_credits, Brand.MUTED)
	_over_the_bay(_car_name, Brand.WHITE)
	dress_loud(_play)
	dress_quiet(_how_to_play)
	_play.pressed.connect(_on_play_pressed)
	_how_to_play.pressed.connect(_on_how_to_play_pressed)
	for arrow: CarArrow in [_previous_car, _next_car]:
		dress_quiet(arrow)
		arrow.pressed.connect(_on_arrow_pressed.bind(arrow.step()))
	# Whatever the room drew, adopted rather than replaced — see the class docs.
	# The room is a child, so its car has already been built and can be asked.
	_show_the_car(_parked_style())
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


## One press of an arrow: the next car along, [param step] places from the one
## that is parked.
##
## No bell and no fade, for [method _on_how_to_play_pressed]'s reason and one
## more. Nothing has started, so nothing should sound like it has — and this is a
## press a player is expected to make several of in a row, which is the one shape
## of interaction a counter bell turns into a fairground.
func _on_arrow_pressed(step: int) -> void:
	_show_the_car(CarChoice.stepped(_parked_style(), step, MeshCar.STYLES))


## Parks [param style] in the bay, says its name under the lockup, and remembers
## it as the car Play will open with.
##
## The three of those are one action and never happen apart, which is why they are
## one function: a name that moved without the car is the bug this screen is most
## likely to grow, and the way it grows is somebody adding a fourth caller that
## does two of the three.
##
## An empty style does nothing. That is a room with no [MeshCar] in it — every
## fixture under [code]tests/fixtures/[/code] is one — and the honest answer there
## is a menu with no car to name rather than a crash on the way to a screen that
## would have worked.
func _show_the_car(style: String) -> void:
	if style.is_empty():
		return
	CarChoice.choose(style)
	_garage.show_style(style)
	_car_name.text = CarChoice.label_for(style)


## Which of the ten is standing in the bay, or [code]""[/code] for a room parking
## something that is not one of them.
##
## Asked of the room every time rather than remembered here — the class docs have
## why, and it is the difference between a label that can be wrong and one that
## cannot.
func _parked_style() -> String:
	var parked: MeshCar = _garage.car() as MeshCar
	return "" if parked == null else parked.style


## Puts [param label] in [param ink] over an ink shadow, which is what type laid
## over a lit driveway costs.
##
## Both labels on this screen need it and neither needs anything else: the thing
## behind them is tarmac, grass, sky and a car of whatever colour was drawn, and
## every one of those is a background some flat colour disappears into. The
## outline is what makes legibility a promise rather than a hope, and it is the
## same treatment the score wears over the same room.
func _over_the_bay(label: Label, ink: Color) -> void:
	label.add_theme_color_override("font_color", ink)
	label.add_theme_color_override("font_outline_color", Color(Brand.INK, SHADOW_ALPHA))
	label.add_theme_constant_override("outline_size", OUTLINE_PX)
