## Unit tests for [HighScores] — the board, and the file it survives a closed tab
## in.
##
## The shape of this file mirrors [code]tests/unit/test_settings.gd[/code]
## because the class mirrors [Settings]: the three states a save can be in —
## present, absent and corrupt — and then the round trip. The corrupt case is the
## one that earns its place, for the same reason it does there: losing a board to
## a mangled file is a bad afternoon, and crashing on the way to the menu because
## of one is a broken game.
##
## Every case goes through a throwaway file under [code]user://[/code], never
## [constant HighScores.SCORES_PATH] — a file left behind there is exactly the one
## a real boot would read.
extends GutTest

## Somewhere no test ever writes, so "the file is missing" is a fact and not a
## race with a sibling test's cleanup.
const MISSING_SCORES: String = "user://test_high_scores_no_such_file.json"

## Written and deleted per test — see [method after_each].
const TEMP_SCORES: String = "user://test_high_scores_file.json"

## Two of the ten, so "keyed per car" is a claim about two boards that do not see
## each other rather than about one board with a label on it.
const SEDAN: String = "sedan"
const COUPE: String = "coupe"

## A timestamp, handed in rather than read off a clock — see
## [method HighScores.record]. The number is arbitrary and nothing sorts on it.
const WHEN: int = 1_700_000_000


func after_each() -> void:
	if FileAccess.file_exists(TEMP_SCORES):
		DirAccess.remove_absolute(TEMP_SCORES)


# ---- read_table: the three states a save can be in ----------------------------


func test_an_absent_save_reads_as_an_empty_board() -> void:
	assert_false(FileAccess.file_exists(MISSING_SCORES), "the missing file must stay missing")
	assert_eq(HighScores.read_table(SEDAN, MISSING_SCORES).size(), 0)


func test_a_saved_board_reads_back() -> void:
	HighScores.record(SEDAN, "JOS", 4200, WHEN, TEMP_SCORES)
	var table: Array[HighScores.Entry] = HighScores.read_table(SEDAN, TEMP_SCORES)
	assert_eq(table.size(), 1)
	assert_eq(table[0].initials, "JOS")
	assert_eq(table[0].score, 4200)
	assert_eq(table[0].at, WHEN)


func test_a_mangled_save_reads_as_an_empty_board() -> void:
	# The acceptance criterion from the issue, said as a test: degrade to an empty
	# table, do not crash.
	_write('{"cars": {"sedan": [{"initials": "JOS",')
	assert_eq(HighScores.read_table(SEDAN, TEMP_SCORES).size(), 0)


# ---- parse_table: the shapes JSON can be that aren't a board ------------------


func test_parse_table_reads_a_board() -> void:
	var text: String = '{"cars": {"sedan": [{"initials": "ABC", "score": 900, "at": 7}]}}'
	var table: Array[HighScores.Entry] = HighScores.parse_table(text, SEDAN)
	assert_eq(table.size(), 1)
	assert_eq(table[0].initials, "ABC")


func test_parse_table_rejects_json_that_is_not_an_object() -> void:
	# Valid JSON, wrong shape — what a bare `JSON.parse_string()` would let through.
	assert_eq(HighScores.parse_table("[1, 2, 3]", SEDAN).size(), 0)


func test_parse_table_rejects_a_save_with_no_cars_section() -> void:
	assert_eq(HighScores.parse_table('{"cars": 7}', SEDAN).size(), 0)


func test_parse_table_reads_empty_text_as_an_empty_board() -> void:
	assert_eq(HighScores.parse_table("", SEDAN).size(), 0)


func test_parse_table_skips_rows_that_are_not_rows() -> void:
	# A row with no score in it is not a row; neither is a number, nor a nested
	# list. The one real entry beside them is what makes this test worth anything.
	var text: String = (
		'{"cars": {"sedan": [3, "x", [], {"initials": "NOP"},'
		+ ' {"initials": "YES", "score": 10, "at": 1}]}}'
	)
	var table: Array[HighScores.Entry] = HighScores.parse_table(text, SEDAN)
	assert_eq(table.size(), 1)
	assert_eq(table[0].initials, "YES")


func test_parse_table_defaults_a_row_with_only_a_score() -> void:
	var table: Array[HighScores.Entry] = HighScores.parse_table(
		'{"cars": {"sedan": [{"score": 5}]}}', SEDAN
	)
	assert_eq(table.size(), 1)
	assert_eq(table[0].initials, Initials.DEFAULT, "a row with no name is still a row")
	assert_eq(table[0].at, 0)


func test_parse_table_cleans_the_initials_it_finds() -> void:
	# The save is text on a disk somebody can edit. Nothing that comes off it is
	# allowed onto the board without going through Initials.sanitised.
	var text: String = '{"cars": {"sedan": [{"initials": "j-o-s-h", "score": 5}]}}'
	assert_eq(HighScores.parse_table(text, SEDAN)[0].initials, "JOS")


func test_parse_table_sorts_a_file_that_was_written_out_of_order() -> void:
	var text: String = '{"cars": {"sedan": [{"score": 100}, {"score": 900}, {"score": 500}]}}'
	var table: Array[HighScores.Entry] = HighScores.parse_table(text, SEDAN)
	assert_eq([table[0].score, table[1].score, table[2].score], [900, 500, 100])


func test_parse_table_caps_a_file_with_too_many_rows_in_it() -> void:
	var rows: PackedStringArray = PackedStringArray()
	for index: int in HighScores.KEEP + 5:
		rows.append('{"score": %d}' % (index + 1))
	var text: String = '{"cars": {"sedan": [%s]}}' % ", ".join(rows)
	assert_eq(HighScores.parse_table(text, SEDAN).size(), HighScores.KEEP)


func test_parse_table_reads_a_car_nobody_has_played_as_empty() -> void:
	var text: String = '{"cars": {"sedan": [{"score": 5}]}}'
	assert_eq(HighScores.parse_table(text, COUPE).size(), 0)


# ---- placed: what makes the board ---------------------------------------------


func test_the_first_score_takes_the_top_place() -> void:
	assert_eq(HighScores.placed([], 10), 0)


func test_a_better_score_goes_above() -> void:
	assert_eq(HighScores.placed(_board([100, 50]), 200), 0)
	assert_eq(HighScores.placed(_board([100, 50]), 75), 1)


func test_a_tie_goes_below_the_run_that_got_there_first() -> void:
	# Strictly greater, so replaying the same score cannot climb the board.
	assert_eq(HighScores.placed(_board([100]), 100), 1)


func test_a_run_that_scored_nothing_does_not_place() -> void:
	assert_eq(HighScores.placed([], 0), HighScores.NOT_PLACED)
	assert_eq(HighScores.placed([], -5), HighScores.NOT_PLACED)


func test_a_full_board_turns_a_worse_score_away() -> void:
	var full: Array[HighScores.Entry] = _board(_descending(HighScores.KEEP, 1000))
	assert_eq(HighScores.placed(full, 1), HighScores.NOT_PLACED)
	assert_eq(HighScores.placed(full, 10_000), 0, "but not a better one")


# ---- with_entry: seating a run ------------------------------------------------


func test_with_entry_leaves_the_board_it_was_handed_alone() -> void:
	# A new array rather than an edit in place — the parse loop and the save both
	# call this, and the order of those two should not matter.
	var before: Array[HighScores.Entry] = _board([100])
	HighScores.with_entry(before, HighScores.Entry.new("XYZ", 500, WHEN))
	assert_eq(before.size(), 1, "the argument grew a row")


func test_with_entry_caps_the_board() -> void:
	var full: Array[HighScores.Entry] = _board(_descending(HighScores.KEEP, 1000))
	var seated: Array[HighScores.Entry] = HighScores.with_entry(
		full, HighScores.Entry.new("TOP", 99_999, WHEN)
	)
	assert_eq(seated.size(), HighScores.KEEP, "the board grew past what it keeps")
	assert_eq(seated[0].score, 99_999)


func test_with_entry_refuses_a_run_that_did_not_place() -> void:
	var full: Array[HighScores.Entry] = _board(_descending(HighScores.KEEP, 1000))
	var seated: Array[HighScores.Entry] = HighScores.with_entry(
		full, HighScores.Entry.new("BAD", 1, WHEN)
	)
	assert_eq(seated.size(), HighScores.KEEP)
	assert_eq(seated[HighScores.KEEP - 1].score, full[HighScores.KEEP - 1].score)


# ---- Entry: the suspicious end of the round trip -------------------------------


func test_an_entry_cleans_what_it_is_given() -> void:
	var entry: HighScores.Entry = HighScores.Entry.new("j!", -5, -1)
	assert_eq(entry.initials, "JAA", "initials go through the wheel's own rules")
	assert_eq(entry.score, 0, "a negative score is floored rather than rejected")
	assert_eq(entry.at, 0)


func test_a_row_that_is_not_a_dictionary_is_not_a_row() -> void:
	assert_null(HighScores.Entry.from_json(7))
	assert_null(HighScores.Entry.from_json("JOS"))


func test_a_row_with_no_score_is_not_a_row() -> void:
	assert_null(HighScores.Entry.from_json({"initials": "JOS"}))


func test_a_score_that_came_back_as_a_float_is_still_an_integer() -> void:
	# JSON.parse decodes every number as a float, so this is the arm every score
	# read off disk actually goes through.
	var entry: HighScores.Entry = HighScores.Entry.from_json({"score": 4200.0})
	assert_eq(entry.score, 4200)


func test_a_row_survives_a_round_trip_through_json() -> void:
	var before: HighScores.Entry = HighScores.Entry.new("JOS", 4200, WHEN)
	var after: HighScores.Entry = HighScores.Entry.from_json(
		JSON.parse_string(JSON.stringify(before.to_json()))
	)
	assert_eq([after.initials, after.score, after.at], [before.initials, before.score, before.at])


# ---- record: the write half of the round trip ---------------------------------


func test_record_writes_a_board_that_reads_back() -> void:
	var table: Array[HighScores.Entry] = HighScores.record(SEDAN, "JOS", 4200, WHEN, TEMP_SCORES)
	assert_eq(table.size(), 1, "record hands back the board it saved")
	assert_eq(HighScores.read_table(SEDAN, TEMP_SCORES)[0].score, 4200)


func test_record_keeps_the_other_cars() -> void:
	# The one that would be a silent data loss: nine other boards are in that file.
	HighScores.record(COUPE, "AAA", 100, WHEN, TEMP_SCORES)
	HighScores.record(SEDAN, "BBB", 200, WHEN, TEMP_SCORES)
	assert_eq(HighScores.read_table(COUPE, TEMP_SCORES).size(), 1, "the coupe's board went missing")
	assert_eq(HighScores.read_table(COUPE, TEMP_SCORES)[0].initials, "AAA")


func test_the_boards_are_kept_per_car() -> void:
	HighScores.record(SEDAN, "SED", 5000, WHEN, TEMP_SCORES)
	assert_eq(HighScores.read_table(COUPE, TEMP_SCORES).size(), 0, "the coupe borrowed the sedan's")


func test_record_keeps_a_car_this_build_has_never_heard_of() -> void:
	# What a save written by a newer version looks like. Rewriting only what we
	# understand would delete a board every time somebody opened an older build.
	_write('{"cars": {"hovercraft": [{"initials": "ZZZ", "score": 1}]}}')
	HighScores.record(SEDAN, "JOS", 10, WHEN, TEMP_SCORES)
	assert_eq(HighScores.parse_cars(HighScores.read_text(TEMP_SCORES)).size(), 2)


func test_record_orders_the_board_it_writes() -> void:
	HighScores.record(SEDAN, "LOW", 100, WHEN, TEMP_SCORES)
	HighScores.record(SEDAN, "TOP", 900, WHEN, TEMP_SCORES)
	HighScores.record(SEDAN, "MID", 500, WHEN, TEMP_SCORES)
	var table: Array[HighScores.Entry] = HighScores.read_table(SEDAN, TEMP_SCORES)
	assert_eq([table[0].initials, table[1].initials, table[2].initials], ["TOP", "MID", "LOW"])


func test_record_never_keeps_more_than_the_board_holds() -> void:
	for index: int in HighScores.KEEP + 5:
		HighScores.record(SEDAN, "AAA", index + 1, WHEN, TEMP_SCORES)
	assert_eq(HighScores.read_table(SEDAN, TEMP_SCORES).size(), HighScores.KEEP)


func test_record_over_a_mangled_save_starts_a_fresh_board() -> void:
	_write("{{{ not json")
	HighScores.record(SEDAN, "JOS", 10, WHEN, TEMP_SCORES)
	assert_eq(HighScores.read_table(SEDAN, TEMP_SCORES).size(), 1)


func test_record_now_stamps_the_row_with_the_clock() -> void:
	# The only place the real clock is read. Asserted as "after this suite started"
	# rather than against a value, which is the most a test can honestly say.
	var before: int = roundi(Time.get_unix_time_from_system())
	var table: Array[HighScores.Entry] = HighScores.record_now(SEDAN, "JOS", 10, TEMP_SCORES)
	assert_gte(table[0].at, before)


# ---- helpers -------------------------------------------------------------------


## A board with one row per entry in [param scores], best first — the order
## [method HighScores.with_entry] would have produced anyway.
func _board(scores: Array) -> Array[HighScores.Entry]:
	var table: Array[HighScores.Entry] = []
	for score: int in scores:
		table = HighScores.with_entry(table, HighScores.Entry.new("AAA", score, WHEN))
	return table


## [param count] scores stepping down from [param top], for the "the board is
## full" cases.
func _descending(count: int, top: int) -> Array:
	var scores: Array = []
	for index: int in count:
		scores.append(top - index)
	return scores


func _write(text: String) -> void:
	var file: FileAccess = FileAccess.open(TEMP_SCORES, FileAccess.WRITE)
	assert_not_null(file, "could not write the temp scores file at %s" % TEMP_SCORES)
	if file == null:
		return
	file.store_string(text)
	file.close()
