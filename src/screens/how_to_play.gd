## The rules: one screen, no scrolling, no pages, and a way out at either end of
## the bottom row.
##
## [b]The brief is the shape.[/b] Four things the player can do, then the three
## passes a panel goes through, then out — and all of it visible at once, because
## a rules screen that scrolls is a rules screen the second half of which nobody
## reads. "One screen" is therefore a constraint the layout is built against
## rather than a description of it, and
## [code]tests/integration/test_how_to_play.gd[/code] holds it to that by asking
## every label whether it is showing all of its own lines.
##
## [b]Which is what put the four rules in two columns.[/b] The drafted copy is
## about seven hundred characters, the design is 1280x720, and the two buttons at
## the bottom are held at [method TouchTarget.min_design_size] because a control
## below it is one a thumb misses — that is not a guess, it is the bug the title
## screen's Start button shipped with. Stacked in one column the paragraphs wrap
## to roughly forty lines and either the type or the buttons has to give; in two
## they wrap to fourteen, and the type gets bigger instead of smaller. The
## trade is stated here because the mockup this screen is drawn from is a single
## column, and this is the one place it does not follow it.
##
## [b]The bay is behind it, as it is behind every other screen.[/b] A still
## picture would be cheaper and would be the only place in the project where a
## screen shows the room without the room being there. What it costs is a 3D
## scene rendering behind a card that covers most of it — paid once, since only
## one screen exists at a time — and what it buys is that leaving this screen
## does not look like leaving the game.
##
## [b]Play is the red one here too.[/b] Somebody who came to read and then wants
## to start should not have to go back to the menu to do it, so this screen has
## its own way into the game; and since it has two exits, the same rule the menu
## follows decides which is which. Main Menu is the quiet pill on the left, Play
## is the accent on the right, and focus opens on Play.
##
## [b]The type is not a fixed size, and this is the one screen in the game where
## that is true.[/b] The design is 1280x720 and project.godot stretches it
## "expand", so a phone held upright is handed the design width and as much extra
## design [i]height[/i] as its aspect asks for — 1280x2773 on a 1080x2340
## handset. Laid out at the sizes the mockup uses, that is a readable sheet
## floating in two thousand pixels of nothing, and the copy on it is about six
## CSS pixels tall on the glass. The room is there; the words were not using it.
## [method _lay_out] is what spends it. See that method for how big, and
## [method _fits] for why the arithmetic is a square root.
##
## Same split as every screen: the [code].tscn[/code] owns layout and the copy —
## what is on screen, how big, in what order — and this owns brand, sourced from
## [Brand]. The type scale sits on this side of that line for the reason the
## colours do: it is one rule applied to sixteen controls, and sixteen numbers in
## a scene file is not a rule, it is sixteen numbers.
extends GameScreen

## The scene names its headings and its body text with these two node names, at
## every depth, and [method _paint] colours them by looking for exactly that. See
## that method for why sixteen labels are found rather than listed.
const HEADING: String = "Heading"
const BODY: String = "Body"

## How wide a screen has to be, against its own height, to keep the four rules in
## two columns.
##
## Below this the sheet goes to one column, and it is a reflow rather than a
## rescale because those are the only two ways to spend height and only one of
## them helps: a column half as wide wraps the same sentence to twice as many
## lines, so two columns on a tall screen would grow [i]downwards[/i] as the type
## grew and reach a readable size no sooner. One column at the full width of the
## sheet is also the layout the mockup draws — it did not fit at 720, and this is
## the shape of screen where it does.
const TWO_COLUMN_ASPECT: float = 1.2

## The most the type is allowed to grow, whatever the screen. A ceiling rather
## than a number anybody arrived at: nothing in the wild should reach it, and a
## screen tall enough to ask for more than this is asking for a poster.
const MAX_TYPE_SCALE: float = 3.0

## How much of the room the sheet is allowed to fill once it has settled. The
## rest is the margin the bay shows through, and the slack [method _fits]'s
## estimate is allowed to be wrong by.
const FILL: float = 0.92

## How many frames [method _lay_out] spends correcting its own guess before it
## stops looking. See [method _process].
const SETTLE_PASSES: int = 2

## The least room left between the two pills at the bottom, in design pixels. It
## is what stops [method _widest_button] handing each of them exactly half the
## row and leaving them touching.
const BUTTON_GAP: int = 48

## What every piece of type on this screen was authored at, by control, and what
## every button's minimum size was. Captured once in [method _ready], because
## after the first scale the scene's own numbers are gone and a second pass that
## multiplied the multiplied ones would compound.
var _base_type: Dictionary[Control, int] = {}
var _base_button: Dictionary[Button, Vector2] = {}

## Frames of correction still owed. See [method _process].
var _settling: int = 0

@onready var _card: PanelContainer = %Card
@onready var _column: VBoxContainer = %Card/Column
@onready var _rules: GridContainer = %Rules
@onready var _rule: ColorRect = %Rule
@onready var _title: Label = %Title
@onready var _title_accent: Label = %TitleAccent
@onready var _subtitle: Label = %Subtitle
@onready var _main_menu: Button = %MainMenu
@onready var _play: Button = %Play


func _ready() -> void:
	# Nothing to do per frame until a layout has been asked for; _lay_out turns
	# this back on and _process turns it off again once the type has settled.
	set_process(false)
	_remember()
	_dress()
	_main_menu.pressed.connect(_on_main_menu_pressed)
	_play.pressed.connect(_on_play_pressed)
	# Every screen shape this can be opened at, and every one it can be turned
	# into afterwards — a browser window being dragged, a phone being rotated.
	resized.connect(_lay_out)
	_lay_out()
	# The primary button takes focus on open, so the whole flow — title, menu,
	# rules, game — is drivable from a keyboard or a pad without a mouse.
	_play.grab_focus()


## Writes down what the scene authored, before anything here overwrites it.
##
## [method _lay_out] runs more than once — on open, and again on every resize —
## and it sets absolute sizes rather than nudging the current ones. Without a
## copy of the originals the second pass would scale the first pass's output, and
## a window dragged slowly larger would grow type that never came back down.
func _remember() -> void:
	for control: Control in _typeset(self):
		_base_type[control] = control.get_theme_font_size("font_size")
	for button: Button in [_main_menu, _play]:
		_base_button[button] = button.custom_minimum_size


## Everything on this screen that draws words: the labels and the two buttons.
##
## A [Button] is not a [Label] and this is the second time that has mattered —
## the two glyphs Open Sans could not draw were both on a button, back when Open
## Sans was what this game drew in, and so is a third of the type that has to
## grow here.
static func _typeset(root: Node) -> Array[Control]:
	var found: Array[Control] = []
	for child: Node in root.get_children():
		if child is Label or child is Button:
			found.append(child as Control)
		found.append_array(_typeset(child))
	return found


## Chooses the shape of the sheet and the size of its type for the screen it has
## actually been given, then arms the passes that correct the guess.
##
## [b]The correction has to happen on a later frame, not a later call.[/b] A
## container has not resized its children until it has been notified to sort
## them, and that notification is itself queued — so a
## [method Object.call_deferred] correction runs in the same frame as the change
## it is meant to measure and reads the height the sheet had [i]before[/i]. That
## version shipped nothing but looked right: it computed a correction off stale
## numbers, applied it, and left the type at the first estimate.
func _lay_out() -> void:
	_rules.columns = 2 if size.x >= size.y * TWO_COLUMN_ASPECT else 1
	_scale_type(_fits(1.0, _design_height(), size.y))
	_settling = SETTLE_PASSES
	set_process(true)


## One correction per frame until the estimate has stopped moving.
##
## Bounded rather than run to convergence, and it disables itself the moment it
## is done, so the cost of this whole feature on a screen nobody is resizing is
## two frames of arithmetic when it opens. [method _fits] converges
## geometrically — the second pass is already inside the margin [constant FILL]
## leaves — so [constant SETTLE_PASSES] is a small number and not a loop with a
## bail-out.
func _process(_delta: float) -> void:
	_settling -= 1
	if _settling <= 0:
		set_process(false)
	_correct()


## The second pass: what the estimate cost, and what it should have been.
##
## The room is the row the card is centred in, read off that row rather than
## recomputed from [member Control.size] and the frame's margins. Those margins
## are the scene's to set and this has no business knowing them — and the version
## that did know them measured the card's own centred position instead, which
## made the room exactly the height the card already was and the correction a
## no-op that looked like it worked.
func _correct() -> void:
	var sheet: Control = _card.get_parent() as Control
	var written: float = _column.size.y
	if sheet == null or written <= 0.0:
		return
	_scale_type(_fits(_type_scale(), written, sheet.size.y * FILL))


## [param factor] grown from a sheet [param written] pixels tall to one that fills
## [param room], clamped to something sane.
##
## [b]The square root is the whole of the arithmetic and it is not a fudge.[/b]
## Wrapped text at a fixed width gets taller two ways at once as the type grows:
## every line is taller, and there are more of them, because a line holds fewer
## characters. Both are proportional to the type size, so the height of a
## paragraph goes as its [i]square[/i] — double the type and a paragraph is four
## times the height, not twice. Inverting that is what makes one correction land
## instead of ten.
##
## It is an under-estimate on purpose, and that is the direction to be wrong in:
## headings, buttons and separations grow linearly rather than quadratically, so
## the real sheet comes out a little shorter than this predicts and the error
## lands in the margin instead of off the bottom of the screen.
static func _fits(factor: float, written: float, room: float) -> float:
	return clampf(factor * sqrt(room / written), 1.0, MAX_TYPE_SCALE)


## Draws every word at [param factor] times the size the scene asked for.
##
## The buttons' minimum sizes go with it. A pill is a box around a word, and type
## grown to twice the size inside a box that stayed still is type that overflows
## its own button — which would also quietly walk the tap target back down
## towards the floor it is held above.
##
## [b]Height by [param factor], width only as far as the sheet allows.[/b] The
## two are not symmetrical: this screen is given extra [i]height[/i] and never
## extra width, so a row of two pills whose widths both grew by two and a half is
## a row half again as wide as the sheet it is printed on. That does not clip —
## a minimum size propagates — it pushes the card out past both edges of the
## phone, which is what the first version of this did. Half the row each is the
## ceiling, and it is a ceiling rather than a share: below it the scene's own
## widths are what they always were.
##
## The pills are re-cut afterwards because [method GameScreen.dress_loud] takes
## its corner radius from the height it is handed, and the height has just
## changed. A pill that kept its old radius at three times the size is a
## rectangle with slightly rounded corners.
##
## [b]This is the one place in the game that does not round to
## [method Brand.crisp], and the exemption is worth its paragraph.[/b] Both faces
## are drawn on an eighth of an em, so a size off that grid draws some strokes
## three screen pixels wide and some four — everywhere else in this project the
## sizes are multiples of eight for exactly that reason. Snapping here breaks two
## things at once. [method _fits] is a deliberate under-estimate whose error is
## meant to land in the margin, and [method Brand.crisp] rounds to
## [i]nearest[/i], so a 1.9x estimate becomes a 2.0x sheet — the error moves out
## of the margin and off the bottom of the screen, which is the failure this
## whole method exists to avoid. And the scale would quantise: with a base of 16
## there is nothing between 1.0x and 1.5x, so a phone that could take 1.2x either
## gets nothing or overflows.
##
## What is given up is smaller than it sounds. The sizes the scene authors are
## all on the grid, so a 16:9 screen — where the factor is small and the type is
## nearest its authored size — is nearly right; and the further from it a screen
## gets, the more the type is being grown for a reader holding a phone at arm's
## length rather than examined at 1:1. Uneven pixels on a paragraph lose to a
## paragraph nobody can read.
func _scale_type(factor: float) -> void:
	for control: Control in _base_type:
		control.add_theme_font_size_override(
			"font_size", maxi(1, roundi(float(_base_type[control]) * factor))
		)
	var ceiling: float = _widest_button()
	for button: Button in _base_button:
		var base: Vector2 = _base_button[button]
		button.custom_minimum_size = Vector2(minf(base.x * factor, ceiling), base.y * factor)
	dress_quiet(_main_menu)
	dress_loud(_play)


## How wide either pill is allowed to get: half the sheet, less the gap between
## them.
##
## Falls back to the whole screen before the first layout, when the column has no
## width yet. That first answer is too generous and it does not matter — the
## passes in [method _process] run once the containers have sorted, and the
## ceiling is right from then on.
func _widest_button() -> float:
	var row: float = _column.size.x if _column.size.x > 0.0 else size.x
	return maxf((row - float(BUTTON_GAP)) / 2.0, 1.0)


## What the type is currently drawn at, relative to the scene's own numbers.
func _type_scale() -> float:
	var reference: Button = _play
	return float(reference.get_theme_font_size("font_size")) / float(_base_type[reference])


## The height this screen was laid out against, from project.godot.
##
## Read rather than written down, for [method TouchTarget.design_width]'s reason:
## a copy of 720 in here is a copy that quietly stops being true the day somebody
## changes the base resolution.
static func _design_height() -> float:
	return str(ProjectSettings.get_setting("display/window/size/viewport_height", 720)).to_float()


## Puts the brand on: the sheet the rules are printed on, the two pills, and the
## three colours the type comes in.
func _dress() -> void:
	_card.add_theme_stylebox_override("panel", Brand.card())
	_rule.color = Brand.RED
	_title.add_theme_color_override("font_color", Brand.WHITE)
	_title.add_theme_font_override("font", Brand.DISPLAY_FACE)
	_title_accent.add_theme_color_override("font_color", Brand.RED)
	_title_accent.add_theme_font_override("font", Brand.DISPLAY_FACE)
	_subtitle.add_theme_color_override("font_color", Brand.MUTED)
	_subtitle.add_theme_font_override("font", Brand.BODY_FACE)
	_paint(_card, HEADING, Brand.RED, Brand.DISPLAY_FACE)
	_paint(_card, BODY, Brand.WHITE, Brand.BODY_FACE)
	dress_quiet(_main_menu)
	dress_loud(_play)


## Sets every [Label] named [param label_name] anywhere under [param root] in
## [param colour] and [param face].
##
## Found rather than listed because there are fourteen of them. A screen of rules
## is almost entirely labels, and a [code]@onready[/code] line per label would be
## a second copy of the scene tree living in this file, out of date the first
## time a row is added or reordered. What this walks instead is a convention the
## scene states out loud in its own node names — [constant HEADING] and
## [constant BODY] — which is one thing to keep true rather than fourteen.
##
## [b]Colour and face together, because on this screen they are one decision.[/b]
## A heading is red and chunky and a paragraph is white and readable; those are
## not two rules that happen to agree, they are the two halves of "this is a
## label and that is a sentence". Splitting them into two walks would let a row
## end up red and readable, which is a heading that has stopped looking like one.
##
## The body face is set here even though [code]project.godot[/code] already makes
## it the default. Redundant on paper and not in practice: this screen is the one
## that grows its own type, so it is the one where "what face is this drawn in"
## has to be a question with an answer in this file rather than an inheritance
## nobody can see.
static func _paint(root: Node, label_name: String, colour: Color, face: FontFile) -> void:
	for child: Node in root.get_children():
		var label: Label = child as Label
		if label != null and label.name == label_name:
			label.add_theme_color_override("font_color", colour)
			label.add_theme_font_override("font", face)
		_paint(child, label_name, colour, face)


## Back to the menu, with nothing started and nothing stopped.
func _on_main_menu_pressed() -> void:
	request_transition(MainMenuGameState.new())


## Into the game, the same three steps the menu's own Play makes — the bell, the
## fade, then the transition, in that order and for
## [code]src/screens/main_menu.gd[/code]'s reasons.
##
## The duplication is deliberate and is two lines: the alternative is a shared
## "start the game" helper on [GameScreen], which would put a rule about the
## music and the bell into the base class that every screen inherits and only two
## screens are allowed to use.
##
## [b]It does not choose a mode, and that is why it still says Play.[/b] The menu
## has the two pills; this screen has one button and it means "the game", which
## is whatever [member GameMode.chosen] already is — the arcade, unless the
## player has been in the bay and come back. A third mode pill on the rules
## screen would be the same choice offered twice, in a place a player came to
## read rather than to decide.
func _on_play_pressed() -> void:
	ring_bell(Bell.Voice.START)
	stop_music()
	request_transition(PlayGameState.new())
