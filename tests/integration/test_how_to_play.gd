## Integration test for the how-to-play screen: that both exits lead where they
## claim to, and that the whole of the copy is actually on the screen.
##
## [b]The assertion that earns its line count is
## [method test_every_word_of_the_rules_is_visible].[/b] "One screen, no
## scrolling" is the brief, and it is the one property of this screen that cannot
## be established by reading the file: a [Label] with
## [constant TextServer.AUTOWRAP_WORD_SMART] on it and less height than its text
## needs does not overflow, complain or resize — it silently draws the lines that
## fit and drops the rest. So the screen would look finished, pass every other
## test here, and be missing the last sentence of a rule. Godot will tell us how
## many lines each label has and how many of them it managed to draw; those two
## numbers agreeing, for every label on the screen, is the brief.
##
## It is therefore also the test that fails when the copy grows. That is
## intended: a rules screen is a fixed amount of room, and the moment a sentence
## no longer fits, somebody has to decide between the sentence and the type size
## rather than find out in a browser.
##
## [b]The other two are here because they were found in a browser, on a phone,
## after this screen had already shipped once.[/b]
## [method test_the_font_can_draw_every_word] pins the glyphs: this project
## ships no font of its own, so everything is drawn in Godot's built-in Open
## Sans, and a character it does not have is not an error — it is a tofu box on
## a released build. [method test_the_sheet_fits_a_phone_held_upright] pins the
## shape: the design is 16:9 and stretched "expand", so a portrait handset hands
## this screen nearly four times the height it was laid out against, and every
## other assertion in this file was made at exactly 1280x720, where that cannot
## show up.
extends GutTest

const HOW_TO_PLAY: String = "res://src/screens/how_to_play.tscn"

## A portrait handset, in real pixels: a Pixel-class 1080x2340, which
## project.godot's "expand" resolves to 1280x2773 design pixels. The number that
## matters is the aspect, not the model — anything much taller than 16:9 puts
## this screen in the shape the bug needed.
const PORTRAIT: Vector2i = Vector2i(1080, 2340)

## How much taller than its own content the sheet is allowed to be.
##
## Zero would be the honest number and is not quite reachable: a
## [GridContainer] row is as tall as its tallest cell, so the shorter rule in
## each row leaves a few pixels under it whatever the screen is. This is loose
## enough for that and nowhere near loose enough for the two thousand pixels of
## nothing the shipped version had.
const SLACK: float = 32.0

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


## One of the four rules' body paragraphs — any of them, since the type scale is
## one rule applied to all of them.
func _a_body() -> Label:
	return _screen.get_node("%Rules/Walk/Body") as Label


## What [param control] has written on it, whichever of the two it is.
func _words_of(control: Control) -> String:
	var label: Label = control as Label
	if label != null:
		return label.text
	return (control as Button).text


func test_the_screen_is_a_game_screen() -> void:
	assert_not_null(_screen, "the rules screen must instantiate as a GameScreen")


# ---- one screen, no scrolling ------------------------------------------------


func test_every_word_of_the_rules_is_visible() -> void:
	# See this file's header. An autowrapping Label with too little height draws
	# what fits and drops the rest, in silence.
	var labels: Array[Label] = _labels(_screen)
	assert_gt(labels.size(), 10, "the rules screen should be mostly words")
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
	# shipped reading "◀ Main Menu" and "Play ▶", and Godot's built-in Open Sans
	# has no geometric shapes block, so both arrows drew as tofu boxes on a real
	# phone. A missing glyph is not an error and not a warning — it is a rectangle
	# in a released build, and nothing else in this project would ever mention it.
	#
	# The buttons *and* the labels, and the buttons are the reason this comment
	# says so: the first version of this test walked the labels only, which is
	# every word on the screen except the two that were actually broken.
	var typeset: Array[Control] = _typeset(_screen)
	assert_gt(typeset.size(), 10, "the rules screen should be mostly words")
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


func test_the_type_grows_into_the_room_a_phone_gives_it() -> void:
	# The point of the whole exercise. At 1280x720 the type is the size the
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


func test_the_rules_go_to_one_column_on_a_phone_held_upright() -> void:
	# Reflow rather than rescale, and the two are not interchangeable: a column
	# half as wide wraps the same sentence to twice as many lines, so two columns
	# on a tall screen would grow downwards as fast as the type grew and reach a
	# readable size no sooner. One column is also the layout the mockup draws —
	# it did not fit at 720, and this is the shape of screen where it does.
	var rules: GridContainer = _screen.get_node("%Rules") as GridContainer
	assert_eq(rules.columns, 2, "a 16:9 screen keeps the two columns")
	get_tree().root.size = PORTRAIT
	await wait_process_frames(3)
	assert_eq(rules.columns, 1, "a phone held upright reads better in one")


func test_the_rules_do_not_come_apart_on_a_phone_held_upright() -> void:
	# The half of that bug a card-sized assertion cannot see, and the half that
	# was actually visible: the slack was absorbed *inside* the column by the
	# rules grid, which packs its rows at the top. So the four rules sat under
	# the header, the strip and the buttons sat at the bottom of the phone, and
	# there were two thousand pixels of black between them — with the card and
	# the column both perfectly full the whole time.
	get_tree().root.size = PORTRAIT
	await wait_process_frames(2)
	var rules: GridContainer = _screen.get_node("%Rules") as GridContainer
	var strip: HBoxContainer = _screen.get_node("%Strip") as HBoxContainer
	var written: float = 0.0
	for cell: Node in rules.get_children():
		var control: Control = cell as Control
		if control != null:
			written = maxf(written, control.get_global_rect().end.y)
	assert_lte(
		strip.get_global_rect().position.y - written,
		SLACK,
		"the rules and the passes came apart — there is a hole in the middle of the sheet"
	)


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


func test_the_rules_are_printed_on_a_brand_card() -> void:
	# Without it the type is laid straight over a lit garage, a yellow truck and
	# a green verge, which is the one way this palette fails.
	var card: PanelContainer = _screen.get_node("%Card") as PanelContainer
	var box: StyleBoxFlat = card.get_theme_stylebox("panel") as StyleBoxFlat
	assert_not_null(box, "the rules must sit on a brand card")
	if box == null:
		return
	assert_eq(box.bg_color, Brand.PANEL, "the sheet must be the site's panel colour")


func test_play_is_the_accent_and_main_menu_is_not() -> void:
	var loud: StyleBoxFlat = _play_button().get_theme_stylebox("normal") as StyleBoxFlat
	var quiet: StyleBoxFlat = _main_menu_button().get_theme_stylebox("normal") as StyleBoxFlat
	assert_not_null(loud, "Play must be a brand pill, not the theme's button")
	assert_not_null(quiet, "Main Menu must be a brand pill, not the theme's button")
	if loud == null or quiet == null:
		return
	assert_eq(loud.bg_color, Brand.RED, "starting the game is the answer, so it is red")
	assert_eq(quiet.bg_color, Brand.PANEL, "going back is not a second accent")


func test_every_face_of_every_button_is_dressed() -> void:
	for button: Button in [_play_button(), _main_menu_button()]:
		for state: String in ["normal", "hover", "pressed", "focus"]:
			assert_true(
				button.has_theme_stylebox_override(state),
				"%s's `%s` box must come from Brand" % [button.name, state]
			)


func test_both_buttons_are_big_enough_for_a_finger() -> void:
	# This is also what holds the layout above honest: the buttons are the first
	# thing a cramped column would borrow height from, and this is the floor
	# they are not allowed to go below to make room for a sentence.
	var minimum: float = TouchTarget.min_design_size()
	for button: Button in [_play_button(), _main_menu_button()]:
		assert_gte(button.size.x, minimum, "%s is too narrow to hit on a phone" % button.name)
		assert_gte(button.size.y, minimum, "%s is too short to hit on a phone" % button.name)


func test_the_headings_are_red_and_the_body_is_not() -> void:
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
	assert_eq(reds, 7, "four rules and three passes, each with a heading")
	assert_eq(whites, 7, "and each with a body")


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
