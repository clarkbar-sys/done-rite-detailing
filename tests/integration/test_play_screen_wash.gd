## Integration test for the trigger doing something: a held press with the power
## wash in hand takes mud off the car.
##
## [b]Through [code]main.tscn[/code], like [code]test_play_screen_trigger.gd[/code][/b]
## and for the same reason — a screen instanced on its own has nothing underneath
## it and the game has two full-rect [Control]s underneath it, so a suite that
## skips the real stack can pass while the feature does nothing whatsoever in the
## game. That has already happened once here; the trigger suite's class docs
## record it.
##
## What is asserted is the wiring and the rules, not the arithmetic: that water
## reaches the paint at all, that only the right tool spends it, that a press
## past the car does not, and that letting go stops it. Where the water lands in
## the texture is [code]tests/unit/test_box_projection.gd[/code], and what it does
## when it gets there is [code]tests/unit/test_grime_map.gd[/code].
extends GutTest

const MAIN: String = "res://src/main/main.tscn"

## Above GUT's own output layer, so a finger aimed at the game lands on the game.
const ABOVE_THE_RUNNER: int = 200

## Long enough for the standoff to have eased out to the gap the walk wants, so a
## press lands on a settled camera.
const SETTLE_FRAMES: int = 90

## Enough physics ticks for a press to have been resolved into a mark.
const RESOLVE_FRAMES: int = 4

## A second of held trigger, which at [member Garage.wash_per_second] is most of
## the way through the mud under the jet. Long enough that the assertions below
## are about whether water is flowing rather than about how fast.
const WASH_FRAMES: int = 60

var _main: Control = null
var _window_size_before: Vector2i = Vector2i.ZERO


func before_each() -> void:
	# A headless window is 64x64, which is smaller than one tap target. Put back
	# in after_each: every suite shares this window.
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
	var title: GameScreen = _host().get_child(0) as GameScreen
	(title.get_node("%Start") as Button).pressed.emit()
	await wait_process_frames(2)


func after_each() -> void:
	_lift()
	get_tree().root.size = _window_size_before


func _host() -> Control:
	return _main.get_node("%ScreenHost") as Control


func _screen() -> GameScreen:
	return _host().get_child(0) as GameScreen


func _garage() -> Garage:
	return _screen().get_node("Garage") as Garage


func _camera() -> Camera3D:
	return _garage().get_node("%Camera") as Camera3D


func _car() -> Car:
	return _garage().get_node("%Car") as Car


func _grime() -> Grime:
	return _garage().grime()


func _marker() -> AimMarker:
	return _garage().aim_marker()


func _masks() -> GrimeDebug:
	return _screen().get_node("GrimeDebug") as GrimeDebug


func _belt() -> ToolBelt:
	return _garage().view_model().belt()


func _on_screen(point: Vector3) -> Vector2:
	return _camera().unproject_position(point)


## The middle of the car, on the glass — the one press that must always land on
## bodywork.
func _at_the_car() -> Vector2:
	return _on_screen(_car().global_position)


## Just over the roof: a press that hits nothing, and so one the room answers
## with the nearest bodywork rather than with a hit.
##
## Measured off the car's own bounding box rather than written down as an offset.
## A press has to clear the roof to miss and stay in frame to be a press at all,
## and the gap between those two is small — half a metre higher than this is off
## the top of a 720-line frame, which is a test that fails for a reason that has
## nothing to do with washing.
func _at_the_sky() -> Vector2:
	var middle: Vector3 = _car().global_position
	return _on_screen(Vector3(middle.x, _car().bounds().end.y + 0.3, middle.z))


func _touch(at: Vector2, pressed: bool) -> void:
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.position = at
	touch.pressed = pressed
	Input.parse_input_event(touch)
	Input.flush_buffered_events()


## Holds the trigger at [param at] for a second, without letting go — so a test
## can still ask what is marked. [method after_each] lifts it.
func _press(at: Vector2) -> void:
	_touch(at, true)
	await wait_physics_frames(WASH_FRAMES)


## Holds the trigger at [param at] for a second and lets go.
func _hold(at: Vector2) -> void:
	await _press(at)
	_touch(Vector2.ZERO, false)
	await wait_physics_frames(RESOLVE_FRAMES)


func _lift() -> void:
	_touch(Vector2.ZERO, false)
	await wait_physics_frames(RESOLVE_FRAMES)


func _settle() -> void:
	await wait_physics_frames(SETTLE_FRAMES)


# ---- is there mud at all -----------------------------------------------------


func test_the_car_starts_filthy_and_the_room_says_when_it_is() -> void:
	# The frame's wait, from the outside. `Garage` lays the grime on a process
	# frame after `_ready` because a panel has no size before then, and the signal
	# is how anything downstream finds out — a view that bound early would draw an
	# empty grid all game.
	await _settle()
	assert_not_null(_grime(), "the room built no grime")
	assert_true(_grime().is_laid(), "and never laid it on the car")
	assert_almost_eq(_grime().remaining(), 1.0, 0.0001, "a fresh car is entirely dirty")


# ---- does the trigger spend anything -----------------------------------------


func test_holding_the_power_wash_on_the_car_takes_mud_off() -> void:
	# The whole feature, end to end and through the real scene stack: a thumb on
	# the glass, a ray, a panel, a projection, and a texel that is cleaner than it
	# was. Exact rather than approximate — the car starts at exactly 1.0, so any
	# water at all makes this strictly less.
	await _settle()
	assert_eq(_belt().equipped().id, DetailingTool.Id.POWER_WASH, "the wash is what you start with")
	await _hold(_at_the_car())
	assert_lt(_grime().remaining(), 1.0, "a second of water changed nothing on the car")


func test_letting_go_stops_the_water() -> void:
	await _settle()
	await _hold(_at_the_car())
	var after: float = _grime().remaining()
	await wait_physics_frames(WASH_FRAMES)
	assert_almost_eq(
		_grime().remaining(), after, 0.0000001, "the water kept running after the lift"
	)


func test_a_press_past_the_car_marks_it_without_washing_it() -> void:
	# The crosshair snaps to the nearest bodywork when a press hits nothing,
	# because "nothing" is not a useful thing to mark — but that post is assembled
	# out of bounding boxes rather than a place water went. Washing there would
	# let a player clean the car by pointing at the sky beside it.
	# Held rather than held-and-released: letting go puts the mark away, so a test
	# that lifted first would be asserting on an empty crosshair and passing for
	# the wrong reason.
	await _settle()
	await _press(_at_the_sky())
	assert_true(_marker().is_marking(), "the press still marked the nearest bodywork")
	assert_almost_eq(_grime().remaining(), 1.0, 0.0001, "and pointing at the sky washed the car")


func test_only_the_power_wash_spends_the_trigger() -> void:
	# Four of the five tools have nothing to write to yet. A sponge that quietly
	# washed mud off would be the wrong rule shipped invisibly — the sponge works
	# on the layer under the mud, and only once the mud is gone.
	await _settle()
	_belt().equip(DetailingTool.Id.SPONGE)
	await _hold(_at_the_car())
	assert_almost_eq(_grime().remaining(), 1.0, 0.0001, "the sponge washed mud off")


func test_swapping_back_to_the_wash_starts_the_water_again() -> void:
	# And the other half of it, so the test above cannot pass because the trigger
	# is broken for everything.
	await _settle()
	_belt().equip(DetailingTool.Id.SPONGE)
	await _hold(_at_the_car())
	_belt().equip(DetailingTool.Id.POWER_WASH)
	await _hold(_at_the_car())
	assert_lt(_grime().remaining(), 1.0)


# ---- the debug view ----------------------------------------------------------


func test_the_masks_are_bound_but_out_of_the_way() -> void:
	# Built from the room's own maps rather than from a set of its own, and hidden
	# until asked for: it is a developer's view of a texture, and a player who has
	# never pressed G should never see it.
	await _settle()
	assert_false(_masks().is_shown(), "the masks are up without being asked for")
	assert_eq(
		_masks().get_node("Margin/Stack/%Masks").get_child_count(),
		_car().panels().size(),
		"one thumbnail per panel"
	)


func test_the_masks_can_be_put_up_and_taken_down() -> void:
	await _settle()
	_masks().toggle()
	assert_true(_masks().is_shown())
	_masks().toggle()
	assert_false(_masks().is_shown())


func test_the_masks_do_not_eat_the_press_underneath_them() -> void:
	# A picture and not a control. The overlay sits in the corner of the same
	# screen the player aims through, so anything it claimed would be water that
	# never reached the car.
	await _settle()
	_masks().set_shown(true)
	await wait_process_frames(1)
	assert_eq(_masks().mouse_filter, Control.MOUSE_FILTER_IGNORE)
	await _hold(_at_the_car())
	assert_lt(_grime().remaining(), 1.0, "the masks swallowed the press")
