## Integration test for the title screen.
##
## Under tests/integration/ because every one of these facts is established in
## `_ready()` — the build label is filled and the button is wired only once the
## scene is in a tree. Nothing here can be asserted by loading the script alone.
##
## The build label assertion moved here from the entry-scene test when the title
## card became a state of its own; it is the same promise as before, made
## where the text now lives.
extends GutTest

const TITLE_SCREEN: String = "res://src/screens/title_screen.tscn"

var _screen: GameScreen = null
var _requested: Array[GameState] = []
var _rung: Array[Bell.Voice] = []
var _window_size_before: Vector2i = Vector2i.ZERO
var _muted_before: bool = false


func before_each() -> void:
	_requested = []
	_rung = []
	# The toggle below opens agreeing with whatever [Sound] was already at — see
	# src/ui/sound_toggle.gd — so a suite that left the game muted would open
	# every screen after it silenced, for a reason that has nothing to do with
	# this one. Put back in after_each, like the window size below.
	_muted_before = Sound.muted
	Sound.set_muted(false)
	# A headless window is 64x64 — smaller than the Start button, small enough
	# that a tap at the button's own coordinates lands outside the layout
	# entirely, and the touch tests below then pass or fail for a reason that has
	# nothing to do with the game. `content_scale_size` is the design resolution
	# from project.godot, so this makes a coordinate in this file mean what it
	# means on screen. Put back in after_each: every suite shares this window.
	var root: Window = get_tree().root
	_window_size_before = root.size
	root.size = root.content_scale_size
	var packed: PackedScene = load(TITLE_SCREEN) as PackedScene
	assert_not_null(packed, "could not load %s" % TITLE_SCREEN)
	if packed == null:
		return
	# Instantiate into a typed local before handing it to add_child_autofree —
	# GUT's helper is untyped, and autofree is what keeps a failing assertion
	# below from being reported as a leak against whichever test runs next.
	var screen: GameScreen = packed.instantiate() as GameScreen
	_screen = screen
	add_child_autofree(_screen)
	_screen.transition_requested.connect(_record)
	# The screen asks for a bell rather than playing one — the host owns the
	# [Chime], and a screen instanced on its own like this one has no host. So
	# what a suite at this level can assert is the ask, and
	# `tests/integration/test_main_scene.gd` asserts that the ask makes a noise.
	_screen.bell_requested.connect(_record_bell)
	# `_ready()` has already fired inside add_child; the frame is only here to
	# let layout settle before the labels are read.
	await wait_process_frames(1)


func after_each() -> void:
	get_tree().root.size = _window_size_before
	Sound.set_muted(_muted_before)


func _record(state: GameState) -> void:
	_requested.append(state)


func _record_bell(voice: Bell.Voice) -> void:
	_rung.append(voice)


func _start_button() -> Button:
	return _screen.get_node("%Start") as Button


func _sound_toggle() -> SoundToggle:
	return _screen.get_node("%Sound") as SoundToggle


func _garage() -> Garage:
	return _screen.get_node("Garage") as Garage


func test_the_screen_is_a_game_screen() -> void:
	# The host casts to [GameScreen] and refuses anything else, so a scene that
	# lost its script would boot to an empty window.
	assert_not_null(_screen, "the title screen must instantiate as a GameScreen")


func test_it_shows_the_garage_behind_the_title() -> void:
	assert_not_null(_garage(), "the title screen is played over the real room, not a picture of it")


func test_the_title_screen_plays_the_game_behind_the_card() -> void:
	# It used to circle a clean car from outside, which showed the car off and could
	# not show a tool working — there is nobody in that shot to hold one. What is
	# behind the card now is the game playing itself. This is the switch; what it
	# actually does is [code]tests/integration/test_title_screen_attract.gd[/code].
	assert_true(_garage().attracting, "the title screen shows the job being done, not a still")
	assert_true(_garage().first_person, "and somebody standing in the bay doing it")


func test_build_label_shows_the_build_identity() -> void:
	# The on-screen build line and the stdout line CI greps must agree; if this
	# drifts, the "I can see which commit this build is" promise quietly dies.
	var build: Label = _screen.get_node("%Build") as Label
	assert_eq(build.text, BuildInfo.describe())


func test_it_offers_a_start_button() -> void:
	assert_not_null(_start_button(), "the title screen must have a Start button")


# ---- the brand: the logo, and the pill under it ------------------------------


func test_it_shows_the_business_logo() -> void:
	# The picture is the first thing anyone sees of Done Rite, in the game and on
	# the site both. A texture lost to a moved file or a dropped .import leaves a
	# blank card and nothing else complaining.
	var logo: TextureRect = _screen.get_node("%Logo") as TextureRect
	assert_not_null(logo, "the title screen must show the logo")
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


func test_start_wears_the_brand_pill() -> void:
	# The styling is applied in `_ready()` from [Brand], so this is where a
	# dropped override shows up — the scene alone would still lay out a
	# default-grey button and pass every other test in this file.
	var normal: StyleBoxFlat = _start_button().get_theme_stylebox("normal") as StyleBoxFlat
	assert_not_null(normal, "Start must be a brand pill, not the theme's button")
	if normal == null:
		return
	assert_eq(normal.bg_color, Brand.RED, "Start is the one red thing on the screen")
	assert_eq(
		normal.corner_radius_top_left,
		roundi(_start_button().size.y / 2.0),
		"Start must be round-ended at the size it is actually drawn"
	)


func test_every_face_of_start_is_dressed() -> void:
	# Hover and pressed fall back to the theme's grey if they are not overridden,
	# which would strand the default button at the one moment it is being used.
	var start: Button = _start_button()
	for state: String in ["normal", "hover", "pressed", "focus"]:
		assert_true(
			start.has_theme_stylebox_override(state),
			"Start's `%s` box must come from Brand" % state
		)


func test_start_asks_for_the_menu() -> void:
	# Through the button's own signal rather than by calling the handler, so a
	# connection dropped in `_ready()` fails here rather than in the browser.
	#
	# It used to lead straight into [PlayGameState], and the reason it no longer
	# does is that there is now a second thing to offer — the rules — and a title
	# card is the wrong place to hang a second door off.
	_start_button().pressed.emit()
	assert_eq(_requested.size(), 1, "Start must request exactly one transition")
	if _requested.size() != 1:
		return
	assert_true(_requested[0] is MainMenuGameState, "Start must open the menu")
	assert_false(_requested[0] is PlayGameState, "and must not open the game itself")


func test_it_asks_for_nothing_on_its_own() -> void:
	assert_eq(_requested.size(), 0, "the title screen must wait for the player")
	assert_eq(_rung.size(), 0, "and must not make a noise before it is touched")


func test_start_no_longer_rings_the_counter_bell() -> void:
	# The ding moved to the menu's Play along with the music's fade.
	# [constant Bell.Voice.START] means the job starts, and pressing Start no
	# longer starts a job — see `tests/integration/test_main_menu.gd`, which is
	# where the same assertion now lives in the positive.
	#
	# The press is still the one that unlocks the browser's audio; what answers
	# it is the theme coming up, which is
	# `tests/integration/test_title_screen_music.gd`'s.
	_start_button().pressed.emit()
	assert_eq(_rung.size(), 0, "the bell belongs to the press that starts the job")


# ---- the sound toggle: the first of the three corners it sits in -------------
#
# The toggle's own size, dressing and effect on [Sound] are
# tests/integration/test_sound_toggle.gd's job. What is worth pinning here is
# that the title card actually carries one, and that pressing it is not
# mistaken by this screen for the press that starts the theme and opens the
# menu.


func test_the_title_card_offers_the_sound_toggle() -> void:
	assert_not_null(_sound_toggle(), "the title screen must offer a way to mute before Start")


func test_pressing_it_does_not_ask_for_the_menu() -> void:
	_sound_toggle().pressed.emit()
	assert_eq(_requested.size(), 0, "muting is not starting")


# ---- touch: the phone-shaped half of "does Start work" -----------------------


## Taps the screen at [param at], the way a finger does: a touch event, not the
## mouse click a desktop test would send.
##
## Through `Input` rather than `Viewport.push_input()` deliberately. Nothing in
## `Button` reads a touch event — `BaseButton` handles mouse buttons and
## `ui_accept` and nothing else — so what actually makes a tap work is the
## engine turning it into a click first, and that emulation lives in `Input`.
## Pushing the touch straight at the viewport would skip the exact step this
## test exists to prove, and pass while the game was broken.
func _tap(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var touch: InputEventScreenTouch = InputEventScreenTouch.new()
		touch.position = at
		touch.pressed = pressed
		Input.parse_input_event(touch)
	Input.flush_buffered_events()


func test_a_tap_on_start_asks_for_the_menu() -> void:
	_tap(_start_button().get_global_rect().get_center())
	await wait_process_frames(1)
	assert_eq(_requested.size(), 1, "a tap on Start must ask for the menu")


func test_start_is_big_enough_for_a_finger() -> void:
	# The bug this pins: the button was 220x56 design px, which is ~70x18 CSS px
	# on a phone — measured in a browser, where most taps missed it and the game
	# looked dead. [TouchTarget] has the arithmetic and the sources.
	var start: Button = _start_button()
	var minimum: float = TouchTarget.min_design_size()
	assert_gte(start.size.x, minimum, "Start is too narrow to hit on a phone")
	assert_gte(start.size.y, minimum, "Start is too short to hit on a phone")


func test_a_tap_on_start_unlocks_the_audio_without_ringing() -> void:
	# The phone-shaped half of the press that used to ding. This is still the
	# gesture a browser unlocks audio on — see [Chime] — and what it now answers
	# with is the theme rather than the counter bell, so the promise the rest of
	# the game's sound rides on is `music_requested` and not `bell_requested`.
	var asked: Array[int] = []
	_screen.music_requested.connect(func() -> void: asked.append(1))
	_tap(_start_button().get_global_rect().get_center())
	await wait_process_frames(1)
	assert_eq(asked.size(), 1, "a tap on Start must still unlock the audio")
	assert_eq(_rung.size(), 0, "but must not ring a job that has not started")


func test_a_tap_just_outside_start_asks_for_nothing() -> void:
	# The other half of the same promise: a target big enough to hit is only
	# useful if it is still the player who decides when to press it.
	var start: Button = _start_button()
	var below: Vector2 = start.get_global_rect().get_center() + Vector2(0, start.size.y)
	_tap(below)
	await wait_process_frames(1)
	assert_eq(_requested.size(), 0, "only Start starts the game")
