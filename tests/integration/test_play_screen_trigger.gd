## Integration test for which presses are an aim and which belong to somebody
## else.
##
## Split from [code]test_play_screen_aim.gd[/code], which covers what a press
## does to the car — the mark, the swing and the clearance. This covers the
## plumbing underneath: whose finger it was, whether the HUD wanted it first, and
## whether a mouse at a desk gets the same treatment as a thumb. They fail for
## unrelated reasons, and together they were past [code].gdlintrc[/code]'s
## public-method cap, which is the same signal that split the walk out of the
## shot.
##
## [b]Most of what is here exists because the engine emulates a mouse from
## touch[/b], and only from the first finger. That is what makes the tool belt's
## [Button]s work on a phone at all, and it is also what would have made walking
## and aiming mutually exclusive — so the screen reads the touch events
## themselves and drops the emulated mice. Every test below is a way that could
## have gone wrong.
extends GutTest

const PLAY_SCREEN: String = "res://src/screens/play_screen.tscn"

## Above GUT's own output layer, so a finger aimed at the game lands on the game
## — the same measurement [code]test_play_screen_walk.gd[/code] records at
## length.
const ABOVE_THE_RUNNER: int = 200

## Close enough for positions in metres — a tenth of a millimetre.
const TOLERANCE: float = 0.0001

## Long enough for the standoff to have eased from the parked stance out to the
## gap the walk wants, so a press below lands on a settled camera. A second and a
## half; the walk suite explains the arithmetic.
const SETTLE_FRAMES: int = 90

## Enough physics ticks for a press to have been resolved into a mark, with room
## to spare. Two would do — the aim is answered on the next tick — and this is
## four because a test that is exactly tight enough goes red on a slow machine
## for a reason that has nothing to do with the code.
const RESOLVE_FRAMES: int = 4

## How far above the car's roof to press for a shot that is certainly sky. Three
## metres up is past the top of the frame's worth of car at every height the eye
## can be driven to, so the ray misses everything and the nearest-point fallback
## is what answers.
const ABOVE_THE_ROOF: float = 3.0

var _screen: GameScreen = null
var _window_size_before: Vector2i = Vector2i.ZERO


func before_each() -> void:
	# A headless window is 64x64, which is smaller than one tap target — so every
	# screen coordinate below would be off the picture. `content_scale_size` is the
	# design resolution from project.godot. Put back in after_each: every suite
	# shares this window.
	var root: Window = get_tree().root
	_window_size_before = root.size
	root.size = root.content_scale_size
	var packed: PackedScene = load(PLAY_SCREEN) as PackedScene
	assert_not_null(packed, "could not load %s" % PLAY_SCREEN)
	if packed == null:
		return
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = ABOVE_THE_RUNNER
	add_child_autofree(layer)
	var screen: GameScreen = packed.instantiate() as GameScreen
	_screen = screen
	layer.add_child(_screen)
	await wait_process_frames(1)


func after_each() -> void:
	# A finger left on the glass is global state: the next test would start with
	# something already aiming, and its failure would land nowhere near its cause.
	_lift()
	get_tree().root.size = _window_size_before


func _garage() -> Garage:
	return _screen.get_node("Garage") as Garage


func _camera() -> Camera3D:
	return _garage().get_node("%Camera") as Camera3D


## The sub-viewport the world is rendered into. Typed, because the camera's own
## `get_viewport()` is a plain [Viewport] as far as the compiler is concerned and
## only a [SubViewport] has a `size`.
func _view() -> SubViewport:
	return _garage().get_node("View") as SubViewport


func _car() -> Car:
	return _garage().get_node("%Car") as Car


func _marker() -> AimMarker:
	return _garage().aim_marker()


func _pad() -> MotionPad:
	return _screen.get_node("MotionPad") as MotionPad


## Where [param point] in the world lands on the glass. Through the camera's own
## projection rather than by writing pixels down, because the eye moves: the
## standoff eases it back a metre and a quarter during [method _settle].
func _on_screen(point: Vector3) -> Vector2:
	return _camera().unproject_position(point)


## The middle of the car, on the glass. The one press that must always land on
## bodywork.
func _at_the_car() -> Vector2:
	return _on_screen(_car().global_position)


## A patch of sky above the roof, on the glass — a press that hits nothing at all
## and has to be answered by the nearest-point fallback.
func _at_the_sky() -> Vector2:
	return _on_screen(_car().global_position + Vector3.UP * ABOVE_THE_ROOF)


## Puts a finger on the glass at [param at], or takes it off again.
##
## Through [method Input.parse_input_event] and not [method Viewport.push_input],
## for the reason the walk suite gives: this is the path a real tap takes,
## emulated mouse and all, so it exercises the de-duplication in the screen
## rather than a parallel route around it.
func _touch(at: Vector2, pressed: bool) -> void:
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.position = at
	touch.pressed = pressed
	Input.parse_input_event(touch)
	Input.flush_buffered_events()


## Presses at [param at] and waits for the room to have answered.
func _press(at: Vector2) -> void:
	_touch(at, true)
	await wait_physics_frames(RESOLVE_FRAMES)


## Lifts the finger and waits for the room to have noticed.
func _lift() -> void:
	_touch(Vector2.ZERO, false)
	await wait_physics_frames(RESOLVE_FRAMES)


## Lets the standoff ease out to the gap it wants, so a press below lands on a
## settled camera rather than one still arriving.
func _settle() -> void:
	await wait_physics_frames(SETTLE_FRAMES)


# ---- whose finger was it -----------------------------------------------------


func test_a_tap_on_the_motion_pad_is_not_an_aim() -> void:
	# The pad's arrows are their own controls and get their own taps. A screen that
	# also aimed on them would put a crosshair on the car every time the player
	# took a step.
	await _settle()
	var arrow: Button = _pad().button_for(MotionPad.RIGHT)
	await _press(arrow.get_global_rect().get_center())
	assert_true(arrow.button_pressed, "the arrow took the press")
	assert_false(_marker().is_marking(), "and the room was not asked to aim")


func test_walking_and_aiming_at_the_same_time_both_work() -> void:
	# The two-thumb case, and the whole reason this screen reads touch events
	# instead of the mouse the engine emulates from them: the engine only emulates
	# the *first* finger, so a thumb parked on the pad would otherwise make the
	# second finger produce no event at all.
	await _settle()
	var arrow: Button = _pad().button_for(MotionPad.RIGHT)
	var before: Vector3 = _camera().global_position
	_touch(arrow.get_global_rect().get_center(), true)
	await wait_physics_frames(RESOLVE_FRAMES)
	await _press(_at_the_car())
	await wait_physics_frames(RESOLVE_FRAMES * 4)
	assert_true(_marker().is_marking(), "the second finger aimed")
	assert_gt(before.distance_to(_camera().global_position), 0.0, "while the first one walked")
	_touch(arrow.get_global_rect().get_center(), false)


func test_a_second_finger_does_not_steal_the_aim() -> void:
	# Two fingers cannot aim one tool. The first one down keeps it until it lifts,
	# because the alternative is a crosshair that snaps between them.
	await _settle()
	await _press(_at_the_car())
	var first: Vector3 = _marker().marked_point()
	var second: InputEventScreenTouch = InputEventScreenTouch.new()
	second.index = 1
	second.position = _at_the_sky()
	second.pressed = true
	Input.parse_input_event(second)
	Input.flush_buffered_events()
	await wait_physics_frames(RESOLVE_FRAMES)
	assert_almost_eq(_marker().marked_point(), first, Vector3.ONE * TOLERANCE)
	second.pressed = false
	Input.parse_input_event(second)
	Input.flush_buffered_events()
	await wait_physics_frames(RESOLVE_FRAMES)
	assert_true(_marker().is_marking(), "and the second one lifting does not end the aim either")


# ---- the desk ----------------------------------------------------------------


func test_a_mouse_aims_too() -> void:
	# Nobody at a desk is going to enjoy a game that only responds to fingers, and
	# the mouse path is separate code — the emulated-mouse filter that makes two
	# thumbs work is exactly what would break a real one if it were written wrong.
	await _settle()
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = _at_the_car()
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	await wait_physics_frames(RESOLVE_FRAMES)
	assert_true(_marker().is_marking(), "a click marks the car")
	click.pressed = false
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	await wait_physics_frames(RESOLVE_FRAMES)
	assert_false(_marker().is_marking(), "and releasing it puts the mark away")


# ---- the room the title screen is ---------------------------------------------


func test_the_title_screens_room_has_nothing_to_aim() -> void:
	# The same scene, without a player in it. A crosshair appearing on the car
	# behind the title card would read as a rendering bug, and the showcase orbit
	# has nobody standing behind it to have pressed anything.
	var packed: PackedScene = load("res://src/world/garage.tscn") as PackedScene
	var showcase: Garage = packed.instantiate() as Garage
	add_child_autofree(showcase)
	await wait_physics_frames(RESOLVE_FRAMES)
	assert_null(showcase.aim_marker(), "no crosshair was built")
	assert_null(showcase.view_model().aim(), "and the hidden hand has no aim to swing on")
	showcase.aim_at(Vector2(100.0, 100.0))
	await wait_physics_frames(RESOLVE_FRAMES)
	assert_null(showcase.aim_marker(), "and asking it to aim does nothing at all")
