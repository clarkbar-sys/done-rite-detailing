## The rules: one screen, no scrolling, three passes across the middle of it,
## and a way out at either end of the bottom row.
##
## [b]It used to be seven hundred characters and it is now about a hundred.[/b]
## The first version of this screen was four rules and three passes in two
## columns of body copy, and the two-column layout existed only because that was
## the one way the sentences and the tap targets both fitted. #175 called that
## what it was: a wall of text on the screen a player opens when they have
## already decided to play. What replaces it is the thing the words were
## describing — three numbered passes, three words each, in the order a panel
## goes through them — and a button that opens a film of somebody doing it.
## [WatchVideo] carries why the film is a link rather than something the game
## plays, and owns the address; nothing on this side knows it.
##
## [b]The wall is gone and what it taught is not[/b], because everything below
## was learned paying for it and every line of it is still load-bearing:
##
## [b]One screen, no scrolling, no pages.[/b] A rules screen that scrolls is a
## rules screen the second half of which nobody reads — so "one screen" is a
## constraint the layout is built against rather than a description of it, and
## [code]tests/integration/test_how_to_play.gd[/code] still holds every label to
## drawing all of its own lines. With three captions instead of four paragraphs
## that gate is cheap to pass, which is the point of having cleared the room.
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
## is the accent on the right, and focus opens on Play. The watch button is a
## third pill and it is [i]not[/i] on that row: it is not a way out, it is the
## other half of what this screen is for, so it sits under the passes it
## illustrates and leaves the bottom row saying exactly what it said before.
##
## [b]The type is not a fixed size, and this is the one screen in the game where
## that is true.[/b] The design is 1280x720 and project.godot stretches it
## "expand", so a phone held upright is handed the design width and as much
## extra design [i]height[/i] as its aspect asks for — 1280x2773 on a 1080x2340
## handset. Laid out at the sizes the mockup uses, that is a readable sheet
## floating in two thousand pixels of nothing, and the copy on it is about six
## CSS pixels tall on the glass. The room is there; the words were not using it.
## [method _lay_out] is what spends it. See that method for how big, and
## [method _fits] for why the arithmetic is a square root.
##
## [b]And gutting the copy is what made width the binding constraint.[/b] The
## type grows until the sheet fills the screen it was given, so a screen with
## less printed on it grows the type further — the wall of text ran out of
## height at about 2.4x and three captions do not run out at all, they reach
## [constant MAX_TYPE_SCALE]. What stops them first is the bottom row: the pills
## say twelve and seven characters in a face that advances a whole em per
## character, so past a certain size that row is wider than the sheet it is
## printed on and the card grows sideways off both edges of the phone.
## [method _fits_across] measures that and caps the factor at it — the type is
## as big as the [i]shorter[/i] of the two rooms allows, which is the only
## reading of "as big as it fits" that stays true on a screen of any shape.
##
## Same split as every screen: the [code].tscn[/code] owns layout and the copy —
## what is on screen, how big, in what order — and this owns brand, sourced from
## [Brand]. The type scale sits on this side of that line for the reason the
## colours do: it is one rule applied to every control on the screen, and a
## scale factor written into a scene file per label is not a rule, it is a
## column of numbers.
extends GameScreen

## The scene names the passes' headings and their captions with these two node
## names, at every depth, and [method _paint] colours them by looking for
## exactly that. See that method for why they are found rather than listed.
const HEADING: String = "Heading"
const BODY: String = "Body"

## The most the type is allowed to grow, whatever the screen. A ceiling rather
## than a number anybody arrived at: nothing in the wild should reach it, and a
## screen tall enough to ask for more than this is asking for a poster. Since
## the copy went, the height on a tall phone reaches it — see
## [method _fits_across] for what actually binds there.
const MAX_TYPE_SCALE: float = 3.0

## How much of the room the sheet is allowed to fill once it has settled. The
## rest is the margin the bay shows through, and the slack [method _fits]'s
## estimate is allowed to be wrong by.
const FILL: float = 0.92

## How many frames [method _lay_out] spends correcting its own guess before it
## stops looking. See [method _process].
const SETTLE_PASSES: int = 2

## The least room left between two pills sharing a row, in design pixels. It is
## what stops [method _widest_button] handing each of them exactly half the row
## and leaving them touching, and it is the gap [method _fits_across] budgets
## for when it asks whether that row still fits.
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
@onready var _strip: HBoxContainer = %Strip
@onready var _rule: ColorRect = %Rule
@onready var _title: Label = %Title
@onready var _title_accent: Label = %TitleAccent
@onready var _subtitle: Label = %Subtitle
@onready var _watch: Button = %Watch
@onready var _main_menu: Button = %MainMenu
@onready var _play: Button = %Play


func _ready() -> void:
	# Nothing to do per frame until a layout has been asked for; _lay_out turns
	# this back on and _process turns it off again once the type has settled.
	set_process(false)
	_remember()
	_dress()
	_watch.pressed.connect(_on_watch_pressed)
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
	for button: Button in _buttons():
		_base_button[button] = button.custom_minimum_size


## Everything on this screen that draws words: the labels and the three buttons.
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


## Every pill on the screen, in no particular order — the two exits and the one
## that opens the film.
func _buttons() -> Array[Button]:
	var found: Array[Button] = [_watch, _main_menu, _play]
	return found


## The two exits, as the row they share. [method _fits_across] and
## [method _widest_button] both need to know that they are two things dividing
## one row rather than three things dividing the sheet.
func _exits() -> Array[Button]:
	var found: Array[Button] = [_main_menu, _play]
	return found


## Chooses the size of the type for the screen it has actually been given, then
## arms the passes that correct the guess.
##
## [b]The correction has to happen on a later frame, not a later call.[/b] A
## container has not resized its children until it has been notified to sort
## them, and that notification is itself queued — so a
## [method Object.call_deferred] correction runs in the same frame as the change
## it is meant to measure and reads the height the sheet had [i]before[/i]. That
## version shipped nothing but looked right: it computed a correction off stale
## numbers, applied it, and left the type at the first estimate.
func _lay_out() -> void:
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
## lands in the margin instead of off the bottom of the screen. Since the
## paragraphs went there is almost nothing left that wraps, so the estimate is
## conservative nearly everywhere and the settle passes in [method _process] are
## what actually land it — which is the same behaviour it always had, arriving
## from underneath rather than from above.
static func _fits(factor: float, written: float, room: float) -> float:
	return clampf(factor * sqrt(room / written), 1.0, MAX_TYPE_SCALE)


## The largest factor the rows that cannot wrap can be drawn at and still fit
## [i]across[/i] the sheet: the two exits, the film button, and the three passes
## side by side.
##
## The screen is only ever given extra height — "expand" hands a portrait phone
## the design width and nothing more — so height is what [method _fits] spends
## and width is a fixed budget the type is spending too. A pill is as wide as
## the word on it, the display face advances a whole em per character, and the
## two exits together are nineteen characters plus the gap between them: at 3x
## that row is half again as wide as the sheet, and a row wider than the sheet
## does not clip, it pushes the card out past both edges of the phone.
##
## Measured from the type rather than assumed, because the thing that decides it
## is the [i]wording[/i] of two buttons, which is in the scene file and will
## change without anybody thinking of this. The floor is 1.0 for
## [method _fits]'s reason: a sheet whose own authored layout does not fit
## across is a bug in the scene, and shrinking the type below what was drawn
## would hide it.
func _fits_across() -> float:
	var alone: Array[Button] = [_watch]
	var widest: float = maxf(_row_width(_exits()), _row_width(alone))
	widest = maxf(widest, _strip_width())
	if widest <= 0.0:
		return MAX_TYPE_SCALE
	return maxf(_row_room() / widest, 1.0)


## How wide the row [param buttons] share has to be at the sizes the scene
## authored, gaps included.
func _row_width(buttons: Array[Button]) -> float:
	var total: float = float(BUTTON_GAP) * float(buttons.size() - 1)
	for button: Button in buttons:
		total += _base_width(button)
	return total


## How wide one pill is at the size the scene authored it: the wider of the
## minimum it was given and the room its own word needs.
##
## Both, because either can be the larger and the one that is larger is the one
## that sets the width. Main Menu is 340 design pixels of minimum carrying 288
## pixels of word; Play is 300 carrying 224. Grow the type and the words
## overtake the minimums, which is exactly the case this arithmetic exists for.
func _base_width(button: Button) -> float:
	return maxf(_words_width(button), _base_button[button].x)


## How wide the passes need their row to be at the sizes the scene authored.
##
## [b]The pills are not the only row on this sheet that cannot get narrower.[/b]
## The three passes divide the row equally and each one carries a heading in the
## display face, which does not wrap — so the row needs three of the widest of
## them, plus the gaps, and a factor that ignored it would grow "2. SPONGE" out
## of the third of the sheet it has been given. The captions underneath are left
## out on purpose: they wrap, and a thing that wraps is not a thing that sets a
## minimum width.
##
## The gap is read off the container rather than written down here, for
## [method _design_height]'s reason: the scene owns the layout, and a copy of
## its separation in this file is a copy that stops being true silently.
func _strip_width() -> float:
	var cells: int = _strip.get_child_count()
	if cells < 1:
		return 0.0
	var widest: float = 0.0
	for cell: Node in _strip.get_children():
		for control: Control in _typeset(cell):
			if control.name == HEADING:
				widest = maxf(widest, _words_width(control))
	var gaps: float = float(_strip.get_theme_constant("separation")) * float(cells - 1)
	return float(cells) * widest + gaps


## The room [param control]'s own words need at the size the scene authored it.
##
## Zero for anything this screen never wrote down a size for, which is nothing
## it draws — [method _remember] walks the same set — and zero is the harmless
## answer for whatever is not in it.
func _words_width(control: Control) -> float:
	var font: Font = control.get_theme_font("font")
	if font == null or not _base_type.has(control):
		return 0.0
	return (
		font
		. get_string_size(_words_of(control), HORIZONTAL_ALIGNMENT_LEFT, -1.0, _base_type[control])
		. x
	)


## What [param control] has written on it, whichever kind of control it is. A
## [Button] is not a [Label] and both of them draw words — see
## [method _typeset], which is where that distinction keeps mattering.
static func _words_of(control: Control) -> String:
	var label: Label = control as Label
	if label != null:
		return label.text
	var button: Button = control as Button
	return "" if button == null else button.text


## Draws every word at [param factor] times the size the scene asked for, or at
## what fits across the sheet if that is less.
##
## The buttons' minimum sizes go with it. A pill is a box around a word, and type
## grown to twice the size inside a box that stayed still is type that overflows
## its own button — which would also quietly walk the tap target back down
## towards the floor it is held above.
##
## [b]Height by the factor, width only as far as the sheet allows.[/b] The two
## are not symmetrical: this screen is given extra [i]height[/i] and never extra
## width, so a row of two pills whose widths both grew by two and a half is a row
## half again as wide as the sheet it is printed on. That does not clip — a
## minimum size propagates — it pushes the card out past both edges of the
## phone, which is what the first version of this did. A share of the row each
## is the ceiling, and it is a ceiling rather than a share: below it the scene's
## own widths are what they always were.
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
## length rather than examined at 1:1. Uneven pixels on a caption lose to a
## caption nobody can read.
func _scale_type(factor: float) -> void:
	var drawn: float = minf(factor, _fits_across())
	for control: Control in _base_type:
		control.add_theme_font_size_override(
			"font_size", maxi(1, roundi(float(_base_type[control]) * drawn))
		)
	for button: Button in _base_button:
		var base: Vector2 = _base_button[button]
		var ceiling: float = _widest_button(1 if button == _watch else _exits().size())
		button.custom_minimum_size = Vector2(minf(base.x * drawn, ceiling), base.y * drawn)
	dress_quiet(_watch)
	dress_quiet(_main_menu)
	dress_loud(_play)


## How wide any one pill is allowed to get on a row [param share] of them are
## dividing between the gaps.
##
## The watch button is alone on its row and gets the lot; the two exits get half
## each, less the gap. Passed rather than counted from the scene, because what
## the number means is "how many things are competing for this row" and the
## scene expresses that as which container a button is in — a fact this side can
## read out of [method _exits] without walking the tree for it.
func _widest_button(share: int) -> float:
	var shared: float = _row_room() - float(BUTTON_GAP) * float(share - 1)
	return maxf(shared / float(share), 1.0)


## How wide a row on the sheet is.
##
## Falls back to the whole screen before the first layout, when the column has no
## width yet. That first answer is too generous and it does not matter — the
## passes in [method _process] run once the containers have sorted, and the
## ceiling is right from then on.
func _row_room() -> float:
	return _column.size.x if _column.size.x > 0.0 else size.x


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


## Puts the brand on: the sheet the passes are printed on, the three pills, and
## the three colours the type comes in.
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
	dress_quiet(_watch)
	dress_quiet(_main_menu)
	dress_loud(_play)


## Sets every [Label] named [param label_name] anywhere under [param root] in
## [param colour] and [param face].
##
## Found rather than listed. There were fourteen of these when the rules were
## paragraphs and there are six now, and the walk is worth keeping at six for
## the reason it was worth having at fourteen: an [code]@onready[/code] line per
## label is a second copy of the scene tree living in this file, out of date the
## first time a step is added or reordered. What this walks instead is a
## convention the scene states out loud in its own node names —
## [constant HEADING] and [constant BODY] — which is one thing to keep true
## rather than six.
##
## [b]Colour and face together, because on this screen they are one decision.[/b]
## A heading is red and chunky and a caption is white and readable; those are
## not two rules that happen to agree, they are the two halves of "this is a
## step and that is what it does". Splitting them into two walks would let a
## step end up red and readable, which is a heading that has stopped looking
## like one.
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


## Out to the film, in a tab of its own, leaving the game exactly where it is.
##
## [b]The opening happens on this line and not one frame later.[/b] A browser
## credits a page with a gesture for a few seconds after the player makes one,
## and the first thing to ask spends it — so this handler cannot ring a bell,
## fade anything, await anything or defer the call, because every one of those
## is a chance for the tab to be blocked instead of opened, silently, on the
## web build only. [method WatchVideo.open] is one call for the same reason.
##
## No bell and no fade either way round: nothing has started, the player is
## coming straight back, and the theme should still be playing when they do.
func _on_watch_pressed() -> void:
	WatchVideo.open()


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
