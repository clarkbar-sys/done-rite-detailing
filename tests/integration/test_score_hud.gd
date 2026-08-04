## Integration test for [ScoreHud] — the digits in the top-right corner, the
## flash that ties them to the ding, and the [code]+250[/code] that lifts off
## them.
##
## In tests/integration/ rather than tests/unit/ because the thing under test is
## a [Control] with children, a [method Node._process] driving three animations
## and a layout that reads the viewport — none of which exists without a
## [SceneTree]. The arithmetic it is drawing is [Scoring]'s and is unit-tested
## there; nothing here re-asserts a point value.
##
## [b]What is worth pinning is the wiring and the timing, not the taste.[/b] How
## bright the flash is, how far a pop rises and what colour a wash throws are
## numbers somebody will turn the first time they see this move. What cannot
## drift is that a score is reachable at all — the digits do arrive at the total
## rather than easing towards it forever, the flash does go out rather than
## staying lit, and a pop does retire rather than accumulating until the pool is
## permanently full. Each of those three failures looks like a tuning problem and
## is not.
##
## The frames are waited for rather than faked. [method ScoreHud._process] is
## driven by the engine's delta and there is no seam to hand a clock through,
## which is a deliberate difference from [Scoring]: the run has to be assertable
## without waiting a second and a half, and a fade does not — everything here
## finishes inside a second.
extends GutTest

const HUD: String = "res://src/ui/score_hud.tscn"

## Long enough for the roll, the flash and a pop to have finished — the longest
## of the three is [constant ScoreHud.POP_SECONDS].
const SETTLE_SECONDS: float = 1.0

var _hud: ScoreHud = null


func before_each() -> void:
	var packed: PackedScene = load(HUD) as PackedScene
	assert_not_null(packed, "could not load %s" % HUD)
	if packed == null:
		return
	_hud = packed.instantiate() as ScoreHud
	assert_not_null(_hud, "%s is not a ScoreHud" % HUD)
	add_child_autofree(_hud)
	await wait_process_frames(1)


## Scores one wash worth [param award], bringing the total to [param total].
func _award(total: int, award: int, multiplier: int = 1) -> void:
	_hud.score(total, award, GrimeMap.Stage.WASHED, multiplier)


func test_starts_at_nothing() -> void:
	assert_eq(_hud.total(), 0, "a fresh scoreboard is not at zero")
	assert_eq(_hud.shown(), 0, "and its digits do not read zero")
	assert_eq(_hud.flash(), 0.0, "and it is lit before anything happened")
	assert_eq(_hud.flying(), 0, "and something is already in the air")


func test_an_award_lands_on_the_total_at_once() -> void:
	_award(1000, 1000)
	assert_eq(_hud.total(), 1000, "the target did not take the award")


func test_the_digits_roll_rather_than_jump() -> void:
	_award(10_000, 10_000)
	await wait_process_frames(1)
	assert_lt(_hud.shown(), 10_000, "the digits arrived on the first frame")
	assert_gt(_hud.shown(), 0, "the digits did not move at all")


## The one that matters: an eased roll that never quite arrives leaves a score
## permanently a few points light, which reads as the scorer being wrong.
func test_the_digits_do_arrive() -> void:
	_award(12_345, 12_345)
	await wait_seconds(SETTLE_SECONDS)
	assert_eq(_hud.shown(), 12_345, "the digits never caught up with the total")


## An award landing mid-roll retargets rather than stacking two rolls.
func test_a_second_award_mid_roll_still_arrives() -> void:
	_award(10_000, 10_000)
	await wait_process_frames(2)
	_award(20_000, 10_000)
	await wait_seconds(SETTLE_SECONDS)
	assert_eq(_hud.shown(), 20_000, "the digits lost the second award")


func test_an_award_lights_the_flash() -> void:
	_award(100, 100)
	assert_almost_eq(_hud.flash(), 1.0, 0.001, "an award did not light the score")


func test_the_flash_goes_out() -> void:
	_award(100, 100)
	await wait_seconds(SETTLE_SECONDS)
	assert_eq(_hud.flash(), 0.0, "the score stayed lit")


## The tie the feature is for: the corner and the square on the car fade over one
## constant, so a score still lit after its patch has gone dark cannot happen by
## somebody tuning one of the two.
func test_the_flash_fades_over_the_same_time_the_patch_does() -> void:
	_award(100, 100)
	await wait_seconds(PatchFlash.SECONDS + 0.05)
	assert_eq(_hud.flash(), 0.0, "the score outlasted the square that rang with it")


func test_an_award_puts_a_pop_in_the_air() -> void:
	_award(250, 250)
	assert_eq(_hud.flying(), 1, "an award did not throw a number")


func test_a_pop_comes_back_down() -> void:
	_award(250, 250)
	await wait_seconds(SETTLE_SECONDS)
	assert_eq(_hud.flying(), 0, "a pop never retired")


## A sweep of the jet finishes patches faster than a pop lives, so the pool has
## to wrap rather than grow — and it has to still be usable afterwards.
func test_a_burst_past_the_pool_wraps_rather_than_grows() -> void:
	for index: int in ScoreHud.POPS * 3:
		_award((index + 1) * 100, 100)
	assert_eq(_hud.flying(), ScoreHud.POPS, "the pool of pops is not the size it says it is")
	await wait_seconds(SETTLE_SECONDS)
	assert_eq(_hud.flying(), 0, "a wrapped pool never emptied")
	_award(9_999, 100)
	assert_eq(_hud.flying(), 1, "the pool stopped working after it wrapped")


func test_the_multiplier_is_hidden_at_one_and_shown_above_it() -> void:
	_award(100, 100, 1)
	assert_false(_hud.run_shown(), "a multiplier of one is being printed")
	_award(300, 200, 2)
	assert_true(_hud.run_shown(), "a real multiplier is not being printed")


## Three passes, three colours, and no two of them the same — the corner has to
## be able to say which pass paid.
func test_each_stage_throws_its_own_colour() -> void:
	var wash: Color = ScoreHud.tint_for(GrimeMap.Stage.WASHED)
	var foam: Color = ScoreHud.tint_for(GrimeMap.Stage.FOAMED)
	var buff: Color = ScoreHud.tint_for(GrimeMap.Stage.BUFFED)
	assert_ne(wash, foam, "a wash and a foam flash the same colour")
	assert_ne(foam, buff, "a foam and a buff flash the same colour")
	assert_ne(wash, buff, "a wash and a buff flash the same colour")


## The near-white product case the class docs are about: the resting colour has
## to be far enough off the foam tint for that flash to read at all. Measured as
## a distance rather than as an exact pair of colours, so retuning either end
## stays free and closing the gap does not.
func test_the_foam_flash_is_visible_against_the_resting_colour() -> void:
	var foam: Color = ScoreHud.tint_for(GrimeMap.Stage.FOAMED)
	var apart: float = absf(foam.get_luminance() - Brand.MUTED.get_luminance())
	assert_gt(apart, 0.1, "the foam flash is too close to the resting colour to see")


## Nothing in the corner may take a press: the play screen reads aims out of
## `_gui_input`, so a control at `stop` here is a piece of the car that cannot be
## pointed at. Checked over every descendant rather than the root alone, because
## the pops are built in code and a filter left off one of them is exactly the
## kind of thing a screenshot cannot show.
func test_nothing_in_the_corner_can_be_pressed() -> void:
	_award(100, 100)
	for node: Node in _hud.find_children("*", "Control", true, false):
		var control: Control = node as Control
		assert_eq(
			control.mouse_filter,
			Control.MOUSE_FILTER_IGNORE,
			"%s would swallow a press meant for the car" % control.name
		)
	assert_eq(_hud.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the scoreboard itself stops presses")


## A game nobody is playing costs nothing to draw. Not a benchmark — the early
## out in [method ScoreHud._process] is the thing being pinned, and the way it
## shows is that a settled scoreboard stays settled.
func test_a_settled_scoreboard_stays_where_it_is() -> void:
	_award(500, 500)
	await wait_seconds(SETTLE_SECONDS)
	var settled: int = _hud.shown()
	await wait_process_frames(5)
	assert_eq(_hud.shown(), settled, "an idle scoreboard drifted")
	assert_eq(_hud.flash(), 0.0, "an idle scoreboard re-lit itself")
