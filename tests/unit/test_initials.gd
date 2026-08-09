## Unit test for [Initials] — the three-letter wheel a cabinet asks for a name
## with.
##
## Under [code]tests/unit/[/code] because none of it needs a [SceneTree]: the
## wheel is a string, a cursor and four verbs. What the buttons and the keyboard
## do with it is [code]tests/integration/test_job_done.gd[/code]'s.
##
## [b]The wrap cases are most of the file, and that is on purpose.[/b] Everything
## interesting about this class is at an edge — the wheel wrapping at Z, the
## cursor wrapping at the third slot, and a name arriving with the wrong number
## of the wrong characters in it. The middle of the range takes care of itself.
extends GutTest

# ---- the alphabet and its two constants ---------------------------------------


func test_the_default_is_the_first_letter_repeated() -> void:
	# The pair the class docs promise, checked rather than trusted: DEFAULT has to
	# be spelled out because a const cannot call `repeat`, so this is what stops
	# the two from drifting.
	assert_eq(Initials.DEFAULT, Initials.FILL.repeat(Initials.LENGTH))
	assert_eq(Initials.DEFAULT.length(), Initials.LENGTH)


func test_the_wheel_starts_where_the_fill_is() -> void:
	assert_eq(Initials.ALPHABET[0], Initials.FILL, "a player who dials nothing gets the fill")


func test_the_alphabet_has_no_blank_in_it() -> void:
	# The one rule that makes two sets of initials comparable by looking at them —
	# see the class docs.
	assert_false(Initials.ALPHABET.contains(" "), "a space would make 'J  ' and 'J ' two players")
	assert_eq(Initials.ALPHABET.length(), 36, "26 letters and 10 digits, and nothing else")


# ---- sanitised: everything that can arrive as a name --------------------------


func test_sanitised_upper_cases() -> void:
	assert_eq(Initials.sanitised("jos"), "JOS")


func test_sanitised_pads_a_short_name() -> void:
	assert_eq(Initials.sanitised("J"), "J" + Initials.FILL.repeat(2))


func test_sanitised_pads_nothing_at_all_to_the_default() -> void:
	assert_eq(Initials.sanitised(""), Initials.DEFAULT)


func test_sanitised_cuts_a_long_name() -> void:
	assert_eq(Initials.sanitised("JOSHUA"), "JOS")


func test_sanitised_drops_what_the_wheel_cannot_spell() -> void:
	# Dropped rather than substituted, so what is left is what the player meant.
	assert_eq(Initials.sanitised("Jo-Sh"), "JOS")


func test_sanitised_keeps_digits() -> void:
	assert_eq(Initials.sanitised("a1b"), "A1B")


func test_sanitised_always_returns_three_spellable_characters() -> void:
	for text: String in ["", "!", "!!!!!!", "j", "JOSHUA", "  ", "éé", "0"]:
		var spelled: String = Initials.sanitised(text)
		assert_eq(spelled.length(), Initials.LENGTH, "%s did not come back three long" % text)
		for character: String in spelled:
			assert_true(Initials.ALPHABET.contains(character), "%s spelled the unspellable" % text)


# ---- index_of -----------------------------------------------------------------


func test_index_of_finds_a_letter() -> void:
	assert_eq(Initials.index_of("A"), 0)
	assert_eq(Initials.index_of("z"), 25, "and it does not care about case")


func test_index_of_rejects_a_character_the_wheel_lacks() -> void:
	assert_eq(Initials.index_of("!"), Initials.NOWHERE)


func test_index_of_rejects_more_than_one_character() -> void:
	# `find` would happily match "ABC" at 0 and report a character that is three.
	assert_eq(Initials.index_of("ABC"), Initials.NOWHERE)
	assert_eq(Initials.index_of(""), Initials.NOWHERE)


# ---- where it starts ----------------------------------------------------------


func test_a_fresh_dial_reads_the_default() -> void:
	var dial: Initials = Initials.new()
	assert_eq(dial.text(), Initials.DEFAULT)
	assert_eq(dial.at(), 0, "and the cursor is on the first letter")


func test_a_dial_can_be_started_from_a_name() -> void:
	assert_eq(Initials.new("zz9").text(), "ZZ9")


func test_a_dial_started_from_rubbish_is_still_spellable() -> void:
	assert_eq(Initials.new("!").text(), Initials.DEFAULT)


# ---- the wheel ----------------------------------------------------------------


func test_stepping_turns_the_letter_under_the_cursor() -> void:
	var dial: Initials = Initials.new()
	dial.step(1)
	assert_eq(dial.text(), "B" + Initials.FILL.repeat(2), "only the first letter moves")


func test_stepping_wraps_off_the_bottom() -> void:
	var dial: Initials = Initials.new()
	dial.step(-1)
	assert_eq(dial.letter(0), Initials.ALPHABET[Initials.ALPHABET.length() - 1])


func test_stepping_wraps_off_the_top() -> void:
	var dial: Initials = Initials.new()
	dial.step(Initials.ALPHABET.length())
	assert_eq(dial.text(), Initials.DEFAULT, "a whole turn is no turn at all")


func test_stepping_follows_the_cursor() -> void:
	var dial: Initials = Initials.new()
	dial.advance()
	dial.step(1)
	assert_eq(dial.text(), "ABA")


# ---- the cursor ---------------------------------------------------------------


func test_the_cursor_walks_along() -> void:
	var dial: Initials = Initials.new()
	dial.advance()
	assert_eq(dial.at(), 1)


func test_the_cursor_wraps_past_the_last_slot() -> void:
	# The whole reason there is no fourth button: three Nexts is where you started.
	var dial: Initials = Initials.new()
	for _press: int in Initials.LENGTH:
		dial.advance()
	assert_eq(dial.at(), 0)


func test_the_cursor_wraps_back_from_the_first_slot() -> void:
	var dial: Initials = Initials.new()
	dial.back()
	assert_eq(dial.at(), Initials.LENGTH - 1)


# ---- typing -------------------------------------------------------------------


func test_typing_sets_the_letter_and_moves_along() -> void:
	var dial: Initials = Initials.new()
	assert_true(dial.type("j"), "a letter the wheel has must take")
	assert_eq(dial.letter(0), "J")
	assert_eq(dial.at(), 1, "typing is 'this one, and I am ready for the next'")


func test_typing_three_letters_spells_a_name() -> void:
	var dial: Initials = Initials.new()
	for character: String in "JOS":
		dial.type(character)
	assert_eq(dial.text(), "JOS")


func test_typing_something_unspellable_changes_nothing() -> void:
	var dial: Initials = Initials.new()
	assert_false(dial.type("!"), "and it says so, so the caller can leave the event alone")
	assert_eq(dial.text(), Initials.DEFAULT)
	assert_eq(dial.at(), 0, "and the cursor stays put")


# ---- reading it back ----------------------------------------------------------


func test_a_slot_that_does_not_exist_reads_as_nothing() -> void:
	var dial: Initials = Initials.new()
	assert_eq(dial.letter(-1), "", "a caller counting wrong is not worth a crash")
	assert_eq(dial.letter(Initials.LENGTH), "")


func test_the_text_is_always_three_characters_long() -> void:
	var dial: Initials = Initials.new()
	for press: int in 40:
		dial.step(press)
		dial.advance()
		assert_eq(dial.text().length(), Initials.LENGTH)
