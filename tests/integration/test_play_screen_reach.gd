## Integration test for the four tools that leave the hand: the sponge and the
## rag onto the paint, the two bottles a few inches off it with product crossing
## the gap.
##
## [b]Why a suite of its own.[/b] [code]test_play_screen_wand.gd[/code] is about
## the one tool that stays in the hand and [code]test_play_screen_jet.gd[/code] is
## about the water it throws from there. This is the other half of the belt, and
## the thing being asserted is the one no unit test can reach:
## [code]test_reach_carry.gd[/code] proves the arithmetic puts a tool a known
## distance off a surface, and only a real press against real bodywork proves that
## the surface it was handed is the one the player is looking at.
##
## [b]Everything goes through a real press[/b], for that reason. The room only
## knows where the paint is and which way it faces because it cast a ray, so the
## finger goes down for the length of each test and [method after_each] lifts it.
##
## [b]What is measured and what deliberately is not.[/b] Where each tool ends up
## relative to the crosshair, and where the mist starts, stops and what colour it
## is — all read back off the things that actually draw. What no test here can say
## is whether a sponge on a door [i]looks[/i] like a sponge on a door; that is what
## the thing is for.
extends GutTest

const PLAY_SCREEN: String = "res://src/screens/play_screen.tscn"

## Above GUT's own output layer, so a finger aimed at the game lands on the game.
const ABOVE_THE_RUNNER: int = 200

## How near its promised standoff a tool has to land, in metres.
##
## A centimetre, and the slack is a clock rather than a fudge — the same one
## [code]test_play_screen_jet.gd[/code] records: the mark is resolved on the
## physics tick and the tool is posed on the frame clock afterwards, so the two
## agree exactly on a shot that has stopped moving and disagree by however far one
## frame carries the eye on a machine still easing something.
const ON_THE_SPOT: float = 0.01

## How near the can's nozzle the mist has to start, in metres. The same
## allowance and for the same reason.
const ON_THE_NOZZLE: float = 0.01

## How near the mark the mist has to land, in metres. A millimetre, and tight on
## purpose: unlike the nozzle there is no clock between the two — the emitter's
## throw and the crosshair's point are set from the same numbers on the same tick.
const ON_THE_MARK: float = 0.001

## Long enough for the standoff to have eased from the parked stance out to the
## gap the walk wants, which is where the whole shot is measured.
const SETTLE_FRAMES: int = 90

## Enough physics ticks for a press to have been resolved into a mark.
const RESOLVE_FRAMES: int = 4

## Enough drawn frames for the swing to have arrived and a tool to have travelled
## all the way out — half a second, against a fifth and a sixth.
const SWING_FRAMES: int = 30

## The two tools that go onto the paint, and the two that hover over it.
const SCRUBBERS: Array[DetailingTool.Id] = [
	DetailingTool.Id.SPONGE,
	DetailingTool.Id.DRYING_RAG,
]
const BOTTLES: Array[DetailingTool.Id] = [
	DetailingTool.Id.WINDOW_CLEANER,
	DetailingTool.Id.TIRE_ENGINE_CLEANER,
]

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
	# A finger left on the glass is global state, and it is awaited for the reason
	# [code]test_play_screen_jet.gd[/code] records at length: GUT resolves every
	# wait through one awaiter, so a release still running at the end of a test
	# makes the next test's settle come back early with the camera still moving.
	await _lift()
	get_tree().root.size = _window_size_before


func _garage() -> Garage:
	return _screen.get_node("Garage") as Garage


func _camera() -> Camera3D:
	return _garage().get_node("%Camera") as Camera3D


func _car() -> Car:
	return _garage().get_node("%Car") as Car


func _view_model() -> ViewModel:
	return _garage().view_model()


func _marker() -> AimMarker:
	return _garage().aim_marker()


## What the aim is drawn with. Reached through the room's own accessor rather than
## by node path, so this suite is not the thing that decides what it is called.
func _sight() -> ToolSight:
	return _garage().tool_sight()


func _mist() -> SprayMist:
	return _sight().spray_mist()


## The emitter the product actually comes out of, reached by the name [SprayMist]
## gives it rather than by counting children.
func _spray() -> GPUParticles3D:
	return _mist().get_node(NodePath(SprayMist.MIST)) as GPUParticles3D


## The three sights, which are children of one node rather than three loose ones
## beside the car. Asserted once here because it is the arrangement everything
## below reads through, and a room that had built them anywhere else would fail
## with a null rather than with a reason.
func _sights_are_together() -> bool:
	return (
		_sight().marker().get_parent() == _sight()
		and _sight().wash_jet().get_parent() == _sight()
		and _sight().spray_mist().get_parent() == _sight()
	)


func _crosshair() -> Vector3:
	return _marker().marked_point()


## The middle of the car, on the glass. The one press that must always land on
## bodywork.
func _at_the_car() -> Vector2:
	return _camera().unproject_position(_car().global_position)


func _touch(at: Vector2, pressed: bool) -> void:
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.position = at
	touch.pressed = pressed
	Input.parse_input_event(touch)
	Input.flush_buffered_events()


## Puts [param id] in the player's hands, presses in the middle of the car and
## holds, then waits for the room to have marked something and the tool to have
## finished travelling.
func _press_with(id: DetailingTool.Id) -> void:
	_view_model().belt().equip(id)
	_touch(_at_the_car(), true)
	await wait_physics_frames(RESOLVE_FRAMES)
	await wait_process_frames(SWING_FRAMES)


func _lift() -> void:
	_touch(Vector2.ZERO, false)
	await wait_physics_frames(RESOLVE_FRAMES)
	await wait_process_frames(SWING_FRAMES)


func _settle() -> void:
	await wait_physics_frames(SETTLE_FRAMES)


## How far [param point] is off the paint at the crosshair, measured along the
## panel's own normal — which is what a standoff is. Read off the mark's own
## orientation rather than re-cast here, so this measures the surface the room
## handed the tool.
func _off_the_paint(point: Vector3) -> float:
	return (point - _crosshair()).dot(_marker().global_basis.y.normalized())


## The worst [param tint] is off [param wanted], as a single channel distance.
func _off_tint(tint: Color, wanted: Color) -> float:
	var worst: float = absf(tint.r - wanted.r)
	worst = maxf(worst, absf(tint.g - wanted.g))
	return maxf(worst, absf(tint.b - wanted.b))


# ---- the two that go onto the paint ------------------------------------------


func test_the_room_keeps_its_three_sights_in_one_place() -> void:
	# [ToolSight] exists because the crosshair, the water and the product are
	# mutually exclusive answers to one question. If the room ever goes back to
	# building them loose beside the car, the rule for choosing between them goes
	# back to being spread across a file about a camera.
	assert_not_null(_sight(), "a first-person room has something to draw the aim with")
	assert_true(_sights_are_together(), "and all three of them live in it")


func test_a_scrubbing_tool_ends_up_on_the_panel_it_is_pointed_at() -> void:
	# The whole of what was asked for the sponge and the rag: not near the car, on
	# it. Measured square on to the panel the room actually marked, so a tool that
	# arrived at the right distance from the wrong surface fails.
	await _settle()
	for id: DetailingTool.Id in SCRUBBERS:
		await _press_with(id)
		var proxy: MeshInstance3D = _view_model().proxy_for(id)
		var standoff: float = _off_the_paint(proxy.global_position)
		assert_gt(standoff, 0.0, "%d: on the outside of the paint" % id)
		assert_lt(standoff, ViewModel.SPRAY_STANDOFF, "%d: and against it, not hovering" % id)
		await _lift()


func test_a_scrubbing_tool_lies_flat_against_the_panel() -> void:
	# The other half of "on the surface itself": its broad face is on the paint
	# rather than its edge. A sponge standing on one corner would satisfy every
	# distance above and would read as a brick balanced on a door.
	await _settle()
	for id: DetailingTool.Id in SCRUBBERS:
		await _press_with(id)
		var proxy: MeshInstance3D = _view_model().proxy_for(id)
		var facing: Vector3 = proxy.global_basis.y.normalized()
		assert_almost_eq(
			facing.dot(_marker().global_basis.y.normalized()), 1.0, 0.001, "%d: flat on it" % id
		)
		await _lift()


func test_letting_go_brings_every_tool_back_to_the_hand() -> void:
	# Holding the glass is working and letting go is not — the same rule the mark
	# and the water already follow, applied to a tool that is now two metres away
	# when it is being used. A sponge left on the paint after a release would be a
	# sponge the player has put down on the car.
	await _settle()
	for id: DetailingTool.Id in SCRUBBERS + BOTTLES:
		_view_model().belt().equip(id)
		await wait_process_frames(SWING_FRAMES)
		var rest: Transform3D = _view_model().proxy_for(id).transform
		await _press_with(id)
		assert_gt(
			_view_model().proxy_for(id).transform.origin.distance_to(rest.origin),
			1.0,
			"%d: the press sent it out" % id
		)
		await _lift()
		assert_almost_eq(
			_view_model().proxy_for(id).transform.origin,
			rest.origin,
			Vector3.ONE * ON_THE_SPOT,
			"%d: and the release brought it back" % id
		)


# ---- the two that hover and spray --------------------------------------------


func test_a_bottle_holds_its_nozzle_a_few_inches_off_the_paint() -> void:
	# The measurement the whole behaviour was asked for. The nozzle rather than the
	# bottle, for [method ReachCarry.worked]'s reason — and against the panel the
	# room marked rather than against a number this test made up, so a can hovering
	# perfectly over the wrong surface fails.
	await _settle()
	for id: DetailingTool.Id in BOTTLES:
		await _press_with(id)
		var nozzle: Marker3D = _view_model().muzzle_of(id)
		assert_not_null(nozzle, "%d: a bottle has a nozzle" % id)
		assert_almost_eq(
			_off_the_paint(nozzle.global_position),
			ViewModel.SPRAY_STANDOFF,
			ON_THE_SPOT,
			"%d: a few inches off the spot" % id
		)
		await _lift()


func test_the_product_is_thrown_from_that_nozzle_onto_the_mark() -> void:
	# The geometry the picture rests on: emitted at the can's nozzle, aimed down the
	# short line to the crosshair, arriving on it. Product merely parallel to that
	# line passes nothing here.
	await _settle()
	for id: DetailingTool.Id in BOTTLES:
		await _press_with(id)
		var nozzle: Vector3 = _view_model().muzzle_of(id).global_position
		assert_true(_mist().is_spraying(), "%d: the can is spraying" % id)
		assert_lt(_mist().global_position.distance_to(nozzle), ON_THE_NOZZLE, "out of the nozzle")
		assert_lt(_mist().landing().distance_to(_crosshair()), ON_THE_MARK, "and onto the paint")
		await _lift()


func test_the_spray_lands_as_wide_as_the_patch_it_is_covering() -> void:
	# What makes this a picture of the work rather than a decoration: the cone
	# arrives on [member Garage.scrub_radius_metres] of paint, which is the patch
	# [method Garage._spend_the_trigger] is laying product on.
	await _settle()
	await _press_with(DetailingTool.Id.WINDOW_CLEANER)
	assert_almost_eq(
		_mist().spread(), _garage().scrub_radius_metres, ON_THE_MARK, "as wide as it covers"
	)
	assert_eq(_spray().amount, SprayMist.DROPS, "and every droplet of it")


func test_each_bottle_sprays_its_own_product_colour() -> void:
	# The one piece of feedback in the game that says which bottle is in hand while
	# the player is looking at the car. Read against [method Surface.product_from],
	# which is derived from the surface-to-cleaner pairing rather than tabled beside
	# it — so a mist that came out the wrong colour is a mist disagreeing with the
	# film it is about to leave behind.
	await _settle()
	for id: DetailingTool.Id in BOTTLES:
		await _press_with(id)
		assert_lt(
			_off_tint(_mist().product(), Surface.product_from(id)),
			0.0001,
			"%d: sprays what it leaves behind" % id
		)
		await _lift()
	assert_ne(
		Surface.product_from(DetailingTool.Id.WINDOW_CLEANER),
		Surface.product_from(DetailingTool.Id.TIRE_ENGINE_CLEANER),
		"and the two are told apart by it"
	)


func test_the_tools_that_do_not_spray_do_not_spray() -> void:
	# Swapped mid-press on purpose: the sight is chosen from the belt every tick, so
	# a can put away while the finger is down has to stop spraying without the
	# finger being lifted first. The power wash is in here because it is the one
	# tool with a nozzle that must not feed this emitter — it has water of its own.
	await _settle()
	await _press_with(DetailingTool.Id.TIRE_ENGINE_CLEANER)
	assert_true(_mist().is_spraying(), "the can was spraying to begin with")
	for id: DetailingTool.Id in SCRUBBERS + [DetailingTool.Id.POWER_WASH]:
		_view_model().belt().equip(id)
		await wait_physics_frames(RESOLVE_FRAMES)
		assert_false(_mist().is_spraying(), "%d does not spray product" % id)


func test_letting_go_shuts_the_can_off_and_lets_the_last_of_it_land() -> void:
	# Holding the glass is spraying and letting go is not. The second half is what
	# the world-space emission buys: the emitter stops rather than hiding, so the
	# product already in the air finishes its throw instead of being deleted along
	# with the can's intention to have sprayed it.
	await _settle()
	await _press_with(DetailingTool.Id.WINDOW_CLEANER)
	assert_true(_mist().is_spraying(), "spraying while the finger is down")
	await _lift()
	assert_false(_mist().is_spraying(), "and not once it is up")
	assert_true(_spray().visible, "with what is in the air still drawn")
	assert_false(_spray().local_coords, "and still where the can left it")
