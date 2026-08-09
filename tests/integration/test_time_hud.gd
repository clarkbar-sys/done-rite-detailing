## Integration test for [TimeHud] — the clock along the top of the play screen.
##
## Under [code]tests/integration/[/code] because it is a [Label] and needs a
## [SceneTree] to have a theme to read back out of. What the numbers mean is
## [code]tests/unit/test_run_clock.gd[/code]'s; what this asserts is that the
## right one is printed, in the right colour, and not rebuilt sixty times a
## second to say the same thing.
##
## Built directly rather than instanced from a scene, because there is no scene:
## it is a [Label] subclass carrying its own presentation, the shape
## [SoundToggle] and [CarArrow] already use. See its class docs.
extends GutTest

var _hud: TimeHud = null


func before_each() -> void:
	_hud = TimeHud.new()
	add_child_autofree(_hud)


func test_it_opens_on_the_whole_run() -> void:
	# Drawn full in `_ready`, so the clock does not appear a frame after the room.
	assert_eq(_hud.text, RunClock.spell(RunClock.SECONDS))
	assert_eq(_hud.shown(), RunClock.whole_seconds(RunClock.SECONDS))


func test_it_prints_the_time_it_is_handed() -> void:
	_hud.show_time(65.0)
	assert_eq(_hud.text, "1:05")


func test_it_rests_in_the_muted_ink() -> void:
	_hud.show_time(RunClock.SECONDS)
	assert_eq(_hud.get_theme_color("font_color"), TimeHud.RESTING)


func test_it_goes_to_the_accent_for_the_last_of_the_run() -> void:
	_hud.show_time(RunClock.WARNING_SECONDS)
	assert_eq(_hud.get_theme_color("font_color"), TimeHud.WARNING)


func test_it_is_still_resting_a_second_before_the_warning() -> void:
	_hud.show_time(RunClock.WARNING_SECONDS + 1.0)
	assert_eq(_hud.get_theme_color("font_color"), TimeHud.RESTING)


func test_it_stays_lit_once_the_time_is_up() -> void:
	_hud.show_time(RunClock.UP)
	assert_eq(_hud.text, "0:00")
	assert_eq(_hud.get_theme_color("font_color"), TimeHud.WARNING)


func test_a_frame_that_does_not_change_the_second_does_not_redraw() -> void:
	# The early-out the class docs are about: the screen hands this a float every
	# frame and fifty-nine of every sixty say the same thing.
	_hud.show_time(65.0)
	_hud.show_time(64.9)
	assert_eq(_hud.shown(), 65, "the reading moved on a frame that changed nothing")
	_hud.show_time(64.0)
	assert_eq(_hud.shown(), 64)


func test_a_run_with_no_clock_on_it_reads_as_the_sign() -> void:
	# The simulation's readout. Nothing in TimeHud knows the mode exists — it is
	# handed RunClock.UNTIMED like any other float and prints whatever the clock
	# spells it as.
	_hud.show_time(RunClock.UNTIMED)
	assert_eq(_hud.text, RunClock.FOREVER_SIGN)
	assert_eq(_hud.shown(), RunClock.FOREVER)


func test_the_sign_is_not_a_warning() -> void:
	# A clock that never runs out is never nearly out, so it rests in the muted
	# ink for the whole run rather than sitting red on a screen with no red on it.
	_hud.show_time(RunClock.UNTIMED)
	assert_eq(_hud.get_theme_color("font_color"), TimeHud.RESTING)


func test_the_sign_draws_once_rather_than_once_a_frame() -> void:
	# The early-out below, at the one reading that is handed over every frame of
	# an untimed run and never changes. It is also the collision the sentinel
	# moved for: FOREVER is -1 and "nothing printed yet" used to be too, so a
	# readout that compared them would have drawn the sign never rather than once.
	_hud.show_time(RunClock.UNTIMED)
	assert_eq(_hud.shown(), RunClock.FOREVER)
	assert_ne(TimeHud.NOTHING_YET, RunClock.FOREVER, "the two sentinels must differ")


func test_the_readout_can_go_from_the_sign_back_to_a_number() -> void:
	# Unreachable in the game — a run does not change mode halfway — and asserted
	# because the early-out is a cache and a cache that cannot be invalidated in
	# one direction is a bug waiting for the first caller that tries.
	_hud.show_time(RunClock.UNTIMED)
	_hud.show_time(65.0)
	assert_eq(_hud.text, "1:05")


func test_the_face_can_actually_draw_the_sign() -> void:
	# The same bug tests/integration/test_main_menu.gd pins about the credit's
	# curly quotes: a glyph the face does not have is a tofu box in a released
	# build rather than an error anybody would see. This is the one character in
	# the game's own copy that is not ASCII, and it is on screen for every frame
	# of every simulation run.
	var font: Font = _hud.get_theme_font("font")
	for index: int in RunClock.FOREVER_SIGN.length():
		var glyph: int = RunClock.FOREVER_SIGN.unicode_at(index)
		assert_true(
			font.has_char(glyph),
			"the clock wants U+%04X, which %s cannot draw" % [glyph, font.get_font_name()]
		)


func test_nothing_under_it_can_be_pressed_through() -> void:
	# Load-bearing rather than tidy: the play screen reads aims out of _gui_input,
	# so a readout that stopped a press would be a rectangle of the windscreen the
	# player cannot point a tool at.
	assert_eq(_hud.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_it_is_drawn_with_an_edge_on_it() -> void:
	# What is behind the top of the play screen is sometimes sky and sometimes
	# tarmac, and type with no outline disappears into one of them.
	assert_eq(_hud.get_theme_constant("outline_size"), TimeHud.OUTLINE)
	assert_eq(_hud.get_theme_font_size("font_size"), TimeHud.FONT)


## The clock and the score are the two numbers of a run, so they are one
## decision: same face, same size. The size is asserted as an identity rather
## than as a number because that is the bug it is for — TimeHud.FONT was a
## copied 76 and stayed there when #174 moved the score to 56, which is two
## constants meant to be equal disagreeing within a commit of being written.
func test_the_clock_matches_the_score_it_sits_opposite() -> void:
	assert_eq(
		_hud.get_theme_font("font"),
		Brand.DISPLAY_FACE,
		"the clock must be in the face the score is"
	)
	assert_eq(
		_hud.get_theme_font_size("font_size"),
		ScoreHud.TOTAL_FONT,
		"the clock and the score must be the same size"
	)
	assert_eq(TimeHud.FONT % Brand.TYPE_GRID, 0, "and that size must be on the face's own grid")
