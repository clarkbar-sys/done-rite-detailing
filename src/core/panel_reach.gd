## Which texels of one panel's grime atlas the player can actually get a tool
## onto — the mask [GrimeMap] seeds mud through, so that "done" is a number
## somebody can reach.
##
## [b]The problem, in one sentence.[/b] A [GrimeMap] is a box projection and a car
## is not a box, so most of the atlas is not paint at all: the underside of a
## pack car's shell is part of [code]Body[/code]'s own [code]-Y[/code] tile and
## renders muddy, the middle of that tile is air nothing projects to, and a
## surface tucked behind a wheel arch is real paint no legal aim can land on.
## Seeding every texel therefore seeded a car that could never come clean —
## [method GrimeMap.is_clean] and [method GrimeMap.is_finished] could not become
## true in play, [method Grime.shine] could not reach one, and there was no honest
## percentage to put in front of the player. The user-visible half of it is the
## one the issue was filed about: [i]mud on the underside of the car, which you
## cannot clean[/i].
##
## [b]Reachability is measured, not modelled.[/b] The alternative was to derive it
## from the geometry — rasterise each panel's own triangles into its atlas, then
## subtract whatever faces down — and it is cheaper and it answers a different
## question. What a player can clean is not "is there geometry here"; it is "can
## the eye get somewhere that a ray from it lands here", and there is already a
## piece of code that decides that: [method PhysicsDirectSpaceState3D.intersect_ray],
## cast from the eye, exactly as [method AimProbe.under_the_finger] casts it to spend
## the trigger. So the mask is built by standing in the places the player is
## allowed to stand and looking at the car through the same query. Reachability and
## the trigger then cannot disagree, because they are the same call.
##
## This class is the arithmetic half of that: where to stand ([method eyes]), what
## to look at ([method targets]), and where a hit lands in the atlas
## ([method saw], [method spread]). The casting itself is [method Grime.lay_on]'s,
## because a space state belongs to a node in a tree and this has to be
## constructible in a unit test.
##
## [b]Cells, not texels, and that is a performance decision with a correctness
## argument under it.[/b] The mask is a coarse grid over the atlas —
## [constant CELLS_PER_PATCH] cells along each axis of every patch — rather than
## one bit per pixel. Two reasons:
##
## - [i]It is what makes the dilation affordable.[/i] Marking a brush-wide ellipse
##   around every hit at atlas resolution is the same work [method GrimeMap.wash]
##   does, measured on this hardware at about 1.0 ms a splat on the biggest panel;
##   at tens of thousands of hits that is a minute of loading. At cell resolution a
##   hit is one byte and the dilation is four linear sweeps.
## - [i]A brush is much wider than a texel anyway.[/i] The narrowest tool in the
##   game reaches 0.22 m; a cell on a [MeshCar]'s body is 0.15 m along the car at
##   its coarsest and 0.04 m up it, because a tile is not square in metres. So the
##   boundary between "reachable" and "not" is already blurred by the tool, by more
##   than the grid blurs it, on the axis where the grid is worst.
##
## The grid is [constant CELLS_PER_PATCH] cells [i]per patch[/i] rather than a flat
## number so that every cell lies wholly inside one patch: patch boundaries fall at
## [code]ceil(p * pixels / patches)[/code] and cell boundaries at
## [code]ceil(c * pixels / (patches * CELLS_PER_PATCH))[/code], and the second set
## contains the first exactly. That is what lets [GrimeMap] add a patch's capacity
## up out of whole cells instead of walking a hundred thousand pixels, and it is
## the property to preserve if this constant is ever made a knob.
##
## [b]Dilated by the narrowest tool, and the direction of that error matters.[/b]
## A texel is cleanable if [i]some[/i] aim lands within a brush radius of it, so
## the honest mask is the hits grown by a brush. Grown by too much and the car
## carries mud nobody can take off — 100% goes back to being unreachable, which is
## the bug this class exists to fix. Grown by too little and a patch of paint
## starts clean, which looks odd and costs nothing. So the radius handed to
## [method spread] is the [i]smallest[/i] of the three tools' reaches rather than
## the water's widest: a texel the sponge cannot cover is a texel that can be
## washed and never foamed, and a panel like that is a panel nobody can finish.
##
## [b]And every approximation in here is deliberately in the same direction.[/b]
## The eyes are a few dozen poses out of a continuum, the targets are a lattice,
## the dilation is separable and so squares off the ellipse's corners. The first
## two can only find fewer places than a player can; the third is the one that
## goes the other way, by up to a corner of the brush, and it is bounded by the
## brush being smaller than the sampling is dense.
class_name PanelReach
extends RefCounted

## How many mask cells fit across one patch, on each axis. Six puts a cell at
## roughly 0.15 m on a [MeshCar]'s body — comfortably finer than the 0.22 m the
## narrowest tool reaches, which is the scale the answer is really being asked at.
## See the class docs for why it is a multiple of the patch grid rather than of
## the tile.
const CELLS_PER_PATCH: int = 6

## How many radii out from the car the eye is sampled at, across the band the walk
## is fenced into ([member Garage.standoff_radius_min] to
## [member Garage.orbit_radius]).
##
## Two, because what a third radius buys is nearly nothing: a ray from further
## out along the same bearing lands within centimetres of the near one on
## anything that is not a deep recess, and the near ring is already dropped
## wherever it would put the eye inside the bodywork — see [method eyes].
const RING_SAMPLES: int = 2

## How many heights the eye is sampled at across [member Garage.eye_height_min] to
## [member Garage.eye_height_max]. Three: crouched at a sill, standing, and looking
## down over the roof, which is the whole of what the lift control can do.
const HEIGHT_SAMPLES: int = 3

## How many bearings around the car. Sixteen is a pose every 22.5°, which is what
## decides how far into a wheel arch or under a mirror the mask can see. Under-
## sampling here costs coverage and never costs correctness — see the class docs
## on which way every approximation leans.
const ANGLE_SAMPLES: int = 16

## How far apart the aiming targets are, in metres. The lattice is what gives each
## eye its angular resolution, so this is really "how finely is the car looked
## at": 0.35 m is inside the 0.44 m a 0.22 m brush covers end to end, so the hits
## a single eye produces already overlap once they are dilated.
const TARGET_SPACING: float = 0.35

## The most targets any one axis of the lattice may be diced into, so a room that
## is handed a bus does not quietly cast a million rays. At
## [constant TARGET_SPACING] this binds at about seven metres, which is longer
## than the longest style in the pack.
const MOST_TARGET_STEPS: int = 20

## Further than any tile is wide, so "no marked cell in this direction" is a
## distance rather than a branch at every comparison in [method _distances].
const _NOWHERE: int = 1 << 24

var _box: AABB
var _cells: Vector2i
var _tile: Vector2i
var _seen: PackedByteArray = PackedByteArray()


## The mask grid for a [GrimeMap] whose patches are laid out [param patch_grid] —
## see [method GrimeMap.patch_grid].
##
## Public and static because both sides need it and neither owns it: [Grime]
## builds the mask before there is a map to ask, and the map has to agree about
## the same grid afterwards.
static func cells_for(patch_grid: Vector2i) -> Vector2i:
	return patch_grid * CELLS_PER_PATCH


## Where the player's eye can be, given the car's [param bounds] and the band the
## room fences the walk into: [param radius_min] to [param radius_max] out from
## the middle of the car on the floor plane, [param height_min] to
## [param height_max] above it.
##
## [b]The ring is sampled and then filtered, and the filter is not a detail.[/b]
## The room's inner fence ([member Garage.standoff_radius_min]) is a backstop for a
## ray that measured nothing rather than a distance anybody stands at — what
## actually holds the eye off the paint is [member Garage.standoff_metres], easing
## the radius panel by panel. So the raw ring at the inner radius runs straight
## through the bodywork on a car longer than it is wide, and an eye inside the
## shell would see the underside of every panel through
## [member ConcavePolygonShape3D.backface_collision] — which the pack's colliders
## all set, and which is exactly how the inside of the car would have been marked
## reachable. Dropping any pose standing on the car's own footprint is the whole of
## the fix, and it is also just true: nobody stands there.
##
## The height band is not filtered against the roof, and deliberately. A pose
## above a low car is legal — the lift really does go to
## [member Garage.eye_height_max] — and what it sees is the roof, which is
## reachable from the ground anyway.
static func eyes(
	bounds: AABB, radius_min: float, radius_max: float, height_min: float, height_max: float
) -> PackedVector3Array:
	var found: PackedVector3Array = PackedVector3Array()
	var middle: Vector3 = bounds.get_center()
	var footprint: Rect2 = Rect2(
		Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z)
	)
	for ring: int in RING_SAMPLES:
		var radius: float = lerpf(radius_min, radius_max, _across(ring, RING_SAMPLES))
		for step: int in ANGLE_SAMPLES:
			var turn: float = TAU * float(step) / float(ANGLE_SAMPLES)
			var on_the_floor: Vector2 = Vector2(
				middle.x + radius * sin(turn), middle.z + radius * cos(turn)
			)
			if footprint.has_point(on_the_floor):
				continue
			for lift: int in HEIGHT_SAMPLES:
				var height: float = lerpf(height_min, height_max, _across(lift, HEIGHT_SAMPLES))
				found.append(Vector3(on_the_floor.x, height, on_the_floor.y))
	return found


## The points every eye aims at: a lattice through [param bounds] at
## [constant TARGET_SPACING].
##
## [b]Through the box and not over it.[/b] A ray stops at the first thing it
## meets, so aiming at a point deep inside the car is a ray that lands on whatever
## faces the eye — and as the eye walks round, the same interior target sweeps the
## near surface. Aiming at points on the surface of the box instead would spend
## the same rays on a shell that is mostly air at the corners and would never look
## down the length of the car at all.
static func targets(bounds: AABB) -> PackedVector3Array:
	var found: PackedVector3Array = PackedVector3Array()
	var steps: Vector3i = Vector3i(
		_steps_along(bounds.size.x), _steps_along(bounds.size.y), _steps_along(bounds.size.z)
	)
	for ix: int in steps.x + 1:
		for iy: int in steps.y + 1:
			for iz: int in steps.z + 1:
				found.append(
					(
						bounds.position
						+ Vector3(
							bounds.size.x * float(ix) / float(steps.x),
							bounds.size.y * float(iy) / float(steps.y),
							bounds.size.z * float(iz) / float(steps.z)
						)
					)
				)
	return found


## An empty mask over [param panel_box] — the panel's own box, in the space hits
## will be given in — diced [constant CELLS_PER_PATCH] cells to a side of every
## patch of [param patch_grid].
##
## Nothing is reachable until something has been [method saw] onto it, which is
## the right way round: a mask built and never filled in seeds a panel with no mud
## on it at all, which is visible immediately, where one that defaulted to
## reachable would silently be the bug this class removes.
func _init(panel_box: AABB, patch_grid: Vector2i) -> void:
	_box = panel_box
	_cells = cells_for(patch_grid)
	_tile = Vector2i(_cells.x / BoxProjection.COLUMNS, _cells.y / BoxProjection.ROWS)
	_seen.resize(_cells.x * _cells.y)


## The shape of the mask, in cells across the whole atlas and down it.
func grid() -> Vector2i:
	return _cells


## A tool can land on [param point], a place on this panel facing
## [param normal], both in the panel's own space.
##
## One cell per call and no brush: the brush is [method spread], applied once at
## the end, because dilating tens of thousands of hits one at a time is the cost
## the class docs open on.
func saw(point: Vector3, normal: Vector3) -> void:
	var face: BoxProjection.Face = BoxProjection.face_for(normal)
	var uv: Vector2 = BoxProjection.tile_uv(_box, point, face)
	var at: Vector2i = _cell_in(face, uv)
	_seen[at.y * _cells.x + at.x] = 1


## Grows everything [method saw] has marked by a brush of [param radius_metres],
## so that a texel a tool would cover is reachable even though no sampled ray
## landed exactly on it.
##
## [b]Per face, because a brush is.[/b] The radius is converted through
## [method BoxProjection.tile_radius], which is two different numbers on the two
## axes of a tile and six different pairs across the atlas — a face measured along
## the length of the car and up it turns a round splash into a tall ellipse. And
## the growth stops at the edge of its own tile, exactly as
## [method GrimeMap._brush] does, because the atlas is six pictures side by side
## and bleeding across the seam would mark the roof from a hit on the flank.
##
## [b]Separable, so it is four sweeps of the grid rather than an ellipse per
## cell.[/b] Each row is grown by the horizontal reach and then each column by the
## vertical one, which is a rectangle where a brush is an ellipse. That is the one
## approximation in this class that marks more than it should, and it is bounded:
## it can only add the corners of a brush-sized box, and only around cells that
## are already at the edge of what was seen.
func spread(radius_metres: float) -> void:
	if radius_metres <= 0.0:
		return
	for index: int in BoxProjection.FACES:
		var face: BoxProjection.Face = index as BoxProjection.Face
		var radius: Vector2 = BoxProjection.tile_radius(_box, face, radius_metres)
		var origin: Vector2i = _tile_origin(face)
		var reach: Vector2i = Vector2i(
			int(radius.x * float(_tile.x)), int(radius.y * float(_tile.y))
		)
		for row: int in _tile.y:
			_grow_row(origin.y + row, origin.x, reach.x)
		for column: int in _tile.x:
			_grow_column(origin.x + column, origin.y, reach.y)


## Whether a tool can be got onto the cell at [param at].
##
## Answers [code]false[/code] rather than erroring for a cell off the grid, the
## way [method GrimeMap.is_patch_clean] does for a patch that is not there: the
## caller is walking pixels and rounding them into cells, and "off the edge" is
## not reachable by any reading.
func reaches(at: Vector2i) -> bool:
	if at.x < 0 or at.y < 0 or at.x >= _cells.x or at.y >= _cells.y:
		return false
	return _seen[at.y * _cells.x + at.x] != 0


## How many cells of the mask are reachable. What a test asserts against the whole
## grid to say how much of a panel the player can get at.
func reached() -> int:
	var count: int = 0
	for cell: int in _seen.size():
		if _seen[cell] != 0:
			count += 1
	return count


## Where [param index] of [param count] samples falls across a band, as
## [code]0..1[/code]. One sample sits at the near end rather than dividing by
## zero, which is the honest reading of "sample this band once".
static func _across(index: int, count: int) -> float:
	if count <= 1:
		return 0.0
	return float(index) / float(count - 1)


## How many steps of [constant TARGET_SPACING] fit along [param extent], at least
## one and never more than [constant MOST_TARGET_STEPS].
static func _steps_along(extent: float) -> int:
	return clampi(int(extent / TARGET_SPACING), 1, MOST_TARGET_STEPS)


## The cell a tile coordinate lands in, placed into the whole atlas.
func _cell_in(face: BoxProjection.Face, uv: Vector2) -> Vector2i:
	var origin: Vector2i = _tile_origin(face)
	return Vector2i(
		origin.x + clampi(int(uv.x * float(_tile.x)), 0, _tile.x - 1),
		origin.y + clampi(int(uv.y * float(_tile.y)), 0, _tile.y - 1),
	)


## The top-left cell of a face's tile — the same layout
## [method GrimeMap._tile_origin] uses for pixels.
func _tile_origin(face: BoxProjection.Face) -> Vector2i:
	var column: int = int(face) % BoxProjection.COLUMNS
	var row: int = int(face) / BoxProjection.COLUMNS
	return Vector2i(column * _tile.x, row * _tile.y)


## Grows one row of one tile: every cell within [param reach] of a marked one is
## marked too.
##
## Two sweeps and a pass rather than a window per cell. The first two record how
## far each cell is from the nearest marked one to its left and to its right,
## which is a running count, and the third marks whatever came out inside the
## reach. The distances are taken before anything is written, so a cell this call
## marks cannot go on to mark its own neighbour and walk the whole row.
func _grow_row(row: int, from: int, reach: int) -> void:
	if reach <= 0:
		return
	var base: int = row * _cells.x + from
	var near: PackedInt32Array = _distances(base, 1, _tile.x)
	for step: int in _tile.x:
		if near[step] <= reach:
			_seen[base + step] = 1


## Grows one column of one tile, the way [method _grow_row] grows a row.
func _grow_column(column: int, from: int, reach: int) -> void:
	if reach <= 0:
		return
	var base: int = from * _cells.x + column
	var near: PackedInt32Array = _distances(base, _cells.x, _tile.y)
	for step: int in _tile.y:
		if near[step] <= reach:
			_seen[base + step * _cells.x] = 1


## How far each of [param count] cells starting at [param base] and taken
## [param stride] apart is from the nearest marked cell in the same run.
##
## [constant _NOWHERE] stands in for "there is no marked cell that way", and it is
## larger than any reach a tile can ask for, so a run with nothing in it grows
## nothing.
func _distances(base: int, stride: int, count: int) -> PackedInt32Array:
	var near: PackedInt32Array = PackedInt32Array()
	near.resize(count)
	var last: int = -_NOWHERE
	for step: int in count:
		if _seen[base + step * stride] != 0:
			last = step
		near[step] = step - last
	last = count + _NOWHERE
	for back: int in count:
		var step: int = count - 1 - back
		if _seen[base + step * stride] != 0:
			last = step
		near[step] = mini(near[step], last - step)
	return near
