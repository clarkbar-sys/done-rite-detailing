## Integration test for the one tool that is aimed rather than merely held: the
## power wash wand, lying on the line between its own nozzle and the crosshair.
##
## [b]Why this is a suite of its own[/b] and not four more tests in
## [code]test_play_screen_aim.gd[/code]: that file is already at
## [code].gdlintrc[/code]'s public-method cap, and it is about where the mark
## lands and where the hand swings — both of which are true for all five tools.
## This is about the shape of one of them.
##
## [b]What it is for.[/b] The water is not written yet, and when it is it will be
## particles born at the [code]Muzzle[/code] marker and pushed along that node's
## own [code]-Z[/code]. Everything below is the promise that makes that the whole
## of the effect: emit along the wand and the water lands on the crosshair,
## because the wand, its nozzle and the crosshair are one line rather than three
## points that nearly agree. Nothing here draws a particle — what is measured is
## the geometry the particles will inherit, which is the part that can be wrong
## silently.
##
## [b]Everything goes through a real press.[/b] Driving [method ViewModel.aim_at]
## by hand would skip the ray, and the ray is what the wand is pointed at — the
## room only knows where the crosshair is because it cast one. It also means the
## finger stays down for the length of each test, because a press and a release
## are the two halves of what is being asserted; [method after_each] lifts it.
extends GutTest

const PLAY_SCREEN: String = "res://src/screens/play_screen.tscn"

## Above GUT's own output layer, so a finger aimed at the game lands on the game.
const ABOVE_THE_RUNNER: int = 200

## Close enough for positions in metres — a tenth of a millimetre.
const TOLERANCE: float = 0.0001

## How near the crosshair the wand's own line has to pass, in metres.
##
## Measured at under a tenth of a millimetre — the whole suite passes with this
## set to [constant TOLERANCE], on the car and at the sky alike, because the wand
## is aimed at the marked point rather than fitted to it. Two centimetres is two
## hundred times that, and still a twentieth of
## [member Garage.wash_radius_metres]: loose enough to survive a slower machine
## resolving one frame differently, tight enough that anything that could be seen
## fails it.
const ON_THE_LINE: float = 0.02

## Long enough for the standoff to have eased from the parked stance out to the
## gap the walk wants, which is where every clearance below is measured.
const SETTLE_FRAMES: int = 90

## Enough physics ticks for a press to have been resolved into a mark.
const RESOLVE_FRAMES: int = 4

## Enough drawn frames for the swing to have arrived and the tool to have come
## all the way up — a fifth of a second and a sixth of one respectively, and this
## is half a second.
const SWING_FRAMES: int = 30

## How far a held thing may stick out from the anchor in any direction, the same
## promise [code]test_play_screen_aim.gd[/code] holds the swing to. An aimed wand
## turns about the anchor with half of itself either side, so it is bound by this
## as much as a hand-posed tool is.
const HELD_REACH: float = 0.45

## How far above the car's own silhouette to press for a shot that is certainly
## sky, in pixels on the glass. Off the car's projected box rather than written
## down, for the reason the aim suite gives at length: a fixed pixel stops being
## sky the moment the shot changes.
const SKY_MARGIN: float = 60.0

var _screen: GameScreen = null
var _window_size_before: Vector2i = Vector2i.ZERO


func before_each() -> void:
	# A headless window is 64x64, which is smaller than one tap target — so every
	# screen coordinate below would be off the picture. Put back in after_each:
	# every suite shares this window.
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


func _view() -> SubViewport:
	return _garage().get_node("View") as SubViewport


func _car() -> Car:
	return _garage().get_node("%Car") as Car


func _view_model() -> ViewModel:
	return _garage().view_model()


func _marker() -> AimMarker:
	return _garage().aim_marker()


func _wand() -> MeshInstance3D:
	return _view_model().proxy_for(DetailingTool.Id.POWER_WASH)


## The wand as a line in the world: where the nozzle is, and which way it runs.
## Read off the two markers rather than off the mesh's basis, so this measures
## the thing a jet will actually be parented to.
func _nozzle() -> Vector3:
	return _view_model().muzzle().global_position


func _along_the_wand() -> Vector3:
	return _view_model().butt().global_position.direction_to(_nozzle())


## The same direction, read in the camera's own frame.
##
## What every "did it move" comparison below uses, because the world one moves
## when the eye does: the standoff is still easing by fractions of a degree long
## after [method _settle], and a test that compared world directions across a
## press would be measuring the camera as well as the wand.
func _wand_in_view() -> Vector3:
	return _camera().global_transform.basis.inverse() * _along_the_wand()


func _crosshair() -> Vector3:
	return _marker().marked_point()


func _on_screen(point: Vector3) -> Vector2:
	return _camera().unproject_position(point)


## The middle of the car, on the glass. The one press that must always land on
## bodywork.
func _at_the_car() -> Vector2:
	return _on_screen(_car().global_position)


## A patch of sky above the roof: a press that hits nothing, so the mark comes
## from the nearest-point fallback and is somewhere the finger is not.
func _at_the_sky() -> Vector2:
	var roof: Vector3 = Vector3(
		_car().global_position.x, _car().bounds().end.y, _car().global_position.z
	)
	var sky: Vector2 = _on_screen(roof) - Vector2(0.0, SKY_MARGIN)
	assert_true(
		Rect2(Vector2.ZERO, Vector2(_view().size)).has_point(sky),
		"the sky press at %v is off the picture and would not be a press at all" % sky
	)
	return sky


func _touch(at: Vector2, pressed: bool) -> void:
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.position = at
	touch.pressed = pressed
	Input.parse_input_event(touch)
	Input.flush_buffered_events()


## Presses at [param at] and holds, then waits for the room to have marked
## something and the tool to have finished coming up.
func _press(at: Vector2) -> void:
	_touch(at, true)
	await wait_physics_frames(RESOLVE_FRAMES)
	await wait_process_frames(SWING_FRAMES)


func _lift() -> void:
	_touch(Vector2.ZERO, false)
	await wait_physics_frames(RESOLVE_FRAMES)
	await wait_process_frames(SWING_FRAMES)


func _settle() -> void:
	await wait_physics_frames(SETTLE_FRAMES)


## How far [param point] is off the line the wand lies on. The perpendicular
## distance, which is zero only when the wand really would spray through it.
func _off_the_wands_line(point: Vector3) -> float:
	var reach: Vector3 = point - _nozzle()
	return reach.cross(_along_the_wand()).length()


## Every corner of the wand's own box, in world space. The mesh's local box
## transformed corner by corner and not a world [AABB] — a world box around a
## cylinder on a diagonal bulges well past the cylinder, and every clearance
## below would then be measured against empty air.
func _wand_corners() -> Array[Vector3]:
	var corners: Array[Vector3] = []
	var box: AABB = _wand().get_aabb()
	for corner: int in 8:
		corners.append(_wand().global_transform * box.get_endpoint(corner))
	return corners


## The gap between [param point] and the nearest face of [param box], and zero if
## the point is inside it.
func _clearance(box: AABB, point: Vector3) -> float:
	var low: Vector3 = box.position - point
	var high: Vector3 = point - box.end
	var gap: Vector3 = Vector3(
		maxf(maxf(low.x, high.x), 0.0),
		maxf(maxf(low.y, high.y), 0.0),
		maxf(maxf(low.z, high.z), 0.0)
	)
	return gap.length()


# ---- the line the water will travel ------------------------------------------


func test_a_press_on_the_car_lays_the_wand_on_the_line_to_the_crosshair() -> void:
	# The whole feature, measured the way it will fail: not "is the wand roughly
	# parallel to the aim" but "would something leaving the nozzle along the wand
	# arrive at the mark". A wand parallel to the aim and offset from the eye passes
	# the first and misses the second by a fifth of a metre.
	await _settle()
	await _press(_at_the_car())
	assert_true(_marker().is_marking(), "there is a crosshair to line up with")
	assert_lt(_off_the_wands_line(_crosshair()), ON_THE_LINE, "the wand does not point at the mark")


func test_the_nozzle_points_at_the_crosshair_rather_than_merely_toward_it() -> void:
	# The same fact in the form the particle system will ask it in: the direction
	# out of the nozzle and the direction from the nozzle to the mark are one
	# direction. Asserted on the marker's own -Z, because that is the axis a
	# [GPUParticles3D] emits along and therefore the one that has to be right.
	await _settle()
	await _press(_at_the_car())
	var out: Vector3 = -_view_model().muzzle().global_basis.z.normalized()
	assert_almost_eq(out.dot(_nozzle().direction_to(_crosshair())), 1.0, 0.001)


func test_the_nozzle_is_the_end_of_the_wand_nearest_the_car() -> void:
	# Which way round it is aimed. Both ends of a cylinder lie on its axis, so an
	# alignment that pointed the hose at the car would satisfy every line above.
	await _settle()
	await _press(_at_the_car())
	assert_lt(
		_nozzle().distance_to(_crosshair()),
		_view_model().butt().global_position.distance_to(_crosshair()),
		"the water comes out of the end facing the paint"
	)


func test_a_press_at_the_sky_still_lines_the_wand_up_with_the_crosshair() -> void:
	# The case the wand follows the mark rather than the finger for, and the reason
	# [method ViewModel.mark_at] takes a point instead of a distance. A thumb on a
	# low car sends the ray over the roof often enough that this is normal play: the
	# crosshair snaps back to the bodywork, the water goes there, and the wand has
	# to be pointed where the water goes.
	await _settle()
	await _press(_at_the_sky())
	assert_true(_marker().is_marking(), "the fallback marked the nearest bodywork")
	assert_lt(
		_clearance(_car().bounds(), _crosshair()),
		AimMarker.LIFT * 2.0,
		"and it is on the car rather than out where the finger pointed"
	)
	assert_lt(_off_the_wands_line(_crosshair()), ON_THE_LINE, "so the wand is pointed at the car")


func test_the_wand_follows_the_crosshair_as_the_press_moves() -> void:
	# A drag, in the only form that matters here: two different marks, two different
	# wand directions, and the alignment holding at both. Without this, an alignment
	# computed once and cached would pass every test above.
	await _settle()
	await _press(_at_the_car())
	var first: Vector3 = _wand_in_view()
	var marked: Vector3 = _crosshair()
	await _lift()
	await _press(_at_the_sky())
	assert_gt(_crosshair().distance_to(marked), 0.1, "the second press marked somewhere else")
	assert_gt(rad_to_deg(_wand_in_view().angle_to(first)), 1.0, "and the wand went with it")
	assert_lt(_off_the_wands_line(_crosshair()), ON_THE_LINE)


# ---- and it is a tool in a hand the rest of the time -------------------------


func test_the_wand_is_across_the_frame_until_somebody_aims_it() -> void:
	# The rule [code]test_view_model.gd[/code] holds for every cylinder on the belt:
	# a wand pointed down the barrel is a disc. Aligning it while aiming is the
	# point of all this; aligning it while nobody is aiming would have been a tool
	# that reads as a circle in the corner of the screen for most of the game.
	await _settle()
	assert_lt(absf(_wand_in_view().dot(Vector3.FORWARD)), 0.866, "held, not aimed")


func test_letting_go_puts_the_wand_back_across_the_frame() -> void:
	await _settle()
	var at_rest: Vector3 = _wand_in_view()
	await _press(_at_the_car())
	assert_gt(rad_to_deg(_wand_in_view().angle_to(at_rest)), 10.0, "the press brought it up")
	await _lift()
	assert_almost_eq(
		_wand_in_view(), at_rest, Vector3.ONE * TOLERANCE, "and the release put it back"
	)


func test_an_aimed_wand_stays_out_of_the_paint_and_inside_the_shot() -> void:
	# The three budgets the room's docs record, held at the poses that spend the
	# most of all of them: fully aimed, at presses spread across the glass rather
	# than at the one in the middle. The wand turns about the anchor instead of
	# being slid along its own axis first, which is what keeps half a wand — 0.36 m
	# — inside the 0.45 m every other tool is already allowed, and what keeps its
	# butt in front of a 0.05 m near plane with the rest of it pointed away.
	#
	# Worth being thorough about, because this is the one thing on screen that is no
	# longer inside [member Garage.aim_yaw_degrees]: the wand follows the mark, and
	# the mark is wherever the nearest bodywork happens to be. What keeps it safe is
	# not the fence but the standoff — everything it can point at is at least
	# [member Garage.standoff_metres] away — and that is the claim being tested.
	await _settle()
	var middle: Vector2 = Vector2(_view().size) * 0.5
	for at: Vector2 in [
		_at_the_car(),
		_at_the_sky(),
		middle + Vector2(400.0, 0.0),
		middle - Vector2(400.0, 0.0),
	]:
		await _press(at)
		var car: AABB = _car().bounds()
		var anchor: Vector3 = _view_model().global_position
		var near: float = _camera().near
		for corner: Vector3 in _wand_corners():
			assert_gt(_clearance(car, corner), 0.0, "the wand is inside the car, pressing %v" % at)
			assert_lte(
				anchor.distance_to(corner), HELD_REACH, "reached past the promise at %v" % at
			)
			assert_lt(
				_camera().to_local(corner).z, -near, "the wand clips the near plane at %v" % at
			)
		await _lift()


func test_the_other_four_tools_are_held_exactly_where_they_always_were() -> void:
	# The instruction this refactor was given, asserted rather than reviewed: only
	# the power wash is aimed. Each tool is measured at rest, then again with a
	# finger on the glass and the same tool in hand — a carry that had grown an
	# opinion about the aim would move one of them.
	await _settle()
	var before: Dictionary = {}
	for tool: DetailingTool in DetailingTool.catalogue():
		_view_model().belt().equip(tool.id)
		await wait_process_frames(1)
		before[tool.id] = _view_model().proxy_for(tool.id).transform
	await _press(_at_the_car())
	for tool: DetailingTool in DetailingTool.catalogue():
		if tool.id == DetailingTool.Id.POWER_WASH:
			continue
		_view_model().belt().equip(tool.id)
		await wait_process_frames(SWING_FRAMES)
		var held: Transform3D = _view_model().proxy_for(tool.id).transform
		var was: Transform3D = before[tool.id]
		assert_almost_eq(held.origin, was.origin, Vector3.ONE * TOLERANCE, tool.display_name)
		assert_almost_eq(held.basis.y, was.basis.y, Vector3.ONE * TOLERANCE, tool.display_name)


func test_the_wand_is_the_one_that_moved() -> void:
	# The other half of the test above: a suite that only asserted "nothing moved"
	# would pass with the whole feature deleted.
	await _settle()
	var was: Transform3D = _wand().transform
	await _press(_at_the_car())
	assert_gt(
		rad_to_deg(_wand().transform.basis.y.angle_to(was.basis.y)),
		10.0,
		"aiming turns the power wash in the hand"
	)
