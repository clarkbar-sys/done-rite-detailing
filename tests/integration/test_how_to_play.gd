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
extends GutTest

const HOW_TO_PLAY: String = "res://src/screens/how_to_play.tscn"

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
