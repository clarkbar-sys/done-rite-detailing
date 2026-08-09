## Integration test for [ScoreHud] — the digits in the top-right corner, the
## flash that ties them to the ding, and the [code]+250[/code] that lifts off
## them.
##
## In tests/integration/ rather than tests/unit/ because the thing under test is
## a [Control] with children, a [method Node._process] driving three animations
## and a layout that reads the viewport — none of which exists without a
## [SceneTree]. The arithmetic it is drawing is [Scoring]'s and is unit-tested
## there; nothing here re-asserts a point value.
##
## [b]What is worth pinning is the wiring and the timing, not the taste.[/b] How
## bright the flash is, how far a pop rises and what colour a wash throws are
## numbers somebody will turn the first time they see this move. What cannot
## drift is that a score is reachable at all — the digits do arrive at the total
## rather than easing towards it forever, the flash does go out rather than
## staying lit, and a pop does retire rather than accumulating until the pool is
## permanently full. Each of those three failures looks like a tuning problem and
## is not.
##
## The frames are waited for rather than faked. [method ScoreHud._process] is
## driven by the engine's delta and there is no seam to hand a clock through,
## which is a deliberate difference from [Scoring]: the run has to be assertable
## without waiting a second and a half, and a fade does not — everything here
## finishes inside a second.
extends GutTest

const HUD: String = "res://src/ui/score_hud.tscn"

## Long enough for the roll, the flash and a pop to have finished — the longest
## of the three is [constant ScoreHud.POP_SECONDS].
const SETTLE_SECONDS: float = 1.0

## How long a test that watches the flash all the way down will wait for it
## before giving up. A hang guard rather than a duration: the fade itself is
## [constant PatchFlash.SECONDS], and anything past this many milliseconds means
## it is not fading at all.
const FADE_TIMEOUT_MSEC: int = 3000

## A six-figure score, for the one case where "the digits have arrived" and "the
## digits are on the total" come apart on purpose rather than by luck of the
## frame. See [method ScoreHud._process] and the test at the bottom of this file.
const BIG_SCORE: int = 200_000

var _hud: ScoreHud = null


func before_each() -> void:
	var packed: PackedScene = load(HUD) as PackedScene
	assert_not_null(packed, "could not load %s" % HUD)
	if packed == null:
		return
	_hud = packed.instantiate() as ScoreHud
	assert_not_null(_hud, "%s is not a ScoreHud" % HUD)
	add_child_autofree(_hud)
	await wait_process_frames(1)


## Scores one wash worth [param award], bringing the total to [param total].
func _award(total: int, award: int, multiplier: int = 1) -> void:
	_hud.score(total, award, GrimeMap.Stage.WASHED, multiplier)


func test_starts_at_nothing() -> void:
	assert_eq(_hud.total(), 0, "a fresh scoreboard is not at zero")
	assert_eq(_hud.shown(), 0, "and its digits do not read zero")
	assert_eq(_hud.flash(), 0.0, "and it is lit before anything happened")
	assert_eq(_hud.flying(), 0, "and something is already in the air")


func test_an_award_lands_on_the_total_at_once() -> void:
	_award(1000, 1000)
	assert_eq(_hud.total(), 1000, "the target did not take the award")


func test_the_digits_roll_rather_than_jump() -> void:
	_award(10_000, 10_000)
	await wait_process_frames(1)
	assert_lt(_hud.shown(), 10_000, "the digits arrived on the first frame")
	assert_gt(_hud.shown(), 0, "the digits did not move at all")


## The one that matters: an eased roll that never quite arrives leaves a score
## permanently a few points light, which reads as the scorer being wrong.
func test_the_digits_do_arrive() -> void:
	_award(12_345, 12_345)
	await wait_seconds(SETTLE_SECONDS)
	assert_eq(_hud.shown(), 12_345, "the digits never caught up with the total")


## An award landing mid-roll retargets rather than stacking two rolls.
func test_a_second_award_mid_roll_still_arrives() -> void:
	_award(10_000, 10_000)
	await wait_process_frames(2)
	_award(20_000, 10_000)
	await wait_seconds(SETTLE_SECONDS)
	assert_eq(_hud.shown(), 20_000, "the digits lost the second award")


func test_an_award_lights_the_flash() -> void:
	_award(100, 100)
	assert_almost_eq(_hud.flash(), 1.0, 0.001, "an award did not light the score")


func test_the_flash_goes_out() -> void:
	_award(100, 100)
	await wait_seconds(SETTLE_SECONDS)
	assert_eq(_hud.flash(), 0.0, "the score stayed lit")


## The tie the feature is for: the corner and the square on the car fade over one
## constant, so a score still lit after its patch has gone dark cannot happen by
## somebody tuning one of the two.
func test_the_flash_fades_over_the_same_time_the_patch_does() -> void:
	_award(100, 100)
	await wait_seconds(PatchFlash.SECONDS + 0.05)
	assert_eq(_hud.flash(), 0.0, "the score outlasted the square that rang with it")


func test_an_award_puts_a_pop_in_the_air() -> void:
	_award(250, 250)
	assert_eq(_hud.flying(), 1, "an award did not throw a number")


func test_a_pop_comes_back_down() -> void:
	_award(250, 250)
	await wait_seconds(SETTLE_SECONDS)
	assert_eq(_hud.flying(), 0, "a pop never retired")


## A sweep of the jet finishes patches faster than a pop lives, so the pool has
## to wrap rather than grow — and it has to still be usable afterwards.
func test_a_burst_past_the_pool_wraps_rather_than_grows() -> void:
	for index: int in ScoreHud.POPS * 3:
		_award((index + 1) * 100, 100)
	assert_eq(_hud.flying(), ScoreHud.POPS, "the pool of pops is not the size it says it is")
	await wait_seconds(SETTLE_SECONDS)
	assert_eq(_hud.flying(), 0, "a wrapped pool never emptied")
	_award(9_999, 100)
	assert_eq(_hud.flying(), 1, "the pool stopped working after it wrapped")


func test_the_multiplier_is_hidden_at_one_and_shown_above_it() -> void:
	_award(100, 100, 1)
	assert_false(_hud.run_shown(), "a multiplier of one is being printed")
	_award(300, 200, 2)
	assert_true(_hud.run_shown(), "a real multiplier is not being printed")


## Three passes, three colours, and no two of them the same — the corner has to
## be able to say which pass paid.
func test_each_stage_throws_its_own_colour() -> void:
	var wash: Color = ScoreHud.tint_for(GrimeMap.Stage.WASHED)
	var foam: Color = ScoreHud.tint_for(GrimeMap.Stage.FOAMED)
	var buff: Color = ScoreHud.tint_for(GrimeMap.Stage.BUFFED)
	assert_ne(wash, foam, "a wash and a foam flash the same colour")
	assert_ne(foam, buff, "a foam and a buff flash the same colour")
	assert_ne(wash, buff, "a wash and a buff flash the same colour")


## The near-white product case the class docs are about: the resting colour has
## to be far enough off the foam tint for that flash to read at all. Measured as
## a distance rather than as an exact pair of colours, so retuning either end
## stays free and closing the gap does not.
func test_the_foam_flash_is_visible_against_the_resting_colour() -> void:
	var foam: Color = ScoreHud.tint_for(GrimeMap.Stage.FOAMED)
	var apart: float = absf(foam.get_luminance() - Brand.MUTED.get_luminance())
	assert_gt(apart, 0.1, "the foam flash is too close to the resting colour to see")


# ---- the quiet half: work coming in between events ---------------------------


func test_a_tick_moves_the_digits_without_an_event() -> void:
	_hud.tick(750)
	assert_eq(_hud.total(), 750, "a tick did not reach the target")
	await wait_seconds(SETTLE_SECONDS)
	assert_eq(_hud.shown(), 750, "the digits never caught up with a tick")


## The whole reason [method ScoreHud.tick] exists rather than reusing
## [method ScoreHud.score]: a jet running is a tick on every frame, and a flash
## on every frame is a readout that is permanently lit.
func test_a_tick_does_not_flash_or_pop() -> void:
	_hud.tick(750)
	assert_eq(_hud.flash(), 0.0, "a tick lit the score")
	assert_eq(_hud.flying(), 0, "a tick threw a number")


## What a held trigger actually looks like: a small tick every frame, for a
## while. The digits must track it and then land on it.
func test_a_trickle_every_frame_is_tracked_and_lands() -> void:
	var total: int = 0
	for _frame: int in 30:
		total += 40
		_hud.tick(total)
		await wait_process_frames(1)
	assert_gt(_hud.shown(), 0, "the digits never moved under a trickle")
	await wait_seconds(SETTLE_SECONDS)
	assert_eq(_hud.shown(), total, "the digits never caught up with the trickle")


## A point added to a six-figure score has to arrive, and the reason it might not
## has no float luck in it at all.
##
## [code]#183[/code] took [method @GlobalScope.is_equal_approx] out of
## [method ScoreHud._process]'s arrival test, and the trickle case above is what
## found it: at 1,200 the tolerance is 0.012, so the bug needs the last step of
## the roll to land inside a hundredth of the target, which is a thing one
## frame's delta decides. That is a real case and a poor guard — it passed on its
## own and failed behind a heavier suite.
##
## This is the same bug with the luck taken out. The tolerance is proportional,
## so at 200,000 it is 2.0 and a single-point tick is inside it from the first
## frame: the roll is declared arrived before it has moved, and the point is
## swallowed outright rather than landing a hundredth short. Nothing here depends
## on a delta, so it fails on the old comparison every time.
func test_a_point_on_a_six_figure_score_still_arrives() -> void:
	_hud.tick(BIG_SCORE)
	await wait_seconds(SETTLE_SECONDS)
	assert_eq(_hud.shown(), BIG_SCORE, "the digits never reached the big total")
	_hud.tick(BIG_SCORE + 1)
	await wait_seconds(SETTLE_SECONDS)
	assert_eq(_hud.shown(), BIG_SCORE + 1, "a point on a six-figure score went missing")
	assert_eq(_hud.total(), BIG_SCORE + 1, "and the readout disagrees with the score")


## A patch landing mid-trickle still gets its flash and its pop — the two halves
## share a readout and the quiet one must not swallow the loud one.
func test_an_award_during_a_trickle_still_flashes() -> void:
	_hud.tick(500)
	await wait_process_frames(1)
	_award(750, 250)
	assert_almost_eq(_hud.flash(), 1.0, 0.001, "an award mid-trickle did not light the score")
	assert_eq(_hud.flying(), 1, "an award mid-trickle threw no number")
	await wait_seconds(SETTLE_SECONDS)
	assert_eq(_hud.shown(), 750, "the digits lost the award that landed mid-trickle")


## Nothing in the corner may take a press: the play screen reads aims out of
## `_gui_input`, so a control at `stop` here is a piece of the car that cannot be
## pointed at. Checked over every descendant rather than the root alone, because
## the pops are built in code and a filter left off one of them is exactly the
## kind of thing a screenshot cannot show.
func test_nothing_in_the_corner_can_be_pressed() -> void:
	_award(100, 100)
	for node: Node in _hud.find_children("*", "Control", true, false):
		var control: Control = node as Control
		assert_eq(
			control.mouse_filter,
			Control.MOUSE_FILTER_IGNORE,
			"%s would swallow a press meant for the car" % control.name
		)
	assert_eq(_hud.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the scoreboard itself stops presses")


## The type. This corner is the hero use of the display face — issue #174's
## words — and it is also the only place in the game where a font size is
## computed at runtime rather than written in a scene file, which is where the
## pixel grid can quietly stop being true.
func test_every_row_of_the_corner_is_in_the_display_face() -> void:
	_award(100, 100)
	for node: Node in _hud.find_children("*", "Label", true, false):
		var label: Label = node as Label
		assert_eq(
			label.get_theme_font("font"),
			Brand.DISPLAY_FACE,
			"%s is not in the face the rest of the score is" % label.name
		)


func test_every_resting_size_is_on_the_faces_own_grid() -> void:
	# A size off the grid gives some of a digit's strokes three screen pixels and
	# others four — see Brand.crisp. That is a thing to get wrong once, in a diff
	# where somebody nudges a readout by two, and it sits in the corner of every
	# frame of the game afterwards.
	for size: int in [
		ScoreHud.TOTAL_FONT, ScoreHud.RUN_FONT, ScoreHud.DONE_FONT, ScoreHud.POP_FONT
	]:
		assert_eq(size % Brand.TYPE_GRID, 0, "%d is not a multiple of the type grid" % size)


func test_the_punch_steps_between_two_grid_sizes_and_never_lands_between_them() -> void:
	# The flash punches the total larger and fades back over PatchFlash.SECONDS,
	# so the size is recomputed on every frame of the fade. Sampled across a whole
	# fade rather than at its two ends, because the failure this pins is a frame
	# in the middle at 61 px.
	#
	# Driven by the flash rather than by a frame count, and that is not fussiness:
	# `_process` runs on the engine's own delta, and a headless run has no vsync
	# to pace it — thirty frames is half a second on a monitor and a few
	# milliseconds here, which would sample the punch and never see it come back
	# down. The deadline is a hang guard, not the exit.
	var total: Label = _hud.get_node("%Total") as Label
	var seen: Dictionary[int, bool] = {}
	var deadline: int = Time.get_ticks_msec() + FADE_TIMEOUT_MSEC
	_award(1000, 1000)
	while _hud.flash() > 0.0 and Time.get_ticks_msec() < deadline:
		seen[total.get_theme_font_size("font_size")] = true
		await wait_process_frames(1)
	seen[total.get_theme_font_size("font_size")] = true
	assert_eq(_hud.flash(), 0.0, "the flash never went out, so the fade was never sampled")
	for size: int in seen:
		assert_eq(size % Brand.TYPE_GRID, 0, "the punch drew the total at %d px" % size)
	assert_true(
		seen.has(Brand.crisp(roundi(float(ScoreHud.TOTAL_FONT) * (1.0 + ScoreHud.PUNCH)))),
		"the punch never reached the size above the resting one"
	)
	assert_true(seen.has(ScoreHud.TOTAL_FONT), "the punch never came back down")


func test_the_widest_reading_still_fits_the_column_it_is_right_aligned_in() -> void:
	# The display face advances a whole em per character, so six digits are
	# exactly 6 x size wide — which is how the old 76 px total came to be 456 px
	# inside a 426 px column, and why this is a test rather than a comment.
	#
	# The column is a third of the screen (`_row_width` in score_hud.gd) and the
	# screen is the design width, read off project.godot rather than typed here
	# for TouchTarget.design_width's reason. The `/ 3.0` is transcribed and is
	# meant to be: a test that asked the HUD for its own answer would agree with
	# it however wrong it was.
	var punched: int = Brand.crisp(roundi(float(ScoreHud.TOTAL_FONT) * (1.0 + ScoreHud.PUNCH)))
	var widest: float = (
		Brand
		. DISPLAY_FACE
		. get_string_size("".lpad(ScoreHud.DIGITS, "0"), HORIZONTAL_ALIGNMENT_LEFT, -1, punched)
		. x
	)
	assert_lte(
		widest,
		TouchTarget.design_width() / 3.0,
		"a full score at full punch is wider than the column it sits in"
	)


## A game nobody is playing costs nothing to draw. Not a benchmark — the early
## out in [method ScoreHud._process] is the thing being pinned, and the way it
## shows is that a settled scoreboard stays settled.
func test_a_settled_scoreboard_stays_where_it_is() -> void:
	_award(500, 500)
	await wait_seconds(SETTLE_SECONDS)
	var settled: int = _hud.shown()
	await wait_process_frames(5)
	assert_eq(_hud.shown(), settled, "an idle scoreboard drifted")
	assert_eq(_hud.flash(), 0.0, "an idle scoreboard re-lit itself")


## The done percentage — [method Grime.shine] printed in the corner, and the only
## number on this HUD that is true continuously rather than at a moment.
##
## Its own group of tests rather than folded in above, because everything it is
## checked against is different: it does not roll, does not flash and does not
## pop, and the one thing that could go wrong with it is the rounding.
func test_the_done_readout_starts_at_nothing() -> void:
	assert_eq(_hud.done_shown(), 0, "a car nobody has touched is not partly done")


func test_the_done_readout_follows_the_shine() -> void:
	_hud.done(0.42)
	assert_eq(_hud.done_shown(), 42)
	_hud.done(1.0)
	assert_eq(_hud.done_shown(), 100, "a finished car does not read a hundred")


func test_the_done_readout_rounds_down_so_a_hundred_means_finished() -> void:
	# The one lie a progress number must not tell. At 99.6% the last patch is still
	# muddy, and a readout that had rounded to "100% done" would be telling the
	# player to stop.
	_hud.done(0.996)
	assert_eq(_hud.done_shown(), 99)


func test_the_done_readout_takes_a_number_out_of_range_without_complaint() -> void:
	# Fed off a running total once a frame, so a float that has drifted a
	# ten-thousandth past one is a thing that happens rather than a bug to crash on.
	_hud.done(1.0001)
	assert_eq(_hud.done_shown(), 100, "past the end")
	_hud.done(-0.0001)
	assert_eq(_hud.done_shown(), 0, "and before the start")


func test_the_done_readout_survives_being_told_the_same_thing_every_frame() -> void:
	# Which is what the play screen does: it is polled, not signalled, so this is
	# called sixty times a second with the same number for as long as nobody is
	# cleaning. The early out is what stops that being sixty strings a second.
	_hud.done(0.5)
	for _frame: int in 30:
		_hud.done(0.5)
	assert_eq(_hud.done_shown(), 50)
