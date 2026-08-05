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
## Same split as every screen: the [code].tscn[/code] owns layout and the copy —
## what is on screen, how big, in what order — and this owns brand, sourced from
## [Brand].
extends GameScreen

## The scene names its headings and its body text with these two node names, at
## every depth, and [method _paint] colours them by looking for exactly that. See
## that method for why sixteen labels are found rather than listed.
const HEADING: String = "Heading"
const BODY: String = "Body"

@onready var _card: PanelContainer = %Card
@onready var _rule: ColorRect = %Rule
@onready var _title: Label = %Title
@onready var _title_accent: Label = %TitleAccent
@onready var _subtitle: Label = %Subtitle
@onready var _main_menu: Button = %MainMenu
@onready var _play: Button = %Play


func _ready() -> void:
	_dress()
	_main_menu.pressed.connect(_on_main_menu_pressed)
	_play.pressed.connect(_on_play_pressed)
	# The primary button takes focus on open, so the whole flow — title, menu,
	# rules, game — is drivable from a keyboard or a pad without a mouse.
	_play.grab_focus()


## Puts the brand on: the sheet the rules are printed on, the two pills, and the
## three colours the type comes in.
func _dress() -> void:
	_card.add_theme_stylebox_override("panel", Brand.card())
	_rule.color = Brand.RED
	_title.add_theme_color_override("font_color", Brand.WHITE)
	_title_accent.add_theme_color_override("font_color", Brand.RED)
	_subtitle.add_theme_color_override("font_color", Brand.MUTED)
	_paint(_card, HEADING, Brand.RED)
	_paint(_card, BODY, Brand.WHITE)
	dress_quiet(_main_menu)
	dress_loud(_play)


## Colours every [Label] named [param label_name] anywhere under [param root] in
## [param colour].
##
## Found rather than listed because there are fourteen of them. A screen of rules
## is almost entirely labels, and a [code]@onready[/code] line per label would be
## a second copy of the scene tree living in this file, out of date the first
## time a row is added or reordered. What this walks instead is a convention the
## scene states out loud in its own node names — [constant HEADING] and
## [constant BODY] — which is one thing to keep true rather than fourteen.
static func _paint(root: Node, label_name: String, colour: Color) -> void:
	for child: Node in root.get_children():
		var label: Label = child as Label
		if label != null and label.name == label_name:
			label.add_theme_color_override("font_color", colour)
		_paint(child, label_name, colour)


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
func _on_play_pressed() -> void:
	ring_bell(Bell.Voice.START)
	stop_music()
	request_transition(PlayGameState.new())
