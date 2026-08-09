## Unit test for [RunResult] — the three numbers a finished run leaves behind for
## the screen that reports it.
##
## Under [code]tests/unit/[/code] because it is three static fields and no
## [SceneTree] anywhere. What actually crosses on them — the play screen writing
## and the board reading — is
## [code]tests/integration/test_job_done.gd[/code]'s.
##
## [b]Every test here puts it back.[/b] The fields are process-wide by design, so
## a suite that set one and walked away would hand it to whichever suite runs
## next, and the symptom would be a job-done test reporting a score nothing in its
## own file mentions. The same care [code]tests/unit/test_car_choice.gd[/code]
## already takes over the chosen car.
extends GutTest

const STYLE: String = "sedan"
const SCORE: int = 4200
const PATCHES: int = 37

var _style_before: String = ""
var _score_before: int = 0
var _patches_before: int = 0
var _finished_before: bool = false


func before_each() -> void:
	_style_before = RunResult.style
	_score_before = RunResult.score
	_patches_before = RunResult.patches
	_finished_before = RunResult.finished
	RunResult.forget()


func after_each() -> void:
	RunResult.remember(_style_before, _score_before, _patches_before, _finished_before)


func test_nothing_has_been_handed_in_to_start_with() -> void:
	assert_false(RunResult.handed_in())
	assert_eq(RunResult.score, 0)
	assert_eq(RunResult.patches, 0)
	assert_false(RunResult.finished)


func test_remembering_a_run_records_all_four() -> void:
	RunResult.remember(STYLE, SCORE, PATCHES, true)
	assert_eq(RunResult.style, STYLE)
	assert_eq(RunResult.score, SCORE)
	assert_eq(RunResult.patches, PATCHES)
	assert_true(RunResult.finished)


func test_a_run_the_clock_ended_is_not_a_finished_car() -> void:
	RunResult.remember(STYLE, SCORE, PATCHES, false)
	assert_false(RunResult.finished, "a timeout must not read as a finished car")
	assert_true(RunResult.handed_in(), "but it is still a run that happened")


func test_a_remembered_run_has_been_handed_in() -> void:
	RunResult.remember(STYLE, SCORE, PATCHES, true)
	assert_true(RunResult.handed_in())


func test_a_run_on_no_car_has_not_been_handed_in() -> void:
	# What a room with no MeshCar in it produces — every fixture under
	# tests/fixtures/ is one. A board with nothing new on it, rather than a crash.
	RunResult.remember("", SCORE, PATCHES, false)
	assert_false(RunResult.handed_in())


func test_a_second_run_replaces_the_first() -> void:
	RunResult.remember(STYLE, SCORE, PATCHES, true)
	RunResult.remember("coupe", 1, 2, false)
	assert_eq(RunResult.style, "coupe")
	assert_eq(RunResult.score, 1)


func test_forgetting_puts_it_back_to_where_a_game_starts() -> void:
	RunResult.remember(STYLE, SCORE, PATCHES, true)
	RunResult.forget()
	assert_false(RunResult.handed_in())
	assert_eq(RunResult.score, 0)
	assert_eq(RunResult.patches, 0)
	assert_false(RunResult.finished)
