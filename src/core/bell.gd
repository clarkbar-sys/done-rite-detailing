## The ding: a payout chime, built out of arithmetic rather than shipped as a
## file.
##
## Two voices, and they are the same synthesis at two sizes — the chime that
## rings when Start is pressed, and the small one that rings when a patch of the
## car comes clean. On a run of consecutive patches that second one climbs a C
## major arpeggio and pays out a chord at the top. What rings them is [Chime];
## where they are rung from is [code]src/screens/[/code]. This class only knows
## how to make a sound.
##
## [b]Why it is generated and not a .wav in the repo.[/b] The same argument the
## car is a CSG blockout for and the tools are primitives for: the decision is
## the numbers, and the numbers are readable here. A recorded ding would be a
## binary nobody can diff, an import sidecar, a licence to check, and a thing
## that has to be re-recorded to be re-tuned — against about eighty lines that
## re-tune by editing a frequency. It costs a fraction of a second of startup
## (see [constant MIX_RATE]) and it buys a chime whose pitch, length, brightness
## and shimmer are all in the diff.
##
## [b]What that fraction is, measured rather than assumed.[/b] Godot 4.7.1
## headless on a CI-class x86_64: about [b]105 ms[/b] for every voice [Chime]
## builds — the counter chime, the three rungs, the payout chord and the note the
## run holds on — against 40 ms for the single-note bell this replaced. The extra
## is the payout: four notes of four partials over twice a rung's length is more
## than half the total on its own. It is paid in [method Chime._ready] beside
## [Bandstand]'s much larger bill for the title theme, while the web export's
## loading screen is still up, so it lands inside a load rather than as a hitch
## in front of somebody. A phone will be several times slower and it will still
## land there.
##
## [b]Additive, and harmonic, because this is a machine and not a lump of
## metal.[/b] A cast bell's partials sit at ratios that are not whole numbers —
## 2.76 and 5.4 are the textbook pair — and that inharmonicity is exactly what
## makes one clang. A slot machine does not clang. Its chime is a synthesiser:
## partials on whole multiples of the fundamental, the same spectrum a plucked
## string or an organ pipe has, heard as a [i]note[/i] rather than as struck
## metal. [constant RATIOS] is therefore 1, 2, 3, 4, and it is the single change
## that moves this sound from hotel lobby to casino floor.
##
## [b]And it shimmers, which is the other half.[/b] Nothing on a casino floor is
## one clean tone: a payout chime is two of them a few cents apart, and the beat
## between two detuned copies is the sparkle. Two sines at [code]f[/code] and
## [code]f+d[/code] summed are identically one sine at the mean amplitude-modulated
## at [code]d[/code] — so [constant SHIMMER_HZ] and [constant SHIMMER_DEPTH] are
## that beat written as the modulation it already is, one cosine a sample instead
## of a second oscillator bank per partial. It is a knob rather than a constant
## baked into [method chord] so a test can build the same chime without it and
## measure the difference, which [code]tests/unit/test_bell.gd[/code] does.
##
## [b]It is in C, and it stays in C.[/b] [constant START_HZ] is C5, the patch
## chime is the C above it, and [constant PATCH_RUN_RATIOS] is a C major triad up
## to the octave — so the counter chime, every rung of the run and the payout
## chord are all the same three note names. That is not decoration: the point of
## a casino's audio is that a machine paying out sounds like good news before
## anybody has read a number, and a major triad on one root is the cheapest way
## there is to say so.
##
## [b]It ends in silence rather than being cut off.[/b] Every partial decays to
## well under a percent of its peak by the end of the buffer, so the last sample
## is near zero and there is no click when playback stops — a sound that ends on
## a step is heard as a fault in the game, not as the end of a chime.
class_name Bell
extends RefCounted

## Which chime to ring.
enum Voice {
	## The counter chime: one clear ding, low and long, for Start.
	START,
	## The little chime: shorter and an octave higher, for a patch coming clean.
	## Short on purpose — these come in threes and fours while the water is
	## running, and a long one would smear them into a drone.
	PATCH,
}

## Samples a second. 22050 rather than 44100 because the highest partial of the
## highest voice lands at [constant CEILING_HZ], comfortably under this rate's
## 11 kHz limit, and because every sample is a trip round a GDScript loop:
## halving the rate halves the startup cost of building every voice, on a phone
## in a browser where that cost is paid in a hitch rather than in a benchmark.
const MIX_RATE: int = 22050

## The partials of the chime, as multiples of its fundamental. Whole numbers,
## because this is a synthesiser and not a bell — see the class docs.
const RATIOS: PackedFloat32Array = [1.0, 2.0, 3.0, 4.0]

## How loud each partial starts, against the fundamental's 1.0. Falling steeply,
## because a chime whose overtones are as loud as its body reads as a cymbal —
## and less steeply than a bell's would, because whole-number partials are what
## this voice is [i]for[/i] and burying them under the fundamental would be
## paying for the spectrum and then hiding it.
const WEIGHTS: PackedFloat32Array = [1.0, 0.45, 0.25, 0.12]

## How many times a second the chime beats. The difference between two copies of
## it a few cents apart, if there were two — see the class docs. Eight and a half
## is a shimmer: slow enough to be heard as one sound wobbling rather than as a
## buzz, fast enough that three of them fit inside [constant PATCH_SECONDS] so
## even the shortest ding sparkles rather than merely starting to.
const SHIMMER_HZ: float = 8.5

## How deep the shimmer cuts, as a fraction of the amplitude: the chime swings
## between full and [code]1 - 2 * SHIMMER_DEPTH[/code] of it. Enough to hear,
## well short of the full cancellation two equal detuned copies would give —
## which on a sound this short would read as a stutter rather than as sparkle.
const SHIMMER_DEPTH: float = 0.22

## How many times the fundamental's amplitude halves-and-halves-again over the
## length of the sound: [code]e^-5[/code] is under a percent left at the end,
## which is the "ends in silence" promise in the class docs. Every partial above
## the fundamental decays this much faster again per multiple of its ratio, so
## the top of the chime is gone in the first fraction of a second and what rings
## on is the body.
const E_FOLDS: float = 5.0

## How long the strike takes to reach full volume, in seconds. Not zero: a
## waveform that starts at full amplitude starts with a step, and a step is a
## click. Three milliseconds is short enough to still be a strike.
const ATTACK_SECONDS: float = 0.003

## The fundamental of the counter chime, in hertz. C5 — the tonic everything
## else here is a ratio of, and low enough to have some body under the patch
## chime an octave above it. Still clear of the few hundred hertz below which a
## phone speaker has nothing at all, and its partials at 1046, 1570 and 2093 sit
## where a phone is loudest anyway.
const START_HZ: float = 523.25

## How long the counter chime rings for, in seconds.
const START_SECONDS: float = 1.1

## What the counter chime peaks at, as a fraction of full scale. Under 1.0 so a
## chime that lands on the same frame as anything else has somewhere to go.
const START_LEVEL: float = 0.75

## The fundamental of the patch chime — C6, an octave above the counter chime,
## so a game in progress is recognisably the same instrument in the same key as
## the one that started it. Also the root of [constant PATCH_RUN_RATIOS]: the
## first patch of a run always rings here.
const PATCH_HZ: float = 1046.5

## How the patch chime climbs on a run of consecutive patches, each entry a
## multiple of [constant PATCH_HZ]. C, E, G, C — a major triad up to the octave,
## rather than a chromatic run up: a plain triad has no step that clashes against
## the ones before it, which a semitone-by-semitone climb starts to after four or
## five steps.
##
## The last entry is where the run pays out rather than another rung: arriving on
## it rings [method payout] — the whole triad at once — and every patch after
## that holds on this note alone. [method voice] has the argument for why a run
## past the top stops paying and starts ringing.
const PATCH_RUN_RATIOS: PackedFloat32Array = [1.0, 1.25, 1.5, 2.0]

## How long a gap between two patches, in milliseconds, ends a run — dropping the
## next one back to the bottom of [constant PATCH_RUN_RATIOS] rather than letting
## it carry on climbing. A taste knob, the same way [constant PATCH_SECONDS] is:
## long enough that a run survives the player swinging the jet from one panel to
## the next, short enough that stopping to think really does start the ladder
## over rather than picking up where it left off a few seconds later.
##
## [b]It is here rather than on [Chime] because it is not only the chime's.[/b]
## [Scoring] climbs the same run for the multiplier, and the whole point of that
## feature is that the note going up and the number going up are one event: a
## reset the pitch honoured and the score did not would be a player hearing the
## ladder start over while the multiplier stayed high, which reads as a bug in
## whichever of the two they were watching. One constant, two readers, no way for
## them to drift. It sits beside [constant PATCH_RUN_RATIOS] because the ladder
## and how long you have to stay on it are the same decision.
const RUN_RESET_MSEC: int = 1500

## How long the patch chime rings for. A third of the counter chime: these arrive
## in bursts, and the point is to be able to count them.
const PATCH_SECONDS: float = 0.36

## What the patch chime peaks at. Quieter than the counter chime because it is
## heard far more often, and because several can overlap — [Chime] plays them on
## a pool of players rather than cutting each one off.
const PATCH_LEVEL: float = 0.5

## How long the payout chord rings for. Twice a plain rung, because it is the one
## moment in the game that is allowed to hang in the air, and still shorter than
## the counter chime because another patch can land a fifteenth of a second after
## it.
const PAYOUT_SECONDS: float = 0.72

## What the payout chord peaks at. Above [constant PATCH_LEVEL] — it is the
## payoff and it should land like one — and below [constant START_LEVEL], which
## is the loudest anything in this file gets.
const PAYOUT_LEVEL: float = 0.62

## The highest frequency any voice here puts out: the top of
## [constant PATCH_RUN_RATIOS] times the top of [constant RATIOS]. Worth writing
## down because it is the number [constant MIX_RATE] is chosen against, and
## because it is the ladder's top rung rather than [constant PATCH_HZ] that
## decides it — a partial above half the mix rate does not vanish, it folds back
## down as an inharmonic whistle, which is the one thing a chime built out of
## whole numbers cannot afford. [code]tests/unit/test_bell.gd[/code] asserts the
## margin rather than leaving it to this comment.
const CEILING_HZ: float = PATCH_HZ * 2.0 * 4.0

## Full scale for the 16-bit samples this writes.
const FULL_SCALE: float = 32767.0


## The stream for [param which] chime, ready to hand to an [AudioStreamPlayer].
##
## [param run] only matters for [constant Voice.PATCH]: it is how many
## consecutive patches have rung before this one, and it picks the rung of
## [constant PATCH_RUN_RATIOS] this strike lands on. Ignored for
## [constant Voice.START] — the counter chime does not climb.
##
## [b]The top of the ladder is two sounds, not one.[/b] Rungs below it are single
## notes climbing the triad. Arriving on the top rung rings [method payout], the
## whole triad struck together. Every patch [i]past[/i] it rings the top note on
## its own, and that last case is the one worth explaining: a long sweep holds at
## the top of the ladder, so a payout there would re-pay every patch for as long
## as the player kept the jet moving — a jackpot every seventieth of a second is
## not a jackpot, it is a fire alarm in C major. Ringing on the top note instead
## is what a machine that has already paid actually does, and it leaves the chord
## meaning "you got here".
##
## Built fresh on every call rather than cached in a `static var`: a shared
## [AudioStreamWAV] is a mutable global, and the caller that wants one kept is
## [Chime], which keeps it for the life of the game and knows it.
static func voice(which: Voice, run: int = 0) -> AudioStreamWAV:
	if which != Voice.PATCH:
		return strike(START_HZ, START_SECONDS, START_LEVEL)
	var top: int = PATCH_RUN_RATIOS.size() - 1
	if run == top:
		return payout()
	return strike(PATCH_HZ * PATCH_RUN_RATIOS[clampi(run, 0, top)], PATCH_SECONDS, PATCH_LEVEL)


## The payout: every rung of [constant PATCH_RUN_RATIOS] struck at once.
##
## The chord is the ladder rather than a chord written out separately, so
## retuning the climb retunes what it pays out into and the two cannot come
## apart. Struck together they are one C major triad spread over two octaves,
## with the root doubled at the top — which is why arriving on it reads as
## landing rather than as four notes that happened to coincide.
static func payout() -> AudioStreamWAV:
	var notes: PackedFloat32Array = PackedFloat32Array()
	for ratio: float in PATCH_RUN_RATIOS:
		notes.append(PATCH_HZ * ratio)
	return chord(notes, PAYOUT_SECONDS, PAYOUT_LEVEL)


## A chime of [param hz], ringing for [param seconds], peaking at [param level]
## of full scale.
##
## The one-note case of [method chord], kept as its own function because it is
## what both plain voices want and because "strike a note" is the knob a tuning
## change reaches for.
static func strike(hz: float, seconds: float, level: float) -> AudioStreamWAV:
	return chord([hz] as PackedFloat32Array, seconds, level)


## Every note in [param notes] struck together for [param seconds], peaking at
## [param level] of full scale, shimmering [param depth] deep.
##
## Mono, 16-bit, [constant MIX_RATE], no loop. Normalised by its own measured
## peak rather than by a level worked out on paper — the partials are summed, so
## how loud the sum gets depends on how their phases land, and guessing at that
## is how a sound ships either inaudible or clipped. That matters more here than
## it did when this only ever made one note at a time: the payout is sixteen
## partials whose sum nobody can predict on paper.
##
## The shimmer is one cosine over the whole frame rather than one per note, so a
## chord wobbles as a chord instead of as four things beating against each other
## at once — and so it costs the same whether one note is ringing or four.
static func chord(
	notes: PackedFloat32Array, seconds: float, level: float, depth: float = SHIMMER_DEPTH
) -> AudioStreamWAV:
	var frames: int = maxi(int(seconds * float(MIX_RATE)), 1)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(frames)
	var peak: float = 0.0
	for frame: int in frames:
		var at: float = float(frame) / float(MIX_RATE)
		var value: float = 0.0
		for hz: float in notes:
			value += _partials(hz, seconds, at)
		value *= minf(at / ATTACK_SECONDS, 1.0) * _shimmer(depth, at)
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


## Every partial of a chime of [param hz] lasting [param seconds], summed at
## [param at] seconds in, before the shimmer, the attack ramp and normalising.
static func _partials(hz: float, seconds: float, at: float) -> float:
	var value: float = 0.0
	for partial: int in RATIOS.size():
		var ratio: float = RATIOS[partial]
		# The fundamental gets the whole buffer to fade over and everything above
		# it fades that much faster — the class docs have why.
		var life: float = seconds / (E_FOLDS * ratio)
		value += WEIGHTS[partial] * exp(-at / life) * sin(TAU * hz * ratio * at)
	return value


## What the shimmer multiplies the chime by at [param at] seconds in, [param depth]
## deep.
##
## Starts at 1.0 rather than anywhere in the middle of its swing, so the strike
## is struck at full amplitude and the wobble takes the frames after it — a
## shimmer that started in its own trough would soften the transient, which is
## the one part of a chime nobody is allowed to touch.
static func _shimmer(depth: float, at: float) -> float:
	return 1.0 - depth + depth * cos(TAU * SHIMMER_HZ * at)


## One sample as the signed 16-bit integer the stream stores, clamped rather than
## wrapped: an overflow here would be heard as a crack, and the whole point of
## normalising above is that this never has to do anything.
static func _to_pcm(value: float) -> int:
	return clampi(roundi(value * FULL_SCALE), -32768, 32767)
