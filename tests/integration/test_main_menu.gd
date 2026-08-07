## Integration test for the main menu: the lockup, the two pills, and which
## transition each of them asks for.
##
## Under tests/integration/ for [code]test_title_screen.gd[/code]'s reason —
## every fact here is established in `_ready()`, so nothing below can be
## asserted by loading the script alone.
##
## [b]What is deliberately not repeated from the title screen's suite.[/b] The
## build label and the attract bay are asserted here because they are promises
## this screen makes on its own account, but the shape of the brand pill, the
## touch-target arithmetic and the tap-versus-click behaviour are all
## [code]test_title_screen.gd[/code]'s, and the mechanism is shared —
## [method GameScreen.dress_loud] and one Button. What is tested here is what is
## different: that there are two of them, that they are dressed differently, and
## that they lead to different places.
extends GutTest

const MAIN_MENU: String = "res://src/screens/main_menu.tscn"

var _screen: GameScreen = null
var _requested: Array[GameState] = []
var _rung: Array[Bell.Voice] = []
var _faded: Array[float] = []
var _window_size_before: Vector2i = Vector2i.ZERO
var _muted_before: bool = false


func before_each() -> void:
	_requested = []
	_rung = []
	_faded = []
	# The menu's own toggle opens agreeing with whatever [Sound] was already at —
	# see src/ui/sound_toggle.gd — so a suite that left the game muted would open
	# this screen silenced too, for a reason that has nothing to do with this
	# one. Put back in after_each, like the window size below.
	_muted_before = Sound.muted
	Sound.set_muted(false)
	# A headless window is 64x64 — smaller than either button, small enough that
	# a tap at a button's own coordinates lands outside the layout entirely.
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
	# Instantiated into a typed local before handing it to add_child_autofree —
	# GUT's helper is untyped, and autofree is what keeps a failing assertion
	# below from being reported as a leak against whichever test runs next.
	var screen: GameScreen = packed.instantiate() as GameScreen
	_screen = screen
	add_child_autofree(_screen)
	_screen.transition_requested.connect(_record)
	_screen.bell_requested.connect(_record_bell)
	_screen.music_stop_requested.connect(_record_fade)
	# `_ready()` has already fired inside add_child; the frame is only here to
	# let layout settle before the sizes below are read.
	await wait_process_frames(1)


func after_each() -> void:
	get_tree().root.size = _window_size_before
	Sound.set_muted(_muted_before)


func _record(state: GameState) -> void:
	_requested.append(state)


func _record_bell(voice: Bell.Voice) -> void:
	_rung.append(voice)


func _record_fade(seconds: float) -> void:
	_faded.append(seconds)


func _play_button() -> Button:
	return _screen.get_node("%Play") as Button


func _how_to_play_button() -> Button:
	return _screen.get_node("%HowToPlay") as Button


func _sound_toggle() -> SoundToggle:
	return _screen.get_node("%Sound") as SoundToggle


func test_the_screen_is_a_game_screen() -> void:
	# The host casts to [GameScreen] and refuses anything else, so a scene that
	# lost its script would boot to an empty window.
	assert_not_null(_screen, "the main menu must instantiate as a GameScreen")


func test_it_is_played_over_the_bay_working_itself() -> void:
	# The menu is the title card with one more pill, and that includes what is
	# behind it: a flat panel here would be a screen the attract mode disappears
	# behind, one press after it was the best argument the game made for itself.
	var garage: Garage = _screen.get_node("Garage") as Garage
	assert_not_null(garage, "the menu is played over the real room, not a picture of it")
	if garage == null:
		return
	assert_true(garage.attracting, "the bay must still be working behind the menu")
	assert_true(garage.first_person, "and somebody must still be standing in it")


func test_build_label_shows_the_build_identity() -> void:
	# The label stays top-right across the new screen. Same promise the title
	# card makes, made again where a player now spends time before starting.
	var build: Label = _screen.get_node("%Build") as Label
	assert_eq(build.text, BuildInfo.describe())


func test_it_shows_the_business_logo() -> void:
	var logo: TextureRect = _screen.get_node("%Logo") as TextureRect
	assert_not_null(logo, "the menu must show the lockup, like the card before it")
	if logo == null:
		return
	assert_not_null(logo.texture, "the logo's texture must have imported")
	assert_gt(logo.size.x, 0.0, "and must be laid out, not collapsed to nothing")


func test_the_logo_is_framed_rather_than_pasted_on() -> void:
	# The artwork carries its own black background, so without the card it reads
	# as a hole cut in the garage behind it. [Brand.card] has that argument.
	var card: PanelContainer = _screen.get_node("%LogoCard") as PanelContainer
	var box: StyleBoxFlat = card.get_theme_stylebox("panel") as StyleBoxFlat
	assert_not_null(box, "the logo must sit in a brand card")
	if box == null:
		return
	assert_eq(box.bg_color, Brand.PANEL, "the card must be the site's panel colour")


# ---- the credit the cars arrive under ----------------------------------------


func test_the_car_pack_is_credited_where_a_player_can_read_it() -> void:
	# CC-BY 4.0 is the licence assets/models/cars/ arrives under and attribution
	# is a condition of it, not a courtesy. A file in the repository does not
	# discharge that — the person playing the game never sees one — so the credit
	# has to be on a screen, and this is the screen every player passes through.
	#
	# All three parts by name, because the licence asks for all three and a line
	# that lost one of them would still look like a credit: the title of the work,
	# who made it, and what licence it is under. Substrings rather than the whole
	# string, so the wording around them stays the .tscn's business.
	var credits: Label = _screen.get_node("%Credits") as Label
	assert_not_null(credits, "the menu must carry the credit for the cars")
	if credits == null:
		return
	for required: String in ["Generic passenger car pack", "Comrade1280", "CC BY 4.0"]:
		assert_string_contains(credits.text, required, "the credit must name %s" % required)


func test_the_credit_is_actually_on_the_screen() -> void:
	# A label with the right words in it, laid out off the bottom of the picture,
	# is not attribution. The design height rather than the window's, for the
	# reason the rules screen uses it: `window/stretch/aspect` is "expand", so a
	# taller screen gets more room and never less — a line that fits at the design
	# resolution fits everywhere.
	var credits: Label = _screen.get_node("%Credits") as Label
	assert_gt(credits.size.x, 0.0, "the credit must be laid out, not collapsed")
	var box: Rect2 = credits.get_global_rect()
	assert_gte(box.position.x, 0.0, "the credit runs off the left of the screen")
	var design: Vector2i = get_tree().root.content_scale_size
	assert_lte(box.end.y, float(design.y), "the credit is off the bottom of the picture")
	assert_true(credits.is_visible_in_tree(), "the credit must be drawn")


func test_the_font_can_draw_the_credit() -> void:
	# The same bug `tests/integration/test_how_to_play.gd` pins, in the one place
	# on this screen where the copy is not plain ASCII: this project ships no font
	# of its own, so every label is drawn in Godot's built-in Open Sans, and a
	# glyph it does not have is a tofu box in a released build rather than an error
	# anybody would see. The credit carries curly quotes and an em dash.
	var credits: Label = _screen.get_node("%Credits") as Label
	var font: Font = credits.get_theme_font("font")
	for i: int in credits.text.length():
		var glyph: int = credits.text.unicode_at(i)
		assert_true(
			font.has_char(glyph),
			(
				"the credit wants U+%04X (%s), which %s cannot draw"
				% [glyph, char(glyph), font.get_font_name()]
			)
		)


func test_the_credit_is_legible_over_a_lit_driveway() -> void:
	# It is laid over the bay working itself, which is tarmac, grass, sky and a
	# car of whatever colour was drawn — so muted grey on its own is legible
	# against about half of that. The outline is what makes it a promise rather
	# than a hope, and it is the same treatment the score wears over the same room.
	var credits: Label = _screen.get_node("%Credits") as Label
	assert_eq(credits.get_theme_color("font_color"), Brand.MUTED)
	assert_gt(credits.get_theme_constant("outline_size"), 0, "grey type needs a shadow here")


# ---- two buttons, and only one of them is the answer -------------------------


func test_it_offers_both_ways_on() -> void:
	assert_not_null(_play_button(), "the menu must offer Play")
	assert_not_null(_how_to_play_button(), "and How to Play")


func test_play_is_the_one_red_thing_on_the_screen() -> void:
	# The whole reason the second pill is dark. [constant Brand.RED] is the
	# site's one accent — worn by the thing you are meant to press and by
	# nothing else — and a menu with two of them leaves the eye nowhere to land.
	var loud: StyleBoxFlat = _play_button().get_theme_stylebox("normal") as StyleBoxFlat
	var quiet: StyleBoxFlat = _how_to_play_button().get_theme_stylebox("normal") as StyleBoxFlat
	assert_not_null(loud, "Play must be a brand pill, not the theme's button")
	assert_not_null(quiet, "How to Play must be a brand pill, not the theme's button")
	if loud == null or quiet == null:
		return
	assert_eq(loud.bg_color, Brand.RED, "Play is the answer, so Play is red")
	assert_eq(quiet.bg_color, Brand.PANEL, "How to Play is the card's colour, not a second accent")


func test_the_quiet_pill_still_has_an_edge() -> void:
	# A dark shape over a lit garage with no lit edge is a hole cut in the room
	# rather than a button sitting on it — [method Brand.quiet_pill]'s argument,
	# and the one thing that separates it from a rectangle of panel colour.
	var quiet: StyleBoxFlat = _how_to_play_button().get_theme_stylebox("normal") as StyleBoxFlat
	assert_eq(quiet.border_width_top, 1, "How to Play must carry the card's hairline")
	assert_eq(quiet.border_color, Brand.LINE)


func test_both_pills_are_round_ended_at_the_size_they_are_drawn() -> void:
	for button: Button in [_play_button(), _how_to_play_button()]:
		var box: StyleBoxFlat = button.get_theme_stylebox("normal") as StyleBoxFlat
		assert_eq(
			box.corner_radius_top_left,
			roundi(button.size.y / 2.0),
			"%s must be a pill at the size it is actually drawn" % button.name
		)


func test_every_face_of_every_button_is_dressed() -> void:
	# Hover and pressed fall back to the theme's grey if they are not overridden,
	# which would strand a default button at the one moment it is being used.
	for button: Button in [_play_button(), _how_to_play_button()]:
		for state: String in ["normal", "hover", "pressed", "focus"]:
			assert_true(
				button.has_theme_stylebox_override(state),
				"%s's `%s` box must come from Brand" % [button.name, state]
			)


func test_both_buttons_are_big_enough_for_a_finger() -> void:
	# The bug this pins is the one the title card already shipped: a button below
	# this floor is ~18 CSS px on a phone, and most taps miss it. [TouchTarget]
	# has the arithmetic and the sources.
	var minimum: float = TouchTarget.min_design_size()
	for button: Button in [_play_button(), _how_to_play_button()]:
		assert_gte(button.size.x, minimum, "%s is too narrow to hit on a phone" % button.name)
		assert_gte(button.size.y, minimum, "%s is too short to hit on a phone" % button.name)


func test_play_holds_the_focus_when_the_menu_opens() -> void:
	# So the flow is drivable from a keyboard or a pad without a mouse, and on
	# the button that is already drawn as the answer — a focus ring round the
	# quiet pill would disagree with the colour.
	assert_eq(
		_screen.get_viewport().gui_get_focus_owner(),
		_play_button(),
		"the menu must open with Play under the keyboard"
	)


# ---- where each of them leads ------------------------------------------------


func test_it_asks_for_nothing_on_its_own() -> void:
	assert_eq(_requested.size(), 0, "the menu must wait for the player")
	assert_eq(_rung.size(), 0, "and must not make a noise on its own account")
	assert_eq(_faded.size(), 0, "and must not touch the music it was handed")


func test_play_asks_for_the_play_state() -> void:
	# Through the button's own signal rather than by calling the handler, so a
	# connection dropped in `_ready()` fails here rather than in the browser.
	_play_button().pressed.emit()
	assert_eq(_requested.size(), 1, "Play must request exactly one transition")
	if _requested.size() != 1:
		return
	assert_true(_requested[0] is PlayGameState, "Play must open the game")


func test_how_to_play_asks_for_the_rules() -> void:
	_how_to_play_button().pressed.emit()
	assert_eq(_requested.size(), 1, "How to Play must request exactly one transition")
	if _requested.size() != 1:
		return
	assert_true(_requested[0] is HowToPlayGameState, "How to Play must open the rules")


func test_play_rings_the_counter_bell() -> void:
	# The ding moved here from the title card's Start when Start stopped opening
	# the game: [constant Bell.Voice.START] means the job starts, and this is
	# where the job starts.
	_play_button().pressed.emit()
	assert_eq(_rung, [Bell.Voice.START] as Array[Bell.Voice], "Play must ding once")


func test_play_asks_for_a_fade_rather_than_a_stop() -> void:
	_play_button().pressed.emit()
	assert_eq(_faded.size(), 1, "Play did not ask for the music to go")
	assert_almost_eq(_faded[0], Bandstand.FADE_SECONDS, 0.001, "Play cut the music dead")


func test_play_asks_for_the_fade_before_it_asks_to_leave() -> void:
	# `request_transition` frees this screen synchronously, so a fade asked for
	# afterwards would be emitted from a node on its way out. It survives either
	# way, because the host is already connected, but the version that does not
	# rely on that is the one that should stay.
	var order: Array[String] = []
	_screen.music_stop_requested.connect(func(_seconds: float) -> void: order.append("fade"))
	_screen.transition_requested.connect(func(_state: GameState) -> void: order.append("leave"))
	_play_button().pressed.emit()
	assert_eq(order, ["fade", "leave"] as Array[String])


func test_the_rules_are_reached_without_disturbing_the_theme() -> void:
	# The theme is supposed to carry across the menu and fade as the game opens,
	# so the long way round to the game must sound like no decision at all.
	_how_to_play_button().pressed.emit()
	assert_eq(_faded.size(), 0, "reading the rules must not stop the music")
	assert_eq(_rung.size(), 0, "and must not ring the bell that means the job started")


# ---- the sound toggle: carried over from the title card ----------------------
#
# The toggle's own size, dressing and effect on [Sound] are
# tests/integration/test_sound_toggle.gd's job. What is worth pinning here is
# that the choice a player made on the title card is still on offer one screen
# later, and that pressing it here is not mistaken for either of the two real
# doors this screen has.


func test_the_menu_offers_the_sound_toggle_too() -> void:
	assert_not_null(_sound_toggle(), "the menu must carry the same toggle the title card does")


func test_pressing_it_opens_neither_door() -> void:
	_sound_toggle().pressed.emit()
	assert_eq(_requested.size(), 0, "muting is not Play and it is not How to Play")
	assert_eq(_rung.size(), 0, "and it must not ring the bell that means the job started")
	assert_eq(_faded.size(), 0, "and it must not touch the theme it is about to silence")


# ---- touch: the phone-shaped half of "do these buttons work" -----------------


## Taps the screen at [param at], the way a finger does.
##
## Through `Input` rather than `Viewport.push_input()` for
## [code]test_title_screen.gd[/code]'s reason: nothing in `Button` reads a touch
## event, so what actually makes a tap work is the engine turning it into a click
## first, and that emulation lives in `Input`.
func _tap(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var touch: InputEventScreenTouch = InputEventScreenTouch.new()
		touch.position = at
		touch.pressed = pressed
		Input.parse_input_event(touch)
	Input.flush_buffered_events()


func test_a_tap_on_play_opens_the_game() -> void:
	_tap(_play_button().get_global_rect().get_center())
	await wait_process_frames(1)
	assert_eq(_requested.size(), 1, "a tap on Play must ask for the game")
	if _requested.size() != 1:
		return
	assert_true(_requested[0] is PlayGameState)


func test_a_tap_on_how_to_play_opens_the_rules() -> void:
	# The two pills are stacked and adjacent, so this is also the assertion that
	# a tap lands on the one under the finger rather than on the bigger one
	# above it.
	_tap(_how_to_play_button().get_global_rect().get_center())
	await wait_process_frames(1)
	assert_eq(_requested.size(), 1, "a tap on How to Play must ask for the rules")
	if _requested.size() != 1:
		return
	assert_true(_requested[0] is HowToPlayGameState)
