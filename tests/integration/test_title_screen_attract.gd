## Integration test for the title screen's attract mode: the room playing itself
## while nobody is holding anything.
##
## Under tests/integration/ because every claim here needs the whole stack running
## — a car whose CSG has built, masks laid on it a frame later, a physics tick to
## cast the demo's ray on, and an eye a [Standoff] is easing around real bodywork.
## What the demo [i]decides[/i] needs none of that and is not repeated here:
## [code]tests/unit/test_attract_routine.gd[/code] has the running order and
## [code]tests/unit/test_attract_walk.gd[/code] has the push.
##
## [b]The pass length is shortened, and nothing else is.[/b]
## [member Garage.attract_seconds_per_pass] ships at four seconds, so watching one
## panel through all three passes would cost this suite twelve seconds of real
## frames per test. It is set to a second here, before the room has had the frame
## it builds the demo in — every other number, including the two easing bands and
## every tool rate, is the one that ships.
extends GutTest

const TITLE_SCREEN: String = "res://src/screens/title_screen.tscn"

## The room on its own, for the two tests that need one nobody else is steering.
const GARAGE: String = "res://src/world/garage.tscn"

## Close enough for positions in metres.
const TOLERANCE: float = 0.0001

## What a pass is shortened to, and the physics frames that go with it at the
## engine's default 60 Hz. The two have to agree — a suite that waited fewer
## frames than a pass takes would assert on a pass that has not happened.
const QUICK_PASS: float = 1.0
const PASS_FRAMES: int = 60

## Enough ticks for the room to have resolved the demo's first press into a mark
## and spent something on it.
##
## Counted from [signal Garage.grimed] and not from [method GutTest.before_each],
## because physics frames are the wrong clock for the wait that comes first — see
## [method before_each].
const RESOLVE_FRAMES: int = 4

## How long [method before_each] will wait for the room to lay its masks before
## giving up and letting the assertions report what they find. Generous: the wait
## is one process frame in a room that has just built a car, and a second is
## twenty times the worst build measured on the slowest machine this runs on.
const GRIME_TIMEOUT: float = 1.0

## Long enough for a quarter turn of the car to have finished rather than nearly
## finished. At [member Garage.turn_degrees_per_second] the first 50° of it are
## flat out; the last [member Garage.attract_turn_ease_degrees] are an easing
## curve, and an easing curve costs several times what the sprint did.
const ARRIVAL_FRAMES: int = 360

var _screen: GameScreen = null
var _window_size_before: Vector2i = Vector2i.ZERO


func before_each() -> void:
	# A headless window is 64x64, and the demo aims by projecting the work onto the
	# glass and checking it is on it — so at that size nothing is ever in frame and
	# the trigger never comes down. `content_scale_size` is the design resolution
	# from project.godot. Put back in after_each: every suite shares this window.
	var root: Window = get_tree().root
	_window_size_before = root.size
	root.size = root.content_scale_size
	var packed: PackedScene = load(TITLE_SCREEN) as PackedScene
	assert_not_null(packed, "could not load %s" % TITLE_SCREEN)
	if packed == null:
		return
	var screen: GameScreen = packed.instantiate() as GameScreen
	_screen = screen
	add_child_autofree(_screen)
	# Before the first `await`, which is the frame the room builds its demo in. See
	# the class docs on why this one number is not the shipped one.
	_garage().attract_seconds_per_pass = QUICK_PASS
	# WAIT FOR THE SIGNAL, NOT FOR A COUNT OF PHYSICS FRAMES. Everything below
	# needs the masks to be on the car and the demo's running order to have been
	# taken up, and both of those happen in `Garage._lay_on_the_grime` one *process*
	# frame after `_ready`. Physics frames do not measure that: when a frame runs
	# long — and the frame this room is built in is the longest one it will ever
	# have, a car's worth of CSG and a grove — the engine catches up by running
	# several physics ticks inside a single iteration of the main loop, so all four
	# of RESOLVE_FRAMES can pass before `process_frame` has been emitted once.
	#
	# Found the honest way: adding trim to `car.tscn` put about 3 ms on that build
	# and two tests here started failing with `is_laid()` false, while the same
	# suite passed on its own. `test_play_screen_wash.gd` makes the same wait and
	# has never flaked, because it counts process frames. This counts neither and
	# waits for the room to say so.
	await wait_for_signal(_garage().grimed, GRIME_TIMEOUT)
	await wait_physics_frames(RESOLVE_FRAMES)


func after_each() -> void:
	get_tree().root.size = _window_size_before


func _garage() -> Garage:
	return _screen.get_node("Garage") as Garage


func _camera() -> Camera3D:
	return _garage().get_node("%Camera") as Camera3D


func _car() -> Car:
	return _garage().get_node("%Car") as Car


func _grime() -> Grime:
	return _garage().grime()


func _belt() -> ToolBelt:
	return _garage().view_model().belt()


## Where the eye is standing, as an angle around the car — the number the demo's
## walk is actually steering, read off the camera rather than out of the orbit so
## a test cannot pass on arithmetic that never reached a transform.
func _eye_angle() -> float:
	var offset: Vector3 = _camera().global_position - _car().global_position
	return rad_to_deg(atan2(offset.x, offset.z))


func _run(passes: float) -> void:
	await wait_physics_frames(int(PASS_FRAMES * passes))


# ---- the shot: the title screen is now somebody standing in the bay ------------


func test_the_title_screen_stands_in_the_room_rather_than_circling_it() -> void:
	# The showcase circuit could not show a tool working, because there is nobody in
	# that shot to hold one. All three are exports on one [Garage] instance, which is
	# the pattern the play screen already follows.
	assert_true(_garage().first_person, "there has to be somebody in the room to hold a wand")
	assert_true(_garage().walkaround, "and the demo walks them round the car")
	assert_true(_garage().attracting, "and the room plays itself while nobody is playing")


func test_the_tool_in_the_demo_s_hands_is_drawn() -> void:
	# The anchor ships hidden and the room switches it on in first person. On the
	# old title screen it was correctly invisible — a tool hanging in the corner of
	# an outside-in shot reads as a rendering fault — and the whole point of the
	# attract mode is that there is now a hand for it to be in.
	var anchor: Node3D = _garage().get_node("%ViewModel") as Node3D
	assert_true(anchor.is_visible_in_tree(), "the demo is holding something invisible")


# ---- the car: mud goes on it, and comes off without anybody pressing anything --


func test_the_car_the_demo_starts_on_is_filthy() -> void:
	# New to this screen. The title screen used to show a clean car nobody was
	# touching, which is exactly the "nothing is happening" the attract mode
	# replaces — and it had no masks at all, because the room only laid them on in
	# first person.
	#
	# All but a few ticks of it, rather than exactly all: the demo picks up the wand
	# and starts spending water on the same frame the masks go on, so by the time a
	# test can look at the car it is already fractionally cleaner than it was made.
	# That is the screen working, and it is what the test below measures properly.
	assert_not_null(_grime(), "the title screen's room built no grime")
	assert_true(_grime().is_laid(), "and never laid it on the car")
	assert_gt(_grime().remaining(), 0.99, "a demo starts on a dirty car")


func test_the_demo_starts_with_the_water_in_its_hands() -> void:
	assert_eq(_belt().equipped().id, DetailingTool.Id.POWER_WASH, "mud comes off first")


func test_the_water_reaches_the_car_with_nobody_touching_anything() -> void:
	# The whole feature end to end, and the one assertion that cannot be satisfied
	# by a cutscene: the demo pressed the glass, the room cast a ray, found a panel,
	# projected onto its mask and spent [member Garage.wash_per_second] on it. The
	# car starts at exactly 1.0, so any water at all makes this strictly less.
	await _run(1.0)
	assert_lt(_grime().remaining(), 1.0, "a pass of the power wash left the car as dirty as it was")


func test_it_works_a_panel_through_all_three_passes() -> void:
	# The ask, in one test: dirty, washed, product on it, buffed out. Each number is
	# the one the pass before it makes possible — there is no bare paint to soap
	# until the water has been over it, and no product to buff until the bottle has.
	# [GrimeMap]'s buckets are what enforce that, so a demo that ran the passes in
	# any other order would leave both of the last two at zero.
	await _run(1.0)
	var washed: float = _grime().remaining()
	assert_lt(washed, 1.0, "the water did nothing")
	await _run(1.0)
	assert_gt(_grime().product(), 0.0, "the cleaner laid nothing on the paint the water bared")
	await _run(1.0)
	assert_gt(_grime().shine(), 0.0, "the rag buffed none of that product out")


# ---- the belt: something changes hands often enough to be worth watching -------


func test_it_puts_the_water_down_and_picks_a_cleaner_up() -> void:
	await _run(1.0)
	assert_ne(
		_belt().equipped().id, DetailingTool.Id.POWER_WASH, "the demo never let go of the wand"
	)
	assert_ne(_belt().equipped().id, DetailingTool.Id.DRYING_RAG, "and skipped straight to the rag")


func test_it_finishes_the_panel_with_the_rag() -> void:
	await _run(2.0)
	assert_eq(_belt().equipped().id, DetailingTool.Id.DRYING_RAG, "the shine is the last pass")


func test_it_goes_back_to_the_water_on_the_next_panel() -> void:
	await _run(3.0)
	assert_eq(_belt().equipped().id, DetailingTool.Id.POWER_WASH, "every panel starts under mud")


# ---- the camera: it follows the work rather than circling on a timer -----------


func test_the_eye_moves_on_its_own() -> void:
	# The one that proves the engine is driving this. Everything else about the
	# camera is asserted against a number; if the demo were not running at all, only
	# this would notice.
	var before: Vector3 = _camera().global_position
	await _run(1.0)
	assert_gt(_camera().global_position.distance_to(before), 0.0, "the demo's eye never moved")


func test_it_keeps_looking_at_the_car_while_it_goes() -> void:
	# The walk is a rail around the car and cannot look away from it, demo or no
	# demo — so a script pushing that rail must not be able to produce a shot the
	# player could not.
	await _run(1.0)
	var to_car: Vector3 = (_car().global_position - _camera().global_position).normalized()
	var looking: Vector3 = -_camera().global_transform.basis.z
	assert_almost_eq(looking.dot(to_car), 1.0, 0.001, "the demo walked the camera off the car")


## A first-person room with a walk in it and no demo driving it, so the two tests
## below can push the lead themselves and watch where the eye ends up.
##
## [b]A second room rather than the title screen's own[/b], because the title
## screen's is already being steered every tick by the demo it is running: a test
## that pushed the lead at one panel while the routine pushed it at another would
## be measuring which of the two called [method Garage.steer] last. The exports are
## set before the room is added to the tree, which is where [method Node._ready]
## reads them.
func _a_room_to_lead_by_hand() -> Garage:
	var packed: PackedScene = load(GARAGE) as PackedScene
	var room: Garage = packed.instantiate() as Garage
	room.first_person = true
	room.walkaround = true
	add_child_autofree(room)
	return room


## Where [param eye] is standing around [param focus], as an angle in degrees on
## the orbit's own convention — from [code]+Z[/code] toward [code]+X[/code].
func _angle_around(eye: Vector3, focus: Vector3) -> float:
	var offset: Vector3 = eye - focus
	return rad_to_deg(atan2(offset.x, offset.z))


## Leads [param room]'s eye at [param target] for [param frames] physics ticks,
## the way [method Garage._run_the_demo] does once a tick, and hands back how far
## round the car it ended up.
func _lead_for(room: Garage, target: Vector3, frames: int) -> float:
	var eye: Camera3D = room.get_node("%Camera") as Camera3D
	var focus: Vector3 = (room.get_node("%Car") as Node3D).global_position
	for _tick: int in range(frames):
		room._lead_the_eye(target)
		await wait_physics_frames(1)
	return _angle_around(eye.global_position, focus)


func test_it_walks_round_to_a_panel_that_is_off_to_one_side() -> void:
	# The half of "the camera follows the tools" that a wheel is the honest test of.
	# Led at a panel a quarter of the way round the car, the eye has to actually
	# arrive rather than approach — through [method Garage.steer] and the same
	# [OrbitDrive] a thumb pushes, which is why it is measured off the camera's own
	# transform and not out of the orbit.
	var room: Garage = _a_room_to_lead_by_hand()
	await wait_physics_frames(RESOLVE_FRAMES)
	var focus: Vector3 = (room.get_node("%Car") as Node3D).global_position
	var eye: Camera3D = room.get_node("%Camera") as Camera3D
	var wanted: float = _angle_around(eye.global_position, focus) + 90.0
	var radians: float = deg_to_rad(wanted)
	var beside: Vector3 = focus + Vector3(sin(radians) * 2.0, 0.0, cos(radians) * 2.0)
	var landed: float = await _lead_for(room, beside, ARRIVAL_FRAMES)
	assert_almost_eq(
		absf(wrapf(landed - wanted, -180.0, 180.0)), 0.0, 2.0, "the eye stopped short of the panel"
	)


func test_a_panel_with_no_side_to_it_does_not_send_the_eye_anywhere() -> void:
	# The roof, the cabin and the tub are all centred on the car, and the angle of a
	# point at the middle of a circle flips from one side to the other over a
	# centimetre. [constant Garage.NO_SIDE_TO_IT] is what stops the eye lurching off
	# to the nose the moment the demo reaches one — measured against the eye's angle
	# alone, because the standoff and the lift are both still allowed to move it.
	var room: Garage = _a_room_to_lead_by_hand()
	await wait_physics_frames(RESOLVE_FRAMES)
	var focus: Vector3 = (room.get_node("%Car") as Node3D).global_position
	var eye: Camera3D = room.get_node("%Camera") as Camera3D
	var before: float = _angle_around(eye.global_position, focus)
	var landed: float = await _lead_for(room, focus, PASS_FRAMES)
	assert_almost_eq(
		absf(wrapf(landed - before, -180.0, 180.0)), 0.0, 1.0, "a centred panel moved the eye"
	)


# ---- the lap: what happens when the car is clean -------------------------------


func test_a_finished_lap_puts_the_mud_back() -> void:
	# The one thing the demo does that a player cannot, and the reason the title
	# screen never settles on a clean car nobody is touching. Driven through the
	# routine's own signal rather than by waiting out a lap, which at the shipped
	# pass length is a little over two minutes.
	await _run(1.0)
	assert_lt(_grime().remaining(), 1.0, "there is no wash to undo")
	_garage()._on_lapped()
	assert_almost_eq(_grime().remaining(), 1.0, TOLERANCE, "the next demo starts on a clean car")
	assert_almost_eq(_grime().shine(), 0.0, TOLERANCE, "and on one nobody has polished")
