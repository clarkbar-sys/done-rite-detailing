## The drying rag, drawn as a piece of cloth instead of as a quad: a [Cloth]
## simulated in world space and rebuilt into an [ArrayMesh] every frame.
##
## [b]It stands in for a [PlaneMesh] and keeps every promise that one made.[/b]
## The catalogue says the rag is a [constant DetailingTool.Shape.PLANE] of a given
## size ([method DetailingTool.catalogue]) and the roll-up icon draws one, so this
## is exactly that rectangle — same extent, same origin, same one-sidedness —
## with the single quad inside it diced into [constant ACROSS] by [constant DOWN]
## points that are allowed to move. A rag that quietly rendered at a different
## size would be a rag the roll-up disagrees with, which is the thing
## [ViewModel]'s own docs are about.
##
## [b]Simulated in world space, and that is the whole trick.[/b] [method Cloth.hold]
## is handed this node's [member Node3D.global_transform] every frame, so the
## pinned edge is dragged wherever the hand goes while the free points stay where
## they were in the room until the springs catch them up. Inertia comes out of
## that for nothing: no acceleration to differentiate out of a transform, no
## frame-of-reference term to get the sign of. What it costs is one inverse
## transform a frame to put the answer back into the mesh's own coordinates, which
## is one matrix against forty-nine points.
##
## [b]Why the mesh is rebuilt rather than skinned or shaded.[/b] A vertex shader
## rippling a tessellated plane is cheaper and is what this would be if the
## motion only had to look plausible — but a shader cannot know where the hand
## was last frame, so it can only ever fake the one thing this is for, which is
## the rag trailing behind an arm that has just thrown it two metres. The other
## way round, a [SoftBody3D] is the engine's real answer and is the wrong tool
## here for a specific reason: it simulates in global space against the physics
## server and has no notion of being parented to a camera, so a viewmodel made of
## one fights its own anchor every frame. Forty-nine points stepped in GDScript is
## small enough that neither trade is worth taking.
##
## [b]Normals are recomputed, not carried.[/b] A cloth whose normals stayed flat
## while its vertices moved is a flat rag with a wobbly silhouette — the shape
## would ripple and the shading would not, which reads as a rendering fault. They
## come off the neighbouring points, which is the same surface the triangles are
## built from and so cannot disagree with it.
##
## [b]And so are tangents, for the same reason and one more.[/b] A normal map is
## read in the surface's own tangent frame, so a mesh built by hand that ships no
## [constant Mesh.ARRAY_TANGENT] gets whatever the renderer has lying around —
## which is how a [Microfiber] weave ends up lit from a direction the cloth is not
## facing. A [PlaneMesh] of this size ships one ([code](1, 0, 0)[/code] with a
## [code]+1[/code] binormal sign, measured rather than assumed), and the whole of
## this class is about being that plane, so this ships the same frame bent along
## with the sheet.
class_name ClothRag
extends MeshInstance3D

## How many points across and down the sheet is diced into.
##
## Seven each way is thirty-six quads: enough that a fold reads as a curve rather
## than as a crease, few enough that the whole simulation is a few hundred
## floating-point operations a frame. It is also odd, which puts a point in the
## middle of the rag rather than a seam — the middle is where a cloth held by one
## edge does most of its moving.
const ACROSS: int = 7
const DOWN: int = 7

## How hard the cloth is pulled down, in metres per second squared.
##
## Two, and not the nine and a bit the room's other physics would use. A rag this
## size under real gravity hangs straight down from its pinned edge and stays
## there, which is a towel on a rail rather than a tool in a hand — and the shape
## spring in [Cloth] would then be fighting gravity to a draw, in a tug of war
## whose result is a number nobody chose. A light pull gives the sag a direction
## without deciding the shape, and the shape stays the flat rectangle the
## catalogue asked for.
const SAG: float = 2.0

## The normal handed back where a sheet is too crumpled to measure one — its own
## flat [code]+Y[/code], which is what the rag's normal is for all but a moment
## anyway. Reached only by two neighbouring points landing on top of each other,
## which the link lengths in [Cloth] make about as likely as it sounds.
const FLAT: Vector3 = Vector3.UP

## The tangent handed back in the same case, and for the same reason: the flat
## sheet's own [code]+X[/code], which is the direction [member Cloth.size]'s
## [code]x[/code] runs and so the way the weave's [code]u[/code] increases.
const SIDEWAYS: Vector3 = Vector3.RIGHT

## The binormal sign written after every tangent. Positive, because that is what
## a [PlaneMesh] of this size writes and this is standing in for one — a sheet
## that flipped it would light its weave as though the texture were mirrored.
const HANDED: float = 1.0

## How many floats a tangent takes in [constant Mesh.ARRAY_TANGENT]: three for
## the direction and a fourth for [constant HANDED].
const TANGENT_STRIDE: int = 4

var _cloth: Cloth = null
var _local: PackedVector3Array = PackedVector3Array()
var _normals: PackedVector3Array = PackedVector3Array()
var _tangents: PackedFloat32Array = PackedFloat32Array()
var _uvs: PackedVector2Array = PackedVector2Array()
var _triangles: PackedInt32Array = PackedInt32Array()
var _sheet: ArrayMesh = null


## A rag [param size] metres across, read the way a [PlaneMesh] reads a size:
## [code]x[/code] along [code]X[/code] and [code]y[/code] along [code]Z[/code].
func _init(size: Vector2) -> void:
	_cloth = Cloth.new(size, ACROSS, DOWN)
	_local.resize(_cloth.count())
	_normals.resize(_cloth.count())
	_tangents.resize(_cloth.count() * TANGENT_STRIDE)
	_face()
	_wind()
	_sheet = ArrayMesh.new()
	mesh = _sheet
	# Built flat before the node is in a tree at all, so a rag that never gets a
	# frame — a headless test, the title screen, the four frames before something
	# equips it — still has the mesh the catalogue asked for rather than nothing.
	for index: int in _cloth.count():
		_local[index] = _cloth.rest_point(index)
	_reshape()


## Drops the cloth flat onto wherever the hand has just put it, at rest.
##
## Called on the frame this rag is equipped — see
## [method ViewModel._on_equipped_changed]. Without it the sheet would still be
## wherever it was left several presses and half a lap around the car ago, and
## would spend its first second on screen flying across the room to catch up with
## a swap the player has already finished making.
func settle() -> void:
	_cloth.hold(global_transform)
	_cloth.settle()
	_reshape_from_world()


## The sheet this rag is drawn from. Public so a test can ask what the simulation
## actually did rather than trying to read it back out of a vertex buffer.
func cloth() -> Cloth:
	return _cloth


## Steps the cloth and redraws it.
##
## [b]Nothing at all while the rag is not the tool in hand[/b], which is four
## frames in five: the belt shows one proxy at a time and the other four are not
## on screen to have physics done to. [method settle] is what makes that safe —
## a rag coming back up is placed rather than resumed.
func _process(delta: float) -> void:
	if not visible:
		return
	_cloth.hold(global_transform)
	_cloth.step(delta, Vector3.DOWN * SAG)
	_reshape_from_world()


## Pulls the simulated points back into this node's own coordinates and rebuilds
## the mesh from them.
##
## The inverse is taken once for the whole sheet rather than through
## [method Node3D.to_local] per point, which would recompute it forty-nine times
## a frame for one answer.
func _reshape_from_world() -> void:
	var into: Transform3D = global_transform.affine_inverse()
	for index: int in _cloth.count():
		_local[index] = into * _cloth.point(index)
	_reshape()


## The mesh itself: one surface, rebuilt from [member _local].
##
## [method ArrayMesh.clear_surfaces] and a fresh surface rather than an in-place
## vertex update, because the index buffer, the UVs and the vertex count never
## change and the engine's own cost here is dominated by the upload either way.
## Forty-nine vertices is a rounding error next to the two hundred draw calls the
## room already makes.
func _reshape() -> void:
	for row: int in _cloth.rows():
		for column: int in _cloth.columns():
			_frame_at(column, row)
	var surface: Array = []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = _local
	surface[Mesh.ARRAY_NORMAL] = _normals
	surface[Mesh.ARRAY_TANGENT] = _tangents
	surface[Mesh.ARRAY_TEX_UV] = _uvs
	surface[Mesh.ARRAY_INDEX] = _triangles
	_sheet.clear_surfaces()
	_sheet.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)


## Writes the normal and the tangent at [param column], [param row], both
## measured from the same two spans across the sheet and along it.
##
## One function for the pair rather than two, because they are one measurement:
## a tangent that was taken from a different neighbourhood than the normal it is
## paired with is a tangent frame that is not square to its own surface, and the
## weave shears where the cloth folds. Written in place rather than returned
## because GDScript has no cheap way to hand back both.
##
## Clamped at the edges rather than wrapped, so a border point measures against
## itself and its one neighbour — half the span, the same direction, and the
## normalisation takes the difference back out.
func _frame_at(column: int, row: int) -> void:
	var last_column: int = _cloth.columns() - 1
	var last_row: int = _cloth.rows() - 1
	var across: Vector3 = (
		_local[_cloth.index_of(mini(column + 1, last_column), row)]
		- _local[_cloth.index_of(maxi(column - 1, 0), row)]
	)
	var along: Vector3 = (
		_local[_cloth.index_of(column, mini(row + 1, last_row))]
		- _local[_cloth.index_of(column, maxi(row - 1, 0))]
	)
	# `along × across` and not the other way round: the sheet runs +X across and
	# +Z along, and Z cross X is +Y — which is the face a [PlaneMesh] of the same
	# size would have presented.
	var facing: Vector3 = along.cross(across)
	var normal: Vector3 = FLAT if facing.is_zero_approx() else facing.normalized()
	var index: int = _cloth.index_of(column, row)
	_normals[index] = normal
	# The `u` axis is the span across, less whatever of it is leaning out of the
	# surface — Gram-Schmidt, and the reason a fold does not tilt the weave out of
	# the cloth it is woven into.
	var sideways: Vector3 = across - normal * across.dot(normal)
	var tangent: Vector3 = SIDEWAYS if sideways.is_zero_approx() else sideways.normalized()
	_tangents[index * TANGENT_STRIDE] = tangent.x
	_tangents[index * TANGENT_STRIDE + 1] = tangent.y
	_tangents[index * TANGENT_STRIDE + 2] = tangent.z
	_tangents[index * TANGENT_STRIDE + 3] = HANDED


## The UVs, which never change: the sheet's own grid, corner to corner. Built
## once because a rag that is stretched is still the same piece of cloth.
func _face() -> void:
	_uvs.resize(_cloth.count())
	for row: int in _cloth.rows():
		for column: int in _cloth.columns():
			_uvs[_cloth.index_of(column, row)] = Vector2(
				float(column) / float(_cloth.columns() - 1), float(row) / float(_cloth.rows() - 1)
			)


## The index buffer, which never changes either: two triangles per quad, wound so
## the sheet's front face is its [code]+Y[/code].
func _wind() -> void:
	for row: int in _cloth.rows() - 1:
		for column: int in _cloth.columns() - 1:
			var here: int = _cloth.index_of(column, row)
			var right: int = _cloth.index_of(column + 1, row)
			var below: int = _cloth.index_of(column, row + 1)
			var opposite: int = _cloth.index_of(column + 1, row + 1)
			_triangles.append_array(PackedInt32Array([here, below, right]))
			_triangles.append_array(PackedInt32Array([right, below, opposite]))
