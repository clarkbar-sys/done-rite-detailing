## Three minutes on the meter: how long a run lasts, and how that reads on
## screen.
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
## [b]Three minutes, and the number is meant to be turned.[/b] It is long enough
## to walk the car, pick a tool and get a run of patches going, and short enough
## that a second go is cheaper than being annoyed about the first. Nothing derives
## anything from it — no tariff, no cap, no pace — so moving it moves only how
## much of the car a good run gets through.
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
const SECONDS: float = 180.0

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

var _left: float = SECONDS
var _running: bool = false


## A clock of [param seconds], stopped.
##
## The length is an argument rather than [constant SECONDS] read directly so a
## test can run a whole run out in one call, and so
## [code]src/screens/play_screen.gd[/code] can expose it as the export a suite
## pins — the same seam [code]src/screens/job_done.gd[/code] gives its save path.
## Nothing in the game passes anything but the default.
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
## game, where the length is [constant SECONDS].
func is_up() -> bool:
	return _left <= UP


## Whether the readout should be shouting: [constant WARNING_SECONDS] or less
## left.
##
## Asked of the clock rather than worked out by [TimeHud], so "nearly out of
## time" has one definition and the day something else wants to know — the music,
## the bell, a light in the garage — it asks the same question rather than
## inventing a second threshold.
func is_warning() -> bool:
	return _left <= WARNING_SECONDS


## [param seconds] as the whole number a readout prints.
##
## [b]Rounded up, and that is the arcade convention rather than a preference.[/b]
## A clock counting down shows the time you have [i]left[/i], so it should read
## 3:00 for the whole of the first second and reach 0:00 exactly when there is
## nothing left — not a second early, which is what flooring gives and which
## makes the last second of the run one the player watched expire twice.
static func whole_seconds(seconds: float) -> int:
	return ceili(maxf(seconds, UP))


## [param seconds] as [code]M:SS[/code].
##
## Zero-padded on the seconds and not on the minutes, which is what a cabinet
## did and is also the only version that does not shuffle: the minutes are one
## digit for any run this length, and the seconds are always two.
static func spell(seconds: float) -> String:
	var whole: int = whole_seconds(seconds)
	return "%d:%02d" % [whole / PER_MINUTE, whole % PER_MINUTE]
