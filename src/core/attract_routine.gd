## The demo an arcade cabinet plays when nobody is holding the controls: which
## panel of the car is being worked, which of the three passes is on it, and
## where on that panel the tool is pointed this instant.
##
## [b]It is the player, not the game.[/b] Everything here decides what a person
## standing in the bay would be doing next; the room then does exactly what it
## would do for a real one — the same belt, the same aim, the same trigger, the
## same [GrimeMap] buckets. Nothing in this class writes to a mask, and there is
## no "demo" branch anywhere downstream of it. That is what makes the attract
## mode honest rather than a cutscene: it cannot show a wash the game would not
## have given the player, because it is the game giving it.
##
## [b]The running order is handed in.[/b] Which panels exist, how big they are
## and what they are made of are all the car's business ([method Car.panels],
## [method Car.kind_of]), so this takes a list of [enum Surface.Kind] already in
## the order they are to be worked and never learns what a panel is. Which is
## what keeps a full lap of a twelve-panel car a [code]for[/code] loop in a unit
## test rather than two minutes of somebody watching a title screen.
##
## [b]Three passes per panel, in the one order that works[/b]: water, then the
## bottle for that surface, then the rag. That is not a rule this class invents —
## it is the order [GrimeMap]'s buckets already force on a player, where a sponge
## on a muddy wing has no bare paint to draw from and a rag on a dry one has no
## product. The demo is doing the job the way the job has to be done, which is
## also why it is worth watching.
##
## [b]Time is the only input.[/b] A pass ends because it ran out, not because the
## panel came clean, and that is deliberate: a demo whose length depended on how
## much mud the jet happened to catch would stall on a panel the sweep grazes and
## never reach the buff — the pass a viewer most needs to see. The cost is that a
## pass sometimes leaves a streak behind, which the next lap takes off.
##
## Node-free (STANDARDS.md "Coverage" R3).
class_name AttractRoutine
extends RefCounted

## A full circuit has finished — every panel in the running order washed,
## cleaned and buffed — so whoever is showing the car off can put the mud back
## and start again. Emitted from [method advance], on the tick the last pass of
## the last panel runs out.
##
## A signal rather than a flag a caller polls, because it is true for an instant
## and a caller that missed the frame would restart the demo a lap late.
signal lapped

## How many passes each panel gets: one per member of [enum GrimeMap.Stage], and
## one per arm of [method stage].
const PASSES: int = 3

## The shortest a pass may be, in seconds.
##
## A fence rather than a tuning number. [method advance] consumes whole passes in
## a loop so a long frame cannot swallow one silently, and a pass length of zero
## is not a very fast demo — it is that loop never ending, inside one frame, with
## nothing on screen to say why.
const MIN_SECONDS: float = 0.05

## How much of a panel the sweep covers, as a fraction of its own box.
##
## Short of the whole thing on purpose. The aim wanders the panel's bounding box
## and a bounding box is bigger than the panel inside it — every one of them, but
## a wing mirror's especially — so a sweep that ran to the edges would spend a
## good part of every pass pointed at the air beside the bodywork.
const REACH: float = 0.8

## How many times the aim crosses the panel while working down it. Three, which
## is what a person washing a door actually does: side to side, coming down.
const CROSSINGS: float = 3.0

var _kinds: Array[Surface.Kind] = []
var _seconds: float = 0.0
var _elapsed: float = 0.0
var _stop: int = 0
var _pass: int = 0


## Built with the surfaces to be worked, in the order they are to be worked, and
## how long each pass over one of them lasts.
##
## No defaults, for [CameraOrbit]'s reason: the pass length is the scene's number,
## where it is an [code]@export[/code] somebody can see and change, and a second
## answer here would drift from it. An empty running order is allowed and holds
## still — a room with no car in it is a thing a test can build, and it should not
## have to be special-cased by everything that drives one.
func _init(kinds: Array[Surface.Kind], seconds_per_pass: float) -> void:
	_kinds = kinds
	_seconds = maxf(seconds_per_pass, MIN_SECONDS)


## Moves the demo [param delta] seconds on.
##
## Whole passes are consumed in a loop rather than one per call, so a frame long
## enough to cover two of them advances by two instead of quietly dropping one.
## That matters most on the web, where the first frame after the tab comes back
## can be seconds long, and the visible symptom of getting it wrong would be a
## demo that falls further behind the longer it is left running.
func advance(delta: float) -> void:
	if _kinds.is_empty():
		return
	_elapsed += maxf(delta, 0.0)
	while _elapsed >= _seconds:
		_elapsed -= _seconds
		_step()


## Which entry of the running order is being worked — an index into the list
## handed to [method _init], not a panel. See the class docs on why this class
## has never heard of one.
func stop() -> int:
	return _stop


## Which pass is on it.
func stage() -> GrimeMap.Stage:
	match _pass:
		0:
			return GrimeMap.Stage.WASHED
		1:
			return GrimeMap.Stage.FOAMED
	return GrimeMap.Stage.BUFFED


## What the demo is holding: water for the wash, the bottle [method
## Surface.cleaner_for] gives this surface for the middle pass, and the rag for
## the shine.
##
## The middle one is asked of [Surface] rather than tabled here for that class's
## own reason — one direction, no second table — and it is the whole of why the
## demo swaps tools at all. A run down a car goes wash, sponge, rag, wash, window
## cleaner, rag, wash, tyre cleaner, rag, which is four of the five tools inside
## the first three panels without anybody scripting a tour of the belt.
func tool() -> DetailingTool.Id:
	match stage():
		GrimeMap.Stage.WASHED:
			return DetailingTool.Id.POWER_WASH
		GrimeMap.Stage.FOAMED:
			return Surface.cleaner_for(_kinds[_stop])
	return DetailingTool.Id.DRYING_RAG


## How far through the current pass the clock is, as [code]0..1[/code].
func progress() -> float:
	return clampf(_elapsed / _seconds, 0.0, 1.0)


## Where on [param box] the tool is pointed right now — side to side across the
## panel while working steadily down it, which is the motion a hand makes and not
## a shape anybody would draw.
##
## [b]It is an aim and not a landing point.[/b] What comes back is a point in the
## panel's own bounding box, and the room casts a ray at it exactly the way it
## casts one at a finger: where the water actually lands is wherever that ray
## meets the car. So a sweep that clips the inside of a wheel arch is not a bug to
## correct here — it is the same near-miss a player produces, answered the same
## way.
##
## [b]Across the longer of the two ground axes.[/b] A door's box is long in
## [code]x[/code] or in [code]z[/code] depending on which way the car is parked
## and which panel it is, and sweeping along the short one would rub the same
## stripe for the whole pass. Height is always [code]y[/code], because a car is
## never parked on its roof.
func aim_over(box: AABB) -> Vector3:
	var reach: Vector3 = box.size * 0.5 * REACH
	var across: float = sin(TAU * CROSSINGS * progress())
	var down: float = 1.0 - 2.0 * progress()
	if box.size.x >= box.size.z:
		return box.get_center() + Vector3(across * reach.x, down * reach.y, 0.0)
	return box.get_center() + Vector3(0.0, down * reach.y, across * reach.z)


## One pass done: on to the next one, then the next panel, then round again.
##
## The lap wraps rather than stopping, because an attract mode that ran out is a
## title screen showing a clean car and nothing happening — which is the state
## this whole thing exists to replace.
func _step() -> void:
	_pass += 1
	if _pass < PASSES:
		return
	_pass = 0
	_stop += 1
	if _stop < _kinds.size():
		return
	_stop = 0
	lapped.emit()
