## The instruments: six voices of a small synthetic orchestra, each one a run of
## arithmetic rather than a recording.
##
## This is the [Bell] tier for music — it knows how to make a sound and nothing
## about when. [Fanfare] owns the tune, [Bandstand] owns the playing of it, and
## this owns the question "what does a brass stab sound like".
##
## [b]Why there are voices here at all rather than a module file.[/b] The obvious
## answer to "a title theme that costs no download" is a tracker module — a .s3m
## or a .mod, which is small precisely because it is a handful of short samples
## plus a pattern that says where to put them. Godot imports WAV, Ogg Vorbis and
## MP3 and nothing else: no MOD, no S3M, no XM, no IT, and no MIDI either (the
## engine's MIDI is [InputEventMIDI], for reading a keyboard somebody plugged in,
## not a synthesiser). So a tracker is not something we can ship.
##
## But a tracker is only two halves, and the repo already builds the first half
## in code — [method Bell.strike] writes an [AudioStreamWAV] out of a loop over
## [code]sin[/code]. This file is that half widened to six instruments and
## [Fanfare] is the pattern. What we lose against a real module is a tracker to
## edit it in. What we gain is the same thing [Bell] gains: the theme is a diff.
##
## [b]The wavetable, and why it is a stack of them.[/b] A note here is not summed
## from sines per sample the way a bell is — a bell is one and a half seconds
## long and the theme is fifteen, and the same approach would multiply the
## project's startup cost by something nobody would accept. Instead each timbre
## is drawn once into a table of [constant TABLE_SIZE] samples and every note is
## a walk round that table at its own speed, which turns a dozen transcendental
## calls per sample into two array reads and a lerp.
##
## The cost of a table is aliasing: reading it faster than it was drawn for folds
## every harmonic above [constant MIX_RATE] / 2 back down into the audible range
## as an inharmonic whistle, and it is the sound of a synthesiser being played
## wrong. So there is not one table but [constant OCTAVES] of them, each drawn
## with only the harmonics that still fit under the ceiling at the top of its
## octave — a mip chain for a waveform, chosen per note by pitch. The bottom
## octave gets [constant MAX_HARMONICS] and a bright brassy edge; the top gets
## three or four and is nearly a sine, which is also what a real instrument does
## up there.
##
## [b]The noise is deterministic.[/b] The snare and the hat are filtered noise,
## and noise from [method RandomNumberGenerator.randf] would make the theme a
## different waveform on every boot — a thing no test can assert on and no ear
## can review twice. [method _noise] is a fixed xorshift from a per-voice seed,
## so the drum kit is the same kit on every machine and in every run, and
## [code]tests/unit/test_fanfare.gd[/code] can assert that two builds of the
## theme are byte-identical.
class_name Timbre
extends RefCounted

## Which instrument to play.
enum Voice {
	## The lead: the brass line that carries the tune. Bright, with enough of a
	## front edge on it to read as blown rather than as a pad fading in.
	BRASS,
	## The section under it, playing chord tones on the offbeat. The same table
	## as [constant BRASS] at a lower register and a shorter envelope, because a
	## stab is a brass note with its sustain taken away.
	HORN,
	## The bass. A hollower table — odd harmonics weighted up — because a pure
	## saw down here turns to mud on the only speaker most people will hear this
	## on.
	BASS,
	## The kick: a sine falling from [constant KICK_TOP_HZ] to
	## [constant KICK_BOTTOM_HZ]. Not a sample of a drum, the arithmetic of one.
	KICK,
	## The snare, gated — see [constant SNARE_GATE_SECONDS], which is the single
	## number that dates this whole arrangement to about 1992.
	SNARE,
	## The hat. Noise, differentiated to take the body out of it, and gone in a
	## twentieth of a second.
	HAT,
}

## Samples a second, matching [constant Bell.MIX_RATE] for the same reason it
## picked that number: every sample is a trip round a GDScript loop, and this
## loop runs for fifteen seconds of audio rather than one. The ceiling it buys is
## 11 kHz, which is the number the octave tables are cut against.
const MIX_RATE: int = 22050

## How many samples one cycle of a timbre is drawn into. A power of two so the
## wrap in [method _oscillate] is a mask rather than a modulo, and 1024 rather
## than 256 because the linear interpolation between two table entries is the
## other place aliasing comes from.
const TABLE_SIZE: int = 1024

## How many tables each timbre is drawn into, one per MIDI octave from 0 up. The
## theme uses about four of them; the rest exist so a note written outside that
## range is quietly correct rather than quietly a whistle.
const OCTAVES: int = 9

## The most harmonics any table is drawn with, before the ceiling cuts it down.
## Fourteen is comfortably past the point where a saw stops getting brighter and
## starts only getting more expensive to draw.
const MAX_HARMONICS: int = 14

## The highest frequency that survives [constant MIX_RATE]. Anything drawn above
## this folds back down as an inharmonic tone, so it is the cut every octave
## table is made against — with a little headroom, because the top harmonic of a
## table is still audible as a whistle when it sits right on the ceiling.
const CEILING_HZ: float = float(MIX_RATE) * 0.45

## A4, in hertz — the one tuning constant everything else is a ratio of.
const CONCERT_A_HZ: float = 440.0

## The MIDI note number of A4, so [method hz] is the standard formula rather than
## a table.
const CONCERT_A_MIDI: int = 69

## How much louder the odd harmonics of [constant Voice.BASS] are drawn than the
## even ones. Above 1.0 the table leans towards a square, which is hollow where a
## saw is thick — the difference between a bass you can hear on a phone and a
## bass that is only a rumble smearing everything above it.
const BASS_ODD_LIFT: float = 2.0

## Where the kick starts, in hertz, before it falls. High enough to have a click
## in it: a kick that starts at its floor is a thud with no front, and on a small
## speaker the front is the entire drum.
const KICK_TOP_HZ: float = 150.0

## Where the kick lands.
const KICK_BOTTOM_HZ: float = 48.0

## How long the kick takes to fall, in seconds — the shape of it, and short,
## because the pitch drop is the transient rather than a slide anybody hears as
## pitch.
const KICK_SWEEP_SECONDS: float = 0.045

## How long a kick rings, in seconds.
const KICK_SECONDS: float = 0.30

## How long a snare rings before the gate takes it, in seconds. See
## [constant SNARE_GATE_SECONDS] — this is the decay the gate interrupts, and it
## is deliberately longer than the gate so there is something there to cut.
const SNARE_DECAY_SECONDS: float = 0.34

## Where the snare is cut off dead. [b]This is the gated reverb[/b] — the sound
## of a big room's tail chopped by a noise gate, which is what every drum on
## every sports broadcast and film trailer between about 1984 and 1995 was
## printed with. A snare left to decay naturally sounds like a drum in a room; a
## snare cut here sounds like a drum on television, which is the whole brief.
const SNARE_GATE_SECONDS: float = 0.155

## How long the gate takes to close, in seconds. Not zero: a waveform cut to
## silence in one sample is a step, and a step is a click. Six milliseconds is
## short enough to still be heard as a cut rather than as a fade.
const SNARE_GATE_RELEASE: float = 0.006

## The pitch of the drum under the snare's noise, in hertz. A snare is not only
## a rattle — the head has a note in it, and without this the voice reads as a
## burst of static on the backbeat.
const SNARE_TONE_HZ: float = 185.0

## How much of the snare is the head rather than the wires.
const SNARE_TONE_MIX: float = 0.35

## How long a hat rings, in seconds.
const HAT_SECONDS: float = 0.05

## How long the three unpitched voices take to reach full volume, in seconds.
##
## [b]Not zero, and this is not a detail.[/b] A drum is physically a step — that
## is what a transient is — but a waveform that begins at, say, -0.23 begins with
## a discontinuity, and a discontinuity is a click sitting on top of the hit. With
## a snare on every backbeat and a hat on every sixteenth that is thirty-odd
## clicks a bar. A millisecond and a half is twenty-two samples at
## [constant MIX_RATE]: far too short for anyone to hear as a softer hit, long
## enough that the sound starts from silence. Caught by
## [code]tests/unit/test_timbre.gd[/code], which asserts it of every voice.
const TRANSIENT_ATTACK_SECONDS: float = 0.0015

## The attack, decay, sustain and release of each pitched voice, in that order —
## the first, second and fourth in seconds, the third as a fraction of the peak.
## Read by [method _envelope], which multiplies the three curves together rather
## than switching between them, so there is no stage boundary for a note shorter
## than its own envelope to land on and click at.
const BRASS_ADSR: PackedFloat32Array = [0.014, 0.070, 0.85, 0.070]

## See [constant BRASS_ADSR]. Shorter everywhere: a stab is a brass note with the
## middle taken out of it.
const HORN_ADSR: PackedFloat32Array = [0.008, 0.055, 0.45, 0.045]

## See [constant BRASS_ADSR]. The fastest attack of the three, because a bass
## note that arrives late is heard as the beat being late.
const BASS_ADSR: PackedFloat32Array = [0.004, 0.060, 0.72, 0.030]

## The seed each noise voice draws from, so the kit is the same kit on every
## machine. Two different values so the snare and the hat are not the same
## rattle at two lengths, which is audible as a phasing artefact when they land
## on the same step.
const SNARE_SEED: int = 0x5EED_5EA1

## See [constant SNARE_SEED].
const HAT_SEED: int = 0x1CE_CAFE

## The 32-bit mask the xorshift in [method _noise] is kept inside. GDScript ints
## are 64-bit, so the left shifts would otherwise walk off into a range the
## algorithm was never defined over and the sequence would stop being the one
## everybody else's xorshift32 produces.
const WORD: int = 0xFFFF_FFFF

## Drawn on first use and never redrawn or mutated after — [method _tables] has
## why that is safe here when [method Bell.voice] argues the opposite for a
## stream.
static var _drawn: Dictionary[Voice, Array] = {}


## The frequency of MIDI note [param midi], in hertz. A4 is 69 and every octave
## doubles, which is the whole of it.
static func hz(midi: int) -> float:
	return CONCERT_A_HZ * pow(2.0, float(midi - CONCERT_A_MIDI) / 12.0)


## How many frames [param seconds] is at [constant MIX_RATE], never zero — a
## note rounded down to no samples at all is silence that no assertion about
## pitch or envelope can see.
static func frames(seconds: float) -> int:
	return maxi(int(seconds * float(MIX_RATE)), 1)


## One note of [param voice] at MIDI pitch [param midi], lasting
## [param seconds], as samples in [code]-1..1[/code].
##
## Floats rather than the 16-bit an [AudioStreamWAV] wants, and not normalised:
## these are summed by [Fanfare] before anything is decided about how loud the
## result is, and a voice that normalised itself would make every note in the
## arrangement the same loudness no matter what it was written as.
##
## [param midi] is ignored by the three unpitched voices — a kick is a kick.
static func note(voice: Voice, midi: int, seconds: float) -> PackedFloat32Array:
	match voice:
		Voice.KICK:
			return _kick(seconds)
		Voice.SNARE:
			return _snare(seconds)
		Voice.HAT:
			return _hat(seconds)
		Voice.HORN:
			return _pitched(voice, midi, seconds, HORN_ADSR)
		Voice.BASS:
			return _pitched(voice, midi, seconds, BASS_ADSR)
		_:
			return _pitched(voice, midi, seconds, BRASS_ADSR)


## A pitched note: [param voice]'s table for [param midi]'s octave, walked at
## [param midi]'s frequency for [param seconds], under the envelope
## [param adsr] describes.
static func _pitched(
	voice: Voice, midi: int, seconds: float, adsr: PackedFloat32Array
) -> PackedFloat32Array:
	var table: PackedFloat32Array = _tables(voice)[clampi(midi / 12, 0, OCTAVES - 1)]
	return _oscillate(table, hz(midi), seconds, adsr)


## [param table] read at [param at_hz] for [param seconds], shaped by
## [param adsr].
##
## The phase is kept in table units rather than in radians so the read is an
## index and a fraction with no scaling in the inner loop, and it is wrapped by
## subtraction rather than by [code]fposmod[/code] because the step is always
## smaller than the table and one subtraction is therefore always enough.
static func _oscillate(
	table: PackedFloat32Array, at_hz: float, seconds: float, adsr: PackedFloat32Array
) -> PackedFloat32Array:
	var count: int = frames(seconds)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(count)
	var step: float = at_hz * float(TABLE_SIZE) / float(MIX_RATE)
	var phase: float = 0.0
	for frame: int in count:
		var index: int = int(phase)
		var blend: float = phase - float(index)
		var here: float = table[index & (TABLE_SIZE - 1)]
		var next: float = table[(index + 1) & (TABLE_SIZE - 1)]
		out[frame] = (
			(here + (next - here) * blend)
			* _envelope(float(frame) / float(MIX_RATE), seconds, adsr)
		)
		phase += step
		if phase >= float(TABLE_SIZE):
			phase -= float(TABLE_SIZE)
	return out


## The envelope [param adsr] describes, at [param at] seconds into a note of
## [param seconds].
##
## Three curves multiplied rather than four stages switched between. A stage
## machine has to decide what a note does when it is shorter than its own attack
## plus release, and every answer to that is a discontinuity somewhere; a product
## of an attack ramp, a decay towards the sustain and a release ramp is
## continuous for any note of any length, and at the lengths this arrangement
## actually uses it is indistinguishable from the stage machine anyway.
static func _envelope(at: float, seconds: float, adsr: PackedFloat32Array) -> float:
	var attack: float = minf(at / adsr[0], 1.0)
	var decay: float = adsr[2] + (1.0 - adsr[2]) * exp(-at / adsr[1])
	var release: float = clampf((seconds - at) / adsr[3], 0.0, 1.0)
	return attack * decay * release


## The kick: a sine whose frequency falls from [constant KICK_TOP_HZ] to
## [constant KICK_BOTTOM_HZ], under a decay of its own.
##
## The phase is integrated rather than computed from [code]hz * at[/code],
## which would be a different sound entirely — multiplying a falling frequency by
## an advancing time runs the phase backwards partway through the sweep, and what
## comes out is a warble instead of a drop.
static func _kick(seconds: float) -> PackedFloat32Array:
	var count: int = frames(seconds)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(count)
	var phase: float = 0.0
	for frame: int in count:
		var at: float = float(frame) / float(MIX_RATE)
		var falling: float = (
			KICK_BOTTOM_HZ + (KICK_TOP_HZ - KICK_BOTTOM_HZ) * exp(-at / KICK_SWEEP_SECONDS)
		)
		phase += TAU * falling / float(MIX_RATE)
		out[frame] = (
			sin(phase) * exp(-at / (seconds * 0.35)) * minf(at / TRANSIENT_ATTACK_SECONDS, 1.0)
		)
	return out


## The snare: wires, head, and the gate that dates it.
##
## The decay under it runs longer than [constant SNARE_GATE_SECONDS] on purpose —
## the gate is only audible as a gate if it is cutting something that was still
## going, and a decay tuned to end where the gate is would just be a short snare.
static func _snare(seconds: float) -> PackedFloat32Array:
	var count: int = frames(seconds)
	var wires: PackedFloat32Array = _noise(count, SNARE_SEED)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(count)
	for frame: int in count:
		var at: float = float(frame) / float(MIX_RATE)
		var head: float = sin(TAU * SNARE_TONE_HZ * at)
		var body: float = wires[frame] * (1.0 - SNARE_TONE_MIX) + head * SNARE_TONE_MIX
		var gate: float = clampf((SNARE_GATE_SECONDS - at) / SNARE_GATE_RELEASE + 1.0, 0.0, 1.0)
		out[frame] = (
			body * exp(-at / SNARE_DECAY_SECONDS) * gate * minf(at / TRANSIENT_ATTACK_SECONDS, 1.0)
		)
	return out


## The hat: noise with its body differentiated away.
##
## The difference between neighbouring samples is a one-pole high pass and it is
## the cheapest one there is — noise minus a delayed copy of itself cancels
## whatever moves slowly and keeps whatever moves fast, which is the definition
## of the sound wanted here.
static func _hat(seconds: float) -> PackedFloat32Array:
	var count: int = frames(seconds)
	var source: PackedFloat32Array = _noise(count + 1, HAT_SEED)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(count)
	for frame: int in count:
		var at: float = float(frame) / float(MIX_RATE)
		out[frame] = (
			(source[frame + 1] - source[frame])
			* 0.5
			* exp(-at / (seconds * 0.28))
			* minf(at / TRANSIENT_ATTACK_SECONDS, 1.0)
		)
	return out


## [param count] samples of white noise in [code]-1..1[/code], from
## [param from_seed].
##
## xorshift32, spelled out rather than taken from [RandomNumberGenerator]: the
## point is that the same seed gives the same drum on every platform and in every
## run, and the engine's generator makes no promise about that across versions.
## Every shift is masked back to [constant WORD] because GDScript ints are 64-bit
## and an unmasked xorshift32 is a different sequence.
static func _noise(count: int, from_seed: int) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(count)
	var state: int = from_seed & WORD
	for frame: int in count:
		state = (state ^ (state << 13)) & WORD
		state = state ^ (state >> 17)
		state = (state ^ (state << 5)) & WORD
		out[frame] = float(state) / 2147483647.5 - 1.0
	return out


## [param voice]'s octave tables, drawn on the first call and handed back
## unchanged on every one after.
##
## [b]A cache in a static var, which [method Bell.voice] explicitly refuses to
## do.[/b] The difference is what is being handed out. Bell hands out an
## [AudioStreamWAV], which a caller can assign to a player and then mutate, so a
## shared one is a mutable global with the game's audio hanging off it. These are
## [PackedFloat32Array]s, which GDScript copies on assignment — a caller cannot
## reach back through one and change the table. Nothing in this file writes to a
## table after [method _draw] returns it, and the only reader is
## [method _pitched].
static func _tables(voice: Voice) -> Array:
	if not _drawn.has(voice):
		var built: Array = []
		for octave: int in OCTAVES:
			built.append(_draw(voice, octave))
		_drawn[voice] = built
	return _drawn[voice]


## One table for [param voice] at [param octave], drawn with every harmonic that
## still fits under [constant CEILING_HZ] at the top of that octave.
##
## The top of the octave rather than the bottom, because one table serves all
## twelve notes in it and the highest of them is the one that folds first.
static func _draw(voice: Voice, octave: int) -> PackedFloat32Array:
	var top: float = hz(octave * 12 + 11)
	var harmonics: int = clampi(int(CEILING_HZ / top), 1, MAX_HARMONICS)
	var table: PackedFloat32Array = PackedFloat32Array()
	table.resize(TABLE_SIZE)
	var peak: float = 0.0
	for index: int in TABLE_SIZE:
		var turn: float = TAU * float(index) / float(TABLE_SIZE)
		var value: float = 0.0
		for harmonic: int in range(1, harmonics + 1):
			value += _weight(voice, harmonic) * sin(turn * float(harmonic))
		table[index] = value
		peak = maxf(peak, absf(value))
	if peak > 0.0:
		for index: int in TABLE_SIZE:
			table[index] /= peak
	return table


## How loud [param harmonic] is drawn for [param voice], against a fundamental
## of 1.0.
##
## [code]1 / n[/code] is a sawtooth, which is the brass end of the spectrum and
## what both brass voices want. The bass lifts its odd harmonics towards a
## square — see [constant BASS_ODD_LIFT].
static func _weight(voice: Voice, harmonic: int) -> float:
	var falloff: float = 1.0 / float(harmonic)
	if voice == Voice.BASS and harmonic % 2 == 1:
		return falloff * BASS_ODD_LIFT
	return falloff
