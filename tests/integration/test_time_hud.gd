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
