## Integration test for what the power wash draws: the water it throws from its
## nozzle at the paint.
##
## [b]Why a suite of its own.[/b] [code]test_play_screen_aim.gd[/code] is about
## where the mark lands and [code]test_play_screen_wand.gd[/code] is about the
## line the wand lies on — both true of every press with any tool. This is about
## the one tool that answers "where am I pointed" with a jet, and it was the first
## one to answer it with anything at all: the whole belt draws its own sight now,
## and [code]test_play_screen_wash.gd[/code] is where "no tool draws the ring" is
## asserted across all five.
##
## [b]What is measured and what deliberately is not.[/b] Where the water starts,
## where it gets to and how wide it is when it arrives are asserted through
## [WashJet]'s own read-backs — which take their answers off the emitter that is
## actually flying the droplets, so a jet that quietly stopped short or fanned
## twice as wide fails here. Its colours and its opacity are read off the colour
## ramp the droplets are tinted from, since "bright blue at the nozzle, deeper
## where it lands, half see-through" is the whole brief and a gradient that came
## out grey would pass every geometric assertion in the file. What no test can say
## is whether it
## [i]looks[/i] like water; that is what the thing is for.
##
## [b]Nothing here waits for a droplet.[/b] The particles are simulated on the
## GPU and a headless run has no frames to look at them in, so every assertion is
## about what the emitter has been told to do rather than about where some
## individual drop got to. That is the honest seam: the throw, the fan and the
## ramp are the whole of what this class decides, and the engine is not on trial.
##
## [b]Everything goes through a real press[/b], for [code]test_play_screen_wand
## .gd[/code]'s reason: the room only knows where the mark is because it cast a
## ray, and the water is thrown at the mark. So the finger goes down for the
## length of each test and [method after_each] lifts it.
extends GutTest

const PLAY_SCREEN: String = "res://src/screens/play_screen.tscn"

## Above GUT's own output layer, so a finger aimed at the game lands on the game.
const ABOVE_THE_RUNNER: int = 200

## Close enough for positions in metres — a tenth of a millimetre.
const TOLERANCE: float = 0.0001

## How near the wand's nozzle the water has to start, in metres.
##
## A centimetre rather than [constant TOLERANCE], and the slack is a clock
## rather than a fudge: the emitter is placed on the physics tick from wherever
## the nozzle was then, and the nozzle is posed on the frame clock afterwards
## ([method ViewModel._process]). The two agree exactly on a shot that has
## stopped moving — measured at zero, repeatedly, which is what
## [method after_each] awaiting its own [method _lift] buys — and they disagree
## by however far one frame carries the eye on a machine still easing something.
## A centimetre absorbs that and is still a fiftieth of the jet's own width.
const ON_THE_NOZZLE: float = 0.01

## How near the mark the water has to land, in metres.
##
## A millimetre, and tight on purpose: unlike the nozzle above there is no clock
## between the two. The emitter's throw and the crosshair's point are set from the
## same numbers on the same tick, so anything past float noise here is the jet
## having decided to stop somewhere else.
const ON_THE_MARK: float = 0.001

## Long enough for the standoff to have eased from the parked stance out to the
## gap the walk wants, which is where the whole shot is measured.
const SETTLE_FRAMES: int = 90

## Enough physics ticks for a press to have been resolved into a mark.
const RESOLVE_FRAMES: int = 4

## Enough drawn frames for the swing to have arrived and the wand to have come
## all the way up — half a second, against a fifth and a sixth.
const SWING_FRAMES: int = 30

## How far above the car's own silhouette to press for a shot that is certainly
## sky, in pixels on the glass.
const SKY_MARGIN: float = 60.0

## How thin a slice off the top of the wand's mesh counts as the end face of its
## nozzle, in metres. A millimetre, for
## [code]tests/integration/test_tool_model.gd[/code]'s reason: enough to take a
## whole ring rather than the one vertex that happens to be highest.
const END_FACE: float = 0.001

## How far into the car's own height to press for a shot that is certainly high
## bodywork and one that is certainly low, as a fraction of that height. A
## tenth in from each end: past the glass at the top and above the shadow under
## the sill at the bottom, on every one of the ten pack styles.
const OFF_THE_EDGE: float = 0.1

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
	# A finger left on the glass is global state: the next test would start with
	# something already spraying, and its failure would land nowhere near its cause.
	#
	# [b]Awaited, and that is not tidiness.[/b] GUT resolves every wait through one
	# awaiter per run, so a [method _lift] left running past the end of a test is a
	# second waiter on it — and the next test's [method _settle] then comes back
	# early, with the standoff still easing the camera 2.4 cm a tick. Every
	# absolute position in this suite is measured against a shot that has stopped
	# moving, so that lands as "the water is not on the nozzle" three tests later
	# and nowhere near its cause. Found exactly that way.
	await _lift()
	get_tree().root.size = _window_size_before


func _garage() -> Garage:
	return _screen.get_node("Garage") as Garage


func _camera() -> Camera3D:
	return _garage().get_node("%Camera") as Camera3D


func _view() -> SubViewport:
	return _garage().get_node("View") as SubViewport


func _car() -> Car:
	return _garage().get_node("%Car") as Car


func _view_model() -> ViewModel:
	return _garage().view_model()


func _marker() -> AimMarker:
	return _garage().aim_marker()


func _jet() -> WashJet:
	return _garage().wash_jet()


## The emitter the water actually comes out of, reached by the name [WashJet]
## gives it rather than by counting children.
func _water() -> GPUParticles3D:
	return _jet().get_node(NodePath(WashJet.WATER)) as GPUParticles3D


## How the droplets are flown, read off the emitter rather than rebuilt here — so
## the spread being asserted on is the spread they are fired into.
func _flight() -> ParticleProcessMaterial:
	return _water().process_material as ParticleProcessMaterial


## The bright-to-deep run the droplets are tinted from.
func _ramp() -> Gradient:
	var ramp: GradientTexture1D = _flight().color_ramp as GradientTexture1D
	return ramp.gradient


## Where the water leaves the wand.
func _nozzle() -> Vector3:
	return _view_model().muzzle().global_position


## The middle of the end face of the wand the player can see, in the world.
##
## Measured off the mesh rather than off the marker, which is the whole point of
## the one test that uses it: the marker says where the game thinks the nozzle is
## and this says where it actually is on the model. The topmost [constant
## END_FACE] of the mesh and not its single highest vertex, because the end of a
## round nozzle is a ring and any one of its vertices is a nozzle radius off the
## middle.
func _wand_tip() -> Vector3:
	var proxy: MeshInstance3D = _view_model().proxy_for(DetailingTool.Id.POWER_WASH)
	var mesh: Mesh = proxy.mesh
	var top: float = mesh.get_aabb().end.y - END_FACE
	var face: AABB = AABB()
	var found: bool = false
	for surface: int in mesh.get_surface_count():
		var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex: Vector3 in vertices:
			if vertex.y < top:
				continue
			face = face.expand(vertex) if found else AABB(vertex, Vector3.ZERO)
			found = true
	return proxy.global_transform * face.get_center()


func _crosshair() -> Vector3:
	return _marker().marked_point()


func _on_screen(point: Vector3) -> Vector2:
	return _camera().unproject_position(point)


## The middle of the car, on the glass. The one press that must always land on
## bodywork.
func _at_the_car() -> Vector2:
	return _on_screen(_car().global_position)


## A patch of sky above the roof: a press that hits nothing, so the mark comes
## from the nearest-point fallback and is somewhere the finger is not.
func _at_the_sky() -> Vector2:
	var roof: Vector3 = Vector3(
		_car().global_position.x, _car().bounds().end.y, _car().global_position.z
	)
	var sky: Vector2 = _on_screen(roof) - Vector2(0.0, SKY_MARGIN)
	assert_true(
		Rect2(Vector2.ZERO, Vector2(_view().size)).has_point(sky),
		"the sky press at %v is off the picture and would not be a press at all" % sky
	)
	return sky


## A press high on the car and a press low on it, on the glass — the two ends of
## the swing a player actually uses, and what "at every aim angle" means for the
## wand: pointed up at the roof it is nearly along the eye's own line, and pointed
## down at the rockers it is swung as far off it as the pitch fence allows.
func _up_and_down() -> Array[Vector2]:
	var bounds: AABB = _car().bounds()
	var high: Vector3 = Vector3(
		_car().global_position.x,
		bounds.end.y - bounds.size.y * OFF_THE_EDGE,
		_car().global_position.z
	)
	var low: Vector3 = Vector3(high.x, bounds.position.y + bounds.size.y * OFF_THE_EDGE, high.z)
	var presses: Array[Vector2] = [_on_screen(high), _on_screen(low)]
	for at: Vector2 in presses:
		assert_true(
			Rect2(Vector2.ZERO, Vector2(_view().size)).has_point(at),
			"the press at %v is off the picture and would not be a press at all" % at
		)
	return presses


func _touch(at: Vector2, pressed: bool) -> void:
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.position = at
	touch.pressed = pressed
	Input.parse_input_event(touch)
	Input.flush_buffered_events()


## Presses at [param at] and holds, then waits for the room to have marked
## something and the tool to have finished coming up.
func _press(at: Vector2) -> void:
	_touch(at, true)
	await wait_physics_frames(RESOLVE_FRAMES)
	await wait_process_frames(SWING_FRAMES)


func _lift() -> void:
	_touch(Vector2.ZERO, false)
	await wait_physics_frames(RESOLVE_FRAMES)
	await wait_process_frames(SWING_FRAMES)


func _settle() -> void:
	await wait_physics_frames(SETTLE_FRAMES)


## How far the water gets, nozzle to landing.
func _throw() -> float:
	return _jet().global_position.distance_to(_jet().landing())


## The worst [param tint] is off [param wanted], as a single channel distance.
## One number so a colour is one assertion with a readable message rather than
## four that all say the same thing.
func _off_tint(tint: Color, wanted: Color) -> float:
	var worst: float = absf(tint.r - wanted.r)
	worst = maxf(worst, absf(tint.g - wanted.g))
	worst = maxf(worst, absf(tint.b - wanted.b))
	return maxf(worst, absf(tint.a - wanted.a))


# ---- the water the power wash throws -----------------------------------------


func test_the_power_wash_sprays_water_instead_of_a_crosshair() -> void:
	# The swap itself. Both halves matter: water that appeared while the ring
	# stayed on the paint would be two answers to one question, which is the thing
	# this change exists to stop.
	await _settle()
	assert_false(_jet().is_spraying(), "nothing is spraying before the press")
	await _press(_at_the_car())
	assert_true(_jet().is_spraying(), "the power wash throws water")
	assert_eq(_water().amount, WashJet.DROPS, "and throws all of it")
	assert_false(_marker().is_crosshair_drawn(), "and the crosshair gets out of its way")
	assert_true(_marker().is_marking(), "while the mark itself is still made")


func test_the_water_is_thrown_from_the_nozzle_at_the_mark() -> void:
	# The geometry the whole thing rests on: emitted at the wand's nozzle, aimed
	# down the line to the crosshair, arriving on it. Water merely parallel to that
	# line passes nothing here.
	await _settle()
	await _press(_at_the_car())
	assert_lt(_jet().global_position.distance_to(_nozzle()), ON_THE_NOZZLE, "out of the nozzle")
	assert_lt(_jet().landing().distance_to(_crosshair()), ON_THE_MARK, "and onto the paint")
	var along: Vector3 = _jet().global_position.direction_to(_jet().landing())
	assert_almost_eq(along.dot(_nozzle().direction_to(_crosshair())), 1.0, 0.001, "down the line")
	assert_eq(_flight().direction, WashJet.FAR_END, "which is the axis the droplets are fired on")


func test_the_water_leaves_the_end_of_the_wand_the_player_can_see() -> void:
	# Issue #162: "water must leave from the nozzle tip (it starts too low)". Every
	# assertion in this file passed while that was happening, and the test above is
	# why — it measures the water against the nozzle [i]marker[/i], and the marker
	# was exactly where it was supposed to be. What was wrong was the model under
	# it: the wand was a Sketchfab flamethrower whose box was sized by the gas
	# bottle strapped across it, so the barrel's own tip sat 12 cm off the marker
	# and the jet left a point in mid-air beside the wand.
	#
	# So this one goes around the marker entirely and reads the drawn mesh: the
	# middle of the topmost face of the thing in the player's hands, in world
	# coordinates, against where the emitter was actually put. The two are the same
	# claim the player makes with their eyes.
	#
	# [b]At both ends of the swing[/b], because that is the acceptance the issue
	# asked for and because a wand is posed by a rotation about the hand — an
	# origin that agreed with the model at one angle and not another would be an
	# offset in the wrong frame, which is a different bug that would look identical
	# in one screenshot.
	await _settle()
	for at: Vector2 in _up_and_down():
		await _press(at)
		var off: float = _jet().global_position.distance_to(_wand_tip())
		assert_lt(off, ON_THE_NOZZLE, "the water starts %.3f m from the end of the nozzle" % off)
		# And the marker is on the model, which is the same fact from the other
		# side and the one a new model could quietly break: it is what says the
		# catalogue's box and the mesh inside it still agree about which point is
		# the business end.
		assert_lt(
			_nozzle().distance_to(_wand_tip()), ON_THE_NOZZLE, "and the marker is on the wand"
		)
		await _lift()


func test_the_water_flies_at_one_speed_and_lives_as_long_as_the_throw_takes() -> void:
	# What makes the reach above a fact about the emitter rather than about a
	# transform: the droplets are given a fixed speed and exactly enough life to
	# cross the gap, plus [constant WashJet.OVERSHOOT] so they break over the panel
	# instead of stopping in the air in front of it. Both ends are asserted,
	# because a jet with twice the speed and half the life would land in the right
	# place having crossed the room instantly.
	await _settle()
	await _press(_at_the_car())
	var reach: float = _nozzle().distance_to(_crosshair())
	assert_almost_eq(_flight().initial_velocity_min, WashJet.SPEED, TOLERANCE, "one speed out")
	assert_almost_eq(_flight().initial_velocity_max, WashJet.SPEED, TOLERANCE, "and the same in")
	assert_almost_eq(
		_water().lifetime * WashJet.SPEED,
		reach * WashJet.OVERSHOOT,
		ON_THE_NOZZLE,
		"a droplet lives exactly as long as the throw takes, and a little over"
	)
	assert_eq(_flight().gravity, Vector3.ZERO, "and does not sag out of the jet on the way")


func test_the_spray_lands_as_wide_as_the_water_it_stands_in_for() -> void:
	# What makes this a picture of the physics rather than a decoration: the patch
	# the droplets arrive on is [member Garage.wash_radius_metres] of paint, which
	# is the patch the trigger is taking mud off. The angle is asserted as well as
	# the width, because the width alone would pass for a jet that stopped short
	# and kept the radius — and the angle is what stays true as the player walks in.
	await _settle()
	await _press(_at_the_car())
	var radius: float = _garage().wash_radius_metres
	assert_almost_eq(_jet().spread(), radius, ON_THE_MARK, "as wide as the water lands")
	assert_almost_eq(
		_jet().spread() / _throw(),
		radius / _nozzle().distance_to(_crosshair()),
		0.001,
		"and at the angle that would put exactly that radius on the mark"
	)


func test_the_droplets_run_bright_at_the_nozzle_and_deep_where_they_land() -> void:
	# The brief, read back off the ramp the droplets are tinted from. The gradient
	# is the whole of the colour: bright blue at birth, the same blue with the
	# light gone out of it by the time it arrives, and gone altogether by the time
	# it dies — that last stop is what keeps a few hundred droplets all stopping at
	# the same distance from reading as a wall. The opacity is one number and is
	# the reason the car is still visible through all of this.
	await _settle()
	await _press(_at_the_car())
	var ramp: Gradient = _ramp()
	assert_eq(ramp.get_point_count(), 3, "three stops: pressure, spent, gone")
	assert_lt(
		_off_tint(ramp.get_color(0), Color(WashJet.TIP, WashJet.OPACITY)),
		TOLERANCE,
		"a droplet leaves the nozzle bright and about half opaque"
	)
	assert_lt(
		_off_tint(ramp.get_color(1), Color(WashJet.SPRAY, WashJet.OPACITY)),
		TOLERANCE,
		"and arrives deeper"
	)
	assert_almost_eq(ramp.get_offset(1), WashJet.SPENT, TOLERANCE, "with the fade left to run")
	assert_almost_eq(ramp.get_color(2).a, 0.0, TOLERANCE, "before it goes out altogether")
	# Darker and not merely different: the far end is the near end with light taken
	# out of it, which is the whole of what the run down the throw is saying. A
	# gradient that came out brighter at the paint would pass an `assert_ne` and
	# would be a jet lighting up as it lost pressure.
	assert_lt(
		WashJet.SPRAY.get_luminance(),
		WashJet.TIP.get_luminance(),
		"which is a gradient, and one that runs the way water does"
	)
	var mist: StandardMaterial3D = _water().material_override as StandardMaterial3D
	assert_true(mist.vertex_color_use_as_albedo, "so the ramp above is what gets drawn")
	assert_eq(
		mist.billboard_mode,
		BaseMaterial3D.BILLBOARD_PARTICLES,
		"and every droplet faces the player rather than turning edge-on to half of them"
	)


func test_the_water_follows_the_mark_across_a_drag() -> void:
	# Two presses that mark different places, so a jet aimed once and cached cannot
	# pass. The sky press is the interesting one: the ray misses the car entirely
	# and the mark snaps back onto the nearest bodywork, which is where the water
	# goes — so it is where the jet has to be thrown too.
	await _settle()
	await _press(_at_the_car())
	var first: Vector3 = _jet().landing()
	await _lift()
	await _press(_at_the_sky())
	assert_gt(_jet().landing().distance_to(first), 0.1, "the water went to the second mark")
	assert_lt(_jet().landing().distance_to(_crosshair()), ON_THE_MARK, "and reaches it")


func test_another_tool_puts_the_water_away_without_putting_a_ring_back() -> void:
	# Swapped mid-press on purpose: the sight is chosen from the belt every tick,
	# so it has to change without the finger being lifted first.
	#
	# The second half is what the swap no longer does. It used to hand the ring
	# back, because the other four tools had nothing else to say; they all draw
	# their own sight now — the sponge trailing foam here — so the water stops and
	# nothing red replaces it. The mark is still made, which is the thing the ring
	# was never the same as.
	await _settle()
	await _press(_at_the_car())
	assert_true(_jet().is_spraying(), "the washer was spraying to begin with")
	_view_model().belt().equip(DetailingTool.Id.SPONGE)
	await wait_physics_frames(RESOLVE_FRAMES)
	assert_false(_jet().is_spraying(), "a sponge does not spray")
	assert_false(_marker().is_crosshair_drawn(), "and does not bring the ring back with it")
	assert_true(_marker().is_marking(), "while the mark itself is still made")


func test_letting_go_shuts_the_water_off_and_lets_the_last_of_it_land() -> void:
	# Holding the glass is firing and letting go is not — the same rule the mark
	# already follows, applied to the thing that replaced it. The second half is
	# what a solid cone could not do: the trigger stops the emitter rather than
	# hiding it, and the droplets already in the air are in world coordinates, so
	# the water that had left the nozzle finishes its throw instead of being
	# deleted in mid-flight along with the wand's intention to have sprayed it.
	await _settle()
	await _press(_at_the_car())
	assert_true(_jet().is_spraying(), "spraying while the finger is down")
	await _lift()
	assert_false(_jet().is_spraying(), "and not once it is up")
	assert_true(_water().visible, "with the water in the air still drawn")
	assert_false(_water().local_coords, "and still where the wand left it")
	assert_false(_marker().is_marking(), "with nothing marked either")
