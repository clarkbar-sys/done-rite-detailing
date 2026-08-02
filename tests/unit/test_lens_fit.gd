## Unit tests for [LensFit] — the trigonometry that keeps a portrait phone from
## being handed a fisheye.
##
## Node-free, so every aspect ratio here is a row in a table rather than a window
## somebody resized. What the numbers actually do to the shot is
## [code]tests/integration/test_play_screen_lens.gd[/code]'s job.
extends GutTest

## The lens the shot is framed at, as [code]garage.tscn[/code] has it.
const DESIGN: float = 75.0

## The ceiling the room ships with.
const CEILING: float = 70.0

## 16:9, the aspect the game is designed at.
const WIDE: float = 1280.0 / 720.0

## A Pixel 7 held upright in a browser, which is the viewport the real complaint
## came from: 411x838 CSS px against a 1280-wide design resolution, stretched
## "expand", lands on 1280x2609.
const TALL: float = 1280.0 / 2609.0

## Degrees, close enough. These are angles for a camera, not a survey.
const TOLERANCE: float = 0.05


func test_a_wide_screen_keeps_the_lens_it_was_framed_at() -> void:
	# The whole promise to the desktop shot: the design lens is already inside the
	# ceiling at 16:9, so nothing moves. A fit that "helpfully" adjusted here would
	# be a silent reframing of a shot nobody asked to change.
	assert_almost_eq(LensFit.horizontal_fov(DESIGN, CEILING, WIDE), DESIGN, TOLERANCE)


func test_the_design_lens_really_is_under_the_ceiling_on_a_wide_screen() -> void:
	# Why the test above passes, stated separately so that a future change to
	# either number fails the reason rather than only the result.
	assert_lt(LensFit.vertical_fov(DESIGN, WIDE), CEILING)


func test_a_tall_screen_gets_a_narrower_lens() -> void:
	assert_lt(LensFit.horizontal_fov(DESIGN, CEILING, TALL), DESIGN)


func test_the_ceiling_is_what_the_tall_screen_is_narrowed_to() -> void:
	# The point of the exercise: the horizontal angle is the thing being set, and
	# the vertical angle is the thing being promised. So assert the promise.
	var fitted: float = LensFit.horizontal_fov(DESIGN, CEILING, TALL)
	assert_almost_eq(LensFit.vertical_fov(fitted, TALL), CEILING, TOLERANCE)


func test_the_uncapped_tall_screen_is_the_fisheye_this_exists_for() -> void:
	# The measured "before" — 114.8° top to bottom on a phone — pinned so the
	# problem cannot quietly stop being a problem.
	assert_almost_eq(LensFit.vertical_fov(DESIGN, TALL), 114.8, 0.1)


func test_the_lens_never_opens_wider_than_the_shot_was_framed_at() -> void:
	# An ultrawide monitor's ceiling would allow a much wider lens than anybody
	# framed anything at. The fit is a rescue, not a licence.
	assert_almost_eq(LensFit.horizontal_fov(DESIGN, CEILING, 21.0 / 9.0), DESIGN, TOLERANCE)


func test_no_ceiling_means_no_change() -> void:
	# Zero is how a caller says "I have no opinion", and it has to be safe: the
	# alternative is a room that exports 0.0 by accident and gets a lens of nothing.
	assert_almost_eq(LensFit.horizontal_fov(DESIGN, 0.0, TALL), DESIGN, TOLERANCE)
	assert_almost_eq(LensFit.horizontal_fov(DESIGN, -10.0, TALL), DESIGN, TOLERANCE)


func test_a_viewport_with_no_shape_leaves_the_shot_alone() -> void:
	# A container that has not been laid out yet reports zero, and a zero aspect
	# would otherwise divide the shot's framing into nonsense. The honest answer to
	# having no measurement is to not move the camera.
	assert_almost_eq(LensFit.horizontal_fov(DESIGN, CEILING, 0.0), DESIGN, TOLERANCE)
	assert_almost_eq(LensFit.vertical_fov(DESIGN, 0.0), DESIGN, TOLERANCE)


func test_the_two_angles_are_inverses_of_each_other() -> void:
	# vertical_fov is the sum horizontal_fov solves, run backwards. If they ever
	# disagree, one of them is wrong and nothing else in this file would say which.
	for aspect: float in [TALL, 1.0, WIDE, 21.0 / 9.0]:
		var vertical: float = LensFit.vertical_fov(DESIGN, aspect)
		# Uncapped by the design lens, so this is the pure round trip: ask for a
		# ceiling the lens already sits exactly at.
		assert_almost_eq(
			LensFit.horizontal_fov(180.0, vertical, aspect),
			DESIGN,
			TOLERANCE,
			"round trip failed at aspect %f" % aspect
		)


func test_a_square_screen_measures_the_same_both_ways() -> void:
	assert_almost_eq(LensFit.vertical_fov(DESIGN, 1.0), DESIGN, TOLERANCE)


func test_the_frame_gets_wider_the_further_out_you_look() -> void:
	# The unit the held tool is placed in — half the visible width at a depth.
	assert_almost_eq(LensFit.half_frame(DESIGN, 0.45), 0.345, 0.001)
	assert_almost_eq(LensFit.half_frame(DESIGN, 0.9), 0.690, 0.001)


func test_a_narrower_lens_sees_less_at_the_same_depth() -> void:
	# Which is why the hand has to move in when the lens narrows: the frame it was
	# placed as a fraction of got smaller.
	var fitted: float = LensFit.horizontal_fov(DESIGN, CEILING, TALL)
	assert_lt(LensFit.half_frame(fitted, 0.45), LensFit.half_frame(DESIGN, 0.45))
