## The noise a tool makes while it is running: four looping sounds, built out of
## arithmetic rather than shipped as files.
##
## The same argument [Bell] makes, applied to the other half of the game's audio.
## A bell is an event — something finished, ding — and these are the opposite: a
## thing that is true for as long as the trigger is held, and stops being true
## when it is let go. So every voice here is a seamless loop rather than a strike,
## and what plays them is [ToolRacket].
##
## [b]Four voices for five tools[/b], because the two bottles are one sound. A
## window cleaner and a tyre cleaner are the same trigger spray with different
## liquid in them, and inventing a second hiss to tell them apart would be
## claiming a difference the player's ear cannot hear and the game does not mean.
## [method voice_for] is that mapping and it is the only place it exists.
##
## [b]What each one is made of, and why it is that rather than a recording.[/b]
##
## - [b]The wash[/b] is a broad band of water noise with a motor under it. The
##   hiss alone reads as a tap running; what says [i]pressure washer[/i] is the
##   pump — a buzzy low tone at [constant WASH_MOTOR_HZ] with its first harmonics
##   over it — and the slow surge of the water on top of that.
## - [b]The spray[/b] is the same noise generator with the bottom taken off it.
##   An aerosol is a hiss with almost nothing below a couple of kilohertz, and
##   that band is the entire difference between "bottle" and "hose".
## - [b]The rag[/b] is the only pitched voice: a squeak is a tone that rises as it
##   goes ([constant RAG_RISE]), gated into one squeak per pass of the hand
##   ([constant RAG_SQUEAKS_PER_SECOND]) with a little dry rub in the gaps. A flat
##   tone gated the same way is a phone ringing, and the rise is what makes it a
##   cloth on glass.
## - [b]The squish[/b] is a wet, dull band of noise pumped by the squeeze, with a
##   low body tone under it that bends up as the sponge is pressed. It is
##   deliberately the darkest of the four: the sponge is the one tool that touches
##   the paint with its whole face.
##
## [b]Why generated, again, and the part that is new.[/b] Everything [Bell] says
## about a diff-able sound holds here and more so — a loop is four numbers about
## pitch and rhythm, and retuning "the squeak is too fast" is
## [constant RAG_SQUEAKS_PER_SECOND] rather than a session with a microphone. What
## a recording would additionally have cost is the loop itself: a looping .wav has
## to be cut at a zero crossing by hand and it clicks for ever after if it was cut
## a sample out. Here the loop point is a property of how the sound is built —
## see [method _wrapped_noise] and [constant WRAP_SECONDS] — and
## [code]tests/unit/test_tool_noise.gd[/code] measures the seam rather than
## trusting it.
##
## [b]What it costs.[/b] All four voices together are 78 ms of arithmetic on a
## desktop, measured — about three and a half seconds of audio at
## [constant MIX_RATE], generated and then filtered twice ([method _band] says
## why twice). It is paid once, in [method ToolRacket._ready], on the screen
## that can hear them; the title screen builds none of it. That is the number to
## re-measure before making any of the loops below longer, because it is the one
## a phone multiplies.
##
## [b]Nothing here is random at play time.[/b] The noise comes from a
## [RandomNumberGenerator] seeded per voice, so the same build makes the same
## sound every run — a hiss that came out differently each boot would be a bug
## report nobody could reproduce. Variation, if it is ever wanted, is a second
## seeded buffer picked between, not a call to [method @GlobalScope.randf] in the
## middle of a loop.
class_name ToolNoise
extends RefCounted

## Which noise. Named for what it sounds like rather than for the tool that makes
## it, because [constant Voice.SPRAY] is two tools — see the class docs.
enum Voice {
	## The power wash: water and a pump.
	WASH,
	## Either bottle: a trigger spray.
	SPRAY,
	## The drying rag: a squeak per pass of the hand.
	RAG,
	## The sponge: a wet squeeze.
	SQUISH,
}

## Every voice there is, in the order above.
##
## A list rather than each caller writing its own, for [enum DetailingTool.Id]'s
## reason: [ToolRacket] builds a player per voice and its test asserts on every
## voice, and two hand-written lists is the bug where a fifth voice is added and
## silently never played. Iterating an [code]enum[/code] is not a thing GDScript
## does, so the list is the enum written down once.
const EVERY_VOICE: Array[Voice] = [Voice.WASH, Voice.SPRAY, Voice.RAG, Voice.SQUISH]

## Samples a second, and [constant Bell.MIX_RATE]'s reasoning applies unchanged:
## every sample is a trip round a GDScript loop, and this is a phone in a browser.
## The one thing it costs here is the top of the spray — an aerosol has real
## energy above this rate's 11 kHz ceiling — which is a hiss slightly duller than
## life against a startup cost twice as large. See [constant SPRAY_HIGH_HZ].
const MIX_RATE: int = 22050

## Full scale for the 16-bit samples this writes.
const FULL_SCALE: float = 32767.0

## How long the crossfade that makes a noise buffer wrap is, in seconds. Long
## enough that the two ends are blended rather than butted together, short enough
## that the blended part is a small fraction of the loop — see
## [method _wrapped_noise], which is the only thing that reads it.
const WRAP_SECONDS: float = 0.04

## How long each loop is, in seconds.
##
## Short, because the whole buffer is built at startup and a loop is heard on
## repeat by definition; long enough that the repeat is not a rhythm of its own.
## The wash and the spray are near-featureless noise and get away with the least;
## the two that pulse are as long as a whole number of their own pulses, which is
## what [method _cycled] enforces rather than these numbers promising it.
const WASH_SECONDS: float = 0.8
const SPRAY_SECONDS: float = 0.7
const RAG_SECONDS: float = 1.25
const SQUISH_SECONDS: float = 0.9

## What each voice peaks at, as a fraction of full scale.
##
## Peak and not loudness, the same way [Bell] normalises, which is why these are
## not all the same number: a band of noise peaks well above its average and a
## tone peaks barely above its own, so matching them by peak is what makes them
## sound roughly matched. All four are well under the bell's, because a tool runs
## for as long as the trigger is held and a bell rings for a third of a second.
const WASH_LEVEL: float = 0.55
const SPRAY_LEVEL: float = 0.42
const RAG_LEVEL: float = 0.34
const SQUISH_LEVEL: float = 0.4

## The seed each voice's noise is drawn from. Four different ones so no two
## voices share a hiss — the wash and the spray are the same generator with
## different bands taken out of it, and identical noise underneath would make
## swapping between them sound like a filter sweep rather than like two tools.
const WASH_SEED: int = 5_101
const SPRAY_SEED: int = 5_197
const RAG_SEED: int = 5_231
const SQUISH_SEED: int = 5_309

## The band of water noise the wash is built on, in hertz. Wide, and low enough at
## the bottom to have some weight: a jet is heard in the chest as well as the ear,
## and a hiss that starts at two kilohertz is a hairdryer.
const WASH_LOW_HZ: float = 380.0
const WASH_HIGH_HZ: float = 6_000.0

## The pump, in hertz, and how loud it is against the water. Low and buzzy — this
## is the part that says a motor is driving the water rather than a tap being
## open.
const WASH_MOTOR_HZ: float = 54.0
const WASH_MOTOR_LEVEL: float = 0.5

## The harmonics of the pump, as weights on the fundamental and its multiples. A
## falling series rather than a single sine, because a motor is a rough thing:
## one sine at 54 Hz is a test tone most phone speakers cannot even reproduce,
## and its harmonics are what carries it on a speaker with nothing below a few
## hundred hertz.
const MOTOR_WEIGHTS: PackedFloat32Array = [1.0, 0.6, 0.35, 0.2]

## How fast the water surges, in hertz, and how much of the hiss that swallows.
## Slight on purpose: the jet is steady and this is the pump's pressure showing
## through it, not a pulse.
const WASH_SURGE_HZ: float = 6.5
const WASH_SURGE_DEPTH: float = 0.18

## The band the bottles hiss in. The bottom of it is the whole voice — see the
## class docs — and the top is at the rate's ceiling because a spray has nothing
## up there to cut.
const SPRAY_LOW_HZ: float = 1_900.0
const SPRAY_HIGH_HZ: float = 9_500.0

## How much the bottle's hiss flutters, and how fast. A trigger spray is not
## perfectly steady; this is small enough to be heard as texture rather than as a
## wobble.
const SPRAY_FLUTTER_HZ: float = 9.0
const SPRAY_FLUTTER_DEPTH: float = 0.12

## How many squeaks a second the rag makes — one per pass of the hand, so this is
## really "how fast is somebody buffing". Two and a bit a second is a brisk
## circular polish; much faster reads as a bird.
const RAG_SQUEAKS_PER_SECOND: float = 2.4

## How much of each squeak's cycle is the squeak, as a fraction. The rest is the
## hand travelling back, which is quiet — and which is also what makes the loop
## seamless, because the buffer both begins and ends in that gap.
const RAG_DUTY: float = 0.42

## Where a squeak starts, in hertz, and how far it climbs by the end of itself.
## The climb is the entire difference between a squeak and a beep.
const RAG_HZ: float = 880.0
const RAG_RISE: float = 0.45

## How loud the squeak's second harmonic is. A squeak is a bad reed, not a flute:
## with no harmonic at all it is a sine, which reads as electronic.
const RAG_PARTIAL: float = 0.3

## The dry rub of cloth on paint, under the squeak: a quiet band of noise, gated
## by the same envelope so it arrives with the hand rather than running
## underneath everything.
const RAG_RUB_LOW_HZ: float = 1_600.0
const RAG_RUB_HIGH_HZ: float = 7_000.0
const RAG_RUB_LEVEL: float = 0.35

## How many squeezes a second the sponge makes. Slower than the rag's squeaks: a
## sponge is pushed and dragged, not flicked.
const SQUISH_PER_SECOND: float = 2.2

## The band the wet noise sits in. Dull by design — the top of it is below where
## the spray's even starts, which is what makes a sponge and a bottle two sounds
## rather than two levels.
const SQUISH_LOW_HZ: float = 110.0
const SQUISH_HIGH_HZ: float = 900.0

## How many low-pass stages the sponge's noise goes through, against one for
## every other voice.
##
## [b]Measured, after the obvious version failed a test that was right.[/b] One
## pole is six decibels an octave, which is the gentle shaping the other three
## voices want — and it leaves so much above the cutoff that a "dull" band at 900
## Hz still crossed zero more often than the rag's squeak did. That is not a
## quibble about a number in a test: a sponge that hisses is a sponge that sounds
## like a small aerosol, which is the one thing the belt already has two of.
## Three stages is eighteen decibels an octave, which is the difference between a
## band with the top rolled off and a sound with no top in it.
const SQUISH_STAGES: int = 3

## How much of the wet noise survives between squeezes, as a fraction. Not zero:
## the sponge is still against the paint on the way back, and a voice that
## switched fully off twice a second would be heard as a fault in the audio.
const SQUISH_FLOOR: float = 0.3

## The body of the squeeze: a low tone at [constant SQUISH_HZ] that bends up by
## [constant SQUISH_BEND] as the sponge is pressed, at [constant SQUISH_BODY]
## against the noise. This is the "hmm" in the squish — air being pushed out of
## something soft, which has a pitch, and which rises as the thing is squashed.
const SQUISH_HZ: float = 160.0
const SQUISH_BEND: float = 0.35
const SQUISH_BODY: float = 0.55


## Which noise [param id] makes.
##
## The two bottles share [constant Voice.SPRAY] — see the class docs. Anything
## unrecognised gets the wash, which is a tool that certainly exists rather than
## silence: a belt that grew a sixth tool would be audible-but-wrong here instead
## of silently mute, and the first is a bug somebody reports.
static func voice_for(id: DetailingTool.Id) -> Voice:
	if id == DetailingTool.Id.SPONGE:
		return Voice.SQUISH
	if id == DetailingTool.Id.DRYING_RAG:
		return Voice.RAG
	if id == DetailingTool.Id.WINDOW_CLEANER or id == DetailingTool.Id.TIRE_ENGINE_CLEANER:
		return Voice.SPRAY
	return Voice.WASH


## The stream for [param which] noise, ready to hand to an [AudioStreamPlayer]
## and already set to loop.
##
## Built fresh on every call rather than cached in a `static var`, for [method
## Bell.voice]'s reason: a shared [AudioStreamWAV] is a mutable global, and the
## caller that wants one kept is [ToolRacket], which keeps it for the life of the
## screen and knows it.
static func voice(which: Voice) -> AudioStreamWAV:
	if which == Voice.SPRAY:
		return _loop(_spray(), SPRAY_LEVEL)
	if which == Voice.RAG:
		return _loop(_rag(), RAG_LEVEL)
	if which == Voice.SQUISH:
		return _loop(_squish(), SQUISH_LEVEL)
	return _loop(_wash(), WASH_LEVEL)


## The power wash: a band of water noise, surging slightly, over a pump.
static func _wash() -> PackedFloat32Array:
	var frames: int = _frames(WASH_SECONDS)
	var water: PackedFloat32Array = _hiss(frames, WASH_SEED, WASH_LOW_HZ, WASH_HIGH_HZ)
	var motor_hz: float = _cycled(WASH_MOTOR_HZ, WASH_SECONDS)
	var surge_hz: float = _cycled(WASH_SURGE_HZ, WASH_SECONDS)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(frames)
	for frame: int in frames:
		var at: float = float(frame) / float(MIX_RATE)
		var surge: float = 1.0 - WASH_SURGE_DEPTH * _swell(at, surge_hz)
		out[frame] = water[frame] * surge + _motor(motor_hz, at) * WASH_MOTOR_LEVEL
	return out


## Either bottle: a bright hiss with a flutter on it.
static func _spray() -> PackedFloat32Array:
	var frames: int = _frames(SPRAY_SECONDS)
	var mist: PackedFloat32Array = _hiss(frames, SPRAY_SEED, SPRAY_LOW_HZ, SPRAY_HIGH_HZ)
	var flutter_hz: float = _cycled(SPRAY_FLUTTER_HZ, SPRAY_SECONDS)
	for frame: int in frames:
		var at: float = float(frame) / float(MIX_RATE)
		mist[frame] *= 1.0 - SPRAY_FLUTTER_DEPTH * _swell(at, flutter_hz)
	return mist


## The drying rag: one rising squeak per pass of the hand, with the rub of the
## cloth inside it.
##
## [b]The phase is integrated rather than computed[/b] — [code]sin(TAU * hz *
## at)[/code] is a tone at a fixed pitch, and a pitch that changes has to be
## accumulated a sample at a time or it comes out as a warble at the wrong speed.
## That leaves the phase at the end of the buffer at whatever it happens to be,
## which would click on the wrap if the envelope were not zero there — which is
## what [constant RAG_DUTY] guarantees, since the buffer holds a whole number of
## squeaks ([method _cycled]) and each one starts and ends silent.
static func _rag() -> PackedFloat32Array:
	var frames: int = _frames(RAG_SECONDS)
	var rub: PackedFloat32Array = _hiss(frames, RAG_SEED, RAG_RUB_LOW_HZ, RAG_RUB_HIGH_HZ)
	var squeaks: float = _cycled(RAG_SQUEAKS_PER_SECOND, RAG_SECONDS)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(frames)
	var phase: float = 0.0
	for frame: int in frames:
		var at: float = float(frame) / float(MIX_RATE)
		var through: float = fposmod(at * squeaks, 1.0)
		var open: float = _squeak(through)
		phase += TAU * (RAG_HZ * (1.0 + RAG_RISE * through)) / float(MIX_RATE)
		var reed: float = sin(phase) + RAG_PARTIAL * sin(phase * 2.0)
		out[frame] = open * (reed + rub[frame] * RAG_RUB_LEVEL)
	return out


## The sponge: wet noise pumped by the squeeze, with a bending body tone under it.
static func _squish() -> PackedFloat32Array:
	var frames: int = _frames(SQUISH_SECONDS)
	var wet: PackedFloat32Array = _hiss(
		frames, SQUISH_SEED, SQUISH_LOW_HZ, SQUISH_HIGH_HZ, SQUISH_STAGES
	)
	var presses: float = _cycled(SQUISH_PER_SECOND, SQUISH_SECONDS)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(frames)
	var phase: float = 0.0
	for frame: int in frames:
		var at: float = float(frame) / float(MIX_RATE)
		var press: float = _swell(at, presses)
		phase += TAU * (SQUISH_HZ * (1.0 + SQUISH_BEND * press)) / float(MIX_RATE)
		# The tone is gated all the way to silence at the ends of a squeeze and the
		# noise is not, which is the same split [method _rag] makes and for the same
		# two reasons: a bending tone has to be silent at the wrap to loop, and a
		# sponge that went completely quiet twice a second would read as a dropout.
		var body: float = SQUISH_BODY * sin(phase) * press * press
		out[frame] = wet[frame] * (SQUISH_FLOOR + (1.0 - SQUISH_FLOOR) * press) + body
	return out


## A band of noise between [param low_hz] and [param high_hz], [param frames]
## long, drawn from [param hiss_seed], and seamless end to end.
##
## [param stages] is how hard the top of the band is cut — see
## [constant SQUISH_STAGES], which is the only caller that asks for more than one.
static func _hiss(
	frames: int, hiss_seed: int, low_hz: float, high_hz: float, stages: int = 1
) -> PackedFloat32Array:
	return _band(_wrapped_noise(frames, hiss_seed), low_hz, high_hz, stages)


## [param frames] of white noise from [param hiss_seed] whose end runs into its
## own beginning.
##
## [b]The problem this solves.[/b] Two ends of an unrelated pair of samples butted
## together is a step, and a step is a click — once per loop, for ever, which is
## the single most recognisable fault a generated loop can have. So the generator
## is run for [constant WRAP_SECONDS] longer than the buffer and the extra tail is
## faded into the head: the last sample of the buffer is followed, at the wrap, by
## the sample that genuinely came after it.
##
## [b]Equal-power and not linear.[/b] The two ends are uncorrelated noise, so
## their sum is quieter than either — mixing them at a half each drops the middle
## of the fade to about seven tenths, which is heard as a dip once a loop rather
## than as a click. Square roots keep the power constant instead of the amplitude.
static func _wrapped_noise(frames: int, hiss_seed: int) -> PackedFloat32Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hiss_seed
	var fade: int = mini(_frames(WRAP_SECONDS), frames / 2)
	var raw: PackedFloat32Array = PackedFloat32Array()
	raw.resize(frames + fade)
	for frame: int in raw.size():
		raw[frame] = rng.randf_range(-1.0, 1.0)
	var out: PackedFloat32Array = raw.slice(0, frames)
	for frame: int in fade:
		var through: float = float(frame) / float(fade)
		out[frame] = raw[frame] * sqrt(through) + raw[frames + frame] * sqrt(1.0 - through)
	return out


## [param source], with everything below [param low_hz] and above [param high_hz]
## taken off it.
##
## One-pole filters and a subtraction: what is left after the low end is removed
## from the high end is the band between them. Six decibels an octave a side by
## default, which is the right kind of gentle for shaping noise into a voice —
## a steep filter is heard as a resonance rather than as a band. [param stages]
## cascades the top of that for a voice that needs the difference between "rolled
## off" and "not there", which is [constant SQUISH_STAGES] and only that.
##
## [b]It runs the whole buffer twice and keeps the second pass.[/b] A filter has
## state, and a filter started from silence spends its first few milliseconds
## climbing out of it — which would be a thump at the start of the buffer and,
## since the buffer loops, a thump every time round. Running it once as a warm-up
## leaves the state where it will be at the end of the loop, so the second pass
## begins where it ends and the seam [method _wrapped_noise] built into the noise
## survives being filtered.
static func _band(
	source: PackedFloat32Array, low_hz: float, high_hz: float, stages: int = 1
) -> PackedFloat32Array:
	var frames: int = source.size()
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(frames)
	var top: float = _pole(high_hz)
	var bottom: float = _pole(low_hz)
	var under_the_top: PackedFloat32Array = PackedFloat32Array()
	under_the_top.resize(maxi(stages, 1))
	var under_the_bottom: float = 0.0
	for lap: int in 2:
		for frame: int in frames:
			var value: float = source[frame]
			var carried: float = value
			for stage: int in under_the_top.size():
				under_the_top[stage] += (carried - under_the_top[stage]) * top
				carried = under_the_top[stage]
			under_the_bottom += (value - under_the_bottom) * bottom
			if lap == 1:
				out[frame] = carried - under_the_bottom
	return out


## The coefficient of a one-pole filter at [param hz], for this mix rate.
##
## Clamped at 1.0 because a cutoff at or above half the rate has nothing left to
## remove, and a coefficient over one is an oscillator rather than a filter.
static func _pole(hz: float) -> float:
	return minf(1.0 - exp(-TAU * hz / float(MIX_RATE)), 1.0)


## The pump at [param hz], [param at] seconds in: a fundamental and its first
## harmonics, weighted by [constant MOTOR_WEIGHTS].
static func _motor(hz: float, at: float) -> float:
	var value: float = 0.0
	for partial: int in MOTOR_WEIGHTS.size():
		value += MOTOR_WEIGHTS[partial] * sin(TAU * hz * float(partial + 1) * at)
	return value


## A [code]0..1[/code] rise and fall at [param hz], [param at] seconds in, sitting
## at zero at the start of every cycle.
##
## A raised cosine rather than a sine, because what every caller wants is a pulse
## that is [i]off[/i] at the loop point and full in the middle of itself — a sine
## crosses zero going both ways and would pump twice per cycle.
static func _swell(at: float, hz: float) -> float:
	return 0.5 - 0.5 * cos(TAU * hz * at)


## How open the rag's squeak is [param through] its own cycle, as [code]0..1[/code].
##
## Silent for the part of the cycle the hand is travelling back —
## [constant RAG_DUTY] is how much of it is the squeak itself — and a raised
## cosine over the rest, so the squeak swells and dies rather than being switched
## on. Both ends are exactly zero, which is what lets the pitch bend inside it
## without clicking at either edge.
static func _squeak(through: float) -> float:
	if through >= RAG_DUTY:
		return 0.0
	return 0.5 - 0.5 * cos(TAU * through / RAG_DUTY)


## [param hz], moved to the nearest rate that fits a whole number of cycles into
## [param seconds].
##
## [b]This is what makes the loops loop.[/b] Anything periodic in a buffer that
## does not divide into its length exactly is cut off mid-cycle at the wrap — a
## surge caught halfway, a squeak caught halfway through its rise — and that
## discontinuity is a click at best and a stutter in the rhythm at worst. Moving
## the frequency instead of the buffer length is the cheap direction: the pulse
## rates here are taste rather than measurement, and a squeak at 2.4 a second
## being played at 2.4 instead is a difference nobody can hear.
##
## Never below one cycle: a rate rounded down to zero would be a modulation that
## never moves, which is silently wrong rather than loudly wrong.
static func _cycled(hz: float, seconds: float) -> float:
	return maxf(roundf(hz * seconds), 1.0) / seconds


## How many frames [param seconds] is, at least one.
static func _frames(seconds: float) -> int:
	return maxi(int(seconds * float(MIX_RATE)), 1)


## [param samples] as a looping [AudioStreamWAV] peaking at [param level].
##
## Normalised by its own measured peak, for [method Bell.strike]'s reason: these
## are sums of noise and tones whose loudest moment depends on how their phases
## land, and guessing at that on paper is how a sound ships inaudible or clipped.
##
## [b]Looped forward across the whole buffer[/b], which is the one thing that
## makes this class different from [Bell]: a bell is played once and decays to
## silence, and a tool runs until the trigger is let go. The loop ends one frame
## short of the data — the last frame is the one the wrap runs [i]into[/i], not
## one to play — and starts at zero because the whole buffer is the sound.
static func _loop(samples: PackedFloat32Array, level: float) -> AudioStreamWAV:
	var frames: int = samples.size()
	var peak: float = 0.0
	for value: float in samples:
		peak = maxf(peak, absf(value))
	var scale: float = 0.0 if peak <= 0.0 else level / peak
	var data: PackedByteArray = PackedByteArray()
	data.resize(frames * 2)
	for frame: int in frames:
		data.encode_s16(frame * 2, _to_pcm(samples[frame] * scale))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = frames - 1
	return stream


## One sample as the signed 16-bit integer the stream stores, clamped rather than
## wrapped: an overflow here would be heard as a crack, and the whole point of
## normalising above is that this never has to do anything.
static func _to_pcm(value: float) -> int:
	return clampi(roundi(value * FULL_SCALE), -32768, 32767)
