## Unit tests for [TouchTarget] — the arithmetic behind "big enough to tap".
##
## The number itself is checked where it is used, in
## [code]tests/integration/test_title_screen.gd[/code]. What is checked here is
## that the rule keeps meaning what it says: it follows the project's design
## width, and it lands where hand arithmetic says it should.
extends GutTest


func test_the_design_width_comes_from_the_project() -> void:
	# Not a copy of 1280 kept in the class, which is the failure mode: it would
	# still pass this test's twin everywhere while quietly describing a design
	# the game no longer has.
	var setting: Variant = ProjectSettings.get_setting("display/window/size/viewport_width")
	assert_eq(TouchTarget.design_width(), str(setting).to_float())


func test_the_minimum_is_the_target_scaled_by_the_squeeze() -> void:
	# 48 reference px of finger, a 375 px screen, a 1280 px design: the design
	# is shown at 375/1280 of its size, so 48 on screen needs 48 * 1280/375.
	var expected: float = (
		TouchTarget.MIN_REFERENCE_PX * TouchTarget.design_width() / TouchTarget.NARROWEST_SCREEN_PX
	)
	assert_almost_eq(TouchTarget.min_design_size(), expected, 0.001)


func test_the_minimum_is_around_164_design_px_for_todays_design() -> void:
	# Spelled out, because a formula can be self-consistently wrong. If the base
	# resolution changes this number moves, and that is worth a second look
	# rather than a silent pass.
	assert_almost_eq(TouchTarget.min_design_size(), 163.84, 0.01)


func test_it_asks_for_more_than_a_finger_needs_on_screen() -> void:
	# Sanity, in the direction that matters: the design is scaled *down* on a
	# phone, so the design-space minimum must be larger than the on-screen one.
	assert_gt(TouchTarget.min_design_size(), TouchTarget.MIN_REFERENCE_PX)
