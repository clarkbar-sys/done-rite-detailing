## Integration test for the how-to-play screen: that the three passes are on it
## and in order, that the film is one press away, and that both exits lead where
## they claim to.
##
## [b]This suite used to be mostly about a wall of text, and the wall is
## gone.[/b] The assertions that asked "is every line of every paragraph
## actually drawn" were the load-bearing ones when the screen carried seven
## hundred characters of copy in two columns — an autowrapping [Label] with less
## height than its text needs does not overflow, complain or resize, it silently
## draws the lines that fit and drops the rest, so the screen would have looked
## finished and been missing the last sentence of a rule. #226 replaced the copy
## with three numbered passes and a link out to a film, so most of what that
## gate was defending no longer exists. The gate stays — clipping is still
## invisible and captions still wrap — but it is no longer what this file is
## for.
##
## [b]What it is for now is the shape.[/b] Three things can go wrong with a
## screen this size and none of them is a compile error:
## [method test_the_wall_of_text_stays_gone] is the one that would creep back,
## [method test_the_three_passes_are_numbered_in_order] is the teaching the
## screen has left, and
## [method test_the_sheet_stays_inside_the_screen_sideways_on_a_phone_held_upright]
## is the failure that arrived [i]with[/i] the gutting: less copy means the type
## grows further, and past a certain size the row of pills is wider than the
## sheet it is printed on. That one is measured here because
## [code]how_to_play.gd[/code]'s answer to it — [code]_fits_across[/code] — is
## arithmetic over the wording of two buttons, and wording changes.
##
## [b]And two are here because they were found in a browser, on a phone, after
## this screen had already shipped once.[/b]
## [method test_the_font_can_draw_every_word] pins the glyphs: a character the
## face does not have is not an error — it is a tofu box on a released build.
## It was written when everything was drawn in Godot's built-in Open Sans and it
## is worth more since #174, not less: the game now ships two faces of its own,
## both of them pixel faces with far thinner glyph sets than a Google-scale web
## sans, and this screen carries the guillemets, an em dash and an apostrophe.
## [method test_the_sheet_is_the_size_of_its_own_words_on_a_phone_held_upright]
## pins the shape: the design is 16:9 and stretched "expand", so a portrait
## handset hands this screen nearly four times the height it was laid out
## against, and every other assertion in this file was made at exactly 1280x720,
## where that cannot show up.
extends GutTest

const HOW_TO_PLAY: String = "res://src/screens/how_to_play.tscn"

## The screen's own script, read as text by
## [method test_the_film_is_opened_inside_the_press]. Source-scanning is a blunt
## instrument and this is the one claim on this screen that nothing else can
## make — see that test.
const HOW_TO_PLAY_SCRIPT: String = "res://src/screens/how_to_play.gd"

## A portrait handset, in real pixels: a Pixel-class 1080x2340, which
## project.godot's "expand" resolves to 1280x2773 design pixels. The number that
## matters is the aspect, not the model — anything much taller than 16:9 puts
## this screen in the shape the bug needed.
const PORTRAIT: Vector2i = Vector2i(1080, 2340)

## How much taller than its own content the sheet is allowed to be, and how far
## apart two rows printed on it may drift.
##
## Zero would be the honest number and is not quite reachable: a row of the
## passes is as tall as its tallest cell, so a shorter caption leaves a few
## pixels under it whatever the screen is. This is loose enough for that and
## nowhere near loose enough for the two thousand pixels of nothing the shipped
## version had.
const SLACK: float = 32.0

## Every word on the screen, added up. The copy this replaced was about seven
## hundred characters; what is there now is under a hundred, and the budget is
## somewhere between the two so that a caption can be reworded and a paragraph
## cannot come back. See [method test_the_wall_of_text_stays_gone] for why that
## is a test and not a note in a review.
const COPY_BUDGET: int = 240

## The design the layout is built against, from project.godot. Read rather than
## written down here for [method TouchTarget.design_width]'s reason: a copy of
## 1280x720 in a test is a copy that quietly stops being true the day somebody
## changes the base resolution.
const DESIGN_HEIGHT_SETTING: String = "display/window/size/viewport_height"

var _screen: GameScreen = null
var _requested: Array[GameState] = []
var _rung: Array[Bell.Voice] = []
var _faded: Array[float] = []
var _window_size_before: Vector2i = Vector2i.ZERO


func before_each() -> void:
	_requested = []
	_rung = []
	_faded = []
	# Everything below is about what fits on a screen, so the window has to be
	# the size the design assumes rather than the 64x64 a headless run gets.
	# Put back in after_each: every suite shares this window.
	var root: Window = get_tree().root
	_window_size_before = root.size
	root.size = root.content_scale_size
	var packed: PackedScene = load(HOW_TO_PLAY) as PackedScene
	assert_not_null(packed, "could not load %s" % HOW_TO_PLAY)
	if packed == null:
		return
	var screen: GameScreen = packed.instantiate() as GameScreen
	_screen = screen
	add_child_autofree(_screen)
	_screen.transition_requested.connect(_record)
	_screen.bell_requested.connect(_record_bell)
	_screen.music_stop_requested.connect(_record_fade)
	# Two frames rather than one: the first lays the containers out and the
	# second is where an autowrapping Label, which cannot know its line count
	# until it has been given a width, settles on one.
	await wait_process_frames(2)


func after_each() -> void:
	get_tree().root.size = _window_size_before


func _record(state: GameState) -> void:
	_requested.append(state)


func _record_bell(voice: Bell.Voice) -> void:
	_rung.append(voice)


func _record_fade(seconds: float) -> void:
	_faded.append(seconds)


func _play_button() -> Button:
	return _screen.get_node("%Play") as Button


func _main_menu_button() -> Button:
	return _screen.get_node("%MainMenu") as Button


func _watch_button() -> Button:
	return _screen.get_node("%Watch") as Button


## The three pills, in the order the screen offers them.
func _pills() -> Array[Button]:
	var found: Array[Button] = [_watch_button(), _main_menu_button(), _play_button()]
	return found


func _design_height() -> float:
	return str(ProjectSettings.get_setting(DESIGN_HEIGHT_SETTING, 720)).to_float()


## Every [Label] under [param root], however deep — the whole of the copy, found
## the same way [code]how_to_play.gd[/code] finds it to colour it.
func _labels(root: Node) -> Array[Label]:
	var found: Array[Label] = []
	for child: Node in root.get_children():
		var label: Label = child as Label
		if label != null:
			found.append(label)
		found.append_array(_labels(child))
	return found


## Everything under [param root] that draws words: the labels [i]and[/i] the
## buttons.
##
## The distinction cost a shipped bug. [method _labels] is the right tool for
## anything about the copy — colours, wrapping, clipping — because the copy is
## labels. It is the wrong tool for anything about the font, because a [Button]
## draws text too and the two glyphs this project could not draw were both on
## one.
func _typeset(root: Node) -> Array[Control]:
	var found: Array[Control] = []
	for child: Node in root.get_children():
		if child is Label or child is Button:
			found.append(child as Control)
		found.append_array(_typeset(child))
	return found


## The headings of the three passes, in the order the scene lays them out.
func _pass_headings() -> Array[Label]:
	var found: Array[Label] = []
	var strip: HBoxContainer = _screen.get_node("%Strip") as HBoxContainer
	for cell: Node in strip.get_children():
		var heading: Label = cell.get_node_or_null("Heading") as Label
		if heading != null:
			found.append(heading)
	return found


## One of the passes' captions — any of them, since the type scale is one rule
## applied to all of them.
func _a_body() -> Label:
	return _screen.get_node("%Strip/Water/Body") as Label


## The lines of [param source] that make up the function [param header] opens,
## or [code]""[/code] if there is no such function.
##
## Stops at the next function [i]or the next doc comment[/i], so what comes back
## is code and not the prose introducing whatever is written underneath it —
## which matters because the thing being searched for is a word like
## [code]await[/code], and a paragraph explaining why there is no await in this
## handler would otherwise read as one.
func _body_of(source: String, header: String) -> String:
	var at: int = source.find(header)
	if at < 0:
		return ""
	var ends: int = source.length()
	for boundary: String in ["\nfunc ", "\n##"]:
		var found: int = source.find(boundary, at + 1)
		if found >= 0:
			ends = mini(ends, found)
	return source.substr(at, ends - at)


## What [param control] has written on it, whichever of the two it is.
func _words_of(control: Control) -> String:
	var label: Label = control as Label
	if label != null:
		return label.text
	return (control as Button).text


func test_the_screen_is_a_game_screen() -> void:
	assert_not_null(_screen, "the rules screen must instantiate as a GameScreen")


# ---- what the screen teaches ---------------------------------------------------


func test_the_wall_of_text_stays_gone() -> void:
	# The regression this screen is one commit away from at any time. Nothing
	# stops a paragraph being pasted back into the scene file: it would type-check,
	# export, and fail nothing except the reason #175 was opened — a player who
	# came to press Play being handed seven hundred characters to read first. So
	# the budget is a number a test can hold, and a caption that has grown into a
	# sentence has to argue with it.
	var written: int = 0
	for label: Label in _labels(_screen):
		written += label.text.length()
	assert_lt(
		written,
		COPY_BUDGET,
		(
			"the rules screen is back to %d characters of copy — the film is what the words were"
			% written
		)
	)


func test_the_three_passes_are_numbered_in_order() -> void:
	# What the screen has left to teach on its own account, for the player who
	# will not click out to a film: a panel goes water, then bottle, then rag,
	# and the order is the whole content. Numbers rather than arrows because the
	# row is free to reflow on a narrow screen, and both are asserted — the text
	# says the order and the layout agrees with it, which is the pair that can
	# come apart when somebody reorders the cells and not the labels.
	var headings: Array[Label] = _pass_headings()
	assert_eq(headings.size(), 3, "wash, cleaner, buff — three passes")
	var previous: float = -1.0
	for i: int in headings.size():
		var heading: Label = headings[i]
		assert_true(
			heading.text.begins_with("%d." % (i + 1)),
			'pass %d reads "%s" — the numbers are the order' % [i + 1, heading.text]
		)
		var at: float = heading.get_global_rect().position.x
		assert_gt(at, previous, "the passes must read left to right: %s" % heading.text)
		previous = at


func test_the_film_is_one_press_away() -> void:
	# The other half of what replaced the copy. The button is wired to exactly
	# one thing, which is this screen's own handler — a second connection would
	# mean two tabs, and none would mean a pill that looks pressable and is not.
	var connections: Array = _watch_button().pressed.get_connections()
	assert_eq(connections.size(), 1, "the watch button must do exactly one thing")
	if connections.size() != 1:
		return
	var wiring: Dictionary = connections[0]
	var to: Callable = wiring["callable"]
	assert_eq(to.get_object(), _screen, "the press is the screen's to handle")
	assert_eq(to.get_method(), "_on_watch_pressed")


func test_the_film_is_opened_inside_the_press() -> void:
	# Source-scanned, and it is the one claim about this screen that nothing
	# else can make. A browser lets a page open a window only while it is still
	# crediting a gesture the player made, and the first thing that waits spends
	# it — so an await, a timer or a deferred call in this handler is not a
	# delay, it is a popup blocked in silence, on the web build only, on a page
	# CI cannot open. There is nothing to instrument: the failure is a tab that
	# never appears. So what is checked is the shape of the handler itself.
	var source: String = FileAccess.get_file_as_string(HOW_TO_PLAY_SCRIPT)
	var body: String = _body_of(source, "func _on_watch_pressed")
	assert_false(body.is_empty(), "%s must still handle the press" % HOW_TO_PLAY_SCRIPT)
	if body.is_empty():
		return
	assert_true(body.contains("WatchVideo.open()"), "the press must open the film: %s" % body)
	for waiting: String in ["await", "call_deferred", "create_timer", "create_tween"]:
		assert_false(
			body.contains(waiting),
			"%s in the handler spends the gesture the browser opens the tab on" % waiting
		)


# ---- one screen, no scrolling ------------------------------------------------


func test_every_word_on_the_screen_is_visible() -> void:
	# See this file's header. An autowrapping Label with too little height draws
	# what fits and drops the rest, in silence. Cheap to pass now and kept for
	# the same reason it was written: nothing else would ever mention it.
	var labels: Array[Label] = _labels(_screen)
	assert_gte(labels.size(), 9, "the title, its caption and three passes of two labels each")
	for label: Label in labels:
		assert_eq(
			label.get_visible_line_count(),
			label.get_line_count(),
			(
				"%s is clipped — %d of its %d lines are drawn"
				% [label.name, label.get_visible_line_count(), label.get_line_count()]
			)
		)


func test_nothing_is_scrollable() -> void:
	# The other half of "one screen": a suite that only checked labels would pass
	# a screen someone had quietly wrapped in a ScrollContainer to make the copy
	# fit.
	assert_eq(
		_screen.find_children("*", "ScrollContainer", true, false).size(),
		0,
		"the rules must fit rather than scroll"
	)


func test_the_whole_sheet_is_on_the_screen() -> void:
	# The card is laid inside a margin container anchored to the viewport, so
	# this fails if the copy has pushed the layout past the bottom rather than
	# clipped inside it — the other way the same mistake can show up.
	var frame: MarginContainer = _screen.get_node("%Frame") as MarginContainer
	assert_lte(
		frame.get_global_rect().end.y,
		_design_height(),
		"the sheet runs off the bottom of a %d-tall screen" % roundi(_design_height())
	)


func test_the_buttons_are_the_last_thing_and_are_on_it() -> void:
	var buttons: HBoxContainer = _screen.get_node("%Buttons") as HBoxContainer
	assert_lte(
		buttons.get_global_rect().end.y,
		_design_height(),
		"the way out of the rules screen is off the bottom of it"
	)


func test_the_font_can_draw_every_word() -> void:
	# The bug this pins, measured rather than imagined: the bottom two buttons
	# shipped reading "◀ Main Menu" and "Play ▶", and Godot's built-in Open Sans —
	# what the whole game was drawn in then — has no geometric shapes block, so
	# both arrows drew as tofu boxes on a real phone. A missing glyph is not an
	# error and not a warning — it is a rectangle in a released build, and nothing
	# else in this project would ever mention it.
	#
	# `get_theme_font` and not Brand.DISPLAY_FACE/BODY_FACE by name, which is the
	# point of asking the control: this screen sets a face per role, so what is
	# under test is the face the label will actually be drawn in rather than the
	# one this test assumed it would be.
	#
	# The buttons *and* the labels, and the buttons are the reason this comment
	# says so: the first version of this test walked the labels only, which is
	# every word on the screen except the two that were actually broken. The
	# watch button is the newest reason to keep it — it says "it's", and an
	# apostrophe is a glyph like any other.
	var typeset: Array[Control] = _typeset(_screen)
	assert_gte(typeset.size(), 12, "nine labels and three pills")
	for control: Control in typeset:
		var font: Font = control.get_theme_font("font")
		var words: String = _words_of(control)
		for i: int in words.length():
			var glyph: int = words.unicode_at(i)
			assert_true(
				font.has_char(glyph),
				(
					"%s wants U+%04X (%s), which %s cannot draw"
					% [control.name, glyph, char(glyph), font.get_font_name()]
				)
			)


func test_the_sheet_is_the_size_of_its_own_words_on_a_phone_held_upright() -> void:
	# The other thing that shipped. The design is 1280x720 and project.godot
	# stretches it "expand", so a portrait handset does not get a letterboxed
	# strip — it gets the design width and as much extra design *height* as its
	# aspect asks for, which for a 1080x2340 phone is 1280x2773. The card was
	# anchored to that, so it arrived four times taller than anything printed on
	# it.
	#
	# The sheet is now free to be as tall as the phone — that is what growing the
	# type is for — so what is asserted is that it is the size of its own words
	# and still on the screen, rather than a fixed number of pixels.
	get_tree().root.size = PORTRAIT
	await wait_process_frames(3)
	assert_gt(_screen.size.y, _design_height() * 2.0, "the premise: a much taller screen")
	var card: PanelContainer = _screen.get_node("%Card") as PanelContainer
	var column: VBoxContainer = card.get_node("Column") as VBoxContainer
	assert_lte(
		card.size.y - column.size.y,
		SLACK + float(Brand.CARD_INSET * 2),
		"the sheet is taller than what is printed on it"
	)
	# And the whole of it is still on the screen, top and bottom both, rather
	# than centred by having been pushed off one end.
	assert_gte(card.get_global_rect().position.y, 0.0)
	assert_lte(card.get_global_rect().end.y, _screen.size.y)


func test_the_sheet_stays_inside_the_screen_sideways_on_a_phone_held_upright() -> void:
	# The failure that arrived with the gutting, and the reason `_fits_across`
	# exists. "Expand" hands a tall screen extra *height* and never extra width,
	# so the type grows until the sheet is as tall as the phone — and with three
	# captions instead of four paragraphs there is almost nothing to stop it
	# reaching the ceiling. The display face advances a whole em per character,
	# so at 3x the two exits are a row half again as wide as the sheet they are
	# printed on. A row wider than the sheet does not clip: a minimum size
	# propagates, and the card grows out past both edges of the phone.
	get_tree().root.size = PORTRAIT
	await wait_process_frames(3)
	var card: Rect2 = (_screen.get_node("%Card") as PanelContainer).get_global_rect()
	assert_gte(card.position.x, 0.0, "the sheet hangs off the left of the screen")
	assert_lte(card.end.x, _screen.size.x, "the sheet hangs off the right of the screen")
	for button: Button in _pills():
		var pill: Rect2 = button.get_global_rect()
		assert_gte(
			pill.position.x, card.position.x, "%s hangs off the left of the sheet" % button.name
		)
		assert_lte(pill.end.x, card.end.x, "%s hangs off the right of the sheet" % button.name)


func test_the_type_grows_into_the_room_a_phone_gives_it() -> void:
	# The point of the whole exercise. At 1280x720 the type is near the size the
	# mockup draws; on a handset that hands this screen nearly four times the
	# height, the sheet was a readable strip floating in two thousand pixels of
	# nothing, and the copy was about six CSS pixels tall on the glass.
	#
	# Asserted as a ratio against the same label's own landscape size, so it
	# survives anybody retuning the scene's numbers — the claim is "bigger here
	# than there", which is the actual promise, and not a font size in pixels.
	var body: Label = _a_body()
	var landscape: int = body.get_theme_font_size("font_size")
	get_tree().root.size = PORTRAIT
	await wait_process_frames(3)
	assert_gt(
		_a_body().get_theme_font_size("font_size"),
		landscape,
		"a phone held upright hands this screen the room and the type did not take it"
	)


func test_the_type_goes_back_down_when_the_room_does() -> void:
	# The failure the base sizes in `_remember` exist for: `_lay_out` runs again
	# on every resize, and a pass that scaled the previous pass's output rather
	# than the scene's would ratchet — a window dragged out and back would leave
	# the type permanently larger than it started.
	var body: Label = _a_body()
	var landscape: int = body.get_theme_font_size("font_size")
	get_tree().root.size = PORTRAIT
	await wait_process_frames(3)
	get_tree().root.size = get_tree().root.content_scale_size
	await wait_process_frames(3)
	assert_eq(
		_a_body().get_theme_font_size("font_size"),
		landscape,
		"the type did not come back down when the screen did"
	)


func test_the_sheet_does_not_come_apart_on_a_phone_held_upright() -> void:
	# The half of the portrait bug a card-sized assertion cannot see, and the
	# half that was actually visible: the slack was absorbed *inside* the column,
	# which packs its rows at the top. So the copy sat under the header, the
	# buttons sat at the bottom of the phone, and there were two thousand pixels
	# of black between them — with the card and the column both perfectly full
	# the whole time. Now that the sheet carries three rows rather than five, the
	# gap between any two consecutive ones is the same question asked cheaper.
	get_tree().root.size = PORTRAIT
	await wait_process_frames(3)
	var column: VBoxContainer = _screen.get_node("%Card/Column") as VBoxContainer
	var previous: Control = null
	for child: Node in column.get_children():
		var row: Control = child as Control
		if row == null:
			continue
		if previous != null:
			assert_lte(
				row.get_global_rect().position.y - previous.get_global_rect().end.y,
				SLACK,
				"there is a hole in the sheet above %s" % row.name
			)
		previous = row


func test_nothing_is_clipped_on_a_phone_held_upright_either() -> void:
	# The sheet is narrower per column in portrait than the arithmetic in
	# how_to_play.gd was done against? It is not — "expand" keeps the design
	# width — but the sheet is now sized to its own content rather than to the
	# screen, and a container that computes its own height is exactly the kind
	# that can compute one line too few. So the clipping gate is run again in the
	# shape that made the sizing conditional.
	get_tree().root.size = PORTRAIT
	await wait_process_frames(2)
	for label: Label in _labels(_screen):
		assert_eq(
			label.get_visible_line_count(),
			label.get_line_count(),
			"%s is clipped on a portrait phone" % label.name
		)


# ---- the brand ----------------------------------------------------------------


func test_the_passes_are_printed_on_a_brand_card() -> void:
	# Without it the type is laid straight over a lit garage, a yellow truck and
	# a green verge, which is the one way this palette fails.
	var card: PanelContainer = _screen.get_node("%Card") as PanelContainer
	var box: StyleBoxFlat = card.get_theme_stylebox("panel") as StyleBoxFlat
	assert_not_null(box, "the passes must sit on a brand card")
	if box == null:
		return
	assert_eq(box.bg_color, Brand.PANEL, "the sheet must be the site's panel colour")


func test_play_is_the_accent_and_nothing_else_is() -> void:
	# Three pills now, and still one red one. The watch button is the newest
	# candidate for a second accent and is deliberately not one: the answer to
	# "what do I press" on this screen is still Play, and a screen with two red
	# pills on it leaves the eye with nowhere to land — the menu's argument,
	# reached again with one more button.
	var loud: StyleBoxFlat = _play_button().get_theme_stylebox("normal") as StyleBoxFlat
	assert_not_null(loud, "Play must be a brand pill, not the theme's button")
	if loud == null:
		return
	assert_eq(loud.bg_color, Brand.RED, "starting the game is the answer, so it is red")
	for quiet_button: Button in [_main_menu_button(), _watch_button()]:
		var quiet: StyleBoxFlat = quiet_button.get_theme_stylebox("normal") as StyleBoxFlat
		assert_not_null(
			quiet, "%s must be a brand pill, not the theme's button" % quiet_button.name
		)
		if quiet == null:
			continue
		assert_eq(quiet.bg_color, Brand.PANEL, "%s is not a second accent" % quiet_button.name)


func test_every_face_of_every_button_is_dressed() -> void:
	for button: Button in _pills():
		for state: String in ["normal", "hover", "pressed", "focus"]:
			assert_true(
				button.has_theme_stylebox_override(state),
				"%s's `%s` box must come from Brand" % [button.name, state]
			)


func test_every_button_is_big_enough_for_a_finger() -> void:
	# This is also what holds the layout above honest: the buttons are the first
	# thing a cramped column would borrow height from, and this is the floor
	# they are not allowed to go below to make room for anything else.
	var minimum: float = TouchTarget.min_design_size()
	for button: Button in _pills():
		assert_gte(button.size.x, minimum, "%s is too narrow to hit on a phone" % button.name)
		assert_gte(button.size.y, minimum, "%s is too short to hit on a phone" % button.name)


func test_every_button_is_big_enough_for_a_finger_on_a_phone_held_upright_too() -> void:
	# The screen that grows its own type is the screen where a tap target can be
	# walked backwards by a layout decision — a pill capped at its share of a row
	# is a pill something else could cap to nothing. The floor is the floor in
	# both shapes.
	get_tree().root.size = PORTRAIT
	await wait_process_frames(3)
	var minimum: float = TouchTarget.min_design_size()
	for button: Button in _pills():
		assert_gte(button.size.x, minimum, "%s is too narrow to hit on a phone" % button.name)
		assert_gte(button.size.y, minimum, "%s is too short to hit on a phone" % button.name)


func test_the_headings_are_red_and_the_captions_are_not() -> void:
	# The colours are applied in `_ready()` by walking for the scene's own node
	# names, so this is where a renamed or re-nested row shows up: the label
	# would simply keep the theme's default colour and nothing else would notice.
	var reds: int = 0
	var whites: int = 0
	for label: Label in _labels(_screen):
		if label.name == "Heading":
			assert_eq(label.get_theme_color("font_color"), Brand.RED, "%s" % label.get_path())
			reds += 1
		elif label.name == "Body":
			assert_eq(label.get_theme_color("font_color"), Brand.WHITE, "%s" % label.get_path())
			whites += 1
	assert_eq(reds, 3, "three passes, each with a heading")
	assert_eq(whites, 3, "and each with a caption")


func test_a_heading_is_chunky_and_a_caption_is_readable() -> void:
	# The same walk-by-node-name that colours this screen also sets its face, and
	# for the same reason: "heading" and "caption" are one decision made twice,
	# and a row that came out red and readable is a heading that has stopped
	# looking like one.
	var headings: int = 0
	var bodies: int = 0
	for label: Label in _labels(_screen):
		if label.name == "Heading":
			assert_eq(label.get_theme_font("font"), Brand.DISPLAY_FACE, "%s" % label.get_path())
			headings += 1
		elif label.name == "Body":
			assert_eq(label.get_theme_font("font"), Brand.BODY_FACE, "%s" % label.get_path())
			bodies += 1
	assert_eq(headings, 3, "three passes, each with a heading")
	assert_eq(bodies, 3, "and each with a caption")
	var title: Label = _screen.get_node("%Title") as Label
	assert_eq(title.get_theme_font("font"), Brand.DISPLAY_FACE, "the title of the sheet")
	var subtitle: Label = _screen.get_node("%Subtitle") as Label
	assert_eq(subtitle.get_theme_font("font"), Brand.BODY_FACE, "the caption beside it")


func test_the_rule_under_the_title_is_the_accent() -> void:
	var rule: ColorRect = _screen.get_node("%Rule") as ColorRect
	assert_eq(rule.color, Brand.RED)


func test_play_holds_the_focus_when_the_screen_opens() -> void:
	assert_eq(
		_screen.get_viewport().gui_get_focus_owner(),
		_play_button(),
		"the rules screen must open with Play under the keyboard"
	)


# ---- both ways out ------------------------------------------------------------


func test_it_asks_for_nothing_on_its_own() -> void:
	assert_eq(_requested.size(), 0, "the rules must wait for the player")
	assert_eq(_rung.size(), 0, "and must not make a noise on their own account")
	assert_eq(_faded.size(), 0, "and must not touch the music they were handed")


func test_main_menu_goes_back_to_the_menu() -> void:
	_main_menu_button().pressed.emit()
	assert_eq(_requested.size(), 1, "Main Menu must request exactly one transition")
	if _requested.size() != 1:
		return
	assert_true(_requested[0] is MainMenuGameState, "Main Menu must lead back to the menu")


func test_main_menu_leaves_the_theme_alone() -> void:
	# Coming back out of the rules is not an event; it should sound like nothing
	# happened, because nothing did.
	_main_menu_button().pressed.emit()
	assert_eq(_faded.size(), 0, "going back must not stop the music")
	assert_eq(_rung.size(), 0, "and must not ring the bell that means the job started")


func test_play_opens_the_game_without_a_second_hop() -> void:
	# The reason this screen has a Play at all: somebody who came here to learn
	# should be able to start from where they are rather than walk back through
	# the menu to press the same word again.
	_play_button().pressed.emit()
	assert_eq(_requested.size(), 1, "Play must request exactly one transition")
	if _requested.size() != 1:
		return
	assert_true(_requested[0] is PlayGameState, "Play must open the game")


func test_play_rings_and_fades_exactly_as_the_menus_does() -> void:
	# Both Plays are the same press, so they must make the same three things
	# happen — otherwise starting the game sounds different depending on which
	# screen you started it from.
	var order: Array[String] = []
	_screen.music_stop_requested.connect(func(_seconds: float) -> void: order.append("fade"))
	_screen.transition_requested.connect(func(_state: GameState) -> void: order.append("leave"))
	_play_button().pressed.emit()
	assert_eq(_rung, [Bell.Voice.START] as Array[Bell.Voice], "Play must ding once")
	assert_eq(_faded.size(), 1, "Play did not ask for the music to go")
	if _faded.size() == 1:
		assert_almost_eq(_faded[0], Bandstand.FADE_SECONDS, 0.001, "Play cut the music dead")
	assert_eq(order, ["fade", "leave"] as Array[String])
