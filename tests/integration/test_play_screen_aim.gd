## Integration test for the third thing the play screen owns: pointing the tool
## in your hands at the car.
##
## Split out of the other three play-screen suites for the reason the walk was
## split out of the shot — these fail for unrelated causes, and one file that
## covered the shot, the belt, the walk and the trigger would be four jobs and
## well past [code].gdlintrc[/code]'s public-method cap.
##
## [b]What is here and what is deliberately not.[/b] The angles a press turns
## into are [code]tests/unit/test_tool_aim.gd[/code]'s, and the closest-point
## arithmetic is [code]tests/unit/test_nearest_point.gd[/code]'s; neither is
## repeated. What needs a running game — and is therefore all that is here — is
## whether a real finger on real glass reaches a real panel of the car, whether
## the mark lands on it, and whether the tool that swings to meet it stays out of
## the paint.
##
## [b]The offset between the finger and the aim is not this suite's[/b] either —
## it is [code]tests/integration/test_play_screen_thumb.gd[/code]'s. What it is
## here is a fact every press below has to survive: a touch aims a thumb's width
## above where it lands, so [method _press] takes the point the test wants to aim
## at and works back to the finger that would ask for it. That is the whole of
## this suite's dealings with [ThumbLift], and it is what let the offset land
## without changing a single assertion in the file.
##
## [b]Everything waits on the physics clock[/b], because that is where
## [method Garage._resolve_aim] casts its ray. A test that pressed and asserted
## in the same frame would be asserting against the tick before the press.
extends GutTest

const PLAY_SCREEN: String = "res://src/screens/play_screen.tscn"

## Above GUT's own output layer, so a finger aimed at the game lands on the game
## — the same measurement [code]test_play_screen_walk.gd[/code] records at
## length.
const ABOVE_THE_RUNNER: int = 200

## Close enough for positions in metres — a tenth of a millimetre.
const TOLERANCE: float = 0.0001

## Long enough for the standoff to have eased from the parked stance out to the
## gap the walk wants, which is where every clearance below is measured. A second
## and a half; the walk suite explains the arithmetic.
const SETTLE_FRAMES: int = 90

## Enough physics ticks for a press to have been resolved into a mark, with room
## to spare. Two would do — the aim is answered on the next tick — and this is
## four because a test that is exactly tight enough goes red on a slow machine
## for a reason that has nothing to do with the code.
const RESOLVE_FRAMES: int = 4

## Enough drawn frames for the hand to have finished swinging anywhere inside its
## cone at the speed the room exports. A fifth of a second is the full width; this
## is half a second.
const SWING_FRAMES: int = 30

## How far a held thing may stick out from the anchor in any direction — the same
## number [code]test_play_screen.gd[/code] and the walk suite hold the shot to.
const HELD_REACH: float = 0.45

## How far above the car's own silhouette to press for a shot that is certainly
## sky, in pixels on the glass.
##
## [b]Measured up the screen and not up the world, which was the second attempt
## at this.[/b] The first was "three metres above the roof", and three metres
## above the roof is off the top of the picture: the eye stands 2.2 m off the
## paint looking at the middle of the car, and a 16:9 frame at a 75° lens only
## has about 23° of headroom, which is a shade over a metre of sky above the
## roofline at that range. A press off the top of the screen is not a press at
## all — it lands outside the control and never becomes an event — so those tests
## were passing a nothing through the whole machine and asserting on the result.
##
## Sixty pixels above wherever the car's box actually projects is on the glass by
## construction, tracks the camera when it moves, and is far enough above the
## bodywork that only the nearest-point fallback can answer it. Asserted, in
## [method _at_the_sky], rather than trusted.
const SKY_MARGIN: float = 60.0

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


func _view_model() -> ViewModel:
	return _garage().get_node("%ViewModel") as ViewModel


func _marker() -> AimMarker:
	return _garage().aim_marker()


func _readout() -> Label:
	return _screen.get_node("PanelReadout") as Label


func _car_box() -> AABB:
	return _car().bounds()


## Every name the car can honestly answer with, read off the car rather than
## written down here — so a test that asserts a "real panel" keeps meaning it
## after somebody adds a wing.
func _panel_names() -> Array[String]:
	var names: Array[String] = []
	for panel: Node3D in _car().panels():
		names.append(String(panel.name))
	return names


## Where [param point] in the world lands on the glass.
##
## Through the camera's own projection rather than by writing screen coordinates
## down, because the eye moves: the standoff eases it back a metre and a quarter
## during [method _settle], and a hard-coded pixel that was on the door before
## that is on the driveway after it.
func _on_screen(point: Vector3) -> Vector2:
	return _camera().unproject_position(point)


## The middle of the car, on the glass. The one press that must always land on
## bodywork.
func _at_the_car() -> Vector2:
	return _on_screen(_car().global_position)


## A patch of sky above the roof, on the glass — a press that hits nothing at all
## and has to be answered by the nearest-point fallback.
##
## Derived from where the top of the car actually lands on the glass, then lifted
## [constant SKY_MARGIN] px clear of it, and the result is asserted to be on the
## picture. Without that assertion this silently stops testing anything the day
## the shot changes, which is exactly what it did once already.
func _at_the_sky() -> Vector2:
	var box: AABB = _car_box()
	var roofline: Vector3 = Vector3(_car().global_position.x, box.end.y, _car().global_position.z)
	var sky: Vector2 = _on_screen(roofline) - Vector2(0.0, SKY_MARGIN)
	assert_true(
		Rect2(Vector2.ZERO, Vector2(_view().size)).has_point(sky),
		"the sky press at %v is off the picture and would not be a press at all" % sky
	)
	return sky


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


## [constant ThumbLift.REFERENCE_PX] in this window's design pixels, read the same
## way the screen reads it rather than written down — [code]before_each[/code]
## sizes the window to the design resolution, which makes this 80 today, and a
## copy of 80 here would stop being true the moment that changed.
func _lift_px() -> float:
	return ThumbLift.design_lift(
		get_tree().root.get_final_transform().get_scale().y, DisplayServer.screen_get_scale()
	)


## Where a thumb has to be to aim at [param aim].
##
## [b]Every press below goes through here, which is what keeps the rest of this
## suite about aiming rather than about the offset.[/b] The helpers above answer
## "where is the car on the glass"; the touch that asks about it is a thumb's
## width lower down, and threading that through one function means adding the
## lift did not change a single assertion in the file.
##
## The inverse of [method ThumbLift.raised], both branches of it: a straight
## subtraction outside the strip at the top of the glass, and the parabola's own
## inverse inside it. Asserted rather than trusted — the round trip has to come
## back to the aim that was asked for.
func _thumb_for(aim: Vector2) -> Vector2:
	var lift: float = _lift_px()
	var down: float = aim.y + lift
	if aim.y < lift:
		down = sqrt(4.0 * lift * maxf(aim.y, 0.0))
	var thumb: Vector2 = Vector2(aim.x, down)
	assert_almost_eq(
		ThumbLift.aim_from(thumb, lift).y, maxf(aim.y, 0.0), 0.01, "a thumb at %v aims back" % thumb
	)
	assert_true(
		Rect2(Vector2.ZERO, Vector2(_view().size)).has_point(thumb),
		(
			"the thumb for %v is at %v, which is off the picture and would not be a press"
			% [aim, thumb]
		)
	)
	return thumb


## Presses so that the aim lands at [param at], and waits for the room to have
## answered. The finger itself goes a thumb's width below it — see
## [method _thumb_for].
func _press(at: Vector2) -> void:
	_touch(_thumb_for(at), true)
	await wait_physics_frames(RESOLVE_FRAMES)


## Lifts the finger and waits for the room to have noticed.
func _lift() -> void:
	_touch(Vector2.ZERO, false)
	await wait_physics_frames(RESOLVE_FRAMES)


## Lets the standoff ease out to the gap it wants, so the clearances below are
## measured against a settled camera rather than one still arriving.
func _settle() -> void:
	await wait_physics_frames(SETTLE_FRAMES)


## The gap between [param point] and the nearest face of [param box], and zero if
## the point is inside it. The same per-axis measure the walk suite uses — a
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


## Every corner of the currently held tool's own bounding box, in world space.
## The mesh's local box transformed corner by corner, not a world [AABB] — see
## [code]test_view_model.gd[/code], which makes the same point: a world box
## around a cylinder on a diagonal bulges well past the cylinder.
func _held_corners() -> Array[Vector3]:
	var corners: Array[Vector3] = []
	for child: Node in _view_model().get_children():
		var proxy: MeshInstance3D = child as MeshInstance3D
		if proxy == null or not proxy.visible:
			continue
		var box: AABB = proxy.get_aabb()
		for corner: int in 8:
			corners.append(proxy.global_transform * box.get_endpoint(corner))
	return corners


## Points the hand at [param yaw] and [param pitch] degrees off straight ahead
## and lets the swing arrive.
##
## Straight at the [ToolAim] rather than through a press, on purpose: this is for
## the tests that sweep the corners of the cone, and the corners of the cone are
## at the corners of the screen — where the tool belt and the motion pad live. A
## press there is a press on a button, so driving the aim directly is the only way
## to ask the question the fence is actually for.
func _swing_to(yaw: float, pitch: float) -> void:
	var yawed: float = deg_to_rad(yaw)
	var pitched: float = deg_to_rad(pitch)
	_view_model().aim_toward(
		Vector3(-sin(yawed) * cos(pitched), sin(pitched), -cos(yawed) * cos(pitched))
	)
	await wait_process_frames(SWING_FRAMES)


# ---- the mark on the car -----------------------------------------------------


func test_nothing_is_marked_before_anybody_presses_anything() -> void:
	assert_not_null(_marker(), "the room took up aiming")
	assert_false(_marker().is_marking(), "and is not marking anything yet")
	assert_eq(_readout().text, "", "so the readout says nothing")


func test_a_press_on_the_car_puts_the_crosshair_on_the_car() -> void:
	await _settle()
	await _press(_at_the_car())
	assert_true(_marker().is_marking(), "a press on the bodywork marks it")
	assert_almost_eq(
		_clearance(_car_box(), _marker().marked_point()),
		0.0,
		TOLERANCE,
		"and the mark is on the car rather than beside it"
	)


func test_a_press_on_the_car_names_the_panel_it_hit() -> void:
	# The whole reason the car is separate panels instead of one solid: a hit comes back
	# as a piece of the car with a name, which is what the grime work will hang
	# off. Asserted against the car's own list rather than against the string
	# "Hood", so reshaping the car cannot make this quietly meaningless.
	await _settle()
	await _press(_at_the_car())
	assert_ne(_readout().text, "", "the readout names something")
	assert_has(_panel_names(), _readout().text, "and it is a panel the car really has")


func test_the_mark_stands_off_the_paint_rather_than_fighting_it() -> void:
	# Lifted by [constant AimMarker.LIFT] so the ring does not z-fight the panel.
	# Measured as the gap between where the mark says it is and where its mesh
	# actually sits, because that is the thing that would silently go to zero if
	# somebody simplified the lift away.
	await _settle()
	await _press(_at_the_car())
	var lifted: float = _marker().global_position.distance_to(_marker().marked_point())
	assert_almost_eq(lifted, AimMarker.LIFT, TOLERANCE)


func test_the_crosshair_lies_flat_against_the_panel() -> void:
	# Its +Y is the surface normal — see [method AimMarker._lying_on] — and a
	# normal pointing at the eye is what a surface facing the player has. Without
	# this the ring is a disc seen edge-on, which is the same failure the drying
	# rag has and is invisible for the same reason.
	await _settle()
	await _press(_at_the_car())
	var facing: Vector3 = _camera().global_position - _marker().marked_point()
	assert_gt(
		_marker().global_basis.y.normalized().dot(facing.normalized()),
		0.0,
		"the mark faces the player rather than into the car"
	)


# ---- pressing where the car is not -------------------------------------------


func test_a_press_at_the_sky_still_marks_the_car() -> void:
	# The answer the nearest-point fallback exists for. A press that hits nothing
	# is still a question about the car, and "nothing" is not a useful answer to
	# give a player who is plainly asking about the roof.
	await _settle()
	await _press(_at_the_sky())
	assert_true(_marker().is_marking(), "a press at the sky marks the nearest car")
	assert_lt(
		_clearance(_car_box(), _marker().marked_point()),
		AimMarker.LIFT * 2.0,
		"and the mark is on the car, not floating where the finger was"
	)


func test_a_press_at_the_sky_marks_the_top_of_the_car() -> void:
	# Nearest, and not merely somewhere on the car: pressing above the roof has to
	# find the roof rather than the sill it happens to be numerically closest to
	# in some other measure.
	await _settle()
	await _press(_at_the_car())
	var on_the_car: Vector3 = _marker().marked_point()
	# Lifted between the two, and not for tidiness: the first finger down keeps
	# the aim until it comes up, so a second press without a release is ignored
	# and this test would compare a point with itself.
	await _lift()
	await _press(_at_the_sky())
	assert_gt(_marker().marked_point().y, on_the_car.y, "the sky press marked higher up the car")


func test_a_press_at_the_sky_names_a_panel_too() -> void:
	await _settle()
	await _press(_at_the_sky())
	assert_has(_panel_names(), _readout().text, "the fallback names a real panel")


# ---- the hand follows the finger ---------------------------------------------


func test_the_hand_starts_at_rest() -> void:
	assert_not_null(_view_model().aim(), "the room handed the hand an aim")
	assert_false(_view_model().aim().is_raised(), "and nothing has raised it")


func test_a_press_on_the_right_of_the_glass_swings_the_tool_right() -> void:
	# The sign that is easiest to get backwards, checked in world space rather
	# than in degrees: the anchor's forward, seen from the camera, has to move
	# toward the right of the frame. In degrees this test would be asserting the
	# same convention twice and would pass with the convention inverted.
	await _settle()
	var middle: Vector2 = Vector2(_view().size) * 0.5
	await _press(middle + Vector2(300.0, 0.0))
	await wait_process_frames(SWING_FRAMES)
	assert_gt(_camera().to_local(_view_model().to_global(Vector3.FORWARD)).x, 0.0)


func test_a_press_on_the_left_of_the_glass_swings_the_tool_left() -> void:
	await _settle()
	var middle: Vector2 = Vector2(_view().size) * 0.5
	await _press(middle - Vector2(300.0, 0.0))
	await wait_process_frames(SWING_FRAMES)
	assert_lt(_camera().to_local(_view_model().to_global(Vector3.FORWARD)).x, 0.0)


func test_the_hand_stays_where_the_scene_file_framed_it() -> void:
	# A swing turns the hand; it must not move it. If this drifts, the tool has
	# started sliding across the frame toward the touch and the whole clearance
	# budget below is being spent without anybody deciding to.
	await _settle()
	var framed: Vector3 = _view_model().position
	await _press(_at_the_sky())
	await wait_process_frames(SWING_FRAMES)
	assert_almost_eq(_view_model().position, framed, Vector3.ONE * TOLERANCE)


# ---- letting go --------------------------------------------------------------


func test_lifting_the_finger_takes_the_crosshair_off_the_car() -> void:
	# Holding is firing and letting go is not — so a mark left behind would say
	# the tool is still pointed at something when nothing is.
	await _settle()
	await _press(_at_the_car())
	assert_true(_marker().is_marking(), "marked while the finger is down")
	await _lift()
	assert_false(_marker().is_marking(), "and not once it is up")
	assert_eq(_readout().text, "", "the readout goes quiet too")


func test_lifting_the_finger_brings_the_hand_back_to_rest() -> void:
	await _settle()
	await _press(_at_the_sky())
	await wait_process_frames(SWING_FRAMES)
	assert_true(_view_model().aim().is_raised(), "the hand went up")
	await _lift()
	await wait_process_frames(SWING_FRAMES)
	assert_false(_view_model().aim().is_raised(), "and came back down")
	assert_almost_eq(
		_view_model().transform.basis.get_euler(),
		Vector3.ZERO,
		Vector3.ONE * TOLERANCE,
		"square on to the camera, exactly as the scene file has it"
	)


# ---- the clearance the fence is for ------------------------------------------


func test_the_held_tool_stays_out_of_the_paint_at_every_corner_of_the_cone() -> void:
	# The question the cone exists to answer, and the reason it is a fence rather
	# than a free look. The room stands the eye [member Garage.standoff_metres] off
	# the bodywork partly so a held tool has room; swinging the hand moves every
	# corner of that tool, so the clearance has to hold at the extremes and not
	# only at the rest pose the other suites measure.
	await _settle()
	var box: AABB = _car_box()
	var yaw: float = _garage().aim_yaw_degrees
	var pitch: float = _garage().aim_pitch_degrees
	for corner: Vector2 in [
		Vector2(-yaw, -pitch),
		Vector2(-yaw, pitch),
		Vector2(yaw, -pitch),
		Vector2(yaw, pitch),
		Vector2(0.0, pitch),
		Vector2(0.0, -pitch),
	]:
		await _swing_to(corner.x, corner.y)
		for point: Vector3 in _held_corners():
			assert_gt(
				_clearance(box, point),
				0.0,
				"the tool is inside the car at yaw %.0f pitch %.0f" % [corner.x, corner.y]
			)


func test_the_swing_cannot_put_the_tool_further_out_than_the_shot_allows() -> void:
	# The other half of the same budget: [constant HELD_REACH] is what the parked
	# shot and the walk both promise about how far a held thing sticks out from the
	# anchor, and a swing that turned the tool about a point other than the
	# anchor's own origin would break it.
	await _settle()
	await _swing_to(_garage().aim_yaw_degrees, _garage().aim_pitch_degrees)
	var anchor: Vector3 = _view_model().global_position
	for point: Vector3 in _held_corners():
		assert_lte(anchor.distance_to(point), HELD_REACH, "a tool corner reached past the promise")
