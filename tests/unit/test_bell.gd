## Unit tests for [Bell] — the ding, built out of arithmetic.
##
## Under tests/unit/ despite producing an [AudioStreamWAV]: a stream is a
## [Resource], nothing here needs a scene tree, a frame or an audio device, and
## the whole reason the sound is generated rather than recorded is that it can be
## asserted on like any other number. Whether it can be [i]heard[/i] is
## [code]tests/integration/test_chime.gd[/code]'s half of the job.
extends GutTest

## A tenth of a percent of full scale, for numbers that are all fractions of one.
const TOLERANCE: float = 0.001

## What a sample is worth as a fraction of full scale, so the assertions below
## read in the same units [Bell] normalises in.
const PER_UNIT: float = 1.0 / 32767.0


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
## needs no Fourier transform: a higher bell crosses more often.
func _crossings(from: PackedFloat32Array) -> int:
	var count: int = 0
	for frame: int in range(1, from.size()):
		if signf(from[frame]) != signf(from[frame - 1]):
			count += 1
	return count


# ---- the shape of the stream -------------------------------------------------


func test_a_voice_is_a_mono_16_bit_stream_at_the_projects_rate() -> void:
	# What an [AudioStreamPlayer] is handed. Stereo would double the buffer for
	# two identical channels, and a loop would leave a bell ringing forever.
	var stream: AudioStreamWAV = Bell.voice(Bell.Voice.START)
	assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_eq(stream.mix_rate, Bell.MIX_RATE)
	assert_false(stream.stereo, "a bell is one channel")
	assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_DISABLED, "a bell rings once")


func test_a_voice_is_as_long_as_it_says_it_is() -> void:
	# Two bytes a frame at [constant Bell.MIX_RATE], so the byte count is the
	# length — a stream half as long as intended is a ding that got cut off.
	var stream: AudioStreamWAV = Bell.voice(Bell.Voice.START)
	assert_almost_eq(stream.get_length(), Bell.START_SECONDS, 0.01)
	assert_eq(stream.data.size(), int(Bell.START_SECONDS * float(Bell.MIX_RATE)) * 2)


func test_the_same_voice_is_the_same_sound_twice() -> void:
	# Nothing random in here. A bell that came out differently each press would be
	# a bug nobody could reproduce, and it is what a "little variation" would cost
	# if it were ever added carelessly.
	assert_eq(Bell.voice(Bell.Voice.PATCH).data, Bell.voice(Bell.Voice.PATCH).data)


# ---- does it sound like a struck bell ----------------------------------------


func test_it_starts_from_silence_rather_than_from_a_step() -> void:
	# The attack ramp. A waveform that begins at full amplitude begins with a
	# click, which is heard as a fault rather than as a strike.
	var samples: PackedFloat32Array = _samples(Bell.voice(Bell.Voice.START))
	assert_almost_eq(samples[0], 0.0, TOLERANCE, "the bell starts with a step in it")


func test_it_is_loudest_at_the_strike() -> void:
	# A bell is struck and then decays: the peak belongs in the first tenth of the
	# sound, not in the middle of it.
	var samples: PackedFloat32Array = _samples(Bell.voice(Bell.Voice.START))
	var tenth: int = samples.size() / 10
	assert_almost_eq(
		_peak(samples.slice(0, tenth)),
		_peak(samples),
		TOLERANCE,
		"the loudest part of the bell is not the strike"
	)


func test_it_decays_all_the_way_to_silence() -> void:
	# The two halves of "ends in silence": quieter as it goes, and near enough to
	# nothing at the end that stopping playback makes no click.
	var samples: PackedFloat32Array = _samples(Bell.voice(Bell.Voice.START))
	var quarter: int = samples.size() / 4
	var early: float = _loudness(samples, 0, quarter)
	var late: float = _loudness(samples, quarter * 3, samples.size())
	assert_lt(late, early * 0.25, "the bell is not decaying")
	assert_lt(absf(samples[samples.size() - 1]), 0.01, "the bell is cut off rather than faded")


func test_it_is_normalised_to_its_own_level_without_clipping() -> void:
	# Normalising is what stops a sum of partials from shipping either inaudible
	# or clipped — see [method Bell.strike]. Asserted on both voices because they
	# carry deliberately different levels.
	assert_almost_eq(
		_peak(_samples(Bell.voice(Bell.Voice.START))), Bell.START_LEVEL, 0.01, "the counter bell"
	)
	assert_almost_eq(
		_peak(_samples(Bell.voice(Bell.Voice.PATCH))), Bell.PATCH_LEVEL, 0.01, "the patch bell"
	)


# ---- the two voices are actually two -----------------------------------------


func test_the_patch_bell_is_shorter_and_quieter_than_the_counter_bell() -> void:
	# The whole reason there are two: the patch bell arrives in bursts while the
	# water is running, and one as long and as loud as Start's would be a drone.
	var start: AudioStreamWAV = Bell.voice(Bell.Voice.START)
	var patch: AudioStreamWAV = Bell.voice(Bell.Voice.PATCH)
	assert_lt(patch.get_length(), start.get_length())
	assert_lt(_peak(_samples(patch)), _peak(_samples(start)))


func test_the_patch_bell_is_the_higher_of_the_two() -> void:
	# Pitch, measured as zero crossings a second so the test needs no maths the
	# reader has to take on trust. A fifth up is about a 1.5x difference; anything
	# near 1.0 would mean both voices came out of the same numbers.
	var start: PackedFloat32Array = _samples(Bell.voice(Bell.Voice.START))
	var patch: PackedFloat32Array = _samples(Bell.voice(Bell.Voice.PATCH))
	var start_rate: float = float(_crossings(start)) / Bell.START_SECONDS
	var patch_rate: float = float(_crossings(patch)) / Bell.PATCH_SECONDS
	assert_gt(patch_rate, start_rate * 1.2, "the two bells are the same pitch")


func test_a_bell_can_be_struck_at_any_pitch_and_length() -> void:
	# The knob under both voices. A tuning change is a number here rather than a
	# re-recording, which is the entire argument for generating the sound.
	var quiet: AudioStreamWAV = Bell.strike(440.0, 0.2, 0.3)
	assert_almost_eq(quiet.get_length(), 0.2, 0.01)
	assert_almost_eq(_peak(_samples(quiet)), 0.3, 0.01)
