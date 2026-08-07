## Integration test for [code]#144[/code] on a car out of the pack: mud only
## where the player can reach, and a done percentage in the corner that can
## actually get there.
##
## [b]It has to be a [MeshCar] and it has to be one style.[/b] The blockout keeps
## its floor pan and arch liners out of [method Car.panels] through
## [constant Car.TRIM_GROUP], so its underside was never the problem; the pack is
## an outside-only shell with no trim at all, and the underside of [code]Body[/code]
## is a face of [code]Body[/code]'s own box. So this is the car the issue was
## filed about. The style is pinned the way
## [code]tests/integration/test_garage_styles.gd[/code] pins it — set on the
## instantiated scene before it enters the tree, because [method MeshCar._ready]
## reads the export once — so a failure here names a car somebody can go and look
## at rather than one of ten.
##
## [b]The room is instanced rather than walked into through
## [code]main.tscn[/code][/b], unlike the trigger and score suites: nothing here
## presses anything. What is being asserted is what the room laid on the car and
## what the corner says about it, and both are readable off the play screen on its
## own.
##
## [b]The panel taken all the way through is a wheel, and that is pragmatism said
## out loud.[/b] A whole car is seven maps, the biggest of them 384 x 256 pixels,
## and finishing one on the CPU is a second of CI time per pass. A wheel is the
## smallest map the car has and it makes the same point: every texel of it that
## was seeded can be washed, foamed and buffed, and when they have been the panel
## calls itself finished — which is the reading that could not become true before
## this change on any panel of any car.
extends GutTest

const PLAY_SCREEN: String = "res://src/screens/play_screen.tscn"

## The style the bay pins for itself in [code]src/world/mesh_car.tscn[/code]: the
## middle of the pack in every direction, and the car a developer running the game
## actually sees.
const STYLE: String = "sedan"

## How long to wait for the room to say the mud is on. A signal and not a count of
## frames, for the reason [code]test_title_screen_attract.gd[/code] records at
## length — and now for a second one: laying the mud on casts tens of thousands of
## rays at the car, so this is the longest frame the room will ever have.
const GRIME_TIMEOUT: float = 20.0

## Passes of a tool at full strength over one face. The brush is subtractive and
## clamped, so a bucket empties in two or three; eight is margin.
const PRESSES: int = 8

## A ten-thousandth, for numbers that are all fractions of one.
const TOLERANCE: float = 0.0001

var _screen: GameScreen = null
var _window_size_before: Vector2i = Vector2i.ZERO


func before_each() -> void:
	# A headless window is 64x64, which is smaller than one tap target, and the HUD
	# below lays itself out against the window. Put back in after_each: every suite
	# shares this window.
	var root: Window = get_tree().root
	_window_size_before = root.size
	root.size = root.content_scale_size
	var packed: PackedScene = load(PLAY_SCREEN) as PackedScene
	assert_not_null(packed, "could not load %s" % PLAY_SCREEN)
	if packed == null:
		return
	var screen: GameScreen = packed.instantiate() as GameScreen
	_screen = screen
	var car: MeshCar = _garage_of(screen).get_node("%Car") as MeshCar
	assert_not_null(car, "the bay must park a MeshCar for any of this to mean anything")
	if car != null:
		car.style = STYLE
	add_child_autofree(_screen)
	await wait_for_signal(_garage().grimed, GRIME_TIMEOUT)


func after_each() -> void:
	get_tree().root.size = _window_size_before


func _garage_of(screen: GameScreen) -> Garage:
	return screen.get_node("Garage") as Garage


func _garage() -> Garage:
	return _garage_of(_screen)


func _car() -> Car:
	return _garage().get_node("%Car") as Car


func _grime() -> Grime:
	return _garage().grime()


func _scoreboard() -> ScoreHud:
	return _screen.get_node("ScoreHud") as ScoreHud


## The panel whose name starts with [param prefix] — [code]Body[/code] and
## [code]Wheel[/code] below, which the pack's own build script asserts the names
## of ([MeshCar]'s class docs have the contract).
func _panel_named(prefix: String) -> Node3D:
	for panel: Node3D in _car().panels():
		if String(panel.name).begins_with(prefix):
			return panel
	return null


## A panel's geometry — the node the map was measured off, which on a mesh car is
## not the panel's root.
func _skin_of(panel: Node3D) -> GeometryInstance3D:
	return _car().skin_of(panel)


## Runs every pass of the job over every face of [param panel], in the room's own
## coordinates and through [Grime] rather than into a [GrimeMap] directly, so the
## world-to-panel conversion the game does on every press is part of what is being
## tested.
##
## A brush wider than the panel, aimed at the middle of its box from each of the
## six axis directions in turn: that covers every texel of every tile in one press
## each, which is what makes finishing a panel affordable here. The mask is what
## decides which of those texels move, and that is the whole point — nothing here
## knows which they are.
func _do_the_whole_job(panel: Node3D) -> void:
	var skin: GeometryInstance3D = _skin_of(panel)
	var box: AABB = skin.get_aabb()
	var middle: Vector3 = skin.global_transform * box.get_center()
	var wide: float = maxf(box.size.x, maxf(box.size.y, box.size.z)) * 2.0
	var faces: Array[Vector3] = [
		Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD
	]
	for stage: GrimeMap.Stage in [
		GrimeMap.Stage.WASHED, GrimeMap.Stage.FOAMED, GrimeMap.Stage.BUFFED
	]:
		for axis: Vector3 in faces:
			var facing: Vector3 = (skin.global_basis * axis).normalized()
			for _press: int in PRESSES:
				match stage:
					GrimeMap.Stage.WASHED:
						_grime().wash(panel, middle, facing, wide, 1.0)
					GrimeMap.Stage.FOAMED:
						_grime().foam(panel, middle, facing, wide, 1.0)
					_:
						_grime().buff(panel, middle, facing, wide, 1.0)


# ---- the mud ------------------------------------------------------------------


func test_the_room_laid_the_mud_on_at_all() -> void:
	assert_true(_grime().is_laid(), "the room never got the mud onto the car")
	assert_almost_eq(_grime().remaining(), 1.0, 0.001, "and a fresh car is not entirely dirty")


func test_the_underside_of_the_car_has_no_mud_on_it() -> void:
	# The sentence the issue was filed as: "dont put grime on underside of car — U
	# cant clean it". The pack is a shell with no trim group, so the underside is
	# the `-Y` tile of `Body`'s own box, and nothing standing on the driveway can
	# ever get a ray onto it.
	var body: Node3D = _panel_named(MeshCar.BODY_PART)
	assert_not_null(body, "the car has no body")
	if body == null:
		return
	var map: GrimeMap = _grime().map_of(body)
	var middle: Vector3 = _skin_of(body).get_aabb().get_center()
	assert_almost_eq(map.mud_at(middle, Vector3.DOWN), 0.0, TOLERANCE, "the underside is muddy")


func test_the_paint_the_player_can_see_is_still_filthy() -> void:
	# The other half of the same claim, and the half that makes the one above worth
	# anything: a mask that came back empty would pass that test and would be a car
	# with no mud on it at all.
	var body: Node3D = _panel_named(MeshCar.BODY_PART)
	assert_not_null(body, "the car has no body")
	if body == null:
		return
	var map: GrimeMap = _grime().map_of(body)
	var middle: Vector3 = _skin_of(body).get_aabb().get_center()
	assert_almost_eq(
		map.mud_at(middle, Vector3.RIGHT), GrimeMap.FILTHY, TOLERANCE, "the flank is clean"
	)
	assert_almost_eq(map.mud_at(middle, Vector3.UP), GrimeMap.FILTHY, TOLERANCE, "the roof is")


func test_every_panel_has_somewhere_the_player_can_reach() -> void:
	# A panel the rays all missed would be dropped out of the car's averages
	# entirely ([method GrimeMap.has_reach]) — which is the right behaviour and the
	# wrong outcome, so it is worth knowing that no panel of the parked car is in
	# that state.
	for panel: Node3D in _grime().panels():
		assert_true(_grime().map_of(panel).has_reach(), "nothing is reachable on %s" % panel.name)


# ---- the readout --------------------------------------------------------------


func test_the_corner_says_how_far_along_the_job_is() -> void:
	assert_not_null(_scoreboard(), "the play screen has no scoreboard")
	assert_eq(_scoreboard().done_shown(), 0, "a car nobody has touched is not partly done")


func test_finishing_a_panel_moves_the_readout_off_zero() -> void:
	var wheel: Node3D = _panel_named(MeshCar.WHEEL_PART)
	assert_not_null(wheel, "the car has no wheels")
	if wheel == null:
		return
	_do_the_whole_job(wheel)
	# The screen polls the number once a frame, the way it polls the walk and the
	# wage — see `_show_how_far_along` there — so one frame is what it takes.
	await wait_process_frames(1)
	assert_gt(_scoreboard().done_shown(), 0, "a finished panel left the corner reading zero")


# ---- and the reading that could not be reached before -------------------------


func test_a_panel_of_a_pack_car_can_be_finished() -> void:
	var wheel: Node3D = _panel_named(MeshCar.WHEEL_PART)
	assert_not_null(wheel, "the car has no wheels")
	if wheel == null:
		return
	var map: GrimeMap = _grime().map_of(wheel)
	assert_false(map.is_finished(), "the panel started finished, so this proves nothing")
	_do_the_whole_job(wheel)
	assert_true(map.is_clean(), "the mud did not all come off")
	assert_true(map.is_finished(), "and the panel does not call itself done")
	assert_almost_eq(map.shine(), 1.0, TOLERANCE, "so its progress number cannot reach one")
