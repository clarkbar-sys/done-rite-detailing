## Integration test for the trigger doing something: a held press with the power
## wash in hand takes mud off the car.
##
## [b]Through [code]main.tscn[/code], like [code]test_play_screen_trigger.gd[/code][/b]
## and for the same reason — a screen instanced on its own has nothing underneath
## it and the game has two full-rect [Control]s underneath it, so a suite that
## skips the real stack can pass while the feature does nothing whatsoever in the
## game. That has already happened once here; the trigger suite's class docs
## record it.
##
## What is asserted is the wiring and the rules, not the arithmetic: that water
## reaches the paint at all, that only the right tool spends it, that a press
## past the car does not, and that letting go stops it. Where the water lands in
## the texture is [code]tests/unit/test_box_projection.gd[/code], and what it does
## when it gets there is [code]tests/unit/test_grime_map.gd[/code].
extends GutTest

const MAIN: String = "res://src/main/main.tscn"

## Above GUT's own output layer, so a finger aimed at the game lands on the game.
const ABOVE_THE_RUNNER: int = 200

## Long enough for the standoff to have eased out to the gap the walk wants, so a
## press lands on a settled camera.
const SETTLE_FRAMES: int = 90

## Enough physics ticks for a press to have been resolved into a mark.
const RESOLVE_FRAMES: int = 4

## A second of held trigger, which at [member Garage.wash_per_second] is most of
## the way through the mud under the jet. Long enough that the assertions below
## are about whether water is flowing rather than about how fast.
const WASH_FRAMES: int = 60

## How far over the roofline a press has to aim, in metres, to be past every tier
## that answers off real geometry — see [method _at_the_sky].
##
## [b]Measured across all ten styles at the design resolution, at the settled
## shot, rather than reasoned about[/b] — because the two edges it has to sit
## between are only a few tenths of a metre apart and neither of them is the same
## number on every car:
##
## [codeblock]
## 0.3   the exact ray misses all ten, and a 0.4 m sweep catches all ten
## 0.4   a 0.4 m sweep still catches the three tallest (minivan, offroad, pickup)
## 0.5   everything misses, and the press is 66 to 152 px down the frame
## 0.6   everything misses, and the press is 43 to 130 px down the frame
## 0.8   everything misses, and the press is 3 px ABOVE the top of it on a minivan
## [/codeblock]
##
## Six tenths: half again the power wash's own 0.4 m window, which is the tool
## this press is made with, and still 43 px inside the picture on the tallest car
## in the pack. [method _at_the_sky] re-asserts that second half on every use
## rather than trusting this table to stay true.
const CLEARS_THE_SWEEP: float = 0.6

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


func _car() -> Car:
	return _garage().get_node("%Car") as Car


func _grime() -> Grime:
	return _garage().grime()


func _bell() -> Chime:
	return _main.get_node("%Bell") as Chime


## The panel called [param named], or null — the car names its own pieces, so a
## test can ask for the bonnet rather than for "the third child".
func _panel(named: String) -> Node3D:
	for panel: Node3D in _car().panels():
		if String(panel.name) == named:
			return panel
	return null


## One panel of [param kind] on the real car. Asked for by what it is made of
## rather than by name, so reshaping or renaming the blockout cannot make a test
## about the bell quietly become a test about nothing.
func _a_panel_of(kind: Surface.Kind) -> Node3D:
	for panel: Node3D in _car().panels():
		if _car().kind_of(panel) == kind:
			return panel
	return null


func _marker() -> AimMarker:
	return _garage().aim_marker()


func _masks() -> GrimeDebug:
	return _screen().get_node("GrimeDebug") as GrimeDebug


func _jet() -> WashJet:
	return _garage().wash_jet()


func _belt() -> ToolBelt:
	return _garage().view_model().belt()


func _on_screen(point: Vector3) -> Vector2:
	return _camera().unproject_position(point)


## The middle of the car, on the glass — the one press that must always land on
## bodywork.
func _at_the_car() -> Vector2:
	return _on_screen(_car().global_position)


## Well over the roof: a press no tier of [method Garage._under_the_finger] can
## answer off real geometry, and so one the room answers with a corner of the
## nearest panel's bounding box.
##
## [b]It has to clear the swept sphere and not merely the exact ray[/b], which is
## what [constant CLEARS_THE_SWEEP] is and what this used to get wrong. It was
## 0.3 m, which is inside the window a 0.4 m sweep reaches — measured in
## [code]tests/integration/test_play_screen_sweep.gd[/code], whose own constants
## record that the car is found up to 0.3 m over the roofline at the power wash's
## radius and lost from 0.4 m. On the blockout the press missed anyway, on the
## shape of that particular roof; against the ten cars the bay parks now it lands
## on one, and a test whose subject is "a mark that came off a box spends no
## water" was quietly asserting something else. [constant CLEARS_THE_SWEEP] has
## the table it was re-measured from.
##
## Measured off the car's own bounding box rather than written down as an offset,
## because the ten styles differ by 70 cm in height. On screen is asserted rather
## than assumed for the same reason: a press off the top of the frame is not a
## press at all, and the headroom above the roof is a different number on a
## minivan than on a sport car.
func _at_the_sky() -> Vector2:
	var middle: Vector3 = _car().global_position
	var over: Vector3 = Vector3(middle.x, _car().bounds().end.y + CLEARS_THE_SWEEP, middle.z)
	var at: Vector2 = _on_screen(over)
	var view: SubViewport = _camera().get_viewport() as SubViewport
	assert_true(
		Rect2(Vector2.ZERO, Vector2(view.size)).has_point(at),
		"the press at %v is off the picture and would not be a press at all" % at
	)
	return at


func _touch(at: Vector2, pressed: bool) -> void:
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.position = at
	touch.pressed = pressed
	Input.parse_input_event(touch)
	Input.flush_buffered_events()


## Holds the trigger at [param at] for a second, without letting go — so a test
## can still ask what is marked. [method after_each] lifts it.
func _press(at: Vector2) -> void:
	_touch(at, true)
	await wait_physics_frames(WASH_FRAMES)


## Holds the trigger at [param at] for a second and lets go.
func _hold(at: Vector2) -> void:
	await _press(at)
	_touch(Vector2.ZERO, false)
	await wait_physics_frames(RESOLVE_FRAMES)


## Taps [param button] the way a thumb does, through the input system rather than
## by emitting its signal — a button that had been laid out under something else
## would still emit and would still be untappable.
func _press_button(button: Button) -> void:
	var at: Vector2 = button.get_global_rect().get_center()
	_touch(at, true)
	await wait_process_frames(1)
	_touch(at, false)
	await wait_process_frames(1)


func _lift() -> void:
	_touch(Vector2.ZERO, false)
	await wait_physics_frames(RESOLVE_FRAMES)


func _settle() -> void:
	await wait_physics_frames(SETTLE_FRAMES)


## A brush wide enough to cover a whole face of [param panel], so a test that
## wants a patch finished gets one whatever size the panel is.
##
## Measured off the panel rather than written down, and that is not fussiness: a
## patch is a fraction of a panel's own box, so 0.6 m covers one comfortably on a
## bonnet and does not reach the corner of one on the car's whole shell. A fixed
## radius here silently stopped finishing patches the moment these tests started
## asking for "a body panel" instead of naming the bonnet.
func _whole_face_of(panel: Node3D) -> float:
	return _box_around(panel).size.length()


## Where a panel's box actually is, in the room — off its skin rather than off the
## panel, which is [method Car.skin_of]'s whole reason for existing.
func _box_around(panel: Node3D) -> AABB:
	var skin: GeometryInstance3D = _car().skin_of(panel)
	return skin.global_transform * skin.get_aabb()


# ---- is there mud at all -----------------------------------------------------


func test_the_car_starts_filthy_and_the_room_says_when_it_is() -> void:
	# The frame's wait, from the outside. `Garage` lays the grime on a process
	# frame after `_ready` because a panel has no size before then, and the signal
	# is how anything downstream finds out — a view that bound early would draw an
	# empty grid all game.
	await _settle()
	assert_not_null(_grime(), "the room built no grime")
	assert_true(_grime().is_laid(), "and never laid it on the car")
	assert_almost_eq(_grime().remaining(), 1.0, 0.0001, "a fresh car is entirely dirty")


# ---- does the trigger spend anything -----------------------------------------


func test_holding_the_power_wash_on_the_car_takes_mud_off() -> void:
	# The whole feature, end to end and through the real scene stack: a thumb on
	# the glass, a ray, a panel, a projection, and a texel that is cleaner than it
	# was. Exact rather than approximate — the car starts at exactly 1.0, so any
	# water at all makes this strictly less.
	await _settle()
	assert_eq(_belt().equipped().id, DetailingTool.Id.POWER_WASH, "the wash is what you start with")
	await _hold(_at_the_car())
	assert_lt(_grime().remaining(), 1.0, "a second of water changed nothing on the car")


func test_letting_go_stops_the_water() -> void:
	await _settle()
	await _hold(_at_the_car())
	var after: float = _grime().remaining()
	await wait_physics_frames(WASH_FRAMES)
	assert_almost_eq(
		_grime().remaining(), after, 0.0000001, "the water kept running after the lift"
	)


func test_a_mark_on_a_bounding_box_is_not_somewhere_water_can_go() -> void:
	# The one case `surface` still refuses. A press well over the roof reaches no
	# geometry at all — not by the exact ray, not by the swept sphere
	# ([constant CLEARS_THE_SWEEP] is what puts it past that) and not by the second
	# probe ray — so the crosshair ends up on
	# a point clamped onto a bounding box with a normal invented facing the player.
	# [BoxProjection] fed that normal picks a face off a measurement nobody took,
	# so it would wash a texel that has nothing to do with where the mark is.
	#
	# Everything the ray *does* reach washes, including the snapped case — that is
	# what `surface` means and it is not the same question as "did the player aim
	# well". [method Garage._spend_the_trigger] has why that distinction had to be
	# rewritten once.
	#
	# Held rather than held-and-released: letting go puts the mark away, so a test
	# that lifted first would be asserting on an empty crosshair.
	await _settle()
	await _press(_at_the_sky())
	assert_true(_marker().is_marking(), "the press still marked the nearest bodywork")
	assert_almost_eq(_grime().remaining(), 1.0, 0.0001, "and a box corner spent water")


func test_only_the_power_wash_takes_mud_off() -> void:
	# All five tools spend the trigger now, and exactly one of them moves mud. A
	# sponge that quietly washed would be the wrong rule shipped invisibly — the
	# sponge works on the layer under the mud, and only once the mud is gone.
	#
	# Nor does it lay any product here, and that is the same assertion read the
	# other way: a car nobody has washed has no bare paint on it, so the bottle
	# has nothing to draw from. No refusal is written anywhere for that — see
	# [GrimeMap].
	await _settle()
	_belt().equip(DetailingTool.Id.SPONGE)
	await _hold(_at_the_car())
	assert_almost_eq(_grime().remaining(), 1.0, 0.0001, "the sponge washed mud off")
	assert_almost_eq(_grime().product(), 0.0, 0.0001, "the sponge soaped a muddy car")


## The panel a press at [param at] actually lands on, asked of the room rather
## than worked out from the geometry here. Washes it flat on the way, so the
## caller has bare paint to work on.
##
## [b]Discovered rather than named, and that is not ceremony.[/b] The aim is
## taken a thumb's width above the finger ([ThumbLift] has why), so a press at the
## middle of the car lands somewhat above the middle of the car — on the side
## glass, as it happens, which was measured here rather than guessed at. A test
## that assumed the bodywork and reached for the sponge would have quietly become
## a test that the sponge does nothing.
func _panel_under(at: Vector2) -> Node3D:
	# An array rather than a plain local: a GDScript lambda captures locals by
	# value, so a `String` assigned inside this one would never come back out.
	var seen: Array[String] = [""]
	var noted: Callable = func(panel: String) -> void: seen[0] = panel
	_garage().aimed.connect(noted)
	await _press(at)
	# Before the lift, which marks nothing and would report the empty string.
	_garage().aimed.disconnect(noted)
	await _lift()
	return _panel(seen[0])


## A cleaner that is not [param right] — the wrong bottle for whatever surface
## the press landed on.
func _a_cleaner_other_than(right: DetailingTool.Id) -> DetailingTool.Id:
	for kind: Surface.Kind in [Surface.Kind.BODY, Surface.Kind.GLASS, Surface.Kind.WHEEL]:
		var cleaner: DetailingTool.Id = Surface.cleaner_for(kind)
		if cleaner != right:
			return cleaner
	return right


func test_the_wrong_cleaner_for_a_surface_does_nothing() -> void:
	# The one rule the buckets cannot express, so the one rule
	# [method Garage._spend_the_trigger] writes down: a sponge is for paint and
	# window cleaner is not, and a texture cannot tell them apart. Asserted after
	# a wash, because before one there would be no bare paint and this would pass
	# for the wrong reason.
	await _settle()
	var panel: Node3D = await _panel_under(_at_the_car())
	assert_not_null(panel, "the press landed on nothing")
	if panel == null:
		return
	var right: DetailingTool.Id = Surface.cleaner_for(_car().kind_of(panel))
	_belt().equip(_a_cleaner_other_than(right))
	await _hold(_at_the_car())
	assert_almost_eq(
		_grime().map_of(panel).product(), 0.0, 0.0001, "the wrong bottle worked on %s" % panel.name
	)


func test_the_right_cleaner_for_a_surface_covers_it() -> void:
	# And the other half, so the test above cannot pass because the middle pass is
	# broken for everything.
	await _settle()
	var panel: Node3D = await _panel_under(_at_the_car())
	assert_not_null(panel, "the press landed on nothing")
	if panel == null:
		return
	_belt().equip(Surface.cleaner_for(_car().kind_of(panel)))
	await _hold(_at_the_car())
	assert_gt(_grime().map_of(panel).product(), 0.0, "nothing was left on %s" % panel.name)


func test_the_rag_turns_that_into_shine() -> void:
	# The last pass, and the whole conveyor end to end through the real scene
	# stack: a thumb on the glass three times with three different tools, and a
	# car that is measurably further along than it was.
	await _settle()
	var panel: Node3D = await _panel_under(_at_the_car())
	assert_not_null(panel, "the press landed on nothing")
	if panel == null:
		return
	_belt().equip(Surface.cleaner_for(_car().kind_of(panel)))
	await _hold(_at_the_car())
	_belt().equip(DetailingTool.Id.DRYING_RAG)
	await _hold(_at_the_car())
	assert_gt(_grime().map_of(panel).shine(), 0.0, "the rag buffed nothing into %s" % panel.name)
	assert_gt(_grime().shine(), 0.0, "and the car as a whole noticed")


func test_swapping_back_to_the_wash_starts_the_water_again() -> void:
	# And the other half of it, so the test above cannot pass because the trigger
	# is broken for everything.
	await _settle()
	_belt().equip(DetailingTool.Id.SPONGE)
	await _hold(_at_the_car())
	_belt().equip(DetailingTool.Id.POWER_WASH)
	await _hold(_at_the_car())
	assert_lt(_grime().remaining(), 1.0)


# ---- the ding ----------------------------------------------------------------


func test_a_patch_coming_clean_rings_the_bell() -> void:
	# The other end of the trigger: the room says a patch finished, the screen
	# asks the host for a bell, and the host rings it. Through the real stack, so
	# a connection dropped anywhere along it fails here.
	#
	# The bonnet is washed flat rather than through the crosshair, the way
	# `tests/integration/test_grime.gd` does it: how long a held jet takes to
	# finish a patch is a tuning number, and a suite that waited for it would go
	# red the day somebody turns the water down. That a held press reaches the
	# paint at all is the tests above.
	await _settle()
	var hood: Node3D = _a_panel_of(Surface.Kind.BODY)
	assert_not_null(hood, "the car has no bodywork")
	if hood == null:
		return
	var before: int = _bell().rings()
	var box: AABB = _box_around(hood)
	var on_top: Vector3 = Vector3(box.get_center().x, box.end.y, box.get_center().z)
	var finished: int = 0
	for _sweep: int in 60:
		finished += _grime().wash(hood, on_top, Vector3.UP, _whole_face_of(hood), 0.1)
	assert_gt(finished, 0, "washing the bonnet flat never finished a patch")
	assert_gt(_bell().rings(), before, "a patch came clean and the game said nothing")


func test_a_burst_of_patches_is_not_a_burst_of_bells() -> void:
	# A wide jet finishes several patches in one tick, and every one of them is a
	# `patch_finished`. [Chime] is what stands between that and a distorted mess —
	# this asserts the screen leaves that judgement to it rather than filtering
	# on its own or, worse, ringing per texel.
	await _settle()
	var hood: Node3D = _a_panel_of(Surface.Kind.BODY)
	if hood == null:
		return
	var box: AABB = _box_around(hood)
	var on_top: Vector3 = Vector3(box.get_center().x, box.end.y, box.get_center().z)
	var before: int = _bell().rings()
	var finished: int = 0
	for _sweep: int in 60:
		finished += _grime().wash(hood, on_top, Vector3.UP, _whole_face_of(hood), 0.2)
	assert_gt(finished, 1, "the sweep finished at most one patch, so there is no burst to thin")
	assert_lt(_bell().rings() - before, finished, "every patch in the burst got its own bell")


# ---- the debug view ----------------------------------------------------------


func test_the_masks_are_bound_but_out_of_the_way() -> void:
	# Built from the room's own maps rather than from a set of its own, and put
	# away until asked for: a player who has never asked should never see it.
	await _settle()
	assert_false(_masks().is_shown(), "the masks are up without being asked for")
	assert_eq(
		_masks().get_node("%Grid").get_child_count(),
		_car().panels().size(),
		"one thumbnail per panel"
	)


func test_the_masks_can_be_put_up_and_taken_down() -> void:
	await _settle()
	_masks().toggle()
	assert_true(_masks().is_shown())
	_masks().toggle()
	assert_false(_masks().is_shown())


func test_a_tap_on_the_toggle_puts_the_masks_up() -> void:
	# The half of this a phone can reach. The key is fine for whoever has one, and
	# the thing this view diagnoses is a projection that behaves differently under
	# a thumb — so it has to be openable on the device with the bug in it.
	await _settle()
	var button: Button = _masks().toggle_button()
	assert_gte(
		button.size.x, TouchTarget.min_design_size(), "the toggle is smaller than a thumb across"
	)
	assert_gte(button.size.y, TouchTarget.min_design_size(), "and up")
	await _press_button(button)
	assert_true(_masks().is_shown(), "a tap on the toggle did not put the masks up")
	await _press_button(button)
	assert_false(_masks().is_shown(), "and a second tap did not put them away")


func test_the_toggle_does_not_sit_on_the_tool_belts_own_corner() -> void:
	# The belt lays its T out at the bottom left and rolls its icons up out of it;
	# this board started life in that same corner, on top of it. Asserted against
	# the belt's real button rather than against the numbers, so moving either one
	# is what fails this rather than editing a constant.
	await _settle()
	var hud: ToolBeltHud = _screen().get_node("ToolBelt") as ToolBeltHud
	assert_false(
		_masks().toggle_button().get_global_rect().intersects(
			hud.toggle_button().get_global_rect()
		),
		"the grime toggle is sitting on the tool belt's toggle"
	)


func test_the_masks_do_not_eat_the_press_underneath_them() -> void:
	# A picture and not a control, apart from the one button. The board sits on
	# the same screen the player aims through, so anything else it claimed would
	# be water that never reached the car.
	await _settle()
	_masks().set_shown(true)
	await wait_process_frames(1)
	assert_eq(_masks().mouse_filter, Control.MOUSE_FILTER_IGNORE)
	await _hold(_at_the_car())
	assert_lt(_grime().remaining(), 1.0, "the masks swallowed the press")


# ---- the crosshair, behind the same panel ------------------------------------


## Puts [param id] in the player's hands and presses in the middle of the car,
## holding for just long enough that the room has resolved the press into a mark
## and drawn a sight for it. [method _lift] lets go.
##
## Deliberately shorter than [method _press], which holds for a second because
## the rest of this suite is measuring what a second of trigger does to the mud.
## Which sight is showing needs none of that: it is decided in the same physics
## tick the mark is, by [method Garage._resolve_aim].
func _aim_with(id: DetailingTool.Id) -> void:
	_belt().equip(id)
	_touch(_at_the_car(), true)
	await wait_physics_frames(RESOLVE_FRAMES)


func test_no_tool_draws_the_ring_during_normal_play() -> void:
	# The whole of retiring the crosshair, in one assertion. Walked over
	# [method DetailingTool.catalogue] rather than over a list written out here,
	# so a sixth tool is in this test the day it is on the belt — which is the
	# case that would quietly reintroduce the ring, since not asking for it is
	# what draws it (see [method AimMarker.draw_crosshair]).
	#
	# [method AimMarker.is_marking] beside every one of them on purpose. Taking
	# the ring off is a change to what is drawn and to nothing else; a mark that
	# stopped being made would take the panel readout, the wand's alignment and
	# the trigger with it, and would sail through an assertion that only looked
	# at the ring.
	await _settle()
	assert_false(_garage().debug_tools, "debug tools was on without being asked for")
	for tool: DetailingTool in DetailingTool.catalogue():
		await _aim_with(tool.id)
		assert_true(_marker().is_marking(), "%d: the press marked nothing at all" % tool.id)
		assert_false(_marker().is_crosshair_drawn(), "%d: and drew the ring on it" % tool.id)
		await _lift()


func test_debug_tools_puts_the_bare_crosshair_under_every_tool() -> void:
	# The other half of the same rule, and what the ring is still built for: with
	# the switch on it is the only sight in the game, under all five tools rather
	# than under the four that used to wear it. Bare is the point — an effect and
	# the mud disagreeing is a question nothing else in the game can be asked, and
	# it cannot be asked with the effect still drawn over the answer.
	await _settle()
	_garage().debug_tools = true
	for tool: DetailingTool in DetailingTool.catalogue():
		await _aim_with(tool.id)
		assert_true(_marker().is_crosshair_drawn(), "%d: the ring did not come back" % tool.id)
		assert_false(_jet().is_spraying(), "%d: and water was drawn over it" % tool.id)
		await _lift()


func test_the_water_is_what_a_player_gets_until_debug_tools_is_switched_on() -> void:
	# [member Garage.debug_tools] is the flag, and this is the default a player
	# who has never opened the "~" panel gets: [WashJet]'s water, not the bare
	# crosshair the switch puts back.
	await _settle()
	assert_false(_garage().debug_tools, "debug tools was on without being asked for")
	# `_press`, not `_hold`: the jet only sprays while the finger is still down,
	# and `_hold` lifts it before handing back (see
	# `test_letting_go_shuts_the_water_off_and_lets_the_last_of_it_land` in
	# `test_play_screen_jet.gd`), so a check made after release would find the
	# trigger off whatever the flag said.
	await _press(_at_the_car())
	assert_true(_jet().is_spraying(), "the power wash sprayed nothing by default")
	assert_false(_marker().is_crosshair_drawn(), "and the crosshair showed through it")


func test_a_tap_on_debug_tools_puts_the_crosshair_back() -> void:
	# The half of the wiring a phone can reach: the switch lives in the same
	# panel the grime masks do, and a tap on it — not a call straight through to
	# [Garage] — is what a developer on a device actually has.
	#
	# The board is opened first, the same way a player would have to: the switch
	# sits inside it, and a hidden control's children get no input at all — a
	# tap "through" a closed panel would be testing a press nobody could make.
	await _settle()
	_masks().set_shown(true)
	await wait_process_frames(1)
	var button: CheckButton = _masks().debug_tools_button()
	await _press_button(button)
	assert_true(_masks().debug_tools_enabled(), "the tap did not switch the panel's own state")
	assert_true(_garage().debug_tools, "and did not reach the room behind it")
	await _press(_at_the_car())
	assert_false(_jet().is_spraying(), "the jet still sprayed with debug tools on")
	assert_true(_marker().is_crosshair_drawn(), "and the crosshair did not come back")
