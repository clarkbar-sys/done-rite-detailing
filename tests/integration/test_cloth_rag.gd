## Integration test for [ClothRag] — the simulated sheet the drying rag is drawn
## as.
##
## Under tests/integration/ because everything interesting about this class is
## about being a node: it reads its own [member Node3D.global_transform] every
## frame, it steps on the frame clock, and what it produces is a mesh. [Cloth]'s
## own promises — pinned edges, the ceiling on how far a point may stray, a sheet
## pulling itself back together — are unit-tested in
## [code]tests/unit/test_cloth.gd[/code] and are not repeated here.
##
## The rag is built directly rather than fished out of a garage, so a failure
## points at the cloth instead of at whatever else a room is doing. That it is
## really the node the viewmodel hangs on the belt is
## [code]tests/integration/test_view_model.gd[/code]'s.
##
## [b]What is asserted is the substitution.[/b] This node exists to stand in for a
## [PlaneMesh] of exactly the size [method DetailingTool.catalogue] asks for, and
## the whole risk in it is that a mesh built point by point quietly stops being
## that rectangle. So: the right size, the right normal, a triangle for every
## quad, and both halves of "it moves" — that a hand yanking it across the room
## disturbs it, and that it comes back a moment later.
##
## [b]"The rectangle" means the settled sheet, not the hanging one.[/b] A rag left
## alone under [constant ClothRag.SAG] does not sit perfectly flat — it droops a
## couple of centimetres off its pinned edge, which is the entire point of it being
## cloth. So the two exact measurements below are taken on a sheet that has just
## been [method ClothRag.settle]d, and everything about the hanging shape is
## measured against [constant HANGING] instead. Asserting flatness on a cloth under
## gravity would be asserting that the feature does not work.
extends GutTest

## A ten-thousandth of a metre. The sheet at rest is laid out by exact division.
const TOLERANCE: float = 0.0001

## The rag's own size, from [method DetailingTool.catalogue].
const SPAN: Vector2 = Vector2(0.32, 0.28)

## How far to yank the rag between two frames. Two metres, which is about the
## reach from the hand to the paint — the move [ReachCarry] actually makes, rather
## than a number chosen to be dramatic.
const YANK: float = 2.0

## Enough drawn frames for a disturbed sheet to have come back to hanging — well
## over a second at [constant Cloth.SPRING]'s fifteen or so radians a second and
## [constant Cloth.DRAG]'s damping.
const SETTLE_FRAMES: int = 90

## How far a rag left hanging under its own weight strays from the flat shape, in
## metres, with room to spare.
##
## Measured at about 0.02 — a sheet pinned along one edge tips about that far off
## the plane before [constant Cloth.SPRING] holds it, which is a droop you can see
## on a 32 cm rag and nothing like the 8 cm [constant Cloth.STRAY] would allow. The
## number is a ceiling on the resting shape rather than the resting shape itself,
## because the exact droop is the simulation's business and pinning it here would
## be writing the integrator down twice.
const HANGING: float = 0.03

## How far off its resting shape counts as having been disturbed, in metres. Well
## past [constant HANGING], so a rag that had merely gone on hanging could not pass
## for one that had been thrown.
const DISTURBED: float = 0.05

var _rag: ClothRag = null


func before_each() -> void:
	_rag = ClothRag.new(SPAN)
	add_child_autofree(_rag)
	await wait_process_frames(1)


## The mesh's own box, which is what a [PlaneMesh] of the same size would have
## reported and so the honest way to ask whether this is still that rectangle.
func _box() -> AABB:
	return _rag.get_aabb()


## The furthest any point of the sheet has strayed from where the flat shape puts
## it.
##
## What every "did it move" assertion below reads, in preference to the mesh's own
## box: a sheet that has tipped off its pinned edge is shorter in projection as
## well as thicker, so a box conflates two things and this does not.
func _worst_stray() -> float:
	var cloth: Cloth = _rag.cloth()
	var worst: float = 0.0
	for index: int in cloth.count():
		worst = maxf(worst, cloth.point(index).distance_to(cloth.placed_point(index)))
	return worst


## The one surface the sheet is built into.
func _surface() -> Array:
	return (_rag.mesh as ArrayMesh).surface_get_arrays(0)


## Read out into a typed local rather than cast on the way back: an [Array] hands
## back [Variant], and this project's warning levels treat casting one as an error
## rather than as a narrowing. The same reading-out
## [method Garage._spend_the_trigger] does with a raycast result.
func _vertices() -> PackedVector3Array:
	var vertices: PackedVector3Array = _surface()[Mesh.ARRAY_VERTEX]
	return vertices


func _normals() -> PackedVector3Array:
	var normals: PackedVector3Array = _surface()[Mesh.ARRAY_NORMAL]
	return normals


func _indices() -> PackedInt32Array:
	var indices: PackedInt32Array = _surface()[Mesh.ARRAY_INDEX]
	return indices


# ---- the rectangle it stands in for ------------------------------------------


func test_settled_it_is_exactly_the_plane_the_catalogue_asked_for() -> void:
	# The substitution, in one assertion. A rag that came out a centimetre narrow
	# would be a rag the roll-up icon disagrees with, and nothing else in the game
	# would notice. Settled first — see the class docs: a hanging cloth is not flat,
	# and it is not supposed to be.
	_rag.settle()
	var box: AABB = _box()
	assert_almost_eq(box.size.x, SPAN.x, TOLERANCE, "x is a width")
	assert_almost_eq(box.size.z, SPAN.y, TOLERANCE, "z is a depth")
	assert_almost_eq(box.size.y, 0.0, TOLERANCE, "and a cloth at rest is flat")
	assert_almost_eq(
		box.get_center(), Vector3.ZERO, Vector3.ONE * TOLERANCE, "centred on its own origin"
	)


func test_it_is_a_woven_sheet_rather_than_a_single_quad() -> void:
	# The tessellation itself. One vertex per point of the [Cloth] and two triangles
	# per quad between them — a mesh that had quietly stayed one quad would pass
	# every measurement above and could not ripple.
	var points: int = _rag.cloth().count()
	assert_eq(points, ClothRag.ACROSS * ClothRag.DOWN, "a point per node of the grid")
	assert_eq(_vertices().size(), points, "and a vertex per point")
	var quads: int = (ClothRag.ACROSS - 1) * (ClothRag.DOWN - 1)
	assert_eq(_indices().size(), quads * 6, "two triangles a quad, three indices a triangle")


func test_a_settled_sheet_faces_the_way_a_plane_of_the_same_size_would() -> void:
	# Which side is the front. The catalogue's rag is a plane and a plane's face is
	# its +Y, so a sheet whose normals came out inverted would light from behind —
	# and would do it without changing a single vertex, which is exactly the sort of
	# thing a size assertion cannot see.
	_rag.settle()
	for normal: Vector3 in _normals():
		assert_almost_eq(normal, Vector3.UP, Vector3.ONE * TOLERANCE)


# ---- and the part that makes it cloth ----------------------------------------


func test_a_rag_left_alone_hangs_rather_than_lying_flat() -> void:
	# That gravity reaches it at all, which every measurement on a settled sheet
	# would pass without. A rag pinned along one edge droops off it — that is the
	# whole of what makes it cloth rather than a quad — and it droops by a couple of
	# centimetres rather than by the eight [constant Cloth.STRAY] would allow.
	_rag.settle()
	await wait_process_frames(SETTLE_FRAMES)
	assert_gt(_worst_stray(), 0.0, "it hangs off its own pinned edge")
	assert_lt(_worst_stray(), HANGING, "and it hangs a little rather than folding in half")


func test_a_hand_yanking_it_across_the_room_leaves_it_trailing() -> void:
	# The whole reason this is simulated in world space rather than rippled by a
	# shader: the sheet is disturbed by the hand having moved, which is a fact no
	# vertex program has access to. One frame after a two-metre jump the rag is a
	# long way from the shape it is meant to be.
	_rag.settle()
	_rag.position += Vector3.UP * YANK
	await wait_process_frames(1)
	assert_gt(_worst_stray(), DISTURBED, "the cloth did not keep up with the hand")


func test_and_it_gathers_itself_back_up_a_moment_later() -> void:
	# The other half. A rag that trailed and stayed crumpled would be a rag that had
	# been ruined rather than thrown, and the tool would drift further from the
	# rectangle it stands in for on every press.
	_rag.settle()
	_rag.position += Vector3.UP * YANK
	await wait_process_frames(1)
	assert_gt(_worst_stray(), DISTURBED, "it was disturbed to begin with")
	await wait_process_frames(SETTLE_FRAMES)
	assert_lt(_worst_stray(), HANGING, "and it is back to merely hanging")


func test_settling_it_flattens_the_sheet_at_once() -> void:
	# What [method ViewModel._on_equipped_changed] calls when a rag comes back up.
	# Without it the sheet would still be wherever it was left several presses and
	# half a lap around the car ago, and would spend its first second on screen
	# flying across the room to catch up.
	_rag.position += Vector3.UP * YANK
	await wait_process_frames(1)
	assert_gt(_worst_stray(), DISTURBED, "it was disturbed to begin with")
	_rag.settle()
	assert_almost_eq(_worst_stray(), 0.0, TOLERANCE, "and now it is flat, this frame")


func test_a_rag_nobody_is_holding_costs_nothing() -> void:
	# Four tools in five are not on screen, and a belt that stepped all of them
	# would pay for a simulation nobody can see. Safe precisely because
	# [method ClothRag.settle] places the sheet rather than resuming it — a rag
	# coming back up does not care where it was left.
	_rag.visible = false
	var before: PackedVector3Array = _vertices()
	_rag.position += Vector3.UP * YANK
	await wait_process_frames(SETTLE_FRAMES)
	assert_eq(_vertices(), before, "an unheld rag is not simulated")
