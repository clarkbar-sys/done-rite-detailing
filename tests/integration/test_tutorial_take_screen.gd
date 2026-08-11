## Integration test for [TutorialTakeScreen] — a tutorial take actually filmed, in
## the real room, through the real controls.
##
## Under tests/integration/ for [code]tests/integration/test_title_screen_attract.gd[/code]'s
## reason, which this suite is deliberately the sibling of: every claim needs the
## whole stack running — a car whose panels have been built, masks laid on them a
## frame later, a physics tick to cast the aim's ray on, and a camera that has been
## stood somewhere. What the take [i]decides[/i] needs none of that and is not
## repeated here: [code]tests/unit/test_tutorial_take.gd[/code] has the running
## order and the lengths, and [code]tests/unit/test_tutorial_framing.gd[/code] has
## the shot.
##
## [b]The takes are shortened, and nothing else is.[/b] The catalogue ships at six
## seconds a beat, so filming the sponge clip as a player would see it costs this
## suite ten seconds of real frames per test. [method TutorialTake._init] is public
## and every test below builds its own short take through it — the same trick the
## attract suite plays with [member Garage.attract_seconds_per_pass], and for the
## same reason: the length is the one number that is not the shipped one.
extends GutTest

const SCREEN: String = "res://src/screens/tutorial_take_screen.tscn"

## How long a beat lasts in this suite: half a second, which is thirty physics
## frames at the engine's default rate and plenty for the trigger to have moved
## something.
const QUICK_BEAT: float = 0.5

## Enough ticks for the room to have resolved the take's first press into a mark and
## spent something on it. [code]test_title_screen_attract.gd[/code]'s number and its
## argument.
const RESOLVE_FRAMES: int = 4

## How long [method before_each] will wait for the room to lay its masks before
## giving up. Generous for that suite's reason: the wait is one process frame in a
## room that has just built a car.
const GRIME_TIMEOUT: float = 1.0

## Close enough for a position in metres.
const TOLERANCE: float = 0.0001

var _screen: TutorialTakeScreen = null
var _window_size_before: Vector2i = Vector2i.ZERO
var _chosen_before: String = ""


## Builds the screen, hands it [param take], and waits until there is mud on the car
## to film.
##
## [b]Rolled before the first await, which is not a detail.[/b] The panel a take is
## filmed on is picked on [signal Garage.grimed], one process frame after the room
## is added, so a take handed over after that would be a take with nothing to work.
## It is the same ordering the attract suite has to respect when it shortens a pass.
func _film(take: TutorialTake) -> void:
	var packed: PackedScene = load(SCREEN) as PackedScene
	assert_not_null(packed, "could not load %s" % SCREEN)
	if packed == null:
		return
	_screen = packed.instantiate() as TutorialTakeScreen
	add_child_autofree(_screen)
	_screen.roll(take)
	# WAIT FOR THE SIGNAL, NOT FOR A COUNT OF PHYSICS FRAMES — see
	# `tests/integration/test_title_screen_attract.gd`, which found out the hard way
	# that the frame a room is built in is long enough to run several physics ticks
	# inside one iteration of the main loop.
	await wait_for_signal(_garage().grimed, GRIME_TIMEOUT)
	await wait_physics_frames(RESOLVE_FRAMES)


## A take of [param subject] on [param kind], at this suite's length rather than the
## catalogue's.
func _quick(kind: Surface.Kind, subject: GrimeMap.Stage) -> TutorialTake:
	return TutorialTake.new("quick", kind, subject, QUICK_BEAT, QUICK_BEAT)


func before_each() -> void:
	# The car is pinned to the one every take is filmed on, which is what
	# `src/main/main.gd` does on the way into this screen — see
	# [constant TutorialTake.CAR_STYLE]. Not decoration: [MeshCar] draws from ten
	# when nobody has chosen, the ten are different shapes, and a suite that let it
	# draw would be asserting about whichever car turned up. Put back in after_each,
	# because the pick is process-wide by design and the next suite is entitled to
	# whatever it found — the same care `tests/integration/test_main_menu_cars.gd`
	# takes with it.
	_chosen_before = CarChoice.chosen
	CarChoice.choose(TutorialTake.CAR_STYLE)
	# A headless window is 64x64, and a take aims by projecting the work onto the
	# glass and checking it landed on it — so at that size nothing is ever in frame
	# and the trigger never comes down. `content_scale_size` is the design resolution
	# from project.godot. Put back in after_each: every suite shares this window.
	var root: Window = get_tree().root
	_window_size_before = root.size
	root.size = root.content_scale_size


func after_each() -> void:
	get_tree().root.size = _window_size_before
	CarChoice.choose(_chosen_before)


func _garage() -> Garage:
	return _screen.get_node("Garage") as Garage


func _camera() -> Camera3D:
	return _garage().get_node("%Camera") as Camera3D


func _car() -> Car:
	return _garage().get_node("%Car") as Car


func _belt() -> ToolBelt:
	return _garage().view_model().belt()


## Runs the room on for [param seconds], and then one tick further so a wait for
## exactly a beat lands the other side of the boundary rather than on it.
func _run(seconds: float) -> void:
	await wait_physics_frames(int(seconds * float(Engine.physics_ticks_per_second)) + 1)


# ---- the room: a fixed shot rather than a walk ---------------------------------


func test_it_films_from_a_room_nobody_is_walking() -> void:
	# The whole difference between this screen and the other three, and it is four
	# exports on one [Garage] instance like every other difference between them: there
	# is somebody standing in the bay, they do not move, and the attract mode is off
	# so there is only one stand-in reaching for the belt.
	await _film(_quick(Surface.Kind.BODY, GrimeMap.Stage.WASHED))
	assert_true(_garage().first_person, "there has to be somebody to hold a wand")
	assert_false(_garage().walkaround, "a take is filmed from one spot")
	assert_false(_garage().attracting, "two stand-ins would fight over the belt")


func test_the_eye_is_stood_where_the_framing_says() -> void:
	# [TutorialFraming] end to end: the arithmetic reached a transform. Read off the
	# camera rather than out of the class, so a test cannot pass on a sum that never
	# moved anything.
	await _film(_quick(Surface.Kind.BODY, GrimeMap.Stage.WASHED))
	var car: Car = _car()
	var wanted: Vector3 = TutorialFraming.eye_for(
		car.box_around(_screen.panel()), car.bounds(), _garage().eye_fov()
	)
	assert_almost_eq(
		_camera().global_position.distance_to(wanted),
		0.0,
		0.01,
		"the eye is not standing where the framing put it"
	)


func test_the_shot_holds_still_for_the_whole_take() -> void:
	# The reason a take is worth filming at all. The attract mode's eye is walked
	# round to whatever is being worked and is never still; a clip that drifted would
	# be teaching around the camera rather than with it.
	await _film(_quick(Surface.Kind.BODY, GrimeMap.Stage.WASHED))
	var before: Vector3 = _camera().global_position
	await _run(QUICK_BEAT)
	assert_almost_eq(
		_camera().global_position.distance_to(before), 0.0, TOLERANCE, "the shot drifted"
	)


func test_it_keeps_looking_at_the_car() -> void:
	await _film(_quick(Surface.Kind.BODY, GrimeMap.Stage.WASHED))
	await _run(QUICK_BEAT)
	var to_car: Vector3 = (_car().global_position - _camera().global_position).normalized()
	var looking: Vector3 = -_camera().global_transform.basis.z
	assert_almost_eq(looking.dot(to_car), 1.0, 0.001, "the take is pointed at the driveway")


# ---- the work: the same controls a player has ----------------------------------


func test_the_water_reaches_the_car_with_nobody_touching_anything() -> void:
	# The feature end to end, and the assertion no cutscene could satisfy: the take
	# pressed the glass, the room cast a ray, found a panel, projected onto its mask
	# and spent [member Garage.wash_per_second] on it.
	await _film(_quick(Surface.Kind.BODY, GrimeMap.Stage.WASHED))
	await _run(QUICK_BEAT)
	assert_lt(_garage().grime().remaining(), 1.0, "a take of the water left the car as it was")


func test_it_holds_the_tool_the_beat_calls_for() -> void:
	await _film(_quick(Surface.Kind.BODY, GrimeMap.Stage.WASHED))
	assert_eq(_belt().equipped().id, DetailingTool.Id.POWER_WASH, "mud comes off first")


func test_a_sponge_take_washes_the_panel_before_it_soaps_it() -> void:
	# The lead-in, in the room rather than on paper: a sponge on mud moves nothing,
	# so the product on the car at the end of this is proof that the water beat
	# actually happened first.
	await _film(_quick(Surface.Kind.BODY, GrimeMap.Stage.FOAMED))
	await _run(QUICK_BEAT)
	assert_eq(_belt().equipped().id, DetailingTool.Id.SPONGE, "the subject beat is the bottle")
	await _run(QUICK_BEAT)
	assert_gt(_garage().grime().product(), 0.0, "nothing was laid on the paint the water bared")


func test_the_panel_it_works_is_one_of_the_take_s_own_surface() -> void:
	# A take of the sponge filmed on a lamp lens would be six seconds of a hand
	# covering the only thing in shot — and a take of the blue bottle filmed on paint
	# would be six seconds of a tool the game correctly refuses.
	#
	# The pick and the bottle, and deliberately not "product landed on glass". A
	# car's windows are one panel whose box is mostly bodywork — the pillars and the
	# roof between them — so whether any particular half-second sweep lands on glass
	# rather than on the paint beside it is a fact about which of the ten cars is
	# parked. At the catalogue's own six seconds it has the whole panel to find; at
	# this suite's length it would be a coin toss dressed as an assertion.
	await _film(_quick(Surface.Kind.GLASS, GrimeMap.Stage.FOAMED))
	assert_eq(_car().kind_of(_screen.panel()), Surface.Kind.GLASS, "filmed on the wrong surface")
	await _run(QUICK_BEAT)
	assert_eq(_belt().equipped().id, Surface.cleaner_for(Surface.Kind.GLASS))


# ---- the ending: on the clock, and without taking the process with it ----------


func test_it_stops_filming_when_the_take_runs_out() -> void:
	# Ends on time rather than on cleanliness — the panel below is nowhere near
	# finished at this length, which is the point.
	var take: TutorialTake = _quick(Surface.Kind.BODY, GrimeMap.Stage.WASHED)
	await _film(take)
	assert_not_null(_screen.take(), "the take should still be rolling")
	await _run(take.seconds())
	assert_null(_screen.take(), "a take has to end itself")


func test_a_take_nobody_launched_does_not_end_the_process() -> void:
	# The guard that lets this suite exist. A screen that quit the engine when its
	# take ran out would fail every test after this one and would read as a crash.
	# That the suite carries on past the assertion is most of the test; the assertion
	# is that it really did finish.
	var take: TutorialTake = _quick(Surface.Kind.BODY, GrimeMap.Stage.WASHED)
	await _film(take)
	await _run(take.seconds())
	assert_true(take.finished(), "the take never ran out, so nothing was proved")


func test_a_screen_nobody_asked_for_a_take_on_stands_still() -> void:
	# Which is what an editor, a suite and every command line without
	# [constant TutorialTake.ARG] on it hand this screen. It has to be a room with a
	# car in it and nothing happening, rather than a null dereference.
	var packed: PackedScene = load(SCREEN) as PackedScene
	var screen: TutorialTakeScreen = packed.instantiate() as TutorialTakeScreen
	add_child_autofree(screen)
	await wait_physics_frames(RESOLVE_FRAMES)
	assert_null(screen.take(), "nobody asked for a take")
