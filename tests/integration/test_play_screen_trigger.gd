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
##
## [b]This suite presses through [code]main.tscn[/code], and that is the whole
## point of it.[/b] Every other play-screen suite instances
## [code]play_screen.tscn[/code] on its own, which is right for asking what the
## room does with an aim and is exactly wrong for asking whether a press reaches
## the room at all — a screen hanging off a bare [CanvasLayer] has nothing
## underneath it, and the game has two full-rect [Control]s underneath it.
## Measured the hard way: a version of this feature passed a suite of its own
## while doing nothing whatsoever in the real game, because the press was landing
## in [code]%ScreenHost[/code] a layer below. So this one boots the real scene and
## walks in the way a player does — the title card's Start, then the menu's Play.
extends GutTest

const MAIN: String = "res://src/main/main.tscn"

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

var _main: Control = null
var _window_size_before: Vector2i = Vector2i.ZERO


func before_each() -> void:
	# A headless window is 64x64, which is smaller than one tap target — so every
	# screen coordinate below would be off the picture. `content_scale_size` is the
	# design resolution from project.godot. Put back in after_each: every suite
	# shares this window.
	var root: Window = get_tree().root
	_window_size_before = root.size
	root.size = root.content_scale_size
	var packed: PackedScene = load(MAIN) as PackedScene
	assert_not_null(packed, "could not load %s" % MAIN)
	if packed == null:
		return
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = ABOVE_THE_RUNNER
	add_child_autofree(layer)
	var main: Control = packed.instantiate() as Control
	_main = main
	layer.add_child(_main)
	await wait_process_frames(2)
	# In through the front door: `main.gd` is the only thing that loads a screen,
	# so the play screen is whatever Start put under the host rather than
	# something this test instanced behind the game's back.
	var title: GameScreen = _host().get_child(0) as GameScreen
	(title.get_node("%Start") as Button).pressed.emit()
	await wait_process_frames(2)
	# Start opens the menu; the menu's Arcade pill opens the game. Two presses
	# rather than one since #91 put a menu between the title card and the bay,
	# and Arcade rather than Play since #214 split that pill into the two modes.
	var menu: GameScreen = _host().get_child(0) as GameScreen
	(menu.get_node("%Arcade") as Button).pressed.emit()
	await wait_process_frames(2)


func after_each() -> void:
	# A finger left on the glass is global state: the next test would start with
	# something already aiming, and its failure would land nowhere near its cause.
	_lift()
	get_tree().root.size = _window_size_before


## Where [code]main.gd[/code] puts whichever screen the game is on — and, in this
## suite, one of the two full-rect controls that would swallow a press if the
## screen above it stopped claiming its own.
func _host() -> Control:
	return _main.get_node("%ScreenHost") as Control


func _screen() -> GameScreen:
	return _host().get_child(0) as GameScreen


func _garage() -> Garage:
	return _screen().get_node("Garage") as Garage


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
	return _screen().get_node("MotionPad") as MotionPad


## Where [param point] in the world lands on the glass. Through the camera's own
## projection rather than by writing pixels down, because the eye moves: the
## standoff eases it back a metre and a quarter during [method _settle].
func _on_screen(point: Vector3) -> Vector2:
	return _camera().unproject_position(point)


## The middle of the car, on the glass. The one press that must always land on
## bodywork.
func _at_the_car() -> Vector2:
	return _on_screen(_car().global_position)


## A different piece of the car, well away from [method _at_the_car] — what a
## second finger tries to steal the aim with. Somewhere it would visibly move the
## crosshair to if it succeeded, because a second press that happened to mark the
## same spot would let the theft through unnoticed.
func _at_the_bonnet() -> Vector2:
	return _on_screen(_car().global_position + Vector3(0.0, 0.15, 1.4))


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


# ---- does a press reach the room at all --------------------------------------


## The regression test for the bug this whole suite was restructured around: a
## press in the real scene stack has to reach the room.
##
## It reads like a tautology and it is not. The first version of this feature put
## the press in [method Node._unhandled_input] and set the play screen's root to
## [code]mouse_filter = ignore[/code] so the event would get there — which works
## when the screen is the only thing on the layer, and does nothing at all in the
## game, because [code]main.tscn[/code]'s [code]%ScreenHost[/code] is a plain
## [Control] at [code]stop[/code] sitting directly underneath and it swallowed
## every tap. Nothing in a suite that instances the screen by itself can see
## that. This can.
func test_a_press_through_the_real_scene_stack_reaches_the_car() -> void:
	await _settle()
	assert_false(_marker().is_marking(), "nothing is marked before the press")
	await _press(_at_the_car())
	assert_true(
		_marker().is_marking(),
		(
			"a press on the car marked nothing — something between the finger and the "
			+ (
				"room is eating it. Under the finger: %s"
				% [get_tree().root.gui_get_hovered_control()]
			)
		)
	)


## And the other half of it: the control that used to eat the press is still
## there, still full-rect, and still underneath. If somebody sets it to ignore
## the test above would pass for the wrong reason.
func test_the_screen_host_underneath_still_stops_what_it_is_handed() -> void:
	assert_eq(
		_host().mouse_filter,
		Control.MOUSE_FILTER_STOP,
		"the host still claims presses, so the screen above it has to claim its own"
	)


# ---- whose finger was it -----------------------------------------------------


func test_a_tap_on_the_motion_pad_is_not_an_aim() -> void:
	# The stick claims presses that land on it, and this is the half of that claim
	# only the real screen can show: a screen that also aimed on them would put a
	# crosshair on the car every time the player took a step. It works because the
	# pad takes the touch in [method Node._input], before the GUI hands it to the
	# screen underneath — so a pad that had merely stopped picking it up in the
	# right place would fail here rather than in a browser.
	await _settle()
	await _press(_pad().point_for(MotionPad.RIGHT))
	assert_true(_pad().is_held(), "the stick took the press")
	assert_false(_marker().is_marking(), "and the room was not asked to aim")


func test_walking_and_aiming_at_the_same_time_both_work() -> void:
	# The two-thumb case, and the whole reason this screen reads touch events
	# instead of the mouse the engine emulates from them: the engine only emulates
	# the *first* finger, so a thumb parked on the pad would otherwise make the
	# second finger produce no event at all.
	await _settle()
	var stick: Vector2 = _pad().point_for(MotionPad.RIGHT)
	var before: Vector3 = _camera().global_position
	_touch(stick, true)
	await wait_physics_frames(RESOLVE_FRAMES)
	await _press(_at_the_car())
	await wait_physics_frames(RESOLVE_FRAMES * 4)
	assert_true(_marker().is_marking(), "the second finger aimed")
	assert_gt(before.distance_to(_camera().global_position), 0.0, "while the first one walked")
	_touch(stick, false)


func test_a_second_finger_does_not_steal_the_aim() -> void:
	# Two fingers cannot aim one tool. The first one down keeps it until it lifts,
	# because the alternative is a crosshair that snaps between them.
	await _settle()
	await _press(_at_the_car())
	var first: Vector3 = _marker().marked_point()
	var second: InputEventScreenTouch = InputEventScreenTouch.new()
	second.index = 1
	second.position = _at_the_bonnet()
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
