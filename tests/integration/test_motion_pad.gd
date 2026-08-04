## Integration test for the motion pad — the circle in the bottom-right corner
## with a knob that follows your thumb.
##
## Under tests/integration/ because almost nothing here is true of the script on
## its own: the circle is placed by a layout pass, the grabs arrive as real touch
## events, and what actually matters — that the stick is big enough for a thumb,
## that it is in the corner the tool belt is not, that a finger anywhere in it
## reports the direction it is pushed, and that the pad eats no input anywhere
## else — is only observable once the scene is in a tree at the design resolution.
##
## The mapping from an offset to a pair of numbers is [ThumbStick]'s and is unit
## tested in [code]tests/unit/test_thumb_stick.gd[/code]. What is here is whether
## a real finger reaches it: the events, the grab rule, the coordinates and the
## claim.
##
## The pad is added [i]over[/i] a full-screen button on purpose, the same way
## [code]tests/integration/test_tool_belt_hud.gd[/code] does it. "Intercepts no
## input" cannot be checked by asserting the pad stayed quiet; a root [Control]
## that swallowed the tap would also stay quiet. The button underneath is the
## witness, and it stands in for the garage's [SubViewportContainer].
##
## [b]What that witness cannot testify to is the other half — that a press
## [i]inside[/i] the circle is kept away from what is underneath.[/b] A [Button] is
## worked by the mouse the engine emulates from the first finger, and that
## emulated click is its own event: claiming the touch does not stop it. Measured
## with a probe — a full-screen [Button] under the stick still recorded the press.
## Harmless in the game, because the two things that actually sit under the pad
## are the play screen, which drops emulated mice on sight, and the room behind
## it — so the "a press on the stick is not an aim" half is pinned in
## [code]tests/integration/test_play_screen_trigger.gd[/code], against the real
## screen, rather than against a witness that cannot see it.
extends GutTest

const MOTION_PAD: String = "res://src/ui/motion_pad.tscn"

## What the pad and its witness are hung from, and why it is not the test itself.
##
## GUT's runner draws its own output over the same window, on a [CanvasLayer] at
## layer 128 — and GUI picking goes to the highest layer first, so a tap aimed at
## the witness in the right-hand corner lands on the runner's log instead.
## Measured: [method Viewport.gui_get_hovered_control] under the stick was GUT's
## `TestOutput`. Above 128, the game is the thing under the finger. The pad itself
## no longer needs this — it claims touches in [method Node._input], before any of
## that — but the witness underneath is a [Button] and still does.
const ABOVE_THE_RUNNER: int = 200

## Close enough for a fraction of full deflection, and for a position in pixels.
const TOLERANCE: float = 0.001

## The four the ring is marked with, in the order the assertions below read best:
## the pair that walks you round the car, then the pair that raises and lowers
## your eye.
const DIRECTIONS: Array[Vector2i] = [MotionPad.LEFT, MotionPad.RIGHT, MotionPad.UP, MotionPad.DOWN]

## The corner of the stick that asks for two things at once — the thing four
## buttons could not do with one thumb.
const CORNER: Vector2i = Vector2i(1, 1)

## A second finger, for the tests about who owns the stick.
const OTHER_FINGER: int = 1

var _pad: MotionPad = null
var _underneath: Button = null
var _underneath_presses: int = 0
var _window_size_before: Vector2i = Vector2i.ZERO


func before_each() -> void:
	_underneath_presses = 0
	# A headless window is 64x64 — smaller than a single tap target, small enough
	# that the circle would be laid out into nonsense and the size and placement
	# assertions would pass or fail for reasons that have nothing to do with the
	# pad. `content_scale_size` is the design resolution from project.godot. Put
	# back in after_each: every suite shares this window.
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
	# A held stick is state that outlives a test. One left grabbed would walk the
	# camera in whatever runs next, and the failure would land somewhere else
	# entirely.
	if _pad != null:
		_pad.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	get_tree().root.size = _window_size_before


func _record_underneath() -> void:
	_underneath_presses += 1


## [param local] in the pad's own coordinates, as a place on the glass.
func _on_the_glass(local: Vector2) -> Vector2:
	return _pad.get_global_transform_with_canvas() * local


## Puts finger [param index] on the glass at [param at], or takes it off again.
##
## Through `Input` rather than `Viewport.push_input()` for the reason the roll-up
## and the title screen both do it: what a phone actually delivers goes through
## the emulation and the buffering in `Input` first, and the witness underneath is
## a [Button], which only works because of that. Pushing the event straight at the
## viewport would skip the exact step these tests exist to prove.
func _touch(at: Vector2, pressed: bool, index: int = 0) -> void:
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.index = index
	touch.position = at
	touch.pressed = pressed
	Input.parse_input_event(touch)
	Input.flush_buffered_events()


## Slides finger [param index] to [param at] without lifting it.
func _drag(at: Vector2, index: int = 0) -> void:
	var dragged: InputEventScreenDrag = InputEventScreenDrag.new()
	dragged.index = index
	dragged.position = at
	Input.parse_input_event(dragged)
	Input.flush_buffered_events()


## Pushes the stick all the way [param direction] and leaves it there.
func _push(direction: Vector2i) -> void:
	_touch(_pad.point_for(direction), true)
	await wait_process_frames(1)


func _let_go(direction: Vector2i) -> void:
	_touch(_pad.point_for(direction), false)
	await wait_process_frames(1)


func test_the_scene_is_a_motion_pad() -> void:
	# The play screen casts to [MotionPad] to read `turn()` and `lift()`; a scene
	# that lost its script would leave the camera unable to move at all.
	assert_not_null(_pad, "the pad must instantiate as a MotionPad")


# ---- sizing and placement: the phone-shaped half ----------------------------


func test_the_stick_is_big_enough_for_a_thumb() -> void:
	# The Start button's bug, one layout along. [TouchTarget] has the arithmetic
	# and the sources; a movement control nobody can hit reads as a game that has
	# frozen, which is worse than a tool icon nobody can hit. The target is the
	# whole grab area, not the knob drawn inside it.
	var across: float = _pad.grab_radius() * 2.0
	assert_gte(across, TouchTarget.min_design_size(), "the stick is too small to hit")


func test_the_whole_stick_is_on_screen() -> void:
	# Both halves of "the whole stick", because they are different sizes and the
	# corner has to clear the larger. The grab area is the part that answers a
	# finger, so it has to be reachable; the knob at full deflection is the part
	# that is drawn furthest out, and a knob sliced in half by the edge of the glass
	# on every hard-right push is what this looked like in a browser before the
	# layout took it into account.
	var screen: Rect2 = Rect2(Vector2.ZERO, _pad.size)
	for reach: float in [_pad.grab_radius(), _pad.radius() * (1.0 + MotionPad.KNOB_FRACTION)]:
		var box: Rect2 = Rect2(_pad.centre() - Vector2(reach, reach), Vector2(reach, reach) * 2.0)
		assert_true(screen.encloses(box), "the stick reaches off screen at %s" % box)


func test_the_stick_is_in_the_corner_the_tool_belt_is_not() -> void:
	# The pad and the belt share a screen and are held in different hands. The belt
	# rolls up out of the bottom-left and wraps rightward; anything here straying
	# into the left half would be sitting on it. And the bottom half, because that
	# is where a thumb already rests on a phone held in two hands.
	assert_gt(
		_pad.centre().x - _pad.grab_radius(),
		_pad.size.x * 0.5,
		"the stick belongs to the right hand"
	)
	assert_gt(_pad.centre().y, _pad.size.y * 0.5, "and to the bottom corner of it")


func test_the_knob_goes_red_under_a_thumb_and_only_under_a_thumb() -> void:
	# Red is what this palette puts on a thing you press, and the stick is
	# furniture you rest a thumb on rather than a button you pick — so a red disc
	# sitting in the corner of every frame would be the loudest thing on a screen
	# whose actual buttons are in the other corner. Held is the one state where it
	# means what red means everywhere else in the game: this control is live.
	# Asserted on the width [method MotionPad._draw] actually uses.
	assert_eq(_pad.knob_rim_width(), 0.0, "an untouched stick is not asking to be pressed")
	await _push(MotionPad.RIGHT)
	assert_gt(_pad.knob_rim_width(), 0.0, "a stick under a thumb says so")
	await _let_go(MotionPad.RIGHT)
	assert_eq(_pad.knob_rim_width(), 0.0, "and stops saying it when the thumb comes off")


func test_each_mark_points_the_way_it_moves_you() -> void:
	# The bug this pins is silent and is the whole reason the marks are drawn from
	# the directions the stick reports: a ring whose top triangle points down is not
	# a bug anybody finds by reading the code, and it is the first thing a player
	# finds.
	for direction: Vector2i in DIRECTIONS:
		# Y flips on the way to the screen: input space has up at +1, screen space
		# has up at -Y.
		var facing: Vector2 = Vector2(float(direction.x), -float(direction.y))
		var corners: PackedVector2Array = _pad.mark_corners(direction)
		assert_eq(corners.size(), 3, "the %s mark must be a triangle" % direction)
		var tip: float = corners[0].dot(facing)
		assert_gt(tip, corners[1].dot(facing), "the drawn tip must lead the base")
		assert_gt(tip, corners[2].dot(facing), "on both corners of it")


# ---- what the stick actually reports ----------------------------------------


func test_an_untouched_stick_asks_for_nothing() -> void:
	# The state the game starts in, and the state it spends most of its time in.
	assert_false(_pad.is_held(), "nobody is on the stick")
	assert_eq(_pad.turn(), 0.0, "and nothing held is not a direction")
	assert_eq(_pad.lift(), 0.0)
	assert_eq(_pad.knob(), _pad.centre(), "so the knob sits in the middle")


func test_pushing_the_stick_asks_for_that_direction() -> void:
	# Through a real touch rather than by reaching into the pad, so a stick that is
	# somehow unhittable on a phone fails here rather than in a browser. Each
	# direction is also the other axis reading zero, which is the leak a diagonal
	# control can develop without anybody noticing.
	for direction: Vector2i in DIRECTIONS:
		await _push(direction)
		assert_true(_pad.is_held(), "the %s push must land" % direction)
		assert_almost_eq(_pad.turn(), float(direction.x), TOLERANCE, "%s must walk" % direction)
		assert_almost_eq(_pad.lift(), float(direction.y), TOLERANCE, "%s must lift" % direction)
		await _let_go(direction)


func test_a_thumb_in_the_middle_holds_the_stick_and_asks_for_nothing() -> void:
	# The dead middle, through a real finger. A player putting a thumb down to get
	# ready has grabbed the stick — the next drag is theirs — but has not asked to
	# go anywhere yet.
	_touch(_on_the_glass(_pad.centre()), true)
	await wait_process_frames(1)
	assert_true(_pad.is_held(), "the middle of the circle is still the circle")
	assert_eq(_pad.turn(), 0.0, "but a thumb sitting in it is not a direction")
	assert_eq(_pad.lift(), 0.0)


func test_a_corner_of_the_stick_walks_and_lifts_at_once() -> void:
	# The whole point of replacing four buttons with a circle: one thumb, both
	# axes, and no more total than an axis alone could ask for.
	await _push(CORNER)
	assert_gt(_pad.turn(), 0.0, "the corner walks you right")
	assert_gt(_pad.lift(), 0.0, "and raises your eye")
	assert_almost_eq(
		Vector2(_pad.turn(), _pad.lift()).length(), 1.0, TOLERANCE, "at full, not 1.41"
	)
	await _let_go(CORNER)


func test_letting_go_stops_asking() -> void:
	# The half that matters most: a stick that kept reporting a direction after the
	# thumb came off is a camera that never stops walking.
	await _push(MotionPad.RIGHT)
	assert_almost_eq(_pad.turn(), 1.0, TOLERANCE, "the test needs the push to have landed")
	await _let_go(MotionPad.RIGHT)
	assert_false(_pad.is_held(), "letting go must let go")
	assert_eq(_pad.turn(), 0.0, "and must stop the camera")
	assert_eq(_pad.knob(), _pad.centre(), "and spring the knob back")


func test_the_stick_follows_a_thumb_that_slides() -> void:
	# A stick is grabbed once and then steered, so the drag is the event that does
	# most of the work — and it is a different event from the press, delivered to a
	# different branch, which is exactly the kind of pair that gets one half wired.
	_touch(_on_the_glass(_pad.centre()), true)
	await wait_process_frames(1)
	assert_eq(_pad.turn(), 0.0, "grabbed in the middle, asking for nothing")
	_drag(_pad.point_for(MotionPad.LEFT))
	await wait_process_frames(1)
	assert_almost_eq(_pad.turn(), -1.0, TOLERANCE, "and steered left without lifting the thumb")
	assert_almost_eq(
		_pad.knob().distance_to(_pad.centre()), _pad.radius(), TOLERANCE, "the knob came with it"
	)


func test_a_thumb_dragged_off_the_stick_keeps_it() -> void:
	# A 25 mm target under a moving hand: the thumb slides off constantly. Dropping
	# the input there would stop the camera for a movement the player did not mean
	# as a stop, and pinning it at full is what the ring's edge means.
	_touch(_on_the_glass(_pad.centre()), true)
	await wait_process_frames(1)
	_drag(_on_the_glass(_pad.centre() + Vector2(_pad.radius() * 10.0, 0.0)))
	await wait_process_frames(1)
	assert_true(_pad.is_held(), "the stick is still being driven")
	assert_almost_eq(_pad.turn(), 1.0, TOLERANCE, "at full, and no more than full")
	assert_almost_eq(
		_pad.knob().distance_to(_pad.centre()),
		_pad.radius(),
		TOLERANCE,
		"the knob stopped at the rim"
	)


func test_a_second_finger_cannot_steal_the_stick() -> void:
	# Two fingers cannot drive one stick. The first one down keeps it until it
	# lifts, because the alternative is a camera that snaps between them — and
	# because the other thumb is usually on the car, aiming.
	await _push(MotionPad.RIGHT)
	_touch(_pad.point_for(MotionPad.LEFT), true, OTHER_FINGER)
	await wait_process_frames(1)
	assert_almost_eq(_pad.turn(), 1.0, TOLERANCE, "the second finger must not take over")
	_touch(_pad.point_for(MotionPad.LEFT), false, OTHER_FINGER)
	await wait_process_frames(1)
	assert_almost_eq(_pad.turn(), 1.0, TOLERANCE, "nor stop the walk by lifting")
	await _let_go(MotionPad.RIGHT)


func test_losing_focus_lets_go_of_the_stick() -> void:
	# The one thing the four buttons were immune to by construction, bought back
	# by hand. A finger on the glass when the browser tab is switched away never
	# sends its release, and a stick still holding that direction is a camera
	# walking on its own when the player comes back.
	await _push(MotionPad.RIGHT)
	assert_true(_pad.is_held(), "the test needs the push to have landed")
	_pad.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_false(_pad.is_held(), "the stick must not still be held")
	assert_eq(_pad.turn(), 0.0, "and must not still be walking the camera")


# ---- everywhere else, the pad is not there ----------------------------------


func test_a_touch_outside_the_circle_is_not_a_grab() -> void:
	# The other half of the grab rule. A pad that claimed presses anywhere would
	# take the aim away from the whole right-hand side of the screen.
	var outside: Vector2 = _pad.centre() - Vector2(_pad.grab_radius() * 1.5, 0.0)
	_touch(_on_the_glass(outside), true)
	await wait_process_frames(1)
	assert_false(_pad.is_held(), "a press beside the stick is not on the stick")
	_touch(_on_the_glass(outside), false)
	await wait_process_frames(1)


func test_a_tap_in_open_space_reaches_what_is_underneath() -> void:
	# The layering trap. A [Control] defaults to MOUSE_FILTER_STOP, so a pad
	# anchored to the whole screen would swallow every tap in the game forever —
	# including the ones meant for the tool belt in the opposite corner. And the
	# claim in [method MotionPad._input] is the same trap wearing a different coat:
	# a pad that marked every event handled would do it without ever picking one.
	_underneath_presses = 0
	_touch(_pad.size * 0.5, true)
	_touch(_pad.size * 0.5, false)
	await wait_process_frames(1)
	assert_eq(_underneath_presses, 1, "the pad covers the screen but must not eat it")
