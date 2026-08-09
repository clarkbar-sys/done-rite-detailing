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

## Where the two faces are committed, written out a second time on purpose —
## same argument as [constant CSS] above. Reading the constant under test to
## check the constant under test would assert nothing, and what is being checked
## here is precisely that the file is in the repo at the path everything else
## expects.
const DISPLAY_PATH: String = "res://assets/brand/fonts/PressStart2P-Regular.ttf"
const BODY_PATH: String = "res://assets/brand/fonts/Silkscreen-Regular.ttf"

## The [ProjectSettings] key that decides what every unstyled [Control] in the
## game draws in. Named rather than typed out at the call site because it is a
## string the engine owns and a typo in it would read as "unset" and pass.
const DEFAULT_FONT_SETTING: String = "gui/theme/custom_font"

## Point sizes to measure the faces at: one grid step, the size the score rests
## at, and the size it punches to. Every one a multiple of
## [constant Brand.TYPE_GRID], because that is the claim under test.
const GRID_SIZES: Array[int] = [8, 16, 24, 32, 56, 64]

## Every character the game prints that is not plain ASCII: the menu's guillemet
## exits, the credit's curly quotes and interpunct and em dash, and the score's
## multiplication sign. Collected here rather than left to the per-screen suites
## because a face is chosen once and this is the bill it has to pay.
const NON_ASCII: String = "«»·×—“”"


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


# ---- the quiet pill: the second button on a screen ---------------------------


func test_a_quiet_pill_is_still_a_pill() -> void:
	# The shape is the whole reason it is not a card: a menu's second button has
	# to read as a button, and what says "button" in this vocabulary is the
	# round end.
	for height: float in HEIGHTS:
		var box: StyleBoxFlat = Brand.quiet_pill(Brand.PANEL, height)
		var radius: int = roundi(height / 2.0)
		assert_eq(box.corner_radius_top_left, radius, "a %s-tall quiet pill is not round" % height)
		assert_eq(box.corner_radius_bottom_right, radius, "on every corner")


func test_a_quiet_pill_is_the_cards_colour_and_not_a_new_one() -> void:
	# The point of the shape existing at all. If this ever comes back something
	# other than what it was handed, the palette has grown a third fill nobody
	# transcribed from the site.
	assert_eq(Brand.quiet_pill(Brand.PANEL, HEIGHT).bg_color, Brand.PANEL)
	assert_eq(Brand.quiet_pill(Brand.INK, HEIGHT).bg_color, Brand.INK)


func test_a_quiet_pill_has_the_lit_edge_a_card_has() -> void:
	# Without it a dark shape over a lit garage is a hole cut in the room rather
	# than a button sitting on it — [method Brand.card]'s argument, applied to
	# the thing you press instead of the thing you look at.
	var box: StyleBoxFlat = Brand.quiet_pill(Brand.PANEL, HEIGHT)
	assert_eq(box.border_color, Brand.LINE, "a quiet pill's edge is --line")
	assert_gt(box.border_width_top, 0, "and it has to actually be drawn")


func test_white_is_readable_on_a_quiet_pill() -> void:
	# Both pills carry white type, and only one of them was ever checked for it.
	# --panel is much darker than --red, so this passes comfortably; it is here
	# because "comfortably" is a measurement and not an impression.
	assert_gte(
		Brand.contrast_ratio(Brand.WHITE, Brand.PANEL),
		Brand.BADGE_CONTRAST,
		"the second button's label has to be readable too"
	)


# ---- the badge, and the contrast arithmetic underneath it --------------------


func test_a_badge_is_a_quiet_pill_at_a_square_size() -> void:
	# The relationship, asserted rather than left to the doc comment: a badge is
	# one shape away from the menu's second button, and if the two ever stop
	# agreeing it is because somebody gave one of them its own edge.
	var badge: StyleBoxFlat = Brand.badge(Brand.PANEL, BADGE_SIDE)
	var quiet: StyleBoxFlat = Brand.quiet_pill(Brand.PANEL, BADGE_SIDE)
	assert_eq(badge.bg_color, quiet.bg_color)
	assert_eq(badge.border_color, quiet.border_color)
	assert_eq(badge.corner_radius_top_left, quiet.corner_radius_top_left)


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


func test_a_tint_is_asked_against_the_plate_it_will_be_drawn_on() -> void:
	# The equipped badge sits on --red, which is twenty-six times the luminance of
	# --panel, so a tint that clears the floor on the dark plate can be well under
	# it on the red one. The sponge is the case: its own yellow is 12:1 on the
	# panel and 3.1:1 on the red, and the belt draws the tool it is holding on the
	# red one.
	var yellow: Color = _albedo_of(DetailingTool.Id.SPONGE)
	assert_lt(
		Brand.contrast_ratio(Brand.badge_tint(yellow), Brand.RED),
		Brand.BADGE_CONTRAST,
		"the premise: the panel's tint is not readable on the accent"
	)
	assert_gte(
		Brand.contrast_ratio(Brand.badge_tint(yellow, Brand.RED), Brand.RED),
		Brand.BADGE_CONTRAST,
		"the tool in your hands has to be the most readable badge on the belt"
	)
	assert_almost_eq(
		Brand.badge_tint(yellow, Brand.RED).h, yellow.h, 0.02, "and still the sponge's own yellow"
	)


func test_a_tint_asked_against_the_dark_plate_is_what_it_always_was() -> void:
	# The plate is a default rather than a new argument every caller has to pass,
	# so the four badges that were already right must not have moved.
	for carried: DetailingTool in DetailingTool.catalogue():
		assert_eq(
			Brand.badge_tint(carried.albedo),
			Brand.badge_tint(carried.albedo, Brand.PANEL),
			"%s: the default plate is the dark one" % carried.display_name
		)


func test_the_picked_badge_says_so_without_using_colour() -> void:
	# Red is one channel, and it is the channel that fails in sunlight and for
	# roughly one man in twelve — the same failure the badges' own pictures
	# stopped relying on. A white ring is the second: it is still there in
	# greyscale, and it does not touch the picture inside it.
	var picked: StyleBoxFlat = Brand.picked_badge(Brand.RED, BADGE_SIDE)
	var plain: StyleBoxFlat = Brand.badge(Brand.PANEL, BADGE_SIDE)
	assert_eq(picked.border_color, Brand.WHITE, "the ring is full white, not the focus ring's 55%")
	assert_eq(picked.border_width_top, Brand.FOCUS_RING_WIDTH, "at the width the brand's ring is")
	assert_gt(
		picked.border_width_top, plain.border_width_top, "and thicker than the hairline it replaces"
	)
	assert_eq(
		picked.corner_radius_top_left,
		plain.corner_radius_top_left,
		"a picked badge is still the same disc"
	)


# ---- the type: two faces, one grid -------------------------------------------


func test_the_two_faces_are_the_files_committed_beside_the_logo() -> void:
	# A transcription gate, like the palette at the top: the whole reason the
	# fonts are in the repo is that a web export cannot fetch one at runtime, and
	# the way that promise breaks quietly is somebody pointing these at a path
	# that is not in `assets/`. Asserted on `resource_path` and not on the
	# preload, because the preload is what is under test.
	assert_eq(Brand.DISPLAY_FACE.resource_path, DISPLAY_PATH)
	assert_eq(Brand.BODY_FACE.resource_path, BODY_PATH)
	assert_eq(Brand.DISPLAY_FACE.get_font_name(), "Press Start 2P")
	assert_eq(Brand.BODY_FACE.get_font_name(), "Silkscreen")


func test_the_projects_default_face_is_the_body_face() -> void:
	# The one line of project.godot that makes this a type *system* rather than a
	# list of overrides — every Control that does not ask for a face gets this
	# one, including the ones nobody has written yet. Two files naming the same
	# font is exactly the drift this repo puts a test on: if the setting is
	# dropped or repointed, the game quietly grows a third typeface and nothing
	# else in the build would say so.
	assert_eq(
		str(ProjectSettings.get_setting(DEFAULT_FONT_SETTING, "")),
		BODY_PATH,
		"project.godot's default theme font must be Brand.BODY_FACE"
	)


func test_neither_face_is_softened_on_its_way_to_the_screen() -> void:
	# The import settings are the other half of "pixel arcade", and they are the
	# half that is invisible in a diff of the scenes: the same font with grey
	# antialiasing and subpixel positioning on is a blurry font, which is worse
	# than no pixel font at all. Read off the imported resource rather than out of
	# the .import file, so this asserts what the engine actually built.
	for face: FontFile in [Brand.DISPLAY_FACE, Brand.BODY_FACE]:
		var named: String = face.get_font_name()
		assert_eq(face.antialiasing, TextServer.FONT_ANTIALIASING_NONE, "%s is antialiased" % named)
		assert_eq(face.hinting, TextServer.HINTING_NONE, "%s is hinted" % named)
		assert_eq(
			face.subpixel_positioning,
			TextServer.SUBPIXEL_POSITIONING_DISABLED,
			"%s is subpixel-positioned" % named
		)
		assert_false(face.generate_mipmaps, "%s is mipmapped" % named)
		assert_false(face.multichannel_signed_distance_field, "%s is an SDF" % named)
		# And a glyph neither face has must come out as the tofu box the existing
		# per-screen font tests are written to catch, rather than as whatever the
		# machine running the editor happens to have installed — which the machine
		# running the browser will not.
		assert_false(face.allow_system_fallback, "%s falls back to a system font" % named)


func test_the_display_face_is_one_em_per_character() -> void:
	# The number every display size in this project was chosen against, and the
	# reason they all went down by about half when the face went in. Measured
	# here so that "a string is length x size wide" is a fact with a test on it
	# rather than a sentence in a doc comment.
	for size: int in GRID_SIZES:
		for word: String in ["W", "il", "000000", "How to Play"]:
			assert_eq(
				Brand.DISPLAY_FACE.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x,
				float(word.length() * size),
				'"%s" at %d must be exactly %d px wide' % [word, size, word.length() * size]
			)


func test_both_faces_scale_cleanly_on_the_grid() -> void:
	# What Brand.TYPE_GRID claims: both faces are drawn on an eighth of an em, so
	# a size that is k grids wide draws every glyph exactly k times the width it
	# has at one grid. That is the property that makes a grid size crisp and any
	# other size uneven, and it is checkable without a screenshot.
	var sample: String = _printable_ascii()
	for face: FontFile in [Brand.DISPLAY_FACE, Brand.BODY_FACE]:
		var unit: float = (
			face.get_string_size(sample, HORIZONTAL_ALIGNMENT_LEFT, -1, Brand.TYPE_GRID).x
		)
		for size: int in GRID_SIZES:
			var steps: int = size / Brand.TYPE_GRID
			assert_eq(
				face.get_string_size(sample, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x,
				unit * float(steps),
				(
					"%s at %d is not %d times its width at %d"
					% [face.get_font_name(), size, steps, Brand.TYPE_GRID]
				)
			)


func test_crisp_lands_on_the_grid_and_never_below_it() -> void:
	assert_eq(Brand.crisp(56), 56, "a size already on the grid must not move")
	assert_eq(Brand.crisp(60), 64, "half a step up rounds up")
	assert_eq(Brand.crisp(59), 56, "and just under half rounds down")
	assert_eq(Brand.crisp(1), Brand.TYPE_GRID, "the floor is one whole grid")
	assert_eq(Brand.crisp(0), Brand.TYPE_GRID, "including at zero")
	assert_eq(Brand.crisp(-40), Brand.TYPE_GRID, "and at a size nobody should ask for")
	# The properties the callers actually depend on, over the whole range a font
	# size in this project can reach. The half-step bound is asked only at or
	# above the grid, and that is the floor being honest rather than an excuse:
	# below one whole grid there is no rounding left to do, so crisp(1) moves
	# seven and is meant to.
	for size: int in range(1, 256):
		var snapped: int = Brand.crisp(size)
		assert_eq(snapped % Brand.TYPE_GRID, 0, "crisp(%d) is off the grid" % size)
		assert_gte(snapped, Brand.TYPE_GRID, "crisp(%d) went under the floor" % size)
		if size >= Brand.TYPE_GRID:
			assert_lte(
				absi(snapped - size),
				Brand.TYPE_GRID / 2,
				"crisp(%d) moved further than half a step" % size
			)


func test_both_faces_can_draw_every_word_in_the_game() -> void:
	# The bug this whole family of tests exists for, moved to the type system
	# itself: a glyph a face does not have is not an error and not a warning, it
	# is a blank rectangle in a released build. The per-screen suites already ask
	# this of the copy they can see; this asks it of the alphabet, so a face
	# swapped for one with a thinner glyph set fails here rather than on somebody's
	# phone.
	var wanted: String = _printable_ascii() + NON_ASCII
	for face: FontFile in [Brand.DISPLAY_FACE, Brand.BODY_FACE]:
		for i: int in wanted.length():
			var glyph: int = wanted.unicode_at(i)
			assert_true(
				face.has_char(glyph),
				"%s cannot draw U+%04X (%s)" % [face.get_font_name(), glyph, char(glyph)]
			)


## Space through tilde: the alphabet every screen in this game is written in.
func _printable_ascii() -> String:
	var found: String = ""
	for code: int in range(0x20, 0x7F):
		found += char(code)
	return found


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
