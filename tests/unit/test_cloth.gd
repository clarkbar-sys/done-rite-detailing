## Unit tests for [Cloth] — the mass-spring sheet the drying rag is drawn from.
##
## Under tests/unit/ because the whole class is arithmetic on an array of points:
## a transform and a pull in, a set of positions out, no mesh and no tree. That
## the positions really become triangles, and that the hand really drags the
## pinned edge around, is [code]tests/integration/test_cloth_rag.gd[/code]'s.
##
## [b]What is worth pinning about a simulation.[/b] Not the exact position of any
## point — that is the whole of what a simulation is for, and asserting on it
## would be writing the integrator down twice. What is asserted here is the set of
## promises the rest of the game is allowed to rely on:
##
## - the pinned edge is the hand and never moves on its own
## - a sheet nobody is disturbing stays exactly flat
## - a sheet somebody is disturbing comes back to flat
## - nothing ever gets further from flat than [constant Cloth.STRAY]
##
## The last one is the load-bearing one. [method ViewModel._carry_for] lifts the
## rag off the paint by exactly that number so the cloth cannot billow through a
## door, and a bound that quietly stopped holding would show up as a rag inside a
## car rather than as a failure here.
extends GutTest

## A ten-thousandth of a metre. The grid below is laid out by exact division, so
## this is float noise rather than slack.
const TOLERANCE: float = 0.0001

## The rag's own size, from [method DetailingTool.catalogue]. Written here rather
## than read off it for [code]test_wand_carry.gd[/code]'s reason: this suite is
## about a sheet of a given size, not about which tool happens to have it.
const SPAN: Vector2 = Vector2(0.32, 0.28)

## How finely it is diced, from [ClothRag]. Odd on both axes, which puts a point
## in the middle of the sheet — the place a cloth held by one edge does most of
## its moving, and so the place worth asserting about.
const ACROSS: int = 7
const DOWN: int = 7

## A frame's worth of time, at the rate the game is drawn at.
const STEP: float = 1.0 / 60.0

## Long enough for a disturbance to have died away — [constant Cloth.SPRING] is
## about 15 rad/s, so half a second is several oscillations under
## [constant Cloth.DRAG].
const SETTLE_STEPS: int = 120

## Real gravity, used to prove the sheet is pullable rather than because the rag
## is dropped in at this rate — [constant ClothRag.SAG] is a fifth of it, for
## reasons that belong to the rag rather than to the cloth.
const GRAVITY: Vector3 = Vector3(0.0, -9.8, 0.0)

## Somewhere a long way from the origin, turned, so a transform that was quietly
## being ignored could not coincide with the answer.
const ELSEWHERE: Transform3D = Transform3D(Basis(Vector3.RIGHT, PI * 0.25), Vector3(1.4, -0.7, 2.9))

var _cloth: Cloth = null


func before_each() -> void:
	_cloth = Cloth.new(SPAN, ACROSS, DOWN)


## The index of the point furthest from the pinned edge and nearest the middle of
## it — the one with the most freedom to move, and so the one every "did it move"
## assertion below reads.
func _loosest() -> int:
	return _cloth.index_of(_cloth.columns() / 2, _cloth.rows() - 1)


## The furthest any point has strayed from where the flat shape puts it.
func _worst_stray() -> float:
	var worst: float = 0.0
	for index: int in _cloth.count():
		worst = maxf(worst, _cloth.point(index).distance_to(_cloth.placed_point(index)))
	return worst


## The worst any neighbouring pair is off the distance it was built at, as a
## fraction of that distance. Rebuilt from the rest grid rather than read off the
## class's own link table, so this is not the cloth checking itself.
func _worst_strain() -> float:
	var worst: float = 0.0
	for row: int in _cloth.rows():
		for column: int in _cloth.columns():
			var here: int = _cloth.index_of(column, row)
			if column < _cloth.columns() - 1:
				worst = maxf(worst, _strain(here, _cloth.index_of(column + 1, row)))
			if row < _cloth.rows() - 1:
				worst = maxf(worst, _strain(here, _cloth.index_of(column, row + 1)))
	return worst


func _strain(first: int, second: int) -> float:
	var rest: float = _cloth.rest_point(first).distance_to(_cloth.rest_point(second))
	if is_zero_approx(rest):
		return 0.0
	return absf(_cloth.point(first).distance_to(_cloth.point(second)) - rest) / rest


func _run(steps: int, pull: Vector3, frame: Transform3D) -> void:
	for step: int in steps:
		_cloth.hold(frame)
		_cloth.step(STEP, pull)


# ---- the flat sheet it starts as ---------------------------------------------


func test_the_rest_grid_is_exactly_the_rectangle_it_was_asked_for() -> void:
	# What lets a [ClothRag] stand in for the [PlaneMesh] the catalogue asks for:
	# same extent, same origin, laid in the same plane. Measured corner to corner
	# rather than point by point, which is what a mesh's own box would report.
	var low: Vector3 = _cloth.rest_point(0)
	var high: Vector3 = _cloth.rest_point(_cloth.count() - 1)
	assert_almost_eq(high.x - low.x, SPAN.x, TOLERANCE, "x is a width")
	assert_almost_eq(high.z - low.z, SPAN.y, TOLERANCE, "z is a depth")
	assert_almost_eq(low + high, Vector3.ZERO, Vector3.ONE * TOLERANCE, "centred on the origin")
	for index: int in _cloth.count():
		assert_almost_eq(_cloth.rest_point(index).y, 0.0, TOLERANCE, "and flat")


func test_it_is_diced_the_way_it_was_asked_for() -> void:
	assert_eq(_cloth.columns(), ACROSS)
	assert_eq(_cloth.rows(), DOWN)
	assert_eq(_cloth.count(), ACROSS * DOWN, "and no points anybody forgot to make")
	assert_eq(_cloth.points().size(), _cloth.count(), "with one position each")
	assert_almost_eq(_cloth.size().distance_to(SPAN), 0.0, TOLERANCE)


func test_a_sheet_with_no_interior_is_refused_rather_than_divided_by() -> void:
	# One row or column is a line with nothing to ripple, and zero is a division by
	# nothing when the grid is laid out. Clamped up to the floor rather than
	# rejected, because the caller has asked for a cloth and the smallest real one
	# is a better answer than a crash.
	var thin: Cloth = Cloth.new(SPAN, 1, 0)
	assert_eq(thin.columns(), Cloth.MIN_SPAN)
	assert_eq(thin.rows(), Cloth.MIN_SPAN)
	for index: int in thin.count():
		assert_true(thin.point(index).is_finite(), "and every point of it is a real place")


func test_the_pinned_edge_is_the_first_row_and_only_the_first_row() -> void:
	# Which points the hand owns. A cloth with nothing pinned drifts off on the
	# first breath of gravity; one pinned everywhere is a trampoline.
	for column: int in _cloth.columns():
		assert_true(_cloth.is_pinned(_cloth.index_of(column, 0)), "column %d of row 0" % column)
	for row: int in range(1, _cloth.rows()):
		for column: int in _cloth.columns():
			assert_false(_cloth.is_pinned(_cloth.index_of(column, row)), "row %d is free" % row)


# ---- what a hand does to it --------------------------------------------------


func test_holding_it_somewhere_puts_the_pinned_edge_there() -> void:
	# The hand, in one call: the flat shape is placed by the transform and the
	# pinned points are put on it. Read against the transform applied by hand, so a
	# cloth that placed its own grid differently would fail rather than agree with
	# itself.
	_cloth.hold(ELSEWHERE)
	for index: int in _cloth.count():
		assert_almost_eq(
			_cloth.placed_point(index),
			ELSEWHERE * _cloth.rest_point(index),
			Vector3.ONE * TOLERANCE,
			"placed %d" % index
		)
		if _cloth.is_pinned(index):
			assert_almost_eq(
				_cloth.point(index),
				_cloth.placed_point(index),
				Vector3.ONE * TOLERANCE,
				"pinned %d" % index
			)


func test_the_pinned_edge_never_moves_however_hard_it_is_pulled() -> void:
	# The promise everything else rests on. A pinned point that drifted would take
	# the rag out of the player's hand a centimetre at a time, which is the kind of
	# bug that gets filed as "the cloth slides off after a while".
	_run(SETTLE_STEPS, GRAVITY * 20.0, ELSEWHERE)
	for index: int in _cloth.count():
		if not _cloth.is_pinned(index):
			continue
		assert_almost_eq(
			_cloth.point(index),
			_cloth.placed_point(index),
			Vector3.ONE * TOLERANCE,
			"pinned %d has come loose" % index
		)


func test_a_sheet_nobody_is_disturbing_stays_exactly_flat() -> void:
	# The other end of it: a rag held still with nothing pulling on it is the
	# rectangle the catalogue asked for and does not wander off on numerical noise.
	_cloth.hold(ELSEWHERE)
	_cloth.settle()
	_run(SETTLE_STEPS, Vector3.ZERO, ELSEWHERE)
	assert_almost_eq(_worst_stray(), 0.0, TOLERANCE, "an undisturbed sheet is where it was put")


func test_gravity_sags_the_free_points_and_only_the_free_points() -> void:
	# That the thing is pullable at all, which every assertion above would pass
	# without. The far edge drops and the hand does not, which is the shape of a
	# cloth being held.
	_cloth.hold(Transform3D.IDENTITY)
	_cloth.settle()
	_run(SETTLE_STEPS, GRAVITY, Transform3D.IDENTITY)
	var loose: int = _loosest()
	assert_lt(_cloth.point(loose).y, _cloth.placed_point(loose).y, "the far edge hangs")
	assert_lt(_worst_stray(), Cloth.STRAY + TOLERANCE, "and not past the ceiling")


# ---- and the ceiling on all of it --------------------------------------------


func test_nothing_ever_gets_further_from_flat_than_the_ceiling() -> void:
	# The bound the rag's own standoff is set from. Driven with the worst input
	# there is — the hand teleporting metres between two frames, which is what a
	# tool being brought up to the paint actually does — and then with gravity
	# twenty times over on top of it.
	_cloth.hold(Transform3D.IDENTITY)
	_cloth.settle()
	for step: int in 8:
		_cloth.hold(ELSEWHERE if step % 2 == 0 else Transform3D.IDENTITY)
		_cloth.step(STEP, GRAVITY * 20.0)
		assert_lt(_worst_stray(), Cloth.STRAY + TOLERANCE, "at step %d" % step)


func test_a_sheet_thrown_across_the_room_pulls_itself_back_together() -> void:
	# What the relaxation passes are for, stated as the thing a player sees: the rag
	# trails when the arm throws it and is a rectangle again a moment later. A sheet
	# that only obeyed the ceiling above would arrive as a bag of points held inside
	# a box.
	_cloth.hold(Transform3D.IDENTITY)
	_cloth.settle()
	_cloth.hold(ELSEWHERE)
	_cloth.step(STEP, GRAVITY)
	assert_gt(_worst_stray(), 0.0, "the throw disturbed it")
	_run(SETTLE_STEPS, Vector3.ZERO, ELSEWHERE)
	assert_lt(_worst_strain(), 0.01, "and every link is back to the length it was built at")


func test_settling_it_drops_the_whole_sheet_onto_the_hand() -> void:
	# What a rag being taken out of the toolbelt wants: it was last simulated
	# wherever the player was standing several presses ago, and easing it across the
	# room from there would be a rag arriving late to its own swap.
	_cloth.hold(Transform3D.IDENTITY)
	_cloth.settle()
	_run(SETTLE_STEPS, GRAVITY, Transform3D.IDENTITY)
	assert_gt(_worst_stray(), 0.0, "it had moved")
	_cloth.hold(ELSEWHERE)
	_cloth.settle()
	assert_almost_eq(_worst_stray(), 0.0, TOLERANCE, "and now it is exactly where the hand is")


func test_a_step_of_no_time_changes_nothing() -> void:
	# A paused game and a frame the engine reported as zero are both things that
	# happen, and dividing by either is not.
	_cloth.hold(ELSEWHERE)
	_cloth.settle()
	_cloth.step(0.0, GRAVITY)
	_cloth.step(-1.0, GRAVITY)
	assert_almost_eq(_worst_stray(), 0.0, TOLERANCE, "no time passed, so nothing did")
