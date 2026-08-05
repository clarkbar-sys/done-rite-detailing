## Where a point on a panel lands in that panel's grime texture, worked out from
## the point itself rather than from a UV map somebody unwrapped.
##
## [b]Why there is no unwrap.[/b] Two reasons, and the second one is fatal on its
## own. CSG generates UVs, but they tile by size in metres per face rather than
## packing into a 0–1 atlas, so two different places on the car share texels —
## wash the driver's door and the passenger's door comes clean too. And
## [method PhysicsDirectSpaceState3D.intersect_ray] does not return a UV at all:
## it hands back a position, a normal and a collider, so even a perfect unwrap
## could not be asked [i]where on it[/i] a press landed without reading mesh
## arrays back by face index. Computing the coordinate from the position is the
## way in, and it is also the cheap way in — a blockout that is still a dozen
## numbers in a scene file has nothing to unwrap yet.
##
## [b]Six half-axis planes, not triplanar's three.[/b] Classic triplanar blends
## three planar projections by [code]abs(NORMAL)[/code], and the [code]abs[/code]
## is exactly what cannot be used here: [code]+X[/code] and [code]-X[/code] fall
## on the same plane at the same coordinates, so the two flanks of the car would
## be the same texels. The blend is the second problem — a point on a curved
## panel reads from all three planes at fractional weights, and a mask has to be
## [i]written[/i] as well as read, which means one point must own exactly one
## texel. So the face is chosen by the [i]signed[/i] dominant axis and chosen
## outright: six planes, hard select, one texel per point.
##
## Triplanar is still the right tool for the half of the job it suits, and
## [code]grime.gdshader[/code] uses it there — the mud [i]pattern[/i] is sampled
## triplanar, because that is a read, and reads are what blending is good at. The
## mask says where; the pattern says what it looks like. Neither does the other's
## job.
##
## [b]What it costs.[/b] A hard select seams at the 45° edges where the dominant
## axis changes over, and on the smooth-shaded cylinders (the wheels, the arches)
## the interpolated normal walks that changeover across a band rather than a line.
## Both are visible in a debug view and neither is visible under mud. The fix, on
## the day a real mesh with a real unwrap exists, is to delete this file and read
## [code]UV[/code] — every caller asks for a texture coordinate and none of them
## care how it was arrived at.
class_name BoxProjection
extends RefCounted

## Which face of a panel's box a normal points out of. The order is the atlas
## order, read left to right and then down: [code]+X -X +Y[/code] on the top row,
## [code]-Y +Z -Z[/code] on the bottom.
enum Face {
	RIGHT,
	LEFT,
	TOP,
	BOTTOM,
	FRONT,
	BACK,
}

## How many faces a box has, and so how many tiles the atlas carries. Named
## rather than spelled [code]6[/code] at each use, because the two numbers below
## have to keep multiplying to it.
const FACES: int = 6

## The six of them, in that same atlas order, so a caller that has to visit every
## face can iterate rather than count to [constant FACES] and cast an [int] back
## into a [enum Face].
##
## [method GrimeMap._brush] is why it exists: a brush that reaches round a corner
## has no single face to work on any more, so it asks each of them in turn
## whether the tool is pointed at it.
const ALL_FACES: Array[Face] = [
	Face.RIGHT,
	Face.LEFT,
	Face.TOP,
	Face.BOTTOM,
	Face.FRONT,
	Face.BACK,
]

## Tiles across the atlas.
const COLUMNS: int = 3

## Tiles down it. Three by two rather than six by one or one by six: it is the
## squarest arrangement of six tiles, which keeps a square-ish texture — the
## shape every GPU is happiest with, and the shape a debug view can lay out in a
## grid without one panel being a ribbon.
const ROWS: int = 2

## The smallest extent, in metres, an axis of a box may have before it is treated
## as flat. Guards the divisions below: a panel with a zero-thickness axis would
## otherwise hand back an infinity, and a coordinate of infinity is a texel index
## nobody can clamp back into range. A tenth of a millimetre is thinner than any
## panel on the car — the glass, the thinnest of them, is centimetres.
const FLATNESS: float = 0.0001


## The face of a box that [param normal] points out of, in the box's own space.
##
## The largest component wins and its sign picks the half — which is the whole
## of the "signed dominant axis" in the class docs. Ties go to the earlier axis,
## which is arbitrary and has to be: a normal at exactly 45° between two faces is
## on the seam, and the seam has to fall on one side of itself.
static func face_for(normal: Vector3) -> Face:
	var size: Vector3 = normal.abs()
	if size.x >= size.y and size.x >= size.z:
		return Face.RIGHT if normal.x >= 0.0 else Face.LEFT
	if size.y >= size.z:
		return Face.TOP if normal.y >= 0.0 else Face.BOTTOM
	return Face.FRONT if normal.z >= 0.0 else Face.BACK


## The axis a face lies on, as an index into a [Vector3] — the one axis that is
## [i]not[/i] in [method tile_axes], because a face is flat along its own.
static func face_axis(face: Face) -> int:
	if face == Face.RIGHT or face == Face.LEFT:
		return Vector3.AXIS_X
	if face == Face.TOP or face == Face.BOTTOM:
		return Vector3.AXIS_Y
	return Vector3.AXIS_Z


## Which way a face points out of its box, in the box's own space.
##
## The inverse of [method face_for] for the six normals that are exactly on an
## axis, and the thing that makes "is this face turned toward the tool" a dot
## product rather than a table. [method GrimeMap._brush] is what wanted it: a
## brush that reaches round a corner has to decide, per face, whether the tool
## is in front of it or behind it, and the answer is the sign of
## [code]outward.dot(normal)[/code] and nothing else.
##
## Spelled out rather than derived from the enum's ordering. The order does pair
## each axis positive-then-negative, so [code]int(face) % 2[/code] would answer
## it — but that ordering exists to lay the atlas out (see [method atlas_uv]),
## and a second meaning read out of it is a second thing that breaks silently
## when the tiles are rearranged.
static func face_normal(face: Face) -> Vector3:
	match face:
		Face.RIGHT:
			return Vector3.RIGHT
		Face.LEFT:
			return Vector3.LEFT
		Face.TOP:
			return Vector3.UP
		Face.BOTTOM:
			return Vector3.DOWN
		Face.FRONT:
			return Vector3.BACK
	return Vector3.FORWARD


## The two axes of the box that a face's tile is measured along, as indices into
## a [Vector3]: [code]x[/code] is the axis that runs across the tile and
## [code]y[/code] is the one that runs down it.
##
## The pairs are the two axes that are not the face's own — a side of the car is
## measured along the car and up it, a roof along the car and across it. Nothing
## is mirrored for the negative faces, so the left flank's tile reads back to
## front against the right flank's. That is invisible in a mask and would be
## worth fixing the day these tiles carry anything a human has to recognise.
static func tile_axes(face: Face) -> Vector2i:
	if face == Face.RIGHT or face == Face.LEFT:
		return Vector2i(Vector3.AXIS_Z, Vector3.AXIS_Y)
	if face == Face.TOP or face == Face.BOTTOM:
		return Vector2i(Vector3.AXIS_X, Vector3.AXIS_Z)
	return Vector2i(Vector3.AXIS_X, Vector3.AXIS_Y)


## Where in a face's own tile [param point] falls, as [code]0..1[/code] on each
## axis, for a panel whose box is [param box] in the same space as the point.
##
## Clamped, because a point may legitimately sit slightly outside the box it is
## being measured against: [method CSGShape3D.get_aabb] is the box around a
## built mesh and a ray hits the mesh, so rounding at a corner can put the hit a
## float's width past the face. Clamping puts it on the edge of the tile, which
## is where it is.
static func tile_uv(box: AABB, point: Vector3, face: Face) -> Vector2:
	var axes: Vector2i = tile_axes(face)
	return Vector2(
		_along(box, point, axes.x),
		_along(box, point, axes.y),
	)


## Where on the box a tile coordinate sits, in the box's own space: [method
## tile_uv] run backwards and put back onto the face's own plane.
##
## [b]What it is for is measuring, not sampling.[/b] Every other function here
## turns a place into a texel; this turns a texel back into a place, which is
## what lets a brush ask how far apart two texels actually are in metres instead
## of in tile coordinates. [method GrimeMap._brush] is the caller, and the
## difference matters most exactly where the tile coordinates are least
## comparable: across two faces, whose tiles are measured along different axes
## and are not the same size in metres.
##
## The face's own axis is pinned to whichever side of the box the face is —
## [code]position + size[/code] for the three positive faces and
## [code]position[/code] for the three negative ones — so the answer is always on
## the box's surface rather than somewhere inside it.
##
## Not clamped, unlike [method tile_uv], because there is nothing to clamp: a
## tile coordinate is already [code]0..1[/code] by construction, and a caller
## that hands in something outside it is asking about a point off the face and
## should get one.
static func point_on_face(box: AABB, tile: Vector2, face: Face) -> Vector3:
	var axes: Vector2i = tile_axes(face)
	var axis: int = face_axis(face)
	var outward: Vector3 = face_normal(face)
	var point: Vector3 = Vector3.ZERO
	point[axes.x] = box.position[axes.x] + tile.x * box.size[axes.x]
	point[axes.y] = box.position[axes.y] + tile.y * box.size[axes.y]
	point[axis] = box.position[axis] + (box.size[axis] if outward[axis] > 0.0 else 0.0)
	return point


## A tile coordinate placed into the whole atlas, so it can be sampled or written
## as one texture rather than as six.
static func atlas_uv(tile: Vector2, face: Face) -> Vector2:
	var column: int = int(face) % COLUMNS
	var row: int = int(face) / COLUMNS
	return Vector2((float(column) + tile.x) / float(COLUMNS), (float(row) + tile.y) / float(ROWS))


## The whole projection in one call: where [param point] on a panel of
## [param normal] lands in that panel's atlas, as [code]0..1[/code] across the
## whole texture.
static func uv_for(box: AABB, point: Vector3, normal: Vector3) -> Vector2:
	var face: Face = face_for(normal)
	return atlas_uv(tile_uv(box, point, face), face)


## A brush radius in metres, as a radius in tile coordinates on each axis.
##
## Two numbers and not one because a tile is not square in metres: the side of a
## car is four metres long and one and a half high, so a round splash of water on
## it is an ellipse in the tile it lands in. Painting a circle in tile space
## instead would put a wash on a door twice as tall as it is wide.
static func tile_radius(box: AABB, face: Face, radius_metres: float) -> Vector2:
	var axes: Vector2i = tile_axes(face)
	return Vector2(
		radius_metres / maxf(box.size[axes.x], FLATNESS),
		radius_metres / maxf(box.size[axes.y], FLATNESS),
	)


## How far along one axis of [param box] a point sits, as [code]0..1[/code].
static func _along(box: AABB, point: Vector3, axis: int) -> float:
	return clampf((point[axis] - box.position[axis]) / maxf(box.size[axis], FLATNESS), 0.0, 1.0)
