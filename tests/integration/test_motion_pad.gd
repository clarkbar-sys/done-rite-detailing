## Integration test for the motion pad — the four hold-to-move arrows down the
## right-hand edge.
##
## Under tests/integration/ because almost nothing here is true of the script on
## its own: the buttons are built in [method Node._ready], their rectangles come
## from a layout pass, and what actually matters — every arrow is big enough for
## a thumb, they are all in the corner the tool belt is not, and the pad eats no
## input anywhere else — is only observable once the scene is in a tree at the
## design resolution.
##
## The pad is added [i]over[/i] a full-screen button on purpose, the same way
## [code]tests/integration/test_tool_belt_hud.gd[/code] does it. "Intercepts no
## input" cannot be checked by asserting the pad stayed quiet; a root [Control]
## that swallowed the tap would also stay quiet. The button underneath is the
## witness, and it stands in for the garage's [SubViewportContainer].
##
## [b]What is not staged here: two thumbs at once.[/b] A [Button] is pressed by
## the mouse the engine emulates from a touch, and there is exactly one of those,
## so "left and right held together cancel" is not something this file can set up
## honestly. What it can pin is that each direction really is [code]±1[/code] and
## that letting go really is [code]0[/code] — the cancellation is then the
## subtraction in [method MotionPad.turn], and
## [code]tests/unit/test_orbit_drive.gd[/code] holds the other end of it by
## proving zero means "hold still" rather than "pick one".
extends GutTest

const MOTION_PAD: String = "res://src/ui/motion_pad.tscn"

## What the pad and its witness are hung from, and why it is not the test itself.
##
## GUT's runner draws its own output over the same window, on a [CanvasLayer] at
## layer 128 — and GUI picking goes to the highest layer first, so a tap aimed at
## an arrow in the right-hand corner lands on the runner's log instead. Measured:
## [method Viewport.gui_get_hovered_control] under the right arrow was GUT's
## `TestOutput`, and every press below reported nothing at all. Above 128, the
## game is the thing under the finger. The tool belt's tests get away without
## this because their corner happens to be one the runner's panel does not
## reach, which is luck rather than a difference.
const ABOVE_THE_RUNNER: int = 200

## The four directions, in the order the assertions below read best: the pair
## that walks you round the car, then the pair that raises and lowers your eye.
const DIRECTIONS: Array[Vector2i] = [MotionPad.LEFT, MotionPad.RIGHT, MotionPad.UP, MotionPad.DOWN]

var _pad: MotionPad = null
var _underneath: Button = null
var _underneath_presses: int = 0
var _window_size_before: Vector2i = Vector2i.ZERO


func before_each() -> void:
	_underneath_presses = 0
	# A headless window is 64x64 — smaller than a single tap target, small enough
	# that every rectangle in this file would be clamped into nonsense and the
	# size and placement assertions would pass or fail for reasons that have
	# nothing to do with the pad. `content_scale_size` is the design resolution
	# from project.godot. Put back in after_each: every suite shares this window.
	var root: Window = get_tree().root
	_window_size_before = root.size
	root.size = root.content_scale_size
	# Typed locals before add_child_autofree because GUT's helper is untyped, and
	# autofree is what keeps a failing assertion below from being reported as a
	# leak against whichever test runs next.
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = ABOVE_THE_RUNNER
	add_child_autofree(layer)
	var underneath: Button = Button.new()
	underneath.set_anchors_preset(Control.PRESET_FULL_RECT)
	_underneath = underneath
	layer.add_child(_underneath)
	_underneath.pressed.connect(_record_underneath)
	var packed: PackedScene = load(MOTION_PAD) as PackedScene
	assert_not_null(packed, "could not load %s" % MOTION_PAD)
	if packed == null:
		return
	var pad: MotionPad = packed.instantiate() as MotionPad
	_pad = pad
	layer.add_child(_pad)
	# `_ready()` has already fired inside add_child; the frame is only here to let
	# layout settle before any rectangle is read.
	await wait_process_frames(1)


func after_each() -> void:
	get_tree().root.size = _window_size_before


func _record_underneath() -> void:
	_underneath_presses += 1


## Puts a finger on the glass at [param at] and leaves it there.
##
## Through `Input` rather than `Viewport.push_input()` for the reason the roll-up
## and the title screen both do it: nothing in [Button] reads a touch event, so
## what actually makes a tap work is the engine turning it into a click first,
## and that emulation lives in `Input`. Pushing the touch straight at the
## viewport would skip the exact step these tests exist to prove.
func _touch(at: Vector2, pressed: bool) -> void:
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.position = at
	touch.pressed = pressed
	Input.parse_input_event(touch)
	Input.flush_buffered_events()


## Holds the arrow that moves you [param direction], and returns once the press
## has been routed.
func _hold(direction: Vector2i) -> void:
	_touch(_pad.button_for(direction).get_global_rect().get_center(), true)
	await wait_process_frames(1)


func _let_go(direction: Vector2i) -> void:
	_touch(_pad.button_for(direction).get_global_rect().get_center(), false)
	await wait_process_frames(1)


## Every arrow's rectangle, for the sizing and placement assertions.
func _rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for direction: Vector2i in DIRECTIONS:
		rects.append(_pad.button_for(direction).get_global_rect())
	return rects


func test_the_scene_is_a_motion_pad() -> void:
	# The play screen casts to [MotionPad] to read `turn()` and `lift()`; a scene
	# that lost its script would leave the camera unable to move at all.
	assert_not_null(_pad, "the pad must instantiate as a MotionPad")


func test_there_is_one_arrow_per_direction() -> void:
	for direction: Vector2i in DIRECTIONS:
		var button: Button = _pad.button_for(direction)
		assert_not_null(button, "no arrow moves you %s" % direction)


func test_a_direction_the_pad_does_not_have_is_refused() -> void:
	# Diagonals are not a thing this scheme offers, and asking for one should get
	# nothing rather than the nearest arrow.
	assert_null(_pad.button_for(Vector2i(1, 1)), "the pad has four arrows, not eight")


func test_each_arrow_points_the_way_it_moves_you() -> void:
	# The bug this pins is silent and is the whole reason the triangle is drawn
	# from the direction rather than written out four times: a button that walks
	# you left with a triangle pointing right is not a bug anybody finds by
	# reading the code, and it is the first thing a player finds.
	for direction: Vector2i in DIRECTIONS:
		var arrow: MotionPad.ArrowButton = _pad.button_for(direction) as MotionPad.ArrowButton
		assert_eq(arrow.direction(), direction, "the arrow must know which one it is")
		# Y flips on the way to the screen: input space has up at +1, screen space
		# has up at -Y.
		var facing: Vector2 = Vector2(float(direction.x), -float(direction.y))
		var corners: PackedVector2Array = arrow.corners()
		var tip: float = corners[0].dot(facing)
		assert_gt(tip, corners[1].dot(facing), "the drawn tip must lead the base")
		assert_gt(tip, corners[2].dot(facing), "on both corners of it")


# ---- sizing and placement: the phone-shaped half ----------------------------


func test_every_arrow_is_big_enough_for_a_thumb() -> void:
	# The Start button's bug, two layouts along. [TouchTarget] has the arithmetic
	# and the sources; a movement control nobody can hit reads as a game that has
	# frozen, which is worse than a tool icon nobody can hit.
	var minimum: float = TouchTarget.min_design_size()
	for direction: Vector2i in DIRECTIONS:
		var button: Button = _pad.button_for(direction)
		assert_gte(button.size.x, minimum, "the %s arrow is too narrow to hit" % direction)
		assert_gte(button.size.y, minimum, "the %s arrow is too short to hit" % direction)


func test_no_two_arrows_overlap() -> void:
	# The other half of "big enough": an arrow that measures 164 px with a
	# neighbour sitting on half of it is 82 px of usable strip, and the test above
	# would still be green. Worse here than on the belt, because the neighbour of
	# every arrow is the one that moves you the opposite way.
	var rects: Array[Rect2] = _rects()
	for first: int in rects.size():
		for second: int in range(first + 1, rects.size()):
			assert_false(
				rects[first].intersects(rects[second]),
				"arrows %d and %d overlap: %s vs %s" % [first, second, rects[first], rects[second]]
			)


func test_every_arrow_is_on_screen() -> void:
	var screen: Rect2 = Rect2(Vector2.ZERO, _pad.size)
	for direction: Vector2i in DIRECTIONS:
		assert_true(
			screen.encloses(_pad.button_for(direction).get_global_rect()),
			"the %s arrow is off screen and cannot be tapped" % direction
		)


func test_every_arrow_is_on_the_side_the_tool_belt_is_not() -> void:
	# The pad and the belt share a screen and are held in different hands. The
	# belt rolls up out of the bottom-left and wraps rightward; anything here
	# straying into the left half would be sitting on it.
	for rect: Rect2 in _rects():
		assert_gt(
			rect.position.x, _pad.size.x * 0.5, "the pad belongs to the right hand: %s" % rect
		)


func test_up_and_down_are_stacked_at_the_top_and_the_right_way_up() -> void:
	var up: Rect2 = _pad.button_for(MotionPad.UP).get_global_rect()
	var down: Rect2 = _pad.button_for(MotionPad.DOWN).get_global_rect()
	assert_lt(up.end.y, _pad.size.y * 0.5, "the lift pair rides at the top of the screen")
	assert_lt(down.end.y, _pad.size.y * 0.5)
	assert_lt(up.position.y, down.position.y, "up must be above down, or the pad reads as a lie")
	assert_almost_eq(up.position.x, down.position.x, 1.0, "and they must line up")


func test_left_and_right_are_side_by_side_at_the_bottom_and_the_right_way_round() -> void:
	var left: Rect2 = _pad.button_for(MotionPad.LEFT).get_global_rect()
	var right: Rect2 = _pad.button_for(MotionPad.RIGHT).get_global_rect()
	assert_gt(left.position.y, _pad.size.y * 0.5, "the walking pair sits under the thumb")
	assert_gt(right.position.y, _pad.size.y * 0.5)
	assert_lt(left.position.x, right.position.x, "left must be left of right")
	assert_almost_eq(left.position.y, right.position.y, 1.0, "and they must line up")


# ---- what the pad actually reports ------------------------------------------


func test_an_untouched_pad_asks_for_nothing() -> void:
	# The state the game starts in, and the state it spends most of its time in.
	assert_eq(_pad.turn(), 0.0, "nothing held is not a direction")
	assert_eq(_pad.lift(), 0.0)


func test_holding_an_arrow_asks_for_that_direction() -> void:
	# Through a real touch rather than by reaching into the buttons, so an arrow
	# that is somehow unhittable on a phone fails here rather than in a browser.
	for direction: Vector2i in DIRECTIONS:
		await _hold(direction)
		assert_eq(_pad.turn(), float(direction.x), "holding %s must ask to turn" % direction)
		assert_eq(_pad.lift(), float(direction.y), "holding %s must ask to lift" % direction)
		await _let_go(direction)


func test_letting_go_stops_asking() -> void:
	# The half that matters most: a pad that kept reporting a direction after the
	# thumb came off is a camera that never stops walking.
	await _hold(MotionPad.RIGHT)
	assert_eq(_pad.turn(), 1.0, "the test needs the press to have landed")
	await _let_go(MotionPad.RIGHT)
	assert_eq(_pad.turn(), 0.0, "letting go must stop the camera")


func test_the_two_axes_do_not_leak_into_each_other() -> void:
	# Walking and lifting are separate pairs on separate corners of the screen,
	# and a player holding one must not drift on the other.
	await _hold(MotionPad.UP)
	assert_eq(_pad.turn(), 0.0, "the lift pair must not walk you round the car")
	await _let_go(MotionPad.UP)
	await _hold(MotionPad.LEFT)
	assert_eq(_pad.lift(), 0.0, "and the walking pair must not raise your eye")
	await _let_go(MotionPad.LEFT)


# ---- everywhere else, the pad is not there ----------------------------------


func test_a_tap_in_open_space_reaches_what_is_underneath() -> void:
	# The layering trap. A [Control] defaults to MOUSE_FILTER_STOP, so a pad
	# anchored to the whole screen would swallow every tap in the game forever —
	# including the ones meant for the tool belt in the opposite corner.
	_underneath_presses = 0
	_touch(_pad.size * 0.5, true)
	_touch(_pad.size * 0.5, false)
	await wait_process_frames(1)
	assert_eq(_underneath_presses, 1, "the pad covers the screen but must not eat it")
