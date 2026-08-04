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
	# Not a `:root` variable — a literal in the site's own `.btn-dark` rule.
	"button_dark": "17171b",
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


func test_the_dark_button_is_the_sites_dark_button() -> void:
	assert_eq(
		Brand.BUTTON_DARK.to_html(false),
		CSS["button_dark"],
		"the second button must be the site's .btn-dark"
	)


func test_the_dark_button_is_not_the_card() -> void:
	# Three shades apart on the site, and the pair only works if they stay apart:
	# a dark button that is exactly a card reads as a card, and a card cannot be
	# pressed.
	assert_ne(Brand.BUTTON_DARK, Brand.PANEL, "a dark button must not become a card")


func test_a_dark_pill_is_round_ended_like_the_red_one() -> void:
	# The pair are the same shape and differ only in how they are finished, so
	# the corner arithmetic is asserted against the red pill rather than repeated.
	for height: float in HEIGHTS:
		assert_eq(
			Brand.dark_pill(Brand.BUTTON_DARK, height).corner_radius_top_left,
			Brand.pill(Brand.RED, height).corner_radius_top_left,
			"a %s-tall dark pill must be the same shape as a red one" % height
		)


func test_a_dark_pill_is_edged_rather_than_lit() -> void:
	# The whole of the difference between the two buttons, and the reason the red
	# one reads as the one to press. A dark pill that grew a glow would be a
	# second Start.
	var box: StyleBoxFlat = Brand.dark_pill(Brand.BUTTON_DARK, HEIGHT)
	assert_eq(box.bg_color, Brand.BUTTON_DARK, "a dark pill is filled with what it was asked for")
	assert_eq(box.shadow_size, 0, "a dark pill must not glow — that is Start's job")
	assert_eq(box.border_color, Brand.LINE, "its edge is the card's hairline")
	assert_gt(box.border_width_top, 0, "without one it disappears into whatever is behind it")


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
