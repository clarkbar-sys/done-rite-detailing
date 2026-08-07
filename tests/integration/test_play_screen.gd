## Integration test for the play screen — the garage seen from inside it.
##
## What pressing Start actually changes is four settings on the [Garage] instance
## in this scene's file rather than code anywhere: the showcase orbit stops, the
## camera becomes a person standing in the bay, the anchor held things hang off
## switches on, and that person can walk. Settings in a scene file are exactly
## the kind of thing that is silently wrong until somebody looks, so each of them
## is checked twice — once as the property that was set, and once as the effect
## it had on the camera the player is actually looking through. The last of the
## four is [code]tests/integration/test_play_screen_walk.gd[/code]'s subject and
## this file covers the shot the walk starts from.
##
## The geometry assertions below are the other half of the clipping decision
## recorded in [code]src/world/garage.gd[/code]: the viewmodel is kept inside the
## near plane instead of being given a camera of its own, and that is only safe
## because the eye has room around it. These are what go red if it ever hasn't —
## here where the eye begins, and in the walk suite at every angle it reaches.
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

## The furthest the eye may be from the car's own bodywork and still count as
## having walked up to it. Measured to the box rather than to the middle of the
## car, because the middle of a 4.3 m long car is metres from the panel you are
## standing at and a radius says nothing about what fills the frame. Beyond this
## the shot stops being somebody working on a car and becomes somebody looking at
## one from across the room.
const REACHED_THE_CAR: float = 3.0

## How far a held thing may stick out from the anchor in any direction. Half the
## longest tool on the belt (the power wash wand, 0.72 m) plus room to spare, so
## the clearance below is a promise about the proxies #42 hangs here and not just
## about the empty node they hang from.
const HELD_REACH: float = 0.45

## Long enough for the standoff to have eased from where the standing shot puts
## the eye to the gap the walk wants, with room to spare. That is a metre and a
## quarter of dolly at the correction speed the scene exports — about fifty ticks
## — so this is a second and a half. The eye is placed before the first physics
## tick and settled shortly after, and the tests below say which of the two they
## mean.
const SETTLE_FRAMES: int = 90

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


func _car() -> Car:
	return _garage().get_node("%Car") as Car


func _view_model() -> Node3D:
	return _garage().get_node("%ViewModel") as Node3D


## The car's bounding box in world space — read off the car rather than written
## down again here, so it keeps meaning "the car" after somebody reshapes it.
##
## [Car.bounds] rather than an [AABB] off a mesh, because a car is a handful of
## separate panels and there is no one visual instance left to ask. An
## axis-aligned box is wider than the bodywork it is drawn round — every car in
## the pack tapers at the nose and the tail — which only makes every clearance
## below more conservative. It is deliberately not "the mirrors": the blockout's
## mirrors were the widest thing on it and no car in the pack has any, so the
## slack here is the shape of the car rather than a fitting on it.
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
## ground itself. The narrower of its two sides, since what hangs off this is an
## absolute value.
func _ground_half_width() -> float:
	var box: AABB = (_garage().get_node("%Ground") as Ground).extent()
	return minf(absf(box.position.x), box.end.x)


## How far the eye stands from the middle of the car, measured flat on the floor.
func _radius() -> float:
	var eye: Vector3 = _camera().global_position
	var car: Vector3 = _car().global_position
	return Vector2(eye.x - car.x, eye.z - car.z).length()


## Lets the standoff ease from where the standing shot puts the eye to the gap
## the walk wants, so what is measured afterwards is a settled camera rather than
## one still arriving.
func _settle() -> void:
	await wait_physics_frames(SETTLE_FRAMES)


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


func test_the_showcase_orbit_has_stopped() -> void:
	# The camera the player walks is not the one that circles the car on its own.
	# That the eye really does hold still until it is asked not to is the walk
	# suite's job, because "still" only means anything next to "moving".
	assert_false(_garage().orbiting, "the game is not a screensaver")


# ---- the shot: a person on the driveway, not the showcase rig stopped mid-circle


func test_the_shot_is_first_person() -> void:
	# The intent. Parking the orbit was what this screen used to do and it is not
	# the same thing: a frozen orbit is still the outside-in shot of a car, just
	# no longer moving.
	assert_true(_garage().first_person, "the game is played from inside the room")


func test_the_eye_stands_at_head_height() -> void:
	var height: float = _camera().global_position.y
	assert_between(height, EYE_MIN_HEIGHT, EYE_MAX_HEIGHT, "the camera must be somebody's eye")


func test_the_eye_starts_where_the_export_says() -> void:
	# The effect of the property, not the property. `_ready()` used to aim the
	# camera unconditionally, which would have put it straight back on the orbit
	# and left `eye_position` looking like it worked.
	#
	# A second, unstepped screen, and not the one `before_each` built. The standoff
	# eases the eye out to the gap the walk wants from the first physics tick
	# onward, and the tick that has already happened by the time a test body runs
	# has moved it 2.5 cm — measured, by asserting this on the shared screen and
	# reading the failure. `_ready()` fires inside `add_child`, so placing the eye
	# has happened here and nothing else has.
	var packed: PackedScene = load(PLAY_SCREEN) as PackedScene
	var fresh: GameScreen = packed.instantiate() as GameScreen
	add_child_autofree(fresh)
	var garage: Garage = fresh.get_node("Garage") as Garage
	var camera: Camera3D = garage.get_node("%Camera") as Camera3D
	var offset: float = camera.global_position.distance_to(garage.eye_position)
	assert_almost_eq(offset, 0.0, TOLERANCE, "the eye must start where it was told to")


func test_the_eye_has_walked_up_to_the_car() -> void:
	await _settle()
	var gap: float = _clearance(_car_box(), _camera().global_position)
	assert_lt(gap, REACHED_THE_CAR, "the car has to fill the frame, not sit in it")
	assert_lt(_radius(), _garage().orbit_radius, "and it must be nearer than the showcase shot was")


func test_the_eye_is_not_standing_in_the_bodywork() -> void:
	# The failure mode of moving a camera closer without looking: the near plane
	# is 5 cm, so an eye inside the car renders the inside of the car's box and
	# the room disappears.
	await _settle()
	assert_false(_car_box().has_point(_camera().global_position), "stand beside the car, not in it")


func test_the_eye_stays_inside_the_room() -> void:
	await _settle()
	var eye: Vector3 = _camera().global_position
	assert_lt(absf(eye.x), _ground_half_width(), "the eye must be over the modeled ground")
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
	# The second half, where the eye starts. Nothing in the room may come nearer
	# to the lens than the things hanging off it, and the car is the only
	# candidate — the walls are metres away. That it stays true for a whole walk
	# is the walk suite's version of this assertion.
	await _settle()
	var clearance: float = _clearance(_car_box(), _view_model().global_position)
	assert_gt(clearance, HELD_REACH, "a held tool must not be able to reach into the car")


func test_it_asks_for_nothing_and_offers_no_way_out() -> void:
	# Deliberate, and documented in src/screens/play_screen.gd: a Back button is
	# a decision about pausing that there is nothing yet to pause.
	await wait_process_frames(10)
	assert_eq(_requested.size(), 0, "the play screen is the end of the road for now")
