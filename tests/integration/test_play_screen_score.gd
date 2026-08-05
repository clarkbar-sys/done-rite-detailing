## Integration test for the fifth loop on the play screen: a patch of the car
## finishing a step of the job turns into points in the corner.
##
## [b]Through [code]main.tscn[/code][/b] for the reason
## [code]tests/integration/test_play_screen_trigger.gd[/code] records at length,
## and here for a second reason of its own: the thing most worth pinning is that
## the score and the bell agree about a run, and the bell lives on the host. A
## suite that instanced the play screen alone would have a scoreboard and no
## [Chime] to check it against.
##
## What is asserted is the wiring and the agreement, not the tariff. What a patch
## pays is [code]tests/unit/test_scoring.gd[/code]'s, and how the digits get
## there is [code]tests/integration/test_score_hud.gd[/code]'s; nothing here
## repeats either.
##
## [b]The title screen is checked too, and that is not scope creep.[/b] The room
## is one scene and the title card plays the game behind itself as an attract
## mode — so "the score is the play screen's" is a claim about a file that is not
## this one, and the failure it prevents is a player pressing Start onto a total
## the attract mode ran up for them.
extends GutTest

const MAIN: String = "res://src/main/main.tscn"

## Above GUT's own output layer, so a finger aimed at the game lands on the game.
const ABOVE_THE_RUNNER: int = 200

## Enough frames for the room, its grime and the screen's bindings to exist.
const SETTLE_FRAMES: int = 90

## How many sweeps of a whole-face wash it takes to be sure patches finished.
## The same shape [code]test_play_screen_wash.gd[/code] uses, and for the same
## reason: how long a jet takes is a tuning number and waiting for it by the
## clock would go red the day somebody turns the water down.
const SWEEPS: int = 60

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


func after_each() -> void:
	get_tree().root.size = _window_size_before


## Walks in through the front door and waits for the room behind the play screen
## to be ready.
##
## Two presses rather than one: Start opens the menu and the menu's Play opens
## the game. Still in through the front door, and still the reason it is done
## this way — `main.gd` is the only thing that loads a screen, so the play screen
## here is whatever the buttons put under the host rather than something this
## test instanced behind the game's back.
func _start() -> void:
	var title: GameScreen = _host().get_child(0) as GameScreen
	(title.get_node("%Start") as Button).pressed.emit()
	await wait_process_frames(1)
	var menu: GameScreen = _host().get_child(0) as GameScreen
	(menu.get_node("%Play") as Button).pressed.emit()
	await wait_process_frames(SETTLE_FRAMES)


func _host() -> Control:
	return _main.get_node("%ScreenHost") as Control


func _screen() -> GameScreen:
	return _host().get_child(0) as GameScreen


func _garage() -> Garage:
	return _screen().get_node("Garage") as Garage


func _car() -> Car:
	return _garage().get_node("%Car") as Car


func _grime() -> Grime:
	return _garage().grime()


func _bell() -> Chime:
	return _main.get_node("%Bell") as Chime


func _scoreboard() -> ScoreHud:
	return _screen().get_node("ScoreHud") as ScoreHud


## One panel of [param kind] on the real car, asked for by what it is made of
## rather than by name — see [code]test_play_screen_wash.gd[/code] on why.
func _a_panel_of(kind: Surface.Kind) -> CSGShape3D:
	for panel: CSGShape3D in _car().panels():
		if _car().kind_of(panel) == kind:
			return panel
	return null


## The whole of [param panel]'s widest face, as a brush radius in metres — a
## sweep this wide finishes patches rather than nibbling at one.
func _whole_face_of(panel: CSGShape3D) -> float:
	var box: AABB = panel.get_aabb()
	return maxf(box.size.x, maxf(box.size.y, box.size.z))


## Washes the top of a body panel flat, and returns how many patches that
## finished. Flat rather than through the crosshair for the reason the wash suite
## gives: this is a test about scoring, not about aiming.
func _wash_a_panel_flat() -> int:
	var body: CSGShape3D = _a_panel_of(Surface.Kind.BODY)
	assert_not_null(body, "the car has no bodywork")
	if body == null:
		return 0
	var box: AABB = body.global_transform * body.get_aabb()
	var on_top: Vector3 = Vector3(box.get_center().x, box.end.y, box.get_center().z)
	var finished: int = 0
	for _sweep: int in SWEEPS:
		finished += _grime().wash(body, on_top, Vector3.UP, _whole_face_of(body), 0.2)
	return finished


func test_the_game_starts_on_nothing() -> void:
	await _start()
	assert_not_null(_scoreboard(), "the play screen has no scoreboard")
	assert_eq(_scoreboard().total(), 0, "the game started with points already on the board")


func test_a_finished_patch_pays() -> void:
	await _start()
	var finished: int = _wash_a_panel_flat()
	assert_gt(finished, 0, "washing a panel flat never finished a patch")
	assert_gt(_scoreboard().total(), 0, "a patch came clean and the score did not move")


## The money is for the work, not for the noise. [Chime] drops any ding landing
## inside [constant Chime.MIN_GAP_MSEC] of the last, so a burst rings fewer times
## than it finishes patches — and every one of those patches still has to have
## been paid for. This is the assertion that keeps somebody from "fixing" the
## mismatch by scoring off the bell.
func test_every_patch_in_a_burst_is_paid_even_when_its_ding_is_dropped() -> void:
	await _start()
	var before: int = _bell().rings()
	var finished: int = _wash_a_panel_flat()
	assert_gt(finished, 1, "the sweep finished at most one patch, so there is no burst to check")
	var rang: int = _bell().rings() - before
	assert_lt(rang, finished, "the burst was not thinned, so this proves nothing")
	# Every patch paid at least the face value of a wash, so the total cannot be
	# as low as the number of *bells*. Stated as a floor rather than as an exact
	# figure, because the multiplier moves with the timing of the sweep.
	assert_gte(
		_scoreboard().total(),
		finished * Scoring.WASH_POINTS,
		"patches whose ding was dropped were not paid for"
	)


## The tie the feature is for, checked where the two actually meet: the run the
## score is on and the run the pitch is on are stepped by the same events, so
## after one sweep they read the same number. [Chime]'s class docs have why they
## are counted separately rather than one reading the other.
func test_the_score_and_the_ding_are_on_the_same_run() -> void:
	await _start()
	var finished: int = _wash_a_panel_flat()
	assert_gt(finished, 0, "nothing finished, so there is no run to compare")
	assert_eq(
		_scoreboard().run_shown(),
		_bell().patch_run() > 1,
		"the corner is printing a multiplier the bell does not agree exists"
	)


## The follow-up the whole wage half exists for: the score has to move while a
## panel is being cleaned, not only when a square happens to complete. Asserted
## with a brush too weak to finish anything, so the only thing that can have paid
## is the work itself.
func test_the_score_moves_while_cleaning_before_anything_finishes() -> void:
	await _start()
	var body: CSGShape3D = _a_panel_of(Surface.Kind.BODY)
	assert_not_null(body, "the car has no bodywork")
	if body == null:
		return
	var box: AABB = body.global_transform * body.get_aabb()
	var on_top: Vector3 = Vector3(box.get_center().x, box.end.y, box.get_center().z)
	# A tenth of the panel and a light touch: enough mud moves to be worth paying
	# for, nowhere near enough to take a patch all the way clean.
	var narrow: float = _whole_face_of(body) * 0.1
	var finished: int = 0
	for _sweep: int in 8:
		finished += _grime().wash(body, on_top, Vector3.UP, narrow, 0.02)
		await wait_process_frames(1)
	assert_eq(finished, 0, "the sweep finished a patch, so this proves nothing about the wage")
	assert_gt(_scoreboard().total(), 0, "cleaning paid nothing until a patch completed")


## And the wage is quiet: a trigger held is not an event, so it must not be
## ringing the corner like one.
func test_the_wage_does_not_flash_the_corner() -> void:
	await _start()
	var body: CSGShape3D = _a_panel_of(Surface.Kind.BODY)
	if body == null:
		return
	var box: AABB = body.global_transform * body.get_aabb()
	var on_top: Vector3 = Vector3(box.get_center().x, box.end.y, box.get_center().z)
	var narrow: float = _whole_face_of(body) * 0.1
	for _sweep: int in 8:
		_grime().wash(body, on_top, Vector3.UP, narrow, 0.02)
		await wait_process_frames(1)
	assert_gt(_scoreboard().total(), 0, "nothing was paid, so this proves nothing")
	assert_eq(_scoreboard().flash(), 0.0, "the wage lit the corner like a finished patch")
	assert_eq(_scoreboard().flying(), 0, "the wage threw a number like a finished patch")


func test_the_score_is_in_the_corner_the_grime_board_is_not_using() -> void:
	await _start()
	var toggle: Control = _screen().get_node("GrimeDebug").get_node("%Toggle") as Control
	var digits: Control = _scoreboard().get_node("%Total") as Control
	if not toggle.visible:
		return
	assert_gte(
		digits.position.y,
		toggle.position.y + toggle.size.y,
		"the score is drawn over the grime board's toggle"
	)


## The attract mode runs the same room, so the claim being pinned is that only
## the play screen listens. A title card that scored would hand the player a
## total they never earned, and it would look like the game starting mid-game.
func test_the_attract_mode_does_not_score() -> void:
	await wait_process_frames(SETTLE_FRAMES)
	var title: GameScreen = _host().get_child(0) as GameScreen
	assert_null(title.get_node_or_null("ScoreHud"), "the title screen has a scoreboard")
	await _start()
	assert_eq(_scoreboard().total(), 0, "the attract mode ran up a score before Start")
