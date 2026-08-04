## Unit tests for [Bell] — the ding, built out of arithmetic.
##
## Under tests/unit/ despite producing an [AudioStreamWAV]: a stream is a
## [Resource], nothing here needs a scene tree, a frame or an audio device, and
## the whole reason the sound is generated rather than recorded is that it can be
## asserted on like any other number. Whether it can be [i]heard[/i] is
## [code]tests/integration/test_chime.gd[/code]'s half of the job.
##
## [b]Two of the assertions below measure a spectrum, and [method _energy_at] is
## how.[/b] It is one bin of a discrete Fourier transform — the samples
## correlated against a sine and a cosine at one frequency — which is a dozen
## lines and needs no library. That is what lets "the partials are whole
## multiples" and "the payout is four notes at once" be measured rather than
## asserted about the constants that were meant to produce them: a test that only
## reads [constant Bell.RATIOS] back would pass just as happily if
## [method Bell.chord] had stopped using it.
extends GutTest

## A tenth of a percent of full scale, for numbers that are all fractions of one.
const TOLERANCE: float = 0.001

## What a sample is worth as a fraction of full scale, so the assertions below
## read in the same units [Bell] normalises in.
const PER_UNIT: float = 1.0 / 32767.0

## The partials of a struck bar — the inharmonic pair [Bell] deliberately does
## [i]not[/i] use any more. They are here as the probe the harmonic partials are
## measured against: a chime built on whole numbers has to have less at 2.76x its
## fundamental than at 2x, and a bell is the other way round.
const BELL_RATIOS: PackedFloat32Array = [2.76, 5.4]

## How long a window the shimmer is measured in, in seconds. Comfortably shorter
## than one beat of [constant Bell.SHIMMER_HZ], so a window lands inside the
## wobble rather than averaging it away.
const WINDOW_SECONDS: float = 0.02


## The samples of [param stream], as [code]-1..1[/code].
##
## [AudioStreamWAV] stores signed 16-bit little-endian, which is exactly what
## [method PackedByteArray.decode_s16] reads — so this is the same arithmetic
## [Bell] did on the way in, run backwards.
func _samples(stream: AudioStreamWAV) -> PackedFloat32Array:
	var data: PackedByteArray = stream.data
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(data.size() / 2)
	for frame: int in out.size():
		out[frame] = float(data.decode_s16(frame * 2)) * PER_UNIT
	return out


## The loudest sample in [param from], as [code]0..1[/code].
func _peak(from: PackedFloat32Array) -> float:
	var loudest: float = 0.0
	for value: float in from:
		loudest = maxf(loudest, absf(value))
	return loudest


## The average loudness of the samples between [param first] and [param last],
## which is how "it is quieter later on" is asked below.
func _loudness(from: PackedFloat32Array, first: int, last: int) -> float:
	var total: float = 0.0
	for frame: int in range(first, last):
		total += absf(from[frame])
	return 0.0 if last <= first else total / float(last - first)


## How many times [param from] crosses zero, which is a pitch measurement that
## needs no Fourier transform: a higher chime crosses more often.
func _crossings(from: PackedFloat32Array) -> int:
	var count: int = 0
	for frame: int in range(1, from.size()):
		if signf(from[frame]) != signf(from[frame - 1]):
			count += 1
	return count


## How much of [param from] sits at [param hz], as an amplitude in the same
## [code]0..1[/code] the samples are in.
##
## One bin of a DFT: correlate against a sine and a cosine at that frequency and
## take the magnitude, which is phase-independent and therefore says nothing
## about when in the buffer the energy arrived — only how much of it there is.
## Divided by the length so two streams of different lengths are comparable.
func _energy_at(from: PackedFloat32Array, hz: float) -> float:
	var real: float = 0.0
	var imaginary: float = 0.0
	for frame: int in from.size():
		var turn: float = TAU * hz * float(frame) / float(Bell.MIX_RATE)
		real += from[frame] * cos(turn)
		imaginary += from[frame] * sin(turn)
	return sqrt(real * real + imaginary * imaginary) / float(from.size())


## The average loudness of every [constant WINDOW_SECONDS] window of
## [param from], in order — the envelope, sampled fine enough to see a shimmer
## in.
func _envelope(from: PackedFloat32Array) -> PackedFloat32Array:
	var width: int = int(WINDOW_SECONDS * float(Bell.MIX_RATE))
	var out: PackedFloat32Array = PackedFloat32Array()
	for first: int in range(0, from.size() - width, width):
		out.append(_loudness(from, first, first + width))
	return out


# ---- the shape of the stream -------------------------------------------------


func test_a_voice_is_a_mono_16_bit_stream_at_the_projects_rate() -> void:
	# What an [AudioStreamPlayer] is handed. Stereo would double the buffer for
	# two identical channels, and a loop would leave a chime ringing forever.
	var stream: AudioStreamWAV = Bell.voice(Bell.Voice.START)
	assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_eq(stream.mix_rate, Bell.MIX_RATE)
	assert_false(stream.stereo, "a chime is one channel")
	assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_DISABLED, "a chime rings once")


func test_a_voice_is_as_long_as_it_says_it_is() -> void:
	# Two bytes a frame at [constant Bell.MIX_RATE], so the byte count is the
	# length — a stream half as long as intended is a ding that got cut off.
	var stream: AudioStreamWAV = Bell.voice(Bell.Voice.START)
	assert_almost_eq(stream.get_length(), Bell.START_SECONDS, 0.01)
	assert_eq(stream.data.size(), int(Bell.START_SECONDS * float(Bell.MIX_RATE)) * 2)


func test_the_same_voice_is_the_same_sound_twice() -> void:
	# Nothing random in here. A chime that came out differently each press would
	# be a bug nobody could reproduce, and it is what a "little variation" would
	# cost if it were ever added carelessly.
	assert_eq(Bell.voice(Bell.Voice.PATCH).data, Bell.voice(Bell.Voice.PATCH).data)


# ---- does it sound like a struck chime ---------------------------------------


func test_it_starts_from_silence_rather_than_from_a_step() -> void:
	# The attack ramp. A waveform that begins at full amplitude begins with a
	# click, which is heard as a fault rather than as a strike.
	var samples: PackedFloat32Array = _samples(Bell.voice(Bell.Voice.START))
	assert_almost_eq(samples[0], 0.0, TOLERANCE, "the chime starts with a step in it")


func test_it_is_loudest_at_the_strike() -> void:
	# A chime is struck and then decays: the peak belongs in the first tenth of
	# the sound, not in the middle of it. Which is also the shimmer's half of the
	# bargain — [method Bell._shimmer] starts at the top of its swing precisely so
	# that this stays true.
	var samples: PackedFloat32Array = _samples(Bell.voice(Bell.Voice.START))
	var tenth: int = samples.size() / 10
	assert_almost_eq(
		_peak(samples.slice(0, tenth)),
		_peak(samples),
		TOLERANCE,
		"the loudest part of the chime is not the strike"
	)


func test_it_decays_all_the_way_to_silence() -> void:
	# The two halves of "ends in silence": quieter as it goes, and near enough to
	# nothing at the end that stopping playback makes no click.
	var samples: PackedFloat32Array = _samples(Bell.voice(Bell.Voice.START))
	var quarter: int = samples.size() / 4
	var early: float = _loudness(samples, 0, quarter)
	var late: float = _loudness(samples, quarter * 3, samples.size())
	assert_lt(late, early * 0.25, "the chime is not decaying")
	assert_lt(absf(samples[samples.size() - 1]), 0.01, "the chime is cut off rather than faded")


func test_it_is_normalised_to_its_own_level_without_clipping() -> void:
	# Normalising is what stops a sum of partials from shipping either inaudible
	# or clipped — see [method Bell.chord]. Asserted on all three voices because
	# they carry deliberately different levels.
	var top: int = Bell.PATCH_RUN_RATIOS.size() - 1
	assert_almost_eq(
		_peak(_samples(Bell.voice(Bell.Voice.START))), Bell.START_LEVEL, 0.01, "the counter chime"
	)
	assert_almost_eq(
		_peak(_samples(Bell.voice(Bell.Voice.PATCH))), Bell.PATCH_LEVEL, 0.01, "the patch chime"
	)
	assert_almost_eq(
		_peak(_samples(Bell.voice(Bell.Voice.PATCH, top))),
		Bell.PAYOUT_LEVEL,
		0.01,
		"the payout chord"
	)


# ---- a casino chime rather than a cast bell ----------------------------------


func test_the_partials_are_whole_multiples_rather_than_a_bells() -> void:
	# The change that moves this from hotel lobby to casino floor: whole-number
	# partials are heard as a note, a bar's 2.76 and 5.4 are heard as a clang.
	# Measured rather than read back off [constant Bell.RATIOS] — see the class
	# docs on why the spectrum is the thing worth asserting.
	var samples: PackedFloat32Array = _samples(Bell.voice(Bell.Voice.PATCH))
	var clang: float = 0.0
	for ratio: float in BELL_RATIOS:
		clang = maxf(clang, _energy_at(samples, Bell.PATCH_HZ * ratio))
	for ratio: float in Bell.RATIOS:
		assert_gt(
			_energy_at(samples, Bell.PATCH_HZ * ratio),
			clang * 3.0,
			"the partial at %.1fx is no louder than the inharmonic ones between them" % ratio
		)


func test_nothing_folds_back_down() -> void:
	# A partial above half the mix rate does not vanish, it aliases back into the
	# audible range as an inharmonic whistle — the one thing a chime built out of
	# whole numbers cannot afford. The ceiling is the ladder's top rung times the
	# top partial, not [constant Bell.PATCH_HZ] times it, which is the easy
	# version of this sum to get wrong.
	var highest: float = 0.0
	for rung: float in Bell.PATCH_RUN_RATIOS:
		for ratio: float in Bell.RATIOS:
			highest = maxf(highest, Bell.PATCH_HZ * rung * ratio)
	assert_almost_eq(Bell.CEILING_HZ, highest, 0.1, "the stated ceiling is not the real one")
	assert_lt(highest, float(Bell.MIX_RATE) * 0.5, "the top partial aliases")


func test_it_shimmers() -> void:
	# The sparkle: the same chime with the shimmer turned off is the control, and
	# the ratio between the two envelopes is the wobble on its own, with the decay
	# and the normalising divided out. It has to come back to full — the strike —
	# and it has to dip well below it in between.
	var shimmering: PackedFloat32Array = _envelope(
		_samples(Bell.chord([Bell.PATCH_HZ] as PackedFloat32Array, Bell.PATCH_SECONDS, 1.0))
	)
	var plain: PackedFloat32Array = _envelope(
		_samples(Bell.chord([Bell.PATCH_HZ] as PackedFloat32Array, Bell.PATCH_SECONDS, 1.0, 0.0))
	)
	var deepest: float = 1.0
	var fullest: float = 0.0
	for window: int in shimmering.size():
		var ratio: float = shimmering[window] / plain[window]
		deepest = minf(deepest, ratio)
		fullest = maxf(fullest, ratio)
	assert_gt(fullest, 0.95, "the shimmer never reaches full amplitude")
	assert_lt(deepest, 1.0 - Bell.SHIMMER_DEPTH, "the shimmer is not deep enough to hear")


# ---- the two voices are actually two -----------------------------------------


func test_the_patch_chime_is_shorter_and_quieter_than_the_counter_chime() -> void:
	# The whole reason there are two: the patch chime arrives in bursts while the
	# water is running, and one as long and as loud as Start's would be a drone.
	var start: AudioStreamWAV = Bell.voice(Bell.Voice.START)
	var patch: AudioStreamWAV = Bell.voice(Bell.Voice.PATCH)
	assert_lt(patch.get_length(), start.get_length())
	assert_lt(_peak(_samples(patch)), _peak(_samples(start)))


func test_the_patch_chime_is_the_higher_of_the_two() -> void:
	# Pitch, measured as zero crossings a second so the test needs no maths the
	# reader has to take on trust. An octave up is about a 2x difference; anything
	# near 1.0 would mean both voices came out of the same numbers.
	var start: PackedFloat32Array = _samples(Bell.voice(Bell.Voice.START))
	var patch: PackedFloat32Array = _samples(Bell.voice(Bell.Voice.PATCH))
	var start_rate: float = float(_crossings(start)) / Bell.START_SECONDS
	var patch_rate: float = float(_crossings(patch)) / Bell.PATCH_SECONDS
	assert_gt(patch_rate, start_rate * 1.2, "the two chimes are the same pitch")


func test_both_voices_are_in_the_same_key() -> void:
	# "Key of C" as a number rather than as a comment: the patch chime is the
	# octave of the counter chime, and the ladder over it is a major triad. Every
	# note this file can produce is C, E or G because of these three lines.
	assert_almost_eq(Bell.PATCH_HZ, Bell.START_HZ * 2.0, 0.01, "the patch chime is not a C")
	assert_eq(
		Bell.PATCH_RUN_RATIOS,
		[1.0, 1.25, 1.5, 2.0] as PackedFloat32Array,
		"the run is not a major triad up to the octave"
	)


# ---- the patch chime climbs a run --------------------------------------------


func test_the_patch_chime_defaults_to_the_bottom_of_the_run() -> void:
	# No run argument at all is how every existing caller of `voice()` spells
	# "first patch of a run" — this is the case the two tests above already rely
	# on, made explicit.
	assert_eq(Bell.voice(Bell.Voice.PATCH).data, Bell.voice(Bell.Voice.PATCH, 0).data)


func test_the_patch_chime_climbs_with_the_run() -> void:
	# Each rung below the payout should be a higher pitch than the last —
	# measured the same zero-crossing way the fixed pitch test above is. The top
	# rung is a chord rather than a note and has its own test below.
	var last_rate: float = 0.0
	for step: int in Bell.PATCH_RUN_RATIOS.size() - 1:
		var samples: PackedFloat32Array = _samples(Bell.voice(Bell.Voice.PATCH, step))
		var rate: float = float(_crossings(samples)) / Bell.PATCH_SECONDS
		assert_gt(rate, last_rate, "step %d was not higher than the one before it" % step)
		last_rate = rate


func test_every_rung_rings_its_own_note() -> void:
	# The climb, checked against the ladder rather than only against itself: a
	# rung has to have more energy at the note it was written as than at any other
	# rung's note, which a pitch measured by zero crossings cannot tell you.
	for step: int in Bell.PATCH_RUN_RATIOS.size() - 1:
		var samples: PackedFloat32Array = _samples(Bell.voice(Bell.Voice.PATCH, step))
		var mine: float = _energy_at(samples, Bell.PATCH_HZ * Bell.PATCH_RUN_RATIOS[step])
		for other: int in Bell.PATCH_RUN_RATIOS.size():
			if other == step:
				continue
			assert_gt(
				mine,
				_energy_at(samples, Bell.PATCH_HZ * Bell.PATCH_RUN_RATIOS[other]),
				"rung %d rings rung %d's note as loudly as its own" % [step, other]
			)


# ---- and pays out at the top -------------------------------------------------


func test_the_top_of_the_run_pays_out_the_whole_triad() -> void:
	# The winner: every rung of the ladder struck at once. Each note of it has to
	# actually be in there — a chord that lost a note on the way through
	# [method Bell.chord] would still be a pleasant ding, and nothing else in this
	# suite would notice.
	var top: int = Bell.PATCH_RUN_RATIOS.size() - 1
	var samples: PackedFloat32Array = _samples(Bell.voice(Bell.Voice.PATCH, top))
	var loudest: float = 0.0
	for rung: float in Bell.PATCH_RUN_RATIOS:
		loudest = maxf(loudest, _energy_at(samples, Bell.PATCH_HZ * rung))
	for rung: float in Bell.PATCH_RUN_RATIOS:
		assert_gt(
			_energy_at(samples, Bell.PATCH_HZ * rung),
			loudest * 0.15,
			"the payout is missing the note at %.2fx" % rung
		)


func test_a_single_rung_is_not_a_chord() -> void:
	# The control for the test above: the same measurement on a plain rung finds
	# one note and not four, so "all four are present" means something.
	var samples: PackedFloat32Array = _samples(Bell.voice(Bell.Voice.PATCH))
	assert_lt(
		_energy_at(samples, Bell.PATCH_HZ * 1.25),
		_energy_at(samples, Bell.PATCH_HZ) * 0.15,
		"the first rung is ringing the third of the chord as well as its root"
	)


func test_the_payout_rings_longer_and_lands_harder_than_a_rung() -> void:
	# It is the one moment in the game allowed to hang in the air, and it is
	# still under the counter chime so that nothing here is the loudest thing in
	# the mix.
	var top: int = Bell.PATCH_RUN_RATIOS.size() - 1
	var payout: AudioStreamWAV = Bell.voice(Bell.Voice.PATCH, top)
	assert_gt(payout.get_length(), Bell.voice(Bell.Voice.PATCH).get_length())
	assert_gt(Bell.PAYOUT_LEVEL, Bell.PATCH_LEVEL, "the payout is no louder than a rung")
	assert_lt(Bell.PAYOUT_LEVEL, Bell.START_LEVEL, "the payout is the loudest thing in the game")


func test_a_run_past_the_top_holds_on_the_top_note_rather_than_paying_again() -> void:
	# A sweep that keeps going holds at the top of the ladder, so a payout there
	# would re-pay on every patch — see [method Bell.voice]. What it rings instead
	# is the top note on its own, at a plain rung's length, and it rings the same
	# one however long the sweep goes on.
	var top: int = Bell.PATCH_RUN_RATIOS.size() - 1
	var held: AudioStreamWAV = Bell.voice(Bell.Voice.PATCH, top + 1)
	assert_ne(held.data, Bell.voice(Bell.Voice.PATCH, top).data, "it paid out twice")
	assert_eq(held.data, Bell.voice(Bell.Voice.PATCH, top + 5).data, "the hold is not a hold")
	assert_almost_eq(held.get_length(), Bell.PATCH_SECONDS, 0.01)
	var samples: PackedFloat32Array = _samples(held)
	assert_gt(
		_energy_at(samples, Bell.PATCH_HZ * Bell.PATCH_RUN_RATIOS[top]),
		_energy_at(samples, Bell.PATCH_HZ) * 3.0,
		"the hold dropped back down the ladder instead of staying at the top"
	)


# ---- the knobs under all of it -----------------------------------------------


func test_a_chime_can_be_struck_at_any_pitch_and_length() -> void:
	# The knob under every voice. A tuning change is a number here rather than a
	# re-recording, which is the entire argument for generating the sound.
	var quiet: AudioStreamWAV = Bell.strike(440.0, 0.2, 0.3)
	assert_almost_eq(quiet.get_length(), 0.2, 0.01)
	assert_almost_eq(_peak(_samples(quiet)), 0.3, 0.01)


func test_a_chord_is_every_note_it_was_given() -> void:
	# And the knob under the payout: any set of notes, struck together, still
	# normalised to the level asked for rather than to the sum of its parts.
	var notes: PackedFloat32Array = [440.0, 660.0]
	var struck: AudioStreamWAV = Bell.chord(notes, 0.3, 0.4)
	assert_almost_eq(_peak(_samples(struck)), 0.4, 0.01, "a chord is not normalised like a note")
	for hz: float in notes:
		assert_gt(_energy_at(_samples(struck), hz), 0.0, "the chord is missing %.0f Hz" % hz)
