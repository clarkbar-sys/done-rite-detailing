## Integration test for the showroom: the menu's two arrows, the name under the
## lockup, and the car in the bay behind all three.
##
## [b]Its own suite, beside [code]test_main_menu.gd[/code].[/b] That file is
## about the screen — the lockup, the two pills, the credit, and where each
## press leads. This one is about the one thing on the menu that reaches through
## the screen into the room, which is a different subject with a different
## failure mode, and splitting them is the same call
## [code]tests/integration/test_garage_styles.gd[/code] makes about the shot and
## [code]test_play_screen_*.gd[/code] makes about the bay.
##
## [b]What is worth pinning is the join.[/b] #142 pinned the game to the sedan
## and #143 gave the choice to the player instead, so there are now three answers
## to "which car" — the label under the lockup, the model standing in the bay,
## and what [CarChoice] hands the next screen. Each of the three looks right on
## its own and a playtest is the only thing that catches two of them disagreeing,
## so nearly every test below asserts more than one of them at once.
##
## [b]Every test here puts the choice back.[/b] Opening this screen writes the
## player's car into [CarChoice], which is process-wide by design — so a suite
## that walked away from one would decide which car every later suite's bay
## parks. The same care [member Sound.muted] gets in the suite next door.
extends GutTest

const MAIN_MENU: String = "res://src/screens/main_menu.tscn"

## The screen Play opens, loaded here rather than transitioned to: this suite has
## no host and does not need one — what it is checking is that the two screens
## agree about the car without anything being handed between them.
const PLAY_SCREEN: String = "res://src/screens/play_screen.tscn"

var _screen: GameScreen = null
var _requested: Array[GameState] = []
var _rung: Array[Bell.Voice] = []
var _faded: Array[float] = []
var _window_size_before: Vector2i = Vector2i.ZERO
var _chosen_before: String = ""


func before_each() -> void:
	_requested = []
	_rung = []
	_faded = []
	_chosen_before = CarChoice.chosen
	CarChoice.forget()
	# A headless window is 64x64 — smaller than either arrow, small enough that a
	# tap at a control's own coordinates lands outside the layout entirely.
	# `content_scale_size` is the design resolution from project.godot, so this
	# makes a coordinate in this file mean what it means on screen. Put back in
	# after_each: every suite shares this window.
	var root: Window = get_tree().root
	_window_size_before = root.size
	root.size = root.content_scale_size
	var packed: PackedScene = load(MAIN_MENU) as PackedScene
	assert_not_null(packed, "could not load %s" % MAIN_MENU)
	if packed == null:
		return
	# Into a typed local before handing it to add_child_autofree — GUT's helper is
	# untyped, and autofree is what keeps a failure here from being reported as a
	# leak against whichever test runs next.
	var screen: GameScreen = packed.instantiate() as GameScreen
	_screen = screen
	add_child_autofree(_screen)
	_screen.transition_requested.connect(_record)
	_screen.bell_requested.connect(_record_bell)
	_screen.music_stop_requested.connect(_record_fade)
	# `_ready()` has already fired inside add_child, and one more frame is what
	# `Garage._lay_on_the_grime` waits before it measures anything — so the bay
	# behind this screen is fully dressed by the time a test runs.
	await wait_process_frames(1)


func after_each() -> void:
	get_tree().root.size = _window_size_before
	CarChoice.choose(_chosen_before)


func _record(state: GameState) -> void:
	_requested.append(state)


func _record_bell(voice: Bell.Voice) -> void:
	_rung.append(voice)


func _record_fade(seconds: float) -> void:
	_faded.append(seconds)


func _garage() -> Garage:
	return _screen.get_node("Garage") as Garage


## The car in the bay behind the menu — what the whole picker is about, and the
## only place this screen keeps the answer.
func _parked() -> MeshCar:
	return _garage().car() as MeshCar


func _previous_car() -> CarArrow:
	return _screen.get_node("%PreviousCar") as CarArrow


func _next_car() -> CarArrow:
	return _screen.get_node("%NextCar") as CarArrow


func _car_name() -> Label:
	return _screen.get_node("%CarName") as Label


func _play_button() -> Button:
	return _screen.get_node("%Play") as Button


func _how_to_play_button() -> Button:
	return _screen.get_node("%HowToPlay") as Button


## Taps the screen at [param at], the way a finger does.
##
## Through `Input` rather than `Viewport.push_input()` for
## [code]tests/integration/test_title_screen.gd[/code]'s reason: nothing in
## [Button] reads a touch event, so what actually makes a tap work is the engine
## turning it into a click first, and that emulation lives in `Input`.
func _tap(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var touch: InputEventScreenTouch = InputEventScreenTouch.new()
		touch.position = at
		touch.pressed = pressed
		Input.parse_input_event(touch)
	Input.flush_buffered_events()


func test_the_menu_offers_a_way_through_the_pack() -> void:
	assert_not_null(_previous_car(), "the menu must offer a way back through the cars")
	assert_not_null(_next_car(), "and a way on")
	assert_not_null(_car_name(), "and must say which one is parked")


func test_the_arrows_point_opposite_ways() -> void:
	# Two instances of one script, differing in an export. A scene file that
	# forgot it would ship two forward arrows, both of which work and one of which
	# is drawn backwards from what it does.
	assert_eq(_previous_car().step(), -1, "the left arrow must step back")
	assert_eq(_next_car().step(), 1, "the right arrow must step on")
	assert_ne(
		CarArrow.glyph(true), CarArrow.glyph(false), "both arrows are drawn the same way round"
	)


func test_it_names_the_car_that_is_actually_parked() -> void:
	# The join, on the way in. The label is not allowed to be a guess about what
	# the bay drew — it is read off the car standing there.
	var parked: MeshCar = _parked()
	assert_not_null(parked, "the bay behind the menu must park one of the ten")
	if parked == null:
		return
	assert_eq(_car_name().text, CarChoice.label_for(parked.style), "the label names another car")


func test_the_menu_adopts_the_car_it_was_opened_over() -> void:
	# The first menu of a run is opened over a car nobody chose, because nobody had
	# been asked yet. Adopting that draw rather than replacing it is what makes the
	# first car a player is offered the first car they were shown.
	assert_eq(CarChoice.chosen, _parked().style, "the menu did not keep the car it opened with")


func test_the_next_arrow_parks_the_next_car() -> void:
	# The press, end to end: the bay swaps the model, the label follows it, and
	# [CarChoice] remembers it. All three, because each of them looks right alone.
	var before: String = _parked().style
	var wanted: String = CarChoice.stepped(before, 1, MeshCar.STYLES)
	_next_car().pressed.emit()
	assert_eq(_parked().style, wanted, "the bay did not park the next car along")
	assert_eq(_car_name().text, CarChoice.label_for(wanted), "the label did not follow the car")
	assert_eq(CarChoice.chosen, wanted, "the car on screen is not the car Play would open")


func test_the_back_arrow_goes_the_other_way() -> void:
	var before: String = _parked().style
	_previous_car().pressed.emit()
	assert_eq(
		_parked().style,
		CarChoice.stepped(before, -1, MeshCar.STYLES),
		"the left arrow parked the wrong car"
	)


func test_a_press_each_way_comes_back_to_the_car_it_started_on() -> void:
	var before: String = _parked().style
	_next_car().pressed.emit()
	_previous_car().pressed.emit()
	assert_eq(_parked().style, before, "there and back must be nowhere")
	assert_eq(_car_name().text, CarChoice.label_for(before), "and the label must agree")


func test_the_arrows_reach_all_ten_and_wrap() -> void:
	# The reason the step wraps rather than stopping: the list is alphabetical
	# because it is the pack's file names, so its ends mean nothing to a player.
	#
	# Panels as well as names, because the two fail differently. A style whose
	# model will not load leaves `MeshCar.style` saying exactly what was asked for
	# and a car with nothing hanging off it — `MeshCar._build` pushes an error and
	# carries on, which is the right thing for a game and invisible to a test that
	# only reads the readout. Ten presses is the one place every style in the pack
	# is actually built through the game's own path.
	var seen: Array[String] = []
	var start: String = _parked().style
	for _each: int in MeshCar.STYLES.size():
		_next_car().pressed.emit()
		var now: String = _parked().style
		assert_false(seen.has(now), "the arrows went round without showing all ten")
		assert_gt(_parked().panels().size(), 0, "the %s was parked as an empty car" % now)
		seen.append(now)
	assert_eq(seen.size(), MeshCar.STYLES.size(), "the arrows do not reach every car")
	assert_eq(_parked().style, start, "a full circuit must land back where it started")


func test_the_arrows_open_no_doors_and_make_no_noise() -> void:
	# A press a player is expected to make several of in a row. A bell on it would
	# be a fairground, and a transition on it would be the game starting because
	# somebody wanted a look at the pickup.
	_next_car().pressed.emit()
	_previous_car().pressed.emit()
	assert_eq(_requested.size(), 0, "looking at a car is not asking to play")
	assert_eq(_rung.size(), 0, "and it must not ring the bell that means the job started")
	assert_eq(_faded.size(), 0, "and it must not touch the theme")


func test_the_mud_goes_back_on_whichever_car_is_parked() -> void:
	# The half of the swap that is the room's rather than the car's. Every grime
	# mask is built against a panel's own box, so a swap that did not re-lay them
	# would leave the bay working a car that no longer exists — masks sized for the
	# old one, hanging off freed nodes. Two frames because `Garage._lay_on_the_grime`
	# deliberately waits one before it measures anything.
	_next_car().pressed.emit()
	await wait_process_frames(2)
	var grime: Grime = _garage().grime()
	assert_not_null(grime, "somebody is standing in this bay, so there is mud in it")
	if grime == null:
		return
	assert_true(grime.is_laid(), "the new car was parked clean and stayed that way")
	assert_eq(grime.panels(), _parked().panels(), "the mud is on a car that has left")


func test_both_arrows_are_big_enough_for_a_finger() -> void:
	# Same floor as the two pills, and the same bug: below it an arrow is about
	# 18 CSS px on a phone and most taps miss. This one is worth its own assertion
	# rather than folding into the pills' test, because the arrows are the controls
	# on this screen a player presses repeatedly.
	var minimum: float = TouchTarget.min_design_size()
	for arrow: CarArrow in [_previous_car(), _next_car()]:
		assert_gte(arrow.size.x, minimum, "%s is too narrow to hit on a phone" % arrow.name)
		assert_gte(arrow.size.y, minimum, "%s is too short to hit on a phone" % arrow.name)


func test_the_arrows_are_not_a_second_red_thing() -> void:
	# [constant Brand.RED] is worn by the thing you are meant to press and by
	# nothing else. An arrow is how you look rather than how you go, so it wears
	# what How to Play wears.
	for arrow: CarArrow in [_previous_car(), _next_car()]:
		var box: StyleBoxFlat = arrow.get_theme_stylebox("normal") as StyleBoxFlat
		assert_not_null(box, "%s must be a brand pill, not the theme's button" % arrow.name)
		if box == null:
			continue
		assert_eq(box.bg_color, Brand.PANEL, "%s must not compete with Play" % arrow.name)
		for state: String in ["normal", "hover", "pressed", "focus"]:
			assert_true(
				arrow.has_theme_stylebox_override(state),
				"%s's `%s` box must come from Brand" % [arrow.name, state]
			)


func test_the_arrows_stay_clear_of_the_column() -> void:
	# They are out at the screen's edges because there is no height for them in the
	# column — it already runs 645 of the design's 720 and the credit owns the last
	# 48 — so what has to hold is that they are on screen and not over the buttons
	# they sit beside. A press that landed on Play instead is the failure.
	var design: Vector2i = get_tree().root.content_scale_size
	for arrow: CarArrow in [_previous_car(), _next_car()]:
		var box: Rect2 = arrow.get_global_rect()
		assert_gte(box.position.x, 0.0, "%s runs off the side of the screen" % arrow.name)
		assert_lte(box.end.x, float(design.x), "%s runs off the other side" % arrow.name)
		assert_false(
			box.intersects(_play_button().get_global_rect()), "%s covers Play" % arrow.name
		)
		assert_false(
			box.intersects(_how_to_play_button().get_global_rect()),
			"%s covers How to Play" % arrow.name
		)


func test_the_car_name_is_legible_over_a_lit_driveway() -> void:
	# Same problem the credit line has and the same answer: the thing behind it is
	# tarmac, grass, sky and a car of whatever colour was drawn.
	var label: Label = _car_name()
	assert_eq(label.get_theme_color("font_color"), Brand.WHITE)
	assert_gt(label.get_theme_constant("outline_size"), 0, "type over the bay needs a shadow")
	assert_true(label.is_visible_in_tree(), "the name must be drawn")
	assert_gt(label.size.x, 0.0, "and laid out, not collapsed to nothing")


func test_the_font_can_draw_every_car_in_the_pack() -> void:
	# The tofu gate, aimed at the one label on this screen whose text is chosen by
	# a table rather than typed into the scene file. The ten shipping names are
	# plain ASCII and this is cheap; what it is really standing guard over is the
	# eleventh, added by somebody reaching for a "Coupé" or a "4×4".
	var font: Font = _car_name().get_theme_font("font")
	for style: String in MeshCar.STYLES:
		var label: String = CarChoice.label_for(style)
		for i: int in label.length():
			assert_true(
				font.has_char(label.unicode_at(i)),
				(
					"%s wants U+%04X, which %s cannot draw"
					% [label, label.unicode_at(i), font.get_font_name()]
				)
			)


func test_a_tap_on_an_arrow_actually_reaches_it() -> void:
	# Through a real touch rather than `pressed.emit()`, for the reason the sound
	# toggle's twin of this test gives: a full-rect container left at the engine's
	# default `mouse_filter` swallows the press before it ever arrives, and
	# `pressed.emit()` cannot see that. The arrows are new siblings of exactly such
	# a container — `Center`, which is `ignore` precisely so this works.
	#
	# The back arrow and not the forward one, and that is about the harness rather
	# than about the screen: GUT draws its own run output over the right half of
	# the window — measured at (652, 34) to (1266, 1181) against this design's
	# 1280x720 — and a control under it cannot be reached by a synthetic tap. The
	# two arrows are the same script in the same place in the tree, so the left one
	# answers the question for both. It is also why the suite next door taps Play
	# at x=640 and the sound toggle at x=94 rather than anything further right.
	var before: String = _parked().style
	_tap(_previous_car().get_global_rect().get_center())
	await wait_process_frames(1)
	assert_eq(
		_parked().style,
		CarChoice.stepped(before, -1, MeshCar.STYLES),
		"a tap on the arrow must reach the arrow"
	)


func test_the_car_in_the_showroom_is_the_car_the_game_opens_with() -> void:
	# #143 end to end, through the seam the issue named: whatever is standing in
	# the showroom has to reach [member MeshCar.style] before the bay the game is
	# played in enters the tree. Nothing is passed between the two screens — the
	# host frees one and builds the other (src/main/main.gd), and a screen never
	# names another — so [CarChoice] is the whole of what carries the answer
	# across, and this is the assertion that says so.
	#
	# Two presses rather than one, so a play screen that happened to draw the
	# menu's car cannot pass this by luck twice over.
	_next_car().pressed.emit()
	_next_car().pressed.emit()
	var wanted: String = _parked().style
	var packed: PackedScene = load(PLAY_SCREEN) as PackedScene
	assert_not_null(packed, "could not load %s" % PLAY_SCREEN)
	if packed == null:
		return
	var screen: GameScreen = packed.instantiate() as GameScreen
	add_child_autofree(screen)
	var bay: Garage = screen.get_node("Garage") as Garage
	var driven_off: MeshCar = bay.car() as MeshCar
	assert_not_null(driven_off, "the bay the game is played in must park one of the ten")
	if driven_off == null:
		return
	assert_eq(driven_off.style, wanted, "the game opened with a car nobody picked")
