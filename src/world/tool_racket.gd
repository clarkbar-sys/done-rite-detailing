## The racket a running tool makes: one player per [enum ToolNoise.Voice], and a
## fade so that starting and stopping are not clicks.
##
## The other half of [ToolNoise], the way [Chime] is the other half of [Bell] —
## the arithmetic of a sound is a [RefCounted] in [code]src/core/[/code] and
## playing one needs nodes in the tree. The differences between this class and
## [Chime] are all downstream of the difference between an event and a state:
##
## [b]A player per voice, not a pool.[/b] A bell is rung and forgotten, so what a
## pool buys is several rings overlapping. A tool is either running or it is not,
## and only one tool is in the player's hands — so what is needed is somewhere for
## each voice to keep its playhead while another one is being heard, which is one
## player each and no round robin.
##
## [b]It is asked every tick rather than told once.[/b] [method run] is called from
## [method Garage._resolve_aim] on every physics tick the trigger is down, with
## whatever is in the player's hands at that instant, and [method hush] on every
## tick it is not. That is deliberately the same shape [ToolSight] is driven in —
## the sound and the picture are the same statement about the same tool — and it
## is why [method run] is idempotent: a call naming the voice already running
## changes nothing at all, so a held trigger is one continuous sound rather than
## sixty restarts a second. [method starts] is that promise, countable.
##
## [b]And it fades.[/b] Every voice is a loop, so at the moment a trigger is let go
## the waveform is at whatever amplitude it happened to reach — and a player
## stopped there ends on a step, which is a click. It is the same fault
## [constant Bell.ATTACK_SECONDS] exists to prevent at the other end of a sound,
## and it is worse here because a trigger is pulled and released hundreds of times
## in a session. So each voice carries a gain that moves toward where it should be
## over [constant FADE_SECONDS] rather than jumping there, which buys three things
## for one mechanism: no click on the pull, no click on the release, and a swap of
## tools mid-press that crossfades instead of cutting.
##
## [b]Why it hangs off the room and not the host.[/b] [Chime] lives on
## [code]src/main/main.tscn[/code] because a bell rung by a screen has to go on
## ringing after that screen has been freed. This is the exact opposite: a tool
## that could still be heard after the room it was being used in had gone would be
## the bug. The garage owns it, the garage is freed with the screen, and the sound
## stops because the thing making it no longer exists.
##
## [b]Which is also why it is switched on per screen[/b] — see
## [member Garage.noisy]. The title screen runs the same room, with the game
## playing itself behind the card, and it stays silent for the reason it already
## rings no bell: audio is locked in a browser until somebody has pressed
## something, and a title card that ran a pressure washer at a player who has not
## touched it yet would be an odd first impression on a desktop and impossible on
## the web.
class_name ToolRacket
extends Node

## How long a voice takes to reach full volume, or to reach silence, in seconds.
##
## Short enough that a pull of the trigger is heard as immediate — a twentieth of
## a second is under two frames at 30 fps — and long enough to be a ramp rather
## than a step. The same number both ways: a release that faded slower than the
## pull would be heard as the tool running on after the finger came off.
const FADE_SECONDS: float = 0.05

var _players: Dictionary[ToolNoise.Voice, AudioStreamPlayer] = {}
var _gains: Dictionary[ToolNoise.Voice, float] = {}
var _running: bool = false
var _voice: ToolNoise.Voice = ToolNoise.Voice.WASH
var _starts: int = 0


func _ready() -> void:
	# Every voice built here and kept for the life of the screen, for [Chime]'s
	# reason: the arithmetic is a loop over tens of thousands of samples, and a game
	# that built one on the tick the trigger was pulled would hitch on exactly the
	# frame the player is waiting for a response to.
	for which: ToolNoise.Voice in ToolNoise.EVERY_VOICE:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "Voice%d" % int(which)
		player.stream = ToolNoise.voice(which)
		player.volume_linear = 0.0
		add_child(player)
		_players[which] = player
		_gains[which] = 0.0


## Steps the fade by the frame the engine just drew.
##
## [b]The frame clock rather than the physics one[/b], even though what drives this
## is a physics tick. A fade is a thing the ear hears rather than a thing the world
## does, so it belongs on the clock the player's eyes and ears are actually being
## served at — on a machine drawing 120 frames to 60 ticks, a fade stepped in
## physics would be a fade in eight audible steps instead of sixteen.
func _process(delta: float) -> void:
	settle(delta)


## Moves every voice [param seconds] toward where it should be, and starts or
## stops it at the ends of that move.
##
## [b]The clock is handed in[/b], the same way [method Chime.ring_at] takes one:
## [method Node._process] is this call with the engine's frame in it, and that is
## the only way the game ever reaches it. What it buys is a suite that can assert
## on the middle of a fade — [code]tests/integration/test_tool_racket.gd[/code]
## steps a twentieth of a second in one call instead of waiting a frame and hoping
## the runner drew it quickly. Measured the other way first: on a loaded headless
## run a single frame really is longer than [constant FADE_SECONDS], so a test that
## waited one frame for "partway up" found the fade already finished, and it was
## right to.
##
## Stopping at zero rather than leaving a silent player running: a stream at zero
## gain still costs a mix, and a voice that is restarted from the beginning next
## time it is wanted is also the voice whose loop does not drift out of step with
## the tool being picked up again.
func settle(seconds: float) -> void:
	for which: ToolNoise.Voice in _players:
		var player: AudioStreamPlayer = _players[which]
		var wanted: float = 1.0 if _running and which == _voice else 0.0
		var loudness: float = move_toward(_gains[which], wanted, seconds / FADE_SECONDS)
		_gains[which] = loudness
		if loudness <= 0.0:
			if player.playing:
				player.stop()
			continue
		player.volume_linear = loudness
		if not player.playing:
			player.play()
			_starts += 1


## Runs the noise [param id] makes, or goes on running it if it is already the one
## being heard.
##
## Takes the tool rather than the voice, so the mapping from one to the other lives
## in [method ToolNoise.voice_for] and nowhere else — the caller has a tool in its
## hand and no opinion about how many sounds five tools share between them.
func run(id: DetailingTool.Id) -> void:
	_voice = ToolNoise.voice_for(id)
	_running = true


## Takes the finger off the trigger: whatever is running fades out and stops.
##
## Safe to call on a tick where nothing was running, which is most of them — the
## room calls this every tick the trigger is up rather than only on the tick it
## came up, for [method ToolSight.hold_fire]'s reason.
func hush() -> void:
	_running = false


## Whether the trigger is being held, as this class has been told about it.
##
## Not "is a sound coming out": a voice that has been hushed is still fading for
## [constant FADE_SECONDS] afterwards, and a voice that has just been run has not
## started until the next frame. [method is_sounding] is that question.
func is_running() -> bool:
	return _running


## Whether [param which] voice is actually playing right now.
##
## The honest read-back, and the one a test asks: it is the player's own state
## rather than what this class last intended, so a voice whose stream failed to
## build would answer false here rather than being taken on trust.
func is_sounding(which: ToolNoise.Voice) -> bool:
	if not _players.has(which):
		return false
	return _players[which].playing


## Whether anything at all is making a noise.
func is_making_a_noise() -> bool:
	for which: ToolNoise.Voice in _players:
		if _players[which].playing:
			return true
	return false


## How loud [param which] voice is right now, as [code]0..1[/code] — which is to
## say, where it has got to in its fade.
##
## Public because the fade is the whole reason this class is not three lines, and
## a test that could only see "playing or not" could not tell a ramp from a jump.
func gain(which: ToolNoise.Voice) -> float:
	return _gains.get(which, 0.0)


## How many times a voice has been started since the screen opened.
##
## The countable form of "a held trigger is one sound": a room that restarted the
## stream on every tick would climb this by sixty a second, and nothing about how
## it sounded in a headless test would say so. [method Chime.rings] is the same
## idea for the other half of the game's audio.
func starts() -> int:
	return _starts
