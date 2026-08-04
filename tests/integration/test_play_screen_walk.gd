## Integration test for the other thing the play screen owns: walking the eye
## around the car.
##
## Split out of [code]tests/integration/test_play_screen.gd[/code], which covers
## the shot — where the eye stands and what it can see — for the same two reasons
## [code]test_play_screen_tool_belt.gd[/code] was: these fail for unrelated
## reasons, and one file was about to trip `.gdlintrc`'s public-method cap, which
## is a fair signal that a test file has started doing two jobs.
##
## [b]The walk runs on the physics clock[/b] — the standoff casts a ray, and a
## space state may only be queried while physics is stepping — so everything here
## waits on [code]wait_physics_frames[/code] and lets the engine really drive it.
## The per-frame arithmetic is [code]tests/unit/test_orbit_drive.gd[/code]'s and
## [code]tests/unit/test_standoff.gd[/code]'s job and is not repeated: what is
## here is whether a key and a thumb reach a camera, and whether the camera they
## reach stays somewhere a person could stand.
extends GutTest

const PLAY_SCREEN: String = "res://src/screens/play_screen.tscn"

## What the screen is hung from, and why it is not the test itself.
##
## GUT's runner draws its own output over the same window, on a [CanvasLayer] at
## layer 128 — and GUI picking goes to the highest layer first, so a tap aimed at
## the game's bottom-right corner lands on the runner's log instead. Measured:
## [method Viewport.gui_get_hovered_control] over there was GUT's `TestOutput`,
## and the press reported nothing at all. Above 128, the game is the thing under
## the finger. The tool belt's tests get away without this because their corner
## happens to be one the runner's panel does not reach, which is luck rather than
## a difference.
const ABOVE_THE_RUNNER: int = 200

## Close enough for positions in metres — a tenth of a millimetre.
const TOLERANCE: float = 0.0001

## The keyboard half of the walk. Named here as strings rather than read
## off the screen, because [code]src/screens/play_screen.gd[/code] has no
## [code]class_name[/code] — no screen in this project does — and because the
## real source of truth for both copies is the InputMap in `project.godot`, which
## [method test_the_walk_is_bound_to_keys_as_well_as_buttons] checks they still
## agree with. A name here that drifted off the screen's own would stop moving
## the camera, and every test below would go red rather than quietly pass.
const TURN_LEFT: String = "camera_left"
const TURN_RIGHT: String = "camera_right"
const LIFT_UP: String = "camera_up"
const LIFT_DOWN: String = "camera_down"

## Every one of them, for the tests that sweep the set.
const ACTIONS: Array[String] = [TURN_LEFT, TURN_RIGHT, LIFT_UP, LIFT_DOWN]

## How far a held thing may stick out from the anchor in any direction. Half the
## longest tool on the belt (the power wash wand, 0.72 m) plus room to spare —
## the same number [code]test_play_screen.gd[/code] holds the parked shot to, and
## the point of repeating it here is that a walk has to keep the promise at every
## angle rather than at one.
const HELD_REACH: float = 0.45

## The band the eye has to stay in as it walks: never nearer the bodywork than
## the first, never further off it than the second. Measured to the car's box,
## which is why neither is [member Garage.standoff_metres] — a corner is further
## from a box than a face is, and the standoff is a servo easing toward a target
## rather than a solve.
##
## [b]The numbers are chosen to fail a circle.[/b] That is the only thing they
## are for. Held at the radius that suits the flanks, a fixed circle passes 1.0 m
## from the nose, which is under the first; held at the radius that suits the
## nose it passes 3.41 m from the flanks, which is over the second. The walk as
## it stands ranges 2.18 m to 3.01 m over a lap — measured, by widening each of
## these until it failed and reading the number back — and sits inside both.
const NEAREST: float = 1.5
const FURTHEST: float = 3.25

## How much the radius has to differ between the ends of the car and its flanks
## before the walk counts as following the car's shape rather than a circle drawn
## around it. The car's own half-length and half-width differ by 1.2 m, so
## anything approaching that is the mechanism working.
const NOT_A_CIRCLE: float = 0.5

## Long enough for the standoff to have eased from where the standing shot puts
## the eye to the gap it wants, with room to spare. The parked stance starts a
## metre and a quarter nearer the paint than the walk wants to be — about fifty
## ticks of dolly at the correction speed the scene exports — so this is a second
## and a half.
const SETTLE_FRAMES: int = 90

var _screen: GameScreen = null
var _window_size_before: Vector2i = Vector2i.ZERO


func before_each() -> void:
	# A headless window is 64x64, which is smaller than a single tap target — so
	# the steering band would be the whole screen twice over and the tests below
	# that use a real finger would be measuring that instead.
	# `content_scale_size` is the design resolution from project.godot. Put back
	# in after_each: every suite shares this window.
	var root: Window = get_tree().root
	_window_size_before = root.size
	root.size = root.content_scale_size
	var packed: PackedScene = load(PLAY_SCREEN) as PackedScene
	assert_not_null(packed, "could not load %s" % PLAY_SCREEN)
	if packed == null:
		return
	# Typed locals before add_child_autofree because GUT's helper is untyped, and
	# autofree is what keeps a failing assertion below from being reported as a
	# leak against whichever test runs next. Freeing the layer takes the screen
	# hanging off it with it.
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = ABOVE_THE_RUNNER
	add_child_autofree(layer)
	var screen: GameScreen = packed.instantiate() as GameScreen
	_screen = screen
	layer.add_child(_screen)
	await wait_process_frames(1)


func after_each() -> void:
	# A held action is global state. A test that walked the camera right and left
	# the key down would walk every test after it, and the failure would land
	# somewhere else entirely. A finger left in the steering band is the same thing
	# said with a touch, and losing focus is how the screen itself lets go of one.
	for action: String in ACTIONS:
		Input.action_release(action)
	if _screen != null:
		_screen.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	get_tree().root.size = _window_size_before


func _garage() -> Garage:
	return _screen.get_node("Garage") as Garage


## The camera, the car and the anchor are all reached off the garage rather than
## off the screen: a `%Name` is unique within the scene that *owns* it, so they
## are visible from the room they belong to and not from the screen the room was
## instanced into.
func _camera() -> Camera3D:
	return _garage().get_node("%Camera") as Camera3D


func _car() -> Car:
	return _garage().get_node("%Car") as Car


func _view_model() -> Node3D:
	return _garage().get_node("%ViewModel") as Node3D


## Where a press has to land to ask, at full strength, to go [param direction] —
## halfway across the steering band, in the screen's own coordinates.
##
## Built from [ThumbReach] and the screen's real size rather than from written-down
## pixels, so it follows the band the game actually uses. The screen is full-rect on
## a full-rect host, so its coordinates are the glass's.
func _steer_point(direction: Vector2i) -> Vector2:
	var half: Vector2 = _screen.size * 0.5
	return half + ThumbReach.steer_point(direction, half, ThumbReach.steer_band())


## The car's bounding box in world space — read off the car rather than written
## down again here, so it keeps meaning "the car" after somebody reshapes it.
##
## [Car.bounds] rather than an [AABB] off a mesh, because the car is twelve
## CSG panels now and there is no one visual instance left to ask. It is wider
## than the bodywork by the reach of the wing mirrors, which only makes every
## clearance below more conservative.
func _car_box() -> AABB:
	return _car().bounds()


## The gap between [param point] and the nearest face of [param box], and zero
## if the point is inside it. Written out per axis rather than leaning on the
## centre-to-centre distance, which for a 4.3 m long car is off by metres.
func _clearance(box: AABB, point: Vector3) -> float:
	var low: Vector3 = box.position - point
	var high: Vector3 = point - box.end
	var gap: Vector3 = Vector3(
		maxf(maxf(low.x, high.x), 0.0),
		maxf(maxf(low.y, high.y), 0.0),
		maxf(maxf(low.z, high.z), 0.0)
	)
	return gap.length()


## How far the car is from the outer edge of the modeled ground, read off the
## grass itself.
func _ground_half_width() -> float:
	var grass: Node3D = _garage().get_node("View/World/Ground/GrassRight") as Node3D
	return grass.position.x + grass.scale.x * 0.5


## How far the eye stands from the middle of the car, measured flat on the floor
## — the radius the walk is currently on.
func _radius() -> float:
	var eye: Vector3 = _camera().global_position
	var car: Vector3 = _car().global_position
	return Vector2(eye.x - car.x, eye.z - car.z).length()


## Where the eye is on its lap, in degrees, on [CameraOrbit]'s convention: zero
## is due +Z of the car.
func _bearing() -> float:
	var eye: Vector3 = _camera().global_position
	var car: Vector3 = _car().global_position
	return rad_to_deg(atan2(eye.x - car.x, eye.z - car.z))


## How far the eye has walked since [param before], signed and wrapped, so a step
## that happens to cross zero reads as the step it was rather than as a jump most
## of the way round the car.
func _walked(before: float) -> float:
	return wrapf(_bearing() - before, -CameraOrbit.FULL_TURN * 0.5, CameraOrbit.FULL_TURN * 0.5)


## How many physics ticks half a lap takes at the speed the scene exports. Half,
## because the car is symmetric — a nose, a flank and a tail is every shape it
## has — and because a whole lap is nine seconds of real time in a suite that
## runs on every push. Read off the garage rather than written down, so retuning
## the walk retunes the test instead of breaking it.
func _half_lap_frames() -> int:
	var degrees: float = CameraOrbit.FULL_TURN * 0.5
	var seconds: float = degrees / _garage().turn_degrees_per_second
	return int(seconds * float(Engine.physics_ticks_per_second))


## Holds [param action] and lets the walk run for [param frames] physics ticks.
##
## Through [method Input.action_press] rather than a key event because that is
## what a held key [i]is[/i] to the engine, and it is the same state
## [method Input.get_axis] reads in the play screen — so this exercises the real
## path rather than a parallel one.
func _hold(action: String, frames: int) -> void:
	Input.action_press(action)
	await wait_physics_frames(frames)
	Input.action_release(action)


## Lets the standoff ease from the standing shot to the gap it wants, so the
## measurements below are of a settled camera rather than of one still arriving.
func _settle() -> void:
	await wait_physics_frames(SETTLE_FRAMES)


## [param at] in the screen's own coordinates, as the window coordinate a touch has
## to arrive at to land there.
##
## [b]The two are the same number at the design resolution and only there.[/b]
## [method Input.parse_input_event] takes a window coordinate, and the engine scales
## it into the canvas by `window/stretch/mode` on the way in — which is a no-op while
## `before_each` holds the window at `content_scale_size`, and is emphatically not one
## in [method test_a_portrait_phone_can_still_reach_the_band_that_moves_your_eye],
## which resizes away from it on purpose. Measured the hard way: without this the
## portrait press landed at 1.8x its intended depth into the glass, missed the band
## entirely and read as a control that had stopped working.
func _on_the_window(at: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * at


## Puts a finger on the glass at [param at], in the screen's own coordinates.
func _touch(at: Vector2, pressed: bool) -> void:
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.position = _on_the_window(at)
	touch.pressed = pressed
	Input.parse_input_event(touch)
	Input.flush_buffered_events()


## Slides that finger to [param at] without lifting it. A different event from the
## press, delivered to a different branch of the screen, which is exactly the kind
## of pair that gets one half wired.
func _drag(at: Vector2) -> void:
	var dragged: InputEventScreenDrag = InputEventScreenDrag.new()
	dragged.position = _on_the_window(at)
	Input.parse_input_event(dragged)
	Input.flush_buffered_events()


func test_the_eye_can_be_walked_around_the_car() -> void:
	assert_true(_garage().walkaround, "the game is a car you can walk around")


func test_the_camera_holds_still_until_it_is_asked_not_to() -> void:
	# The showcase orbit is off, and this is the effect of that rather than the
	# property. A camera that drifted with nobody touching the screen is the
	# screensaver that property turned off, wearing a different coat.
	await _settle()
	var before: Vector3 = _camera().global_position
	await wait_physics_frames(30)
	assert_almost_eq(_camera().global_position.distance_to(before), 0.0, TOLERANCE)


func test_the_walk_is_bound_to_keys_as_well_as_buttons() -> void:
	# The band is the spec and is what ships; these exist because nobody at a desk
	# is going to drag a pointer to the edge of a window to walk around a car. An
	# action missing from the InputMap would make `Input.get_axis` push an error on
	# every frame the game is running.
	for action: String in ACTIONS:
		assert_true(InputMap.has_action(action), "%s is not bound in project.godot" % action)


func test_holding_right_walks_the_eye_round_the_car() -> void:
	await _settle()
	var before: float = _bearing()
	await _hold(TURN_RIGHT, 30)
	assert_gt(_walked(before), 0.0, "right walks you toward +X, which is the camera's own right")


func test_holding_left_walks_it_the_other_way() -> void:
	# The sign convention, at the far end of the chain that starts with a triangle
	# drawn on a button. A mirrored control is not a subtle thing to play with, and
	# it is invisible to every test that only checks that something moved.
	await _settle()
	var before: float = _bearing()
	await _hold(TURN_LEFT, 30)
	assert_lt(_walked(before), 0.0, "left is the other way")


func test_letting_go_stops_the_walk() -> void:
	# The half that matters most: a camera that kept going after the key came up
	# is a game that has taken the wheel off the player.
	await _settle()
	await _hold(TURN_RIGHT, 30)
	await _settle()
	var stopped: Vector3 = _camera().global_position
	await wait_physics_frames(30)
	assert_almost_eq(_camera().global_position.distance_to(stopped), 0.0, TOLERANCE)


func test_holding_up_raises_the_eye_and_down_lowers_it() -> void:
	await _settle()
	var standing: float = _camera().global_position.y
	await _hold(LIFT_UP, 30)
	var raised: float = _camera().global_position.y
	assert_gt(raised, standing, "up must raise the eye")
	await _hold(LIFT_DOWN, 60)
	assert_lt(_camera().global_position.y, raised, "and down must lower it")


func test_the_eye_cannot_be_walked_up_through_the_roof() -> void:
	# Two seconds of holding up is more than the whole range, so this is the fence
	# rather than the speed.
	await _hold(LIFT_UP, 120)
	assert_lte(_camera().global_position.y, _garage().eye_height_max + TOLERANCE)


func test_the_eye_cannot_be_walked_down_through_the_floor() -> void:
	await _hold(LIFT_DOWN, 120)
	assert_gte(_camera().global_position.y, _garage().eye_height_min - TOLERANCE)
	assert_gt(_camera().global_position.y, 0.0, "and above the floor it is standing on")


func test_a_thumb_at_the_edge_of_the_glass_walks_the_eye_too() -> void:
	# The whole chain, through a real finger: a touch, to [ThumbReach], to the play
	# screen's poll, to the garage, to a camera. Everything else here drives the
	# keyboard half, which shares only the last three of those — so without this, a
	# band wired to nothing would pass.
	await _settle()
	var before: float = _bearing()
	var at: Vector2 = _steer_point(ThumbReach.RIGHT)
	_touch(at, true)
	await wait_physics_frames(30)
	var walked: float = _walked(before)
	_touch(at, false)
	assert_gt(walked, 0.0, "a thumb in the right-hand band must walk you right")


func test_a_thumb_in_a_corner_of_the_glass_walks_and_lifts_at_the_same_time() -> void:
	# The reason the band is a border rather than two sliders, at the far end of the
	# chain: one thumb in a corner of the frame asks for both axes, and both have to
	# survive the summing in the play screen's poll and the clamping in [OrbitDrive].
	# Neither is true of two buttons a single finger cannot hold at once.
	#
	# The bottom-right corner and not the top-right, because the top-right is the
	# grime board's toggle — a real [Button], which is hit-tested before this screen
	# and takes the press. That is the right outcome and not a bug (a control that is
	# there wins), but it makes that one corner a place a test cannot steer from. The
	# bottom-right is the corner the thumb stick used to own and now nothing does.
	await _settle()
	var before: float = _bearing()
	var standing: float = _camera().global_position.y
	var at: Vector2 = _steer_point(ThumbReach.RIGHT + ThumbReach.DOWN)
	_touch(at, true)
	await wait_physics_frames(30)
	var walked: float = _walked(before)
	var lowered: float = _camera().global_position.y
	_touch(at, false)
	assert_gt(walked, 0.0, "the corner of the frame walks you round the car")
	assert_lt(lowered, standing, "and lowers your eye on the way")


func test_a_thumb_pulled_back_into_the_middle_stops_the_walk_without_letting_go() -> void:
	# "Reach out, then come back" is the gesture the band is designed around: the
	# player drags the shot toward them and settles it with the same thumb, rather
	# than lifting and re-pressing. So a steering finger dragged into the quiet
	# middle has to go quiet while it is still down — and it has to *keep* the
	# steering job, which is the half a naive re-classify-every-drag would break by
	# turning it into an aim.
	await _settle()
	var before: float = _bearing()
	_touch(_steer_point(ThumbReach.RIGHT), true)
	await wait_physics_frames(30)
	var walked: float = _walked(before)
	_drag(_screen.size * 0.5)
	# Two ticks for the poll to have read the new offset, so what is measured after
	# them is a stopped camera rather than one still finishing the frame it was on.
	await wait_physics_frames(2)
	var settled: float = _bearing()
	await wait_physics_frames(30)
	var crept: float = _walked(settled)
	_touch(_screen.size * 0.5, false)
	assert_gt(walked, 0.0, "the test needs the reach out to have walked the eye")
	assert_almost_eq(crept, 0.0, TOLERANCE, "a thumb back in the middle asks for nothing")


func test_losing_focus_stops_a_walk_nobody_can_let_go_of() -> void:
	# The one thing four arrow buttons were immune to by construction, bought back by
	# hand. A finger on the glass when the browser tab is switched away never sends
	# its release, and a screen still holding that direction is a camera walking on
	# its own when the player comes back.
	await _settle()
	var before: float = _bearing()
	_touch(_steer_point(ThumbReach.RIGHT), true)
	await wait_physics_frames(30)
	assert_gt(_walked(before), 0.0, "the test needs the reach to have landed")
	_screen.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await wait_physics_frames(2)
	var stopped: float = _bearing()
	await wait_physics_frames(30)
	assert_almost_eq(_walked(stopped), 0.0, TOLERANCE, "the camera must not still be walking")


func test_a_portrait_phone_can_still_reach_the_band_that_moves_your_eye() -> void:
	# [b]The bug a phone found and this suite could not.[/b] `window/stretch/aspect`
	# is `expand`, so a portrait screen does not letterbox the 16:9 design — it grows
	# the viewport downward, to 1280 x 2611 design px on a 411x838 CSS phone. A band
	# of a fixed 164 design px is 6.3% of that height, tucked into the two hardest
	# edges of the device to reach and, in Firefox for Android, the two the browser
	# owns: its toolbar along the bottom, pull-to-refresh at the top. Turning worked
	# and lifting did not. [constant ThumbReach.BAND_FRACTION] has the fix.
	#
	# Driven through a real resize and a real finger rather than asserted on the
	# arithmetic, because the arithmetic is
	# [code]tests/unit/test_thumb_reach.gd[/code]'s and what is new here is the whole
	# chain surviving a shape the game is genuinely played in.
	get_tree().root.size = Vector2i(720, 1280)
	# Two frames: one for the window, one for the anchors to have re-laid the screen
	# out under it, since every number below is read off the screen's own size.
	await wait_process_frames(2)
	var half: Vector2 = _screen.size * 0.5
	assert_gt(half.y, half.x, "the test needs a viewport that is actually portrait")
	assert_gt(
		ThumbReach.band_axes(half, ThumbReach.steer_band()).y,
		ThumbReach.steer_band(),
		"a tall screen has to get more than the floor, or lifting is unreachable again"
	)
	await _settle()
	var standing: float = _camera().global_position.y
	var at: Vector2 = _steer_point(ThumbReach.DOWN)
	_touch(at, true)
	await wait_physics_frames(30)
	var lowered: float = _camera().global_position.y
	_touch(at, false)
	assert_lt(lowered, standing, "a thumb in the bottom band of a portrait phone lowers the eye")


func test_a_browser_resizing_under_a_held_thumb_does_not_stop_the_walk() -> void:
	# A phone browser changes the viewport whenever its own toolbar shows or hides,
	# which on Firefox for Android happens under a thumb that is already down. The
	# first version of this screen let go of the steer on [signal Control.resized] to
	# avoid reporting a direction measured against an old middle — so the walk died
	# every time the toolbar moved. Keeping the finger's position instead of its
	# offset makes a resize a non-event, and this is what says so.
	await _settle()
	var at: Vector2 = _steer_point(ThumbReach.RIGHT)
	_touch(at, true)
	await wait_physics_frames(10)
	get_tree().root.size = Vector2i(1000, 700)
	await wait_process_frames(2)
	var before: float = _bearing()
	await wait_physics_frames(30)
	var walked: float = _walked(before)
	_touch(at, false)
	assert_gt(walked, 0.0, "the walk has to survive the browser moving its own furniture")


func test_a_press_on_the_car_does_not_walk_the_camera() -> void:
	# The other half of the split, and the one the whole design turns on: a press in
	# the middle of the frame cleans and moves nothing. A band that had crept inward
	# — or a screen that had gone back to steering from every press — would show up
	# as a camera that drifts whenever the player washes a panel, which is the
	# failure that made "one press does both" the wrong answer.
	await _settle()
	var before: Vector3 = _camera().global_position
	_touch(_screen.size * 0.5, true)
	await wait_physics_frames(30)
	var strayed: float = before.distance_to(_camera().global_position)
	_touch(_screen.size * 0.5, false)
	assert_almost_eq(strayed, 0.0, TOLERANCE, "washing a panel must not walk you round the car")


func test_the_eye_keeps_looking_at_the_car_as_it_walks() -> void:
	# The aim is recomputed every tick, so a camera that walks but forgets to turn
	# — the classic version of this bug — fails here rather than in a build.
	await _hold(TURN_RIGHT, 90)
	var to_car: Vector3 = (_car().global_position - _camera().global_position).normalized()
	var looking: Vector3 = -_camera().global_transform.basis.z
	assert_almost_eq(looking.dot(to_car), 1.0, TOLERANCE)


func test_a_walk_round_the_car_keeps_its_distance_and_its_room() -> void:
	# [b]One walk, four promises.[/b] Every assertion below is about the same half
	# lap and can only be made while it is happening, and a lap is seconds of real
	# time in a suite that runs on every push — so they share one rather than each
	# paying for their own.
	#
	# The first two are the reason [Standoff] exists. A fixed radius that clears
	# the 2.15 m nose of this car stands 2.15 m off its doors; one that hugs the
	# doors passes straight through the bumper. The third is the same fact from
	# the other side — if the radius never changed, the walk would be a circle and
	# one of the first two would already have failed. The fourth is the clipping
	# promise from [code]test_play_screen.gd[/code], which used to be one
	# measurement at one parked position and now has to hold everywhere, including
	# where the standoff pulls in tightest.
	await _settle()
	Input.action_press(TURN_RIGHT)
	var box: AABB = _car_box()
	var half_width: float = _ground_half_width()
	var nearest: float = INF
	var furthest: float = 0.0
	var tightest_radius: float = INF
	var widest_radius: float = 0.0
	var held_clearance: float = INF
	var strayed: Vector3 = Vector3.ZERO
	for _tick: int in range(_half_lap_frames()):
		await wait_physics_frames(1)
		var eye: Vector3 = _camera().global_position
		nearest = minf(nearest, _clearance(box, eye))
		furthest = maxf(furthest, _clearance(box, eye))
		tightest_radius = minf(tightest_radius, _radius())
		widest_radius = maxf(widest_radius, _radius())
		held_clearance = minf(held_clearance, _clearance(box, _view_model().global_position))
		if absf(eye.x) >= half_width or box.has_point(eye):
			strayed = eye
	Input.action_release(TURN_RIGHT)
	assert_gt(nearest, NEAREST, "the eye must never scrape the paint")
	assert_lt(furthest, FURTHEST, "nor drift out into the middle of the room")
	assert_gt(
		widest_radius - tightest_radius, NOT_A_CIRCLE, "the lap must follow the car, not a circle"
	)
	assert_gt(held_clearance, HELD_REACH, "a held tool must not be able to reach into the car")
	assert_eq(
		strayed, Vector3.ZERO, "the eye walked off the ground or into the car at %s" % strayed
	)
