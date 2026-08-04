## The running score: what one patch of the car is worth, how a run of them
## multiplies, and the total those two add up to.
##
## [b]Two things pay, and the split is the point.[/b] Work pays as it happens —
## every unit of mud that actually comes off is worth something the instant it
## does, so the corner climbs while the trigger is held rather than sitting still
## between patches. And finishing a patch pays a bonus on top, with the run
## multiplier on it, on exactly the event the bell rings for. The wage and the
## tip: one is for the cleaning and one is for the moment it lands.
##
## The alternative — paying only on [signal Grime.patch_finished] — is what this
## started as, and the thing wrong with it is not the arithmetic. A patch is a
## few hundred texels and a couple of seconds of held jet, so the score stepped
## in silence and then jumped, and the player washing a panel could not see the
## number answering the thing their hands were doing. Paying for the work is what
## makes the readout continuous, and it costs nothing to be honest about because
## the units were already being counted: [GrimeMap] has tracked what every touch
## moved since the day the ding needed it.
##
## [b]A patch's worth of work pays a patch's worth of points.[/b] Work arrives
## here already measured in patches rather than in texels — [method GrimeMap.worked]
## has why — so one full pass over one patch trickles exactly
## [method points_for] and needs no second tariff to keep in step with the first.
## A patch cleaned from filthy to finished therefore pays its face value twice
## over: once for the doing and once for the landing. That is deliberate and it
## is why nothing downstream divides by a total.
##
## [b]The bonus rides the same event the bell and the flash do[/b] —
## [signal Grime.patch_finished], which [GrimeMap] emits on exactly the
## transition worth celebrating and nothing else. That is deliberate: there is no
## second definition of "the player finished something", so there is nothing here
## that can disagree with what the player just heard and saw.
##
## [b]There is no target, no percentage and no "score out of".[/b] An arcade
## score counts up and stops being interesting only when the player does, and
## that is the right shape for this game for a reason beyond taste: the car has
## corners a tool cannot currently reach, so any denominator — patches on the
## car, texels of mud, panels finished — would be a completion figure the player
## can never close, printed on screen, all game. A running total is honest about
## a job that is not finishable yet and needs no revisiting on the day it is.
##
## [b]A buff is worth more than a foam is worth more than a wash[/b], and the
## ordering is the game's rules rather than a preference. [GrimeMap]'s
## conservation arithmetic makes the three passes strictly sequential — you
## cannot foam over mud and you cannot shine what you never foamed — so a patch
## that has been buffed is a patch somebody washed and foamed first. Paying the
## last pass the most is paying for the ground it stands on. The particular
## numbers are taste and are meant to be turned; the order they go in is not.
##
## [b]Round hundreds rather than ones.[/b] A score reading 7 after a minute of
## work is a counter; the same work reading 4,850 is a score, and the difference
## is entirely that the digits move. Nothing downstream divides by these, so the
## units cost nothing and buy the thing the feature is for.
##
## [b]The run multiplier is the bell's run.[/b] [Chime] already steps
## [constant Bell.PATCH_RUN_RATIOS] while the player is on a streak of
## consecutive patches, so the ding climbs a triad up to the octave and then
## holds. This climbs the same streak on the same clock and with the same
## [constant Bell.RUN_RESET_MSEC] gap that ends it — so the note going up and the
## multiplier going up are one event with two outputs, and a player who can hear
## the top of the ladder is looking at the top of the multiplier. That shared
## constant lives on [Bell] rather than here or on [Chime] precisely so there is
## one of it; see its docs.
##
## The cap is [method Array.size] of that same ladder rather than a number
## written here again, for the same reason. [Bell]'s docs have the argument for
## why the ladder is capped at all — an unbounded climb leaves the audible range
## — and a multiplier that kept going after the pitch stopped would be a reward
## the player can no longer hear themselves earning.
##
## [b]The clock is handed in.[/b] [method score_at] takes the time the way
## [method Chime.ring_at] does, and [method score] is the one-line wrapper that
## reads the engine's. That is what lets a run be tested by walking timestamps
## rather than by a suite that waits in real seconds, and it is why this file is
## in [code]src/core/[/code] at all: no [SceneTree], no [Node], nothing to await.
class_name Scoring
extends RefCounted

## What a patch coming clean under the power wash pays.
const WASH_POINTS: int = 100

## What a patch coming up to product pays. Above a wash because it is the pass
## that cannot happen until the wash has.
const FOAM_POINTS: int = 150

## What a patch coming up to shine pays — the end of the job for that square, and
## the only one of the three the player can see from across the driveway.
const BUFF_POINTS: int = 250

## The most the run can multiply an award by: the length of the pitch ladder the
## ding climbs, so the two top out on the same patch. See the class docs.
const MAX_MULTIPLIER: int = 4

## Nothing has been scored yet, as a run length. The first patch of a run reads 1
## — the same convention [method Chime.patch_run] uses, and for the same reason:
## a run of one is a thing that happened, and a multiplier of zero would wipe it
## out.
const NO_RUN: int = 0

var _total: int = 0
var _patches: int = 0
var _run: int = NO_RUN
var _last_award: int = 0
var _last_msec: int = 0
var _started: bool = false

## Every point work has ever earned, fractions included, and how many of them
## have actually been put on the board. See [method work] — the pair is what
## makes a trickle add up to what it should.
var _earned: float = 0.0
var _wages: int = 0


## What one patch finishing [param stage] pays before the run is applied.
##
## Anything that is not one of the three stages pays a wash, which is the
## defaulting [method Surface.cleaner_for] does and is right for the same reason:
## the first pass is what a patch is doing when nobody has said otherwise. The
## enum has exactly three entries today and this branch is unreachable — it is
## here so that adding a fourth is a scoring decision somebody makes on purpose
## rather than a patch that silently pays nothing.
static func points_for(stage: GrimeMap.Stage) -> int:
	match stage:
		GrimeMap.Stage.FOAMED:
			return FOAM_POINTS
		GrimeMap.Stage.BUFFED:
			return BUFF_POINTS
	return WASH_POINTS


## What a run [param length] consecutive patches long multiplies an award by.
##
## The parameter is not called `run` because [method run] is, and GDScript treats
## a parameter shadowing a method in the same class as an error here — worth
## knowing before renaming it back.
##
## Clamped at both ends rather than only at the top. The floor matters because a
## run of zero is what [constant NO_RUN] means and multiplying by it would pay
## nothing for the patch that started the run; the ceiling is
## [constant MAX_MULTIPLIER] for the reason the class docs give.
static func multiplier_for(length: int) -> int:
	return clampi(length, 1, MAX_MULTIPLIER)


## Scores one patch finishing [param stage] as at [param now_msec], and returns
## what it paid.
##
## The run is stepped first, so the patch that starts a run is already on a
## multiplier of one rather than of nothing. A gap of [constant
## Bell.RUN_RESET_MSEC] or more since the last patch drops it back to the bottom
## — the same rule [Chime] applies to the pitch, on the same constant.
##
## [b]The first patch of the game is not a continuation of a run that never
## happened.[/b] Without [member _started] the initial [member _last_msec] of
## zero would put the opening patch of a game booted more than a second and a
## half ago — which is every game — inside or outside the reset depending on
## nothing but how long the loading screen took. It reads as the start of a run
## because it is one.
func score_at(stage: GrimeMap.Stage, now_msec: int) -> int:
	if not _started or now_msec - _last_msec >= Bell.RUN_RESET_MSEC:
		_run = NO_RUN
	_started = true
	_last_msec = now_msec
	_run += 1
	_last_award = points_for(stage) * multiplier_for(_run)
	_total += _last_award
	_patches += 1
	return _last_award


## Scores one patch finishing [param stage] now, and returns what it paid.
##
## The engine's clock, so this is what the game calls. [method score_at] is the
## same thing with the time handed in, which is how the run is tested without a
## suite that has to wait in real seconds — the split [method Chime.ring] and
## [method Chime.ring_at] already make, for the same reason.
func score(stage: GrimeMap.Stage) -> int:
	return score_at(stage, Time.get_ticks_msec())


## Pays for [param done] patches' worth of work in [param stage], and returns the
## whole points that put on the board.
##
## The parameter is not called `patches` because [method patches] is, and
## GDScript treats a parameter shadowing a method in the same class as an error
## here — the same footnote [method multiplier_for] carries.
##
## [b]The fraction is kept rather than rounded away, and that is the whole
## mechanism.[/b] A frame of held jet moves a small fraction of a patch, which is
## a fraction of a point — round each frame and a trickle of a third of a point
## sixty times a second pays nothing at all, for ever. So the fractions run into
## [member _earned] and this hands over whatever of it is not on the board yet.
##
## [b]The running total is rounded, not the increment, and the difference is a
## point per patch.[/b] The obvious version banks a remainder and pays out whole
## points as it crosses them, and it is wrong in a way that only shows up in
## aggregate: a thousand additions of a thousandth land a hair under one in any
## binary float, so the last point of every patch never arrives and the player is
## permanently short by one per patch. Measured, not reasoned about — the first
## version of this shipped into a test that walked a patch in a thousand slices
## and read 99. Rounding [member _earned] instead is self-correcting: the error
## is against the total rather than carried forward, so it can never accumulate,
## and a patch's worth of work pays a patch's worth of points however finely it
## was sliced. That is the same lesson [GrimeMap]'s class docs record about float
## totals, arrived at from the other direction.
##
## The consequence is that the player is paid exactly [method points_for] per
## patch of work no matter what the frame rate was while they did it, which is
## the property a score that moved with the frame rate would not have.
##
## [b]No run multiplier on this half.[/b] A run is a streak of patches
## [i]finished[/i] — moments, countable, and audible as the ding climbing. Work
## is continuous and has no moments in it, so there is nothing here for a streak
## to be a streak of; multiplying it would just be paying the same wage at a
## different rate and would make the number on screen impossible to reconcile
## with the one the player can hear. The streak belongs to the bonus, where the
## events are.
##
## Negative or zero [param done] pays nothing rather than taking points back.
## Work only goes forwards — [method GrimeMap.worked] refuses to count a rinse as
## progress — so a caller handing this a fall has misread a total, and a score
## that could go down on a misread would be a bug nobody would look for here.
func work(stage: GrimeMap.Stage, done: float) -> int:
	if done <= 0.0:
		return 0
	_earned += float(points_for(stage)) * done
	var paid: int = roundi(_earned) - _wages
	if paid <= 0:
		return 0
	_wages += paid
	_total += paid
	return paid


## The running total.
func total() -> int:
	return _total


## How many patches have been scored, whatever they paid. The honest answer to
## "how much of the car has the player actually finished a pass over", and not
## derivable from the total — three washes and one buff pay differently every
## time the multiplier moves.
func patches() -> int:
	return _patches


## How long the current run is, counting the patch that just scored — so the
## first patch of a run reads 1 and a game nothing has happened in reads
## [constant NO_RUN].
func run() -> int:
	return _run


## What the current run is multiplying awards by right now.
func multiplier() -> int:
	return multiplier_for(_run)


## What the last patch paid, run included. Zero before anything has scored.
func last_award() -> int:
	return _last_award
