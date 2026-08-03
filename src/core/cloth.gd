## A rectangle of cloth as a grid of points held together by springs: what turns
## the drying rag from a flat quad into something that moves like a cloth when
## the hand carrying it does.
##
## [b]What it is, plainly.[/b] A mass-spring sheet stepped with Verlet
## integration — points, links between neighbours, and a few relaxation passes a
## step that pull each link back toward the length it wants to be. That is the
## textbook cloth, and it is the whole of the simulation: no self-collision, no
## collision with the car, no tearing, no wind.
##
## [b]And one thing the textbook does not have: the sheet remembers its own
## shape.[/b] Every free point is pulled toward where the flat grid says it
## should be ([constant SPRING]) and is never allowed further from it than
## [constant STRAY]. Both are deliberate and both are about this being a
## [i]viewmodel[/i] cloth rather than a flag on a pole:
##
## - The rag is a tool that has to stay legible while it is being used. A cloth
##   free to drape would drape — over the edge of the panel it is lying on, and
##   through it, because nothing here knows the car exists.
## - The hand it hangs off travels the whole way to the car in about a sixth of a
##   second ([ReachCarry]). An unbounded sheet lags a metre behind a move like
##   that and arrives as a streak; bounded, it lags a few centimetres and arrives
##   as a rag catching up with itself, which is the thing worth drawing.
##
## So this is cloth in the way a game is cloth: it ripples, it trails, it settles,
## and it cannot get into trouble. The bound is the feature, not a limitation
## somebody forgot to remove.
##
## [b]It has no idea which space it is in.[/b] Points go in through
## [method hold] as a [Transform3D] and come back out of [method point] in
## whatever space that transform was in. The rag drives it in world coordinates,
## because that is what makes inertia free: the hand moves, the pinned edge moves
## with it, and the rest of the sheet stays where it was in the room until the
## springs drag it along. Simulating in the tool's own space instead would need
## the frame's acceleration passed in by hand, which is a derivative of a
## derivative of a transform and is exactly as noisy as it sounds.
##
## [b]The pinned edge is one row and it is row zero[/b] — the edge the hand has
## hold of. Everything else is free. A cloth with nothing pinned drifts off on the
## first breath of gravity and a cloth pinned at every corner is a trampoline.
##
## [b]Verlet assumes the step does not change much between frames[/b], because a
## Verlet velocity is a position difference rather than a velocity: halve the
## frame time and the sheet reads as having been damped. [constant DRAG] and
## [constant STRAY] between them make that a wobble nobody can see rather than an
## instability, which is the usual trade and is why every game cloth is written
## this way. Stated here rather than discovered later.
##
## A [RefCounted] in the Node-free tier — STANDARDS.md "Coverage" (R3) — so that
## "a pinned point never moves", "a link never stretches past its limit" and "an
## undisturbed sheet stays flat" are unit tests rather than things somebody
## checks by waving a rag at a monitor.
class_name Cloth
extends RefCounted

## The fewest points a side may have. Two is one quad: a sheet with a single row
## or column has no interior and nothing to ripple, and zero would be a division
## by nothing when the rest grid is laid out.
const MIN_SPAN: int = 2

## How many times a step pulls every link back toward its rest length. Three is
## enough that a sheet this size holds together without visible rubberiness, and
## it is the number that costs least — relaxation is the whole cost of this class
## and it is linear in this.
const RELAX: int = 3

## How much of a point's carried motion is thrown away each step, 0 to 1. Cloth
## is not a pendulum: without this the sheet rings for seconds after the hand
## stops, which reads as jelly rather than as fabric.
const DRAG: float = 0.12

## How hard a free point is pulled back toward the flat shape, in metres per
## second squared per metre of error. See the class docs — this is what makes the
## rag a rag rather than a flag.
##
## Two hundred and forty is a natural frequency around 15 rad/s, so a disturbance
## settles in about half a second: slow enough to see the cloth catch up with the
## hand, fast enough that it has finished doing so by the time anybody looks at
## where it landed.
const SPRING: float = 240.0

## How far a point may ever get from where the flat shape says it should be, in
## metres. Eight centimetres against a rag about thirty across — a visible
## billow, and a hard ceiling on how far the drawn mesh can be from the tool it
## is standing in for.
const STRAY: float = 0.08

## How much of a link's error each of its two ends takes when both are free. A
## half each, which is the whole of "neither end is more real than the other"; a
## link with one end pinned gives the whole correction to the free one instead.
const GIVE: float = 0.5

var _columns: int
var _rows: int
var _size: Vector2
var _rest: PackedVector3Array = PackedVector3Array()
var _placed: PackedVector3Array = PackedVector3Array()
var _points: PackedVector3Array = PackedVector3Array()
var _previous: PackedVector3Array = PackedVector3Array()
var _links: PackedInt32Array = PackedInt32Array()
var _lengths: PackedFloat32Array = PackedFloat32Array()


## A sheet [param span] metres across — [code]x[/code] along the cloth's own
## [code]X[/code] and [code]y[/code] along its [code]Z[/code], which is how a
## [PlaneMesh] reads a size and so how [member DetailingTool.extent] does — diced
## into [param across] by [param down] points.
##
## Laid out about the origin rather than from a corner, so the grid is the plane
## the rag was before it could move and a cloth that never gets a step still
## draws exactly what the catalogue asked for.
func _init(span: Vector2, across: int, down: int) -> void:
	_size = Vector2(maxf(span.x, 0.0), maxf(span.y, 0.0))
	_columns = maxi(across, MIN_SPAN)
	_rows = maxi(down, MIN_SPAN)
	_rest.resize(count())
	for row: int in _rows:
		for column: int in _columns:
			_rest[index_of(column, row)] = Vector3(
				_size.x * (float(column) / float(_columns - 1) - 0.5),
				0.0,
				_size.y * (float(row) / float(_rows - 1) - 0.5)
			)
	_placed = _rest.duplicate()
	_points = _rest.duplicate()
	_previous = _rest.duplicate()
	_weave()


## How many points across the sheet is.
func columns() -> int:
	return _columns


## How many down.
func rows() -> int:
	return _rows


## How many points there are in total, which is also the length of
## [method points].
func count() -> int:
	return _columns * _rows


## How big the flat sheet is, in metres.
func size() -> Vector2:
	return _size


## Where the point at [param column], [param row] sits in [method points].
func index_of(column: int, row: int) -> int:
	return row * _columns + column


## Whether the point at [param index] is held by the hand rather than simulated.
##
## The whole of the first row, which is the edge the hand has hold of. A caller
## that wants to know which points it may not expect to see move asks here rather
## than knowing that "row zero" is the answer.
func is_pinned(index: int) -> bool:
	return index >= 0 and index < _columns


## Where the point at [param index] would be if the cloth had never moved, in the
## space [method hold] last placed it in.
func placed_point(index: int) -> Vector3:
	return _placed[index]


## Where the point at [param index] is in the cloth's own flat space — the grid,
## before any transform and before any physics.
func rest_point(index: int) -> Vector3:
	return _rest[index]


## Where the point at [param index] actually is.
func point(index: int) -> Vector3:
	return _points[index]


## Every point, in the order [method index_of] numbers them.
func points() -> PackedVector3Array:
	return _points


## Puts the sheet's flat shape at [param frame] and moves the pinned edge onto it.
##
## Called once a step before [method step], with wherever the hand has got to.
## The pinned points are placed rather than simulated — they [i]are[/i] the hand —
## and their carried motion is placed with them, so an edge that has just been
## dragged two metres does not then try to keep going.
func hold(frame: Transform3D) -> void:
	for index: int in count():
		_placed[index] = frame * _rest[index]
		if is_pinned(index):
			_points[index] = _placed[index]
			_previous[index] = _placed[index]


## Drops the whole sheet onto the shape [method hold] last placed, at rest.
##
## What a rag that has just been taken out of the toolbelt wants: it was last
## simulated wherever the hand was standing several presses ago, and easing it
## across the room from there would be a rag arriving late to its own swap.
func settle() -> void:
	_points = _placed.duplicate()
	_previous = _placed.duplicate()


## Steps the sheet [param delta] seconds under [param pull] — gravity, in the
## same space [method hold] was given.
##
## Three passes in order, and the order is the whole of why it is stable:
## integrate, then pull the links back toward their rest lengths, then refuse to
## let anything have wandered further than [constant STRAY]. Doing the clamp
## first would have relaxation immediately undo it.
##
## A step of nothing does nothing rather than dividing by it — a paused game and
## a frame the engine reported as zero are both things that happen.
func step(delta: float, pull: Vector3) -> void:
	if delta <= 0.0:
		return
	_carry(delta, pull)
	for pass_number: int in RELAX:
		_tighten()
	_rein_in()


## Verlet: every free point keeps most of the motion it had and takes whatever
## [param pull] and the pull back toward the flat shape give it.
func _carry(delta: float, pull: Vector3) -> void:
	var step_squared: float = delta * delta
	for index: int in count():
		if is_pinned(index):
			continue
		var here: Vector3 = _points[index]
		var carried: Vector3 = (here - _previous[index]) * (1.0 - DRAG)
		var accelerating: Vector3 = pull + (_placed[index] - here) * SPRING
		_previous[index] = here
		_points[index] = here + carried + accelerating * step_squared


## One relaxation pass: every link pulled back toward the length it was built at.
##
## A link with one pinned end gives the whole correction to the free one, because
## the pinned end is the hand and the hand does not move for a piece of cloth.
func _tighten() -> void:
	for link: int in _lengths.size():
		var first: int = _links[link * 2]
		var second: int = _links[link * 2 + 1]
		var first_free: bool = not is_pinned(first)
		var second_free: bool = not is_pinned(second)
		if not first_free and not second_free:
			continue
		var apart: Vector3 = _points[second] - _points[first]
		var span: float = apart.length()
		if is_zero_approx(span):
			continue
		var share: float = GIVE if first_free and second_free else 1.0
		var correction: Vector3 = apart * ((span - _lengths[link]) / span) * share
		if first_free:
			_points[first] += correction
		if second_free:
			_points[second] -= correction


## The ceiling from the class docs: nothing may be further than [constant STRAY]
## from where the flat shape puts it. Applied to the position and not to the
## carried motion, so a point that hits the limit slides along it rather than
## stopping dead against it.
func _rein_in() -> void:
	for index: int in count():
		if is_pinned(index):
			continue
		var strayed: Vector3 = _points[index] - _placed[index]
		if strayed.length_squared() <= STRAY * STRAY:
			continue
		_points[index] = _placed[index] + strayed.normalized() * STRAY


## The links: each point tied to the one on its right and the one below it, plus
## both diagonals of every quad.
##
## The straight pair alone is a sheet that folds flat along its own diagonals like
## a paper hinge — it resists being stretched and not at all being sheared. The
## diagonals are what make it fabric. Built once, with the length each link was
## born at, so a link never has to ask the rest grid what it wants.
func _weave() -> void:
	for row: int in _rows:
		for column: int in _columns:
			var here: int = index_of(column, row)
			if column < _columns - 1:
				_tie(here, index_of(column + 1, row))
			if row < _rows - 1:
				_tie(here, index_of(column, row + 1))
			if column < _columns - 1 and row < _rows - 1:
				_tie(here, index_of(column + 1, row + 1))
				_tie(index_of(column + 1, row), index_of(column, row + 1))


## Ties [param first] to [param second] at whatever the flat grid has them apart.
func _tie(first: int, second: int) -> void:
	_links.append(first)
	_links.append(second)
	_lengths.append(_rest[first].distance_to(_rest[second]))
