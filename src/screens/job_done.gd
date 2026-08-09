## The end of a run: what it scored, three letters to sign it with, and the board
## it goes on.
##
## [b]Two moments on one screen, and only one of them is ever up.[/b] A run that
## made the top ten opens on the prompt — the score, three big letters and the
## four buttons that dial them — and turns into the board the instant the player
## presses Enter. A run that did not make it skips straight to the board. They
## are two states of one screen rather than two screens because they are one
## sentence with a comma in it: nothing happens between them, there is nothing to
## go back to, and a transition would put a scene load inside the half-second a
## player is reading their own initials.
##
## [b]The wheel is [Initials] and this is the dial.[/b] What the player is doing
## is editing three characters with four verbs, all four of which are rules with
## edges — see that class — so the rules are unit-tested there and this owns only
## which label is red and which button says what. Same split [MotionPad] makes
## against [CameraOrbit] and [ToolBeltHud] against [ToolBelt]; what crosses is a
## string and an index.
##
## [b]The buttons say words rather than showing arrows, and that is a font
## decision.[/b] This project ships no font of its own, so every caption is drawn
## in Godot's built-in Open Sans, and [code]▲[/code] is a glyph Open Sans has no
## business having — a blank rectangle in a released build, which is exactly what
## [CarArrow] exists to avoid and what
## [code]tests/integration/test_main_menu.gd[/code] gates the credit line
## against. [CarArrow] answers that by drawing its chevron; four drawn controls
## for one screen would be four more icons to keep at one weight, and "Up" and
## "Down" are two words a cabinet's instruction card would have used anyway.
##
## [b]The arrow keys are claimed in [method Node._input], above the focus
## system.[/b] Godot's own focus navigation eats [code]ui_up[/code] and friends
## to move the ring between controls, so a screen that read them in
## [method Node._unhandled_input] would find the ring walking the four buttons
## while the letter under the cursor never moved. Claiming them earlier — the
## same trick [MotionPad] uses for the touches that land on its stick, and for
## the same reason — costs the focus ring its arrow keys on this one screen while
## the prompt is up, which is a fair trade: [kbd]Tab[/kbd] still moves it,
## [kbd]Enter[/kbd] still presses it, and the arrows are doing the thing the
## player came here to do. They are handed back the moment the board appears.
##
## [b]The theme comes back and no bell rings.[/b] The menu's Play faded the music
## out on the way into the game — see [code]src/screens/main_menu.gd[/code] — so
## this is where it returns, which is the sound of a run being over rather than
## of a thing being pressed. Nothing is rung: [enum Bell.Voice] has a counter
## chime that means the job is starting and a small one that means a patch came
## clean, and the last patch of the car already rang the second of those one frame
## before this screen existed.
##
## Same split as every screen: the [code].tscn[/code] owns layout — what is on
## screen, how big, in what order — and this owns brand, sourced from [Brand],
## plus the rows of the board, which are built here because there are thirty
## labels in them and thirty labels in a scene file is not a layout, it is a copy
## of a loop.
extends GameScreen

## The keyboard's half of the two wheel buttons.
const STEP_UP_ACTION: String = "ui_up"
const STEP_DOWN_ACTION: String = "ui_down"

## The keyboard's half of moving the cursor along the three slots.
const NEXT_ACTION: String = "ui_right"
const BACK_ACTION: String = "ui_left"

## How many places the board is drawn in. Half of [constant HighScores.KEEP],
## because the ten are laid out as two columns of five — see
## [code]src/screens/job_done.tscn[/code].
const ROWS: int = HighScores.KEEP / 2

## How many columns one of those two halves takes: the rank, the initials, and
## the score.
const CELLS: int = 3

## What an empty place on the board shows instead of initials and instead of a
## score. Hyphens rather than a blank row, so a board nobody has been on yet
## reads as ten places waiting rather than as a screen that failed to load.
const NO_INITIALS: String = "---"

## How long the letter under the cursor spends lit, and how long dark. Half a
## second each way is a cabinet's cursor: slow enough to read the letter through,
## fast enough that it is obviously the thing being edited.
const BLINK_SECONDS: float = 0.5

## How far down the blink takes it. Not to nothing — a letter that disappears is
## a letter the player has to wait to check, and the point of the blink is to say
## "this one", not to hide it.
const BLINK_DIM: float = 0.35

## Point size of a place on the board, and of the rank beside it.
const ROW_FONT: int = 28

## How wide the three cells of a place are, in design pixels: the rank, the
## initials, and the score.
##
## Written here rather than in the scene because the cells are built here — the
## scene owns that the grid is six columns and this owns what is in them, which
## is the same line [method _build_the_board] draws for the rest of the row. Wide
## enough for the longest thing each can hold at [constant ROW_FONT]: two digits,
## three capitals, and six.
const RANK_WIDTH: float = 72.0
const INITIALS_WIDTH: float = 170.0
const SCORE_WIDTH: float = 200.0

## Where the board is read from and written to.
##
## [b]An export purely so a suite can point it somewhere else.[/b] Every other
## door into [HighScores] takes a path for the reason
## [method Settings.save_muted] does — a test must exercise the round trip
## against a throwaway file rather than the one a real save lives at — and a
## screen cannot be handed an argument, so the seam has to be a property set
## before the node enters the tree. That is the same way
## [code]tests/integration/test_play_screen_done.gd[/code] pins the car it wants.
## Nothing in the game ever sets it.
@export var scores_path: String = HighScores.SCORES_PATH

## What the run being reported scored, which car it was on, and what the board
## for that car looked like on the way in. Read once from [RunResult] rather than
## per use: the fields there are process-wide and this screen is the only thing
## that ever reads them, so a copy taken at the door is what stops a Play Again
## halfway through this screen's life from changing what it is reporting.
var _score: int = 0
var _style: String = ""
var _table: Array[HighScores.Entry] = []

## Whether the run ended because the car was finished rather than because the
## clock ran out — [member RunResult.finished]. It is in the heading and nowhere
## else: it changes nothing about the score or the board.
var _finished: bool = false

## Which place the run took, or [constant HighScores.NOT_PLACED] for a run that
## did not make the board. Computed before the entry is written, which is the
## same index it lands at afterwards — see [method HighScores.placed].
var _rank: int = HighScores.NOT_PLACED

## The three letters being dialled, or [code]null[/code] once they have been
## handed in — which is also how [method _asking] tells the two halves of this
## screen apart, rather than a second flag that could disagree with it.
var _dial: Initials = null

## How far through the blink the cursor is, in seconds, wrapping at twice
## [constant BLINK_SECONDS].
var _blink: float = 0.0

## The board's thirty labels, in the order [method _place_of] indexes them.
var _cells: Array[Label] = []

@onready var _heading: Label = %Heading
@onready var _total: Label = %Score
@onready var _spelling: HBoxContainer = %Letters
@onready var _keys: HBoxContainer = %Keys
@onready var _board: GridContainer = %Table
@onready var _exits: HBoxContainer = %Exits
@onready var _up: Button = %Up
@onready var _down: Button = %Down
@onready var _next: Button = %Next
@onready var _enter: Button = %Enter
@onready var _main_menu: Button = %MainMenu
@onready var _play_again: Button = %PlayAgain
@onready var _card: PanelContainer = %Card


func _ready() -> void:
	_score = RunResult.score
	_style = RunResult.style
	_finished = RunResult.finished
	_table = HighScores.read_table(_style, scores_path)
	if RunResult.handed_in():
		_rank = HighScores.placed(_table, _score)
	if _rank != HighScores.NOT_PLACED:
		_dial = Initials.new()
	_card.add_theme_stylebox_override("panel", Brand.card())
	_heading.add_theme_color_override("font_color", Brand.WHITE)
	_total.add_theme_color_override("font_color", Brand.MUTED)
	for button: Button in [_up, _down, _next, _main_menu]:
		dress_quiet(button)
	for button: Button in [_enter, _play_again]:
		dress_loud(button)
	_up.pressed.connect(_on_step_pressed.bind(1))
	_down.pressed.connect(_on_step_pressed.bind(-1))
	_next.pressed.connect(_on_next_pressed)
	_enter.pressed.connect(_on_enter_pressed)
	_main_menu.pressed.connect(_on_main_menu_pressed)
	_play_again.pressed.connect(_on_play_again_pressed)
	_build_the_board()
	_show_the_screen()
	# The theme, back after the game took it away. See the class docs.
	request_music()


## Blinks the letter under the cursor, and nothing else.
##
## Off entirely once the initials are in — [method _show_the_screen] turns the
## callback off — so the board costs nothing per frame, which is the state this
## screen spends almost all of its life in.
func _process(delta: float) -> void:
	_blink = fmod(_blink + delta, BLINK_SECONDS * 2.0)
	_light_the_cursor()


## The arrow keys, claimed before the focus ring can have them.
##
## [method Node._input] and not [method Node._unhandled_input] — the class docs
## have the whole argument, and it is the same one
## [code]src/screens/play_screen.gd[/code] records about where a press has to be
## read to actually arrive. Only while the prompt is up: once the board is
## showing there is nothing to dial and the two exit pills should get their
## arrows back.
##
## Typed letters are the second half and are the reason the keyboard is worth
## supporting at all: somebody at a desk spells their initials in three
## keystrokes rather than in up to fifty-four presses of Up. Anything the wheel
## cannot spell is left alone rather than swallowed — [method Initials.type] says
## which — so [kbd]Tab[/kbd], [kbd]Enter[/kbd] and the rest still belong to
## whoever wants them.
func _input(event: InputEvent) -> void:
	if not _asking():
		return
	for action: String in [STEP_UP_ACTION, STEP_DOWN_ACTION, NEXT_ACTION, BACK_ACTION]:
		if not event.is_action_pressed(action, true):
			continue
		_drive(action)
		get_viewport().set_input_as_handled()
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if not _dial.type(char(key.unicode)):
		return
	_spell()
	get_viewport().set_input_as_handled()


## Whether the screen is still asking for initials.
##
## Read off [member _dial] rather than off a flag beside it: the dial existing
## and the prompt being up are the same fact, and two of them is one that can be
## wrong.
func _asking() -> bool:
	return _dial != null


## What [param action] does to the wheel. One place, so the keys and the buttons
## cannot drift into meaning different things.
func _drive(action: String) -> void:
	match action:
		STEP_UP_ACTION:
			_dial.step(1)
		STEP_DOWN_ACTION:
			_dial.step(-1)
		NEXT_ACTION:
			_dial.advance()
		BACK_ACTION:
			_dial.back()
	_spell()


## Builds the thirty labels the board is drawn out of.
##
## In code rather than in the scene for the reason
## [method HowToPlay._paint] finds its fourteen labels rather than listing them:
## thirty [code]@onready[/code] lines would be a second copy of the scene tree
## living in this file, out of date the first time [constant HighScores.KEEP]
## changes. What the scene owns is that the grid is six columns wide; what this
## owns is that six columns of five rows is two boards of five places.
func _build_the_board() -> void:
	_board.columns = CELLS * 2
	_cells.resize(ROWS * 2 * CELLS)
	# Row-major, so the first row of the grid is places 1 and 6 rather than 1 and
	# 2 — the two columns are halves of one list, read down and then down again,
	# which is how a cabinet's board is read.
	for row: int in ROWS:
		for half: int in 2:
			for column: int in CELLS:
				var at: int = _place_of(row + half * ROWS) + column
				var cell: Label = Label.new()
				cell.name = "Cell%d" % at
				cell.custom_minimum_size = Vector2(_cell_width(column), 0.0)
				# The rank and the score are numbers read against each other down
				# a column, so both are right-aligned and the initials between
				# them are centred in the space that leaves.
				cell.horizontal_alignment = (
					HORIZONTAL_ALIGNMENT_CENTER if column == 1 else HORIZONTAL_ALIGNMENT_RIGHT
				)
				cell.add_theme_font_size_override("font_size", ROW_FONT)
				_cells[at] = cell
				_board.add_child(cell)


## Where place [param index]'s three cells start in [member _cells].
static func _place_of(index: int) -> int:
	return index * CELLS


## How wide cell [param column] of a place is.
static func _cell_width(column: int) -> float:
	match column:
		0:
			return RANK_WIDTH
		1:
			return INITIALS_WIDTH
	return SCORE_WIDTH


## Puts up whichever half of this screen is current, and hands focus to the
## obvious thing to press on it.
##
## The two halves are hidden and shown rather than built and freed, because they
## are two states of one card and rebuilding would make the card jump as its
## contents were measured twice.
func _show_the_screen() -> void:
	var asking: bool = _asking()
	_spelling.visible = asking
	_keys.visible = asking
	_board.visible = not asking
	_exits.visible = not asking
	set_process(asking)
	_heading.text = "New High Score" if asking else _board_heading()
	_total.text = str(_score).pad_zeros(ScoreHud.DIGITS)
	if asking:
		_spell()
		_enter.grab_focus()
		return
	_write_the_board()
	_play_again.grab_focus()


## What the board is called: how the run ended, and the car it ended on.
##
## [b]The two ends of a run are worth different words.[/b] Finishing a car inside
## three minutes is the thing the game is asking for, and reporting it in the same
## sentence as running out of time would take the one moment worth celebrating and
## call it a timeout. Nothing else on this screen knows the difference — see
## [member RunResult.finished].
##
## A screen instanced with no run behind it — a test, or somebody opening the
## scene — has no car and no ending, and gets the plain heading rather than a
## dangling dash.
func _board_heading() -> String:
	if _style.is_empty():
		return "Top Scores"
	return "%s — %s" % ["Car Finished" if _finished else "Time Up", CarChoice.label_for(_style)]


## Writes the three letters into their labels, the one under the cursor in the
## accent.
##
## [constant Brand.RED] for the cursor and nothing else on this screen wearing it
## except Enter, which is the rule the whole palette runs on: red is the thing
## you are acting on. The blink is laid over it rather than replacing it — see
## [method _light_the_cursor] — so the letter says both "this one" and what it
## actually is.
func _spell() -> void:
	for index: int in Initials.LENGTH:
		var label: Label = _letter_at(index)
		label.text = _dial.letter(index)
		label.add_theme_color_override(
			"font_color", Brand.RED if index == _dial.at() else Brand.WHITE
		)
	# Restarted lit, so a press is always followed by a visible letter rather than
	# by whatever half of the blink it happened to land in.
	_blink = 0.0
	_light_the_cursor()


## Fades the letter under the cursor in and out on the blink, and leaves the
## other two alone.
func _light_the_cursor() -> void:
	if not _asking():
		return
	var lit: bool = _blink < BLINK_SECONDS
	for index: int in Initials.LENGTH:
		var alpha: float = 1.0 if lit or index != _dial.at() else BLINK_DIM
		_letter_at(index).modulate = Color(Color.WHITE, alpha)


## The label showing slot [param index]. The three of them are the scene's, in
## the order it lays them out, which is the order [Initials] counts them in.
func _letter_at(index: int) -> Label:
	return _spelling.get_child(index) as Label


## Fills the board's thirty cells from [member _table], and marks the row the
## player just took.
##
## Places past the end of the table are drawn rather than skipped, so the board
## is always ten places tall and a new player can see how many of them are going
## spare.
func _write_the_board() -> void:
	for index: int in ROWS * 2:
		var entry: HighScores.Entry = _table[index] if index < _table.size() else null
		var ink: Color = Brand.RED if index == _rank else Brand.WHITE
		var at: int = _place_of(index)
		_write_cell(_cells[at], "%d" % (index + 1), Brand.MUTED)
		_write_cell(_cells[at + 1], NO_INITIALS if entry == null else entry.initials, ink)
		_write_cell(
			_cells[at + 2],
			(
				"-".repeat(ScoreHud.DIGITS)
				if entry == null
				else str(entry.score).pad_zeros(ScoreHud.DIGITS)
			),
			ink
		)


## One cell of the board: [param text] in [param ink].
static func _write_cell(cell: Label, text: String, ink: Color) -> void:
	cell.text = text
	cell.add_theme_color_override("font_color", ink)


## Up or Down, [param by] one place on the wheel.
func _on_step_pressed(by: int) -> void:
	_dial.step(by)
	_spell()


## Next: the cursor along one slot, wrapping — which is also how a player gets
## back to a letter they got wrong. See [method Initials.advance].
func _on_next_pressed() -> void:
	_dial.advance()
	_spell()


## Enter: the initials go on the board, the board goes up, and the file is
## written.
##
## [method HighScores.record_now] rather than an insert into [member _table],
## because the table this screen read on the way in is a copy and the file is the
## thing that has to be right. What comes back is the board as saved, which is
## also the answer to "did anything else change" — nothing else can have, but the
## screen showing the file rather than its own arithmetic is what makes that
## checkable.
func _on_enter_pressed() -> void:
	_table = HighScores.record_now(_style, _dial.text(), _score, scores_path)
	_dial = null
	_show_the_screen()


## Back to the menu, with the theme still playing — it started when this screen
## opened and the menu is the screen it belongs to.
func _on_main_menu_pressed() -> void:
	request_transition(MainMenuGameState.new())


## Another car, the same three steps the menu's Play makes: the bell, the fade,
## then the transition, in that order and for
## [code]src/screens/main_menu.gd[/code]'s reasons.
func _on_play_again_pressed() -> void:
	ring_bell(Bell.Voice.START)
	stop_music()
	request_transition(PlayGameState.new())
