## Integration test for the offset between the finger and the aim: [ThumbLift],
## in a running game.
##
## Split out of [code]test_play_screen_aim.gd[/code] rather than added to it, for
## the reason that suite gives about being split out of the shot in the first
## place — these fail for their own causes, and the aim suite was already at
## [code].gdlintrc[/code]'s public-method cap.
##
## [b]What is here and what is deliberately not.[/b] The shape of the mapping is
## [code]tests/unit/test_thumb_lift.gd[/code]'s — every claim about the ease at
## the top of the glass, the smoothness of its join and the reference-pixel
## conversion is made there, against arithmetic, and none of it is repeated. What
## needs a running game is the part that arithmetic cannot answer: that the offset
## is applied at all, that it is applied on the way to the room rather than
## anywhere else, that a lifted ray still finds real bodywork, and that a mouse
## comes through it untouched.
##
## [b]The mouse is the control, and it is why this is an integration test.[/b]
## Touch and pointer take different branches of [method PlayScreen._gui_input] and
## meet again at one call into the room, so the only place the difference between
## them is observable is here, with both events going through the real input
## stack at the same screen coordinate.
##
## [b]Everything waits on the physics clock[/b], because that is where
## [method Garage._resolve_aim] casts its ray. A test that pressed and asserted in
## the same frame would be asserting against the tick before the press.
extends GutTest

const PLAY_SCREEN: String = "res://src/screens/play_screen.tscn"

## Above GUT's own output layer, so a finger aimed at the game lands on the game
## — the same measurement [code]test_play_screen_walk.gd[/code] records at
## length.
const ABOVE_THE_RUNNER: int = 200

## Close enough for positions in metres — a tenth of a millimetre.
const TOLERANCE: float = 0.0001

## Close enough for a point projected back onto the glass, in design pixels. Two,
## not zero: the mark sits [constant AimMarker.LIFT] off the paint along the
## panel's normal, so re-projecting it lands a hair from the ray that put it
## there.
const ON_GLASS_TOLERANCE: float = 2.0

## Long enough for the standoff to have eased from the parked stance out to the
## gap the walk wants, so every press below is measured against a settled camera.
## A second and a half; the walk suite explains the arithmetic.
const SETTLE_FRAMES: int = 90

## Enough physics ticks for a press to have been resolved into a mark, with room
## to spare — the aim suite explains why it is four and not two.
const RESOLVE_FRAMES: int = 4

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
	# Both, and in this order: a finger and a pointer claim the aim through
	# different indices, so a suite that only lifted one would leave the other
	# holding it and the next test would start already aiming.
	_touch(Vector2.ZERO, false)
	_mouse(Vector2.ZERO, false)
	await wait_physics_frames(RESOLVE_FRAMES)
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


func _readout() -> Label:
	return _screen.get_node("PanelReadout") as Label


func _car_box() -> AABB:
	return _car().bounds()


## Every name the car can honestly answer with, read off the car rather than
## written down here.
func _panel_names() -> Array[String]:
	var names: Array[String] = []
	for panel: Node3D in _car().panels():
		names.append(String(panel.name))
	return names


## Where [param point] in the world lands on the glass. Through the camera's own
## projection rather than by writing screen coordinates down, because the eye
## moves during [method _settle].
func _on_screen(point: Vector3) -> Vector2:
	return _camera().unproject_position(point)


## The middle of the car, on the glass.
func _at_the_car() -> Vector2:
	return _on_screen(_car().global_position)


## Puts a finger on the glass at [param at], or takes it off again.
##
## Through [method Input.parse_input_event] and not [method Viewport.push_input],
## for the reason the walk suite gives: this is the path a real tap takes,
## emulated mouse and all, so it exercises the de-duplication in the screen rather
## than a parallel route around it.
func _touch(at: Vector2, pressed: bool) -> void:
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.position = at
	touch.pressed = pressed
	Input.parse_input_event(touch)
	Input.flush_buffered_events()


## Puts a mouse down at [param at], or lets it up again.
##
## `device` is left at 0 on purpose: [constant InputEvent.DEVICE_ID_EMULATION] is
## the mark on the mouse the engine invents from the first finger, and the screen
## throws those away. An event carrying it would be dropped before it ever reached
## the aim, and this suite would be measuring nothing.
func _mouse(at: Vector2, pressed: bool) -> void:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = at
	click.pressed = pressed
	Input.parse_input_event(click)
	Input.flush_buffered_events()


## [constant ThumbLift.REFERENCE_PX] in this window's design pixels, read the same
## two ways the screen reads it rather than written down.
func _lift_px() -> float:
	return ThumbLift.design_lift(
		get_tree().root.get_final_transform().get_scale().y, DisplayServer.screen_get_scale()
	)


## Where a thumb has to be to aim at [param aim] — the inverse of
## [method ThumbLift.raised], both branches of it, asserted to round-trip.
func _thumb_for(aim: Vector2) -> Vector2:
	var lift: float = _lift_px()
	var down: float = aim.y + lift
	if aim.y < lift:
		down = sqrt(4.0 * lift * maxf(aim.y, 0.0))
	var thumb: Vector2 = Vector2(aim.x, down)
	assert_almost_eq(
		ThumbLift.aim_from(thumb, lift).y, maxf(aim.y, 0.0), 0.01, "a thumb at %v aims back" % thumb
	)
	return thumb


## Presses so that the aim lands at [param at], and waits for the room to have
## answered. The finger itself goes a thumb's width below it.
func _press(at: Vector2) -> void:
	_touch(_thumb_for(at), true)
	await wait_physics_frames(RESOLVE_FRAMES)


## Clicks at [param at] — where the aim also lands, because a pointer is not
## lifted — and waits for the room to have answered.
func _click(at: Vector2) -> void:
	_mouse(at, true)
	await wait_physics_frames(RESOLVE_FRAMES)


## Lets the pointer up, so the next press can claim the aim.
func _unclick() -> void:
	_mouse(Vector2.ZERO, false)
	await wait_physics_frames(RESOLVE_FRAMES)


## Lets the standoff ease out to the gap it wants.
func _settle() -> void:
	await wait_physics_frames(SETTLE_FRAMES)


## The gap between [param point] and the nearest face of [param box], and zero if
## the point is inside it. The same per-axis measure the other suites use — a
## centre-to-centre distance is off by metres on a car this long.
func _clearance(box: AABB, point: Vector3) -> float:
	var low: Vector3 = box.position - point
	var high: Vector3 = point - box.end
	var gap: Vector3 = Vector3(
		maxf(maxf(low.x, high.x), 0.0),
		maxf(maxf(low.y, high.y), 0.0),
		maxf(maxf(low.z, high.z), 0.0)
	)
	return gap.length()


# ---- the mark is not under the hand ------------------------------------------


func test_this_window_squeezes_nothing_so_the_lift_is_a_thumbs_width() -> void:
	# Stated once, because every measurement below is in these pixels.
	# `before_each` sizes the window to the design resolution and a headless run
	# has no device pixel ratio, so the conversion is the identity here and the
	# lift is [constant ThumbLift.REFERENCE_PX] exactly. If this moves, the
	# tolerances below are being measured against a different screen.
	assert_almost_eq(_lift_px(), ThumbLift.REFERENCE_PX, 0.01)


func test_the_mark_lands_a_thumbs_width_above_the_finger_that_asked_for_it() -> void:
	# The whole point of the offset, measured on the glass rather than in the class
	# that computes it: the finger goes down here, and the red ring comes up there,
	# where the hand is not.
	await _settle()
	var aim: Vector2 = _at_the_car()
	var thumb: Vector2 = _thumb_for(aim)
	await _press(aim)
	assert_true(_marker().is_marking(), "the lifted aim still found the car")
	var mark: Vector2 = _on_screen(_marker().marked_point())
	assert_almost_eq(
		thumb.y - mark.y,
		_lift_px(),
		ON_GLASS_TOLERANCE,
		"the mark is a lift above the finger, on the glass"
	)


func test_the_lifted_aim_still_lands_on_real_bodywork() -> void:
	# The offset moves the ray, so it can move it off the car — and an offset that
	# quietly turned every press into a nearest-point fallback would look fine on
	# screen while answering a different question. Held to the same clearance the
	# aim suite holds an unlifted press to.
	await _settle()
	await _press(_at_the_car())
	assert_almost_eq(_clearance(_car_box(), _marker().marked_point()), 0.0, TOLERANCE)
	assert_has(_panel_names(), _readout().text, "and it is a panel the car really has")


func test_a_mouse_aims_at_the_pointer_and_not_above_it() -> void:
	# The control for every claim above. A cursor hides a few pixels of arrow, so
	# there is nothing to dodge, and a desk that had its aim lifted would have the
	# crosshair somewhere the pointer plainly is not.
	await _settle()
	var at: Vector2 = _at_the_car()
	await _click(at)
	assert_true(_marker().is_marking(), "a click marks the car too")
	assert_almost_eq(
		_on_screen(_marker().marked_point()).y, at.y, ON_GLASS_TOLERANCE, "right under the pointer"
	)


func test_the_same_spot_marks_higher_up_the_car_for_a_thumb_than_for_a_mouse() -> void:
	# The two paths side by side, in world space, from one screen coordinate. This
	# is the test that fails if somebody ever "simplifies" the lift by moving it
	# into the room, where it would apply to both.
	await _settle()
	var at: Vector2 = _at_the_car()
	await _click(at)
	var clicked: Vector3 = _marker().marked_point()
	# Let go between the two: the first pointer down keeps the aim until it lifts,
	# so a touch arriving while the mouse still holds it would be ignored and this
	# would compare a point with itself.
	await _unclick()
	_touch(at, true)
	await wait_physics_frames(RESOLVE_FRAMES)
	assert_gt(_marker().marked_point().y, clicked.y, "the thumb's mark sits above the pointer's")


func test_a_thumb_at_the_very_top_of_the_glass_still_marks_something() -> void:
	# The top strip, where the lift eases off — see [method ThumbLift.raised]. The
	# claim here is only that the aim survives the ease: it is a press against the
	# top edge, it aims somewhere well above the car, and the nearest-point fallback
	# answers it like any other miss rather than the whole thing collapsing into a
	# zero or a negative screen coordinate.
	await _settle()
	_touch(Vector2(Vector2(_view().size).x * 0.5, 1.0), true)
	await wait_physics_frames(RESOLVE_FRAMES)
	assert_true(_marker().is_marking(), "a press on the top edge still marks the car")
	assert_has(_panel_names(), _readout().text, "and names a real panel")
