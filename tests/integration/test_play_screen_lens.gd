## Integration test for the lens: what the room actually does to the shot when
## the window it is drawn into is the wrong shape for it.
##
## Split out of [code]test_play_screen.gd[/code] for the reason the walk suite
## was — that file covers where the eye stands, this one covers what the eye can
## see, they fail for unrelated reasons, and one file was near `.gdlintrc`'s
## public-method cap.
##
## [b]Everything here resizes the window[/b], which no other suite does, and that
## is the whole point: the bug this guards against is invisible at the design
## resolution and only appears on a phone held upright. The arithmetic is
## [code]tests/unit/test_lens_fit.gd[/code]'s job; what is here is whether a real
## viewport, a real camera and a real held tool agree with it.
extends GutTest

const PLAY_SCREEN: String = "res://src/screens/play_screen.tscn"

## A Pixel 7 in a portrait browser is 411x838 CSS px, which is below the floor a
## headless window will accept — measured, it clamps to 64x64 and the stretch
## maths then produces a square viewport that proves nothing. This is the same
## aspect at twice the size, and it lands on the identical 1280x2609 viewport the
## real phone gets, which is asserted below rather than hoped for.
const PORTRAIT: Vector2i = Vector2i(822, 1676)

## What that phone's viewport comes out as, once `window/stretch/aspect` has
## expanded the 1280x720 design resolution into it.
const PHONE_VIEWPORT: Vector2i = Vector2i(1280, 2609)

## Degrees, close enough for a camera.
const TOLERANCE: float = 0.05

## Long enough for a resize to have reached the container, the sub-viewport and
## the camera. It is a signal chain, not a poll.
const RESIZE_FRAMES: int = 5

var _screen: GameScreen = null
var _window_size_before: Vector2i = Vector2i.ZERO


func before_each() -> void:
	var root: Window = get_tree().root
	_window_size_before = root.size
	# The design resolution, so every test starts from the shot as it was framed
	# and the portrait ones are visibly a departure from it.
	root.size = root.content_scale_size
	await wait_process_frames(RESIZE_FRAMES)
	var packed: PackedScene = load(PLAY_SCREEN) as PackedScene
	assert_not_null(packed, "could not load %s" % PLAY_SCREEN)
	if packed == null:
		return
	var screen: GameScreen = packed.instantiate() as GameScreen
	_screen = screen
	add_child_autofree(_screen)
	await wait_process_frames(RESIZE_FRAMES)


func after_each() -> void:
	# Every suite shares this window, and a test that left it portrait would
	# reframe whatever ran next.
	get_tree().root.size = _window_size_before


func _garage() -> Garage:
	return _screen.get_node("Garage") as Garage


## Typed as [Lens] rather than [Camera3D]: the ceiling under test is that script's
## export, and naming the class here is also what maps it to a test for
## `scripts/check-test-map.sh`.
func _lens() -> Lens:
	return _garage().get_node("%Camera") as Lens


func _view_model() -> Node3D:
	return _garage().get_node("%ViewModel") as Node3D


func _frame() -> Vector2:
	return _lens().get_viewport().get_visible_rect().size


## The vertical field of view the shot currently has — the angle that is being
## promised, as opposed to [member Camera3D.fov], which is the horizontal one
## being set to keep the promise.
func _vertical_fov() -> float:
	var frame: Vector2 = _frame()
	return LensFit.vertical_fov(_lens().fov, frame.x / frame.y)


## Turns the window portrait and lets the resize reach the camera.
func _hold_the_phone_upright() -> void:
	get_tree().root.size = PORTRAIT
	await wait_process_frames(RESIZE_FRAMES)


func test_the_phone_really_does_produce_the_viewport_this_suite_assumes() -> void:
	# The premise of every test below. If the stretch settings in project.godot
	# change, this is the assertion that should go red rather than the subtler
	# ones about angles.
	await _hold_the_phone_upright()
	assert_eq(Vector2i(_frame()), PHONE_VIEWPORT, "the portrait window's viewport moved")


func test_the_design_resolution_keeps_the_lens_it_was_framed_at() -> void:
	# The promise to the desktop shot. This is the test that fails if the ceiling
	# is ever lowered past the point where it starts reframing 16:9.
	assert_almost_eq(_lens().fov, 75.0, TOLERANCE, "the wide shot must be left alone")


func test_a_phone_held_upright_does_not_get_a_fisheye() -> void:
	# The bug, stated as the thing that was wrong: 114.8 degrees top to bottom.
	await _hold_the_phone_upright()
	assert_lte(
		_vertical_fov(),
		_lens().max_vertical_fov_degrees + TOLERANCE,
		"a portrait window must not blow the vertical field of view out"
	)


func test_the_phone_gets_a_narrower_lens_than_the_desktop_does() -> void:
	# The mechanism, from the other side: the ceiling above is kept by giving up
	# horizontal angle, and this is the giving up.
	var wide: float = _lens().fov
	await _hold_the_phone_upright()
	assert_lt(_lens().fov, wide, "the horizontal angle is what gives")


func test_the_lens_goes_back_when_the_window_does() -> void:
	# A fit that only ever narrowed would ratchet: turn the phone sideways and the
	# already-narrowed lens would be narrowed again. Every fit is computed from the
	# scene file's lens rather than from the current one, and this is that.
	var framed: float = _lens().fov
	await _hold_the_phone_upright()
	get_tree().root.size = get_tree().root.content_scale_size
	await wait_process_frames(RESIZE_FRAMES)
	assert_almost_eq(_lens().fov, framed, TOLERANCE, "the lens must be restored, not ratcheted")


func test_the_held_tool_stays_in_shot_on_a_phone() -> void:
	# The regression a narrower lens causes if nothing else moves: the hand is
	# placed a fixed number of metres off the camera's axis, and a narrower lens
	# sees fewer metres. Measured, with the offset left alone, the anchor lands at
	# 1.05 of the frame's width — off the right-hand edge.
	await _hold_the_phone_upright()
	var frame: Vector2 = _frame()
	var at: Vector2 = _lens().unproject_position(_view_model().global_position) / frame
	assert_between(at.x, 0.0, 1.0, "the hand must not slide off the side of the frame")
	assert_between(at.y, 0.0, 1.0, "nor off the bottom of it")


func test_the_held_tool_sits_the_same_way_into_the_corner_either_way() -> void:
	# Not merely on screen — in the same place in the shot. The scene file's offset
	# means "halfway to the edge", and that fraction is what has to survive.
	var frame: Vector2 = _frame()
	var wide: Vector2 = _lens().unproject_position(_view_model().global_position) / frame
	await _hold_the_phone_upright()
	var tall: Vector2 = _lens().unproject_position(_view_model().global_position) / _frame()
	assert_almost_eq(tall.x, wide.x, 0.01, "the hand keeps its place across the frame")


func test_the_hand_stays_as_far_in_front_of_the_lens_as_it_was() -> void:
	# The depth is deliberately not scaled: it is what the near plane and the car's
	# clearance were both measured against, and neither has anything to do with how
	# wide the lens is.
	var depth: float = _view_model().position.z
	await _hold_the_phone_upright()
	assert_almost_eq(_view_model().position.z, depth, 0.0001, "the hand must not move in or out")


func test_the_car_fills_more_of_the_phone_screen_than_it_used_to() -> void:
	# The thing a player would actually report, rather than an angle. Against the
	# design lens on the same viewport, which is what shipped before.
	await _hold_the_phone_upright()
	var frame: Vector2 = _frame()
	var fitted: float = _lens().fov
	var covered: float = _car_height_fraction(frame)
	_lens().fov = 75.0
	var before: float = _car_height_fraction(frame)
	_lens().fov = fitted
	assert_gt(covered, before * 2.0, "the fit is meant to be worth having, not marginal")


## How much of the frame's height the car's box covers, as a fraction.
func _car_height_fraction(frame: Vector2) -> float:
	var car: Car = _garage().get_node("%Car") as Car
	var box: AABB = car.bounds()
	var camera: Lens = _lens()
	var low: float = INF
	var high: float = -INF
	for i: int in range(8):
		var at: Vector2 = camera.unproject_position(box.get_endpoint(i))
		low = minf(low, at.y)
		high = maxf(high, at.y)
	return (high - low) / frame.y
