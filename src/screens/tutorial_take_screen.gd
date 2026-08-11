## The camera negative of the game: the same bay, filmed rather than played, for
## exactly as long as one [TutorialTake] lasts and then gone.
##
## [b]The whole screen is the room and nothing else.[/b] No HUD, no card, no
## buttons — a tutorial clip is a picture of a tool working on a panel, and every
## control this game has drawn over that picture is a thing that would have to be
## cropped out of the video later. The [Garage] under it is the identical scene the
## title screen and the play screen instance, on the switches that mean "somebody is
## standing in the room": first person, aiming, and — measured rather than chosen —
## silent. [code]src/screens/tutorial_take_screen.tscn[/code] has all four and the
## note on what the tool noise costs at exit.
##
## [b]The take stands in for the player and gets no privileges.[/b] It decides which
## tool to hold and where to point it, and those two answers go in through
## [method ViewModel.belt] and [method Garage.press_the_glass] — the doors a thumb
## uses, the same two the attract mode uses. There is no branch in the trigger, the
## aim, the grime or the score that knows it is being filmed, so a take cannot show
## a wash the game would not have given. It is [code]src/world/garage.gd[/code]'s
## own rule, applied to a second stand-in.
##
## [b]The one thing a player could not do is stand still.[/b] The eye is placed by
## [TutorialFraming] and held there for the take's whole length, through
## [method Garage.stand_at], rather than walked round with the stick. That is the
## deliberate difference between this and the attract mode, and it is the whole
## reason a take is worth filming: a clip that drifted, or that arrived at the panel
## two seconds in, would be teaching around the camera rather than with it.
##
## [b]Which take, and why the command line.[/b] [constant TutorialTake.ARG] names it
## — [code]--take=sponge[/code] after the [code]--[/code] — and
## [code]src/main/main.gd[/code] is what reads it on the way in and boots into
## [TutorialTakeGameState] instead of the title card. The harness that will record
## this footage is a shell line ([code]#221[/code] is the first half of
## [code]#175[/code]), so the way in is a shell line too.
##
## [b]And it takes the process down with it when it is done[/b] — but only when the
## command line is what started it. A screen a test rolled by hand ([method roll])
## films the same take and stops, because a suite that quit the engine two seconds
## into an integration test would fail every test after it and would look like a
## crash.
##
## [b]The only screen in this project with a [code]class_name[/code][/b], and it is
## the test that earns it: every other screen is talked to entirely through
## [GameScreen] and its own nodes, while this one has a seam ([method roll]) that
## has to be reachable with a type on it. The alternative is
## [method Object.call] with a string, which is exactly the untyped hole
## [code]project.godot[/code]'s warning levels exist to close.
class_name TutorialTakeScreen
extends GameScreen

## The colour every take is filmed in — [constant Car.PAINT_COLORS]'s first entry,
## the Viper Red that is also the brand's.
##
## [b]Pinned for the reason the car style is[/b] ([constant TutorialTake.CAR_STYLE]):
## [method Car._ready] draws a colour from five, so the same commit would otherwise
## produce five different films. That export's own docs say the door is the value
## rather than a seeded generator, and this is the value, set once the room exists.
const PAINT: int = 0

## The take being filmed, or [code]null[/code] on a screen nobody asked for one on —
## which is what a screen instanced by a suite, or by somebody who opened the scene
## in the editor, is.
var _take: TutorialTake = null

## Whether [constant TutorialTake.ARG] is what started this. See the class docs on
## why only that screen is allowed to end the process.
var _launched: bool = false

## The panel being worked: the biggest one of the take's own surface, picked once
## the car exists. [method _panel_for] has the argument for "biggest".
var _panel: Node3D = null

## Whether there is mud on the car yet. A take is a film of dirt coming off, so
## there is nothing to film until [signal Garage.grimed] — see [method _on_grimed].
var _muddy: bool = false

@onready var _garage: Garage = $Garage


func _ready() -> void:
	_garage.grimed.connect(_on_grimed)
	var asked: String = TutorialTake.asked_for(OS.get_cmdline_user_args())
	if asked.is_empty():
		return
	_launched = true
	_frame_the_window()
	roll(TutorialTake.named(asked))


## Films [param wanted], starting as soon as there is mud on the car.
##
## [b]The seam this screen is testable through.[/b] [method _ready] calls it with
## whatever the command line asked for; an integration test calls it with a take it
## built itself, because [method OS.get_cmdline_user_args] under GUT is empty and
## there is no honest way to put an argument into a running process. Either way what
## happens next is identical, which is the property that makes the test worth
## anything.
func roll(wanted: TutorialTake) -> void:
	_take = wanted


## The take being filmed, or [code]null[/code]. Public so a test can ask what the
## command line was understood to mean rather than inferring it from the picture.
func take() -> TutorialTake:
	return _take


## The panel being filmed, or [code]null[/code] until there is a car to pick one
## off. Public for [method take]'s reason: a test asking whether the shot is framed
## on the right thing has to be able to name the thing.
func panel() -> Node3D:
	return _panel


## One tick of the film: move the clock, hold the shot, work the panel.
##
## [b]On the physics clock, like everything else this room answers.[/b] The aim is
## resolved in [method Garage._physics_process] and a press recorded after it would
## be answered a tick late — which over a six-second take is a hand that lags the
## sweep by a frame the whole way down the panel.
##
## The shot is re-framed every tick rather than placed once. The answer is a pure
## function of the panel, the car and the lens, none of which move, so this is the
## same position sixty times a second — and it is the version that survives a
## viewport that finished laying itself out a frame after the mud went on, which is
## when the lens gets its real width ([method Lens._fit]).
func _physics_process(delta: float) -> void:
	if _take == null or not _muddy or _panel == null:
		return
	_take.advance(delta)
	_frame_the_shot()
	if _take.working():
		_work_the_panel()
	else:
		_garage.release_aim()
	if _take.finished():
		_cut()


## Puts the eye where [TutorialFraming] says a person filming this panel would
## stand.
func _frame_the_shot() -> void:
	var car: Car = _garage.car()
	_garage.stand_at(
		TutorialFraming.eye_for(car.box_around(_panel), car.bounds(), _garage.eye_fov())
	)


## Holds the tool this beat calls for and presses the glass where the sweep is
## pointed — the two controls a player has, in the order they would use them.
func _work_the_panel() -> void:
	_garage.view_model().belt().equip(_take.tool())
	_garage.press_the_glass(_take.aim_over(_garage.car().box_around(_panel)))


## The take has run out.
##
## Stops the film first and quits afterwards: [method SceneTree.quit] is deferred to
## the end of the frame, so a screen that only asked to quit would go on filming
## until the engine got round to it.
func _cut() -> void:
	_take = null
	_garage.release_aim()
	if _launched:
		get_tree().quit()


## The car has mud on it, so there is something to film: pick the panel, pin the
## paint, and let the clock start.
##
## [b]Everything that has to wait for a car waits here.[/b] Panels have no box until
## a frame after [method Node._ready] — [method Garage._lay_on_the_grime] carries
## that argument — and a shot framed against a zero box would stand the eye in the
## middle of the driveway.
func _on_grimed() -> void:
	var car: Car = _garage.car()
	# Null on a fixture car that was never given a body material — every car the
	# game itself parks has one, and a take is not the place to find out otherwise.
	if car.paint != null:
		car.paint.albedo_color = Car.PAINT_COLORS[PAINT]
	_muddy = true
	if _take == null:
		return
	_panel = _panel_for(car, _take.kind())
	if _panel != null:
		return
	# Said out loud and then ended, rather than waited out. A take with no panel to
	# work would otherwise sit there filming a filthy car until somebody killed it,
	# which is the one failure a capture harness cannot tell from a slow one.
	printerr("tutorial take '%s': this car has no surface of kind %d" % [_take.id(), _take.kind()])
	_cut()


## The panel a take of [param kind] is filmed on: the biggest one the car has of
## that surface.
##
## [b]Biggest, and measured rather than named[/b] — [method Garage._take_up_the_demo]'s
## argument, which is that a list of panel names in a script goes stale the first
## time somebody adds a window. It matters more here than it does there: a take of
## the sponge filmed on a lamp lens would be six seconds of a hand covering the only
## thing in shot.
##
## [code]null[/code] for a car with nothing of that kind on it, which leaves the
## take unfilmed rather than filmed on the wrong panel. Every car in the pack has
## paint and windows; the fixtures a suite parks do not all have both.
func _panel_for(car: Car, kind: Surface.Kind) -> Node3D:
	var best: Node3D = null
	var most: float = 0.0
	for part: Node3D in car.panels():
		if car.kind_of(part) != kind:
			continue
		var volume: float = car.box_around(part).get_volume()
		if best != null and volume <= most:
			continue
		best = part
		most = volume
	return best


## Opens the window at the shape the footage is framed for — see
## [constant TutorialFraming.FRAME], which is what [TutorialFraming] computes the
## lens from.
##
## Skipped where there is no window to size. A headless run has none, and asking a
## display server that is not there is the kind of thing that fails as an error in
## the log rather than as a return value.
func _frame_the_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_size(TutorialFraming.FRAME)
