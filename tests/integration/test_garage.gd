## Integration test for the garage — the driveway, and the camera that circles
## it.
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


func _car() -> MeshInstance3D:
	return _garage.get_node("%Car") as MeshInstance3D


func _car_body() -> StaticBody3D:
	return _garage.get_node("%CarBody") as StaticBody3D


## How far the car is from the outer edge of the modeled ground, read off the
## grass itself rather than written down again here.
func _ground_half_width() -> float:
	var grass: Node3D = _garage.get_node("View/World/Ground/GrassRight") as Node3D
	return grass.position.x + grass.scale.x * 0.5


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


func test_the_camera_never_orbits_off_the_edge_of_the_ground() -> void:
	# The camera circles the middle of the driveway at a fixed radius, so the
	# only thing keeping it over the modeled ground is that radius being the
	# smaller number. Nothing on screen would say it had stopped being true —
	# the view would just start showing empty space at two points in every turn.
	assert_lt(
		_garage.orbit_radius, _ground_half_width(), "the camera circle must fit on the ground"
	)


func test_the_room_orbits_unless_a_screen_says_otherwise() -> void:
	# The defaults are the title screen's shot, and the title screen overrides
	# nothing but the starting angle. If either of these flipped, the title card
	# would come up on a motionless view from somebody's eye socket.
	assert_true(_garage.orbiting, "the room's own shot is the slow circuit")
	assert_false(
		_garage.first_person, "standing on the driveway is the game's idea, not the room's"
	)
	assert_false(_garage.walkaround, "and so is walking about in it")


func test_steering_a_room_nobody_is_standing_in_is_ignored() -> void:
	# The title screen instances this same scene, and its camera is not anybody's
	# to drive. Asking anyway has to be a no-op rather than a crash on a drive
	# that was never built — the play screen calls `steer` every single frame, and
	# a screen that stopped being first person must not take the game down.
	#
	# Measured against the showcase circuit's own speed rather than against "it
	# did not move": the circuit is still turning underneath, and a steered camera
	# that moved by exactly the circuit's chord moved by nothing else.
	_garage.steer(1.0, 1.0)
	var before: Vector3 = _camera().global_position
	_garage._process(1.0)
	var half_sweep: float = deg_to_rad(_garage.orbit_degrees_per_second) * 0.5
	var chord: float = 2.0 * _garage.orbit_radius * sin(half_sweep)
	assert_almost_eq(_camera().global_position.distance_to(before), chord, TOLERANCE)


# ---- the car's collider: what the walkaround camera measures against ---------


func test_the_car_has_a_body_a_ray_can_find() -> void:
	# The green box is a MeshInstance3D and a mesh is invisible to a raycast, so
	# without this the standoff would measure nothing, find no hit, and hold
	# whatever radius it started with — a bug that looks exactly like the feature
	# not being wired up.
	var body: StaticBody3D = _car_body()
	assert_not_null(body, "the car needs something a ray can hit")
	if body == null:
		return
	var shape: CollisionShape3D = body.get_node("Shape") as CollisionShape3D
	assert_not_null(shape, "the body needs a shape")
	assert_not_null(shape.shape as BoxShape3D, "and the shape should be the box the car is")


func test_the_collider_is_the_same_size_and_place_as_the_car() -> void:
	# The cost of keeping the collider out of the mesh's scale (see the class
	# docs): the car's size is written down twice. This is what stops the second
	# copy from quietly going stale the first time somebody resizes the first.
	var car: MeshInstance3D = _car()
	var painted: AABB = car.global_transform * car.get_aabb()
	var box: BoxShape3D = (_car_body().get_node("Shape") as CollisionShape3D).shape as BoxShape3D
	var solid: AABB = AABB(_car_body().global_position - box.size * 0.5, box.size)
	assert_almost_eq(solid.size.distance_to(painted.size), 0.0, TOLERANCE, "same size as the car")
	assert_almost_eq(
		solid.get_center().distance_to(painted.get_center()),
		0.0,
		TOLERANCE,
		"and in the same place"
	)


func test_the_collider_is_not_scaled() -> void:
	# Why it is a sibling of the mesh rather than a child: everything in this room
	# is a unit box scaled into place, a CollisionShape3D inherits that scale, and
	# a non-uniformly scaled shape is the one thing the physics server asks not to
	# be handed.
	var scaling: Vector3 = _car_body().global_transform.basis.get_scale()
	assert_almost_eq(scaling.distance_to(Vector3.ONE), 0.0, TOLERANCE, "shapes are not scaled")


func test_the_view_model_anchor_is_hidden_while_the_camera_circles() -> void:
	# Both screens instance this one scene, so the anchor is here on the title
	# screen too — and a tool hanging in the corner of an outside-in shot of a car
	# reads as a rendering fault, not as something being held. It exists and it is
	# switched off, and `is_visible_in_tree` rather than `visible` because what
	# matters is that nothing under it is drawn.
	var anchor: Node3D = _garage.get_node("%ViewModel") as Node3D
	assert_not_null(anchor, "the anchor is part of the room's scene, not the play screen's")
	assert_false(anchor.is_visible_in_tree(), "nobody is standing here to hold anything")
