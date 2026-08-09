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
## other. That seam has already been cashed in once: the pad was four arrow
## buttons and is now a thumb stick, and nothing in this file or the room changed
## — which is the whole reason the thing crossing here is two numbers in
## [code]-1..1[/code] rather than a button.
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
## somewhere and a mark on the paint. What crosses is a [Vector2] and
## nothing else: the room has never heard of a touch event, and this file has
## never heard of a camera, a ray or a car panel.
##
## Holding is firing and letting go is not, which is why there are only two calls
## — [method Garage.aim_at] while the finger is down and
## [method Garage.release_aim] when it lifts. Nothing sprays yet. When something
## does, it goes on the far end of those two and nothing here changes.
##
## [b]The [Vector2] that crosses is not quite where the finger is[/b], and that
## is this file's one piece of judgement about the trigger rather than an
## accident. A thumb covers the part of the screen it is touching, so an aim
## taken at the contact point puts the mark — and later the spray, and later
## still the patch of grime the player is trying to watch disappear — underneath
## the hand asking for it. [ThumbLift] moves the aim a thumb's width up the glass
## before it is handed over; [method _aim_point] is where that happens, and it
## happens to touches only, because a mouse cursor hides nothing. The room is
## never told: it is still a point on the glass, and which point is a question
## about hands, which is this file's half of the split and not the room's.
##
## [b]Pointer input arrives in [method Control._gui_input] and not in
## [method Node._unhandled_input], where the keys are, and the difference is
## worth knowing before moving any of it.[/b] A [Control] at the default
## [code]stop[/code] filter is the topmost thing under every touch that is not on
## a button, and the GUI system hands the event to [i]it[/i] rather than letting
## the event go unhandled. This screen is such a control, so this is where its
## taps go. The belt's icons still get their own taps first — they are separate
## controls and the hit test finds them before it reaches this one — and the
## motion pad's stick gets in earlier still, by claiming the touches that land on
## it in [method Node._input], before the GUI pass runs at all. Both of those are
## the same rule from two directions: a press that belongs to the HUD is not an
## aim.
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
## [i]first[/i] finger. So a thumb parked on the pad's stick would eat the
## emulation and a second finger on the car would produce no mouse event
## whatsoever: walk and aim, the two things a player does at once, would be
## mutually exclusive. The fix is to read the touch events themselves and ignore
## the emulated mice, which is exact rather than a heuristic —
## [constant InputEvent.DEVICE_ID_EMULATION] is the engine's own mark on an event
## it invented. Mouse events that are not emulated are somebody at a desk, and
## they are handled too.
##
## [b]And the fourth loop is the bell[/b], which is the same shape read
## backwards. The room says a patch of the car finished a step of the job
## ([signal Grime.patch_finished]),
## this file turns that into "ring the small one", and the host's [Chime] is what
## actually makes the noise. The room has never heard of a speaker and this file
## has never heard of an [AudioStreamPlayer] — what crosses is a [enum Bell.Voice]
## and nothing else, and it goes up to the host rather than sideways because a
## screen is freed the moment it asks for the next state.
##
## [b]And the fifth loop is the score[/b], which is the only one that runs both
## ways at once, and deliberately so. [Scoring] turns what the room reports into
## a number and [ScoreHud] turns that into digits in the corner; neither has
## heard of the other — the scorer has never heard of a [Label] and the readout
## has never heard of a [Grime] — and this is the only file that knows both
## exist. What is different is that it is fed from two places, because there are
## two different kinds of thing to be paid for.
##
## [b]Finishing a patch is an instant, so it is a signal.[/b] The room says a
## patch finished a step, this file scores it and rings the bell for it, and the
## corner flashes. The order in [method _on_patch_finished] is not arbitrary: the
## score is taken before the bell is asked for, because both climb the same run
## of consecutive patches on the same clock and reading one after ringing the
## other would put a frame's worth of nothing between two things that are one
## event. [Chime]'s class docs have why the two count their runs separately
## rather than one reading the other's.
##
## [b]Cleaning is true across frames, so it is polled.[/b] Mud coming off is not
## a moment — it is what is happening for as long as the trigger is down — so
## [method _pay_for_the_work] reads a running total off the room once a frame and
## pays for the difference, which is the same treatment the walk gets two
## paragraphs up and for the same reason. That is what makes the corner climb
## while a panel is being washed instead of sitting still between patches, and it
## is why the readout has a second, quieter entry point that neither flashes nor
## pops.
##
## [b]And the sixth loop is the end of the run[/b], which is the only one that
## happens once. The clock counts down and the room reports how far along the job
## is; when either of them is out, the run is written down in [RunResult] and the
## screen asks to be replaced by [JobDoneGameState]. See
## [method _hand_in_the_job].
##
## [b]A run ends two ways, and in the arcade the clock is the one that actually
## fires.[/b] [RunClock] gives the player five minutes, and [method Grime.shine]
## reaching one ends it early — finishing the whole car is about a thousand
## patches, so that is the win condition rather than the usual one. Both land in
## the same place and the only difference downstream is a heading:
## [method RunResult.remember] carries which it was.
##
## The clock is the reason there is a run at all rather than an afternoon. It
## makes the question "how much can you get done" instead of "will you get it
## done", which is the question a score answers and the one two players can
## compare — [RunClock] has the rest of that argument, and the number is on it
## rather than here.
##
## [b]Which leaves the third ending, and it is the one the simulation needs.[/b]
## A run at [constant RunClock.UNTIMED] has no clock to fire, so without
## something else the only way out of the bay is a thousand patches or the
## browser's reload button — a room the player cannot leave. So an untimed run
## gets one control the timed one does not: a pill that hands the job in where it
## stands. It is the same exit through the same function; what it is not is a
## pause, and the paragraph at the bottom of these docs about a Back button still
## stands, because handing the job in is a run [i]ending[/i] rather than a run
## being suspended.
##
## [b]The pill is only there when there is no clock[/b], and that is not tidiness
## either. An arcade run already ends on its own, so a button that ended it early
## would be a way to throw a run away by fumbling the glass — and this screen
## reads a tap anywhere as an aim, which makes every control on it a hole in the
## car. One hole, in the mode that cannot do without it.
##
## [b]It is started on [signal Garage.grimed] and not in [method Node._ready].[/b]
## Laying the mud on casts tens of thousands of rays at the car and is the longest
## frame the room will ever have, so a clock running from the moment the screen
## exists would charge the player for a load. The first instant there is anything
## to clean is the first instant the meter should be running.
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

## Walks the eye left around the car: the keyboard's half of pushing the pad's
## stick left.
const TURN_LEFT_ACTION: String = "camera_left"

## Walks it right.
const TURN_RIGHT_ACTION: String = "camera_right"

## Raises the eye.
const LIFT_UP_ACTION: String = "camera_up"

## Lowers it.
const LIFT_DOWN_ACTION: String = "camera_down"

## Shows or hides the grime masks. Keyboard only and deliberately so: it is a
## developer's view of a texture, and a phone has no spare key to press by
## accident.
const GRIME_DEBUG_ACTION: String = "grime_debug"

## No finger is on the glass. Not a touch index the engine can ever hand out, so
## it cannot collide with a real one.
const NO_FINGER: int = -1

## The stand-in index for a mouse held down at a desk, so one variable can track
## "who is aiming" whether that is a finger or a pointer. Also not a touch index
## the engine hands out, and distinct from [constant NO_FINGER] — a mouse that
## shared the "nobody" value would be released by the first stray touch.
const MOUSE_FINGER: int = -2

## How much shine counts as the whole car being finished — see
## [method _hand_in_the_job].
##
## [b]Not 1.0, and the missing ten-thousandth is not superstition.[/b]
## [method Grime.shine] is a mean of seven panels' means over tens of thousands
## of texels, every one of them a float, so a car whose last texel has genuinely
## been buffed can read a hair under one — which is why
## [code]tests/integration/test_play_screen_done.gd[/code] asserts that reading
## with a tolerance rather than for equality. A run that ended on exactly 1.0 or
## not at all would be a run whose one win condition mostly did not fire. The gap
## it leaves is about a tenth of what one patch of a thousand-patch car is worth,
## so a car with anything left on it cannot reach this either.
const FINISHED: float = 0.9999

## What [member run_seconds] means when nobody has overridden it: ask the mode.
##
## A negative length rather than a zero one, because zero is a run that is over
## before it starts and a suite is entitled to ask for exactly that.
## [method _run_length] — the one reader — takes any negative length to mean the
## same thing, so this is the value the export ships with rather than a magic
## number that has to be matched exactly.
const AS_THE_MODE_SAYS: float = -1.0

## How long this run gets, in seconds, or [constant AS_THE_MODE_SAYS] to let
## [method GameMode.seconds_for] decide.
##
## [b]An export purely so a suite can run a whole run out in a frame.[/b] Five
## minutes of real time is not a thing a headless test can wait for, and the end
## of a run is the one path on this screen that had nothing exercising it. Set
## before the node enters the tree, the same seam
## [code]src/screens/job_done.gd[/code] gives its save path and
## [code]tests/integration/test_play_screen_done.gd[/code] uses to pin the car it
## wants. Nothing in the game ever sets it — what the game sets is the mode, one
## screen earlier.
@export var run_seconds: float = AS_THE_MODE_SAYS

var _belt: ToolBelt = null
var _finger: int = NO_FINGER

## The meter. Built here rather than read off anything, for [member _score]'s
## reason below: the room is also what the title card is showing off, and an
## attract mode with a clock on it would be a demo that ends.
##
## Stopped until [method _on_grimed] starts it — see [RunClock] and the class
## docs.
var _clock: RunClock = null

## The running score. Built here rather than read off anything, because unlike
## the belt there is nothing else in the game that has one — and unlike the belt
## it is this screen's, not the room's: the room is also what the title card is
## showing off, and an attract mode that quietly ran up a score would hand the
## player a number they did not earn. [code]src/screens/title_screen.gd[/code]
## leaves [signal Grime.patch_finished] unconnected for the same reason.
var _score: Scoring = Scoring.new()

## How much work each stage had had done on it when this screen last looked, in
## patches' worth — [method Grime.worked]'s units. What
## [method _pay_for_the_work] takes the difference against, and the reason the
## wage is paid once per frame rather than once per touch.
##
## Sized off the enum rather than off a literal three, so a fourth pass is a
## tariff somebody has to write rather than an out-of-range on the first frame.
var _worked: PackedFloat64Array = _fresh_work()

@onready var _garage: Garage = $Garage
@onready var _hud: ToolBeltHud = $ToolBelt
@onready var _pad: MotionPad = $MotionPad
@onready var _readout: Label = $PanelReadout
@onready var _masks: GrimeDebug = $GrimeDebug
@onready var _scoreboard: ScoreHud = $ScoreHud
@onready var _meter: TimeHud = $TimeHud
@onready var _finish: Button = %Finish


func _ready() -> void:
	# Read rather than built — see the class docs on why there is exactly one.
	# The viewmodel is a descendant of the garage, so its `_ready()` has already
	# run by the time this one does and the belt is there to be taken.
	_belt = _garage.view_model().belt()
	_hud.bind(_belt)
	_hud.tool_selected.connect(_on_tool_selected)
	_garage.aimed.connect(_on_aimed)
	_garage.grimed.connect(_on_grimed)
	_masks.debug_tools_toggled.connect(_on_debug_tools_toggled)
	# In the same face as the score in the opposite corner. It is scaffolding, but
	# it is scaffolding a player can see, and one label in the project's default
	# readable face beside a HUD that is not would read as the one thing on the
	# screen that had been forgotten — which is exactly what it would be.
	_readout.add_theme_font_override("font", Brand.DISPLAY_FACE)
	_readout.text = ""
	# Built here and not in the member above, because the length is an export and
	# an export is only the scene's value once the node has been instanced.
	_clock = RunClock.new(_run_length())
	_meter.show_time(_clock.left())
	# The way out of a run nothing else can end — see the class docs. Dressed
	# quiet rather than loud because the one red thing on this screen is the
	# clock's last thirty seconds, and a run with no clock on it should not be
	# shouting about the way out of itself.
	dress_quiet(_finish)
	_finish.visible = not _clock.is_timed()
	_finish.pressed.connect(_on_finish_pressed)


## Hands the room what the player is asking for, every frame.
##
## Every frame including the ones where nothing is held: "stop" is an intent like
## any other, and a screen that only spoke up when something was pressed would
## leave the camera coasting on the last thing it heard.
##
## The two input sources are summed and the room clamps the total, so holding the
## right arrow key with the stick already pushed right walks at one speed rather
## than two. [method Input.get_axis] is the engine's own idiom for a held pair and
## returns the same [code]-1..1[/code] the pad does — the difference being that a
## key is only ever at an end of that range and a thumb can be anywhere in it.
func _process(delta: float) -> void:
	var turn: float = _pad.turn() + Input.get_axis(TURN_LEFT_ACTION, TURN_RIGHT_ACTION)
	var lift: float = _pad.lift() + Input.get_axis(LIFT_DOWN_ACTION, LIFT_UP_ACTION)
	_garage.steer(turn, lift)
	var grime: Grime = _garage.grime()
	# Only while the masks are up. The number costs a walk over every panel of the
	# car and nothing is reading it otherwise, so a game nobody has pressed the key
	# in does not pay for the readout.
	if _masks.is_shown() and grime != null:
		_masks.report(grime.remaining(), grime.shine())
	_show_how_far_along(grime)
	_pay_for_the_work(grime)
	_run_the_clock(delta)
	# Last, and nothing after it: this is the call that can free the screen this
	# function is running on.
	_hand_in_the_job(grime)


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
	if event.is_action_pressed(GRIME_DEBUG_ACTION):
		_masks.toggle()
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
## mark away.
func _finger_moved(index: int, at: Vector2, pressed: bool) -> void:
	if pressed:
		if _finger != NO_FINGER:
			return
		_finger = index
		_garage.aim_at(_on_the_glass(_aim_point(index, at)))
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
	_garage.aim_at(_on_the_glass(_aim_point(index, at)))


## Where a pointer [param index] touching down at [param at] is actually aiming.
##
## [b]A thumb aims above itself and a mouse aims at itself.[/b] [ThumbLift] has
## the whole argument; the part that belongs here is why the two cases are told
## apart at all, and it is that the screen already knows which is which.
## [constant MOUSE_FINGER] is a real distinction the trigger has been making since
## the day both hands had to work, so asking it one more question costs nothing
## and no heuristic is being invented to answer it.
##
## In this screen's coordinates and before [method _on_the_glass], because that
## is the order the two facts are true in: the thumb is on this screen's glass,
## and where this screen's glass lands in the room is the next question.
func _aim_point(index: int, at: Vector2) -> Vector2:
	if index == MOUSE_FINGER:
		return at
	return ThumbLift.aim_from(at, _thumb_lift())


## [constant ThumbLift.REFERENCE_PX], in this screen's design pixels.
##
## Read every press rather than cached in [method Node._ready], and that is not
## caution: the web build is resized by the browser and rotated by the player,
## and [code]window/stretch/aspect[/code] is [code]expand[/code], so the scale
## below really does change under a running game. A lift measured once at startup
## would be a thumb's width in portrait and something else entirely after the
## first turn of the phone. It is two engine reads and a division, once per press
## or drag event, against a raycast on every physics tick.
func _thumb_lift() -> float:
	return ThumbLift.design_lift(
		get_viewport().get_final_transform().get_scale().y, DisplayServer.screen_get_scale()
	)


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


## The panel under the mark, or [code]""[/code] when the player is not
## aiming at anything.
##
## Debug scaffolding, and deliberately the plainest possible version of it: the
## point is to prove that a press reaches a named piece of the car, which is what
## the grime work will be built on. The label is the first thing to delete when
## something real consumes this.
func _on_aimed(panel: String) -> void:
	_readout.text = panel


## The car has mud on it, so the debug view has something to draw.
##
## Bound on the signal rather than in [method _ready] because the masks do not
## exist for a frame after the room does — [method Garage._lay_on_the_grime] has
## why — and a view that bound early would draw an empty grid for the whole game.
func _on_grimed() -> void:
	var grime: Grime = _garage.grime()
	_masks.bind(grime)
	# Bound here rather than in `_ready()` for the same reason the masks are: the
	# grime does not exist until this fires, so there is nothing to listen to
	# before it.
	grime.patch_finished.connect(_on_patch_finished)
	# And this is the first instant there is anything to clean, which is the first
	# instant the meter should be running. See the class docs.
	_clock.start()


## A bit of the car finished a step of the job, so the player hears about it,
## sees it in the corner, and gets paid for it.
##
## What stops a sweep of the jet from being a hundred bells is [Chime], which
## drops any ding landing inside the last one: the rule about how often a sound
## is worth making belongs with the thing making it, not with every place that
## asks. Nothing drops an [i]award[/i] — the money is for the work and not for
## the noise — which is why the score and the ding are different counts over a
## fast sweep, and [ScoreHud]'s class docs have why that is the honest way round.
##
## [b]The same bell for all three stages[/b], washed, foamed and buffed alike.
## There are two voices in [enum Bell.Voice] and one of them is Start, so a bell
## per stage would mean writing two more — and what the player is being told is
## the same thing in all three cases: the pass you are on just finished a bit of
## the car. A distinct chime for the buff is worth having the day the shine is
## worth celebrating separately from the wash; it is not a thing to invent
## alongside the mechanic it would be rewarding.
##
## [b]The stage is used and the other two arguments still are not.[/b] Which pass
## finished decides what the patch pays and what colour the corner throws —
## [method Scoring.points_for] and [method ScoreHud.tint_for] have both — while
## the panel and the patch remain the sight's business to have already made
## obvious. The bell is unchanged: it says "that worked" in one voice for all
## three, and the paragraph above is still the argument for that.
func _on_patch_finished(_panel: String, _patch: int, stage: GrimeMap.Stage) -> void:
	var award: int = _score.score(stage)
	_scoreboard.score(_score.total(), award, stage, _score.multiplier())
	ring_bell(Bell.Voice.PATCH)


## Puts how far through the job the car is in the corner, if [param grime] exists
## yet.
##
## [b]Polled, and it is the fourth thing on this screen that is[/b] — after the
## walk, the wage and the readout above. Cleaning is true across frames rather than
## being an event, so the number is read off a running total once a frame; the
## alternative is [Grime] emitting a float sixty times a second per tool, which is
## exactly what [signal Garage.aimed] is shaped the way it is to avoid. The class
## docs make the same distinction three times already and this is its fourth
## instance.
##
## [method Grime.progress] rather than [method Grime.shine], and the swap is
## deliberate in both directions. Shine only rises under the rag, so a readout on
## it sat at zero through the washing and the foaming — two thirds of the job in
## which the corner told a player holding the jet that nothing was happening.
## Progress counts the three passes equally, so it climbs under every tool in the
## belt; and it still only ever rises and still reaches one on exactly the stroke
## that finishes the car, so nothing the shine reading promised the readout has
## been given up. Not [method Grime.remaining] for the old reason either way: a
## bar that read "done" when the mud came off would be lying about two passes.
##
## The run's end stays on [method Grime.shine] — see [method _hand_in_the_job] —
## because "finished" is every unit in the last bucket and nothing less, and the
## two numbers agree at exactly that moment.
##
## The cost is a walk over the car's seven maps adding seven floats, which is why
## it is not gated behind the debug view the way the mask report above it is: this
## one the player can see.
func _show_how_far_along(grime: Grime) -> void:
	if grime == null:
		return
	_scoreboard.done(grime.progress())


## Ends the run if the clock is out or [param grime] says the car is finished:
## writes down what it was worth and asks for the screen that puts it on the
## board.
##
## [b]Two ends, one exit.[/b] Which one it was is carried on
## [member RunResult.finished] and changes nothing else — the score is the score,
## and a car finished at 1:20 and a car half done at 0:00 go onto the same board
## by the same rule.
##
## [b]Polled, like the four things above it[/b], and for the same reason rather
## than for want of a signal. [Grime] emits [signal Grime.patch_finished] per
## patch and has nothing to say about the car as a whole; "every panel is done"
## is a property of a running total, so it is read off one once a frame exactly
## as the walk, the wage and the percentage are. A signal for it would be a
## seventh thing [Grime] has to know it is being asked, to answer a question the
## number it already publishes answers. The clock is the same shape from the
## other direction: a [Timer] node would be a second clock in the tree, running
## on a callback this screen would then have to reconcile with the frame it is
## already reading everything else on.
##
## [b][method Node.set_process] first, and it is not tidiness.[/b]
## [method GameScreen.request_transition] reaches the host synchronously and the
## host removes and frees this screen on the next line, so this is a function
## that deletes the node it is running in. Turning the frame callback off first
## means that even if the free is deferred a frame — which it is, [method
## Node.queue_free] is — there is no second pass through here asking for a second
## transition. The alternative, a [code]_handed_in[/code] flag, is a second piece
## of state saying what the disabled callback already says.
##
## The style is read off the room rather than off [member CarChoice.chosen], for
## the reason [code]src/screens/main_menu.gd[/code] reads it that way too: the
## car in the bay is the answer, and a remembered one is free to disagree with it.
func _hand_in_the_job(grime: Grime) -> void:
	var whole: bool = _is_finished(grime)
	if not whole and not _clock.is_up():
		return
	_hand_it_in(whole)


## Writes the run down and asks for the board. The last thing this screen does,
## from whichever of the endings got here.
##
## Split out of [method _hand_in_the_job] when the simulation's pill arrived, so
## that "the run is over" is written once: the polled ending and the pressed one
## are the same three lines, and a second copy of them is a second place to
## forget [method Node.set_process] — which is the line that stops this being
## called once a frame for the rest of the screen's life.
func _hand_it_in(whole: bool) -> void:
	set_process(false)
	RunResult.remember(_parked_style(), _score.total(), _score.patches(), whole)
	request_transition(JobDoneGameState.new())


## The pill an untimed run carries: the job, handed in where it stands.
##
## [b]It still asks whether the car is finished[/b] rather than reporting a
## handed-in run as unfinished on principle. A player who presses this on the
## stroke that completes the last panel has finished the car, and the board
## should say so — [method RunResult.remember] carries the difference and
## [code]src/screens/job_done.gd[/code] is the only thing that reads it.
func _on_finish_pressed() -> void:
	_hand_it_in(_is_finished(_garage.grime()))


## Whether [param grime] says the whole car is done — see [constant FINISHED].
##
## One definition, because two callers now ask and a run that ended "finished" by
## one arithmetic and "unfinished" by the other would be a heading nobody could
## reproduce.
func _is_finished(grime: Grime) -> bool:
	return grime != null and grime.shine() >= FINISHED


## How long this run gets: what the scene was told, or what the mode says.
##
## The override is the export above and the reason it exists is a headless suite;
## the mode is what the player picked on the menu. Read here rather than in
## [method Node._ready] so the two sources have one place they are reconciled,
## and so the reconciliation is a line a test can point at.
func _run_length() -> float:
	if run_seconds < 0.0:
		return GameMode.seconds_for(GameMode.chosen)
	return run_seconds


## Which of the ten is parked in the bay, or [code]""[/code] for a room parking
## something that is not one of them — which is every fixture under
## [code]tests/fixtures/[/code], and reads as a run on no car rather than a crash
## on the way to the board.
func _parked_style() -> String:
	var parked: MeshCar = _garage.car() as MeshCar
	return "" if parked == null else parked.style


## Spends [param delta] off the meter and puts what is left on screen.
##
## [b]Polled, and it is the fifth thing on this screen that is.[/b] A countdown
## is a quantity being spent at the rate the frames arrive, which is the same
## shape as the walk and the wage rather than a different one — and reading it
## off the frame is what stops the clock and the game disagreeing about how long
## a hitch was. [TimeHud] does its own once-a-second early-out, so handing it a
## float sixty times a second costs a comparison.
##
## A no-op before [method _on_grimed] has started the clock. See [RunClock].
func _run_the_clock(delta: float) -> void:
	_clock.tick(delta)
	_meter.show_time(_clock.left())


## A tally of nothing done, one entry per stage of the job.
static func _fresh_work() -> PackedFloat64Array:
	var work: PackedFloat64Array = PackedFloat64Array()
	work.resize(GrimeMap.Stage.size())
	return work


## Pays for whatever cleaning happened since the last frame, if [param grime]
## exists yet.
##
## [b]Polled rather than signalled, and that is the same rule the walk follows
## rather than an inconsistency.[/b] Finishing a patch happens at an instant, so
## it is a signal. Cleaning is a thing that is [i]true across frames[/i] — the
## trigger is held, water is landing, mud is coming off — so it is read once a
## frame off a running total, exactly the way a direction is read off the pad and
## the keys. The class docs make the same distinction about tool changes and
## movement; this is its third instance.
##
## The alternative is a signal per touch, which is [Grime] emitting sixty times a
## second per tool, carrying a float, for a readout — the precise thing
## [signal Garage.aimed] exists in its current shape to avoid.
##
## Three stages and three remembered totals rather than one, because a rag and a
## jet pay different rates and a sweep can be moving both at once — the player
## buffing one hand's width while the other end of the panel is still under
## water. Summing them first would pay the whole lot at whichever tariff was
## asked for last.
func _pay_for_the_work(grime: Grime) -> void:
	if grime == null:
		return
	var earned: int = 0
	for stage: int in _worked.size():
		var done: float = grime.worked(stage)
		# The difference and not the total: this is a wage paid on work that has
		# happened since the last look, and a fall — which cannot happen, see
		# [method Grime.worked] — pays nothing rather than clawing anything back.
		earned += _score.work(stage, done - _worked[stage])
		_worked[stage] = done
	if earned > 0:
		_scoreboard.tick(_score.total())


## The "Debug Tools" switch inside the "~" panel was flipped, so every tool
## trades the effect it draws for itself for the bare crosshair — see
## [member Garage.debug_tools] — or takes it back. Forwarded rather than read
## straight off [GrimeDebug] every tick, for the same reason every other loop on
## this screen is a signal: the two things only have to agree the instant one
## changes, not be polled to stay that way.
func _on_debug_tools_toggled(enabled: bool) -> void:
	_garage.debug_tools = enabled


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
