## Which of the two games this is: the arcade run against a clock, or the
## simulation with nothing on the meter.
##
## [b]It exists because the clock was never the game — it was the arcade half of
## it.[/b] [RunClock] makes the question "how much can you get done", which is
## what a score two players can compare needs. It also makes a car with about a
## thousand patches on it into a car nobody ever finishes, and finishing one is
## the other thing this game is: seven panels taken from mud to shine, in the
## order the arithmetic in [GrimeMap] asks for, with nothing counting down at the
## player while they learn what a rag actually does. So the menu offers both and
## this is what it offers.
##
## [b]A static class rather than an autoload[/b], for [CarChoice]'s reasons word
## for word: [code]godot --check-only[/code] — what [code]make check[/code] gates
## on — resolves global class names but not autoload names, so a call routed
## through an autoload would silently drop out of the type check. And every
## screen is freed the moment the player leaves it (see
## [code]src/main/main.gd[/code]), so a choice made on the menu has to survive a
## screen swap with nothing left behind to free. This is the third thing in the
## game stored that way and it is stored the same way as the first two.
##
## [b]What a mode actually [i]is[/i] is one number.[/b] The whole difference
## between the two games is what [method seconds_for] hands the clock, and
## everything else falls out of it: [method RunClock.is_up] never fires at
## [constant RunClock.UNTIMED], so the run ends the way an untimed run should —
## when the car is finished, or when the player says so. There is no second
## rule-set, no branch in the tools, and no simulation-only code path in the
## room. The two places that do have to know are the readout, which cannot spell
## infinity as [code]M:SS[/code], and the board, which cannot rank a run that had
## all the time it wanted — [code]src/screens/job_done.gd[/code] has that
## argument.
##
## Node-free, like everything in [code]src/core/[/code].
class_name GameMode
extends RefCounted

## The two games. [constant Kind.ARCADE] first so it is the zero value: a game
## nobody has chosen a mode in is the game this one has always been.
enum Kind { ARCADE, SIMULATION }

## The mode the player asked for on the menu.
##
## Defaults to [constant Kind.ARCADE] rather than to an "unset" third value,
## because there is nothing an unset mode could usefully do differently — the
## title card and the rules screen both lead into a run, and the run they have
## always led into is the timed one.
static var chosen: Kind = Kind.ARCADE


## Remembers [param kind] as the game the player wants.
##
## A function and not a bare assignment at the call site for
## [method CarChoice.choose]'s reason: what "choose" means is allowed to grow —
## the obvious next thing being writing it somewhere that survives closing the
## tab — and the one screen that sets it is already calling this.
static func choose(kind: Kind) -> void:
	chosen = kind


## Puts the choice back to the arcade, which is where the game starts.
##
## Here for the suites, exactly as [method CarChoice.forget] is: the field is
## process-wide by design, so a test that sets one and leaves it would hand it to
## whichever suite runs next.
static func forget() -> void:
	chosen = Kind.ARCADE


## How long a run in [param kind] gets, in seconds — the one fact that separates
## the two games. See [RunClock] for both values.
##
## A mode this has never been told about gets the arcade clock rather than an
## endless one, which is the safe way round: a run that ends is recoverable and a
## run that cannot be is not.
static func seconds_for(kind: Kind) -> float:
	match kind:
		Kind.SIMULATION:
			return RunClock.UNTIMED
	return RunClock.SECONDS


## Whether a run in [param kind] is played against a clock.
##
## Derived from [method seconds_for] rather than written down as a second table,
## so the day a third mode arrives there is exactly one place that decides what
## it is worth. [RunClock.is_timed] asks the same question of a clock that has
## already been built; this asks it of a mode nobody has started yet, which is
## what [code]src/screens/job_done.gd[/code] needs after the screen holding the
## clock has been freed.
static func is_timed(kind: Kind) -> bool:
	return seconds_for(kind) != RunClock.UNTIMED
