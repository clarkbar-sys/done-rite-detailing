## Unit tests for [Timbre] — the six voices of the title theme, as arithmetic.
##
## Under tests/unit/ for the reason [code]tests/unit/test_bell.gd[/code] is:
## nothing here needs a scene tree, a frame or an audio device. A voice is a
## [PackedFloat32Array] and the whole point of generating it rather than
## recording it is that it can be asserted on like any other number. Whether the
## theme built out of these can be [i]heard[/i] is
## [code]tests/integration/test_bandstand.gd[/code]'s half of the job.
##
## [b]How pitch is asserted without a Fourier transform.[/b] [method _goertzel]
## is one bin of a DFT — twelve lines, no dependency — and it answers "how much
## of exactly this frequency is in these samples". That is the question every
## assertion about a note is really asking, and it is far stronger than counting
## zero crossings: a saw at 440 Hz and a saw at 440 Hz with an aliasing whistle
## on top cross zero the same number of times.
extends GutTest

## How long a test note is, in seconds. Long enough for [method _goertzel] to
## resolve a semitone at the pitches this arrangement uses, short enough that a
## suite of them runs in no time at all.
const NOTE_SECONDS: float = 0.25

## A4, the note most of the pitch assertions below are written against.
const A4: int = 69

## Middle C.
const C4: int = 60


## How much of [param at_hz] is in [param samples], as a fraction of full scale.
##
## The Goertzel algorithm: a single-bin DFT, which is a two-pole resonator run
## over the samples with its output read at the end. Normalised by the sample
## count so the answer means the same thing for notes of different lengths.
func _goertzel(samples: PackedFloat32Array, at_hz: float) -> float:
	var coefficient: float = 2.0 * cos(TAU * at_hz / float(Timbre.MIX_RATE))
	var back_one: float = 0.0
	var back_two: float = 0.0
	for value: float in samples:
		var now: float = value + coefficient * back_one - back_two
		back_two = back_one
		back_one = now
	var power: float = back_one * back_one + back_two * back_two - coefficient * back_one * back_two
	return sqrt(maxf(power, 0.0)) / float(maxi(samples.size(), 1))


## The loudest sample in [param samples], as [code]0..1[/code].
func _peak(samples: PackedFloat32Array) -> float:
	var loudest: float = 0.0
	for value: float in samples:
		loudest = maxf(loudest, absf(value))
	return loudest


## The average loudness of the samples between [param first] and [param last] —
## how "it is quieter by now" is asked below.
func _loudness(samples: PackedFloat32Array, first: int, last: int) -> float:
	var total: float = 0.0
	for frame: int in range(first, mini(last, samples.size())):
		total += absf(samples[frame])
	return 0.0 if last <= first else total / float(last - first)


# ---- the shape of a note -----------------------------------------------------


func test_a_note_is_as_long_as_it_is_asked_for() -> void:
	var note: PackedFloat32Array = Timbre.note(Timbre.Voice.BRASS, A4, NOTE_SECONDS)
	assert_eq(note.size(), Timbre.frames(NOTE_SECONDS))


func test_a_note_of_no_length_is_still_a_sample_rather_than_nothing() -> void:
	# A note rounded down to an empty array is silence that no assertion about
	# pitch or envelope can see, so it would fail somewhere much less obvious.
	assert_eq(Timbre.note(Timbre.Voice.BRASS, A4, 0.0).size(), 1)


func test_a_note_stays_inside_the_range_it_promises() -> void:
	# [Fanfare] sums six of these before deciding how loud anything is. A voice
	# that came back outside -1..1 would make that sum's normalisation a
	# different, quieter answer for every part of the arrangement.
	for voice: Timbre.Voice in Timbre.Voice.values():
		assert_lt(
			_peak(Timbre.note(voice, A4, NOTE_SECONDS)),
			1.01,
			"voice %d came back louder than full scale" % voice
		)


func test_every_voice_makes_a_sound() -> void:
	# A voice that returned zeroes would be a silent instrument in the mix, and
	# the theme would still build, still loop and still pass every length
	# assertion above.
	for voice: Timbre.Voice in Timbre.Voice.values():
		assert_gt(_peak(Timbre.note(voice, A4, NOTE_SECONDS)), 0.1, "voice %d is silent" % voice)


func test_a_note_starts_from_silence() -> void:
	# The attack ramp. A waveform that starts at full amplitude starts with a
	# step, and a step is a click — on a theme that loops, once every fifteen
	# seconds forever.
	for voice: Timbre.Voice in Timbre.Voice.values():
		assert_almost_eq(
			Timbre.note(voice, A4, NOTE_SECONDS)[0], 0.0, 0.05, "voice %d begins on a step" % voice
		)


func test_a_note_ends_in_silence() -> void:
	# The release ramp, and the same argument as the attack: a note cut off at
	# full amplitude is a click, and here it would be one per note per loop.
	for voice: Timbre.Voice in Timbre.Voice.values():
		var note: PackedFloat32Array = Timbre.note(voice, A4, NOTE_SECONDS)
		assert_almost_eq(note[note.size() - 1], 0.0, 0.05, "voice %d ends on a step" % voice)


# ---- pitch -------------------------------------------------------------------


func test_a_pitched_note_is_the_pitch_it_was_asked_for() -> void:
	for voice: Timbre.Voice in [Timbre.Voice.BRASS, Timbre.Voice.HORN, Timbre.Voice.BASS]:
		var note: PackedFloat32Array = Timbre.note(voice, A4, NOTE_SECONDS)
		var wanted: float = _goertzel(note, Timbre.hz(A4))
		var semitone_up: float = _goertzel(note, Timbre.hz(A4 + 1))
		assert_gt(wanted, semitone_up * 3.0, "voice %d is not centred on its own note" % voice)


func test_an_octave_up_is_twice_the_frequency() -> void:
	# The one relationship in the whole tuning that has to be exact, because the
	# bass lifts by an octave in two bars of [Fanfare] and an octave that was not
	# a doubling would be heard as a wrong note rather than as a lift.
	assert_almost_eq(Timbre.hz(A4 + 12), Timbre.hz(A4) * 2.0, 0.001)


func test_concert_a_is_where_everybody_else_put_it() -> void:
	assert_almost_eq(Timbre.hz(A4), 440.0, 0.001)


func test_a_high_note_does_not_fold_back_down_as_a_whistle() -> void:
	# Aliasing, which is the price of a wavetable and the reason there is a stack
	# of them rather than one. A table drawn with harmonics above the ceiling and
	# then read fast puts energy at frequencies that are in no chord — the test
	# is that a note two octaves above A4 has far less energy at a frequency
	# nothing in its harmonic series can explain than at its own fundamental.
	var high: int = A4 + 24
	var note: PackedFloat32Array = Timbre.note(Timbre.Voice.BRASS, high, NOTE_SECONDS)
	var fundamental: float = _goertzel(note, Timbre.hz(high))
	# Deliberately not a harmonic of the note, and low enough to be audible as a
	# whistle under it if the table folded.
	var nowhere: float = _goertzel(note, Timbre.hz(high) * 0.41)
	assert_gt(fundamental, nowhere * 10.0, "the top of the range is aliasing")


# ---- what each voice is for --------------------------------------------------


func test_the_bass_is_hollow_where_the_brass_is_thick() -> void:
	# [constant Timbre.BASS_ODD_LIFT]. The bass leans towards a square, which is
	# what lets it survive a phone speaker with no bottom end: the odd harmonics
	# carry the pitch when the fundamental is simply not reproduced.
	var third: float = _goertzel(
		Timbre.note(Timbre.Voice.BASS, C4, NOTE_SECONDS), Timbre.hz(C4) * 3.0
	)
	var brass_third: float = _goertzel(
		Timbre.note(Timbre.Voice.BRASS, C4, NOTE_SECONDS), Timbre.hz(C4) * 3.0
	)
	assert_gt(third, brass_third, "the bass lost the harmonic it is carried by")


func test_the_kick_falls_in_pitch() -> void:
	# A kick that did not sweep would be a tone, and the sweep is the transient
	# that makes it read as a drum being hit.
	var kick: PackedFloat32Array = Timbre.note(Timbre.Voice.KICK, 0, Timbre.KICK_SECONDS)
	var front: PackedFloat32Array = kick.slice(0, 700)
	var back: PackedFloat32Array = kick.slice(1500, 2200)
	assert_gt(
		_goertzel(front, Timbre.KICK_TOP_HZ),
		_goertzel(back, Timbre.KICK_TOP_HZ),
		"the kick never leaves the top of its sweep"
	)
	assert_gt(
		_goertzel(back, Timbre.KICK_BOTTOM_HZ),
		_goertzel(front, Timbre.KICK_BOTTOM_HZ),
		"the kick never arrives at the bottom of its sweep"
	)


func test_the_snare_is_cut_off_dead_rather_than_left_to_decay() -> void:
	# [constant Timbre.SNARE_GATE_SECONDS] — the one number that dates this
	# arrangement. Asked for over a snare rendered long enough to have a tail, so
	# what is being asserted is that the gate removed something that was there.
	var long: float = Timbre.SNARE_DECAY_SECONDS
	var snare: PackedFloat32Array = Timbre.note(Timbre.Voice.SNARE, 0, long)
	var gate: int = Timbre.frames(Timbre.SNARE_GATE_SECONDS)
	var before: float = _loudness(snare, gate - 400, gate - 50)
	var after: float = _loudness(snare, gate + 200, gate + 600)
	assert_gt(before, 0.05, "there was nothing for the gate to cut")
	assert_lt(after, before * 0.05, "the snare was left to decay instead of gated")


func test_the_hat_is_brighter_than_the_snare() -> void:
	# The differentiator in [method Timbre._hat] takes the body out of the noise.
	# Without it a hat is a short snare, and sixteen of them a bar is a wash.
	var hat: PackedFloat32Array = Timbre.note(Timbre.Voice.HAT, 0, Timbre.HAT_SECONDS)
	var snare: PackedFloat32Array = Timbre.note(Timbre.Voice.SNARE, 0, Timbre.HAT_SECONDS)
	var low: float = 300.0
	var high: float = 7000.0
	assert_gt(
		_goertzel(hat, high) / maxf(_goertzel(hat, low), 0.00001),
		_goertzel(snare, high) / maxf(_goertzel(snare, low), 0.00001),
		"the hat has as much body in it as the snare"
	)


# ---- determinism -------------------------------------------------------------


func test_the_same_note_is_the_same_samples_twice() -> void:
	# The whole reason [method Timbre._noise] is a spelled-out xorshift rather
	# than [RandomNumberGenerator]: a drum kit that differed between runs could
	# not be reviewed by listening to it once, and no assertion above about the
	# snare or the hat would mean anything.
	for voice: Timbre.Voice in Timbre.Voice.values():
		assert_eq(
			Timbre.note(voice, A4, NOTE_SECONDS),
			Timbre.note(voice, A4, NOTE_SECONDS),
			"voice %d is not the same sound twice" % voice
		)


func test_the_snare_and_the_hat_are_not_the_same_rattle() -> void:
	# Two seeds, so the two noise voices do not phase against each other on the
	# steps where they land together — which they do on every backbeat.
	var snare: PackedFloat32Array = Timbre.note(Timbre.Voice.SNARE, 0, 0.04)
	var hat: PackedFloat32Array = Timbre.note(Timbre.Voice.HAT, 0, 0.04)
	assert_ne(snare, hat, "the kit is one noise wearing two envelopes")
