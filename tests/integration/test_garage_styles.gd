## Integration test for the shot, held against the cars that are least like the
## one it was framed on.
##
## [b]Why this suite exists.[/b] Every clearance in [code]src/world/garage.gd[/code]
## — where the eye stands, how far the standoff holds it off the paint, how much
## room a held tool has to swing in, what a portrait phone's lens has to take in
## — was chosen against a blockout that was 4.3 × 1.9 × 1.4 m and stayed that size
## forever. [code]#139[/code] parked a [MeshCar] there instead, and a mesh car is
## one of ten: 3.26 m of compact to 5.19 m of pickup, 1.04 m of sport car to
## 1.77 m of minivan, and a pickup is 2.07 m across where the blockout was 1.9 m.
## A shot that only works on the middle of that range is a shot that is broken
## one time in five, on a screen nobody can reproduce because the style is drawn
## at random.
##
## [b]So the style is chosen here, and that is the only thing this suite does that
## the game does not.[/b] [member MeshCar.style] is an export read in
## [method Node._ready], so setting it on the instantiated scene before it is
## added to the tree is enough — no test hook, no second code path, and the car
## that comes out is the car the game would have built if the draw had gone that
## way. [code]tests/integration/test_mesh_car.gd[/code] has the argument for the
## export itself.
##
## [b]What is deliberately not repeated here.[/b] The other play-screen suites
## cover the shot in depth on whichever car the room happened to draw — the walk
## over a whole lap, the lens on a phone, every tool against every surface. This
## one takes the handful of properties that could plausibly depend on how big the
## car is, and holds them at both ends of the range. It is a breadth test standing
## behind depth tests, not a copy of them.
##
## [b]Everything is measured against [method Car.bounds][/b] and never against a
## written-down size, which is the same rule the suites it stands behind follow.
## The blockout's mirrors were the widest thing on it and no car in the pack has
## any, so a test that assumed a number would now be asserting something about a
## file in [code]tests/fixtures/[/code].
extends GutTest

const PLAY_SCREEN: String = "res://src/screens/play_screen.tscn"

## The four cars this suite is about, and which extreme each of them is. Between
## them they hold every corner of the range the ten styles span — read off the
## pack itself in [code]tests/integration/test_mesh_car.gd[/code], which is what
## fails if a rebuild moves them.
##
## [codeblock]
## pickup    5.19 m long and 2.07 m wide — the biggest car in the pack
## minivan   1.77 m tall                 — the tallest roof
## sport     1.04 m tall                 — the lowest, and the one a standing
##                                         eye looks furthest down at
## compact   3.26 m long, 1.61 m wide    — the smallest car in the pack
## [/codeblock]
##
## Four and not ten, because the properties below are monotonic in the car's size
## and the middle six are all inside these: the pickup is the worst case for
## anything about reach and framing, the compact for anything about the eye
## standing too far back, and the sport and the minivan for anything about height.
## Ten would be two and a half times the settling for no case the four do not
## already bracket.
const EXTREMES: Array[String] = ["pickup", "minivan", "sport", "compact"]

## The furthest the eye may be from the car's own bodywork and still count as
## having walked up to it — the same number
## [code]tests/integration/test_play_screen.gd[/code] holds the parked shot to,
## and the point of repeating it here is that it has to hold for a car of any
## size rather than for the one that was drawn.
const REACHED_THE_CAR: float = 3.0

## How far a held thing may stick out from the anchor in any direction. Half the
## longest tool on the belt (the power wash wand, 0.72 m) plus room to spare.
## Again the same number the parked shot and the whole walk are held to.
const HELD_REACH: float = 0.45

## Long enough for the standoff to have eased from where the standing shot puts
## the eye out to the gap the walk wants — a metre and a quarter of dolly at the
## speed the scene exports, which is about fifty ticks. A second and a half.
const SETTLE_FRAMES: int = 90

## Enough physics ticks for a press to have been resolved into a mark.
const RESOLVE_FRAMES: int = 4

## Enough frames for a resize to have reached the container, the sub-viewport and
## the camera. It is a signal chain, not a poll.
const RESIZE_FRAMES: int = 5

## A Pixel 7 in a portrait browser, doubled so a headless window will accept it —
## [code]tests/integration/test_play_screen_lens.gd[/code] has why, and asserts
## that this really does land on the viewport a phone gets.
const PORTRAIT: Vector2i = Vector2i(822, 1676)

## The most vertical field of view a shot is allowed, in degrees, plus a hair for
## floating point. [member Lens.max_vertical_fov_degrees] is the ceiling itself;
## this is what a test compares against, so a lens that stopped being fitted at
## all fails rather than passing by a rounding error.
const FISHEYE: float = 70.05

## How much of the frame's height the car has to cover on a phone held upright.
##
## Not a design target — a floor, and a low one. The lens fit exists because the
## design lens put the car at 22.5% of a portrait frame; a third is comfortably
## past that and comfortably under what even the compact manages, so what this
## catches is a fit that stopped happening rather than a shot that got a little
## looser. [code]test_play_screen_lens.gd[/code] holds the fit itself.
const FILLS_THE_PHONE: float = 0.33

var _window_size_before: Vector2i = Vector2i.ZERO


func before_each() -> void:
	# A headless window is 64x64, which is smaller than one tap target and makes
	# every screen coordinate below meaningless. `content_scale_size` is the design
	# resolution from project.godot. Put back in after_each: every suite shares
	# this window.
	var root: Window = get_tree().root
	_window_size_before = root.size
	root.size = root.content_scale_size
	await wait_process_frames(RESIZE_FRAMES)


func after_each() -> void:
	# A finger left on the glass and a window left portrait are both global state,
	# and either one would land on whichever test runs next rather than on this
	# one.
	_touch(Vector2.ZERO, false)
	await wait_physics_frames(RESOLVE_FRAMES)
	get_tree().root.size = _window_size_before


## A play screen with [param style] parked in its bay, ready to be measured.
##
## The style is set on the instantiated scene before it enters the tree, which is
## the whole of the arrangement: [method MeshCar._ready] reads the export and
## builds that car, so by the time [code]add_child[/code] returns the room has
## already parked, aimed and stood in front of the car this test asked for.
##
## Not settled — the tests that need a settled camera say so, and the ones about
## where the car is sat would rather not spend ninety ticks each finding out.
func _screen_of(style: String) -> GameScreen:
	var packed: PackedScene = load(PLAY_SCREEN) as PackedScene
	assert_not_null(packed, "could not load %s" % PLAY_SCREEN)
	if packed == null:
		return null
	var screen: GameScreen = packed.instantiate() as GameScreen
	var car: MeshCar = _car_of(screen) as MeshCar
	assert_not_null(car, "the bay must park a MeshCar for a style to mean anything")
	if car != null:
		car.style = style
	add_child_autofree(screen)
	return screen


## The room inside [param screen].
func _garage_of(screen: GameScreen) -> Garage:
	return screen.get_node("Garage") as Garage


## The car inside [param screen]. Reached through the garage rather than off the
## screen because a `%Name` is unique within the scene that owns it, and the car
## belongs to the room rather than to the screen the room was instanced into.
func _car_of(screen: GameScreen) -> Car:
	return _garage_of(screen).get_node("%Car") as Car


## Typed as [Lens] rather than [Camera3D]: the ceiling the phone test reads is
## that script's export.
func _lens_of(screen: GameScreen) -> Lens:
	return _garage_of(screen).get_node("%Camera") as Lens


func _view_model_of(screen: GameScreen) -> Node3D:
	return _garage_of(screen).get_node("%ViewModel") as Node3D


## The ground the room is standing on, which is a mesh and knows its own size.
func _ground_of(screen: GameScreen) -> Ground:
	return _garage_of(screen).get_node("%Ground") as Ground


## How far the car is from the outer edge of the modeled ground, read off the
## ground itself rather than written down again here. The narrower of its two
## sides, since what hangs off this is an absolute value.
func _ground_half_width(screen: GameScreen) -> float:
	var box: AABB = _ground_of(screen).extent()
	return minf(absf(box.position.x), box.end.x)


## Where the top of the driveway is, read off the driveway. The room is allowed to
## move and this suite is a statement about the car and the floor together.
func _tarmac(screen: GameScreen) -> float:
	return _ground_of(screen).drive().end.y


## The gap between [param point] and the nearest face of [param box], and zero if
## the point is inside it. Per axis rather than centre-to-centre, which for a
## five-metre car is off by metres.
func _clearance(box: AABB, point: Vector3) -> float:
	var low: Vector3 = box.position - point
	var high: Vector3 = point - box.end
	var gap: Vector3 = Vector3(
		maxf(maxf(low.x, high.x), 0.0),
		maxf(maxf(low.y, high.y), 0.0),
		maxf(maxf(low.z, high.z), 0.0)
	)
	return gap.length()


## How much of the frame's height the car's box covers, as a fraction — the eight
## corners of the box, projected, top to bottom.
func _car_height_fraction(screen: GameScreen) -> float:
	var lens: Lens = _lens_of(screen)
	var frame: Vector2 = lens.get_viewport().get_visible_rect().size
	var box: AABB = _car_of(screen).bounds()
	var low: float = INF
	var high: float = -INF
	for corner: int in range(8):
		var at: Vector2 = lens.unproject_position(box.get_endpoint(corner))
		low = minf(low, at.y)
		high = maxf(high, at.y)
	return (high - low) / frame.y


func _touch(at: Vector2, pressed: bool) -> void:
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.position = at
	touch.pressed = pressed
	Input.parse_input_event(touch)
	Input.flush_buffered_events()


func test_every_extreme_style_is_sat_on_the_tarmac() -> void:
	# The one thing the swap could not inherit from the blockout. Every car in the
	# pack is authored about its own mid-height, so where the origin goes is half
	# the car's height — and half a car's height is a different number for each of
	# the ten. The scene file used to carry 0.7, which was right for a 1.4 m
	# blockout and is 18 cm wrong at either end of this list.
	#
	# Both directions in one assertion, because both are real: too low is a wheel
	# through the drive and too high is a car hovering over it, and a fixed lift
	# does one to the minivan and the other to the sport car.
	for style: String in EXTREMES:
		var screen: GameScreen = _screen_of(style)
		var box: AABB = _car_of(screen).bounds()
		assert_almost_eq(
			box.position.y, _tarmac(screen), 0.001, "the %s is not on the drive" % style
		)


func test_the_eye_walks_up_to_every_extreme_without_standing_in_it() -> void:
	# The shot, at both ends of the range: near enough that the car fills the
	# frame, and not so near that the eye is inside the bodywork. The standoff is
	# what makes those compatible — it holds a gap to the paint rather than a
	# radius around the middle — so the pickup, which is 90 cm longer than the
	# blockout the number was chosen on, has to come out no worse than the compact,
	# which is a metre shorter.
	for style: String in EXTREMES:
		var screen: GameScreen = _screen_of(style)
		await wait_physics_frames(SETTLE_FRAMES)
		var box: AABB = _car_of(screen).bounds()
		var eye: Vector3 = _lens_of(screen).global_position
		assert_lt(_clearance(box, eye), REACHED_THE_CAR, "the %s does not fill the frame" % style)
		assert_false(box.has_point(eye), "the eye is standing inside the %s" % style)
		assert_lt(absf(eye.x), _ground_half_width(screen), "walked off the drive at the %s" % style)
		assert_gt(eye.y, _tarmac(screen), "the eye is under the drive at the %s" % style)


func test_a_held_tool_clears_the_bodywork_on_every_extreme() -> void:
	# The clipping decision recorded in `src/world/garage.gd`: the viewmodel has no
	# camera of its own, so it lives or dies by there being room between the eye
	# and the paint for the length of a wand. That budget is what
	# `Garage.standoff_metres` was widened to buy, and it was bought against a
	# 1.9 m blockout — the pickup and the SUV are 2.07 m across, which is 9 cm of
	# it spent before anybody has walked anywhere.
	#
	# The anchor rather than the tool: what hangs off it is `test_view_model.gd`'s
	# subject and it measures every proxy corner. What is held here is the promise
	# the anchor makes on behalf of all of them.
	for style: String in EXTREMES:
		var screen: GameScreen = _screen_of(style)
		await wait_physics_frames(SETTLE_FRAMES)
		var box: AABB = _car_of(screen).bounds()
		var anchor: Vector3 = _view_model_of(screen).global_position
		assert_gt(_clearance(box, anchor), HELD_REACH, "a held tool is inside the %s" % style)


func test_the_standoff_finds_a_flank_on_every_extreme() -> void:
	# What the whole walk is steered by, and the reason the car's origin is at its
	# mid-height rather than on the floor: a level ray through the car's own middle
	# has to meet a vertical face on every style, from every eye height. It is a
	# door skin on all ten — above the sill, below the glass — and a car whose
	# greenhouse reached down to its own middle would put the standoff on a raked
	# windscreen and measure a gap that changes with the weather.
	#
	# Cast the way `Garage._hold_the_standoff` casts it: level, at the car's own
	# mid-height, in at the middle of the car.
	for style: String in EXTREMES:
		var screen: GameScreen = _screen_of(style)
		await wait_physics_frames(1)
		var car: Car = _car_of(screen)
		var focus: Vector3 = car.global_position
		var probe: Vector3 = focus + Vector3(4.0, 0.0, 0.0)
		var space: PhysicsDirectSpaceState3D = _lens_of(screen).get_world_3d().direct_space_state
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(probe, focus))
		assert_false(hit.is_empty(), "a level ray missed the %s entirely" % style)
		if hit.is_empty():
			continue
		# Through an Object first: a Dictionary hands back Variant, and this
		# project's warning levels treat casting one straight to a node as unsafe
		# rather than as a cast.
		var struck: Object = hit["collider"]
		var panel: Node3D = struck as Node3D
		assert_true(car.panels().has(panel), "the %s's flank is not one of its panels" % style)
		assert_eq(panel.name, &"Body", "the ray met something other than the %s's flank" % style)


func test_a_press_in_the_middle_of_every_extreme_lands_on_real_bodywork() -> void:
	# Tool reach, through the door a thumb uses. The aim is taken a thumb's width
	# above the finger ([ThumbLift] has why), which on a low car sends the ray over
	# the roof and on a tall one leaves it well inside the flank — so the press
	# that must always land is the interesting one at both ends of this list, and
	# the sport car at 1.04 m is the case that made it interesting.
	#
	# `surface` is the key that matters. Every tier of `Garage._under_the_finger`
	# answers something, and the bottom one answers with a point clamped onto a
	# bounding box whose normal was invented facing the player — a mark a player
	# can see and no tool may write to. So "the press landed on the car" is not the
	# question; "the press landed on the car's own geometry" is.
	for style: String in EXTREMES:
		var screen: GameScreen = _screen_of(style)
		await wait_physics_frames(SETTLE_FRAMES)
		var garage: Garage = _garage_of(screen)
		var car: Car = _car_of(screen)
		_touch(_lens_of(screen).unproject_position(car.global_position), true)
		await wait_physics_frames(RESOLVE_FRAMES)
		var marker: AimMarker = garage.aim_marker()
		assert_true(marker.is_marking(), "a press at the middle of the %s marked nothing" % style)
		var mark: Vector3 = marker.marked_point()
		assert_lt(
			_clearance(car.bounds(), mark), 0.001, "the mark on the %s is off the car" % style
		)
		_touch(Vector2.ZERO, false)
		await wait_physics_frames(RESOLVE_FRAMES)


func test_a_phone_held_upright_still_frames_every_extreme() -> void:
	# The lens, which is the one part of the shot that does not move with the car:
	# `Lens` narrows the horizontal angle until the vertical fits under its ceiling,
	# and how much car that takes in then depends entirely on how big the car is.
	# The compact is the case — 3.26 m long and 1.61 m wide against a blockout that
	# was 4.3 by 1.9 — because it is the one that could end up sitting in the
	# middle of a tall frame rather than filling it.
	#
	# Both halves, because either alone passes for the wrong reason: a lens that
	# stopped being fitted would still frame a car (badly), and a car walked far
	# too close would fill the frame through a fisheye.
	for style: String in EXTREMES:
		var screen: GameScreen = _screen_of(style)
		await wait_physics_frames(SETTLE_FRAMES)
		get_tree().root.size = PORTRAIT
		await wait_process_frames(RESIZE_FRAMES)
		var lens: Lens = _lens_of(screen)
		var frame: Vector2 = lens.get_viewport().get_visible_rect().size
		assert_lt(
			LensFit.vertical_fov(lens.fov, frame.x / frame.y),
			FISHEYE,
			"the %s is seen through a fisheye on a phone" % style
		)
		assert_gt(
			_car_height_fraction(screen),
			FILLS_THE_PHONE,
			"the %s is parked across the frame rather than filling it" % style
		)
		get_tree().root.size = _window_size_before
		await wait_process_frames(RESIZE_FRAMES)
