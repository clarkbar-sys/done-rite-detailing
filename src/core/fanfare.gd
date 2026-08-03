## The title theme: eight bars of loud brass at a tempo you can march to, built
## out of arithmetic and looping forever until somebody presses Start.
##
## [Timbre] is the orchestra and this is the score. What it hands back is one
## [AudioStreamWAV] with [constant AudioStreamWAV.LOOP_FORWARD] set on it, which
## [Bandstand] plays and fades.
##
## [b]What this is meant to sound like, said plainly, because it is the only part
## of the brief no constant can carry.[/b] Network sports television, about 1992:
## a synth-brass fanfare over a rock backing, a gated snare on the backbeat, and
## sixteenth hats under the second half so it lifts rather than repeats. That is
## a [i]genre[/i], and genres are not anybody's property — the tune below is
## original and no part of it is transcribed from a broadcast theme, all of which
## are somebody's copyright and several of which are still on air.
##
## [b]The shape of it.[/b] Eight bars of D, in the mixolydian the whole idiom
## lives in: [code]D | C | G | D | D | C | G | A[/code]. The flat seventh in bar
## two is the entire 1980s-and-90s arena sound in one chord, and the A in bar
## eight is a dominant that resolves onto the D at the top of bar one — so the
## loop point is not a join anybody has to hide, it is where the tune was going
## anyway. The second half answers the first an octave-and-a-bit up with the
## drums opened out, and the last bar is a run home rather than a held note,
## which is what stops fifteen seconds on repeat from reading as fifteen seconds
## on repeat.
##
## [b]The grid.[/b] [constant STEPS_PER_BEAT] sixteenths to a beat,
## [constant BEATS_PER_BAR] beats to a bar, [constant BARS] bars — 128 steps,
## and every note below is written as the step it starts on and how many steps it
## lasts. That is a tracker's pattern in everything but the file format, which is
## the point: Godot cannot import a .s3m ([Timbre] has that argument), so the
## pattern is a [PackedInt32Array] and the samples are a loop over [code]sin[/code].
##
## [b]Steps are placed, not accumulated.[/b] A sixteenth at
## [constant BPM] is 2505.68 samples and no arrangement of integers makes that
## exact, so [method _at] rounds each step's position from the start of the piece
## rather than adding a rounded step length repeatedly. The difference over 128
## steps is the difference between a snare that is where it was written and one
## that has drifted a thirtieth of a second late by the last bar.
##
## [b]What it costs, measured rather than assumed.[/b] Godot 4.7.1 headless on a
## CI-class x86_64: about [b]390 ms[/b] for the first build and 285 ms for one
## after that, the difference being [Timbre]'s octave tables, which are drawn
## once and kept. That is roughly a third of a million samples written by a GDScript loop
## and it is the honest price of not shipping a file. It is paid in
## [method Bandstand._ready], which runs while the web export's loading screen is
## still up, so it lands inside a load rather than as a hitch in front of
## somebody. A phone will be several times slower and it will still land there.
##
## If that ever stops being true the answer is not to reach for an .ogg — it is
## that the note cache in [method _voice] and the placement loop in
## [method _place] are the whole of the cost, and both are ordinary code that
## could be cut across frames. Measure before believing any of that.
##
## [b]And it wraps.[/b] A note whose tail runs past the end of the eighth bar is
## mixed back onto the beginning — see [method _place]. Without that the loop has
## a hole in it exactly where the last cymbal-ish hat and the ring of the last
## brass note should be carrying across the seam, and a loop with a hole at the
## seam is the most audible fault a piece of game music can have.
class_name Fanfare
extends RefCounted

## Beats a minute. Fast enough to be a march rather than an anthem, slow enough
## that the sixteenth hats in the second half are still separate events on a
## phone speaker rather than a buzz.
const BPM: float = 132.0

## Sixteenths to a beat: the resolution every position below is written at.
const STEPS_PER_BEAT: int = 4

## Beats to a bar. Four, because this is not that kind of piece.
const BEATS_PER_BAR: int = 4

## How many bars the loop is.
const BARS: int = 8

## Steps in a bar, for reading the score below.
const STEPS_PER_BAR: int = STEPS_PER_BEAT * BEATS_PER_BAR

## Steps in the whole loop.
const STEPS: int = STEPS_PER_BAR * BARS

# ---- the notes, as MIDI numbers -----------------------------------------------
#
# Named rather than written as bare integers in the score: `D5` is checkable
# against the chord it is sitting on and `74` is not. `S` is sharp — `FS5` is
# F#5 — because `#` starts a comment.

## B below middle C: the third of the G chord, and the lowest note the horn
## section plays.
const B3: int = 59

## Middle C.
const C4: int = 60

## The third of the A chord in bar eight, and the note that makes it a dominant
## rather than a modal wash.
const CS4: int = 61

const D4: int = 62
const E4: int = 64
const FS4: int = 66
const G4: int = 67

## The bottom of the melody's range.
const A4: int = 69

const B4: int = 71
const C5: int = 72
const D5: int = 74
const E5: int = 76
const FS5: int = 78
const G5: int = 79

## The top of the melody's range, and the note bar eight's run lands on.
const A5: int = 81

## The bass roots, an octave and change below the horns.
const G2: int = 43
const A2: int = 45
const C3: int = 48
const D3: int = 50

# ---- the score ----------------------------------------------------------------

## The tune: a row per note, each one [code]step, note, length in steps[/code].
##
## [b]Rows, not a flat run of integers.[/b] The obvious spelling is one
## [PackedInt32Array] of 3n numbers, and it is unreadable after the formatter has
## been over it: gdformat puts one element of a multi-line collection on each
## line, so a flat score becomes a column of a hundred and five bare numbers with
## no way to tell a step from a pitch. An array of three-element rows formats as
## one row per line, because each row fits on one — which is a tracker pattern,
## which is what this is.
##
## [b]And [Vector3i] rather than the [PackedInt32Array] a row obviously wants to
## be, because of an engine bug — measured on Godot 4.7.1, do not undo this
## without re-measuring.[/b] A [code]const Array[PackedInt32Array][/code] hands
## back garbage for any access that is not constant-folded at parse time:
## [code]NESTED[0][/code] with a literal index is correct, while iterating it, or
## indexing it with a variable, or even [method Array.duplicate]-ing it, reads
## uninitialised memory — MIDI note 255587408, and a theme that came out as noise
## and clipped. A local [code]var[/code] or a [code]static var[/code] of the same
## type is fine, so it is the constant folding rather than the type. [Vector3i]
## is exactly three ints, is a POD the folder handles correctly, still indexes as
## [code]row[STEP][/code], and makes "a row has three numbers in it" a thing the
## type guarantees instead of a thing a test has to check.
##
## Written one bar to a block, in the order the bars are played. The chord each
## bar is sitting on is in the comment above it — that is the only place the
## harmony and the melody are checked against each other, so it is worth keeping
## honest when either changes.
const MELODY: Array[Vector3i] = [
	# Bar 1 — D. The call: the tonic, a dip to the fifth below, then up the triad.
	Vector3i(0, D5, 4),
	Vector3i(4, A4, 2),
	Vector3i(6, D5, 2),
	Vector3i(8, FS5, 4),
	Vector3i(12, E5, 2),
	Vector3i(14, D5, 2),
	# Bar 2 — C. The flat seventh, and the whole reason this reads as an anthem
	# rather than as a hymn.
	Vector3i(16, C5, 6),
	Vector3i(22, E5, 2),
	Vector3i(24, G5, 6),
	Vector3i(30, E5, 2),
	# Bar 3 — G. Up the fourth chord to the top of the first half.
	Vector3i(32, B4, 2),
	Vector3i(34, D5, 2),
	Vector3i(36, G5, 8),
	Vector3i(44, FS5, 2),
	Vector3i(46, E5, 2),
	# Bar 4 — D. Home, held, with two sixteenths of a pickup into the answer.
	Vector3i(48, D5, 12),
	Vector3i(60, A4, 2),
	Vector3i(62, C5, 2),
	# Bar 5 — D. The answer, same opening, but it climbs to the top of the range
	# instead of settling.
	Vector3i(64, D5, 4),
	Vector3i(68, A4, 2),
	Vector3i(70, D5, 2),
	Vector3i(72, FS5, 4),
	Vector3i(76, A5, 4),
	# Bar 6 — C.
	Vector3i(80, G5, 6),
	Vector3i(86, E5, 2),
	Vector3i(88, C5, 8),
	# Bar 7 — G.
	Vector3i(96, D5, 4),
	Vector3i(100, B4, 2),
	Vector3i(102, D5, 2),
	Vector3i(104, G5, 8),
	# Bar 8 — A. The run home. Every sixteenth of it is going somewhere, and where
	# it is going is the D that step 0 starts on.
	Vector3i(112, E5, 2),
	Vector3i(114, FS5, 2),
	Vector3i(116, G5, 2),
	Vector3i(118, A5, 4),
	Vector3i(122, G5, 2),
	Vector3i(124, FS5, 2),
	Vector3i(126, E5, 2),
]

## Where in a row of [constant MELODY] the step, the note and the length are.
const STEP: int = 0
const NOTE: int = 1
const LENGTH: int = 2

## The three chord tones the horns stab, a row per bar — root, third and fifth of
## [code]D C G D D C G A[/code], voiced in the octave below the melody so the
## section sits under the tune rather than fighting it for the same notes.
const CHORD_TONES: Array[Vector3i] = [
	Vector3i(D4, FS4, A4),
	Vector3i(C4, E4, G4),
	Vector3i(B3, D4, G4),
	Vector3i(D4, FS4, A4),
	Vector3i(D4, FS4, A4),
	Vector3i(C4, E4, G4),
	Vector3i(B3, D4, G4),
	Vector3i(CS4, E4, A4),
]

## The root of each bar, for the bass.
const ROOTS: PackedInt32Array = [D3, C3, G2, D3, D3, C3, G2, A2]

## Which steps of a bar the horns stab on in the first half: the "and" of four
## only, so the first four bars are the tune and a backbeat and not much else.
## Sparse on purpose — everything the second half adds has to be added [i]to[/i]
## something.
const HORN_STEPS_EARLY: PackedInt32Array = [14]

## Which steps the horns stab on in the second half. The "and" of two as well,
## which is the offbeat push the whole idiom runs on.
const HORN_STEPS_LATE: PackedInt32Array = [6, 14]

## Which steps of every bar the kick lands on. Not four-on-the-floor: the
## sixteenth-late kick on step 6 is the syncopation that makes this a rock
## backing rather than a disco one.
const KICK_STEPS: PackedInt32Array = [0, 6, 8]

## Which steps of every bar the snare lands on. Two and four — the backbeat,
## and with [constant Timbre.SNARE_GATE_SECONDS] on it, the loudest thing in the
## arrangement.
const SNARE_STEPS: PackedInt32Array = [4, 12]

## The extra snares in the last bar, over the run home. A fill, which is what
## tells the ear the loop is about to come round again rather than stop.
const FILL_STEPS: PackedInt32Array = [10, 13, 14, 15]

## How long a horn stab lasts, in steps.
const STAB_STEPS: int = 2

## How long a bass note lasts, in steps. Eighths, one after another, all the way
## through — the part of this arrangement doing the actual driving.
const BASS_STEPS: int = 2

## The bar the second half starts on: where the hats double, the horns pick up
## the offbeat and the melody starts climbing. Half of [constant BARS], and
## written as that rather than as 4 so the two move together.
const LIFT_BAR: int = BARS / 2

## Which bars lift the last two bass notes an octave. The bar before each half
## ends, so the line walks up into the answer and into the loop point instead of
## sitting on the root for sixteen bars running.
const BASS_LIFT_BARS: PackedInt32Array = [3, 7]

# ---- the mix ------------------------------------------------------------------

## How loud each voice is mixed, against the melody's 1.0. Ratios rather than
## decibels because they are multiplied straight onto the samples, and the whole
## sum is normalised to [constant LEVEL] afterwards — so these set the balance
## between the parts and nothing about the final loudness.
const BRASS_LEVEL: float = 1.0
const HORN_LEVEL: float = 0.5
const BASS_LEVEL: float = 0.72
const KICK_LEVEL: float = 0.9
const SNARE_LEVEL: float = 0.62

## The hats are the quietest thing here by a distance, and in the second half
## there are sixteen of them a bar. Anything louder and they are all anyone
## hears.
const HAT_LEVEL: float = 0.2

## What the finished theme peaks at, as a fraction of full scale. Under 1.0 for
## the same reason [constant Bell.START_LEVEL] is: a bell rung over the top of
## the music has to have somewhere to go.
const LEVEL: float = 0.72

## Full scale for the 16-bit samples this writes, matching [constant Bell.FULL_SCALE].
const FULL_SCALE: float = 32767.0


## How long the loop is, in seconds — [constant BARS] bars at [constant BPM].
static func seconds() -> float:
	return float(STEPS) * step_seconds()


## How long one sixteenth is, in seconds.
static func step_seconds() -> float:
	return 60.0 / BPM / float(STEPS_PER_BEAT)


## The theme, ready to hand to an [AudioStreamPlayer].
##
## Deterministic: the same samples on every call, on every machine, in every
## run — [Timbre]'s noise is seeded rather than random and everything else here
## is arithmetic. [code]tests/unit/test_fanfare.gd[/code] asserts that, because a
## theme that differed between builds could not be reviewed by listening to it
## once.
##
## Built fresh on every call rather than cached, for the reason
## [method Bell.voice] gives: an [AudioStreamWAV] handed to a player is mutable,
## and the caller that wants one kept is [Bandstand], which keeps it for the life
## of the game and knows it.
static func theme() -> AudioStreamWAV:
	var count: int = _at(STEPS)
	var mix: PackedFloat32Array = PackedFloat32Array()
	mix.resize(count)
	var cache: Dictionary[String, PackedFloat32Array] = {}
	_lay_melody(mix, cache)
	_lay_horns(mix, cache)
	_lay_bass(mix, cache)
	_lay_drums(mix, cache)
	return _encode(mix)


## The frame [param step] starts on.
##
## Rounded from the start of the piece every time rather than accumulated — the
## class docs have why, and it is the difference between a tight arrangement and
## one that sags by the last bar.
static func _at(step: int) -> int:
	return roundi(float(step) * step_seconds() * float(Timbre.MIX_RATE))


## The tune.
static func _lay_melody(
	mix: PackedFloat32Array, cache: Dictionary[String, PackedFloat32Array]
) -> void:
	for row: Vector3i in MELODY:
		_place(
			mix,
			_voice(cache, Timbre.Voice.BRASS, row[NOTE], row[LENGTH]),
			_at(row[STEP]),
			BRASS_LEVEL
		)


## The section under it: three chord tones together on the offbeat, every bar,
## and twice as often once the second half starts.
static func _lay_horns(
	mix: PackedFloat32Array, cache: Dictionary[String, PackedFloat32Array]
) -> void:
	for bar: int in BARS:
		var steps: PackedInt32Array = HORN_STEPS_LATE if bar >= LIFT_BAR else HORN_STEPS_EARLY
		for step: int in steps:
			for tone: int in 3:
				_place(
					mix,
					_voice(cache, Timbre.Voice.HORN, CHORD_TONES[bar][tone], STAB_STEPS),
					_at(bar * STEPS_PER_BAR + step),
					HORN_LEVEL
				)


## Eighth notes on the root, all the way through, with the last two of the bars
## in [constant BASS_LIFT_BARS] an octave up.
static func _lay_bass(
	mix: PackedFloat32Array, cache: Dictionary[String, PackedFloat32Array]
) -> void:
	for bar: int in BARS:
		for step: int in range(0, STEPS_PER_BAR, BASS_STEPS):
			var midi: int = ROOTS[bar]
			if step >= STEPS_PER_BAR - 4 and BASS_LIFT_BARS.has(bar):
				midi += 12
			_place(
				mix,
				_voice(cache, Timbre.Voice.BASS, midi, BASS_STEPS),
				_at(bar * STEPS_PER_BAR + step),
				BASS_LEVEL
			)


## The kit. Hats double to sixteenths from [constant LIFT_BAR], and the last bar
## takes [constant FILL_STEPS] on top of its backbeat.
##
## The three unpitched voices are asked for at MIDI 0 and ignore it — see
## [method Timbre.note] — and they are written in seconds rather than in steps
## because a drum is as long as it is regardless of the tempo it is played at.
static func _lay_drums(
	mix: PackedFloat32Array, cache: Dictionary[String, PackedFloat32Array]
) -> void:
	var hat_every: int = 1 if BARS > LIFT_BAR else 2
	for bar: int in BARS:
		var base: int = bar * STEPS_PER_BAR
		for step: int in KICK_STEPS:
			_place(mix, _drum(cache, Timbre.Voice.KICK), _at(base + step), KICK_LEVEL)
		for step: int in SNARE_STEPS:
			_place(mix, _drum(cache, Timbre.Voice.SNARE), _at(base + step), SNARE_LEVEL)
		if bar == BARS - 1:
			for step: int in FILL_STEPS:
				_place(mix, _drum(cache, Timbre.Voice.SNARE), _at(base + step), SNARE_LEVEL)
		var gap: int = hat_every if bar >= LIFT_BAR else 2
		for step: int in range(0, STEPS_PER_BAR, gap):
			_place(mix, _drum(cache, Timbre.Voice.HAT), _at(base + step), HAT_LEVEL)


## [param samples] added into [param mix] starting at frame [param at], scaled by
## [param level], wrapping round the end of the loop.
##
## The wrap is the seam: a brass note held over the last beat and the ring of the
## final snare both run past the end of bar eight, and mixing their tails onto
## the front is what makes the join inaudible. It also means a note written past
## the end of the piece is quietly wrong rather than an out-of-bounds write,
## which is the right way round for a score somebody is editing by ear.
static func _place(
	mix: PackedFloat32Array, samples: PackedFloat32Array, at: int, level: float
) -> void:
	var count: int = mix.size()
	for frame: int in samples.size():
		var index: int = (at + frame) % count
		mix[index] += samples[frame] * level


## One note of [param voice] at [param midi] lasting [param steps] sixteenths,
## rendered once and remembered in [param cache] for the rest of the build.
##
## The cache is the reason this is affordable at all. The arrangement plays
## something like three hundred notes and they are drawn from about thirty
## distinct ones — every eighth of the bass line in bar one is the same note at
## the same length, and rendering it sixty-four times would be sixty-three
## rendered for nothing.
static func _voice(
	cache: Dictionary[String, PackedFloat32Array], voice: Timbre.Voice, midi: int, steps: int
) -> PackedFloat32Array:
	var key: String = "%d:%d:%d" % [voice, midi, steps]
	if not cache.has(key):
		cache[key] = Timbre.note(voice, midi, float(steps) * step_seconds())
	return cache[key]


## One hit of an unpitched [param voice], rendered once and remembered.
##
## Its own function rather than [method _voice] with a pitch of zero because the
## length of a drum comes from [Timbre] rather than from the grid, and threading
## that through the pitched path would mean a [param steps] argument that three
## of the six voices ignore.
static func _drum(
	cache: Dictionary[String, PackedFloat32Array], voice: Timbre.Voice
) -> PackedFloat32Array:
	var key: String = "drum:%d" % voice
	if not cache.has(key):
		cache[key] = Timbre.note(voice, 0, _drum_seconds(voice))
	return cache[key]


## How long [param voice] rings, in seconds.
static func _drum_seconds(voice: Timbre.Voice) -> float:
	match voice:
		Timbre.Voice.KICK:
			return Timbre.KICK_SECONDS
		Timbre.Voice.HAT:
			return Timbre.HAT_SECONDS
		_:
			return Timbre.SNARE_GATE_SECONDS + Timbre.SNARE_GATE_RELEASE


## [param mix] as the stream a player takes: mono, 16-bit,
## [constant Timbre.MIX_RATE], looping forward over the whole buffer.
##
## Normalised by its own measured peak rather than by a level worked out on
## paper, for the reason [method Bell.strike] gives — six voices summed with
## their own phases is not a sum anybody can predict, and guessing at it is how a
## theme ships either inaudible or clipped.
##
## [b]The loop is on the resource, not on the player.[/b] Godot's web export
## plays a sample through the Web Audio API rather than through the engine's
## mixer, and in that path a loop set on the [AudioStreamPlayer] is ignored while
## a loop set here is honoured. [Bandstand] has the rest of what that path does
## and does not support.
static func _encode(mix: PackedFloat32Array) -> AudioStreamWAV:
	var peak: float = 0.0
	for value: float in mix:
		peak = maxf(peak, absf(value))
	var scale: float = 0.0 if peak <= 0.0 else LEVEL / peak
	var data: PackedByteArray = PackedByteArray()
	data.resize(mix.size() * 2)
	for frame: int in mix.size():
		data.encode_s16(frame * 2, clampi(roundi(mix[frame] * scale * FULL_SCALE), -32768, 32767))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = Timbre.MIX_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = mix.size()
	stream.data = data
	return stream
