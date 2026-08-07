## Integration test for the sound toggle as it sits on the play screen.
##
## Split out of [code]tests/integration/test_play_screen.gd[/code] for the same
## reason the tool belt and the motion pad already are: this is a fourth loop
## the screen owns and it fails for reasons of its own. What
## [code]tests/integration/test_sound_toggle.gd[/code] covers once — the size,
## the dressing, what a press does to [Sound] — is not repeated here. What is
## checked is that the control the play screen carries really is that class,
## sitting in the one corner none of the screen's own HUD reaches, and that
## pressing it does not leak into anything the room is doing.
extends GutTest

const PLAY_SCREEN: String = "res://src/screens/play_screen.tscn"

var _screen: GameScreen = null
var _muted_before: bool = false


func before_each() -> void:
	_muted_before = Sound.muted
	Sound.set_muted(false)
	var packed: PackedScene = load(PLAY_SCREEN) as PackedScene
	assert_not_null(packed, "could not load %s" % PLAY_SCREEN)
	if packed == null:
		return
	var screen: GameScreen = packed.instantiate() as GameScreen
	_screen = screen
	add_child_autofree(_screen)
	await wait_process_frames(1)


func after_each() -> void:
	Sound.set_muted(_muted_before)


func _sound_toggle() -> SoundToggle:
	return _screen.get_node("%Sound") as SoundToggle


func test_the_play_screen_carries_the_toggle() -> void:
	assert_not_null(_sound_toggle(), "the bay must offer the same sound toggle as the menus do")


func test_it_sits_clear_of_every_other_corner_control() -> void:
	# The belt owns bottom-left and the pad owns bottom-right — see
	# src/ui/sound_toggle.gd. Measured against the actual pressable shape each
	# one draws, not against its root [Control], which is anchored full-rect
	# over the whole screen the way every HUD layer in this game is (so a finger
	# past the belt's own corner still reaches the glass behind it) and would
	# report an "overlap" against everything on screen.
	var toggle: Rect2 = _sound_toggle().get_rect()
	var belt: ToolBeltHud = _screen.get_node("ToolBelt") as ToolBeltHud
	assert_false(
		toggle.intersects(belt.toggle_button().get_rect()), "the sound toggle overlaps the belt"
	)
	var pad: MotionPad = _screen.get_node("MotionPad") as MotionPad
	var stick: Rect2 = Rect2(
		pad.centre() - Vector2.ONE * pad.radius(), Vector2.ONE * pad.radius() * 2.0
	)
	assert_false(toggle.intersects(stick), "the sound toggle overlaps the motion pad")


func test_pressing_it_does_not_ask_the_host_for_anything() -> void:
	# Muting is entirely [Sound]'s business — nothing about it is a transition, a
	# bell or a music request, and a press that leaked into any of those would be
	# this button doing a second job nobody asked it for.
	var requested: Array[GameState] = []
	var rung: Array[Bell.Voice] = []
	var faded: Array[float] = []
	_screen.transition_requested.connect(func(state: GameState) -> void: requested.append(state))
	_screen.bell_requested.connect(func(voice: Bell.Voice) -> void: rung.append(voice))
	_screen.music_stop_requested.connect(func(seconds: float) -> void: faded.append(seconds))
	_sound_toggle().pressed.emit()
	assert_eq(requested.size(), 0, "muting must not change what screen is showing")
	assert_eq(rung.size(), 0, "muting must not ring the bell it just silenced")
	assert_eq(faded.size(), 0, "muting must not ask for a fade that is not its business")


func test_pressing_it_mutes_the_game_from_the_bay_too() -> void:
	_sound_toggle().pressed.emit()
	assert_true(Sound.muted, "the toggle must work from inside the game, not only from the menus")
