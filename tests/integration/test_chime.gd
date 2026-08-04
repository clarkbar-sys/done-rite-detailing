## Integration test for [Chime] — the pool of players that actually rings a
## [Bell], and the rule about how often.
##
## Under tests/integration/ because a [Chime] builds its players in
## [method Node._ready] and asks them whether they are playing: both of those
## need it in a tree. What the sound itself is made of is
## [code]tests/unit/test_bell.gd[/code].
##
## [b]Time is handed in rather than waited for.[/b] Every assertion below about
## the gap goes through [method Chime.ring_at], so the suite tests the rule at
## whatever clock it likes instead of sleeping through it — a suite that waited
## 70 ms per assertion would be slower and would still be flaky on a loaded CI
## runner. [method Chime.ring] is the same call with [method Time.get_ticks_msec]
## in it, and the game only ever uses that one.
extends GutTest

## A moment far enough from zero that the first ring is not a special case of the
## clock starting there.
const NOW: int = 10_000

var _chime: Chime = null


func before_each() -> void:
	_chime = Chime.new()
	add_child_autofree(_chime)


## Whether any player in the pool is loaded with [param stream].
##
## Compared by samples rather than by identity: [method Bell.voice] builds a
## fresh [AudioStreamWAV] on every call and is deterministic, so "the same sound"
## is the only equality there is — and the only one worth asserting, since what
## the player got handed is the whole question here.
##
## Reads the pool through [method Node.get_child] rather than through [Chime]'s
## own array: the players are public children with a public [member
## AudioStreamPlayer.stream], and a test that reached past that would be
## asserting on bookkeeping instead of on what is about to come out of the
## speaker.
func _pool_holds(stream: AudioStreamWAV) -> bool:
	for index: int in _chime.get_child_count():
		var player: AudioStreamPlayer = _chime.get_child(index) as AudioStreamPlayer
		var loaded: AudioStreamWAV = player.stream as AudioStreamWAV
		if loaded != null and loaded.data == stream.data:
			return true
	return false


func test_it_builds_a_player_for_every_voice_it_promises() -> void:
	# The pool is the whole reason two dings in quick succession are two dings
	# rather than one with a hole in it.
	assert_eq(_chime.get_child_count(), Chime.VOICES)


func test_nothing_rings_until_it_is_rung() -> void:
	assert_false(_chime.is_ringing(), "the game made a noise nobody asked for")


func test_ringing_a_bell_makes_a_noise() -> void:
	assert_true(_chime.ring_at(Bell.Voice.START, NOW), "the counter bell refused to ring")
	assert_true(_chime.is_ringing())


func test_both_voices_can_be_rung() -> void:
	# A voice with no stream behind it would return false here, which is how a
	# half-built [Chime] would show up rather than as silence in the game.
	assert_true(_chime.ring_at(Bell.Voice.PATCH, NOW), "the patch bell refused to ring")


func test_a_second_ding_too_soon_is_dropped() -> void:
	# The burst rule. A wide jet finishes several patches in one tick, and three
	# copies of the same waveform starting in the same millisecond are heard as
	# one distorted bell rather than as three.
	_chime.ring_at(Bell.Voice.PATCH, NOW)
	assert_false(
		_chime.ring_at(Bell.Voice.PATCH, NOW + Chime.MIN_GAP_MSEC - 1),
		"a ding inside the gap rang anyway"
	)
	assert_eq(_chime.ringing(), 1, "and it took a player to do it")


func test_a_ding_after_the_gap_rings() -> void:
	# The other half: the rule drops what cannot be heard apart and nothing else.
	# A player washing for a minute would otherwise get one bell and then silence.
	_chime.ring_at(Bell.Voice.PATCH, NOW)
	assert_true(_chime.ring_at(Bell.Voice.PATCH, NOW + Chime.MIN_GAP_MSEC))
	assert_eq(_chime.ringing(), 2, "the ding ding is one ding")


func test_a_burst_rings_on_a_different_player_each_time() -> void:
	# "Ding ding ding" and not "ding-ding-ding cut short": each one lands on its
	# own player, so the one before it is still ringing out.
	for index: int in Chime.VOICES:
		_chime.ring_at(Bell.Voice.PATCH, NOW + index * Chime.MIN_GAP_MSEC)
	assert_eq(_chime.ringing(), Chime.VOICES, "the pool cut its own bells off")


func test_the_pool_takes_the_oldest_player_back() -> void:
	# Round-robin, so a burst longer than the pool is bounded rather than growing
	# a player per ding. The oldest is the one that has had the longest to ring.
	for index: int in Chime.VOICES + 2:
		_chime.ring_at(Bell.Voice.PATCH, NOW + index * Chime.MIN_GAP_MSEC)
	assert_eq(_chime.ringing(), Chime.VOICES)
	assert_eq(_chime.get_child_count(), Chime.VOICES, "the pool grew rather than recycled")


# ---- the patch bell climbs a run -----------------------------------------------


func test_the_first_patch_of_a_run_is_the_first_step() -> void:
	_chime.ring_at(Bell.Voice.PATCH, NOW)
	assert_eq(_chime.patch_run(), 1, "the first patch of a run should read as the first")


func test_consecutive_patches_climb_the_run() -> void:
	# Well inside [constant Bell.RUN_RESET_MSEC] of each other, so this is a
	# sweep rather than three separate runs.
	_chime.ring_at(Bell.Voice.PATCH, NOW)
	_chime.ring_at(Bell.Voice.PATCH, NOW + 200)
	_chime.ring_at(Bell.Voice.PATCH, NOW + 400)
	assert_eq(_chime.patch_run(), 3, "three patches in a row should be a run of three")


func test_a_gap_resets_the_run() -> void:
	# Hesitating starts the ladder over — the class docs on [Chime] have why.
	_chime.ring_at(Bell.Voice.PATCH, NOW)
	_chime.ring_at(Bell.Voice.PATCH, NOW + 200)
	_chime.ring_at(Bell.Voice.PATCH, NOW + 200 + Bell.RUN_RESET_MSEC)
	assert_eq(_chime.patch_run(), 1, "a gap past the reset window did not reset the run")


func test_the_run_counts_patches_even_when_the_ding_is_dropped() -> void:
	# A ding the rate limiter drops was still a real patch finishing — see the
	# class docs — so a fast sweep still climbs the ladder even though some of
	# its dings never sound.
	_chime.ring_at(Bell.Voice.PATCH, NOW)
	var rang: bool = _chime.ring_at(Bell.Voice.PATCH, NOW + Chime.MIN_GAP_MSEC - 1)
	assert_false(rang, "this ding should have been inside the rate limit")
	assert_eq(_chime.patch_run(), 2, "the dropped ding should still have counted as a patch")


func test_the_top_of_the_run_pays_out() -> void:
	# The winner: a run long enough to reach the top rung rings the whole triad
	# at once rather than another note. [code]tests/unit/test_bell.gd[/code] has
	# what that chord is made of; this is the half that says the pool is actually
	# handed it on the patch that earns it.
	var top: int = Bell.PATCH_RUN_RATIOS.size() - 1
	for step: int in Bell.PATCH_RUN_RATIOS.size():
		_chime.ring_at(Bell.Voice.PATCH, NOW + step * Chime.MIN_GAP_MSEC)
	assert_eq(_chime.patch_run(), Bell.PATCH_RUN_RATIOS.size(), "the run did not reach the top")
	assert_true(
		_pool_holds(Bell.voice(Bell.Voice.PATCH, top)), "the top of the run did not pay out"
	)


func test_a_run_past_the_top_holds_rather_than_paying_out_again() -> void:
	# The reason this class builds one more stream than the ladder has rungs. A
	# sweep that keeps going holds at the top, and re-paying the jackpot on every
	# patch for as long as the jet is moving is not a jackpot — [method Bell.voice]
	# makes the same argument at more length.
	var past: int = Bell.PATCH_RUN_RATIOS.size() + 1
	for step: int in past:
		_chime.ring_at(Bell.Voice.PATCH, NOW + step * Chime.MIN_GAP_MSEC)
	assert_true(
		_pool_holds(Bell.voice(Bell.Voice.PATCH, past - 1)),
		"a run past the top rang something other than the note it holds on"
	)


func test_ringing_the_counter_bell_does_not_touch_the_run() -> void:
	_chime.ring_at(Bell.Voice.PATCH, NOW)
	_chime.ring_at(Bell.Voice.PATCH, NOW + 200)
	_chime.ring_at(Bell.Voice.START, NOW + 400)
	assert_eq(_chime.patch_run(), 2, "ringing Start should not have advanced the patch run")
