## Unit tests for [ThumbReach] — the arithmetic behind "a press near the edge of
## the glass walks you, a press in the middle cleans".
##
## Everything the control promises that is not about fingers or scene trees is
## here: that the middle of the screen asks for nothing, that the edge asks for
## everything, that the two are joined by a ramp with no step in it, that the quiet
## region really is a box rather than a circle, and that a corner of the frame is a
## corner rather than a direction asking for 1.41 of itself. Whether a real touch
## reaches any of it is
## [code]tests/integration/test_play_screen_walk.gd[/code]'s job, and whether the
## numbers move a camera is [code]tests/unit/test_orbit_drive.gd[/code]'s — neither
## is repeated here.
extends GutTest

## Close enough for a fraction of full deflection.
const TOLERANCE: float = 0.0001

## A screen to measure against, as half-extents — [ThumbReach] takes half the glass
## because everything it does is measured from the middle outward. Round, wider than
## it is tall like the design is, and deliberately not the shipping size: these are
## arithmetic tests with worked numbers beside them, and a test that only ever saw
## the real resolution would keep passing if the mapping started depending on it.
const HALF: Vector2 = Vector2(500.0, 400.0)

## A minimum band to measure against, and round for the same reason. Chosen to sit
## between the two rules that could take over from it, so that this file measures the
## plain case: above [constant ThumbReach.BAND_FRACTION] of both half-extents, which
## is 125 and 100, and below what would push either axis into
## [constant ThumbReach.MIN_TRIGGER_FRACTION], which is 250 and 200. That is the
## shape the shipping 16:9 design gets, where the floor is what decides. It leaves the
## quiet region 350 x 250 and gives each axis 150 px of travel, so every number can be
## read off by hand. The two rules it steps around are pinned in
## [method test_a_tall_screen_gets_a_band_in_proportion_to_it] and
## [method test_a_short_screen_keeps_a_trigger_in_the_middle_of_it].
const BAND: float = 150.0

## A portrait phone, as half-extents in design pixels, and not a made-up one:
## measured in a real browser at 411x838 CSS px, where `window/stretch/aspect` being
## `expand` makes the viewport 1280 x 2611 design px. The shape the fixed-thickness
## band got wrong.
const PORTRAIT: Vector2 = Vector2(640.0, 1305.5)

## How many samples the ramp sweep takes. Fine enough to catch a step in the middle
## of it, coarse enough to stay a unit test.
const SAMPLES: int = 200

## The corner that walks and lifts at once — the thing four buttons could not say
## and a circle in the corner of the screen could only say at a quarter of the
## reach.
const CORNER: Vector2i = Vector2i(1, 1)


## How far out the quiet region reaches, for [constant HALF] and [constant BAND].
func _quiet() -> Vector2:
	return ThumbReach.trigger_axes(HALF, BAND)


## A point [param reach] px to the right of the middle — the direction with the
## simplest arithmetic, since it puts the whole answer in [code]turn[/code].
func _right(reach: float) -> Vector2:
	return Vector2(reach, 0.0)


func _asked(offset: Vector2) -> Vector2:
	return ThumbReach.input_from(offset, HALF, BAND)


func _steers(offset: Vector2) -> bool:
	return ThumbReach.steers(offset, HALF, BAND)


# ---- where the band is -------------------------------------------------------


func test_the_band_is_the_frame_less_one_band_on_every_side() -> void:
	# The whole layout, in one assertion, because every number below is derived
	# from it: the quiet region is the screen inset by the band, not a fraction of
	# the screen and not a circle inscribed in it.
	assert_almost_eq(_quiet(), HALF - Vector2(BAND, BAND), Vector2.ONE * TOLERANCE)


func test_a_tall_screen_gets_a_band_in_proportion_to_it() -> void:
	# [b]The bug this is here for was found on a phone and could not have been found
	# in this file as it was.[/b] `window/stretch/aspect` is `expand`, so a portrait
	# phone does not letterbox the 16:9 design — it grows the viewport downward, to
	# 1280 x 2611 design px at 411x838 CSS. A band of a fixed 164 design px is then
	# 12.8% of the width and 6.3% of the height: "raise your eye" ended up in a sliver
	# at the top and bottom edges of a tall phone, which is where the browser's own
	# toolbar and its pull-to-refresh live. Turning worked and lifting did not.
	#
	# Proportional fixes it because a quarter of the axis is a quarter of the axis
	# whatever shape the screen is. Asserted as the ratio rather than as 326.375, so
	# it keeps meaning "a quarter of the height" if the constant is retuned.
	var thickness: Vector2 = ThumbReach.band_axes(PORTRAIT, ThumbReach.steer_band())
	assert_almost_eq(
		thickness.y,
		PORTRAIT.y * ThumbReach.BAND_FRACTION,
		TOLERANCE,
		"a tall axis has to give its band room in proportion"
	)
	assert_gt(
		thickness.y,
		ThumbReach.steer_band() * 1.5,
		"and that has to be a real improvement on the fixed thickness, not a rounding"
	)
	# The narrow axis of the same screen is where the floor still does the work: a
	# quarter of 640 is 160, under the 164 a finger needs.
	assert_almost_eq(
		thickness.x, ThumbReach.steer_band(), TOLERANCE, "the floor still holds the short axis up"
	)


func test_the_shipping_design_is_the_case_where_the_floor_decides() -> void:
	# 16:9 at the base resolution, which is what every integration suite presses
	# against. A quarter of 640 is 160 and a quarter of 360 is 90, both under the tap
	# target — so the band is the floor on both axes and the proportional rule changes
	# nothing here. Worth pinning, because it is why adding the fraction did not move
	# a single one of those suites.
	var design: Vector2 = Vector2(TouchTarget.design_width(), 720.0) * 0.5
	var thickness: Vector2 = ThumbReach.band_axes(design, ThumbReach.steer_band())
	assert_almost_eq(
		thickness,
		Vector2.ONE * ThumbReach.steer_band(),
		Vector2.ONE * TOLERANCE,
		"the design resolution is floored on both axes"
	)


func test_a_press_in_the_middle_of_the_glass_cleans_rather_than_walks() -> void:
	# The state the game spends most of its time in, and the one the whole split
	# exists to protect: a press on the car must not move the camera.
	assert_false(_steers(Vector2.ZERO), "the middle of the screen is not a direction")
	assert_eq(_asked(Vector2.ZERO), Vector2.ZERO)


func test_a_press_anywhere_inside_the_quiet_region_asks_for_nothing() -> void:
	# Every direction rather than one, because a boundary applied to the wrong axis
	# would let one corner of the car walk the camera and no other.
	for step: int in 16:
		var towards: Vector2 = Vector2.from_angle(TAU * float(step) / 16.0)
		var inside: Vector2 = Vector2(towards.x * _quiet().x, towards.y * _quiet().y) * 0.99
		assert_false(_steers(inside), "%s is inside the quiet region" % inside)
		assert_eq(_asked(inside), Vector2.ZERO, "%s must ask for nothing" % inside)


func test_the_quiet_region_is_a_box_and_not_a_circle() -> void:
	# The witness for the one place this deliberately does the opposite of what the
	# stick it replaced did. An ellipse inscribed in the same rectangle cuts the
	# corners off the quiet region — this point is a quarter again further out than
	# that ellipse reaches and still comfortably inside the box — and those corners
	# are where the lower flanks of the car sit in frame. A press there has to clean.
	var corner_of_the_box: Vector2 = _quiet() * Vector2(0.875, 0.9)
	assert_false(_steers(corner_of_the_box), "the corners of the box are still the box")
	assert_eq(_asked(corner_of_the_box), Vector2.ZERO)


func test_the_edge_of_the_quiet_region_still_cleans() -> void:
	# Rounded toward the trigger on purpose: the boundary is invisible, and of the
	# two ways to be wrong about it, walking the camera on a press meant for the
	# paint is the one a player would call a bug.
	assert_false(_steers(_right(_quiet().x)), "exactly on the line is inside it")
	assert_true(_steers(_right(_quiet().x + 1.0)), "and a pixel past it is not")


# ---- the ramp, and the edge of the glass -------------------------------------


func test_just_into_the_band_is_the_slowest_ask_there_is() -> void:
	# The bug this pins is the naive version: distance from the middle over half the
	# screen, which has the camera already at four fifths speed the instant a thumb
	# crosses into the band. A control that starts at four fifths speed has no slow
	# setting, and "nudge the shot round a bit" is most of what this is used for.
	var barely: float = _asked(_right(_quiet().x + BAND * 0.01)).x
	assert_gt(barely, 0.0, "crossing into the band must ask for something")
	assert_lt(barely, 0.05, "but only just — it is the start of the ramp, not a step onto it")


func test_a_press_at_the_edge_of_the_glass_asks_for_everything() -> void:
	assert_almost_eq(_asked(_right(HALF.x)).x, ThumbReach.FULL_INPUT, TOLERANCE)


func test_a_thumb_dragged_off_the_glass_still_asks_for_everything() -> void:
	# Reaching for the edge of a phone is exactly how a thumb leaves the screen, so
	# this is the common case rather than the odd one. Falling quiet out there would
	# stop the camera for a movement the player did not mean as a stop.
	var past: Vector2 = _right(HALF.x * 10.0)
	assert_almost_eq(_asked(past).x, ThumbReach.FULL_INPUT, TOLERANCE)


func test_the_ramp_only_ever_goes_up() -> void:
	# The property that makes this feel like a control rather than a switch: further
	# out is never slower. A sweep rather than three points, because the failure it
	# catches — a step, a dip, an overshoot past full — lives between whatever points
	# anybody would have picked.
	var previous: float = -1.0
	for step: int in SAMPLES + 1:
		var reach: float = HALF.x * float(step) / float(SAMPLES)
		var asked: float = _asked(_right(reach)).x
		assert_gte(asked, previous, "the ramp went backwards at %s px" % reach)
		assert_lte(asked, ThumbReach.FULL_INPUT, "and it must never ask for more than full")
		previous = asked


# ---- which way is which ------------------------------------------------------


func test_the_axes_are_the_ones_the_sides_of_the_frame_stand_for() -> void:
	# Y flips between screen space and input space, and a control that got that
	# backwards would be a camera that goes down when the thumb goes up — the
	# mirrored-control bug, invisible to any test that only checks that something
	# moved.
	var up: Vector2 = _asked(Vector2(0.0, -HALF.y))
	assert_almost_eq(up.y, ThumbReach.FULL_INPUT, TOLERANCE, "the top of the glass raises the eye")
	assert_almost_eq(up.x, 0.0, TOLERANCE, "and must not walk you round the car")
	var left: Vector2 = _asked(Vector2(-HALF.x, 0.0))
	assert_almost_eq(left.x, -ThumbReach.FULL_INPUT, TOLERANCE, "the left-hand edge is left")
	assert_almost_eq(left.y, 0.0, TOLERANCE)


func test_one_side_of_the_frame_asks_for_one_axis_and_leaks_into_no_other() -> void:
	# The per-axis ramps have to stay independent, and this is where that could go
	# wrong quietly: a press well into the right-hand band but still inside the
	# quiet region vertically is a pure turn. A shared strength taken from the
	# length of the offset would put a drift in it that nobody asked for.
	var high_in_the_band: Vector2 = Vector2(HALF.x, _quiet().y * 0.99)
	var asked: Vector2 = _asked(high_in_the_band)
	assert_almost_eq(asked.x, ThumbReach.FULL_INPUT, TOLERANCE, "walking at full")
	assert_almost_eq(asked.y, 0.0, TOLERANCE, "and not moving the eye at all")


func test_a_corner_of_the_frame_asks_for_both_at_once_and_for_no_more_than_full() -> void:
	# The reason the band is a border rather than two sliders — and the trap that
	# comes with it. Clamping the components instead of the length would let the
	# corners of the screen ask for 1.41 times what a side can, so the fastest place
	# to press would be the one hardest to reach.
	var asked: Vector2 = _asked(ThumbReach.point_for(CORNER, HALF))
	assert_gt(asked.x, 0.0, "the top-right corner walks you")
	assert_gt(asked.y, 0.0, "and raises your eye")
	assert_almost_eq(asked.length(), ThumbReach.FULL_INPUT, TOLERANCE, "at full, not 1.41")


# ---- naming a place on the glass ---------------------------------------------


func test_full_deflection_is_the_edge_of_the_frame_itself() -> void:
	# The inverse of the mapping, and the thing a caller asking "where is hard
	# right" wants. Y flips here too, for the same reason it does on the way out.
	assert_almost_eq(
		ThumbReach.point_for(ThumbReach.RIGHT, HALF), Vector2(HALF.x, 0.0), Vector2.ONE * TOLERANCE
	)
	assert_almost_eq(
		ThumbReach.point_for(ThumbReach.UP, HALF), Vector2(0.0, -HALF.y), Vector2.ONE * TOLERANCE
	)
	assert_eq(ThumbReach.point_for(Vector2i.ZERO, HALF), Vector2.ZERO, "and nowhere is nothing")


func test_every_side_of_the_frame_has_a_place_a_press_can_land_and_steer() -> void:
	# What the integration tests press, so it has to be a real place in the band on
	# every one of the four sides — and it has to ask for the direction it is named
	# after and for nothing on the other axis.
	for direction: Vector2i in ThumbReach.DIRECTIONS:
		var at: Vector2 = ThumbReach.steer_point(direction, HALF, BAND)
		assert_true(_steers(at), "%s must land in the band" % direction)
		var asked: Vector2 = _asked(at)
		assert_gt(asked.dot(Vector2(direction)), 0.0, "%s must ask to go %s" % [at, direction])
		# The axis the direction leaves alone: a turn with a drift in it is the
		# failure, and it would look like a camera that will not hold a height.
		var across: Vector2 = Vector2(float(direction.y), float(direction.x))
		assert_almost_eq(asked.dot(across), 0.0, TOLERANCE, "%s must ask for nothing else" % at)


# ---- screens the band does not comfortably fit -------------------------------


func test_a_short_screen_keeps_a_trigger_in_the_middle_of_it() -> void:
	# The minimum band is in pixels and the glass is not. A browser window short
	# enough that a band off the top and another off the bottom would meet leaves
	# nothing to aim at and a camera that walks whenever the player touches the car;
	# the floor makes the band the thing that gives way instead.
	var squat: Vector2 = Vector2(500.0, 100.0)
	var quiet: Vector2 = ThumbReach.trigger_axes(squat, BAND * 4.0)
	assert_almost_eq(
		quiet.y,
		squat.y * ThumbReach.MIN_TRIGGER_FRACTION,
		TOLERANCE,
		"the middle of a squashed axis stays a trigger"
	)
	assert_false(
		ThumbReach.steers(Vector2.ZERO, squat, BAND * 4.0), "so the car is still pressable"
	)
	assert_true(
		ThumbReach.steers(Vector2(0.0, -squat.y), squat, BAND * 4.0),
		"and the edge of it still walks you"
	)


func test_a_screen_with_no_size_walks_nobody_anywhere() -> void:
	# Cannot happen in a laid-out screen and would divide by zero if it did — and a
	# NaN steering a camera takes the whole view with it rather than failing where it
	# was made.
	assert_false(ThumbReach.steers(Vector2(10.0, 10.0), Vector2.ZERO, BAND))
	assert_eq(ThumbReach.input_from(Vector2(10.0, 10.0), Vector2.ZERO, BAND), Vector2.ZERO)


func test_a_minimum_of_nothing_still_leaves_a_band_to_steer_with() -> void:
	# The degenerate end of the tuning knob. It used to be that a band set to zero
	# deleted the movement control outright; now the floor is only a floor, so the
	# proportional rule underneath keeps a quarter of each axis whatever anybody types
	# here. Negative is treated as zero rather than as a band that eats into itself.
	for band: float in [0.0, -BAND]:
		assert_almost_eq(
			ThumbReach.band_axes(HALF, band),
			HALF * ThumbReach.BAND_FRACTION,
			Vector2.ONE * TOLERANCE,
			"%s px" % band
		)
		assert_true(
			ThumbReach.steers(_right(HALF.x), HALF, band), "%s px still steers at the edge" % band
		)


func test_the_shipping_band_is_the_size_a_finger_can_actually_hit() -> void:
	# The one number that is not made up in this file. A movement control nobody can
	# reach reads as a game that has frozen, which is the bug [TouchTarget] was
	# written for — and the band inherits it, because the band *is* the control.
	assert_almost_eq(ThumbReach.steer_band(), TouchTarget.min_design_size(), TOLERANCE)
	assert_gt(ThumbReach.steer_band(), 0.0, "a band of nothing would be no control at all")
	# And the fraction has to be small enough to leave a trigger and big enough to be
	# a band, which is the pair of failures either end of it produces.
	assert_gt(ThumbReach.BAND_FRACTION, 0.0, "no fraction is no band on a large screen")
	assert_lt(ThumbReach.BAND_FRACTION, 1.0 - ThumbReach.MIN_TRIGGER_FRACTION, "and no trigger")
