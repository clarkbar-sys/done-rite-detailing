## Unit tests for [CameraOrbit] — the arithmetic behind the menu camera.
##
## Under tests/unit/ because a [CameraOrbit] is a [RefCounted]: a full
## revolution is a `for` loop here rather than half a minute of real frames in a
## scene. That the garage's camera is actually *moved* by these numbers is
## [code]tests/integration/test_garage.gd[/code]'s job.
extends GutTest

## A tenth of a millimetre. Every assertion below compares positions on a circle
## built from `sin`/`cos`, so exact equality is not on offer; this is far tighter
## than an eye could see and far looser than float noise.
const TOLERANCE: float = 0.0001

## Stand-ins for the numbers the garage scene exports, deliberately distinct
## from each other so a swapped argument fails instead of cancelling out.
const RADIUS: float = 5.0
const HEIGHT: float = 1.6
const SPEED: float = 12.0

## How long a whole revolution takes at [constant SPEED].
const FULL_TURN_SECONDS: float = CameraOrbit.FULL_TURN / SPEED

## Somewhere emphatically not the origin — see
## [method test_it_circles_the_focus_and_not_the_origin].
const FOCUS: Vector3 = Vector3(3.0, 0.7, -2.0)

var _orbit: CameraOrbit = null


func before_each() -> void:
	_orbit = CameraOrbit.new(RADIUS, HEIGHT, SPEED)


func test_it_starts_where_it_was_built() -> void:
	assert_eq(_orbit.radius, RADIUS)
	assert_eq(_orbit.height, HEIGHT)
	assert_eq(_orbit.degrees_per_second, SPEED)
	assert_eq(_orbit.angle_degrees, 0.0, "a fresh orbit has not moved yet")


func test_angle_zero_stands_due_z_of_the_focus() -> void:
	# The one place the convention is pinned down. Everything else here is
	# relative, so without this the whole circle could be rotated and still pass.
	var eye: Vector3 = _orbit.eye(FOCUS)
	assert_almost_eq(eye.x, FOCUS.x, TOLERANCE, "angle 0 is not off to one side")
	assert_almost_eq(eye.z, FOCUS.z + RADIUS, TOLERANCE, "angle 0 stands +Z of the focus")


func test_the_eye_sits_the_stated_height_above_the_focus() -> void:
	# Height is above the *focus*, not above the floor: the camera looks at the
	# middle of the car, so a height measured from y=0 would aim it at the roof.
	for angle: float in [0.0, 90.0, 217.0, 359.0]:
		_orbit.angle_degrees = angle
		var eye: Vector3 = _orbit.eye(FOCUS)
		assert_almost_eq(eye.y, FOCUS.y + HEIGHT, TOLERANCE, "at %f deg" % angle)


func test_it_keeps_its_distance_all_the_way_round() -> void:
	for angle: float in [0.0, 45.0, 90.0, 180.0, 270.0, 330.0]:
		_orbit.angle_degrees = angle
		var eye: Vector3 = _orbit.eye(FOCUS)
		var flat: Vector2 = Vector2(eye.x - FOCUS.x, eye.z - FOCUS.z)
		assert_almost_eq(flat.length(), RADIUS, TOLERANCE, "at %f deg" % angle)


func test_it_circles_the_focus_and_not_the_origin() -> void:
	# The bug this pins: `Vector3(sin * r, height, cos * r)` without the focus
	# term compiles, orbits beautifully, and orbits the wrong place.
	_orbit.angle_degrees = 180.0
	var eye: Vector3 = _orbit.eye(FOCUS)
	assert_almost_eq(eye.x, FOCUS.x, TOLERANCE)
	assert_almost_eq(eye.z, FOCUS.z - RADIUS, TOLERANCE)


func test_advancing_turns_at_the_stated_rate() -> void:
	_orbit.advance(2.0)
	assert_almost_eq(_orbit.angle_degrees, SPEED * 2.0, TOLERANCE)


func test_advancing_lands_in_the_same_place_however_the_frames_fell() -> void:
	# Frame times are not a fixed thing, so a camera whose speed depended on how
	# the deltas happened to land would turn slower on a slower phone.
	var stepped: CameraOrbit = CameraOrbit.new(RADIUS, HEIGHT, SPEED)
	for _frame: int in range(60):
		stepped.advance(1.0 / 60.0)
	_orbit.advance(1.0)
	assert_almost_eq(stepped.angle_degrees, _orbit.angle_degrees, TOLERANCE)


func test_a_full_turn_comes_back_to_where_it_started() -> void:
	var before: Vector3 = _orbit.eye(FOCUS)
	_orbit.advance(FULL_TURN_SECONDS)
	assert_almost_eq(_orbit.eye(FOCUS).distance_to(before), 0.0, TOLERANCE)


func test_the_angle_wraps_instead_of_growing() -> void:
	# See [constant CameraOrbit.FULL_TURN]: an angle left to grow spends its
	# float precision, and the camera starts stuttering only after a long idle.
	for _turn: int in range(10):
		_orbit.advance(FULL_TURN_SECONDS)
	assert_between(_orbit.angle_degrees, 0.0, CameraOrbit.FULL_TURN)


func test_a_negative_speed_goes_the_other_way() -> void:
	var widdershins: CameraOrbit = CameraOrbit.new(RADIUS, HEIGHT, -SPEED)
	widdershins.advance(1.0)
	_orbit.advance(1.0)
	var mirrored: float = CameraOrbit.FULL_TURN - _orbit.angle_degrees
	assert_almost_eq(widdershins.angle_degrees, mirrored, TOLERANCE)


func test_a_still_camera_never_moves() -> void:
	# What the play screen is: the same orbit, parked. It holds the angle it was
	# handed rather than snapping back to zero.
	var parked: CameraOrbit = CameraOrbit.new(RADIUS, HEIGHT, 0.0)
	parked.angle_degrees = 35.0
	var before: Vector3 = parked.eye(FOCUS)
	parked.advance(10.0)
	assert_eq(parked.angle_degrees, 35.0, "no speed, no movement")
	assert_almost_eq(parked.eye(FOCUS).distance_to(before), 0.0, TOLERANCE)
