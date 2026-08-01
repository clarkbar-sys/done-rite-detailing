## The ding: a struck bell, built out of arithmetic rather than shipped as a
## file.
##
## Two of them, and they are the same synthesis at different sizes — the counter
## bell you slap when Start is pressed, and the small one that rings when a patch
## of the car comes clean. What rings them is [Chime]; where they are rung from
## is [code]src/screens/[/code]. This class only knows how to make a sound.
##
## [b]Why it is generated and not a .wav in the repo.[/b] The same argument the
## car is a CSG blockout for and the tools are primitives for: the decision is
## the numbers, and the numbers are readable here. A recorded ding would be a
## binary nobody can diff, an import sidecar, a licence to check, and a thing
## that has to be re-recorded to be re-tuned — against about sixty lines that
## re-tune by editing a frequency. It costs a fraction of a second of startup
## (see [constant MIX_RATE]) and it buys a bell whose pitch, length and brightness
## are all in the diff.
##
## [b]Additive, with inharmonic partials, because that is what metal does.[/b] A
## bell is not a note: it is a handful of partials at ratios that are not whole
## numbers, each decaying at its own rate, with the high ones gone almost at
## once. That last part is what makes it read as [i]struck[/i] rather than as a
## beep — a sine with an envelope on it is a test tone, and no amount of picking
## the right frequency fixes it. [constant RATIOS] is the shape and
## [constant E_FOLDS] is the decay; both are ordinary bell-synthesis numbers
## rather than a measurement of a particular hotel's bell.
##
## [b]It ends in silence rather than being cut off.[/b] Every partial decays to
## well under a percent of its peak by the end of the buffer, so the last sample
## is near zero and there is no click when playback stops — a sound that ends on
## a step is heard as a fault in the game, not as the end of a bell.
class_name Bell
extends RefCounted

## Which bell to ring.
enum Voice {
	## The counter bell: one clear ding, low and long, for Start.
	START,
	## The little bell: shorter and a fifth higher, for a patch coming clean.
	## Short on purpose — these come in threes and fours while the water is
	## running, and a long one would smear them into a drone.
	PATCH,
}

## Samples a second. 22050 rather than 44100 because the highest partial of the
## higher voice lands at about 8.5 kHz, comfortably under this rate's 11 kHz
## ceiling, and because every sample is a trip round a GDScript loop: halving the
## rate halves the startup cost of building both voices, on a phone in a browser
## where that cost is paid in a hitch rather than in a benchmark.
const MIX_RATE: int = 22050

## The partials of a struck bell, as multiples of its fundamental. Not whole
## numbers on purpose — see the class docs.
const RATIOS: PackedFloat32Array = [1.0, 2.76, 5.4]

## How loud each partial starts, against the fundamental's 1.0. Falling, because
## a bell whose overtones are as loud as its body reads as a cymbal.
const WEIGHTS: PackedFloat32Array = [1.0, 0.55, 0.28]

## How many times the fundamental's amplitude halves-and-halves-again over the
## length of the sound: [code]e^-5[/code] is under a percent left at the end,
## which is the "ends in silence" promise in the class docs. Every partial above
## the fundamental decays this much faster again per multiple of its ratio, so
## the top of the bell is gone in the first fraction of a second and what rings
## on is the body.
const E_FOLDS: float = 5.0

## How long the strike takes to reach full volume, in seconds. Not zero: a
## waveform that starts at full amplitude starts with a step, and a step is a
## click. Three milliseconds is short enough to still be a strike.
const ATTACK_SECONDS: float = 0.003

## The fundamental of the counter bell, in hertz. C6 — high enough to cut
## through a phone speaker, which has nothing at all below a few hundred hertz.
const START_HZ: float = 1046.5

## How long the counter bell rings for, in seconds.
const START_SECONDS: float = 1.1

## What the counter bell peaks at, as a fraction of full scale. Under 1.0 so a
## bell that lands on the same frame as anything else has somewhere to go.
const START_LEVEL: float = 0.75

## The fundamental of the patch bell — a fifth above the counter bell, so a game
## in progress is recognisably the same instrument as the one that started it.
const PATCH_HZ: float = 1568.0

## How long the patch bell rings for. A third of the counter bell: these arrive
## in bursts, and the point is to be able to count them.
const PATCH_SECONDS: float = 0.36

## What the patch bell peaks at. Quieter than the counter bell because it is
## heard far more often, and because several can overlap — [Chime] plays them on
## a pool of players rather than cutting each one off.
const PATCH_LEVEL: float = 0.5

## Full scale for the 16-bit samples this writes.
const FULL_SCALE: float = 32767.0


## The stream for [param which] bell, ready to hand to an [AudioStreamPlayer].
##
## Built fresh on every call rather than cached in a `static var`: a shared
## [AudioStreamWAV] is a mutable global, and the caller that wants one kept is
## [Chime], which keeps it for the life of the game and knows it.
static func voice(which: Voice) -> AudioStreamWAV:
	if which == Voice.PATCH:
		return strike(PATCH_HZ, PATCH_SECONDS, PATCH_LEVEL)
	return strike(START_HZ, START_SECONDS, START_LEVEL)


## A bell of [param hz], ringing for [param seconds], peaking at [param level] of
## full scale.
##
## Mono, 16-bit, [constant MIX_RATE], no loop. Normalised by its own measured
## peak rather than by a level worked out on paper — the partials are summed, so
## how loud the sum gets depends on how their phases land, and guessing at that
## is how a sound ships either inaudible or clipped.
static func strike(hz: float, seconds: float, level: float) -> AudioStreamWAV:
	var frames: int = maxi(int(seconds * float(MIX_RATE)), 1)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(frames)
	var peak: float = 0.0
	for frame: int in frames:
		var at: float = float(frame) / float(MIX_RATE)
		var value: float = _partials(hz, seconds, at) * minf(at / ATTACK_SECONDS, 1.0)
		samples[frame] = value
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
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = data
	return stream


## Every partial of a bell of [param hz] lasting [param seconds], summed at
## [param at] seconds in, before the attack ramp and before normalising.
static func _partials(hz: float, seconds: float, at: float) -> float:
	var value: float = 0.0
	for partial: int in RATIOS.size():
		var ratio: float = RATIOS[partial]
		# The fundamental gets the whole buffer to fade over and everything above
		# it fades that much faster — the class docs have why.
		var life: float = seconds / (E_FOLDS * ratio)
		value += WEIGHTS[partial] * exp(-at / life) * sin(TAU * hz * ratio * at)
	return value


## One sample as the signed 16-bit integer the stream stores, clamped rather than
## wrapped: an overflow here would be heard as a crack, and the whole point of
## normalising above is that this never has to do anything.
static func _to_pcm(value: float) -> int:
	return clampi(roundi(value * FULL_SCALE), -32768, 32767)
