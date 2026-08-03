## Integration test for [ToolRacket] — the players that actually run a
## [ToolNoise], and the fade at both ends of a press.
##
## Under tests/integration/ for [code]tests/integration/test_chime.gd[/code]'s
## reason: a racket builds its players in [method Node._ready], starts and stops
## them, and asks them whether they are playing, all three of which need it in a
## tree.  What the sounds themselves are made of is
## [code]tests/unit/test_tool_noise.gd[/code].
##
## [b]Time is handed in rather than waited for[/b], which is the same arrangement
## [code]test_chime.gd[/code] has and it was arrived at the same way — by getting
## it wrong first. The fade is stepped in [method Node._process], so the obvious
## suite waits a frame and asserts the fade is partway up. Measured on this
## project's own headless run, a frame there is routinely longer than
## [constant ToolRacket.FADE_SECONDS], so "partway" had already become "finished"
## and the test failed a class that was working. [method ToolRacket.settle] takes
## the clock, so every assertion below is about an exact point in a fade rather
## than about how fast the runner happened to be drawing.
##
## One test still goes through real frames, because everything above would pass
## just as well on a class the engine never called.
extends GutTest

## Enough frames for a fade to have finished at any frame rate a test runner
## plausibly draws at — only the one test that uses the engine's own clock needs
## this.
const DRAWN_FRAMES: int = 20

var _racket: ToolRacket = null


func before_each() -> void:
	_racket = ToolRacket.new()
	add_child_autofree(_racket)


## Holds [param id]'s trigger and settles until the fade is all the way in.
##
## No [code]await[/code] anywhere in here, which is what makes every assertion in
## this suite deterministic: nothing else can step the fade between two statements
## that never yield.
func _hold(id: DetailingTool.Id) -> void:
	_racket.run(id)
	_racket.settle(ToolRacket.FADE_SECONDS)


func _release() -> void:
	_racket.hush()
	_racket.settle(ToolRacket.FADE_SECONDS)


# ---- the players -------------------------------------------------------------


func test_it_builds_a_player_for_every_voice() -> void:
	# One each rather than a pool: only one tool is in the player's hands, and what
	# the extra players buy is somewhere for each voice to keep its playhead.
	assert_eq(_racket.get_child_count(), 4, "one player per voice")


func test_nothing_runs_until_the_trigger_is_pulled() -> void:
	_racket.settle(ToolRacket.FADE_SECONDS)
	assert_false(_racket.is_running(), "the room thinks a trigger is down")
	assert_false(_racket.is_making_a_noise(), "the game made a noise nobody asked for")


# ---- pulling and letting go --------------------------------------------------


func test_holding_the_trigger_runs_the_tools_own_voice() -> void:
	_hold(DetailingTool.Id.POWER_WASH)
	assert_true(_racket.is_running(), "the trigger is down")
	assert_true(_racket.is_sounding(ToolNoise.Voice.WASH), "and the water is running")
	assert_almost_eq(_racket.gain(ToolNoise.Voice.WASH), 1.0, 0.001, "at full volume")


func test_only_the_held_tools_voice_runs() -> void:
	# The bug this stops is a belt that leaves the last tool's sound underneath the
	# new one — which is what a player per voice makes possible in the first place.
	_hold(DetailingTool.Id.SPONGE)
	assert_true(_racket.is_sounding(ToolNoise.Voice.SQUISH), "the sponge squelches")
	assert_false(_racket.is_sounding(ToolNoise.Voice.WASH), "and the water is not still running")
	assert_false(_racket.is_sounding(ToolNoise.Voice.RAG), "nor the rag")
	assert_false(_racket.is_sounding(ToolNoise.Voice.SPRAY), "nor a bottle")


func test_letting_go_stops_the_noise() -> void:
	_hold(DetailingTool.Id.WINDOW_CLEANER)
	assert_true(_racket.is_making_a_noise(), "the bottle should be hissing")
	_release()
	assert_false(_racket.is_running(), "the trigger is up")
	assert_false(_racket.is_making_a_noise(), "and the room is quiet again")


func test_both_bottles_run_the_same_hiss() -> void:
	# The mapping is [ToolNoise]'s and is unit-tested there; this is that decision
	# arriving intact at the thing that plays it.
	_hold(DetailingTool.Id.TIRE_ENGINE_CLEANER)
	assert_true(_racket.is_sounding(ToolNoise.Voice.SPRAY), "the tyre cleaner hisses")


# ---- a held trigger is one sound ---------------------------------------------


func test_holding_the_trigger_starts_the_voice_once() -> void:
	# The reason [method ToolRacket.run] is idempotent. The room calls it on every
	# physics tick the finger is down, and a class that restarted the stream each
	# time would be a stutter rather than a sound — and would look identical to a
	# working one in any test that only asked whether something was playing.
	for tick: int in 30:
		_racket.run(DetailingTool.Id.POWER_WASH)
		_racket.settle(ToolRacket.FADE_SECONDS * 0.25)
	assert_eq(_racket.starts(), 1, "the water restarted %d times" % _racket.starts())


func test_a_second_press_starts_it_again() -> void:
	# The other half: a voice that has been let go of and stopped is started afresh
	# next time, rather than the count above being a class that only ever plays once.
	_hold(DetailingTool.Id.POWER_WASH)
	_release()
	_hold(DetailingTool.Id.POWER_WASH)
	assert_eq(_racket.starts(), 2, "the second press did not start the water again")


# ---- the fade ----------------------------------------------------------------


func test_a_voice_ramps_up_rather_than_arriving_at_full_volume() -> void:
	# A loop started at full amplitude starts on a step, and a step is a click —
	# the same fault [constant Bell.ATTACK_SECONDS] exists to prevent at the other
	# end of a sound. Half a fade in, the water should be at half volume and being
	# heard while it gets there.
	_racket.run(DetailingTool.Id.POWER_WASH)
	_racket.settle(ToolRacket.FADE_SECONDS * 0.5)
	assert_almost_eq(_racket.gain(ToolNoise.Voice.WASH), 0.5, 0.001, "halfway up")
	assert_true(_racket.is_sounding(ToolNoise.Voice.WASH), "and audible on the way")


func test_a_voice_ramps_down_rather_than_being_cut_off() -> void:
	# The release, which is the half that matters more: a trigger is let go of
	# hundreds of times in a session, and the loop is at whatever amplitude it
	# happened to reach when it is.
	_hold(DetailingTool.Id.DRYING_RAG)
	_racket.hush()
	_racket.settle(ToolRacket.FADE_SECONDS * 0.5)
	assert_almost_eq(_racket.gain(ToolNoise.Voice.RAG), 0.5, 0.001, "halfway down")
	assert_true(_racket.is_sounding(ToolNoise.Voice.RAG), "and still heard while it fades")


func test_swapping_tools_mid_press_crossfades() -> void:
	# What the per-voice gain buys for free. A tool changed while the finger is
	# down is answered on the same tick the sight is — see
	# [method Garage._sight_the_aim] — so both voices are briefly audible, one
	# rising and one falling, rather than one being cut off.
	_hold(DetailingTool.Id.POWER_WASH)
	_racket.run(DetailingTool.Id.SPONGE)
	_racket.settle(ToolRacket.FADE_SECONDS * 0.5)
	assert_almost_eq(_racket.gain(ToolNoise.Voice.SQUISH), 0.5, 0.001, "the sponge coming in")
	assert_almost_eq(_racket.gain(ToolNoise.Voice.WASH), 0.5, 0.001, "the water going out")
	_racket.settle(ToolRacket.FADE_SECONDS)
	assert_false(_racket.is_sounding(ToolNoise.Voice.WASH), "and the water is gone afterwards")
	assert_true(_racket.is_sounding(ToolNoise.Voice.SQUISH), "leaving the sponge")


# ---- and the engine really does step it --------------------------------------


func test_the_engine_steps_the_fade_without_being_asked() -> void:
	# Everything above would pass on a class whose fade only ever moved when a test
	# moved it. This is the frame clock actually being wired to it — the one thing
	# in this file that has to wait for real frames.
	_racket.run(DetailingTool.Id.POWER_WASH)
	await wait_process_frames(DRAWN_FRAMES)
	assert_almost_eq(_racket.gain(ToolNoise.Voice.WASH), 1.0, 0.001, "nothing stepped the fade")
	assert_true(_racket.is_sounding(ToolNoise.Voice.WASH), "and nothing started the water")
