## Integration test for the loop the play screen owns: pick a tool, hold a tool.
##
## Split out of [code]tests/integration/test_play_screen.gd[/code], which covers
## the shot — where the eye stands and what it can see. This file covers the
## other thing that screen does: closing the loop between the roll-up, the belt
## and the viewmodel. Two files because they fail for unrelated reasons and
## because one of them was about to trip `.gdlintrc`'s public-method cap, which
## is a fair signal that a test file has started doing two jobs.
##
## Under tests/integration/ because none of it is true of any script on its own.
## The three parts are wired in [method Node._ready], the roll-up's icons exist
## only after a layout pass, and the assertions below deliberately read the
## [i]mesh[/i] rather than the belt — see [method _visible_tool].
extends GutTest

const PLAY_SCREEN: String = "res://src/screens/play_screen.tscn"

## Long enough for the roll-up's expand/collapse tween to have finished, with
## room to spare. Derived from the HUD's own constant rather than written down
## again, so a snappier roll-up does not silently start being measured mid-flight.
const SETTLE_SECONDS: float = ToolBeltHud.EXPAND_SECONDS * 2.0

var _screen: GameScreen = null
var _leftovers: Leftovers = null
var _window_size_before: Vector2i = Vector2i.ZERO


## Catches input the play screen did not consume.
##
## "The screen left [kbd]Escape[/kbd] alone" cannot be checked by asserting that
## nothing visible happened — a screen that swallowed the key and did nothing
## with it looks identical. This is the witness, and it stands in for whatever
## ends up owning pause.
##
## Deliberately moved to child 0 in [method before_each]: unhandled input is
## offered to nodes in reverse tree order, so the [i]lower[/i] sibling is asked
## last. Added after the screen and left where it landed, it would be asked
## first and would see every key whether the screen wanted it or not.
class Leftovers:
	extends Node

	var seen: Array[StringName] = []

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and event.is_pressed():
			seen.append((event as InputEventKey).as_text_physical_keycode())


func before_each() -> void:
	# A headless window is 64x64 — smaller than a single one of the roll-up's tap
	# targets, small enough that its layout would be clamped into nonsense before
	# anything here got to look at it. `content_scale_size` is the design
	# resolution from project.godot, so this makes the roll-up the size it is on
	# screen. Put back in after_each: every suite shares this window.
	var root: Window = get_tree().root
	_window_size_before = root.size
	root.size = root.content_scale_size
	var packed: PackedScene = load(PLAY_SCREEN) as PackedScene
	assert_not_null(packed, "could not load %s" % PLAY_SCREEN)
	if packed == null:
		return
	# Instantiate into a typed local before handing it to add_child_autofree —
	# GUT's helper is untyped, and autofree is what keeps a failing assertion
	# below from being reported as a leak against whichever test runs next.
	var screen: GameScreen = packed.instantiate() as GameScreen
	_screen = screen
	add_child_autofree(_screen)
	var leftovers: Leftovers = Leftovers.new()
	_leftovers = leftovers
	add_child_autofree(_leftovers)
	_leftovers.get_parent().move_child(_leftovers, 0)
	# `_ready()` has already fired inside add_child; the frame is only here to let
	# the roll-up's layout settle before anything is pressed.
	await wait_process_frames(1)


func after_each() -> void:
	get_tree().root.size = _window_size_before


func _garage() -> Garage:
	return _screen.get_node("Garage") as Garage


func _hud() -> ToolBeltHud:
	return _screen.get_node("ToolBelt") as ToolBeltHud


## The viewmodel is reached off the garage rather than off the screen: a
## `%Name` is unique within the scene that *owns* it, so it is visible from the
## room it belongs to and not from the screen the room was instanced into.
func _view_model() -> ViewModel:
	return _garage().get_node("%ViewModel") as ViewModel


func _belt() -> ToolBelt:
	return _view_model().belt()


## Which tool the player is actually holding, read off the proxies rather than
## off the belt.
##
## The belt is what this screen changes; the mesh is what the player sees, and
## the whole point of the wiring under test is that the second follows the
## first. Asking the belt what it thinks is equipped would pass just as happily
## on a screen where nothing was ever connected to the viewmodel at all.
func _visible_tool() -> DetailingTool.Id:
	var held: Array[DetailingTool.Id] = []
	for tool_carried: DetailingTool in _belt().tools():
		if _view_model().proxy_for(tool_carried.id).visible:
			held.append(tool_carried.id)
	assert_eq(held.size(), 1, "exactly one proxy may be visible at a time")
	if held.size() != 1:
		return DetailingTool.Id.POWER_WASH
	return held[0]


## Presses and releases whatever key [param action] is bound to.
##
## Through [InputMap] rather than a keycode written down here, so this exercises
## the binding in project.godot as well as the handler — a test that pressed
## [kbd]T[/kbd] directly would keep passing after the action stopped being bound
## to anything. Through [Input] and not [method Viewport.push_input] for the same
## reason the title screen's tap helper is: that is the path a real key takes.
func _press(action: StringName) -> void:
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	assert_gt(events.size(), 0, "%s is not bound to anything" % action)
	if events.is_empty():
		return
	var bound: InputEventKey = events[0] as InputEventKey
	assert_not_null(bound, "%s must be bound to a key" % action)
	if bound == null:
		return
	for pressed: bool in [true, false]:
		var key: InputEventKey = bound.duplicate() as InputEventKey
		key.pressed = pressed
		Input.parse_input_event(key)
	Input.flush_buffered_events()


func _open_roll_up() -> void:
	_hud().set_expanded(true)
	await wait_seconds(SETTLE_SECONDS)


func test_the_screen_carries_the_roll_up() -> void:
	assert_not_null(_hud(), "the play screen must have a tool belt to change tool with")


func test_the_roll_up_draws_over_the_room() -> void:
	# The room renders through a SubViewportContainer, which is a canvas item, so
	# "on top" is tree order and not a z-index. A roll-up under the garage is
	# invisible, and would look exactly like one that was never added.
	assert_gt(_hud().get_index(), _garage().get_index(), "the roll-up goes over the room")


func test_the_roll_up_shows_every_tool_on_the_belt() -> void:
	# The roll-up builds its icons from the belt it was handed, so this is also
	# the assertion that it was handed one at all.
	assert_eq(_hud().icon_count(), _belt().size(), "the roll-up must be bound to the real belt")


func test_the_roll_up_starts_shut() -> void:
	assert_false(_hud().is_expanded(), "the game does not open on a menu")


func test_the_player_starts_holding_the_first_tool() -> void:
	# Before anything is picked and on the very first frame: there is no
	# empty-handed state, and no five-tools-at-once frame either.
	assert_eq(_visible_tool(), DetailingTool.Id.POWER_WASH, "the belt starts at its first tool")


func test_picking_a_tool_changes_what_is_in_your_hands() -> void:
	# The whole loop in one assertion: the roll-up's button, through the belt,
	# out to the mesh. Through the button's own signal rather than by calling the
	# handler, so a connection dropped in `_ready()` fails here.
	await _open_roll_up()
	_hud().icon_at(_belt().index_of(DetailingTool.Id.SPONGE)).pressed.emit()
	await wait_process_frames(1)
	assert_eq(_visible_tool(), DetailingTool.Id.SPONGE, "picking a tool must change the proxy")


func test_every_tool_can_be_picked_out_of_the_roll_up() -> void:
	for index: int in _belt().size():
		await _open_roll_up()
		_hud().icon_at(index).pressed.emit()
		await wait_process_frames(1)
		var wanted: DetailingTool = _belt().tools()[index]
		assert_eq(_visible_tool(), wanted.id, "%s is unreachable" % wanted.display_name)


func test_picking_a_tool_puts_the_roll_up_away() -> void:
	await _open_roll_up()
	_hud().icon_at(_belt().index_of(DetailingTool.Id.DRYING_RAG)).pressed.emit()
	await wait_seconds(SETTLE_SECONDS)
	assert_false(_hud().is_expanded(), "one tap, and the roll-up is gone")


func test_picking_the_tool_you_hold_shuts_the_roll_up_and_does_nothing_else() -> void:
	# The belt refuses this swap, so a roll-up that only closed on
	# `equipped_changed` would stay open on exactly the tap that means "never
	# mind, I've got it".
	await _open_roll_up()
	var held: DetailingTool.Id = _visible_tool()
	_hud().icon_at(_belt().equipped_index()).pressed.emit()
	await wait_seconds(SETTLE_SECONDS)
	assert_false(_hud().is_expanded(), "the roll-up closes on any pick")
	assert_eq(_visible_tool(), held, "and the hands are untouched")


# ---- the keyboard, for everyone who will never tap the corner ---------------


func test_the_bindings_are_declared_in_the_project() -> void:
	# The actions live in project.godot so they are remappable and visible in one
	# place; a handler reading an action nobody declared is a silent no-op.
	var actions: Array[StringName] = [&"tool_belt_toggle", &"tool_belt_close"]
	for slot: int in _belt().size():
		actions.append(StringName("tool_slot_%d" % (slot + 1)))
	for action: StringName in actions:
		assert_true(InputMap.has_action(action), "%s is not declared" % action)
		if InputMap.has_action(action):
			assert_gt(InputMap.action_get_events(action).size(), 0, "%s is unbound" % action)


func test_t_opens_the_roll_up_and_t_again_shuts_it() -> void:
	_press(&"tool_belt_toggle")
	await wait_seconds(SETTLE_SECONDS)
	assert_true(_hud().is_expanded(), "T must open the roll-up")
	_press(&"tool_belt_toggle")
	await wait_seconds(SETTLE_SECONDS)
	assert_false(_hud().is_expanded(), "T again must put it away")


func test_the_number_keys_equip_without_opening_anything() -> void:
	# The point of them: a player at a desk never touches the corner of the
	# screen at all.
	_press(&"tool_slot_2")
	await wait_process_frames(1)
	assert_eq(_visible_tool(), _belt().tools()[1].id, "2 must equip the second tool")
	assert_false(_hud().is_expanded(), "a number key does not open the roll-up")


func test_every_number_key_reaches_its_own_tool() -> void:
	for index: int in _belt().size():
		_press(StringName("tool_slot_%d" % (index + 1)))
		await wait_process_frames(1)
		var wanted: DetailingTool = _belt().tools()[index]
		assert_eq(_visible_tool(), wanted.id, "%d must equip %s" % [index + 1, wanted.display_name])


func test_a_number_key_shuts_an_open_roll_up() -> void:
	# "Picking a tool closes the roll-up" is one rule, not one rule per input.
	await _open_roll_up()
	_press(&"tool_slot_3")
	await wait_seconds(SETTLE_SECONDS)
	assert_eq(_visible_tool(), _belt().tools()[2].id, "the key must still equip")
	assert_false(_hud().is_expanded(), "and must not leave a menu behind")


func test_escape_shuts_an_open_roll_up_without_picking_anything() -> void:
	await _open_roll_up()
	var held: DetailingTool.Id = _visible_tool()
	_press(&"tool_belt_close")
	await wait_seconds(SETTLE_SECONDS)
	assert_false(_hud().is_expanded(), "escape must back out of the roll-up")
	assert_eq(_visible_tool(), held, "backing out is not picking")


func test_escape_is_swallowed_only_while_the_roll_up_is_open() -> void:
	# Whatever ends up owning pause wants this key too. It must not fire on the
	# press that put the roll-up away — nor be starved of every other press,
	# which is what binding this to the built-in `ui_cancel` would have cost.
	await _open_roll_up()
	_press(&"tool_belt_close")
	await wait_seconds(SETTLE_SECONDS)
	assert_eq(_leftovers.seen.size(), 0, "the press that closed the roll-up was consumed")
	_press(&"tool_belt_close")
	await wait_process_frames(1)
	assert_eq(_leftovers.seen.size(), 1, "escape must fall through once there is nothing to close")
