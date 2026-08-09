## Integration test for the end of a run: the prompt that asks for three letters,
## the board they land on, and the file the board survives in.
##
## [b]The screen is instanced rather than walked into through
## [code]main.tscn[/code][/b], unlike the trigger and score suites: nothing here
## presses a pixel. What is being asserted is which half of the card is up, what
## the labels say, and what ends up on disk — all of which are readable off the
## screen on its own, and none of which can be swallowed by a control higher up
## the tree.
##
## [b]Nothing here touches the real save.[/b] The screen's
## [code]scores_path[/code] export exists for exactly this and is set before the
## node enters the tree, the same way
## [code]tests/integration/test_play_screen_done.gd[/code] pins the car it wants.
## A test that wrote to [constant HighScores.SCORES_PATH] would be writing the
## file a real boot reads.
##
## [b]And [RunResult] is put back.[/b] It is process-wide by design — see that
## class — so a suite that left a finished run in it would hand it to whichever
## suite runs next.
extends GutTest

const JOB_DONE: String = "res://src/screens/job_done.tscn"

## Written and deleted per test, never [constant HighScores.SCORES_PATH].
const TEMP_SCORES: String = "user://test_job_done_scores.json"

## Two of the ten, so "the board is kept per car" is a claim about two boards
## that cannot see each other.
const SEDAN: String = "sedan"
const COUPE: String = "coupe"

## What the run being reported is worth. Six digits' worth of nothing in
## particular, chosen so the zero padding below is visible.
const SCORE: int = 4200

var _screen: GameScreen = null
var _requested: Array[GameState] = []
var _music_asked: int = 0
var _window_size_before: Vector2i = Vector2i.ZERO
var _style_before: String = ""
var _score_before: int = 0
var _patches_before: int = 0
var _finished_before: bool = false


func before_each() -> void:
	_requested = []
	_music_asked = 0
	_style_before = RunResult.style
	_score_before = RunResult.score
	_patches_before = RunResult.patches
	_finished_before = RunResult.finished
	RunResult.forget()
	_clear_the_save()
	# A headless window is 64x64, which is smaller than one tap target, and the
	# card below lays itself out against the window. Put back in after_each: every
	# suite shares this window.
	var root: Window = get_tree().root
	_window_size_before = root.size
	root.size = root.content_scale_size


func after_each() -> void:
	get_tree().root.size = _window_size_before
	RunResult.remember(_style_before, _score_before, _patches_before, _finished_before)
	_clear_the_save()


func _clear_the_save() -> void:
	if FileAccess.file_exists(TEMP_SCORES):
		DirAccess.remove_absolute(TEMP_SCORES)


## Opens the screen on a run worth [param score] on [param style] that ended
## because the clock did — the ordinary case. [method _open_finished] is the
## other one.
##
## The path is set through [method Object.set] rather than assigned: the scene's
## root is a [GameScreen] and the export belongs to the script on it, which is
## the one property in this file the type checker cannot see.
func _open(style: String, score: int, whole: bool = false) -> void:
	RunResult.remember(style, score, 1, whole)
	var packed: PackedScene = load(JOB_DONE) as PackedScene
	assert_not_null(packed, "could not load %s" % JOB_DONE)
	if packed == null:
		return
	var screen: GameScreen = packed.instantiate() as GameScreen
	assert_not_null(screen, "%s does not extend GameScreen" % JOB_DONE)
	if screen == null:
		return
	screen.set("scores_path", TEMP_SCORES)
	_screen = screen
	# Connected before the node enters the tree, because `_ready()` fires inside
	# add_child and this screen asks for the theme from there — a listener wired up
	# afterwards would miss the one signal it is watching for.
	_screen.transition_requested.connect(_record)
	_screen.music_requested.connect(_record_music)
	add_child_autofree(_screen)
	# `_ready()` has already fired inside add_child; the frame is only here to let
	# layout settle before any size below is read.
	await wait_process_frames(1)


func _record(state: GameState) -> void:
	_requested.append(state)


func _record_music() -> void:
	_music_asked += 1


## Fills [param style]'s board so that nothing modest can get onto it.
func _fill_the_board(style: String) -> void:
	for index: int in HighScores.KEEP:
		HighScores.record(style, "AAA", 100_000 - index, 1, TEMP_SCORES)


func _node(unique_name: String) -> Control:
	return _screen.get_node("%" + unique_name) as Control


func _button(unique_name: String) -> Button:
	return _screen.get_node("%" + unique_name) as Button


func _label(unique_name: String) -> Label:
	return _screen.get_node("%" + unique_name) as Label


## The three letters as they currently read.
func _spelled() -> String:
	var letters: Node = _node("Letters")
	var spelled: String = ""
	for index: int in Initials.LENGTH:
		spelled += (letters.get_child(index) as Label).text
	return spelled


## Cell [param column] of place [param place] on the board — the rank, the
## initials or the score.
##
## The arithmetic is the inverse of the one
## [code]src/screens/job_done.gd[/code] builds the grid with, and it is worth
## spelling out here rather than reaching for a node name: the ten places are two
## columns of five in a six-wide grid, so the grid's children run place 1, place
## 6, place 2, place 7 and so on. A test that assumed they ran 1 to 10 would pass
## on an empty board and lie on a full one.
func _cell(place: int, column: int) -> Label:
	var rows: int = HighScores.KEEP / 2
	var child: int = ((place % rows) * 2 + place / rows) * 3 + column
	return _node("Table").get_child(child) as Label


# ---- which half of the card is up ----------------------------------------------


func test_a_run_that_made_the_board_is_asked_for_initials() -> void:
	await _open(SEDAN, SCORE)
	assert_true(_node("Letters").visible, "a new high score must ask who")
	assert_true(_node("Keys").visible)
	assert_false(_node("Table").visible, "and the board waits until it has been told")
	assert_false(_node("Exits").visible)


func test_the_first_run_on_a_car_always_makes_the_board() -> void:
	await _open(SEDAN, 1)
	assert_true(_node("Letters").visible, "an empty board has ten places going spare")


func test_a_run_that_did_not_make_the_board_goes_straight_to_it() -> void:
	_fill_the_board(SEDAN)
	await _open(SEDAN, 1)
	assert_false(_node("Letters").visible, "nobody is asked to sign a run that did not place")
	assert_true(_node("Table").visible)
	assert_true(_node("Exits").visible)


func test_a_run_that_scored_nothing_does_not_get_asked() -> void:
	await _open(SEDAN, 0)
	assert_false(_node("Letters").visible)
	assert_true(_node("Table").visible)


func test_a_screen_with_no_run_behind_it_shows_a_board_rather_than_crashing() -> void:
	# What a test, or somebody opening the scene, gets. RunResult was cleared in
	# before_each and nothing has set it.
	var packed: PackedScene = load(JOB_DONE) as PackedScene
	var screen: GameScreen = packed.instantiate() as GameScreen
	screen.set("scores_path", TEMP_SCORES)
	_screen = screen
	add_child_autofree(_screen)
	await wait_process_frames(1)
	assert_false(_node("Letters").visible)
	assert_true(_node("Table").visible)
	assert_eq(_label("Heading").text, "Top Scores", "with no car to name and no dangling dash")


# ---- what it says ---------------------------------------------------------------


func test_the_score_is_printed_the_way_the_corner_printed_it() -> void:
	await _open(SEDAN, SCORE)
	assert_eq(_label("Score").text, str(SCORE).pad_zeros(ScoreHud.DIGITS))


func test_the_board_names_the_car_it_belongs_to() -> void:
	_fill_the_board(SEDAN)
	await _open(SEDAN, 1)
	assert_true(
		_label("Heading").text.ends_with(CarChoice.label_for(SEDAN)),
		"the board did not say which car it is: %s" % _label("Heading").text
	)


func test_a_run_the_clock_ended_says_so() -> void:
	_fill_the_board(SEDAN)
	await _open(SEDAN, 1)
	assert_true(
		_label("Heading").text.begins_with("Time Up"),
		"a timeout was not reported as one: %s" % _label("Heading").text
	)


func test_a_finished_car_is_not_reported_as_a_timeout() -> void:
	# The one moment the game is actually asking for, and the whole reason
	# RunResult carries which end a run got.
	_fill_the_board(SEDAN)
	await _open(SEDAN, 1, true)
	assert_true(
		_label("Heading").text.begins_with("Car Finished"),
		"finishing the car read as running out of time: %s" % _label("Heading").text
	)


func test_the_board_is_numbered_all_the_way_down() -> void:
	_fill_the_board(SEDAN)
	await _open(SEDAN, 1)
	for place: int in HighScores.KEEP:
		assert_eq(_cell(place, 0).text, "%d" % (place + 1), "the ranks are out of order")


func test_a_board_nobody_has_been_on_draws_ten_empty_places() -> void:
	# Ten places waiting rather than a screen that failed to load — and ten of
	# them, so the second column is drawn as well as the first.
	await _open(SEDAN, 0)
	for place: int in HighScores.KEEP:
		assert_eq(_cell(place, 1).text, "---", "place %d had a name on it" % (place + 1))


# ---- dialling the letters --------------------------------------------------------


func test_up_turns_the_letter_under_the_cursor() -> void:
	await _open(SEDAN, SCORE)
	_button("Up").pressed.emit()
	assert_eq(_spelled(), "BAA")


func test_down_turns_it_the_other_way() -> void:
	await _open(SEDAN, SCORE)
	_button("Down").pressed.emit()
	assert_eq(_spelled()[0], Initials.ALPHABET[Initials.ALPHABET.length() - 1])


func test_next_moves_the_cursor_along() -> void:
	await _open(SEDAN, SCORE)
	_button("Next").pressed.emit()
	_button("Up").pressed.emit()
	assert_eq(_spelled(), "ABA", "Up turned the wrong letter")


func test_next_wraps_back_round_to_the_first_letter() -> void:
	# The whole reason there is no fourth button — see Initials.advance.
	await _open(SEDAN, SCORE)
	for _press: int in Initials.LENGTH:
		_button("Next").pressed.emit()
	_button("Up").pressed.emit()
	assert_eq(_spelled(), "BAA")


# ---- Enter, and what lands on disk ------------------------------------------------


func test_enter_puts_the_board_up() -> void:
	await _open(SEDAN, SCORE)
	_button("Enter").pressed.emit()
	assert_false(_node("Letters").visible)
	assert_false(_node("Keys").visible)
	assert_true(_node("Table").visible)
	assert_true(_node("Exits").visible)


func test_enter_writes_the_initials_that_were_dialled() -> void:
	await _open(SEDAN, SCORE)
	_button("Up").pressed.emit()
	_button("Enter").pressed.emit()
	var table: Array[HighScores.Entry] = HighScores.read_table(SEDAN, TEMP_SCORES)
	assert_eq(table.size(), 1)
	assert_eq(table[0].initials, "BAA")
	assert_eq(table[0].score, SCORE)


func test_the_new_row_is_on_the_board_the_screen_shows() -> void:
	await _open(SEDAN, SCORE)
	_button("Enter").pressed.emit()
	assert_eq(_cell(0, 1).text, Initials.DEFAULT, "the run just handed in is not in first place")
	assert_eq(_cell(0, 2).text, str(SCORE).pad_zeros(ScoreHud.DIGITS))


func test_the_row_the_player_took_is_marked() -> void:
	await _open(SEDAN, SCORE)
	_button("Enter").pressed.emit()
	assert_eq(
		_cell(0, 1).get_theme_color("font_color"),
		Brand.RED,
		"the player cannot tell which of the ten rows is theirs"
	)


func test_the_score_survives_the_screen_being_freed() -> void:
	# The acceptance criterion from the issue, as far as a headless suite can go:
	# a reloaded browser is a fresh process reading the same user:// file, and this
	# is a fresh screen reading it. The IndexedDB half is Settings.sync_web, which
	# is a no-op everywhere this suite runs.
	await _open(SEDAN, SCORE)
	_button("Up").pressed.emit()
	_button("Enter").pressed.emit()
	_screen.free()
	# Re-opened on a run worth nothing, so the board is what is on screen rather
	# than a second prompt — a run that scored nothing never places.
	await _open(SEDAN, 0)
	assert_eq(_cell(0, 1).text, "BAA", "the board did not come back")
	assert_eq(_cell(0, 2).text, str(SCORE).pad_zeros(ScoreHud.DIGITS))


func test_the_board_is_kept_per_car() -> void:
	await _open(SEDAN, SCORE)
	_button("Enter").pressed.emit()
	_screen.free()
	await _open(COUPE, 0)
	assert_eq(_cell(0, 1).text, "---", "the coupe is showing the sedan's board")


# ---- the way out ------------------------------------------------------------------


func test_play_again_asks_for_the_game() -> void:
	_fill_the_board(SEDAN)
	await _open(SEDAN, 1)
	_button("PlayAgain").pressed.emit()
	assert_eq(_requested.size(), 1)
	assert_eq(_requested[0].id, PlayGameState.ID)


func test_main_menu_asks_for_the_menu() -> void:
	_fill_the_board(SEDAN)
	await _open(SEDAN, 1)
	_button("MainMenu").pressed.emit()
	assert_eq(_requested.size(), 1)
	assert_eq(_requested[0].id, MainMenuGameState.ID)


func test_the_theme_comes_back() -> void:
	# The menu's Play faded it out on the way into the game; this is where it
	# returns. See src/screens/job_done.gd.
	await _open(SEDAN, SCORE)
	assert_eq(_music_asked, 1)


# ---- and everything a finger has to hit ---------------------------------------------


func test_every_button_clears_the_tap_target_floor() -> void:
	await _open(SEDAN, SCORE)
	var floor_px: float = TouchTarget.min_design_size()
	for named: String in ["Up", "Down", "Next", "Enter", "MainMenu", "PlayAgain"]:
		var button: Button = _button(named)
		assert_gte(button.custom_minimum_size.x, floor_px, "%s is too narrow to hit" % named)
		assert_gte(button.custom_minimum_size.y, floor_px, "%s is too short to hit" % named)


func test_the_card_fits_the_screen_it_is_drawn_on() -> void:
	# A card taller than the design is a card with its exits off the bottom, which
	# is the one failure this screen cannot recover from: there would be no way out
	# of the game at all.
	_fill_the_board(SEDAN)
	await _open(SEDAN, 1)
	var card: Control = _node("Card")
	assert_lte(card.size.y, _screen.size.y, "the board does not fit on the screen")
	assert_lte(card.size.x, _screen.size.x, "and it is wider than the screen too")


func test_the_prompt_fits_the_screen_it_is_drawn_on() -> void:
	await _open(SEDAN, SCORE)
	var card: Control = _node("Card")
	assert_lte(card.size.y, _screen.size.y, "the initials prompt does not fit on the screen")
	assert_lte(card.size.x, _screen.size.x)


## The type. This card is what issue #174 called the hero use of the display
## face — a score, three letters and a table of ten, which is the whole of what
## an arcade cabinet's last screen is — so unlike every other screen in the game
## there is nothing on it in the reading face.
func test_every_word_on_the_card_is_in_the_display_face() -> void:
	_fill_the_board(SEDAN)
	await _open(SEDAN, SCORE)
	for named: String in ["Heading", "Score", "Up", "Down", "Next", "Enter"]:
		assert_eq(
			_node(named).get_theme_font("font"),
			Brand.DISPLAY_FACE,
			"%s is not in the face the rest of the card is" % named
		)
	for index: int in Initials.LENGTH:
		var letter: Label = _node("Letters").get_child(index) as Label
		assert_eq(letter.get_theme_font("font"), Brand.DISPLAY_FACE, "letter %d" % index)
	for place: int in HighScores.KEEP:
		for column: int in 3:
			assert_eq(
				_cell(place, column).get_theme_font("font"),
				Brand.DISPLAY_FACE,
				"place %d cell %d" % [place, column]
			)


func test_every_size_on_the_card_is_on_the_faces_own_grid() -> void:
	# The board is thirty short strings read as a block and the initials are the
	# biggest type in the game; both are where an uneven stroke shows first.
	await _open(SEDAN, SCORE)
	var row: int = _cell(0, 0).get_theme_font_size("font_size")
	assert_eq(row % Brand.TYPE_GRID, 0, "the board's rows are set at %d, off the grid" % row)
	for named: String in ["Heading", "Score", "Up", "Down", "Next", "Enter"]:
		var size: int = _node(named).get_theme_font_size("font_size")
		assert_eq(size % Brand.TYPE_GRID, 0, "%s is set at %d, off the grid" % [named, size])
	for index: int in Initials.LENGTH:
		var letter: Label = _node("Letters").get_child(index) as Label
		assert_eq(letter.get_theme_font_size("font_size") % Brand.TYPE_GRID, 0, "letter %d" % index)


func test_the_board_columns_hold_the_widest_thing_they_can_ever_hold() -> void:
	# The display face advances a whole em per character, so "widest" is
	# arithmetic rather than a measurement — and that is exactly why it is worth
	# asserting: the widths in job_done.gd are now derived numbers, and a change
	# to ROW_FONT that forgets them clips a rank or a score with no other symptom.
	_fill_the_board(SEDAN)
	await _open(SEDAN, 1)
	var longest: Array[String] = ["10", "AAA", "".lpad(ScoreHud.DIGITS, "0")]
	for column: int in 3:
		var cell: Label = _cell(0, column)
		var ink: float = (
			cell
			. get_theme_font("font")
			. get_string_size(
				longest[column],
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				cell.get_theme_font_size("font_size")
			)
			. x
		)
		assert_lte(
			ink,
			cell.custom_minimum_size.x,
			'column %d cannot hold "%s"' % [column, longest[column]]
		)
