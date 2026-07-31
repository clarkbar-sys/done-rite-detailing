## Integration test for the play screen — the garage with the menu gone.
##
## Short on purpose: there is nothing to do in here yet, and the tests say so.
## What it does have to get right is the pair of things pressing Start Game is
## supposed to change — no menu over the room, and a camera that has stopped —
## and both of those are settings on the garage instance in this scene's file
## rather than code anywhere, which is exactly the kind of thing that is silently
## wrong until somebody looks.
extends GutTest

const PLAY_SCREEN: String = "res://src/screens/play_screen.tscn"

## Close enough for positions in metres — a tenth of a millimetre.
const TOLERANCE: float = 0.0001

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
	# The property above is the intent; this is the effect. Both, because the
	# whole visible difference between this screen and the menu rides on it.
	# Off the garage and not off the screen: a `%Name` is unique within the scene
	# that *owns* it, so the camera is reachable from the room it belongs to and
	# not from the screen the room was instanced into.
	var camera: Camera3D = _garage().get_node("%Camera") as Camera3D
	var before: Vector3 = camera.global_position
	await wait_process_frames(30)
	assert_almost_eq(camera.global_position.distance_to(before), 0.0, TOLERANCE)


func test_the_camera_is_not_where_the_menu_left_it() -> void:
	# A cut rather than a freeze-frame. The menu hands over at whatever angle it
	# had drifted to, so the game picks its own shot instead — otherwise the
	# transition reads as the camera having got stuck.
	assert_ne(_garage().start_angle_degrees, 0.0, "the game chooses its own angle on the car")


func test_it_asks_for_nothing_and_offers_no_way_out() -> void:
	# Deliberate, and documented in src/screens/play_screen.gd: a Back button is
	# a decision about pausing that there is nothing yet to pause.
	await wait_process_frames(10)
	assert_eq(_requested.size(), 0, "the play screen is the end of the road for now")
