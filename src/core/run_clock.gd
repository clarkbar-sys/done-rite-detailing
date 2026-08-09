## Five minutes on the meter: how long a run lasts, and how that reads on
## screen. Or nothing on the meter at all, which is the other game this holds —
## see [constant UNTIMED].
##
## [b]It exists because the only other end this game has is unreachable.[/b]
## Before this, a run ended when the car was finished — about a thousand patches
## on a full car, which is a board almost nobody would ever be asked to sign. A
## clock is what an arcade cabinet does with exactly that problem: it makes the
## question "how much can you get done" rather than "will you get it done", and
## it is what turns a score into something two people can compare. Finishing the
## car still ends a run early; [code]src/screens/play_screen.gd[/code] watches for
## both.
##
## [b]Five minutes, and the number was meant to be turned and has been.[/b] It
## was three, on the argument that a run should be short enough that a second go
## is cheaper than being annoyed about the first — and three turned out to be
## short enough that most of a thousand-patch car was never seen. Five is still a
## sitting a player chooses to start rather than commits an evening to, and it is
## long enough to finish a small car. Nothing derives anything from it — no
## tariff, no cap, no pace — so moving it moves only how much of the car a good
## run gets through.
##
## [b]And a clock can have no limit on it at all.[/b] [constant UNTIMED] is what
## [GameMode]'s simulation asks for: the same clock, started at the same moment
## and ticked by the same frames, that never reaches zero. It is a value rather
## than a second class or a flag on the screen because every question below
## already answers itself at infinity — [method tick] spends a delta off it and
## it stays infinite, [method is_up] is false forever, [method is_warning] never
## comes on — so the untimed game is arithmetic rather than a branch in every
## caller. The one place that cannot fall out of the arithmetic is the readout,
## and that is [constant FOREVER_SIGN].
##
## [b]The clock is started rather than running from construction.[/b] Laying the
## mud on casts tens of thousands of rays at the car and takes the longest frame
## the room will ever have — [method Garage._lay_on_the_grime] has why — and a
## clock that had been counting through it would charge the player for a load.
## So the screen starts this on [signal Grime.grimed], which is the first instant
## there is anything to clean.
##
## [b]Driven by [param delta] and not by a timestamp[/b], which is the one place
## this differs from [method Scoring.score_at] and [method Chime.ring_at]. Those
## are asked "did this happen inside the last N milliseconds", which needs a
## clock to compare against; this is a quantity being spent at the rate the frames
## arrive. Handing the deltas in is what makes a three-minute run a unit test that
## takes no time at all, and it means a hitch cannot make the clock disagree with
## the frames the player actually got.
##
## Node-free, like everything in [code]src/core/[/code]: no [SceneTree], no
## [Timer], nothing to await.
class_name RunClock
extends RefCounted

## How long a run is, in seconds.
const SECONDS: float = 300.0

## A run with no clock on it: the length [GameMode]'s simulation is built with.
##
## [b]Infinity rather than a negative number or a zero flag[/b], because it is
## the one value that makes every method on this class stay true without being
## told about it. A run of [code]INF[/code] seconds has [code]INF[/code] left
## after any number of frames, is never up, and is never nearly up — which is
## exactly what "no time limit" means, said in the units the rest of the file is
## already written in.
const UNTIMED: float = INF

## How much is left when the readout starts shouting about it. Thirty seconds is
## about one more panel — long enough that being told is still worth something,
## short enough that the warning is not on for most of the run.
const WARNING_SECONDS: float = 30.0

## No time left. Named because [method is_up] and [method tick]'s floor are the
## same zero and should be seen to be.
const UP: float = 0.0

## How many seconds in a minute, for [method spell]. Written down because the
## alternative is the number 60 appearing twice in one expression, where one of
## them is a division and the other a remainder.
const PER_MINUTE: int = 60

## What [method whole_seconds] answers for a clock with no limit on it: not a
## reading, and deliberately not a big number either. A readout compares this
## against what it last printed — see [method TimeHud.show_time] — so what it
## needs from the untimed case is a value that is stable and is not a second
## count, which negative one is and 2^63 is not.
const FOREVER: int = -1

## What [method spell] reads for that clock. [b]U+221E, and the face has it[/b] —
## [constant Brand.DISPLAY_FACE] is a 656-glyph face and
## [code]tests/integration/test_time_hud.gd[/code] asks it rather than assuming,
## because a missing glyph is a tofu box in a released build rather than an error
## anybody would see.
const FOREVER_SIGN: String = "∞"

var _left: float = SECONDS
var _running: bool = false


## A clock of [param seconds], stopped.
##
## The length is an argument rather than [constant SECONDS] read directly so a
## test can run a whole run out in one call, and so
## [code]src/screens/play_screen.gd[/code] can expose it as the export a suite
## pins — the same seam [code]src/screens/job_done.gd[/code] gives its save path.
## What the game itself passes is whatever [method GameMode.seconds_for] says the
## mode is worth, which is this default or [constant UNTIMED].
func _init(seconds: float = SECONDS) -> void:
	_left = maxf(seconds, UP)


## Starts it counting. Idempotent: starting a clock that is already running is
## what a second [signal Grime.grimed] would do, and it should not put the time
## back.
func start() -> void:
	_running = true


## Spends [param delta] seconds of it, if it has been started.
##
## Floored at [constant UP] rather than allowed to go negative, so
## [method left] is always a time a readout can print and [method spell] never
## has to know about the sign.
func tick(delta: float) -> void:
	if not _running:
		return
	_left = maxf(_left - delta, UP)


## How much is left, in seconds.
func left() -> float:
	return _left


## Whether the clock has been started.
func is_running() -> bool:
	return _running


## Whether the run is over.
##
## True of a stopped clock that was constructed with nothing on it, which is
## honest — a run of no seconds is over before it starts — and unreachable in the
## game, where the length is [constant SECONDS] or [constant UNTIMED].
func is_up() -> bool:
	return _left <= UP


## Whether there is a limit on this clock at all.
##
## Asked against [constant UNTIMED] rather than with [method @GlobalScope.is_inf],
## because what the caller wants to know is whether this is the clock that
## constant describes — and an equality against the named value says that where a
## test for infinity says only how it is spelled. [b][code]INF != INF[/code] is
## false and every finite value differs from it[/b], so the arithmetic is exact
## either way; this is the version that names the reason.
func is_timed() -> bool:
	return _left != UNTIMED


## Whether the readout should be shouting: [constant WARNING_SECONDS] or less
## left.
##
## Asked of the clock rather than worked out by [TimeHud], so "nearly out of
## time" has one definition and the day something else wants to know — the music,
## the bell, a light in the garage — it asks the same question rather than
## inventing a second threshold.
func is_warning() -> bool:
	return _left <= WARNING_SECONDS


## [param seconds] as the whole number a readout prints, or [constant FOREVER]
## for a run with no clock on it.
##
## [b]Rounded up, and that is the arcade convention rather than a preference.[/b]
## A clock counting down shows the time you have [i]left[/i], so it should read
## 5:00 for the whole of the first second and reach 0:00 exactly when there is
## nothing left — not a second early, which is what flooring gives and which
## makes the last second of the run one the player watched expire twice.
##
## The untimed case is caught here rather than at the readout because
## [code]ceili(INF)[/code] is a number nobody wrote down and everybody would then
## have to handle. One branch, at the boundary, and everything downstream is an
## [int] again.
static func whole_seconds(seconds: float) -> int:
	if seconds == UNTIMED:
		return FOREVER
	return ceili(maxf(seconds, UP))


## [param seconds] as [code]M:SS[/code], or [constant FOREVER_SIGN] for a run
## with no clock on it.
##
## Zero-padded on the seconds and not on the minutes, which is what a cabinet
## did and is also the only version that does not shuffle: the minutes are one
## digit for any run this length, and the seconds are always two.
##
## [b]The untimed reading is here and not in [TimeHud][/b], for the reason the
## rest of this file gives about [method is_warning]: what a clock reads is one
## question with one answer, and a readout that spelled its own special case
## would be the second place that has to be told the game grew a mode.
static func spell(seconds: float) -> String:
	var whole: int = whole_seconds(seconds)
	if whole == FOREVER:
		return FOREVER_SIGN
	return "%d:%02d" % [whole / PER_MINUTE, whole % PER_MINUTE]
