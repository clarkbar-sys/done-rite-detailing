## The thing that actually plays the theme: one player, one stream built at
## startup, and a fade that outlives the screen that asked for it.
##
## [Chime] is the same shape for the bell and its class docs carry most of the
## argument for why this is a class at all rather than an [AudioStreamPlayer]
## dropped onto the title screen. The short version, and it is the whole reason
## this file exists: [code]src/main/main.gd[/code] calls
## [method Node.remove_child] and [method Node.queue_free] on the outgoing screen
## the instant it asks for a transition, so a three-second fade owned by the
## title screen would be freed on the first frame of the fade and Start would cut
## the music dead. This hangs off the host, which outlives every screen.
##
## Screens do not reach for it. They call [method GameScreen.request_music] and
## [method GameScreen.stop_music], which the host connects — the same
## one-direction wiring transitions and the bell already use.
##
## [b]The browser will not let this start on its own.[/b] A page may not make a
## noise until somebody has touched it. The title screen therefore starts the
## theme on the first press, key or touch it sees rather than when it opens, and
## that is also the gesture Godot's web export resumes the audio context on. It
## is the same rule the bell lives under — [Chime] has it at length — and it is
## why there is no [code]autoplay[/code] anywhere in this file.
##
## [b]Why this one player is set to stream and the bell's four are not.[/b] Godot
## plays audio on the web through the Web Audio API as a [i]sample[/i] by default,
## which is what keeps sound from garbling in a single-threaded export — and ours
## is single-threaded, deliberately, because we ship the no-threads web template
## (STANDARDS.md "Distribution" has that decision). A sample is handed to the
## browser once, at the volume it had when it started, and changes to
## [member AudioStreamPlayer.volume_db] after that are ignored. That is fine for
## a bell, which is played once at one volume and never touched again. It is
## fatal for a fade, which is nothing but changing the volume of something
## already playing. So this player — and only this player — asks for
## [constant AudioServer.PLAYBACK_TYPE_STREAM], where the engine does its own
## mixing and the volume is live. The cost is latency, which matters to a sound
## that answers a button press and does not matter at all to fifteen seconds of
## music on a loop.
class_name Bandstand
extends Node

## How long the theme takes to go, in seconds, when nobody says otherwise.
## Three: long enough to read as the music stepping aside for the game rather
## than being switched off, short enough to be finished before the player has
## picked up a tool.
const FADE_SECONDS: float = 3.0

## Where the fade ends before the player is stopped, in decibels. Not silence —
## a tween to negative infinity never arrives — and low enough that the stop at
## the end of it is inaudible: -40 dB is a hundredth of the amplitude it started
## at, which is under the noise floor of any speaker this will be heard on.
const FADE_FLOOR_DB: float = -40.0

var _player: AudioStreamPlayer = null
var _fade: Tween = null


func _ready() -> void:
	# Built here and kept for the life of the game, the same as [Chime]'s voices
	# and for the same reason: the arithmetic is a loop over a third of a million
	# samples ([Fanfare]), and a game that built it on the press that plays it
	# would hitch on exactly the frame the player is waiting for a response to.
	# Here it lands during the boot the loading screen is already covering.
	_player = AudioStreamPlayer.new()
	_player.name = "Theme"
	_player.stream = Fanfare.theme()
	# See the class docs. Sample playback would ignore every volume change the
	# fade makes, on the one platform this game is actually played on.
	_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(_player)


## Starts the theme, from the top, unless it is already playing.
##
## Idempotent because the caller is "the first input on the title screen" and
## proving something is the first of anything is harder than making the second
## one harmless. A call that arrives during a fade takes the fade off and brings
## the volume back up rather than restarting — that is a player who pressed a key
## and then thought better of it, and restarting the tune under them would be the
## more surprising answer.
func start() -> void:
	_cancel_fade()
	if _player.playing:
		return
	_player.play()


## Takes the theme away over [param seconds], then stops it.
##
## The duration is an argument rather than only a constant for the reason
## [method Chime.ring_at] takes a clock: it is how the suite tests a three-second
## fade without waiting three seconds for every assertion.
##
## Does nothing if nothing is playing — Start is pressed on a title screen that
## nobody touched first about as often as it is pressed on one they did.
func fade_out(seconds: float = FADE_SECONDS) -> void:
	if not _player.playing:
		return
	_cancel_fade()
	_fade = create_tween()
	_fade.tween_property(_player, "volume_db", FADE_FLOOR_DB, seconds)
	# Not `tween_callback(_player.stop)`: the volume has to go back up as well,
	# or a later [method start] would begin at -40 dB and read as the music
	# having failed rather than as having been faded.
	_fade.tween_callback(_silence)


## Whether the theme is sounding at all — the honest version of "did the title
## screen start the music".
func playing() -> bool:
	return _player.playing


## Whether a fade is running right now.
func fading() -> bool:
	return _fade != null and _fade.is_valid() and _fade.is_running()


## How loud the theme is at this moment, in decibels. 0.0 is full, and it only
## moves while a fade is running.
func level_db() -> float:
	return _player.volume_db


## Stops the player and puts the volume back where [method start] expects it.
func _silence() -> void:
	_player.stop()
	_player.volume_db = 0.0


## Drops any fade in flight and returns the player to full volume.
##
## [method Tween.kill] rather than letting it run out: a tween left alive would
## keep driving [member AudioStreamPlayer.volume_db] down underneath a theme that
## has just been asked to start again.
func _cancel_fade() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = null
	_player.volume_db = 0.0
