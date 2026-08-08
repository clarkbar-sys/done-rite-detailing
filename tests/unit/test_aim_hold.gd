## Unit tests for [AimHold] — the rule that lets [method Garage._under_the_finger]
## ask the swept-sphere tier once per aim instead of once per physics tick.
##
## Under tests/unit/ because an [AimHold] is a [RefCounted] that has never heard of
## a physics space: it is handed an origin, a direction and a tool's width, and it
## answers "is what you already have still an answer to that". That a real press
## dragged off a real car really does stop working the paint —
## [method Garage.aim_at], a physics tick and the jet included — is
## [code]tests/integration/test_play_screen_sweep.gd[/code]'s job.
##
## [b]What every test here is really guarding.[/b] A cache that never invalidates
## is not a cache, it is a stale mark on the paint — the water going where the
## player used to be pointing. So the shape of this suite is one test that it holds
## and one test per way of moving the aim that it must not, and the tolerances are
## exercised from both sides rather than trusted.
extends GutTest

## A tenth of a millimetre.
const TOLERANCE: float = 0.0001

## An aim to hold: an eye standing off a car, pointing at it. Nothing here depends
## on the numbers being the room's, only on their being consistent — which is why
## the direction is normalised on the way in the way the room's is.
const EYE: Vector3 = Vector3(3.2, 1.2, 0.0)
const TOWARD: Vector3 = Vector3(-1.0, 0.0, 0.0)

## [member Garage.wash_radius_metres] and [member Garage.scrub_radius_metres] — two
## tools of genuinely different widths, so "the tool changed" is a real change and
## not a rounding one.
const WASH_REACH: float = 0.4
const SCRUB_REACH: float = 0.22

## Comfortably inside [constant AimHold.HELD_METRES] and comfortably outside it.
## Both are stated as fractions of the constant rather than as numbers of their
## own, so retuning the budget retunes the test with it instead of quietly making
## one of these two meaningless.
const A_TWITCH: float = AimHold.HELD_METRES * 0.25
const A_STEP: float = AimHold.HELD_METRES * 4.0

## The same idea for the direction: multiples of the angle
## [constant AimHold.HELD_COSINE] stands for, a quarter of it and four times it.
## Taken back through [method @GlobalScope.acos] rather than written down as a
## quarter of a degree, so neither of these can drift out of step with the constant
## they are testing.
const A_WOBBLE: float = 0.25
const A_TURN: float = 4.0

var _held: AimHold = null


func before_each() -> void:
	_held = AimHold.new()


## The answer a sweep hands back, with [param panel] as the thing it rested on —
## the same four keys [method AimSweep.onto] fills in, because a hold that only
## worked on a [Dictionary] this suite invented would prove nothing about the one
## the room puts in it.
func _an_answer(panel: Object) -> Dictionary:
	return {
		"position": Vector3(1.0, 1.0, 0.0),
		"normal": Vector3.UP,
		"collider": panel,
		"surface": true,
	}


## The angle [constant AimHold.HELD_COSINE] draws the line at, in radians.
func _the_angle() -> float:
	return acos(AimHold.HELD_COSINE)


## [constant TOWARD], turned [param factor] times that angle about the vertical.
func _turned(factor: float) -> Vector3:
	return TOWARD.rotated(Vector3.UP, _the_angle() * factor).normalized()


## Puts an answer in, taken for the plain [constant EYE] / [constant TOWARD] aim
## with the power wash in hand, and hands back the panel it names so a test can
## free it.
func _take_one() -> Node3D:
	var panel: Node3D = Node3D.new()
	_held.keep(_an_answer(panel), EYE, TOWARD.normalized(), WASH_REACH)
	return panel


func test_a_hold_that_has_never_been_taken_holds_nothing() -> void:
	# The state the room starts every press in, and the reason nothing needs a
	# "has the press just begun" flag of its own: an untaken hold answers false to
	# any aim whatsoever, so the first tick of a finger going down sweeps.
	assert_false(_held.holds(EYE, TOWARD.normalized(), WASH_REACH), "an empty hold held")
	assert_true(_held.answer().is_empty(), "an empty hold is holding an answer")


func test_the_aim_it_was_taken_for_is_still_the_aim_it_answers() -> void:
	# The whole point. A finger held still on the glass produces a bit-identical
	# ray from a bit-identical camera, tick after tick, and that is the press this
	# class exists for — sixty of them a second, each one otherwise buying a
	# four-millisecond sweep to be told what the last one said.
	var panel: Node3D = autofree(_take_one())
	assert_not_null(panel, "the panel the answer names went missing")
	assert_true(_held.holds(EYE, TOWARD.normalized(), WASH_REACH), "an identical aim did not hold")
	var answer: Dictionary = _held.answer()
	var who: Object = answer["collider"]
	assert_eq(who, panel, "the hold handed back somebody else's answer")


func test_an_eye_that_has_only_jittered_still_holds() -> void:
	# What [constant AimHold.HELD_METRES] is for, said as a test rather than as a
	# paragraph: [Standoff] is a servo that converges asymptotically, so a settled
	# camera goes on moving by amounts with several zeroes in front of them forever
	# and a hold with no budget at all would be dropped every single tick.
	autofree(_take_one())
	var nudged: Vector3 = EYE + Vector3(A_TWITCH, 0.0, 0.0)
	assert_true(_held.holds(nudged, TOWARD.normalized(), WASH_REACH), "a twitch dropped the hold")


func test_an_eye_that_has_walked_does_not_hold() -> void:
	# The other side of the same budget, and the case the issue's own suggestion
	# would have missed: a finger held perfectly still while the player walks round
	# the car is a still press with a moving aim, and answering it with a sweep
	# taken from where they used to be standing is water going somewhere nobody is
	# pointing.
	autofree(_take_one())
	var walked: Vector3 = EYE + Vector3(A_STEP, 0.0, 0.0)
	assert_false(_held.holds(walked, TOWARD.normalized(), WASH_REACH), "a step held")


func test_an_aim_that_has_only_wobbled_still_holds() -> void:
	# [constant AimHold.HELD_COSINE] from the inside. A quarter of a degree at the
	# distance the walk stands off is about a centimetre across the paint, which is
	# two orders of magnitude inside the tool-radius the swept answer already sits
	# off the line it was cast down.
	autofree(_take_one())
	assert_true(_held.holds(EYE, _turned(A_WOBBLE), WASH_REACH), "a wobble dropped the hold")


func test_an_aim_that_has_moved_does_not_hold() -> void:
	# And from the outside. Without this the mark stops following the finger, which
	# is the one behaviour a player would actually notice this class getting wrong.
	autofree(_take_one())
	assert_false(_held.holds(EYE, _turned(A_TURN), WASH_REACH), "a turned aim held")


func test_a_tool_swapped_mid_press_is_a_new_question() -> void:
	# How wide the tool works is how wide a miss the room forgives — see
	# [method Garage._reach_of] — so the reach is part of the aim and not a detail
	# of the query. A sponge inheriting the power wash's window would forgive a miss
	# nearly twice its own width, on the same tick the player swapped to it.
	autofree(_take_one())
	assert_false(_held.holds(EYE, TOWARD.normalized(), SCRUB_REACH), "a narrower tool held")


func test_an_answer_of_nothing_is_held_like_any_other() -> void:
	# The expensive case, and the one that looks skippable. "A window this wide down
	# this line touches nothing" is the identical query at the identical price — a
	# fan whose every ray ran the full reach, four milliseconds of swept sphere when
	# the hold was built — and it is what a thumb parked in the sky beside the car
	# produces on every tick it is held there. A cache that kept only the hits would
	# leave the whole cost in place.
	_held.keep({}, EYE, TOWARD.normalized(), WASH_REACH)
	assert_true(_held.holds(EYE, TOWARD.normalized(), WASH_REACH), "an empty answer was not held")
	assert_true(_held.answer().is_empty(), "an empty answer came back holding something")
	assert_false(_held.holds(EYE, _turned(A_TURN), WASH_REACH), "an empty answer outlived its aim")


func test_an_answer_whose_panel_has_gone_is_not_an_answer() -> void:
	# Nothing in the game frees a panel while a finger is on the glass today. This
	# is here because the failure if one ever did is a crash reading `name` off a
	# freed [Object] rather than a mark in the wrong place, and a room that keeps
	# engine references between ticks has to say what happens when one dies.
	var panel: Node3D = Node3D.new()
	_held.keep(_an_answer(panel), EYE, TOWARD.normalized(), WASH_REACH)
	assert_true(_held.holds(EYE, TOWARD.normalized(), WASH_REACH), "a live panel did not hold")
	panel.free()
	assert_false(_held.holds(EYE, TOWARD.normalized(), WASH_REACH), "a freed panel held")


func test_dropping_it_puts_the_answer_down_as_well_as_the_aim() -> void:
	# What [method Garage.release_aim] calls when the finger comes off the glass.
	# Both halves are asserted because only one of them is about correctness: the
	# aim being forgotten is what makes the next press sweep, and the answer being
	# forgotten is what stops the room holding a panel alive on behalf of a finger
	# that has left.
	autofree(_take_one())
	_held.drop()
	assert_false(_held.holds(EYE, TOWARD.normalized(), WASH_REACH), "a dropped hold still held")
	assert_true(_held.answer().is_empty(), "a dropped hold is still holding an answer")


func test_the_budgets_are_the_slack_they_claim_to_be() -> void:
	# The two constants read as numbers rather than as tolerances, because every
	# test above is stated relative to them and would go on passing if both were
	# retuned to something absurd. A quarter of a degree is what the class docs
	# argue for; a millimetre or two of eye drift is what a settled servo produces.
	assert_almost_eq(AimHold.HELD_METRES, 0.002, TOLERANCE, "the eye budget is not 2 mm")
	assert_almost_eq(
		rad_to_deg(_the_angle()), 0.256, 0.01, "the aim budget is not a quarter degree"
	)
