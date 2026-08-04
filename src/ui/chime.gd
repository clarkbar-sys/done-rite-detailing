## The thing that actually rings: a small pool of players, every [Bell] voice
## built once, and a rule about how often a ding is allowed.
##
## It hangs off [code]src/main/main.tscn[/code] rather than off a screen, and
## that placement is the whole reason it exists as a class. A [GameScreen] is
## removed and freed the moment it asks for the next state — so a bell started by
## the title screen's own [AudioStreamPlayer] would be freed mid-ding, and Start
## would sound like a click. The host outlives every screen, so a bell rung there
## rings out over the swap. [code]tests/integration/test_main_scene.gd[/code]
## presses Start and asserts the sound is still going afterwards, because that is
## the failure this arrangement exists to prevent and it is invisible in a
## screenshot.
##
## Screens do not reach for it. They call [method GameScreen.ring_bell], which is
## a signal the host connects — the same one-direction wiring transitions already
## use, and for the same reason: a screen that could reach the host could reach
## anything hanging off it.
##
## [b]Why it lives in src/ui/ and not src/core/.[/b] It is a [Node] with children
## in the tree, and [code]scripts/check-test-map.sh[/code] R3 keeps
## [code]src/core/[/code] to classes a unit test can construct without a
## [SceneTree]. The arithmetic of a bell is that tier ([Bell]); playing one is
## this tier.
##
## [b]A pool rather than one player.[/b] Patches come clean in bursts — a wide
## jet can finish two or three in the same tick — and one player told to play
## again cuts off what it was playing. Three dings on one player is one ding with
## two stutters in it; three dings on three players is the "ding ding ding" the
## player is actually being told about. [constant VOICES] is how many can overlap
## before the oldest is taken back, which is the same round-robin every sound
## pool in every engine ends up with.
##
## [b]And a floor on how often.[/b] Even with a pool, a burst of dings inside a
## few milliseconds is not heard as several bells, it is heard as one loud
## distorted one — they are the same waveform arriving in phase.
## [constant MIN_GAP_MSEC] drops any ding that lands inside the last one's
## shadow, so what comes out is a bell per audible event rather than a bell per
## texel.
##
## [b]The patch bell climbs on a run.[/b] Consecutive calls to
## [method ring_at] with [constant Bell.Voice.PATCH] step up
## [constant Bell.PATCH_RUN_RATIOS]; a gap longer than [constant Bell.RUN_RESET_MSEC]
## resets to the bottom. That step is counted on every call, not only the ones
## that get past [constant MIN_GAP_MSEC] — a ding dropped by the rate limit was
## still a patch finishing, and a run that only advanced on the dings that made
## a sound would fall out of step with what actually happened the moment a
## sweep finished two patches faster than [constant MIN_GAP_MSEC] apart.
## [method patch_run] hands back the count itself, for anything downstream that
## wants a run's length rather than its pitch.
##
## [b][Scoring] climbs the same run, and does not read it from here.[/b] It
## counts its own on [constant Bell.RUN_RESET_MSEC] — the constant both read, and
## the reason that constant moved onto [Bell]. Reaching for this one instead
## would mean plumbing an answer from the host, which owns the [Chime], back down
## into a screen, which is a direction nothing in this project runs in and a lot
## of wiring for an integer. What keeps the two honest is that they are fed the
## same events at the same instants: a screen asks for a ding on every patch and
## scores on every patch, both through [signal Grime.patch_finished], and both
## step their run on every call rather than on the ones that made a noise —
## which is what the paragraph above is about, and is why the pitch and the
## multiplier cannot come apart over a fast sweep.
## [code]tests/integration/test_play_screen_score.gd[/code] walks one sequence
## through both and asserts they agree.
##
## [b]The browser's rule about sound, which is the reason Start dings at all.[/b]
## A page may not make a noise until the person on it has touched it — every
## mobile browser enforces this, and Godot's web export answers it by resuming
## the audio context on the first input the page sees. So the first sound in the
## game has to be one that happens [i]on[/i] a press, and Start is that press.
## That is why the bell is on the button rather than, say, on the title screen
## appearing: a ding nobody asked for would be silently dropped by the browser
## and would leave the rest of the game's audio waiting for a gesture that never
## came with a sound attached to it.
class_name Chime
extends Node

## How many bells can be ringing at once before the oldest is taken back. Four
## covers a burst of patches finishing under one sweep of the jet without
## building a choir out of them.
const VOICES: int = 4

## The shortest gap between two dings, in milliseconds. Anything arriving sooner
## is dropped rather than queued: it is feedback about something that just
## happened, so a late one is worse than none.
##
## 70 ms is about the point where two of the same sound stop being heard as one
## event — short enough that a fast burst still rings three or four times, long
## enough that a single tick finishing several patches is one bell.
const MIN_GAP_MSEC: int = 70

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary[Bell.Voice, AudioStreamWAV] = {}
var _patch_streams: Array[AudioStreamWAV] = []
var _next: int = 0
var _last_msec: int = -MIN_GAP_MSEC
var _rung: int = 0
var _run: int = 0
var _last_patch_msec: int = -Bell.RUN_RESET_MSEC


func _ready() -> void:
	# Every voice built here and kept for the life of the game: the arithmetic is
	# a loop over tens of thousands of samples (see [Bell]), and a game that built
	# one on the press that plays it would hitch on exactly the frame the player
	# is waiting for a response to. The ladder is [constant Bell.PATCH_RUN_RATIOS]
	# long, which [Bell]'s own docs cap for exactly this reason: small enough to
	# build eagerly without a thought.
	_streams[Bell.Voice.START] = Bell.voice(Bell.Voice.START)
	for step: int in Bell.PATCH_RUN_RATIOS.size():
		_patch_streams.append(Bell.voice(Bell.Voice.PATCH, step))
	for index: int in VOICES:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "Voice%d" % index
		add_child(player)
		_players.append(player)


## Rings [param which] bell now, unless one rang too recently to hear this one
## apart from it.
##
## The engine's clock, so this is what everything in the game calls.
## [method ring_at] is the same thing with the time handed in, which is how the
## gap is tested without a suite that has to wait in real seconds.
func ring(which: Bell.Voice) -> void:
	ring_at(which, Time.get_ticks_msec())


## Rings [param which] bell as at [param now_msec]. Returns whether it actually
## rang — false means it landed inside [constant MIN_GAP_MSEC] of the last one.
##
## For [constant Bell.Voice.PATCH], the run is stepped before that gap is
## checked — see the class docs on why a ding the rate limit drops still has to
## count.
func ring_at(which: Bell.Voice, now_msec: int) -> bool:
	var stream: AudioStreamWAV = _stream_for(which, now_msec)
	if stream == null:
		return false
	if now_msec - _last_msec < MIN_GAP_MSEC:
		return false
	_last_msec = now_msec
	_rung += 1
	var player: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.play()
	return true


## How many consecutive patches have rung, counting the one about to ring —
## so the first patch of a run reads 1. The same number [method ring_at] just
## picked [constant Bell.PATCH_RUN_RATIOS]'s step from, for anything downstream
## that wants a run's length rather than its pitch.
func patch_run() -> int:
	return _run + 1


## The stream for [param which] bell at [param now_msec], stepping the patch run
## first when [param which] is [constant Bell.Voice.PATCH]. `null` for a voice
## nothing was built for.
func _stream_for(which: Bell.Voice, now_msec: int) -> AudioStreamWAV:
	if which != Bell.Voice.PATCH:
		return _streams[which] if _streams.has(which) else null
	if now_msec - _last_patch_msec >= Bell.RUN_RESET_MSEC:
		_run = 0
	else:
		_run += 1
	_last_patch_msec = now_msec
	return _patch_streams[mini(_run, _patch_streams.size() - 1)]


## How many bells this has rung since the game started, counting only the ones
## that got past [constant MIN_GAP_MSEC].
##
## The honest version of "did that make a noise" for anything downstream of it: a
## player still ringing from the last event says nothing about whether this one
## rang, and [method is_ringing] cannot tell the two apart.
func rings() -> int:
	return _rung


## How many bells are ringing right now.
func ringing() -> int:
	var count: int = 0
	for player: AudioStreamPlayer in _players:
		if player.playing:
			count += 1
	return count


## Whether anything is ringing at all — the question a test asking "did Start
## make a noise" is really asking.
func is_ringing() -> bool:
	return ringing() > 0
