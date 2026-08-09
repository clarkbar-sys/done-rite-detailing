## What the run that just ended was worth, waiting for the screen that reports
## it.
##
## [b]It exists because a screen is freed the instant it hands over.[/b]
## [code]src/main/main.gd[/code] removes and frees the outgoing screen inside
## [signal GameScreen.transition_requested], so the play screen's [Scoring] is
## gone before [code]src/screens/job_done.tscn[/code] has been instanced. A
## [GameState] is plain data with an id and a scene path and carries nothing —
## deliberately, see that class — so the number has to be put somewhere that
## outlives both of them.
##
## [b]Static fields, for [CarChoice]'s reasons word for word.[/b] Process-wide,
## nothing left in the tree to free, and reachable from
## [code]godot --check-only[/code] because it is a global class name rather than
## an autoload. This is the second thing in the game that has to survive a screen
## swap and it is stored the same way the first one is.
##
## [b]What it is not is a second scorer.[/b] [Scoring] owns the arithmetic and
## this owns three integers it was handed after the arithmetic stopped. Nothing
## here adds anything up, and nothing here is read while a run is in progress.
class_name RunResult
extends RefCounted

## Which of the ten was being cleaned, as a [constant MeshCar.STYLES] name — the
## key the board is kept under. [code]""[/code] when no run has been handed in.
static var style: String = ""

## What [method Scoring.total] read when the job was done.
static var score: int = 0

## How many patches [method Scoring.patches] had counted. Not on the board and
## not shown yet; recorded because it is the one number that says how much of the
## score was work rather than luck with the multiplier, and it is free to keep.
static var patches: int = 0


## Writes down a finished run on [param car] worth [param total], over
## [param done] patches.
##
## A function rather than three assignments at the call site for
## [method CarChoice.choose]'s reason: what "the run ended" means is allowed to
## grow — a duration, a per-stage breakdown — and the one caller is already
## calling this.
static func remember(car: String, total: int, done: int) -> void:
	style = car
	score = total
	patches = done


## Whether there is a run to report.
##
## False is a real state and not an error: [code]src/screens/job_done.tscn[/code]
## instanced on its own — by a test, or by anybody opening it in the editor — has
## no run behind it, and the honest answer there is a board with nothing new on
## it rather than a crash.
static func handed_in() -> bool:
	return not style.is_empty()


## Puts it back to "no run has ended", which is where the game starts.
##
## Here for the suites, exactly as [method CarChoice.forget] is: the fields are
## process-wide by design, so a test that sets one and leaves it would hand it to
## whichever suite runs next.
static func forget() -> void:
	style = ""
	score = 0
	patches = 0
