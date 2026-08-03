## Unit tests for [ToolNoise] — the four looping sounds a running tool makes.
##
## Under tests/unit/ for [code]tests/unit/test_bell.gd[/code]'s reason: a stream
## is a [Resource], nothing here needs a scene tree, a frame or an audio device,
## and the whole argument for generating a sound rather than recording one is that
## it can be asserted on like any other number. Whether it can be [i]heard[/i], and
## whether holding a trigger starts it once rather than sixty times a second, is
## [code]tests/integration/test_tool_racket.gd[/code]'s half of the job.
##
## [b]What is asserted and what is not.[/b] That each voice loops, that it loops
## without a click, that it is normalised, that it is the same sound on every run,
## and that the four are actually four rather than one filtered four ways — all of
## which are facts about the buffer. Whether a pressure washer sounds like a
## pressure washer is not a thing a test can hold and the file does not pretend
## otherwise; what it holds instead is the measurable half of that claim, which is
## that the wash has weight the spray does not and the spray has brightness the
## wash does not.
extends GutTest

## What a sample is worth as a fraction of full scale, so the assertions below
## read in the same units [ToolNoise] normalises in.
const PER_UNIT: float = 1.0 / 32767.0

## Every voice, for the tests that hold of all four at once. [ToolNoise]'s own
## list rather than a copy of it: a voice added there and forgotten here would
## leave the new sound untested by every loop below, which is the one thing a
## second list is always eventually wrong about.
const EVERY_VOICE: Array[ToolNoise.Voice] = ToolNoise.EVERY_VOICE


## The samples of [param stream], as [code]-1..1[/code].
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


## The average loudness of [param from], which is the "how much sound is there"
## a peak cannot answer for noise.
func _loudness(from: PackedFloat32Array) -> float:
	var total: float = 0.0
	for value: float in from:
		total += absf(value)
	return 0.0 if from.is_empty() else total / float(from.size())


## How many times [param from] crosses zero a second, which is a brightness
## measurement that needs no Fourier transform: a hiss with the bottom taken off
## it crosses far more often than one with the bottom left in.
func _crossings(from: PackedFloat32Array) -> float:
	var count: int = 0
	for frame: int in range(1, from.size()):
		if signf(from[frame]) != signf(from[frame - 1]):
			count += 1
	return float(count) * float(ToolNoise.MIX_RATE) / float(from.size())


## The average step between one sample and the next inside [param from].
##
## The yardstick every loop-seam assertion below is measured against: a waveform
## already moving this much per sample cannot be said to have clicked at the wrap
## unless the step across the wrap is far bigger than the steps everywhere else.
func _step(from: PackedFloat32Array) -> float:
	var total: float = 0.0
	for frame: int in range(1, from.size()):
		total += absf(from[frame] - from[frame - 1])
	return 0.0 if from.size() < 2 else total / float(from.size() - 1)


## The step across the loop point of [param from]: the last frame that plays
## into the first one, which is where a badly built loop clicks.
func _wrap_step(from: PackedFloat32Array, stream: AudioStreamWAV) -> float:
	return absf(from[0] - from[stream.loop_end - 1])


## The quietest and the loudest tenth of [param from], as a pair — how a voice
## that pulses is told from one that runs flat.
func _quietest_tenth(from: PackedFloat32Array) -> float:
	var window: int = from.size() / 10
	var quietest: float = 1.0
	for tenth: int in 10:
		quietest = minf(quietest, _loudness(from.slice(tenth * window, (tenth + 1) * window)))
	return quietest


func _loudest_tenth(from: PackedFloat32Array) -> float:
	var window: int = from.size() / 10
	var loudest: float = 0.0
	for tenth: int in 10:
		loudest = maxf(loudest, _loudness(from.slice(tenth * window, (tenth + 1) * window)))
	return loudest


# ---- the shape of the stream -------------------------------------------------


func test_every_voice_is_a_mono_16_bit_stream_at_the_projects_rate() -> void:
	# What an [AudioStreamPlayer] is handed. Stereo would double every buffer for
	# two identical channels, at a startup cost paid on a phone.
	for which: ToolNoise.Voice in EVERY_VOICE:
		var stream: AudioStreamWAV = ToolNoise.voice(which)
		assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS, "voice %d" % which)
		assert_eq(stream.mix_rate, ToolNoise.MIX_RATE, "voice %d" % which)
		assert_false(stream.stereo, "voice %d is not one channel" % which)


func test_every_voice_loops_over_the_whole_buffer() -> void:
	# The difference between this class and [Bell], and the reason it exists: a
	# tool runs for as long as the trigger is held. A voice that came back with
	# looping disabled would play once and leave the rest of the press silent.
	for which: ToolNoise.Voice in EVERY_VOICE:
		var stream: AudioStreamWAV = ToolNoise.voice(which)
		assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "voice %d does not loop" % which)
		assert_eq(stream.loop_begin, 0, "voice %d starts its loop late" % which)
		assert_eq(stream.loop_end, stream.data.size() / 2 - 1, "voice %d loops short" % which)


func test_every_voice_is_the_same_sound_twice() -> void:
	# Nothing random at play time. The noise is seeded per voice, so a build makes
	# the same sound every run — a hiss that came out differently each boot is a
	# bug report nobody can reproduce.
	for which: ToolNoise.Voice in EVERY_VOICE:
		assert_eq(ToolNoise.voice(which).data, ToolNoise.voice(which).data, "voice %d" % which)


func test_every_voice_is_normalised_without_clipping() -> void:
	# Normalising is what stops a sum of noise and tones from shipping either
	# inaudible or clipped, and the four levels are deliberately different — see
	# [constant ToolNoise.WASH_LEVEL].
	var levels: Array[float] = [
		ToolNoise.WASH_LEVEL, ToolNoise.SPRAY_LEVEL, ToolNoise.RAG_LEVEL, ToolNoise.SQUISH_LEVEL
	]
	for index: int in EVERY_VOICE.size():
		var peak: float = _peak(_samples(ToolNoise.voice(EVERY_VOICE[index])))
		assert_almost_eq(peak, levels[index], 0.01, "voice %d" % EVERY_VOICE[index])


func test_every_voice_is_quieter_than_the_bell() -> void:
	# A tool runs for as long as a trigger is held and a bell rings for a third of
	# a second. Whichever way the two are retuned, the thing that plays constantly
	# should not be the loudest thing in the game.
	for which: ToolNoise.Voice in EVERY_VOICE:
		var peak: float = _peak(_samples(ToolNoise.voice(which)))
		assert_lt(peak, Bell.START_LEVEL, "voice %d is louder than the counter bell" % which)


# ---- does it loop without a click --------------------------------------------


func test_no_voice_clicks_at_the_loop_point() -> void:
	# The one fault a generated loop is most recognisable for, and the reason
	# [method ToolNoise._wrapped_noise] and [method ToolNoise._cycled] exist. The
	# test is a comparison rather than an absolute: band-limited noise moves a long
	# way between samples by nature, so what would be audible is not a step but a
	# step much larger than the ones on either side of it.
	for which: ToolNoise.Voice in EVERY_VOICE:
		var stream: AudioStreamWAV = ToolNoise.voice(which)
		var samples: PackedFloat32Array = _samples(stream)
		var wrap: float = _wrap_step(samples, stream)
		assert_lt(
			wrap,
			_step(samples) * 4.0,
			(
				"voice %d steps %.4f across its loop against %.4f inside it"
				% [which, wrap, _step(samples)]
			)
		)


func test_no_voice_fades_out_at_its_own_end() -> void:
	# The lazy way to make a loop seamless is to fade both ends to silence, which
	# loops perfectly and pulses once per buffer for as long as the trigger is
	# held. The two ends should be as alive as the middle.
	for which: ToolNoise.Voice in EVERY_VOICE:
		var samples: PackedFloat32Array = _samples(ToolNoise.voice(which))
		var window: int = samples.size() / 20
		var ends: float = (
			_loudness(samples.slice(0, window))
			+ _loudness(samples.slice(samples.size() - window, samples.size()))
		)
		assert_gt(ends, 0.0, "voice %d is silent at the loop point" % which)


# ---- the four are actually four ----------------------------------------------


func test_the_four_voices_are_four_different_sounds() -> void:
	# Four seeds and four recipes. Two voices coming back with the same buffer
	# would mean a tool swap that changed nothing audible.
	for which: ToolNoise.Voice in EVERY_VOICE:
		for other: ToolNoise.Voice in EVERY_VOICE:
			if which == other:
				continue
			assert_ne(
				ToolNoise.voice(which).data,
				ToolNoise.voice(other).data,
				"voices %d and %d are the same sound" % [which, other]
			)


func test_the_bottles_hiss_brighter_than_the_wash() -> void:
	# The band is the whole difference between "bottle" and "hose" — see the class
	# docs. Measured as zero crossings a second, so the assertion needs no maths
	# the reader has to take on trust.
	var spray: float = _crossings(_samples(ToolNoise.voice(ToolNoise.Voice.SPRAY)))
	var wash: float = _crossings(_samples(ToolNoise.voice(ToolNoise.Voice.WASH)))
	assert_gt(spray, wash * 1.5, "the spray is not the brighter of the two")


func test_the_sponge_is_the_dullest_hiss_on_the_belt() -> void:
	# A sponge touches the paint with its whole face and the sound is meant to say
	# so — [constant ToolNoise.SQUISH_STAGES] is what it cost to mean it, and this
	# is the measurement that caught the version that did not.
	#
	# [b]Against the two continuous voices and not against the rag[/b], which is
	# silent for more than half of every cycle it runs: a crossing rate counted over
	# a gated voice is diluted by the gaps, so it measures the rhythm as much as the
	# brightness and comparing the two would be comparing different questions.
	var squish: float = _crossings(_samples(ToolNoise.voice(ToolNoise.Voice.SQUISH)))
	for which: ToolNoise.Voice in [ToolNoise.Voice.WASH, ToolNoise.Voice.SPRAY]:
		assert_lt(
			squish,
			_crossings(_samples(ToolNoise.voice(which))) * 0.5,
			"the sponge is not the darker of it and voice %d" % which
		)


func test_the_rag_squeaks_rather_than_runs() -> void:
	# One squeak per pass of the hand, with a gap between them — as against the
	# wash, which is a continuous thing. So the rag's quietest tenth should be far
	# below its loudest, and the wash's should not be.
	var rag: PackedFloat32Array = _samples(ToolNoise.voice(ToolNoise.Voice.RAG))
	assert_lt(_quietest_tenth(rag), _loudest_tenth(rag) * 0.25, "the squeak does not let up")
	var wash: PackedFloat32Array = _samples(ToolNoise.voice(ToolNoise.Voice.WASH))
	assert_gt(_quietest_tenth(wash), _loudest_tenth(wash) * 0.5, "the water is not continuous")


func test_the_sponge_pulses_without_going_silent() -> void:
	# Both halves of [constant ToolNoise.SQUISH_FLOOR]: a squeeze the player can
	# hear as a squeeze, and a tool that does not switch itself off twice a second
	# while it is still against the paint.
	#
	# The floor is a fraction of the wet noise and the number below is a fraction of
	# the whole voice, which is why they are not the same number: the body tone is
	# gated all the way to silence between squeezes and the noise is not, so the
	# quiet part of a cycle is the noise on its own and lands well under the third
	# [constant ToolNoise.SQUISH_FLOOR] leaves of it.
	var squish: PackedFloat32Array = _samples(ToolNoise.voice(ToolNoise.Voice.SQUISH))
	assert_lt(_quietest_tenth(squish), _loudest_tenth(squish) * 0.8, "the sponge does not pulse")
	assert_gt(_quietest_tenth(squish), _loudest_tenth(squish) * 0.05, "the sponge drops out")


# ---- which tool makes which noise --------------------------------------------


func test_every_tool_on_the_belt_makes_a_noise() -> void:
	# The mapping is total: a belt that grew a tool with no voice would be a silent
	# trigger, which reads as broken audio rather than as a design decision.
	for tool: DetailingTool in DetailingTool.catalogue():
		assert_true(
			ToolNoise.voice(ToolNoise.voice_for(tool.id)).data.size() > 0,
			"%s makes no noise at all" % tool.display_name
		)


func test_the_two_bottles_share_one_hiss() -> void:
	# A window cleaner and a tyre cleaner are the same trigger spray with different
	# liquid in them — see the class docs. This is the one place that decision is
	# written down, so it is the one place it is asserted.
	assert_eq(
		ToolNoise.voice_for(DetailingTool.Id.WINDOW_CLEANER),
		ToolNoise.voice_for(DetailingTool.Id.TIRE_ENGINE_CLEANER),
		"the two bottles should hiss alike"
	)


func test_the_other_three_tools_each_get_their_own() -> void:
	# The wash, the rag and the sponge are three distinct jobs and three distinct
	# noises; only the bottles double up.
	assert_eq(ToolNoise.voice_for(DetailingTool.Id.POWER_WASH), ToolNoise.Voice.WASH)
	assert_eq(ToolNoise.voice_for(DetailingTool.Id.DRYING_RAG), ToolNoise.Voice.RAG)
	assert_eq(ToolNoise.voice_for(DetailingTool.Id.SPONGE), ToolNoise.Voice.SQUISH)
