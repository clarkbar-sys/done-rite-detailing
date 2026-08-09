## Integration test for the end of a run: the clock starting when there is
## something to clean, running out, and taking the player to the board — and the
## run with no clock on it, which ends the one other way there is.
##
## [b]This is the path that had nothing exercising it.[/b] A run is five minutes
## and no headless suite can wait for one, so the play screen carries a
## [code]run_seconds[/code] export set before the node enters the tree — the same
## seam [code]tests/integration/test_play_screen_done.gd[/code] uses to pin the
## car it wants, and the same one [code]src/screens/job_done.gd[/code] gives its
## save path. Nothing in the game sets it.
##
## A suite of its own rather than more cases in
## [code]test_play_screen_done.gd[/code], because a short clock is a property of
## the whole fixture: every test in a suite that pinned one would have its run end
## underneath it, which is exactly what the other suite must not have while it is
## washing a wheel.
##
## [b]And [RunResult] is put back.[/b] It is process-wide by design, so a suite
## that left a finished run in it would hand it to whichever suite runs next.
extends GutTest

const PLAY_SCREEN: String = "res://src/screens/play_screen.tscn"

## Long enough that the clock is demonstrably still running for a frame or two
## after the mud lands, short enough that a handful of frames spends it. The room
## runs at 60 Hz headless, so this is about a dozen frames.
const SHORT_RUN: float = 0.2

## How long to wait for the room to say the mud is on. A signal and not a count of
## frames, and generous for the reason
## [code]test_play_screen_done.gd[/code] records: laying the mud on casts tens of
## thousands of rays and is the longest frame the room will ever have.
const GRIME_TIMEOUT: float = 20.0

## Frames to let the short run expire in, with margin.
const FRAMES: int = 60

var _screen: GameScreen = null
var _requested: Array[GameState] = []
var _window_size_before: Vector2i = Vector2i.ZERO
var _mode_before: GameMode.Kind = GameMode.Kind.ARCADE
var _style_before: String = ""
var _score_before: int = 0
var _patches_before: int = 0
var _finished_before: bool = false


func before_each() -> void:
	_requested = []
	# The mode decides how long a run the screen builds when nothing overrides it,
	# and it is process-wide — so it is snapshotted here and put back below, the
	# same care [RunResult] already gets in this suite.
	_mode_before = GameMode.chosen
	GameMode.forget()
	_style_before = RunResult.style
	_score_before = RunResult.score
	_patches_before = RunResult.patches
	_finished_before = RunResult.finished
	RunResult.forget()
	var root: Window = get_tree().root
	_window_size_before = root.size
	root.size = root.content_scale_size


func after_each() -> void:
	get_tree().root.size = _window_size_before
	GameMode.choose(_mode_before)
	RunResult.remember(_style_before, _score_before, _patches_before, _finished_before)


## Opens the play screen on a run of [param seconds] and waits for the mud.
func _open(seconds: float) -> void:
	await _open_screen(seconds, true)


## Opens it with no override at all, so the length is whatever
## [method GameMode.seconds_for] says [member GameMode.chosen] is worth.
##
## The path the game itself takes, and the only way to exercise it: the sentinel
## the export defaults to is a constant on a screen script rather than on a
## global class, so this file cannot name it — the same reason `run_seconds` is
## written through [method Object.set] below. Not setting it is naming it.
func _open_in_the_chosen_mode() -> void:
	await _open_screen(0.0, false)


## The two above, sharing everything except whether the export is written.
func _open_screen(seconds: float, override: bool) -> void:
	var packed: PackedScene = load(PLAY_SCREEN) as PackedScene
	assert_not_null(packed, "could not load %s" % PLAY_SCREEN)
	if packed == null:
		return
	var screen: GameScreen = packed.instantiate() as GameScreen
	_screen = screen
	# Before add_child, so `_ready` builds the clock from it. The property belongs
	# to the script on the scene's root, which is the one thing in this file the
	# type checker cannot see.
	if override:
		screen.set("run_seconds", seconds)
	_screen.transition_requested.connect(_record)
	add_child_autofree(_screen)
	await wait_for_signal(_garage().grimed, GRIME_TIMEOUT)


func _record(state: GameState) -> void:
	_requested.append(state)


func _garage() -> Garage:
	return _screen.get_node("Garage") as Garage


func _meter() -> TimeHud:
	return _screen.get_node("TimeHud") as TimeHud


func _finish() -> Button:
	return _screen.get_node("%Finish") as Button


func test_the_clock_is_on_screen_showing_the_whole_run() -> void:
	# Read before the mud lands: the meter says five minutes from the first frame
	# rather than appearing once the room is ready.
	await _open(RunClock.SECONDS)
	assert_eq(_meter().shown(), RunClock.whole_seconds(RunClock.SECONDS))


func test_a_full_run_does_not_end_in_the_first_few_frames() -> void:
	await _open(RunClock.SECONDS)
	await wait_process_frames(5)
	assert_eq(_requested.size(), 0, "five minutes went by rather fast")


func test_the_clock_runs_out_and_the_run_ends() -> void:
	await _open(SHORT_RUN)
	await wait_process_frames(FRAMES)
	assert_eq(_requested.size(), 1, "the clock ran out and nothing happened")
	if _requested.is_empty():
		return
	assert_eq(_requested[0].id, JobDoneGameState.ID, "it went somewhere other than the board")


func test_the_run_is_written_down_for_the_board() -> void:
	await _open(SHORT_RUN)
	await wait_process_frames(FRAMES)
	assert_true(RunResult.handed_in(), "the board has nothing to report")
	assert_false(RunResult.style.is_empty(), "and does not know which car it was on")


func test_a_run_the_clock_ended_is_not_recorded_as_a_finished_car() -> void:
	await _open(SHORT_RUN)
	await wait_process_frames(FRAMES)
	assert_false(RunResult.finished, "running out of time is not finishing the car")


func test_the_run_ends_once_and_not_once_a_frame() -> void:
	# `set_process(false)` is what makes this true, and it is the difference
	# between one transition and one per frame for the rest of the screen's life.
	await _open(SHORT_RUN)
	await wait_process_frames(FRAMES)
	assert_eq(_requested.size(), 1, "the screen asked to be replaced %d times" % _requested.size())


func test_a_run_that_cleaned_nothing_still_ends() -> void:
	# Nothing here touches the car, so the score is zero — the run still has to
	# end, and the board still has to be where it goes. HighScores.placed is what
	# decides a nothing does not get a place on it, not this.
	await _open(SHORT_RUN)
	await wait_process_frames(FRAMES)
	assert_eq(RunResult.score, 0)
	assert_true(RunResult.handed_in())


# ---- the run with no clock on it ---------------------------------------------
#
# What the simulation actually is, from the screen's side: the same bay, the same
# room, the same everything, built with a length that never reaches zero. These
# open with no `run_seconds` override at all, so what is being exercised is the
# path the game itself takes — the mode is read off [GameMode] on the way up.


func test_the_arcade_builds_the_clock_the_mode_asks_for() -> void:
	GameMode.choose(GameMode.Kind.ARCADE)
	await _open_in_the_chosen_mode()
	assert_eq(_meter().shown(), RunClock.whole_seconds(RunClock.SECONDS))


func test_the_simulation_opens_with_no_clock_on_the_meter() -> void:
	GameMode.choose(GameMode.Kind.SIMULATION)
	await _open_in_the_chosen_mode()
	assert_eq(_meter().shown(), RunClock.FOREVER, "the meter is counting something")
	assert_eq(_meter().text, RunClock.FOREVER_SIGN)


func test_a_simulation_run_does_not_end_on_its_own() -> void:
	# The claim the whole mode rests on. Sixty frames is three hundred times the
	# length the arcade cases above run out in.
	GameMode.choose(GameMode.Kind.SIMULATION)
	await _open_in_the_chosen_mode()
	await wait_process_frames(FRAMES)
	assert_eq(_requested.size(), 0, "a run with no clock on it ended by itself")


func test_only_the_untimed_run_carries_the_way_out() -> void:
	# The pill is the simulation's exit and nothing else's: an arcade run already
	# ends on its own, and this screen reads a tap anywhere as an aim, so a button
	# it does not need is a hole in the car.
	GameMode.choose(GameMode.Kind.ARCADE)
	await _open_in_the_chosen_mode()
	assert_false(_finish().visible, "the arcade must not offer a way to end a run early")


func test_the_untimed_run_carries_a_way_out() -> void:
	GameMode.choose(GameMode.Kind.SIMULATION)
	await _open_in_the_chosen_mode()
	assert_true(_finish().visible, "a run nothing can end must offer a way to end it")


func test_the_way_out_is_big_enough_for_a_finger() -> void:
	# The floor everything a finger has to hit clears — see [TouchTarget]. This is
	# the only control on the play screen that is a pill rather than a plate, and
	# it is the one a player presses exactly once.
	GameMode.choose(GameMode.Kind.SIMULATION)
	await _open_in_the_chosen_mode()
	var minimum: float = TouchTarget.min_design_size()
	assert_gte(_finish().size.x, minimum, "the way out is too narrow to hit on a phone")
	assert_gte(_finish().size.y, minimum, "the way out is too short to hit on a phone")


func test_the_way_out_is_a_brand_pill_rather_than_the_theme_button() -> void:
	GameMode.choose(GameMode.Kind.SIMULATION)
	await _open_in_the_chosen_mode()
	var box: StyleBoxFlat = _finish().get_theme_stylebox("normal") as StyleBoxFlat
	assert_not_null(box, "the way out must be dressed by Brand")
	if box == null:
		return
	assert_eq(box.bg_color, Brand.PANEL, "the one red thing on this screen is the clock")


func test_pressing_it_ends_the_run() -> void:
	GameMode.choose(GameMode.Kind.SIMULATION)
	await _open_in_the_chosen_mode()
	_finish().pressed.emit()
	assert_eq(_requested.size(), 1, "the job was not handed in")
	if _requested.is_empty():
		return
	assert_eq(_requested[0].id, JobDoneGameState.ID, "it went somewhere other than the board")


func test_a_job_handed_in_half_done_is_not_a_finished_car() -> void:
	# Nothing here touches the car, so pressing the pill is a player walking away
	# from a car with mud all over it. The board is entitled to say so.
	GameMode.choose(GameMode.Kind.SIMULATION)
	await _open_in_the_chosen_mode()
	_finish().pressed.emit()
	assert_true(RunResult.handed_in(), "the board has nothing to report")
	assert_false(RunResult.finished, "walking away is not finishing the car")


func test_the_job_is_handed_in_once_and_not_once_a_frame() -> void:
	# `set_process(false)` again, from the other ending: the frame callback is off
	# before the transition, so the poll that would also have ended the run on the
	# next frame never runs.
	GameMode.choose(GameMode.Kind.SIMULATION)
	await _open_in_the_chosen_mode()
	_finish().pressed.emit()
	await wait_process_frames(5)
	assert_eq(_requested.size(), 1, "the screen asked to be replaced %d times" % _requested.size())
