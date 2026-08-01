## Unit tests for [ThumbLift] — the arithmetic behind "the crosshair is not under
## the thumb".
##
## Two separable claims, and they are tested separately because they fail for
## unrelated reasons: that the lift is a constant [i]physical[/i] size whatever
## screen it is asked about, and that the mapping from thumb to aim behaves all
## the way to the top edge of the glass rather than only in the middle.
##
## Whether a lifted press still lands on the car is a question about a camera and
## a raycast, so it is
## [code]tests/integration/test_play_screen_aim.gd[/code]'s and is not repeated
## here.
extends GutTest

## Close enough for a distance in pixels.
const TOLERANCE: float = 0.0001

## A lift to sweep the mapping against. Round, and deliberately not
## [constant ThumbLift.REFERENCE_PX]: these tests are about the shape of the
## curve, and a test that only ever sees the shipping number would keep passing
## if the curve started depending on it.
const LIFT: float = 100.0

## How many samples the sweeps below take across the interesting span. Fine
## enough to catch a kink at the join, coarse enough to stay a unit test.
const SAMPLES: int = 200

## The design width the conversion tests scale against. A copy of
## [method TouchTarget.design_width] on purpose: these are arithmetic tests with
## a worked example in the comments, and one that quietly followed the project
## setting would stop matching the numbers written beside it.
const DESIGN_PX: float = 1280.0

## A portrait phone's screen width in reference pixels — a Pixel 7, the same one
## `project.godot` records measuring the stretch mode on.
const PHONE_REFERENCE_PX: float = 411.0

## And its device pixel ratio, which is the number the web build's window size is
## already multiplied by before Godot ever reports it.
const PHONE_SCALE: float = 2.6


## What the [code]canvas_items[/code] stretch is doing on that phone: its window
## is [constant PHONE_REFERENCE_PX] times [constant PHONE_SCALE] pixels wide, and
## the design is [constant DESIGN_PX], so the design is drawn at this many window
## pixels per design pixel.
func _phone_stretch() -> float:
	return PHONE_REFERENCE_PX * PHONE_SCALE / DESIGN_PX


# ---- a thumb is a thumb, on any screen ---------------------------------------


func test_at_one_to_one_the_lift_is_the_reference_number() -> void:
	# A desktop window at the design resolution with no device pixel ratio: design
	# pixels, window pixels and reference pixels are all the same pixel, so the
	# conversion has nothing to do and must not do anything anyway.
	assert_almost_eq(ThumbLift.design_lift(1.0, 1.0), ThumbLift.REFERENCE_PX, TOLERANCE)


func test_a_squeezed_design_needs_more_design_pixels() -> void:
	# A phone shows the 1280 px design at about a third of its size, so a thumb
	# spans about three times as many design pixels as it does on a desktop. This
	# is the direction that is easy to invert, and inverting it would make the
	# lift shrink on exactly the screens it exists for.
	var squeezed: float = ThumbLift.design_lift(1.0 / 3.0, 1.0)
	assert_almost_eq(squeezed, ThumbLift.REFERENCE_PX * 3.0, TOLERANCE)
	assert_gt(squeezed, ThumbLift.design_lift(1.0, 1.0))


func test_a_hidpi_screen_is_measured_in_its_own_pixels() -> void:
	# The web build's trap, written out as arithmetic. A phone reporting 411
	# reference px wide at a device pixel ratio of 2.6 gives Godot a window 2.6
	# times that many pixels across, which the stretch then scales down to the
	# 1280 px design. The lift has to come out at 1280/411 = 3.11 design px per
	# reference px — which it only does if the ratio is put back.
	#
	# The window width is derived rather than written down: rounding it to a whole
	# pixel first made this fail by a tenth, which is the test being wrong about
	# the phone rather than the class being wrong about the thumb.
	var lifted: float = ThumbLift.design_lift(_phone_stretch(), PHONE_SCALE)
	assert_almost_eq(lifted, ThumbLift.REFERENCE_PX * DESIGN_PX / PHONE_REFERENCE_PX, TOLERANCE)


func test_ignoring_the_screen_scale_would_be_wrong_by_the_ratio() -> void:
	# Stated as a comparison rather than as a number, because this is the bug the
	# parameter exists to prevent: the same phone, computed without its ratio, is
	# short by exactly that ratio and looks perfectly plausible.
	var honest: float = ThumbLift.design_lift(_phone_stretch(), PHONE_SCALE)
	var forgotten: float = ThumbLift.design_lift(_phone_stretch(), 1.0)
	assert_almost_eq(honest, forgotten * PHONE_SCALE, TOLERANCE)


func test_a_screen_that_reports_no_scale_is_taken_at_face_value() -> void:
	# Every desktop, and any browser that answers something below one. "No hidpi"
	# is the reading; "shrink the thumb" is not.
	assert_almost_eq(ThumbLift.design_lift(1.0, 0.5), ThumbLift.REFERENCE_PX, TOLERANCE)
	assert_almost_eq(ThumbLift.design_lift(1.0, 0.0), ThumbLift.REFERENCE_PX, TOLERANCE)


func test_a_stretch_of_nothing_falls_back_instead_of_dividing_by_zero() -> void:
	# Cannot happen in a running game; would be an INF aim if it did.
	assert_almost_eq(ThumbLift.design_lift(0.0, 1.0), ThumbLift.REFERENCE_PX, TOLERANCE)
	assert_almost_eq(ThumbLift.design_lift(-1.0, 1.0), ThumbLift.REFERENCE_PX, TOLERANCE)


# ---- the mapping, in the middle of the glass ---------------------------------


func test_the_aim_sits_a_full_lift_above_the_thumb() -> void:
	var aim: Vector2 = ThumbLift.aim_from(Vector2(400.0, 500.0), LIFT)
	assert_almost_eq(aim.y, 400.0, TOLERANCE)


func test_the_aim_is_directly_above_the_thumb_and_not_beside_it() -> void:
	# The sideways component this class deliberately does not have — see its docs
	# on why guessing at handedness is worse than not guessing.
	var aim: Vector2 = ThumbLift.aim_from(Vector2(400.0, 500.0), LIFT)
	assert_almost_eq(aim.x, 400.0, TOLERANCE)


func test_a_drag_well_clear_of_the_top_moves_the_aim_one_for_one() -> void:
	# The property that makes the offset learnable: away from the top edge the
	# whole mapping is a translation, so the mark tracks the thumb exactly and the
	# player only ever has one constant to internalise.
	var lower: Vector2 = ThumbLift.aim_from(Vector2(0.0, 600.0), LIFT)
	var upper: Vector2 = ThumbLift.aim_from(Vector2(0.0, 550.0), LIFT)
	assert_almost_eq(lower.y - upper.y, 50.0, TOLERANCE)


func test_no_lift_at_all_aims_at_the_finger() -> void:
	assert_almost_eq(ThumbLift.raised(500.0, 0.0), 500.0, TOLERANCE)
	assert_almost_eq(ThumbLift.raised(500.0, -10.0), 500.0, TOLERANCE)


# ---- the mapping, at the top of the glass ------------------------------------


func test_the_aim_never_leaves_the_top_of_the_glass() -> void:
	# The thing a clamp would also give, kept while getting the rest.
	for step: int in SAMPLES:
		var y: float = LIFT * ThumbLift.EASE_SPAN * float(step) / float(SAMPLES - 1)
		assert_between(ThumbLift.raised(y, LIFT), 0.0, y, "a press at y=%.1f" % y)


func test_a_thumb_on_the_top_edge_aims_at_the_top_edge() -> void:
	# There is no screen above it, so meeting the thumb is the only honest answer.
	assert_almost_eq(ThumbLift.raised(0.0, LIFT), 0.0, TOLERANCE)


func test_a_thumb_off_the_top_of_the_glass_does_not_aim_off_it() -> void:
	# Cannot arrive from a [Control] whose rect is the glass; would be a negative
	# aim if it did, and a negative aim projects a ray at nothing above the sky.
	assert_almost_eq(ThumbLift.raised(-50.0, LIFT), 0.0, TOLERANCE)


func test_dragging_toward_the_top_never_moves_the_aim_back_down() -> void:
	# The whole reason this is an ease and not a clamp. A clamp passes every other
	# test in this section and fails this one on every sample inside the strip,
	# because it maps them all to zero — and an aim that stops responding while
	# the thumb is still moving is the failure the player actually notices.
	var previous: float = ThumbLift.raised(0.0, LIFT)
	for step: int in SAMPLES:
		var y: float = LIFT * ThumbLift.EASE_SPAN * float(step + 1) / float(SAMPLES)
		var aim: float = ThumbLift.raised(y, LIFT)
		assert_gt(aim, previous, "a press at y=%.1f moved the aim up from the one below it" % y)
		previous = aim


func test_the_ease_meets_the_translation_without_a_step() -> void:
	# Same value on both sides of the join, which is at [constant
	# ThumbLift.EASE_SPAN] lifts. A seam here is a crosshair that jumps as the
	# thumb crosses an invisible line.
	var join: float = ThumbLift.EASE_SPAN * LIFT
	assert_almost_eq(ThumbLift.raised(join, LIFT), join - LIFT, TOLERANCE)
	assert_almost_eq(ThumbLift.raised(join - 0.001, LIFT), join - LIFT, 0.001)


func test_the_ease_meets_the_translation_without_a_kink() -> void:
	# Same *slope* on both sides, which is the claim [constant
	# ThumbLift.EASE_SPAN] being exactly two buys. Measured as a difference
	# quotient either side of the join: below it the parabola's slope is y/join,
	# which is 1 at the join, and above it the translation's slope is 1.
	var join: float = ThumbLift.EASE_SPAN * LIFT
	var step: float = 0.01
	var below: float = (ThumbLift.raised(join, LIFT) - ThumbLift.raised(join - step, LIFT)) / step
	var above: float = (ThumbLift.raised(join + step, LIFT) - ThumbLift.raised(join, LIFT)) / step
	assert_almost_eq(below, 1.0, 0.01)
	assert_almost_eq(above, 1.0, 0.01)


func test_the_lift_fades_in_across_the_strip_rather_than_arriving_at_once() -> void:
	# Halfway up the strip the thumb has earned a quarter of the lift, not none of
	# it and not all of it: the parabola is y²/(2·join), so at y = join/2 it gives
	# join/8 = lift/4 of aim, which is a gap of join/2 - join/8 = 0.75·lift.
	var join: float = ThumbLift.EASE_SPAN * LIFT
	var gap: float = join * 0.5 - ThumbLift.raised(join * 0.5, LIFT)
	assert_almost_eq(gap, LIFT * 0.75, TOLERANCE)
	assert_lt(gap, LIFT, "the lift is still easing in")
	assert_gt(gap, 0.0, "but it has started")
