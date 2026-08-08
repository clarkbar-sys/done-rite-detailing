## Integration test for the middle tier of the aim: [AimSweep], the fan of rays
## the width of the held tool that catches a press which missed the car by a
## hair. It was a swept sphere when this suite was written and is a ray fan now —
## same window, same four answer keys, a hundredth of the cost ([AimSweep]'s
## class docs carry the change) — and nothing asserted here is about which
## engine call opens the window, which is why the suite survived the swap.
##
## [b]Through [code]main.tscn[/code], like the wash suite[/b] and for the same
## reason it records: a screen instanced on its own has nothing underneath it and
## the game has two full-rect [Control]s underneath it, so a suite that skips the
## real stack can pass while the feature does nothing whatsoever in the game.
##
## [b]What is asserted here and what deliberately is not.[/b] This suite is about
## the tier boundaries — that a near miss is now answered off real paint and can
## therefore be worked, that a distant press is still answered by the nearest
## panel and still cannot, and that a press on the car is still the exact ray it
## always was. How wide each tool's window is comes from [method Garage._reach_of]
## and is not restated; where the water lands in the texture is
## [code]tests/unit/test_box_projection.gd[/code]'s.
##
## [b]Every press proves it is the press it claims to be.[/b] A suite about the
## middle tier is worthless if its aims quietly start hitting the car outright, so
## the near-miss tests assert that the exact ray really did come back empty before
## asserting on what happened next. That is the same trap
## [code]test_play_screen_aim.gd[/code] fell into once with a sky press that had
## drifted off the top of the picture.
extends GutTest

const MAIN: String = "res://src/main/main.tscn"

## Above GUT's own output layer, so a finger aimed at the game lands on the game.
const ABOVE_THE_RUNNER: int = 200

## Long enough for the standoff to have eased out to the gap the walk wants, so
## every press below lands on a settled camera. Every screen coordinate here is
## computed after this rather than written down, because the eye moves more than a
## metre during it.
const SETTLE_FRAMES: int = 90

## Enough physics ticks for a press to have been resolved into a mark.
const RESOLVE_FRAMES: int = 4

## A second of held trigger, which at [member Garage.wash_per_second] is most of
## the way through the mud under the jet.
const WASH_FRAMES: int = 60

## How far above the roofline the near-miss presses aim, in metres.
##
## [b]A band, and every edge of it was measured against the settled shot rather
## than reasoned about.[/b] Re-measured across all ten styles for [code]#139[/code],
## because the bay no longer parks one blockout of one size — it draws one of ten
## cars that stand 1.04 m (sport) to 1.77 m (minivan) tall, and every edge below
## is a different number on each of them. Taken when the sweep was a sphere; a
## fan's outermost catch sits a shade inside a sphere's, so the marginal rows may
## drift by a ray's spacing, and the quarter-metre this suite actually presses at
## is chosen to be nowhere near either edge:
##
## [codeblock]
## 0.10  the exact ray already misses all ten
## 0.25  a 0.4 m sweep catches all ten, a 0.6 m sweep catches all ten,
##       and the press is 122 (minivan) to 206 (sport) px down the frame
## 0.40  a 0.4 m sweep still catches the three tallest
##       (minivan, offroad, pickup)
## 0.45  a 0.4 m sweep has lost all ten
## [/codeblock]
##
## A quarter of a metre is inside all of those with room on both sides, which is
## what makes it the press this suite is about — and [method _the_ray_missed]
## re-asserts the important edge on every use rather than trusting this table to
## stay true.
const NEAR_MISS_METRES: float = 0.25

## Where the presses that must [i]not[/i] be caught aim, as a fraction of the way
## across and down the picture: high up, and well off to one side of the car.
##
## [b]Not "N metres over the roofline", which is what this was until
## [code]#139[/code].[/b] A press straight over the middle of the car is the worst
## place in the frame to put this one, and the reason is
## [method Garage._nearest_on_the_car]: the fallback plants a post at the nearest
## point on the nearest panel's box and casts a second ray a tenth past it, so an
## aim that comes down the car's own centreline has a post directly over the roof
## and a probe that runs straight into it. That probe hitting is a mark off real
## paint with a real normal — which is a tool that works, and this test's whole
## subject is the branch where nothing real answers at all.
##
## The blockout hid it: one car, one shape, and 0.8 m over its roofline happened
## to clear the post as well as the sweep. Against the ten the bay parks now there
## is no height that works — measured across every style at the settled shot, the
## band where the exact ray, a [constant WIDE_ENOUGH] sphere and the fallback's own
## probe all decline [i]and[/i] the aim is still inside a 720-line frame is
## 0.80–0.95 m on a coupe and 0.60–0.75 m on a minivan, and those do not overlap.
## Aiming up and to the side removes the question instead of retuning it: the post
## is then a box corner out in open air, and the probe misses on all ten with the
## aim passing 1.88 m (compact) to 2.32 m (wagon) from the middle of the car.
##
## A fifth across and a seventh down, so the press is well inside the picture
## rather than hugging an edge a letterbox could crop. Measured there on all ten,
## with the swept sphere this tier was at the time: the exact ray misses, a 0.4 m
## sweep misses, a 0.6 m sweep misses, the probe misses — and a 1.2 m sphere did
## reach, which is what said this is a bounded margin and not an aim pointed at
## nothing. The fan answers only inside the sphere's window, so the misses hold
## a fortiori and [method _the_sweep_missed] re-asserts the one that matters.
const WELL_CLEAR_ACROSS: float = 0.2
const WELL_CLEAR_DOWN: float = 0.15

## A window far too small to bridge [constant NEAR_MISS_METRES], and one
## comfortably wide enough. Neither is any tool's real radius on purpose: what is
## being pinned is that the radius is the window, not what any particular tool's
## window happens to be this week.
const TOO_SMALL: float = 0.01
const WIDE_ENOUGH: float = 0.6

## Close enough for a position in metres — a tenth of a millimetre.
const TOLERANCE: float = 0.0001

var _main: Control = null
var _window_size_before: Vector2i = Vector2i.ZERO


func before_each() -> void:
	# A headless window is 64x64, which is smaller than one tap target. Put back
	# in after_each: every suite shares this window.
	var root: Window = get_tree().root
	_window_size_before = root.size
	root.size = root.content_scale_size
	var packed: PackedScene = load(MAIN) as PackedScene
	assert_not_null(packed, "could not load %s" % MAIN)
	if packed == null:
		return
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = ABOVE_THE_RUNNER
	add_child_autofree(layer)
	var main: Control = packed.instantiate() as Control
	_main = main
	layer.add_child(_main)
	await wait_process_frames(2)
	var title: GameScreen = _host().get_child(0) as GameScreen
	(title.get_node("%Start") as Button).pressed.emit()
	await wait_process_frames(2)
	# Start opens the menu; the menu's Play opens the game. Two presses rather
	# than one since #91 put a menu between the title card and the bay.
	var menu: GameScreen = _host().get_child(0) as GameScreen
	(menu.get_node("%Play") as Button).pressed.emit()
	await wait_process_frames(2)


func after_each() -> void:
	# A finger left on the glass is global state the next test would start with.
	_lift()
	get_tree().root.size = _window_size_before


func _host() -> Control:
	return _main.get_node("%ScreenHost") as Control


func _screen() -> GameScreen:
	return _host().get_child(0) as GameScreen


func _garage() -> Garage:
	return _screen().get_node("Garage") as Garage


func _camera() -> Camera3D:
	return _garage().get_node("%Camera") as Camera3D


func _view() -> SubViewport:
	return _garage().get_node("View") as SubViewport


func _car() -> Car:
	return _garage().get_node("%Car") as Car


func _grime() -> Grime:
	return _garage().grime()


func _marker() -> AimMarker:
	return _garage().aim_marker()


func _belt() -> ToolBelt:
	return _garage().view_model().belt()


func _space() -> PhysicsDirectSpaceState3D:
	return _camera().get_world_3d().direct_space_state


func _on_screen(point: Vector3) -> Vector2:
	return _camera().unproject_position(point)


## The middle of the car, on the glass — the press that must always be the exact
## ray's to answer.
func _at_the_car() -> Vector2:
	return _on_screen(_car().global_position)


## A point [param above] metres over the middle of the roofline, on the glass.
##
## Measured off the car's own bounding box rather than written down as a pixel
## offset, for the reason every other suite in this directory gives: the standoff
## eases the eye more than a metre back during [method _settle], and a hard-coded
## coordinate that cleared the roof before that is on the bodywork after it.
func _over_the_roof(above: float) -> Vector2:
	var middle: Vector3 = _car().global_position
	var at: Vector2 = _on_screen(Vector3(middle.x, _car().bounds().end.y + above, middle.z))
	assert_true(
		Rect2(Vector2.ZERO, Vector2(_view().size)).has_point(at),
		"the press at %v is off the picture and would not be a press at all" % at
	)
	return at


## Where a press aims when it is plainly not pointing at the car —
## [constant WELL_CLEAR_ACROSS] across and [constant WELL_CLEAR_DOWN] down the
## picture, which is up in the sky and off to one side of it.
##
## Taken off the frame rather than off the car, unlike [method _over_the_roof],
## and that is the point rather than an inconsistency: a near miss is a distance
## from the bodywork and has to be measured off it, while this press is defined by
## being nowhere near the car at all. The car is in the middle of the picture on
## every one of the ten styles, so a corner of the frame is clear of all of them
## without having to know which one was drawn. [method _the_sweep_missed] and
## [method _the_post_missed] assert that on every use.
func _well_clear_of_the_car() -> Vector2:
	var frame: Vector2 = Vector2(_view().size)
	return Vector2(frame.x * WELL_CLEAR_ACROSS, frame.y * WELL_CLEAR_DOWN)


## The world ray a press aiming at [param at] casts, as an origin and a direction
## — the same two the room works out in [method Garage._resolve_aim].
func _ray_through(at: Vector2) -> Array[Vector3]:
	return [_camera().project_ray_origin(at), _camera().project_ray_normal(at)]


## Asserts that the exact ray through [param at] hits nothing, and hands the ray
## back so the caller can sweep the same line.
##
## [b]Every near-miss test starts here.[/b] The whole subject of this suite is
## what happens after the first tier comes back empty, so a test whose aim had
## quietly drifted onto the bodywork would go on passing while testing the tier
## above the one it names.
func _the_ray_missed(at: Vector2) -> Array[Vector3]:
	var ray: Array[Vector3] = _ray_through(at)
	var hit: Dictionary = _space().intersect_ray(
		PhysicsRayQueryParameters3D.create(ray[0], ray[0] + ray[1] * _garage().aim_reach)
	)
	assert_true(hit.is_empty(), "the press at %v hit the car outright and is not a near miss" % at)
	return ray


## Asserts that not even a [constant WIDE_ENOUGH] window down the aim at
## [param at] reaches the car — the other half of [method _the_ray_missed], for
## the presses that are supposed to fall all the way through to the bottom tier.
##
## Without it, a test named for the fallback goes on passing after somebody widens
## a tool far enough for the sweep to answer instead, and the assertion it makes
## about spending no water would then be reporting a real regression as a pass.
func _the_sweep_missed(at: Vector2) -> void:
	var ray: Array[Vector3] = _the_ray_missed(at)
	var sweep: AimSweep = AimSweep.new(_garage().aim_reach)
	assert_true(
		sweep.onto(_space(), ray[0], ray[1], WIDE_ENOUGH).is_empty(),
		(
			"a %s m window reached the car from %v, so this is not the fallback's press"
			% [WIDE_ENOUGH, at]
		)
	)


## Asserts that the nearest-panel fallback has nothing real to rest on either at
## [param at] — the third and last thing that has to be true for a press to reach
## the one answer in the whole room that is allowed to be approximate.
##
## [b]The tier below the two above, restated the way they are.[/b]
## [method Garage._nearest_on_the_car] does not simply hand back a box corner: it
## plants a post at the nearest point on the nearest panel's box and casts a
## second ray a [constant Garage.PAST_THE_POST] fraction past it, and if that
## finds paint the mark is real, the normal is measured and a tool pressed there
## works. Only when the probe misses too is the mark the invented one this test is
## named for.
##
## Without this the test asserts "no water" against a press that three tiers deep
## might still be answered off real geometry — which is exactly how it broke on
## the car pack, silently, on whichever of the ten styles the room happened to
## draw.
func _the_post_missed(at: Vector2) -> void:
	var ray: Array[Vector3] = _ray_through(at)
	var boxes: Array[AABB] = []
	for panel: Node3D in _car().panels():
		var skin: GeometryInstance3D = _car().skin_of(panel)
		boxes.append(skin.global_transform * skin.get_aabb())
	var nearest: int = NearestPoint.nearest_box(boxes, ray[0], ray[1])
	assert_gte(nearest, 0, "the fallback found no panel at all to be nearest to")
	if nearest < 0:
		return
	var post: Vector3 = NearestPoint.in_box_from_ray(boxes[nearest], ray[0], ray[1])
	var reach: Vector3 = post - ray[0]
	var probe: Dictionary = _space().intersect_ray(
		PhysicsRayQueryParameters3D.create(ray[0], ray[0] + reach * Garage.PAST_THE_POST)
	)
	assert_true(
		probe.is_empty(),
		"the fallback's own probe reached the car from %v, so this mark is real paint" % at
	)


## [constant ThumbLift.REFERENCE_PX] in this window's design pixels, read the same
## way the screen reads it rather than written down.
func _lift_px() -> float:
	return ThumbLift.design_lift(
		get_tree().root.get_final_transform().get_scale().y, DisplayServer.screen_get_scale()
	)


## Where a thumb has to be to aim at [param aim] — the inverse of
## [method ThumbLift.raised], both of its branches.
##
## Every press below goes through here, which is what keeps this suite about the
## tiers rather than about the offset: the helpers above answer "where is the roof
## on the glass", and the touch that asks about it is a thumb's width lower down.
func _thumb_for(aim: Vector2) -> Vector2:
	var lift: float = _lift_px()
	var down: float = aim.y + lift
	if aim.y < lift:
		down = sqrt(4.0 * lift * maxf(aim.y, 0.0))
	var thumb: Vector2 = Vector2(aim.x, down)
	assert_almost_eq(
		ThumbLift.aim_from(thumb, lift).y, maxf(aim.y, 0.0), 0.01, "a thumb at %v aims back" % thumb
	)
	return thumb


func _touch(at: Vector2, pressed: bool) -> void:
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.position = at
	touch.pressed = pressed
	Input.parse_input_event(touch)
	Input.flush_buffered_events()


## Holds the trigger so that the aim lands at [param at] for a second, without
## letting go — so a test can still ask what is marked. [method after_each] lifts
## it.
func _press(at: Vector2) -> void:
	_touch(_thumb_for(at), true)
	await wait_physics_frames(WASH_FRAMES)


## Slides the aiming finger to [param at] without letting go — an
## [InputEventScreenDrag] on the same index [method _touch] presses with, which is
## what [method PlayScreen._finger_dragged] routes to [method Garage.aim_at].
##
## [b]A drag and not a second press[/b], because a second press is not what a
## sliding thumb produces and the play screen would ignore it anyway: the first
## finger down claims the aim and holds it until it lifts, so a fresh
## [InputEventScreenTouch] arriving while one is down goes nowhere. Anything
## testing what happens to a held press when the aim moves has to move it this way.
func _drag(at: Vector2) -> void:
	var dragged: InputEventScreenDrag = InputEventScreenDrag.new()
	dragged.position = _thumb_for(at)
	Input.parse_input_event(dragged)
	Input.flush_buffered_events()
	await wait_physics_frames(RESOLVE_FRAMES)


func _lift() -> void:
	_touch(Vector2.ZERO, false)
	await wait_physics_frames(RESOLVE_FRAMES)


func _settle() -> void:
	await wait_physics_frames(SETTLE_FRAMES)


## Whether [param who] is one of the car's own panels, asked of the car rather
## than by name — so this keeps meaning the same thing after somebody adds a wing.
func _is_a_panel(who: Object) -> bool:
	for panel: Node3D in _car().panels():
		if panel == who:
			return true
	return false


# ---- the sweep on its own ----------------------------------------------------


func test_a_tool_wide_fan_at_a_near_miss_lands_on_a_real_panel() -> void:
	# The class's whole claim, against the real car rather than a fixture: where a
	# zero-width ray found nothing, a fan the width of a tool finds a named
	# panel, a point on it, and a normal that was measured rather than invented.
	await _settle()
	var ray: Array[Vector3] = _the_ray_missed(_over_the_roof(NEAR_MISS_METRES))
	var sweep: AimSweep = AimSweep.new(_garage().aim_reach)
	var found: Dictionary = sweep.onto(_space(), ray[0], ray[1], WIDE_ENOUGH)
	assert_false(found.is_empty(), "a %s m fan down the same line found nothing" % WIDE_ENOUGH)
	if found.is_empty():
		return
	var who: Object = found["collider"]
	assert_true(_is_a_panel(who), "the sweep rested on %s, which is not a panel of the car" % who)
	var real: bool = found["surface"]
	assert_true(real, "a swept hit is real geometry and has to say so")


func test_the_swept_answer_carries_the_panels_own_normal_and_not_an_invented_one() -> void:
	# The entire reason this tier exists. The bottom tier can only face its point
	# at the player, and [BoxProjection] fed that picks a face off a measurement
	# nobody took — so what has to be true here is that the normal points out of
	# the car and belongs to the surface the point is on.
	#
	# Checked by stepping off the surface and casting back into it rather than by
	# comparing against a number: a ray from just outside the paint, aimed back
	# down the normal, has to find the same panel again. That is convention-proof
	# in a way "the normal is roughly (0, 1, 0)" would not be.
	await _settle()
	var ray: Array[Vector3] = _the_ray_missed(_over_the_roof(NEAR_MISS_METRES))
	var sweep: AimSweep = AimSweep.new(_garage().aim_reach)
	var found: Dictionary = sweep.onto(_space(), ray[0], ray[1], WIDE_ENOUGH)
	assert_false(found.is_empty(), "no swept hit to read a normal off")
	if found.is_empty():
		return
	var point: Vector3 = found["position"]
	var outward: Vector3 = found["normal"]
	assert_almost_eq(outward.length(), 1.0, 0.001, "the normal is not a unit vector")
	var back: Dictionary = _space().intersect_ray(
		PhysicsRayQueryParameters3D.create(point + outward * 0.05, point - outward * 0.05)
	)
	assert_false(back.is_empty(), "stepping off the normal and casting back reached no car at all")
	if back.is_empty():
		return
	var again: Object = back["collider"]
	var swept: Object = found["collider"]
	assert_eq(again, swept, "the normal points out of a different panel than the point")


func test_the_window_is_the_radius_it_is_given() -> void:
	# The rule [method Garage._reach_of] relies on: how forgiving the aim is *is*
	# the radius handed over, so a wider tool really does forgive a wider miss.
	# Two radii on one line, and the line is one the exact ray already failed.
	await _settle()
	var ray: Array[Vector3] = _the_ray_missed(_over_the_roof(NEAR_MISS_METRES))
	var sweep: AimSweep = AimSweep.new(_garage().aim_reach)
	assert_true(
		sweep.onto(_space(), ray[0], ray[1], TOO_SMALL).is_empty(),
		"a %s m window bridged a %s m miss" % [TOO_SMALL, NEAR_MISS_METRES]
	)
	assert_false(
		sweep.onto(_space(), ray[0], ray[1], WIDE_ENOUGH).is_empty(),
		"a %s m window did not bridge a %s m miss" % [WIDE_ENOUGH, NEAR_MISS_METRES]
	)


func test_a_sweep_with_no_width_is_refused_rather_than_cast() -> void:
	# A fan of no width is the ray that has already missed. Refusing it is what
	# stops a misconfigured reach silently buying back the old behaviour instead of
	# failing in a way somebody would notice.
	await _settle()
	var ray: Array[Vector3] = _the_ray_missed(_over_the_roof(NEAR_MISS_METRES))
	var sweep: AimSweep = AimSweep.new(_garage().aim_reach)
	assert_true(sweep.onto(_space(), ray[0], ray[1], 0.0).is_empty(), "a fan of nothing hit")


func test_a_sweep_at_the_open_sky_finds_nothing_to_rest_on() -> void:
	# The bound that makes this tier safe to put above the nearest-panel fallback:
	# it answers only when there is something within a tool's width, so a press
	# with no car anywhere near it falls through rather than being snapped.
	await _settle()
	var sweep: AimSweep = AimSweep.new(_garage().aim_reach)
	var eye: Vector3 = _camera().global_position
	assert_true(sweep.onto(_space(), eye, Vector3.UP, WIDE_ENOUGH).is_empty(), "the sky was solid")


# ---- what it changes about a press -------------------------------------------


func test_a_press_that_just_clears_the_roof_now_washes_it() -> void:
	# The headline, end to end through the real scene stack. This press used to be
	# answered by a point clamped onto a bounding box, which the trigger refuses —
	# so the water and the mist were drawn on the mark and the mud never moved. A
	# tool that visibly runs and cleans nothing is the failure this tier removes.
	await _settle()
	assert_eq(_belt().equipped().id, DetailingTool.Id.POWER_WASH, "the wash is what you start with")
	var at: Vector2 = _over_the_roof(NEAR_MISS_METRES)
	_the_ray_missed(at)
	await _press(at)
	assert_true(_marker().is_marking(), "the press marked nothing at all")
	assert_lt(_grime().remaining(), 1.0, "a second of water on a near miss moved no mud")


func test_a_press_well_clear_of_the_car_is_still_the_nearest_panel_and_still_dry() -> void:
	# The tier below, unchanged and deliberately so. A press up in the sky and off
	# to one side is far outside any tool's window, so the sweep declines, and it
	# is far enough off the car's centreline that the fallback's own probe declines
	# too — leaving a box corner faced at the player. A mark, because "nothing" is
	# not a useful thing to mark, and no water, because that normal was invented.
	await _settle()
	var at: Vector2 = _well_clear_of_the_car()
	_the_sweep_missed(at)
	_the_post_missed(at)
	await _press(at)
	assert_true(_marker().is_marking(), "the press still marks the nearest bodywork")
	assert_almost_eq(_grime().remaining(), 1.0, TOLERANCE, "a box corner spent water")


func test_a_press_on_the_car_is_still_answered_by_the_exact_ray() -> void:
	# The tier above, unchanged and also deliberately so. A swept sphere stops at
	# the first thing it touches, which at a grazing angle is not what the player
	# pointed at — so the common press has to go on being answered exactly.
	#
	# [b]Asserted as "the mark is on the line" rather than "the mark is at this
	# point".[/b] The exact ray's answer lies on the aim by construction; a swept
	# answer rests a whole radius off it, which is two orders of magnitude further
	# than the slack below. Comparing against a raycast position taken before the
	# press would instead be comparing two different ticks of a camera the standoff
	# is still allowed to nudge, and would fail for that rather than for this.
	await _settle()
	var at: Vector2 = _at_the_car()
	await _press(at)
	assert_true(_marker().is_marking(), "the press at the middle of the car marked nothing")
	var ray: Array[Vector3] = _ray_through(at)
	var mark: Vector3 = _marker().marked_point()
	var off_the_line: float = mark.distance_to(NearestPoint.on_ray(ray[0], ray[1], mark))
	assert_lt(
		off_the_line, 0.01, "the mark sits %s m off the aim, so a sweep answered" % off_the_line
	)


# ---- and the aim that moves under a finger that never lifts -------------------


func test_an_aim_that_slides_off_the_car_stops_working_the_paint() -> void:
	# [b]The guard on [code]#145[/code].[/b] The middle tier is no longer cast on
	# every physics tick: [AimHold] keeps what the last sweep down this aim found
	# and hands it back until the aim moves, which turned a held press from sixty
	# sweeps a second into one — four milliseconds each, back when the tier was a
	# swept sphere, and worth holding at any price. The whole risk of that is an answer
	# that outlives its question — the water going on landing where the player used
	# to be pointing — and this is the test that fails when it does.
	#
	# [b]Stated as "does the water move" rather than as "where is the mark".[/b] A
	# stale mark is not a cosmetic bug; it is the trigger being spent on paint
	# nobody is aiming at, which is the thing a player would actually see. It is
	# also the only reading that separates the tiers cleanly here — measured, a
	# fresh sweep and the fallback's own probe put the mark 0.35 m and 0.25 m off
	# the aim respectively, and a tenth of a metre is far too fine a line to hang a
	# suite on.
	#
	# [b]The press is only held long enough to take one sweep before it moves on[/b],
	# rather than washing for a second first. Both orders catch the bug and only one
	# of them catches it loudly: a spot that has already had a second of water on it
	# has almost no mud left to lose, so the same regression shows up as a couple of
	# ten-thousandths instead of as a visible hole in the roof.
	await _settle()
	var near: Vector2 = _over_the_roof(NEAR_MISS_METRES)
	_the_ray_missed(near)
	_touch(_thumb_for(near), true)
	await wait_physics_frames(RESOLVE_FRAMES)
	assert_true(_marker().is_marking(), "the near miss marked nothing, so nothing was swept")
	var washed: float = _grime().remaining()
	assert_lt(washed, 1.0, "the near miss moved no mud, so there is nothing here to stop")
	# Up in the sky and off to one side: far outside any tool's window, and far
	# enough off the centreline that the fallback's own probe declines too — so the
	# only thing left out there is a box corner with an invented normal, which the
	# trigger refuses. Both of those are asserted rather than assumed, because this
	# test means nothing if the new aim is one that can be worked anyway.
	var away: Vector2 = _well_clear_of_the_car()
	_the_sweep_missed(away)
	_the_post_missed(away)
	await _drag(away)
	await wait_physics_frames(WASH_FRAMES)
	assert_almost_eq(
		_grime().remaining(),
		washed,
		TOLERANCE,
		"the jet went on washing the roofline for a second after the aim had left it"
	)
