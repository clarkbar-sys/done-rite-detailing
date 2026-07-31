## The game: the same garage the title screen was showing off, seen from inside
## it — standing beside the car at head height instead of circling it.
##
## The whole difference between this screen and the title card is two exports on
## the [Garage] instance in this scene's file: the orbit is off and
## [member Garage.first_person] is on. That is on purpose and it is the pattern
## worth keeping — the room is one scene, and a screen configures it rather than
## reaching into it.
##
## [b]What this script does own is the loop between the two halves of the tool
## belt.[/b] The roll-up ([ToolBeltHud]) says which tool the player asked for;
## the belt ([ToolBelt]) decides whether that is a change; the viewmodel
## ([ViewModel]) hears the answer and swaps what is in the player's hands. None
## of those three know about each other — the roll-up has never heard of a mesh
## and the viewmodel has never heard of a button — and this file is the only
## place that knows all three exist. That is what makes the roll-up replaceable
## by a radial menu, or the proxies by real models, without either noticing.
##
## [b]There is exactly one belt.[/b] It is built by the [ViewModel] inside the
## room and read back out of it here, rather than constructed again. Two belts
## constructed the same way is the bug where the roll-up rings the sponge while
## the player is holding the wand, and it would look like a UI bug for as long
## as it took somebody to find this line.
##
## The eye is parked, and that is a decision rather than an omission: walking and
## looking around bring a character body, collision against the room's sealed
## walls, and touch controls with them, and none of those belong in the change
## that put a tool in the player's hands.
##
## There is no way back to the title screen on purpose. A Back button is a
## decision about how the game is paused and what that does to a job in
## progress, and inventing an answer now — before there is a job to interrupt
## — would be guessing at it. Reloading is the way out until then.
extends GameScreen

## Toggles the roll-up: the keyboard's half of the [b]T[/b] button.
const TOGGLE_ACTION: String = "tool_belt_toggle"

## Puts the roll-up away without picking anything.
const CLOSE_ACTION: String = "tool_belt_close"

## Equips the nth tool directly. Numbered from 1 because that is what is printed
## on the key; the belt is indexed from 0 and the conversion happens once, below.
const SLOT_ACTION_PREFIX: String = "tool_slot_"

var _belt: ToolBelt = null

@onready var _garage: Garage = $Garage
@onready var _hud: ToolBeltHud = $ToolBelt


func _ready() -> void:
	# Read rather than built — see the class docs on why there is exactly one.
	# The viewmodel is a descendant of the garage, so its `_ready()` has already
	# run by the time this one does and the belt is there to be taken.
	_belt = _garage.view_model().belt()
	_hud.bind(_belt)
	_hud.tool_selected.connect(_on_tool_selected)


## Keys, for the half of the players who will never tap the [b]T[/b].
##
## [method Node._unhandled_input] and not [method Node._input]: the roll-up's
## buttons are [Control]s and they get the event first, so a tap on an icon is
## consumed before it reaches here. Anything arriving in this function is
## therefore a key the UI did not want.
##
## Every branch that acts marks the event handled. Nothing else is listening
## today, but the thing that will be is a pause menu on the same [kbd]Escape[/kbd]
## — and it should not also fire on the press that closed the roll-up.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(TOGGLE_ACTION):
		_hud.toggle()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(CLOSE_ACTION):
		# Consumed only when there is something to close, so [kbd]Escape[/kbd] is
		# still free for whatever owns pausing later. This is the whole reason
		# the action is ours and not the built-in `ui_cancel`.
		if not _hud.is_expanded():
			return
		_hud.set_expanded(false)
		get_viewport().set_input_as_handled()
		return
	for index: int in _belt.size():
		if not event.is_action_pressed(SLOT_ACTION_PREFIX + str(index + 1)):
			continue
		_equip(index)
		get_viewport().set_input_as_handled()
		return


## A tool picked out of the roll-up.
##
## The roll-up has already closed itself by the time this runs — it does that on
## any pick rather than on hearing back, because the belt refuses a swap to the
## tool you are already holding and a roll-up that waited for
## [signal ToolBelt.equipped_changed] would stay open on exactly the tap that
## means "never mind". So all that is left here is the equip.
func _on_tool_selected(id: DetailingTool.Id, _index: int) -> void:
	_belt.equip(id)


## Equips the tool at [param index] and puts the roll-up away.
##
## The number keys close it too, even though they can be pressed without ever
## opening it. Leaving it up would mean a player who opened the roll-up, thought
## better of it and hit [kbd]2[/kbd] instead is left with a menu they now have to
## dismiss — and "picking a tool closes the roll-up" is one rule rather than two.
func _equip(index: int) -> void:
	_belt.equip_at(index)
	_hud.set_expanded(false)
