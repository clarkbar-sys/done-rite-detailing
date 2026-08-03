## Unit tests for [Fanfare] — the arrangement, and the stream it renders to.
##
## Under tests/unit/ for the reason [code]tests/unit/test_bell.gd[/code] is: an
## [AudioStreamWAV] is a [Resource] and nothing here needs a tree, a frame or a
## sound card. [code]tests/integration/test_bandstand.gd[/code] is the half that
## needs all three.
##
## [b]The theme is built once, in [method before_all].[/b] It costs about a third
## of a second (the class docs have the measurement), and a suite that rebuilt it
## per test would spend most of its runtime rendering the same samples twenty
## times over. Nothing below mutates it.
##
## [b]What is asserted and what is not.[/b] Everything structural — the length,
## the loop, the level, the seam, that the notes are the notes the score says —
## is here. Whether the tune is any [i]good[/i] is not a thing a test can hold,
## and pretending otherwise by asserting on a hash of the samples would only
## mean nobody could ever retune it without a test failing for no reason. The one
## exception is [method test_the_theme_is_the_same_theme_twice], which asserts
## determinism rather than any particular sound.
extends GutTest

## A frequency probe wide enough to resolve a semitone at the pitches the melody
## uses, in samples.
const PROBE: int = 3000

## How far into a note to start probing, in samples — past the attack, where the
## envelope is at its loudest and the neighbouring note has finished.
const SETTLED: int = 1200

var _theme: AudioStreamWAV = null
var _samples: PackedFloat32Array = PackedFloat32Array()


func before_all() -> void:
	_theme = Fanfare.theme()
	_samples = _decode(_theme)


## The samples of [param stream] as [code]-1..1[/code].
##
## [AudioStreamWAV] stores signed 16-bit little-endian, which is exactly what
## [method PackedByteArray.decode_s16] reads — the same arithmetic
## [method Fanfare._encode] did on the way in, run backwards.
func _decode(stream: AudioStreamWAV) -> PackedFloat32Array:
	var data: PackedByteArray = stream.data
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(data.size() / 2)
	for frame: int in out.size():
		out[frame] = float(data.decode_s16(frame * 2)) / 32767.0
	return out


## How much of [param at_hz] is in the [constant PROBE] samples starting at
## [param from]. One bin of a DFT — [code]tests/unit/test_timbre.gd[/code] has
## the argument for why this rather than counting zero crossings.
func _goertzel(from: int, at_hz: float) -> float:
	var coefficient: float = 2.0 * cos(TAU * at_hz / float(Timbre.MIX_RATE))
	var back_one: float = 0.0
	var back_two: float = 0.0
	for frame: int in range(from, mini(from + PROBE, _samples.size())):
		var now: float = _samples[frame] + coefficient * back_one - back_two
		back_two = back_one
		back_one = now
	var power: float = back_one * back_one + back_two * back_two - coefficient * back_one * back_two
	return sqrt(maxf(power, 0.0)) / float(PROBE)


## The frame the note written at [param step] starts on, plus [constant SETTLED].
func _into(step: int) -> int:
	return roundi(float(step) * Fanfare.step_seconds() * float(Timbre.MIX_RATE)) + SETTLED


## The average loudness of the samples between [param first] and [param last].
func _loudness(first: int, last: int) -> float:
	var total: float = 0.0
	for frame: int in range(maxi(first, 0), mini(last, _samples.size())):
		total += absf(_samples[frame])
	return 0.0 if last <= first else total / float(last - first)


## The loudest sample anywhere in the theme, as [code]0..1[/code].
func _peak() -> float:
	var loudest: float = 0.0
	for value: float in _samples:
		loudest = maxf(loudest, absf(value))
	return loudest


# ---- the shape of the stream -------------------------------------------------


func test_the_theme_is_a_mono_16_bit_stream_at_the_projects_rate() -> void:
	assert_eq(_theme.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_eq(_theme.mix_rate, Timbre.MIX_RATE)
	assert_false(_theme.stereo, "stereo would double the buffer for two identical channels")


func test_the_theme_loops_forward_over_the_whole_of_itself() -> void:
	# The loop is set on the resource and not on the player, and that is not a
	# style choice: Godot's web export hands a sample to the browser and ignores
	# an [AudioStreamPlayer]'s own looping flag. [Bandstand] has the rest of it.
	assert_eq(_theme.loop_mode, AudioStreamWAV.LOOP_FORWARD, "the title theme has to repeat")
	assert_eq(_theme.loop_begin, 0, "a loop that starts late drops the downbeat")
	assert_eq(_theme.loop_end, _samples.size(), "a loop that ends early drops the run home")


func test_the_theme_is_eight_bars_long_at_the_tempo_it_says() -> void:
	assert_almost_eq(_theme.get_length(), Fanfare.seconds(), 0.01)
	assert_almost_eq(Fanfare.seconds(), 14.545, 0.01, "eight bars of 4/4 at 132 BPM")


func test_the_theme_leaves_room_for_a_bell_over_the_top_of_it() -> void:
	# [constant Fanfare.LEVEL]. Start rings a bell on the same press that fades
	# this out, and a theme normalised to full scale would leave the bell
	# nowhere to go but into the clipping.
	assert_almost_eq(_peak(), Fanfare.LEVEL, 0.005)


# ---- the seam ----------------------------------------------------------------


func test_the_loop_does_not_click_where_it_joins() -> void:
	# The most audible fault a piece of looping game music can have, and it
	# happens once every fifteen seconds forever. Both ends have to be near zero
	# *and* near each other — a loop that jumped from full positive to full
	# negative at the join is a step, and a step is a click.
	var first: float = _samples[0]
	var last: float = _samples[_samples.size() - 1]
	assert_lt(absf(first - last), 0.25, "the loop joins on a step")


func test_the_tail_of_the_last_bar_is_carried_onto_the_front() -> void:
	# [method Fanfare._place] wraps. Without it the first few milliseconds of the
	# loop are the only place in the piece with nothing decaying underneath, and
	# the seam is audible as a gap rather than as a join.
	assert_gt(_loudness(0, 400), 0.01, "the loop starts from a hole")


# ---- the tune ----------------------------------------------------------------


func test_the_melody_starts_on_the_tonic() -> void:
	# Bar 1, step 0: D5, per the score. Asserted against the semitone either
	# side, because "there is energy at 587 Hz" is also true of a piece that is
	# mostly noise.
	var at: int = _into(0)
	var tonic: float = _goertzel(at, Timbre.hz(Fanfare.D5))
	assert_gt(tonic, _goertzel(at, Timbre.hz(Fanfare.D5 + 1)) * 3.0, "sharp of the tonic")
	assert_gt(tonic, _goertzel(at, Timbre.hz(Fanfare.D5 - 1)) * 3.0, "flat of the tonic")


func test_the_top_of_the_first_half_is_the_note_the_score_says() -> void:
	# Bar 3, step 36: G5, held for half a bar — the peak of the call.
	var at: int = _into(36)
	assert_gt(
		_goertzel(at, Timbre.hz(Fanfare.G5)),
		_goertzel(at, Timbre.hz(Fanfare.D5)) * 3.0,
		"bar 3 is not where the score put it"
	)


func test_the_last_bar_runs_home_to_the_note_the_loop_starts_on() -> void:
	# Bar 8 ends on E5, a step below the D5 that step 0 begins with, over an A
	# chord — so the loop point is a resolution rather than a join. If this ever
	# stops being true the seam stops being musical, and no assertion about
	# samples above would notice.
	var at: int = _into(126)
	assert_gt(
		_goertzel(at, Timbre.hz(Fanfare.E5)),
		_goertzel(at, Timbre.hz(Fanfare.E5 + 2)) * 2.0,
		"the run home does not end where the score says"
	)


func test_the_bass_is_under_the_chord_the_bar_is_written_on() -> void:
	# Bar 3 is G, and the bass root under it is G2. A bass that stayed on D
	# through the fourth chord is the single most audible thing that can go wrong
	# in an arrangement written as two separate tables.
	var at: int = _into(Fanfare.STEPS_PER_BAR * 2)
	assert_gt(
		_goertzel(at, Timbre.hz(Fanfare.G2)),
		_goertzel(at, Timbre.hz(Fanfare.D3)) * 2.0,
		"the bass did not follow the chord"
	)


func test_every_bar_has_a_downbeat_on_it() -> void:
	# The kick, on step 0 of all eight. A bar that lost its downbeat would still
	# render, still loop and still be the right length.
	for bar: int in Fanfare.BARS:
		var at: int = _into(bar * Fanfare.STEPS_PER_BAR) - SETTLED
		assert_gt(_loudness(at, at + 900), 0.05, "bar %d has no downbeat" % (bar + 1))


func test_the_second_half_lifts() -> void:
	# The whole reason the piece is eight bars rather than four: the hats double
	# to sixteenths and the horns pick up the offbeat from
	# [constant Fanfare.LIFT_BAR]. If the two halves measured the same, the
	# arrangement would be four bars played twice and the loop would read as one.
	var half: int = _samples.size() / 2
	assert_gt(_loudness(half, _samples.size()), _loudness(0, half), "the second half does not lift")


# ---- determinism -------------------------------------------------------------


func test_the_theme_is_the_same_theme_twice() -> void:
	# Same samples, every call, every machine, every run. Without it the theme
	# could not be reviewed by listening to it once, and every assertion above is
	# only a statement about the build that happened to run.
	assert_eq(Fanfare.theme().data, _theme.data)


func test_each_call_hands_back_a_stream_of_its_own() -> void:
	# [method Fanfare.theme] deliberately does not cache, for the reason
	# [method Bell.voice] gives: a shared [AudioStreamWAV] is a mutable global
	# with the game's audio hanging off it.
	assert_ne(Fanfare.theme(), _theme, "two callers were handed the same stream")


# ---- the score is internally consistent --------------------------------------


func test_every_bar_has_a_chord_and_a_root() -> void:
	# That each row *has* three numbers in it is [Vector3i]'s job rather than a
	# test's — the class docs have why the score is written in one. What is left
	# for here is that there are as many of them as there are bars.
	assert_eq(Fanfare.ROOTS.size(), Fanfare.BARS, "a bar with no bass root")
	assert_eq(Fanfare.CHORD_TONES.size(), Fanfare.BARS, "a bar with no chord")


func test_the_score_survives_being_read_at_runtime() -> void:
	# The regression guard for the engine bug the class docs describe: on Godot
	# 4.7.1 a `const Array[PackedInt32Array]` hands back uninitialised memory for
	# any access that is not constant-folded, and the theme built from it came
	# out as clipped noise with no error anywhere. Every number in the score is
	# a step, a MIDI note or a length, so all of them are small — reading a
	# pointer instead is off by seven orders of magnitude and this catches it.
	for row: Vector3i in Fanfare.MELODY:
		assert_between(row[Fanfare.STEP], 0, Fanfare.STEPS, "step out of range: %s" % [row])
		assert_between(row[Fanfare.NOTE], 1, 127, "note is not a MIDI pitch: %s" % [row])
		assert_between(row[Fanfare.LENGTH], 1, Fanfare.STEPS, "length out of range: %s" % [row])
	for bar: int in Fanfare.BARS:
		for tone: int in 3:
			assert_between(Fanfare.CHORD_TONES[bar][tone], 1, 127, "chord tone is not a MIDI pitch")


func test_no_note_is_written_past_the_end_of_the_loop() -> void:
	# [method Fanfare._place] wraps, so a note written past the end would be
	# silently mixed onto the front rather than caught — which is the right
	# behaviour for a tail and the wrong one for a typo.
	for row: Vector3i in Fanfare.MELODY:
		assert_lt(row[Fanfare.STEP], Fanfare.STEPS, "a note starts after the loop has ended")


func test_the_melody_is_written_in_the_order_it_is_played() -> void:
	# Not something [method Fanfare._lay_melody] requires — it places each row
	# independently — but a score out of order is unreadable, and the bar
	# comments pairing the melody to the harmony would be pointing at the wrong
	# notes.
	var last: int = -1
	for row: Vector3i in Fanfare.MELODY:
		assert_gt(row[Fanfare.STEP], last, "the score doubles back on itself")
		last = row[Fanfare.STEP]
