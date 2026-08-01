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
## [b]The other loop this screen owns is movement[/b], and it is the same shape:
## the pad ([MotionPad]) says which way the player is asking to go, the room
## ([Garage]) works out what that does to a camera, and neither has heard of the
## other. A stick, a swipe or a pair of thumbs on the glass replaces the first
## without the second noticing, which is the whole reason the thing crossing this
## file is two numbers in [code]-1..1[/code] rather than a button.
##
## [b]Movement is polled and tool changes are not, and that is not an
## inconsistency.[/b] Picking a tool happens at an instant, so it is a signal.
## Holding a direction is a thing that is true across frames, so it is read once
## a frame — from the buttons themselves and from [Input], neither of which can
## get stuck holding a press whose release went missing while the browser tab was
## somewhere else.
##
## [b]And the third loop is the trigger[/b], which is the same shape a third
## time. A finger goes down on the picture of the room, this file turns it into a
## point on the glass, and [method Garage.aim_at] turns that into a tool pointed
## somewhere and a crosshair on the paint. What crosses is a [Vector2] and
## nothing else: the room has never heard of a touch event, and this file has
## never heard of a camera, a ray or a car panel.
##
## Holding is firing and letting go is not, which is why there are only two calls
## — [method Garage.aim_at] while the finger is down and
## [method Garage.release_aim] when it lifts. Nothing sprays yet. When something
## does, it goes on the far end of those two and nothing here changes.
##
## [b]Pointer input arrives in [method Control._gui_input] and not in
## [method Node._unhandled_input], where the keys are, and the difference is
## worth knowing before moving any of it.[/b] A [Control] at the default
## [code]stop[/code] filter is the topmost thing under every touch that is not on
## a button, and the GUI system hands the event to [i]it[/i] rather than letting
## the event go unhandled. This screen is such a control, so this is where its
## taps go. The belt's icons and the pad's arrows still get their own taps first
## — they are separate controls and the hit test finds them before it reaches
## this one.
##
## [b]The way that is wrong, because it was shipped for an hour and looked
## right.[/b] The obvious alternative is to set this root to
## [code]mouse_filter = ignore[/code] and read the presses in
## [method Node._unhandled_input] alongside the keys. Tested against this screen
## on its own, that works perfectly. In the actual game it does nothing at all:
## [code]src/main/main.tscn[/code] hangs every screen off a
## [code]%ScreenHost[/code] which is itself a plain [Control] at
## [code]stop[/code], so a press that falls through this screen lands in that one
## and is swallowed a layer lower down. Measured both ways with a probe — under a
## bare play screen the taps arrive, under the real main scene the control
## reported under the finger is [code]ScreenHost[/code] and nothing reaches here.
## Which is also the lesson for the test:
## [code]tests/integration/test_play_screen_trigger.gd[/code] presses through
## [code]main.tscn[/code] and not through this scene alone, because a suite that
## instances the screen by itself cannot see this class of bug.
##
## [b]Both fingers work, which took the long way round.[/b] The engine emulates a
## mouse from touch — that is what makes the belt's [Button]s work on a phone at
## all, and [code]project.godot[/code] says so — but it only emulates the
## [i]first[/i] finger. So a thumb parked on the pad's right arrow would eat the
## emulation and a second finger on the car would produce no mouse event
## whatsoever: walk and aim, the two things a player does at once, would be
## mutually exclusive. The fix is to read the touch events themselves and ignore
## the emulated mice, which is exact rather than a heuristic —
## [constant InputEvent.DEVICE_ID_EMULATION] is the engine's own mark on an event
## it invented. Mouse events that are not emulated are somebody at a desk, and
## they are handled too.
##
## The eye walks a rail around the car and cannot look away from it, and that is
## a decision rather than an omission: turning your head brings a look control
## the phone has no thumb spare for, and walking anywhere else brings a character
## body and collision against a room that is currently six boxes. Neither belongs
## in the change that proved the camera can move at all.
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

## Walks the eye left around the car: the keyboard's half of the pad's left
## arrow.
const TURN_LEFT_ACTION: String = "camera_left"

## Walks it right.
const TURN_RIGHT_ACTION: String = "camera_right"

## Raises the eye.
const LIFT_UP_ACTION: String = "camera_up"

## Lowers it.
const LIFT_DOWN_ACTION: String = "camera_down"

## No finger is on the glass. Not a touch index the engine can ever hand out, so
## it cannot collide with a real one.
const NO_FINGER: int = -1

## The stand-in index for a mouse held down at a desk, so one variable can track
## "who is aiming" whether that is a finger or a pointer. Also not a touch index
## the engine hands out, and distinct from [constant NO_FINGER] — a mouse that
## shared the "nobody" value would be released by the first stray touch.
const MOUSE_FINGER: int = -2

var _belt: ToolBelt = null
var _finger: int = NO_FINGER

@onready var _garage: Garage = $Garage
@onready var _hud: ToolBeltHud = $ToolBelt
@onready var _pad: MotionPad = $MotionPad
@onready var _readout: Label = $PanelReadout


func _ready() -> void:
	# Read rather than built — see the class docs on why there is exactly one.
	# The viewmodel is a descendant of the garage, so its `_ready()` has already
	# run by the time this one does and the belt is there to be taken.
	_belt = _garage.view_model().belt()
	_hud.bind(_belt)
	_hud.tool_selected.connect(_on_tool_selected)
	_garage.aimed.connect(_on_aimed)
	_readout.text = ""


## Hands the room what the player is asking for, every frame.
##
## Every frame including the ones where nothing is held: "stop" is an intent like
## any other, and a screen that only spoke up when something was pressed would
## leave the camera coasting on the last thing it heard.
##
## The two input sources are summed and the room clamps the total, so holding the
## right arrow and the pad's right button walks at one speed rather than two.
## [method Input.get_axis] is the engine's own idiom for a held pair and returns
## the same [code]-1..1[/code] the pad does.
func _process(_delta: float) -> void:
	var turn: float = _pad.turn() + Input.get_axis(TURN_LEFT_ACTION, TURN_RIGHT_ACTION)
	var lift: float = _pad.lift() + Input.get_axis(LIFT_DOWN_ACTION, LIFT_UP_ACTION)
	_garage.steer(turn, lift)


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


## Every way a pointer can arrive, turned into "aim there" or "stop aiming".
##
## The GUI system's own hook rather than the unhandled-input one the keys use —
## the class docs above have the measurement that settled which, and why the
## other way passes its tests and does nothing in the game.
##
## Four kinds and not one, and the two that look redundant are not: touch and
## drag are what a phone sends, and the mouse pair is what a desk sends. The
## emulated middle case — the mouse the engine invents from the first finger — is
## dropped on sight, because the touch it was invented from is already being
## handled and acting on both would make the second finger a stranger. All of
## that reasoning is in the class docs.
##
## No [method Control.accept_event] anywhere in here. Every branch either aims or
## ignores the event, and the engine already treats a press on a
## [code]stop[/code] control as handled — there is nothing left to consume and
## nothing else in the game listening for a pointer.
func _gui_input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		_finger_moved(touch.index, touch.position, touch.pressed)
		return
	var dragged: InputEventScreenDrag = event as InputEventScreenDrag
	if dragged != null:
		_finger_dragged(dragged.index, dragged.position)
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT:
		_finger_moved(MOUSE_FINGER, click.position, click.pressed)
		return
	var moved: InputEventMouseMotion = event as InputEventMouseMotion
	if moved != null:
		_finger_dragged(MOUSE_FINGER, moved.position)


## A finger [param index] going down or coming up at [param at].
##
## [b]The first finger down wins and keeps aiming until it lifts.[/b] A second
## one landing on the car while the first is still there is ignored rather than
## taking over — two fingers cannot aim one tool, and the alternative is a tool
## that snaps between them. And a release only counts from the finger that
## claimed the aim, so lifting a thumb off the motion pad cannot put the
## crosshair away.
func _finger_moved(index: int, at: Vector2, pressed: bool) -> void:
	if pressed:
		if _finger != NO_FINGER:
			return
		_finger = index
		_garage.aim_at(_on_the_glass(at))
		return
	if index != _finger:
		return
	_finger = NO_FINGER
	_garage.release_aim()


## The aiming finger sliding to [param at]. Anything else moving is somebody
## else's finger, or a mouse nobody is holding down.
func _finger_dragged(index: int, at: Vector2) -> void:
	if index != _finger:
		return
	_garage.aim_at(_on_the_glass(at))


## [param where], moved out of this screen's coordinates and into the room's.
##
## The two are the same rectangle today — both are anchored full-rect on the same
## parent — so this is arithmetic that currently changes nothing. It is here
## because "currently" is doing real work in that sentence: the day the room is
## inset, letterboxed or put in a split screen, every aim in the game would be
## off by the inset, and it would look like a bug in the raycast rather than like
## two rectangles that stopped agreeing.
func _on_the_glass(where: Vector2) -> Vector2:
	var into_the_room: Transform2D = _garage.get_global_transform_with_canvas().affine_inverse()
	return into_the_room * (get_global_transform_with_canvas() * where)


## The panel under the crosshair, or [code]""[/code] when the player is not
## aiming at anything.
##
## Debug scaffolding, and deliberately the plainest possible version of it: the
## point is to prove that a press reaches a named piece of the car, which is what
## the grime work will be built on. The label is the first thing to delete when
## something real consumes this.
func _on_aimed(panel: String) -> void:
	_readout.text = panel


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
