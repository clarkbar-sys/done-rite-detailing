## Integration test for what the power wash draws instead of a crosshair: the
## cone of water between its nozzle and the paint.
##
## [b]Why a suite of its own.[/b] [code]test_play_screen_aim.gd[/code] is about
## where the mark lands and [code]test_play_screen_wand.gd[/code] is about the
## line the wand lies on — both true of every press with any tool. This is about
## the one tool that answers "where am I pointed" with a volume rather than with
## a ring, and about the swap between the two sights, which is a rule no other
## suite has a reason to know exists.
##
## [b]What is measured and what deliberately is not.[/b] The cone's geometry is
## asserted off its own transform — where its tip is, where its far end lands,
## how wide it is there — because that is the part that can be silently wrong.
## Its colours and its opacity are read off the built mesh and material, since
## "blue at the nozzle, red on the paint, a third opaque" is the whole brief and
## a gradient that quietly came out grey would pass every geometric assertion
## here. What no test can say is whether it [i]looks[/i] right; that is what the
## thing is for.
##
## [b]Everything goes through a real press[/b], for [code]test_play_screen_wand
## .gd[/code]'s reason: the room only knows where the mark is because it cast a
## ray, and the cone is drawn to the mark. So the finger goes down for the length
## of each test and [method after_each] lifts it.
extends GutTest

const PLAY_SCREEN: String = "res://src/screens/play_screen.tscn"

## Above GUT's own output layer, so a finger aimed at the game lands on the game.
const ABOVE_THE_RUNNER: int = 200

## Close enough for positions in metres — a tenth of a millimetre.
const TOLERANCE: float = 0.0001

## How near the wand's nozzle the cone's tip has to sit, in metres.
##
## A centimetre rather than [constant TOLERANCE], and the slack is a clock
## rather than a fudge: the cone is placed on the physics tick from wherever the
## nozzle was then, and the nozzle is posed on the frame clock afterwards
## ([method ViewModel._process]). The two agree exactly on a shot that has
## stopped moving — measured at zero, repeatedly, which is what
## [method after_each] awaiting its own [method _lift] buys — and they disagree
## by however far one frame carries the eye on a machine still easing something.
## A centimetre absorbs that and is still a fiftieth of the cone's own width.
const ON_THE_NOZZLE: float = 0.01

## How near a vertex colour has to be to the constant it was written with.
##
## [method SurfaceTool.set_color] stores a vertex colour as four bytes, so the
## committed mesh reports [code]0.949[/code] for a [code]0.95[/code] that went
## in. One step of that quantisation is the honest tolerance: tight enough that
## the wrong colour fails, loose enough that the right one does not.
const QUANTISED: float = 1.0 / 255.0

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
	# moving, so that lands as "the cone is not on the nozzle" three tests later
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


## The mesh the cone is actually built out of, reached by the name [WashJet]
## gives it rather than by counting children.
func _cone() -> MeshInstance3D:
	return _jet().get_node(NodePath(WashJet.CONE)) as MeshInstance3D


## Where the water leaves the wand, read off the marker a particle system will
## one day be parented to.
func _nozzle() -> Vector3:
	return _view_model().muzzle().global_position


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


## How long the drawn cone is, tip to far end.
func _cone_length() -> float:
	return _jet().global_position.distance_to(_jet().landing())


## The vertex colours of the built cone, paired with the local points they sit
## on. Read off the committed mesh rather than off the constants, so a gradient
## that never made it into the geometry fails.
func _tinted(local_z: float) -> Array[Color]:
	var mesh: ArrayMesh = _cone().mesh as ArrayMesh
	var arrays: Array = mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var found: Array[Color] = []
	for index: int in points.size():
		if is_equal_approx(points[index].z, local_z):
			found.append(colours[index])
	return found


## The worst any of [param tints] is off [param wanted], as a single channel
## distance. One number so a whole ring of vertices is one assertion with a
## readable message, rather than seventy-two that all say the same thing.
func _off_tint(tints: Array[Color], wanted: Color) -> float:
	var worst: float = 0.0
	for tint: Color in tints:
		worst = maxf(worst, absf(tint.r - wanted.r))
		worst = maxf(worst, absf(tint.g - wanted.g))
		worst = maxf(worst, absf(tint.b - wanted.b))
		worst = maxf(worst, absf(tint.a - wanted.a))
	return worst


# ---- the cone the power wash draws -------------------------------------------


func test_the_power_wash_sprays_a_cone_instead_of_a_crosshair() -> void:
	# The swap itself. Both halves matter: a cone that appeared while the ring
	# stayed on the paint would be two answers to one question, which is the thing
	# this change exists to stop.
	await _settle()
	assert_false(_jet().is_spraying(), "nothing is spraying before the press")
	await _press(_at_the_car())
	assert_true(_jet().is_spraying(), "the power wash draws its jet")
	assert_false(_marker().is_crosshair_drawn(), "and the crosshair gets out of its way")
	assert_true(_marker().is_marking(), "while the mark itself is still made")


func test_the_cone_runs_from_the_nozzle_to_the_mark() -> void:
	# The geometry the whole thing rests on: tip at the wand's nozzle, axis down
	# the line to the crosshair, far end stopping just short of the paint. A cone
	# merely parallel to that line passes nothing here.
	await _settle()
	await _press(_at_the_car())
	assert_lt(_jet().global_position.distance_to(_nozzle()), ON_THE_NOZZLE, "tip on the nozzle")
	assert_almost_eq(
		_jet().landing().distance_to(_crosshair()),
		WashJet.PULLBACK,
		ON_THE_NOZZLE,
		"the far end stops a pullback short of the paint"
	)
	var along: Vector3 = _jet().global_position.direction_to(_jet().landing())
	assert_almost_eq(along.dot(_nozzle().direction_to(_crosshair())), 1.0, 0.001, "down the line")


func test_the_cone_lands_as_wide_as_the_water_it_stands_in_for() -> void:
	# What makes this a picture of the physics rather than a decoration: the disc
	# at the far end is [member Garage.wash_radius_metres] of paint, which is the
	# patch the trigger is taking mud off. The angle is asserted as well as the
	# width, because the width alone would pass for a cone that stopped short and
	# kept the radius — and the angle is what stays true as the player walks in.
	await _settle()
	await _press(_at_the_car())
	var radius: float = _garage().wash_radius_metres
	assert_almost_eq(_jet().spread(), radius, WashJet.PULLBACK, "as wide as the water lands")
	assert_almost_eq(
		_jet().spread() / _cone_length(),
		radius / _nozzle().distance_to(_crosshair()),
		0.001,
		"and at the angle that would put exactly that radius on the mark"
	)


func test_the_cone_is_blue_at_the_nozzle_red_at_the_paint_and_see_through() -> void:
	# The brief, read back off the mesh and the material. Every vertex at the apex
	# carries the pressure colour and every vertex on the base ring the spent one,
	# so the gradient is in the geometry; the opacity is one number on the shared
	# material and is the reason the car is still visible through all of this.
	var apex: Array[Color] = _tinted(0.0)
	var base: Array[Color] = _tinted(WashJet.FAR_END.z)
	assert_gt(apex.size(), 0, "the cone has an apex")
	assert_gt(base.size(), 0, "and a base ring")
	assert_lt(_off_tint(apex, WashJet.TIP), QUANTISED, "every vertex at the tip is blue")
	assert_lt(_off_tint(base, WashJet.SPRAY), QUANTISED, "and every one where it lands is red")
	assert_ne(WashJet.TIP, WashJet.SPRAY, "which are two colours and therefore a gradient")
	var water: StandardMaterial3D = _cone().material_override as StandardMaterial3D
	assert_almost_eq(water.albedo_color.a, WashJet.OPACITY, TOLERANCE, "a third opaque")
	assert_true(water.vertex_color_use_as_albedo, "so the gradient above is what gets drawn")


func test_the_cone_follows_the_mark_across_a_drag() -> void:
	# Two presses that mark different places, so a cone placed once and cached
	# cannot pass. The sky press is the interesting one: the ray misses the car
	# entirely and the mark snaps back onto the nearest bodywork, which is where
	# the water goes — so it is where the cone has to point too.
	await _settle()
	await _press(_at_the_car())
	var first: Vector3 = _jet().landing()
	await _lift()
	await _press(_at_the_sky())
	assert_gt(_jet().landing().distance_to(first), 0.1, "the cone went to the second mark")
	assert_almost_eq(
		_jet().landing().distance_to(_crosshair()),
		WashJet.PULLBACK,
		ON_THE_NOZZLE,
		"and reaches it"
	)


func test_another_tool_puts_the_crosshair_back_and_the_cone_away() -> void:
	# The other four tools are put on the car at a point, and a ring is the right
	# shape for that. Swapped mid-press on purpose: the sight is chosen from the
	# belt every tick, so it has to change without the finger being lifted first.
	await _settle()
	await _press(_at_the_car())
	assert_true(_jet().is_spraying(), "the washer was spraying to begin with")
	_view_model().belt().equip(DetailingTool.Id.SPONGE)
	await wait_physics_frames(RESOLVE_FRAMES)
	assert_false(_jet().is_spraying(), "a sponge does not spray")
	assert_true(_marker().is_crosshair_drawn(), "and gets the crosshair back")


func test_letting_go_stows_the_cone() -> void:
	# Holding the glass is firing and letting go is not — the same rule the mark
	# already follows, applied to the thing that replaced it.
	await _settle()
	await _press(_at_the_car())
	assert_true(_jet().is_spraying(), "spraying while the finger is down")
	await _lift()
	assert_false(_jet().is_spraying(), "and not once it is up")
	assert_false(_marker().is_marking(), "with nothing marked either")
