## Integration test for the play screen — the garage seen from inside it.
##
## What pressing Start actually changes is three settings on the [Garage]
## instance in this scene's file rather than code anywhere: the orbit stops, the
## camera becomes a person standing in the bay, and the anchor held things hang
## off switches on. Settings in a scene file are exactly the kind of thing that
## is silently wrong until somebody looks, so each of them is checked twice here
## — once as the property that was set, and once as the effect it had on the
## camera the player is actually looking through.
##
## The geometry assertions below are the other half of the clipping decision
## recorded in [code]src/world/garage.gd[/code]: the viewmodel is kept inside the
## near plane instead of being given a camera of its own, and that is only safe
## because the eye is parked somewhere with room around it. These are what go red
## if it ever isn't.
extends GutTest

const PLAY_SCREEN: String = "res://src/screens/play_screen.tscn"

## Close enough for positions in metres — a tenth of a millimetre.
const TOLERANCE: float = 0.0001

## The tallest a standing eye can plausibly be, and the shortest. Not a tuning
## knob: a bracket wide enough to hold anybody, so it only fails when the camera
## has stopped being a person at all — back up on the orbit's 2.6 m perch, or
## down on the floor.
const EYE_MIN_HEIGHT: float = 1.4
const EYE_MAX_HEIGHT: float = 2.0

## The furthest the eye may stand from the middle of the car and still count as
## having walked up to it. The car is 4.3 m long and 1.9 m wide, so from much
## beyond this it stops filling the frame and starts sitting in it.
const REACHED_THE_CAR: float = 3.5

## How far a held thing may stick out from the anchor in any direction. Half the
## longest tool on the belt (the power wash wand, 0.72 m) plus room to spare, so
## the clearance below is a promise about the proxies #42 hangs here and not just
## about the empty node they hang from.
const HELD_REACH: float = 0.45

var _screen: GameScreen = null
var _requested: Array[GameState] = []


func before_each() -> void:
	_requested = []
	var packed: PackedScene = load(PLAY_SCREEN) as PackedScene
	assert_not_null(packed, "could not load %s" % PLAY_SCREEN)
	if packed == null:
		return
	var screen: GameScreen = packed.instantiate() as GameScreen
	_screen = screen
	add_child_autofree(_screen)
	_screen.transition_requested.connect(_record)
	await wait_process_frames(1)


func _record(state: GameState) -> void:
	_requested.append(state)


func _garage() -> Garage:
	return _screen.get_node("Garage") as Garage


## The camera, the car and the anchor are all reached off the garage rather than
## off the screen: a `%Name` is unique within the scene that *owns* it, so they
## are visible from the room they belong to and not from the screen the room was
## instanced into.
func _camera() -> Camera3D:
	return _garage().get_node("%Camera") as Camera3D


func _car() -> MeshInstance3D:
	return _garage().get_node("%Car") as MeshInstance3D


func _view_model() -> Node3D:
	return _garage().get_node("%ViewModel") as Node3D


## The car's bounding box in world space — read off the mesh rather than written
## down again here, so it keeps meaning "the car" after somebody resizes it.
func _car_box() -> AABB:
	var car: MeshInstance3D = _car()
	return car.global_transform * car.get_aabb()


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


## How far the middle of the room is from the inside face of a side wall, read
## off the wall itself. The walls are unit boxes scaled into place, so half the
## scale is half the thickness.
func _inner_half_width() -> float:
	var wall: Node3D = _garage().get_node("View/World/Room/WallLeft") as Node3D
	return absf(wall.position.x) - wall.scale.x * 0.5


func test_the_screen_is_a_game_screen() -> void:
	# The host casts to [GameScreen] and refuses anything else, so a scene that
	# lost its script would leave the player looking at an empty window.
	assert_not_null(_screen, "the play screen must instantiate as a GameScreen")


func test_it_shows_the_same_garage_the_menu_was_showing() -> void:
	var garage: Garage = _garage()
	assert_not_null(garage, "the game happens in the room")
	assert_eq(garage.scene_file_path, "res://src/world/garage.tscn", "the same scene, not a copy")


func test_it_has_no_menu_over_it() -> void:
	# The menu's button is `%Start`; finding one here would mean the menu came
	# along with the room.
	assert_false(_screen.has_node("%Start"), "pressing Start Game must take the menu away")


func test_the_camera_has_stopped() -> void:
	assert_false(_garage().orbiting, "the game is not a screensaver")


func test_the_camera_really_does_not_move() -> void:
	# The property above is the intent; this is the effect.
	var camera: Camera3D = _camera()
	var before: Vector3 = camera.global_position
	await wait_process_frames(30)
	assert_almost_eq(camera.global_position.distance_to(before), 0.0, TOLERANCE)


# ---- the shot: a person in the bay, not the showcase rig stopped mid-circle ---


func test_the_shot_is_first_person() -> void:
	# The intent. Parking the orbit was what this screen used to do and it is not
	# the same thing: a frozen orbit is still the outside-in shot of a car, just
	# no longer moving.
	assert_true(_garage().first_person, "the game is played from inside the room")


func test_the_eye_stands_at_head_height() -> void:
	var height: float = _camera().global_position.y
	assert_between(height, EYE_MIN_HEIGHT, EYE_MAX_HEIGHT, "the camera must be somebody's eye")


func test_the_eye_stands_where_the_export_says() -> void:
	# The effect of the property, not the property. `_ready()` used to aim the
	# camera unconditionally, which would have put it straight back on the orbit
	# and left `eye_position` looking like it worked.
	var offset: float = _camera().global_position.distance_to(_garage().eye_position)
	assert_almost_eq(offset, 0.0, TOLERANCE, "the eye must stand where it was told to")


func test_the_eye_has_walked_up_to_the_car() -> void:
	# Measured flat on the floor, so the height above the car doesn't flatter it.
	var eye: Vector3 = _camera().global_position
	var car: Vector3 = _car().global_position
	var flat: float = Vector2(eye.x - car.x, eye.z - car.z).length()
	assert_lt(flat, REACHED_THE_CAR, "the car has to fill the frame, not sit in it")
	assert_lt(flat, _garage().orbit_radius, "and it must be nearer than the showcase shot was")


func test_the_eye_is_not_standing_in_the_bodywork() -> void:
	# The failure mode of moving a camera closer without looking: the near plane
	# is 5 cm, so an eye inside the car renders the inside of the car's box and
	# the room disappears.
	assert_false(_car_box().has_point(_camera().global_position), "stand beside the car, not in it")


func test_the_eye_stays_inside_the_room() -> void:
	var eye: Vector3 = _camera().global_position
	var ceiling: Node3D = _garage().get_node("View/World/Room/Ceiling") as Node3D
	var underside: float = ceiling.position.y - ceiling.scale.y * 0.5
	assert_lt(absf(eye.x), _inner_half_width(), "the eye must be inside the side walls")
	assert_lt(eye.y, underside, "the eye must be under the roof")
	assert_gt(eye.y, 0.0, "and above the floor")


func test_the_eye_looks_at_the_car() -> void:
	var to_car: Vector3 = (_car().global_position - _camera().global_position).normalized()
	var looking: Vector3 = -_camera().global_transform.basis.z
	assert_almost_eq(looking.dot(to_car), 1.0, TOLERANCE, "the camera must look at the car")


# ---- the anchor held things hang off ----------------------------------------


func test_the_camera_carries_a_view_model_anchor() -> void:
	var anchor: Node3D = _view_model()
	assert_not_null(anchor, "held things need somewhere to render")
	assert_eq(anchor.get_parent(), _camera(), "the anchor rides the eye rather than the room")


func test_the_anchor_is_showing_here() -> void:
	# Hidden in the scene file and switched on by `first_person`, because the
	# title screen instances this same room.
	assert_true(_view_model().is_visible_in_tree(), "the play screen is where hands exist")


func test_the_anchor_is_empty_until_something_is_held() -> void:
	# #41 lands the anchor and nothing in it; #42 fills it. Asserted rather than
	# assumed so "the viewmodel is invisible" can only ever have one cause.
	assert_eq(_view_model().get_child_count(), 0, "the anchor holds nothing yet")


func test_the_anchor_hangs_in_front_of_the_lens_and_to_one_side() -> void:
	# In the camera's own space, so this survives the eye being moved: -Z is
	# forward, +X is the right of the frame, -Y is the bottom of it.
	var held: Vector3 = _view_model().position
	assert_lt(held.z, 0.0, "a held thing is in front of you, not behind you")
	assert_gt(held.x, 0.0, "and off to one side rather than dead centre")
	assert_lt(held.y, 0.0, "and low in the frame, where a hand is")


func test_the_anchor_clears_the_near_plane() -> void:
	# The first half of the clipping decision: the viewmodel has no camera of its
	# own, so it lives or dies by this camera's near plane. Sitting inside it
	# would clip the tool away rather than the world.
	var camera: Camera3D = _camera()
	var reach: float = _view_model().position.length()
	assert_gt(reach, camera.near, "a held thing inside the near plane is not drawn at all")


func test_the_anchor_clears_the_car() -> void:
	# The second half. Nothing in the room may come nearer to the lens than the
	# things hanging off it, and the car is the only candidate — the walls are
	# metres away. Measured at 0.79 m; the floor below is the budget a held proxy
	# gets to spend reaching away from the anchor, and the longest tool on the
	# belt is 0.72 m end to end.
	var clearance: float = _clearance(_car_box(), _view_model().global_position)
	assert_gt(clearance, HELD_REACH, "a held tool must not be able to reach into the car")


func test_it_asks_for_nothing_and_offers_no_way_out() -> void:
	# Deliberate, and documented in src/screens/play_screen.gd: a Back button is
	# a decision about pausing that there is nothing yet to pause.
	await wait_process_frames(10)
	assert_eq(_requested.size(), 0, "the play screen is the end of the road for now")
