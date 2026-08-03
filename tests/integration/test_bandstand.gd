## Integration test for [Bandstand] — the player that holds the theme, and the
## fade that has to outlive the screen which asked for it.
##
## Under tests/integration/ because a [Bandstand] builds its player in
## [method Node._ready], asks it whether it is playing, and drives the fade with
## a [Tween] — and all three of those need it in a tree with frames going past.
## What the theme is made of is [code]tests/unit/test_fanfare.gd[/code].
##
## [b]The fade is asked for in tens of milliseconds, not three seconds.[/b]
## [method Bandstand.fade_out] takes its duration as an argument for exactly this
## reason, the same way [method Chime.ring_at] takes a clock: a suite that waited
## out a real three-second fade per assertion would be slow and would still be
## flaky on a loaded runner. That the default is three seconds is asserted once,
## as a constant, rather than by sitting through it.
extends GutTest

## A fade short enough to wait out several times in a suite, long enough that a
## frame lands inside it.
const QUICK: float = 0.2

var _music: Bandstand = null


func before_each() -> void:
	_music = Bandstand.new()
	add_child_autofree(_music)


func test_it_builds_a_player_with_the_theme_already_on_it() -> void:
	# Built in `_ready` rather than on the press that plays it — a third of a
	# second of arithmetic ([Fanfare] has the measurement) on the frame somebody
	# is waiting for a response would be felt as the game stalling.
	assert_eq(_music.get_child_count(), 1, "the theme needs exactly one player")
	var player: AudioStreamPlayer = _music.get_child(0) as AudioStreamPlayer
	assert_not_null(player, "the child is not an audio player")
	assert_not_null(player.stream, "the player was built with no theme on it")


func test_the_theme_it_holds_loops() -> void:
	# A title theme that played once and stopped would leave the attract mode
	# running in silence, which is worse than never having started.
	var player: AudioStreamPlayer = _music.get_child(0) as AudioStreamPlayer
	var stream: AudioStreamWAV = player.stream as AudioStreamWAV
	assert_not_null(stream)
	assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD)


func test_the_player_asks_for_stream_playback_rather_than_sample() -> void:
	# The one setting in this file that is load-bearing on a platform the suite
	# cannot reach. Godot plays audio on the web as a Web Audio *sample* by
	# default, and a sample keeps the volume it started with — every change after
	# `play()` is ignored. A fade is nothing but changing the volume of something
	# already playing, so on the web this player must be on the streamed path or
	# Start would cut the music dead instead of fading it. [Bandstand] has the
	# whole argument; this is the assertion that stops it being quietly undone.
	var player: AudioStreamPlayer = _music.get_child(0) as AudioStreamPlayer
	assert_eq(player.playback_type, AudioServer.PLAYBACK_TYPE_STREAM)


func test_nothing_plays_until_it_is_asked_for() -> void:
	# A browser drops any sound a page makes before somebody has touched it, so a
	# theme that started itself would not exist for most of the people who see
	# this game. The title screen starts it on the first press.
	assert_false(_music.playing(), "the game made a noise nobody asked for")


func test_starting_plays_the_theme() -> void:
	_music.start()
	assert_true(_music.playing())


func test_starting_twice_does_not_restart_it() -> void:
	# The caller is "the first input on the title screen", and proving something
	# is the first of anything is harder than making the second one harmless.
	_music.start()
	await wait_process_frames(2)
	var was: float = (_music.get_child(0) as AudioStreamPlayer).get_playback_position()
	_music.start()
	assert_true(_music.playing())
	assert_gt(
		(_music.get_child(0) as AudioStreamPlayer).get_playback_position(),
		was * 0.5,
		"the second start threw the theme back to the top"
	)


func test_fading_takes_the_volume_down() -> void:
	_music.start()
	assert_almost_eq(_music.level_db(), 0.0, 0.001, "it should start at full")
	_music.fade_out(QUICK)
	await wait_process_frames(4)
	assert_true(_music.fading(), "the fade is not running")
	assert_lt(_music.level_db(), 0.0, "the volume never moved")


func test_a_fade_ends_in_silence_and_puts_the_volume_back() -> void:
	# Both halves matter. Stopping is what the fade is for; putting the level
	# back is what stops a later [method Bandstand.start] from beginning at -40
	# dB, which would read as the music having failed rather than having faded.
	_music.start()
	_music.fade_out(QUICK)
	await wait_seconds(QUICK + 0.15)
	assert_false(_music.playing(), "the theme is still going after its fade finished")
	assert_almost_eq(_music.level_db(), 0.0, 0.001, "the next start would begin silent")


func test_the_theme_is_still_audible_while_it_fades() -> void:
	# The whole point, and the failure this class exists to prevent: Start must
	# not cut the music dead. Checked at the midpoint of the fade, which is where
	# a `stop()` dressed up as a fade would already have failed.
	_music.start()
	_music.fade_out(QUICK)
	await wait_seconds(QUICK * 0.5)
	assert_true(_music.playing(), "the theme was cut off rather than faded")
	assert_gt(_music.level_db(), Bandstand.FADE_FLOOR_DB, "it is already at the floor")


func test_fading_something_that_is_not_playing_is_harmless() -> void:
	# Start is pressed on a title screen nobody touched first about as often as
	# it is pressed on one they did.
	_music.fade_out(QUICK)
	assert_false(_music.playing())
	assert_false(_music.fading(), "a fade started with nothing to fade")


func test_starting_during_a_fade_brings_it_back_rather_than_leaving_it_sinking() -> void:
	# A tween left alive would go on driving the volume down underneath a theme
	# that had just been asked to start again — the bug that turns a
	# changed-my-mind press into music that quietly disappears.
	_music.start()
	_music.fade_out(QUICK)
	await wait_process_frames(3)
	_music.start()
	await wait_process_frames(3)
	assert_true(_music.playing())
	assert_false(_music.fading(), "the fade is still running under the restart")
	assert_almost_eq(_music.level_db(), 0.0, 0.001, "the theme came back quiet")


func test_the_default_fade_is_the_three_seconds_start_asks_for() -> void:
	# Asserted as a constant rather than by sitting through one. Three seconds:
	# long enough to read as the music stepping aside for the game, short enough
	# to be over before the player has picked up a tool.
	assert_almost_eq(Bandstand.FADE_SECONDS, 3.0, 0.001)
