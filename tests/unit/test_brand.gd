## Unit tests for [Brand].
##
## Under tests/unit/ because a [StyleBoxFlat] is a [Resource]: every shape the
## brand is made of can be built and measured with no window, no tree and no
## frame. That is the whole reason the palette lives in [code]src/core/[/code]
## and not in a [code].tscn[/code].
##
## Two kinds of assertion here, and they are worth telling apart. The colour
## tests are a [b]transcription[/b] gate — they hold this file to the hex codes
## in the site's stylesheet, so a colour drifting is a failing test rather than
## a screen that quietly stops matching the business it is named after. The
## shape tests are a [b]behaviour[/b] gate: they are what makes "the pill is a
## pill" and "the focus ring does not erase the press" checkable claims.
##
## The contrast tests at the bottom are both at once. The ratio itself is
## transcribed — three fixed points of the WCAG definition, so the arithmetic is
## held to a standard somebody else published rather than to itself — and the
## badge tints are behaviour, measured against the real catalogue: a sixth tool
## in a colour nobody can see fails here rather than on a phone.
extends GutTest

## The site's `:root` block, transcribed a second time, on purpose — reading
## the constant under test to check the constant under test would assert
## nothing. Source: https://bespoke-cascaron-816d86.netlify.app
const CSS: Dictionary = {
	"red": "e21b23",
	"red_dark": "a90f16",
	"panel": "141418",
	"muted": "b9b9c1",
	"white": "ffffff",
	"black": "09090b",
}

## A button height to build pills at. The real one is 176 — see
## [TouchTarget] for where that number comes from — but nothing in [Brand]
## should care, so this is deliberately not that number.
const HEIGHT: float = 120.0

## Heights to build a pill at: the smallest tappable thing on any platform's
## guideline, the arbitrary one above, and the size Start actually is. Typed,
## because an untyped literal hands the loop a [Variant] and this project's
## gates reject the arithmetic that follows.
const HEIGHTS: Array[float] = [48.0, HEIGHT, 176.0]

## A badge to build plates at. The real one is a tap target — 164 design px, see
## [TouchTarget] — but nothing in [Brand] should care, so this is deliberately
## not that number either.
const BADGE_SIDE: float = 100.0


func test_the_palette_is_the_sites_palette() -> void:
	assert_eq(Brand.RED.to_html(false), CSS["red"], "the accent must be the site's --red")
	assert_eq(Brand.RED_DARK.to_html(false), CSS["red_dark"], "the pressed pill must be --red-dark")
	assert_eq(Brand.PANEL.to_html(false), CSS["panel"], "a card must be filled with --panel")
	assert_eq(Brand.MUTED.to_html(false), CSS["muted"], "secondary type must be --muted")
	assert_eq(Brand.WHITE.to_html(false), CSS["white"], "primary type must be --white")
	assert_eq(Brand.INK.to_html(false), CSS["black"], "type must be shadowed in --black")


func test_the_hairline_is_white_at_nine_percent() -> void:
	# `--line:rgba(255,255,255,.09)`. Alpha is the whole point of it, so it is
	# asserted separately from the colours above, which are all opaque.
	assert_almost_eq(Brand.LINE.a, 0.09, 0.001, "the card edge must be a highlight, not a border")


func test_a_pill_is_round_ended_at_any_height() -> void:
	# Half the height in every corner is the definition of a pill, and it is
	# arithmetic rather than a clamp, so it holds at sizes nobody has drawn yet.
	for height: float in HEIGHTS:
		var box: StyleBoxFlat = Brand.pill(Brand.RED, height)
		var radius: int = roundi(height / 2.0)
		assert_eq(box.corner_radius_top_left, radius, "a %s-tall pill is not round-ended" % height)
		assert_eq(box.corner_radius_bottom_right, radius, "a pill's corners must all match")


func test_a_pill_is_filled_with_what_it_was_asked_for() -> void:
	assert_eq(Brand.pill(Brand.RED, HEIGHT).bg_color, Brand.RED)
	assert_eq(Brand.pill(Brand.RED_DARK, HEIGHT).bg_color, Brand.RED_DARK)


func test_a_pill_glows_in_its_own_colour() -> void:
	# The gradient did not survive the port, so the glow is what is left of the
	# site's button. A fixed red one would hang under the pressed pill after it
	# had already gone dark.
	var pressed: StyleBoxFlat = Brand.pill(Brand.RED_DARK, HEIGHT)
	assert_eq(Color(pressed.shadow_color, 1.0), Brand.RED_DARK, "the glow must follow the fill")
	assert_almost_eq(pressed.shadow_color.a, Brand.PILL_SHADOW_ALPHA, 0.001)
	assert_gt(pressed.shadow_size, 0, "a pill with no glow is a rectangle with round ends")


func test_the_focus_ring_shows_the_press_through_it() -> void:
	# Godot draws `focus` over whichever state box is already there, and this
	# screen hands focus to Start on open — so an opaque ring would mean the
	# button never visibly reacts to being pressed. Verified as transparency
	# rather than trusted as a comment.
	var ring: StyleBoxFlat = Brand.focus_ring(HEIGHT)
	assert_eq(ring.bg_color.a, 0.0, "the focus ring must not fill the button")
	assert_gt(ring.border_width_top, 0, "...and must still be visible")
	assert_gt(ring.border_color.a, 0.0, "...in a colour you can see")


func test_the_focus_ring_matches_the_pill_it_marks() -> void:
	var height: float = HEIGHT
	assert_eq(
		Brand.focus_ring(height).corner_radius_top_left,
		Brand.pill(Brand.RED, height).corner_radius_top_left,
		"a square ring around a round button reads as a bug"
	)


func test_a_card_is_a_frame_and_not_a_fill() -> void:
	var box: StyleBoxFlat = Brand.card()
	assert_eq(box.bg_color, Brand.PANEL, "a card is --panel")
	assert_eq(box.border_color, Brand.LINE, "a card's edge is --line")
	assert_gt(box.border_width_top, 0, "without an edge it is a hole in the room, not a plate")
	# The inset is what makes it a frame: content stops short of the border on
	# every side, the way the site's `.hero-card{padding:12px}` does.
	assert_eq(box.get_content_margin(SIDE_LEFT), float(Brand.CARD_INSET))
	assert_eq(box.get_content_margin(SIDE_BOTTOM), float(Brand.CARD_INSET))


func test_a_card_is_lifted_off_the_page() -> void:
	var box: StyleBoxFlat = Brand.card()
	assert_gt(box.shadow_size, 0, "the card's drop shadow is what separates it from the garage")
	assert_gt(box.shadow_offset.y, 0.0, "and the light comes from above, as it does on the site")


# ---- the badge, and the contrast arithmetic underneath it --------------------


func test_a_badge_is_a_disc() -> void:
	# A pill at a square size is a circle by the same arithmetic that gives Start
	# its round ends. If that ever stops being true, the belt grows five squircles
	# and nobody has changed a line in the HUD.
	var box: StyleBoxFlat = Brand.badge(Brand.PANEL, BADGE_SIDE)
	var radius: int = roundi(BADGE_SIDE / 2.0)
	assert_eq(box.corner_radius_top_left, radius, "a square pill must come out round")
	assert_eq(box.corner_radius_bottom_right, radius, "on every corner")
	assert_eq(box.bg_color, Brand.PANEL, "and filled with what it was asked for")


func test_a_badge_has_the_lit_edge_a_card_has() -> void:
	# Without it a dark disc over a dark garage is a hole rather than a plate —
	# the same argument [method Brand.card] makes about the logo's own black.
	var box: StyleBoxFlat = Brand.badge(Brand.PANEL, BADGE_SIDE)
	assert_eq(box.border_color, Brand.LINE, "a badge's edge is --line")
	assert_gt(box.border_width_top, 0, "and it has to actually be drawn")


func test_the_contrast_ratio_is_the_one_wcag_defines() -> void:
	# Three fixed points of the published definition, so this is a transcription
	# gate like the palette above rather than a check that the code agrees with
	# itself: black on white is exactly 21, a colour on itself is exactly 1, and
	# the ratio does not care which way round it was asked.
	assert_almost_eq(Brand.contrast_ratio(Color.BLACK, Color.WHITE), 21.0, 0.001, "black on white")
	assert_almost_eq(Brand.contrast_ratio(Brand.RED, Brand.RED), 1.0, 0.001, "a colour on itself")
	assert_almost_eq(
		Brand.contrast_ratio(Brand.WHITE, Brand.PANEL),
		Brand.contrast_ratio(Brand.PANEL, Brand.WHITE),
		0.001,
		"contrast is symmetric"
	)


func test_the_near_black_bottle_is_the_bug_this_exists_for() -> void:
	# The measurement the whole tint mechanism was added for, pinned so it cannot
	# quietly stop being a problem the code still solves — or quietly become one
	# the code stops solving.
	var albedo: Color = _albedo_of(DetailingTool.Id.TIRE_ENGINE_CLEANER)
	assert_lt(
		Brand.contrast_ratio(albedo, Brand.PANEL),
		Brand.BADGE_CONTRAST,
		"the raw albedo is invisible on a dark plate — that is why badge_tint() exists"
	)
	var tint: Color = Brand.badge_tint(albedo)
	assert_gte(Brand.contrast_ratio(tint, Brand.PANEL), Brand.BADGE_CONTRAST, "and the tint is not")
	assert_gt(tint.v, albedo.v, "lifted, rather than replaced with something else entirely")


func test_every_tool_on_the_belt_can_be_seen_on_its_plate() -> void:
	# The claim the badges rest on, checked against the real catalogue rather than
	# against a colour written down twice: adding a sixth tool in a colour nobody
	# can see fails here, at the table, instead of on a phone.
	for carried: DetailingTool in DetailingTool.catalogue():
		var ratio: float = Brand.contrast_ratio(Brand.badge_tint(carried.albedo), Brand.PANEL)
		assert_gte(
			ratio, Brand.BADGE_CONTRAST, "%s is unreadable on its badge" % carried.display_name
		)


func test_a_tint_leaves_a_colour_that_already_clears_alone() -> void:
	# Three of the five tools need nothing done to them, and doing something
	# anyway would be inventing a colour the tool does not have in the name of a
	# problem it does not have.
	var silver: Color = _albedo_of(DetailingTool.Id.POWER_WASH)
	assert_gt(Brand.contrast_ratio(silver, Brand.PANEL), Brand.BADGE_CONTRAST, "the premise")
	assert_eq(Brand.badge_tint(silver), silver, "a colour that clears the floor is left as it is")


func test_a_tint_is_still_the_tools_own_colour() -> void:
	# The other half of "lifted, not replaced". A tint that clears the floor by
	# going grey would pass every assertion above and destroy the one thing the
	# albedo is documented to be for — telling two tools apart at a glance.
	var blue: Color = _albedo_of(DetailingTool.Id.DRYING_RAG)
	var tint: Color = Brand.badge_tint(blue)
	assert_gt(tint.b, tint.r, "the rag's badge must still be blue")
	assert_almost_eq(tint.h, blue.h, 0.02, "and the same blue it always was")


func test_white_is_readable_on_the_equipped_plate() -> void:
	# The equipped badge swaps to a red plate with a white glyph. Red is the one
	# fill in this palette bright enough to be worth checking white against, and
	# it is checked rather than assumed.
	assert_gte(
		Brand.contrast_ratio(Brand.WHITE, Brand.RED),
		Brand.BADGE_CONTRAST,
		"the tool in your hands has to be the most readable badge on the belt"
	)


## The albedo of [param id] as the catalogue actually declares it. Read from
## [method DetailingTool.catalogue] rather than written down here, for the reason
## the badge tint is derived rather than tabulated: a colour that exists twice is
## a colour that can disagree with itself.
func _albedo_of(id: DetailingTool.Id) -> Color:
	for carried: DetailingTool in DetailingTool.catalogue():
		if carried.id == id:
			return carried.albedo
	fail_test("no tool with id %d in the catalogue" % id)
	return Color.MAGENTA
