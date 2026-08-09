## The board: the ten best runs on each of the ten cars, and the file they
## survive a closed tab in.
##
## [b]It is [Settings]' pattern a second time, deliberately.[/b] Same
## [code]user://[/code] home, same "a corrupt save must not fail the boot" rule,
## same [method Settings.sync_web] flush at the end of every write — which on the
## Web export is the whole difference between a score that looks saved and a
## score that is gone on the next reload, because [code]user://[/code] there is
## IndexedDB behind Emscripten's in-memory filesystem and nothing calls
## [code]FS.syncfs[/code] on its own. That flush is [i]called[/i] rather than
## copied: two definitions of "make the write durable" is one of them being wrong
## after the next engine bump.
##
## [b]A file of its own rather than a section of the settings blob.[/b] The two
## are written on completely different events — a setting on a button press, a
## score at the end of a run — and [method Settings.save_muted] writes the whole
## blob every time it is called. Sharing a file would mean the sound toggle
## rewriting the high score table, which is a way to lose a board to a bug in a
## speaker icon.
##
## [b]Keyed per car, because the cars are not the same job.[/b] A wagon has more
## paint on it than a coupe does, so a single global table would be a table of
## which car is biggest with the player's name written next to it —
## [Grime]'s patch counts differ per style and [Scoring] pays per patch. Ten
## boards mean the sports car has a board worth competing on, and it means the
## menu's arrows step through ten sets of records rather than one. The cost is
## that no single number is "the high score", which is the honest position: there
## isn't one.
##
## [b]The order is by score alone, and a tie keeps the older run above.[/b]
## [method placed] takes the first slot the new score is strictly greater than,
## so an equal score lands underneath the run that got there first — the arcade
## rule, and the one that cannot be farmed by replaying the same score to climb.
## The timestamp is therefore [i]recorded[/i] and never sorted on: it is there so
## a board can say when, not so it can break a tie the score already settled.
##
## [b]Nothing here has a [SceneTree] in it and nothing here is an instance.[/b]
## Static, node-free and taking a path everywhere a file is touched, for
## [Settings]' reasons exactly: [code]godot --check-only[/code] resolves global
## class names and not autoload names, and a test has to be able to exercise the
## round trip against a throwaway file rather than the one a real save lives at.
class_name HighScores
extends RefCounted

## Where the board lives. A real file on desktop, IndexedDB on the web — see the
## class docs and [method Settings.sync_web].
const SCORES_PATH: String = "user://high_scores.json"

## How many runs a car remembers. Ten is what a cabinet showed, it is few enough
## that making the board means something on the tenth run rather than the first,
## and it is what [code]src/screens/job_done.tscn[/code] draws in two columns of
## five.
const KEEP: int = 10

## The one key at the top of the save file, under which every car's table sits.
##
## A section rather than the styles being the top-level keys, so the file has
## somewhere to grow: a future "last player's initials" or a format version is a
## sibling of this, where a bare map of styles would have to reserve names that
## could collide with a car.
const KEY_CARS: String = "cars"

## The three keys one row is written with. Named as constants so a typo on either
## side of a read/write is a compile error rather than a silently dropped score —
## the same reason [constant Settings.KEY_MUTED] is one.
const KEY_INITIALS: String = "initials"
const KEY_SCORE: String = "score"
const KEY_AT: String = "at"

## What [method placed] says about a score that does not make the board.
const NOT_PLACED: int = -1


## One run on the board: who, how much, and when.
##
## [b]An object and not the raw dictionary the file holds.[/b] JSON hands back
## [Variant]s, and this project's type gates ([code]unsafe_method_access[/code],
## [code]unsafe_call_argument[/code], both errors) mean every read off a parsed
## dictionary has to be narrowed at the place it happens. Doing that once, here,
## at the boundary, is what lets everything downstream — the sort, the board, the
## screen — be ordinary typed code. [method from_json] is the only place in the
## project that has to be suspicious about what is in the file.
##
## Inner rather than its own file because it has no behaviour of its own worth
## testing apart from the table it lives in, and because a class in
## [code]src/core/[/code] owes STANDARDS.md a unit suite of its own — one for a
## three-field record read through the suite that already covers the table would
## be a file to satisfy a rule rather than a test.
class Entry:
	extends RefCounted
	## Exactly [constant Initials.LENGTH] characters out of
	## [constant Initials.ALPHABET] — guaranteed by the constructor, not hoped
	## for, so nothing downstream has to pad or trim a row to draw it.
	var initials: String = Initials.DEFAULT

	## What the run scored. Never negative: see [method _init].
	var score: int = 0

	## Unix seconds when it was handed in, or zero for a row that never said.
	##
	## Recorded and never sorted on — the class docs have why — so a save with a
	## wrong clock in it produces a board in the right order with one odd date on
	## it, rather than a board in the wrong order.
	var at: int = 0

	## A row for [param who], worth [param points], handed in at [param when].
	##
	## The three arguments are all cleaned here rather than at the call sites,
	## because there are two call sites that matter and they are the two least
	## trustworthy inputs in the feature: a player dialling initials in, and a
	## file somebody edited. A negative score is floored at zero rather than
	## rejected — [method placed] will not seat it either way, and a constructor
	## that could fail would put a null check in front of every use of this.
	func _init(who: String = Initials.DEFAULT, points: int = 0, when: int = 0) -> void:
		initials = Initials.sanitised(who)
		score = maxi(points, 0)
		at = maxi(when, 0)

	## This row as the file writes it.
	func to_json() -> Dictionary:
		return {
			HighScores.KEY_INITIALS: initials,
			HighScores.KEY_SCORE: score,
			HighScores.KEY_AT: at,
		}

	## [param value] read back as a row, or [code]null[/code] for anything that is
	## not one.
	##
	## The suspicious end of the round trip. [param value] is whatever
	## [method JSON.parse] produced for one element of one car's array, which is
	## to say anything at all: a number, a string, a nested array, a dictionary
	## with the wrong keys in it. A row with no score in it is not a row — a
	## player with initials and no points never happened — so that one case is
	## rejected outright and everything else defaults.
	static func from_json(value: Variant) -> Entry:
		if not value is Dictionary:
			return null
		var data: Dictionary = value
		if not data.has(HighScores.KEY_SCORE):
			return null
		return Entry.new(
			HighScores.as_text(data.get(HighScores.KEY_INITIALS, "")),
			HighScores.as_number(data.get(HighScores.KEY_SCORE, 0)),
			HighScores.as_number(data.get(HighScores.KEY_AT, 0))
		)


## The board for [param style], best first, read from the save at [param path].
##
## A missing, unreadable or mangled file is an empty board — see
## [method parse_table]. So is a car nobody has ever finished, and the two are
## the same answer on purpose: "no scores yet" is not an error state.
static func read_table(style: String, path: String = SCORES_PATH) -> Array[Entry]:
	return parse_table(read_text(path), style, path)


## The board for [param style] out of the JSON [param text] of a save file.
##
## Split out from the file read for the reason [method Settings.parse_settings]
## and [method BuildInfo.parse_stamp] are: every shape a save can be wrong in can
## then be tested against a string, with no file anywhere near it.
## [param source] only names the input in the warnings.
##
## [b]The board comes back sorted and capped however the file was written.[/b]
## Rows are seated through [method with_entry] one at a time rather than trusted
## in the order they were stored, so a hand-edited file, a file written by an
## older version that kept a different number, and a file with eleven rows in it
## all read as the same ten rows in the same order. That also quietly drops a
## saved zero, which [method placed] would not have seated in the first place.
static func parse_table(text: String, style: String, source: String = SCORES_PATH) -> Array[Entry]:
	return table_in(parse_cars(text, source), style, source)


## [param style]'s board out of an already-parsed [param cars], which is what
## [method parse_cars] hands back.
##
## The pair exists because [method record] has to read the whole file to keep the
## other nine cars' boards and would otherwise parse the same text twice — once
## for the book and once for the board — which is a second pass and, on a mangled
## save, a second identical warning about it.
static func table_in(cars: Dictionary, style: String, source: String = SCORES_PATH) -> Array[Entry]:
	var table: Array[Entry] = []
	if not cars.has(style):
		return table
	var rows: Variant = cars[style]
	if not rows is Array:
		push_warning("high scores for %s are not a list: %s" % [style, source])
		return table
	var listed: Array = rows
	for row: Variant in listed:
		var entry: Entry = Entry.from_json(row)
		if entry != null:
			table = with_entry(table, entry)
	return table


## Every car's table exactly as the file holds it: style name to raw JSON array,
## nothing narrowed.
##
## [b]Public, and this is the one place the untyped shape is handed out.[/b]
## [method record] needs it, because writing one car's board must not lose the
## other nine — including the boards of cars this build has never heard of, which
## is what a save written by a newer version looks like. Everything else should
## be asking [method parse_table] for a typed board instead.
##
## Anything that is not a JSON object with a [constant KEY_CARS] object in it is
## an empty book plus a warning, which is [method Settings.parse_settings]'
## rule: a mangled save costs the player their scores and must not cost them the
## game. Empty text is the one silent case — a save nobody has written yet reads
## as no scores rather than as a corrupt file.
static func parse_cars(text: String, source: String = SCORES_PATH) -> Dictionary:
	if text.is_empty():
		return {}
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		push_warning("high scores file is not valid JSON: %s" % source)
		return {}
	var parsed: Variant = json.data
	if not parsed is Dictionary:
		push_warning("high scores file is not a JSON object: %s" % source)
		return {}
	var data: Dictionary = parsed
	var cars: Variant = data.get(KEY_CARS, {})
	if not cars is Dictionary:
		push_warning("high scores file has no table of cars in it: %s" % source)
		return {}
	return cars


## Which rank a run scoring [param score] would take on [param table], or
## [constant NOT_PLACED] if it would not make the board at all.
##
## Zero and below never place. A run that earned nothing is a run that did not
## happen — the player pressed Play and finished a car that was already clean, or
## a caller is asking about a score it has not counted yet — and a board with a
## nothing on it is a board with one fewer real row.
##
## Strictly greater, so a tie sits under the run that got there first. The class
## docs have why that is the right way round.
static func placed(table: Array[Entry], score: int) -> int:
	if score <= 0:
		return NOT_PLACED
	for index: int in table.size():
		if score > table[index].score:
			return index
	if table.size() < KEEP:
		return table.size()
	return NOT_PLACED


## [param table] with [param entry] seated in it, or the same table back if it
## did not make the cut.
##
## A new array rather than an edit in place: this is the one operation the whole
## feature is built out of, it is called from a parse loop as well as from a
## save, and a function that quietly rearranged its argument would make the order
## of those two calls matter.
static func with_entry(table: Array[Entry], entry: Entry) -> Array[Entry]:
	var seated: Array[Entry] = []
	seated.append_array(table)
	var rank: int = placed(seated, entry.score)
	if rank == NOT_PLACED:
		return seated
	seated.insert(rank, entry)
	if seated.size() > KEEP:
		seated.resize(KEEP)
	return seated


## Writes a run of [param score] under [param initials] onto [param style]'s
## board as at [param at], and hands back the board it produced.
##
## [b]Read, seat, write — and the read is of the whole file.[/b] Nine other cars'
## boards are in there, and so are any this build does not know about; a save
## that rewrote only what it understood would delete a table every time somebody
## opened an older build. So the untyped book from [method parse_cars] is what
## is written back, with exactly one key replaced.
##
## The clock is handed in rather than read here, which is [method Scoring.score_at]'s
## split and is here for the same reason: a test asserting what lands in the file
## should not have to know what time it is. [method record_now] is the one-line
## wrapper the game calls.
static func record(
	style: String, initials: String, score: int, at: int, path: String = SCORES_PATH
) -> Array[Entry]:
	var cars: Dictionary = parse_cars(read_text(path), path)
	var table: Array[Entry] = with_entry(
		table_in(cars, style, path), Entry.new(initials, score, at)
	)
	var rows: Array = []
	for entry: Entry in table:
		rows.append(entry.to_json())
	cars[style] = rows
	write_text(path, JSON.stringify({KEY_CARS: cars}))
	return table


## The same thing, now. What the game calls; see [method record].
static func record_now(
	style: String, initials: String, score: int, path: String = SCORES_PATH
) -> Array[Entry]:
	return record(style, initials, score, roundi(Time.get_unix_time_from_system()), path)


## The text of the save at [param path], or [code]""[/code] if there isn't one to
## read.
##
## Public because [method record] needs the same read [method read_table] does
## and neither should be opening the file twice by two different routes. A file
## that exists and cannot be opened warns and reads as absent, which is
## [method Settings.read_settings]' answer to the same situation.
static func read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("high scores file exists but could not be opened: %s" % path)
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


## Puts [param text] at [param path] and makes it durable.
##
## [method Settings.sync_web] is the second half and is not optional on the Web
## export — the class docs have why, and it is called rather than reimplemented
## so there is one definition of "flush [code]user://[/code]" in the project.
static func write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("could not write the high scores file: %s" % path)
		return
	file.store_string(text)
	file.close()
	Settings.sync_web()


## Narrows a JSON-decoded [Variant] to [String], defaulting anything else to
## [code]""[/code] — which [method Initials.sanitised] then turns into
## [constant Initials.DEFAULT].
##
## Public only so [Entry] can reach it; the pair below are this file's answer to
## the same problem [method Settings._as_bool] solves, which is that a
## [Dictionary] read out of parsed JSON only ever yields [Variant].
static func as_text(value: Variant) -> String:
	if value is String:
		return value
	return ""


## Narrows a JSON-decoded [Variant] to [int].
##
## [b]Both branches are load-bearing.[/b] [method JSON.parse] decodes every
## number as a [float], so the [code]int[/code] arm is for a value this project
## built rather than read, and the [code]float[/code] arm is for every score that
## ever came back off disk. Rounded rather than truncated, so a score that made a
## round trip through a double comes back as the integer it went in as.
static func as_number(value: Variant) -> int:
	if value is int:
		return value
	if value is float:
		var number: float = value
		return roundi(number)
	return 0
