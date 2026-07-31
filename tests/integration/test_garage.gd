## Integration test for the garage — the room, and the camera that circles it.
##
## Under tests/integration/ because everything here needs the scene to exist and
## a frame to happen: the camera is aimed in `_ready()` and moved in `_process`,
## and the point of most of these is that the engine really is driving it. The
## arithmetic underneath is [code]tests/unit/test_camera_orbit.gd[/code]'s job
## and is not repeated here.
extends GutTest

const GARAGE: String = "res://src/world/garage.tscn"

## Close enough for positions in metres — a tenth of a millimetre.
const TOLERANCE: float = 0.0001

var _garage: Garage = null


func before_each() -> void:
	var packed: PackedScene = load(GARAGE) as PackedScene
	assert_not_null(packed, "could not load %s" % GARAGE)
	if packed == null:
		return
	# Into a typed local first: GUT's add_child_autofree is untyped, and autofree
	# is what stops a failure here being reported as a leak against the next test.
	var garage: Garage = packed.instantiate() as Garage
	_garage = garage
	add_child_autofree(_garage)
	await wait_process_frames(1)


func _camera() -> Camera3D:
	return _garage.get_node("%Camera") as Camera3D


func _car() -> Node3D:
	return _garage.get_node("%Car") as Node3D


## How far the middle of the room is from the inside face of a side wall, read
## off the wall itself rather than written down again here. The walls are unit
## boxes scaled into place, so half the scale is half the thickness.
func _inner_half_width() -> float:
	var wall: Node3D = _garage.get_node("View/World/Room/WallLeft") as Node3D
	return absf(wall.position.x) - wall.scale.x * 0.5


func test_the_room_instantiates() -> void:
	assert_not_null(_garage, "the garage must instantiate as a Garage")


func test_it_has_a_car_and_a_camera_to_look_at_it_with() -> void:
	assert_not_null(_car(), "the garage needs a car in it")
	assert_not_null(_camera(), "the garage needs a camera")
	assert_true(_camera().current, "the camera must be the one its viewport uses")


func test_the_camera_is_aimed_before_the_first_frame() -> void:
	# `_ready()` aims it, so whatever transform the scene file happens to have
	# saved never reaches the screen. Without this, a screen that never orbits
	# would show the camera's parked-at-the-origin view instead of the car.
	var to_car: Vector3 = (_car().global_position - _camera().global_position).normalized()
	var looking: Vector3 = -_camera().global_transform.basis.z
	assert_almost_eq(looking.dot(to_car), 1.0, TOLERANCE, "the camera must look at the car")


func test_the_camera_stands_the_orbit_distance_from_the_car() -> void:
	var eye: Vector3 = _camera().global_position
	var car: Vector3 = _car().global_position
	var flat: Vector2 = Vector2(eye.x - car.x, eye.z - car.z)
	assert_almost_eq(flat.length(), _garage.orbit_radius, TOLERANCE)
	assert_almost_eq(eye.y - car.y, _garage.orbit_height, TOLERANCE)


func test_the_camera_moves_on_its_own() -> void:
	# The one that proves the engine is driving this. Everything below calls
	# `_process` by hand for a number it can predict; if the node were not
	# processing at all, only this test would notice.
	var before: Vector3 = _camera().global_position
	await wait_process_frames(30)
	assert_gt(_camera().global_position.distance_to(before), 0.0, "the menu camera must turn")


func test_a_second_of_orbit_moves_it_the_width_of_a_second() -> void:
	# Called directly so the distance is a number rather than however many
	# frames the machine felt like giving us. The chord of the arc it sweeps:
	# two radii and the sine of half the angle.
	var before: Vector3 = _camera().global_position
	_garage._process(1.0)
	var half_sweep: float = deg_to_rad(_garage.orbit_degrees_per_second) * 0.5
	var chord: float = 2.0 * _garage.orbit_radius * sin(half_sweep)
	assert_almost_eq(_camera().global_position.distance_to(before), chord, TOLERANCE)


func test_it_keeps_looking_at_the_car_as_it_goes() -> void:
	# The aim is recomputed every frame, so a camera that circles but forgets to
	# turn — the classic version of this bug — fails here rather than in a build.
	_garage._process(7.5)
	var to_car: Vector3 = (_car().global_position - _camera().global_position).normalized()
	var looking: Vector3 = -_camera().global_transform.basis.z
	assert_almost_eq(looking.dot(to_car), 1.0, TOLERANCE)


func test_a_parked_camera_holds_still() -> void:
	# What the play screen turns off. Through the exported property rather than
	# by reaching into the orbit, because the property is the whole interface
	# the screens have to this scene.
	_garage.orbiting = false
	var before: Vector3 = _camera().global_position
	_garage._process(5.0)
	await wait_process_frames(10)
	assert_almost_eq(_camera().global_position.distance_to(before), 0.0, TOLERANCE)


func test_the_camera_never_orbits_into_a_wall() -> void:
	# The camera circles the middle of the room at a fixed radius, so the only
	# thing keeping it out of the side walls is that radius being the smaller
	# number. Nothing on screen would say it had stopped being true — the view
	# would just start clipping through a wall at two points in every turn.
	assert_lt(_garage.orbit_radius, _inner_half_width(), "the camera circle must fit in the room")


func test_the_camera_never_orbits_up_through_the_roof() -> void:
	# The other half of the same fence, and the easier one to trip: the height
	# is measured from the middle of the car rather than from the floor, so it
	# is always further off the ground than the number says.
	var ceiling: Node3D = _garage.get_node("View/World/Room/Ceiling") as Node3D
	var underside: float = ceiling.position.y - ceiling.scale.y * 0.5
	assert_lt(_camera().global_position.y, underside, "the camera must stay under the roof")
