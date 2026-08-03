## Integration test for the noise a tool makes in the room it is used in: a press
## on the car runs the held tool's voice, letting go stops it, and the title
## screen — which is the same room with the game playing itself in it — stays
## silent.
##
## [b]Why a suite of its own.[/b] [code]tests/integration/test_tool_racket.gd[/code]
## is about the players and the fade, and it builds a [ToolRacket] by hand with no
## room around it. This is about the wiring: that [member Garage.noisy] decides
## whether a room has one at all, that a real press through
## [code]main.tscn[/code]'s own input path reaches it, and that the tool the
## player is holding is the one they hear. None of that is visible from either end
## on its own.
##
## [b]Everything goes through a real press[/b], for the same reason the jet's
## suite does: the room only answers a trigger it resolved from a ray, and a test
## that called [method Garage.aim_at] would be exercising a path the game does not
## have.
extends GutTest

const PLAY_SCREEN: String = "res://src/screens/play_screen.tscn"
const TITLE_SCREEN: String = "res://src/screens/title_screen.tscn"

## Above GUT's own output layer, so a finger aimed at the game lands on the game.
const ABOVE_THE_RUNNER: int = 200

## Enough physics ticks for a press to have been resolved into a mark, and so
## into a tool that is running.
const RESOLVE_FRAMES: int = 4

## Comfortably more frames than [constant ToolRacket.FADE_SECONDS] needs at any
## frame rate a test runner plausibly draws at — the racket's fade is stepped on
## the frame clock, so "is it sounding yet" is a question about drawn frames
## rather than about physics ticks.
const FADE_FRAMES: int = 20

var _screen: GameScreen = null
var _window_size_before: Vector2i = Vector2i.ZERO


func before_each() -> void:
	# A headless window is 64x64, which is smaller than one tap target — so every
	# screen coordinate below would be off the picture. Put back in after_each:
	# every suite shares this window.
	var root: Window = get_tree().root
	_window_size_before = root.size
	root.size = root.content_scale_size


func after_each() -> void:
	# A finger left on the glass is global state, and here it is also a sound left
	# running into the next test.
	if _screen != null:
		await _lift()
	get_tree().root.size = _window_size_before


## Opens [param scene] and waits for the room in it to be standing.
func _open(scene: String) -> void:
	var packed: PackedScene = load(scene) as PackedScene
	assert_not_null(packed, "could not load %s" % scene)
	if packed == null:
		return
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = ABOVE_THE_RUNNER
	add_child_autofree(layer)
	var screen: GameScreen = packed.instantiate() as GameScreen
	_screen = screen
	layer.add_child(_screen)
	await wait_process_frames(1)


func _garage() -> Garage:
	return _screen.get_node("Garage") as Garage


func _racket() -> ToolRacket:
	return _garage().tool_racket()


func _camera() -> Camera3D:
	return _garage().get_node("%Camera") as Camera3D


func _car() -> Car:
	return _garage().get_node("%Car") as Car


## The middle of the car, on the glass. The one press that always lands on
## bodywork.
func _at_the_car() -> Vector2:
	return _camera().unproject_position(_car().global_position)


func _touch(at: Vector2, pressed: bool) -> void:
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.position = at
	touch.pressed = pressed
	Input.parse_input_event(touch)
	Input.flush_buffered_events()


## Equips [param id], presses on the car and holds until the sound has faded in.
func _press_with(id: DetailingTool.Id) -> void:
	_garage().view_model().belt().equip(id)
	_touch(_at_the_car(), true)
	await wait_physics_frames(RESOLVE_FRAMES)
	await wait_process_frames(FADE_FRAMES)


func _lift() -> void:
	_touch(Vector2.ZERO, false)
	await wait_physics_frames(RESOLVE_FRAMES)
	await wait_process_frames(FADE_FRAMES)


# ---- which rooms can be heard ------------------------------------------------


func test_the_room_the_game_is_played_in_has_a_racket() -> void:
	await _open(PLAY_SCREEN)
	assert_not_null(_racket(), "the play screen's room cannot make a noise")


func test_the_title_screens_room_stays_silent() -> void:
	# The demo behind the title card works the car with all five tools. It rings no
	# bell and it runs no racket, for the same reason: audio is locked in a browser
	# until somebody has pressed something, and Start is that press. See
	# [member Garage.noisy].
	await _open(TITLE_SCREEN)
	assert_null(_racket(), "the title screen ran a pressure washer at nobody")


# ---- the trigger ------------------------------------------------------------


func test_nothing_is_heard_until_the_trigger_is_pulled() -> void:
	await _open(PLAY_SCREEN)
	await wait_process_frames(FADE_FRAMES)
	assert_false(_racket().is_making_a_noise(), "the room made a noise nobody asked for")


func test_pressing_on_the_car_runs_the_held_tool() -> void:
	await _open(PLAY_SCREEN)
	await _press_with(DetailingTool.Id.POWER_WASH)
	assert_true(_racket().is_running(), "the trigger did not reach the racket")
	assert_true(_racket().is_sounding(ToolNoise.Voice.WASH), "the water is not running")


func test_letting_go_of_the_car_stops_the_noise() -> void:
	# The release half, which the room answers on the same line it stops the water
	# and the mist on — see [method Garage._resolve_aim].
	await _open(PLAY_SCREEN)
	await _press_with(DetailingTool.Id.POWER_WASH)
	await _lift()
	assert_false(_racket().is_running(), "the release did not reach the racket")
	assert_false(_racket().is_making_a_noise(), "the water ran on after the finger came off")


func test_every_tool_is_heard_as_itself() -> void:
	# The whole belt through the room, rather than through [ToolRacket] alone: what
	# is being asserted is that the tool the player is holding is the tool the room
	# tells the racket about, on the tick it is holding it.
	await _open(PLAY_SCREEN)
	var voices: Dictionary[DetailingTool.Id, ToolNoise.Voice] = {
		DetailingTool.Id.POWER_WASH: ToolNoise.Voice.WASH,
		DetailingTool.Id.SPONGE: ToolNoise.Voice.SQUISH,
		DetailingTool.Id.DRYING_RAG: ToolNoise.Voice.RAG,
		DetailingTool.Id.WINDOW_CLEANER: ToolNoise.Voice.SPRAY,
		DetailingTool.Id.TIRE_ENGINE_CLEANER: ToolNoise.Voice.SPRAY,
	}
	for id: DetailingTool.Id in voices:
		await _press_with(id)
		assert_true(_racket().is_sounding(voices[id]), "tool %d is not heard as itself" % id)
		await _lift()


func test_a_tool_that_does_nothing_to_a_surface_is_still_heard() -> void:
	# The window cleaner on bodywork lays down no product — [method
	# Garage._spend_the_trigger] refuses the wrong bottle for a surface — and the
	# bottle still hisses, because a trigger that has been pulled has been pulled.
	# Silence would read as a broken tool rather than as the wrong one.
	await _open(PLAY_SCREEN)
	await _press_with(DetailingTool.Id.WINDOW_CLEANER)
	assert_true(_racket().is_sounding(ToolNoise.Voice.SPRAY), "the wrong bottle went quiet")


func test_the_debug_view_does_not_take_the_sound_away() -> void:
	# [member Garage.debug_tools] trades what a tool draws for a bare crosshair so
	# a bug in the drawing can be seen past. It is a switch about pictures: a
	# developer looking at where the aim landed has no reason to work in silence.
	await _open(PLAY_SCREEN)
	_garage().debug_tools = true
	await _press_with(DetailingTool.Id.POWER_WASH)
	assert_true(_racket().is_sounding(ToolNoise.Voice.WASH), "the debug view muted the game")
