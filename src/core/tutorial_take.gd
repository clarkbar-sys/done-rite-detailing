## One short film of one step of the job: which surface is being worked, which
## passes go over it, how long each of them lasts, and when the camera stops
## rolling.
##
## [b]It is [AttractRoutine] with the lap taken off.[/b] The attract mode is the
## game playing itself round a whole car for two minutes; a take is the same thing
## pointed at one panel for a few seconds so somebody who has never played can be
## shown what a sponge does. Everything that decides what a person would do next is
## shared with it outright — [method AttractRoutine.tool_for] picks the tool up and
## [method AttractRoutine.sweep_over] moves the hand — and what is added here is
## only the shape of a take: a subject, a lead-in, and an end.
##
## [b]There is no demo branch downstream of this either.[/b] What comes out is the
## same three answers the attract mode produces — a tool to hold, a point to aim
## at, a trigger to hold down — and [code]src/screens/tutorial_take_screen.gd[/code]
## hands them to the room through [method Garage.press_the_glass] and the
## [ToolBelt], the doors a thumb uses. So a take cannot film a wash the game would
## not have given, which is the entire reason the footage is worth putting in front
## of a player at all.
##
## [b]The lead-in is the interesting part.[/b] A take of the sponge cannot open on
## a muddy panel, because a sponge on mud moves nothing — [GrimeMap]'s buckets
## refuse it, and refusing is the thing the game is right about. So a take is
## always the passes [i]up to and including[/i] its subject, and the ones before it
## run short: [constant LEAD_SECONDS] of water to get to bare paint, then
## [constant BEAT_SECONDS] of the pass the film is actually about. The subject is
## the longest thing on screen and the last, which is how a viewer knows which of
## them they were meant to be watching.
##
## That the passes run in the order [enum GrimeMap.Stage] declares them is not a
## coincidence this class leans on lightly — it is the order the buckets force, so
## the enum's own values are the running order and the number of beats in a take is
## its subject plus one.
##
## [b]Time is the only input, and a take ends on it.[/b] Same argument
## [AttractRoutine] makes and a sharper edge on it: a clip whose length depended on
## how much mud the sweep happened to catch would be a clip of unpredictable length,
## and the thing on the other end of this is a capture harness that has to know how
## long to record for. A take that leaves a streak behind leaves a streak behind.
##
## [b]The catalogue, and the one beat the game does not have.[/b] The tutorial beats
## asked for in [code]#221[/code] are spray, sponge/cleaner, rinse and rag/buff.
## Three of those are the game's three passes and are here as [constant WATER],
## [constant SPONGE] and [constant RAG]. A rinse is not one of them: the mask has
## three buckets and water only ever moves mud, so a second water pass over a foamed
## panel moves nothing at all and would film six seconds of a wand pointed at a
## panel that does not change. What stands in its place is [constant GLASS] — the
## blue bottle on the windows, which is the beat the How to Play strip already
## spells out ("cleaner on glass") and the one that shows the belt mattering.
##
## Node-free (STANDARDS.md "Coverage" R3), so a take is a [code]for[/code] loop over
## ticks in a unit test rather than a video somebody watched.
class_name TutorialTake
extends RefCounted

## The water taking mud off paint — the first pass, and the only one that needs no
## lead-in because mud is what a panel starts as.
const WATER: String = "water"

## The sponge laying suds on the paint the water left.
const SPONGE: String = "sponge"

## The blue bottle on the windows. See the class docs for why this is the fourth
## single-beat take rather than a rinse.
const GLASS: String = "glass"

## The rag buffing product out into a shine — the pass with the longest lead-in,
## because it is the one that needs both of the others to have happened.
const RAG: String = "rag"

## All three passes over one panel at full length: the whole job, on the smallest
## thing it can be shown on.
const FULL: String = "full"

## What names a take on the command line: [code]--take=sponge[/code], after the
## [code]--[/code] that hands the rest of the line to the game.
##
## [method OS.get_cmdline_user_args] and not a scene of its own, for the reason
## [code]scripts/pck-top-ten.gd[/code] takes its pack the same way: the harness
## invoking this is a shell line, and a shell line that names a scene has to know
## where the scene lives.
const ARG: String = "--take="

## How long a pass that is only there to make the next one possible lasts, in
## seconds. Long enough to see the water take the mud off a strip of the panel,
## short enough that nobody watching a sponge clip thinks they are watching a wash
## clip.
const LEAD_SECONDS: float = 3.0

## How long the pass the take is about lasts. Six, against the attract mode's four:
## this footage is watched rather than glanced at, and the sweep crosses the panel
## [constant AttractRoutine.CROSSINGS] times whatever the length, so a longer beat
## is a slower hand rather than more of them.
const BEAT_SECONDS: float = 6.0

## How long the shot holds after the last pass runs out, with the trigger off, in
## seconds.
##
## [b]The tail, and it is for the cut rather than for the game.[/b] A clip that
## ends on the frame the trigger releases ends mid-spray, with the water still in
## the air and the panel half hidden behind it. A second and a half of the finished
## panel with nothing in front of it is what the last frame of a tutorial clip
## should be, and it costs a second and a half.
const HOLD_SECONDS: float = 1.5

## Which of the ten cars every take is filmed on.
##
## Pinned, because "the same commit always produces the same footage" is the whole
## point and [method MeshCar.style] draws from ten when nobody has chosen. The
## sedan for [code]#142[/code]'s reason — it is the car this game has been looked
## at on more than any other — and it is set through [method CarChoice.choose] by
## [code]src/main/main.gd[/code], which is the door the menu already uses rather
## than a second way of pinning a car.
const CAR_STYLE: String = "sedan"

var _id: String = ""
var _kind: Surface.Kind = Surface.Kind.BODY
var _subject: GrimeMap.Stage = GrimeMap.Stage.WASHED
var _lead: float = LEAD_SECONDS
var _beat: float = BEAT_SECONDS
var _elapsed: float = 0.0


## Built with a name to be asked for by, the surface it is filmed on, the pass it
## is about, and how long each half of it runs.
##
## No defaults, for [AttractRoutine]'s reason: the numbers belong to
## [method named], where the whole catalogue can be read at once, and a second
## answer here would drift from it. Both lengths are floored at
## [constant AttractRoutine.MIN_SECONDS] — the same fence and for a related reason:
## a beat of no length is not a very fast film, it is a take whose every frame is
## the last one.
func _init(
	take_id: String,
	filmed_on: Surface.Kind,
	subject_stage: GrimeMap.Stage,
	lead_seconds: float,
	beat_seconds: float
) -> void:
	_id = take_id
	_kind = filmed_on
	_subject = subject_stage
	_lead = maxf(lead_seconds, AttractRoutine.MIN_SECONDS)
	_beat = maxf(beat_seconds, AttractRoutine.MIN_SECONDS)


## Every take there is, in the order a person should be shown them.
##
## A [PackedStringArray] rather than a list of the constants above written out at
## each caller: the harness prints it when it is asked for a take that does not
## exist, and [code]src/main/main.gd[/code] has nothing else to say to somebody who
## typed the name wrong.
static func catalogue() -> PackedStringArray:
	return PackedStringArray([WATER, SPONGE, GLASS, RAG, FULL])


## The take called [param take_id], or [code]null[/code] for a name nobody has
## filmed.
##
## [b]The whole catalogue is these five lines[/b], which is the point of building
## takes here rather than in the screen that plays them: what a take is worth
## reading is the table, and a table spread across a scene file and a script is not
## one.
##
## Null rather than a fallback take, because the caller is a command line and the
## honest answer to a misspelled name is to say so. [code]src/main/main.gd[/code]
## is where that gets said.
static func named(take_id: String) -> TutorialTake:
	match take_id:
		WATER:
			return TutorialTake.new(
				WATER, Surface.Kind.BODY, GrimeMap.Stage.WASHED, LEAD_SECONDS, BEAT_SECONDS
			)
		SPONGE:
			return TutorialTake.new(
				SPONGE, Surface.Kind.BODY, GrimeMap.Stage.FOAMED, LEAD_SECONDS, BEAT_SECONDS
			)
		GLASS:
			return TutorialTake.new(
				GLASS, Surface.Kind.GLASS, GrimeMap.Stage.FOAMED, LEAD_SECONDS, BEAT_SECONDS
			)
		RAG:
			return TutorialTake.new(
				RAG, Surface.Kind.BODY, GrimeMap.Stage.BUFFED, LEAD_SECONDS, BEAT_SECONDS
			)
		FULL:
			return TutorialTake.new(
				FULL, Surface.Kind.BODY, GrimeMap.Stage.BUFFED, BEAT_SECONDS, BEAT_SECONDS
			)
	return null


## The take named in [param args] — what came after [code]--take=[/code] — or
## [code]""[/code] when nobody asked for one.
##
## [b]A seam and not a stub[/b] (the [method BuildInfo.parse_stamp] pattern): the
## reading of [method OS.get_cmdline_user_args] stays at the two call sites that
## have a process to ask, and the deciding is here where a unit test can hand it a
## line. Whatever follows the prefix comes back unchecked, including a name no take
## has — telling the difference is [method named]'s job and complaining about it is
## the caller's.
##
## The first one wins. A line with two of them is a mistake either way, and picking
## the first is the answer that does not depend on how the harness happened to
## build its arguments.
static func asked_for(args: PackedStringArray) -> String:
	for arg: String in args:
		if arg.begins_with(ARG):
			return arg.trim_prefix(ARG)
	return ""


## What this take is called — the name it was asked for by.
func id() -> String:
	return _id


## What it is filmed on, which is what decides both the panel the screen picks and
## the bottle the middle pass reaches for.
func kind() -> Surface.Kind:
	return _kind


## The pass this take is about: the last one it plays and the long one.
func subject() -> GrimeMap.Stage:
	return _subject


## How many passes it plays — the subject's own place in the running order, plus
## itself. See the class docs on why [enum GrimeMap.Stage] can be counted like
## this.
func beats() -> int:
	return int(_subject) + 1


## How long beat [param at] runs, in seconds: the short lead-in for everything
## before the subject, the full length for the subject itself.
func seconds_of(at: int) -> float:
	return _beat if at >= beats() - 1 else _lead


## How long the whole take runs, including the tail it holds on the finished panel.
##
## The number a capture harness records for, and the reason it is arithmetic rather
## than something to be watched for: it is known before a single frame has been
## drawn.
func seconds() -> float:
	return float(beats() - 1) * _lead + _beat + HOLD_SECONDS


## Moves the take [param delta] seconds on.
##
## No loop over whole beats, unlike [method AttractRoutine.advance]: nothing here
## steps on a boundary, every answer below is worked out from the clock, so a frame
## long enough to cover two beats lands in the right one by arithmetic rather than
## by being counted through. Time that ran backwards is ignored for that class's
## reason — it is not a thing the engine hands out and not a thing to rewind a film
## for.
func advance(delta: float) -> void:
	_elapsed += maxf(delta, 0.0)


## How far into the take the clock is, in seconds.
func elapsed() -> float:
	return _elapsed


## Whether the take has run out — which is the only way it ends. See the class docs
## on why this asks the clock and not the paint.
func finished() -> bool:
	return _elapsed >= seconds()


## Which beat is on screen, as an index into the passes this take plays.
##
## Clamped to the last one, which is what makes the tail a held shot of the subject
## rather than an index past the end of the film.
func beat() -> int:
	return mini(int(_elapsed / _lead), beats() - 1)


## Which pass that beat is.
##
## The index [i]is[/i] the stage, for the reason the class docs give, and it is
## still spelled out arm by arm rather than cast — [method AttractRoutine.stage]
## does the same, and this project's warning levels make an int handed back as an
## enum an error rather than a shortcut.
func stage() -> GrimeMap.Stage:
	match beat():
		0:
			return GrimeMap.Stage.WASHED
		1:
			return GrimeMap.Stage.FOAMED
	return GrimeMap.Stage.BUFFED


## What the take is holding: water, the bottle for its surface, or the rag.
func tool() -> DetailingTool.Id:
	return AttractRoutine.tool_for(stage(), _kind)


## Whether the trigger is down.
##
## Off for the tail alone, and that is the whole of it: a take works right up to the
## moment it stops working, and then shows what it did. See
## [constant HOLD_SECONDS].
func working() -> bool:
	return _elapsed < seconds() - HOLD_SECONDS


## How far through the current beat the clock is, as [code]0..1[/code] — and
## [code]1[/code] for the whole of the tail, where the hand has finished its sweep
## and is holding still at the bottom of the panel.
func progress() -> float:
	var at: int = beat()
	return clampf((_elapsed - float(at) * _lead) / seconds_of(at), 0.0, 1.0)


## Where on [param box] the tool is pointed this instant — [method
## AttractRoutine.sweep_over], which is the demo's own hand and deliberately not a
## second one. Everything that method's docs say about an aim not being a landing
## point holds here word for word.
func aim_over(box: AABB) -> Vector3:
	return AttractRoutine.sweep_over(box, progress())
