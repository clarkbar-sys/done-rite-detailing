## Unit tests for [PanelReach] — where the player can get a tool onto a panel,
## which is the mask [GrimeMap] seeds mud through.
##
## Under tests/unit/ although the thing it describes is decided by raycasts,
## because none of the arithmetic here needs one: the poses, the aiming lattice,
## the atlas splat and the dilation are all pure, and [method Grime._reach_across]
## is the twenty lines that hold a space state. That split is the point — a
## reachability rule nobody could test without building a car and a physics world
## is a reachability rule nobody would change.
##
## So the hits below are handed in by name rather than cast for. What is being
## asserted is that a hit lands in the cell it should, that a brush grows it by as
## much as it should and no further, and that the growth stops at the seam between
## two faces of the atlas.
extends GutTest

## The same door-sized panel [code]tests/unit/test_grime_map.gd[/code] uses, and
## for the same reason: nothing about it is square, so an axis swapped anywhere
## below shows up as a number that is out by a factor of two and a half rather
## than as nothing at all.
const PANEL: AABB = AABB(Vector3(-0.1, 0.0, -1.5), Vector3(0.2, 1.2, 3.0))

## Two patches to a tile, twelve to a panel — [code]test_grime_map.gd[/code]'s
## dicing, so the two files are talking about the same grid.
const PATCHES: Vector2i = Vector2i(BoxProjection.COLUMNS * 2, BoxProjection.ROWS * 2)

## A car-sized box on the floor, for the pose and lattice tests. Roughly the
## sedan the bay parks: two metres across, one and a third high, four and a third
## long, sitting on the tarmac rather than straddling it.
const CAR: AABB = AABB(Vector3(-0.97, 0.0, -2.18), Vector3(1.95, 1.35, 4.37))

## The band the room's walk is fenced into — [member Garage.standoff_radius_min],
## [member Garage.orbit_radius], [member Garage.eye_height_min] and
## [member Garage.eye_height_max], copied rather than read off a [Garage] because
## building a room to get four floats is what this file exists not to do.
const NEAR: float = 1.6
const FAR: float = 5.6
const LOW: float = 1.1
const HIGH: float = 2.4

## A thousandth of a metre, for distances that are all metres.
const TOLERANCE: float = 0.001

var _reach: PanelReach = null


func before_each() -> void:
	_reach = PanelReach.new(PANEL, PATCHES)


## The middle of the panel's right-hand face — the same spot
## [code]test_grime_map.gd[/code] points its water at.
func _middle() -> Vector3:
	return Vector3(0.1, 0.6, 0.0)


## How many cells of the atlas fall in one tile.
func _tile() -> Vector2i:
	return Vector2i(_reach.grid().x / BoxProjection.COLUMNS, _reach.grid().y / BoxProjection.ROWS)


# ---- the grid -----------------------------------------------------------------


func test_the_mask_is_the_patch_grid_diced_finer() -> void:
	assert_eq(PanelReach.cells_for(PATCHES), PATCHES * PanelReach.CELLS_PER_PATCH)
	assert_eq(_reach.grid(), PATCHES * PanelReach.CELLS_PER_PATCH)


func test_every_cell_lies_wholly_inside_one_patch() -> void:
	# The property [method GrimeMap._seed_the_totals] adds a patch's capacity up
	# out of whole cells on: a cell grid that was not a whole multiple of the patch
	# grid would put cells across patch boundaries, and a patch short by a pixel is
	# a patch that never rings.
	assert_eq(_reach.grid().x % PATCHES.x, 0, "the cells do not divide by the patches across")
	assert_eq(_reach.grid().y % PATCHES.y, 0, "nor down")


func test_a_fresh_mask_reaches_nowhere() -> void:
	# Empty rather than full, deliberately: a mask nobody filled in seeds a panel
	# with no mud on it at all, which is visible on the first frame. The other
	# default would be the bug this class removes, silently.
	assert_eq(_reach.reached(), 0)
	assert_false(_reach.reaches(Vector2i(6, 6)), "the middle of a face nobody looked at")


func test_a_cell_off_the_grid_is_not_reachable() -> void:
	# Answered rather than errored, the way [method GrimeMap.is_patch_clean] is:
	# the caller is rounding pixels into cells and "off the edge" is not reachable
	# by any reading.
	assert_false(_reach.reaches(Vector2i(-1, 0)), "left of the atlas")
	assert_false(_reach.reaches(Vector2i(0, -1)), "above it")
	assert_false(_reach.reaches(_reach.grid()), "past the far corner")


# ---- what a hit marks ---------------------------------------------------------


func test_a_hit_marks_exactly_one_cell() -> void:
	_reach.saw(_middle(), Vector3.RIGHT)
	assert_eq(_reach.reached(), 1, "a hit is one cell until it is spread")
	var tile: Vector2i = _tile()
	assert_true(
		_reach.reaches(Vector2i(tile.x / 2, tile.y / 2)),
		"the middle of the panel did not mark the middle of its tile"
	)


func test_a_hit_marks_the_face_its_normal_points_out_of() -> void:
	# The whole of why the projection is six signed planes rather than three
	# absolute ones: the two flanks of a car must not share a cell.
	_reach.saw(_middle(), Vector3.RIGHT)
	var tile: Vector2i = _tile()
	assert_false(
		_reach.reaches(Vector2i(tile.x + tile.x / 2, tile.y / 2)),
		"the same spot seen from the left was marked too"
	)
	_reach.saw(Vector3(-0.1, 0.6, 0.0), Vector3.LEFT)
	assert_eq(_reach.reached(), 2, "and the left-hand face did not get its own cell")


func test_two_hits_in_one_cell_are_one_cell() -> void:
	_reach.saw(_middle(), Vector3.RIGHT)
	_reach.saw(_middle() + Vector3(0.0, 0.001, 0.001), Vector3.RIGHT)
	assert_eq(_reach.reached(), 1)


# ---- what a brush grows it by -------------------------------------------------


func test_a_brush_grows_a_hit_by_its_own_reach_on_each_axis() -> void:
	# A tile is not square in metres — this face is three metres along and 1.2 m
	# up — so a round brush is an ellipse in it, and the two reaches below are
	# different numbers. 0.35 m is 0.117 of the face across and 0.292 of it up,
	# which at twelve cells to a tile is 1.4 cells and 3.5, and so one and three.
	# Deliberately nowhere near a whole number of cells on either axis: a radius
	# that came out at exactly three would be a test that failed on whichever side
	# of it the last bit of a float landed.
	_reach.saw(_middle(), Vector3.RIGHT)
	_reach.spread(0.35)
	var tile: Vector2i = _tile()
	var at: Vector2i = Vector2i(tile.x / 2, tile.y / 2)
	assert_true(_reach.reaches(at + Vector2i(1, 0)), "one cell across")
	assert_false(_reach.reaches(at + Vector2i(2, 0)), "but not two")
	assert_true(_reach.reaches(at + Vector2i(0, 3)), "three cells down")
	assert_false(_reach.reaches(at + Vector2i(0, 4)), "but not four")


func test_a_brush_too_small_to_cross_a_cell_grows_nothing() -> void:
	_reach.saw(_middle(), Vector3.RIGHT)
	_reach.spread(0.01)
	assert_eq(_reach.reached(), 1, "a millimetre of brush marked a neighbour")


func test_spreading_nothing_marks_nothing() -> void:
	# The guard that matters for a panel no ray ever hit: growing an empty mask
	# must not fill it in, or a wing mirror nobody can see becomes a wing mirror
	# covered in mud nobody can clean.
	_reach.spread(0.5)
	assert_eq(_reach.reached(), 0)


func test_a_brush_does_not_grow_across_the_seam_between_two_faces() -> void:
	# The same rule [method GrimeMap._brush] follows: the atlas is six pictures
	# side by side, so a hit on the trailing edge of the right flank must not mark
	# the left flank's tile, which is the next thing along in the image and is the
	# other side of the car.
	_reach.saw(Vector3(0.1, 0.6, 1.5), Vector3.RIGHT)
	_reach.spread(0.6)
	var tile: Vector2i = _tile()
	assert_true(_reach.reaches(Vector2i(tile.x - 1, tile.y / 2)), "the edge of its own tile")
	assert_false(_reach.reaches(Vector2i(tile.x, tile.y / 2)), "and the tile next door")


func test_a_brush_does_not_grow_across_the_seam_onto_the_row_below() -> void:
	# The bottom of the tile is the top of the box: a face's tile runs down the
	# image as the panel's own axis runs up, which is [method BoxProjection.tile_uv]
	# and is why this hit is at the roof of the panel rather than at its sill.
	_reach.saw(Vector3(0.1, 1.2, 0.0), Vector3.RIGHT)
	_reach.spread(0.9)
	var tile: Vector2i = _tile()
	assert_true(_reach.reaches(Vector2i(tile.x / 2, tile.y - 1)), "the bottom of its own tile")
	assert_false(_reach.reaches(Vector2i(tile.x / 2, tile.y)), "and the tile under it")


# ---- where the player may stand -----------------------------------------------


func test_every_pose_is_inside_the_band_the_walk_is_fenced_into() -> void:
	var found: PackedVector3Array = PanelReach.eyes(CAR, NEAR, FAR, LOW, HIGH)
	assert_gt(found.size(), 0, "the band produced no poses at all")
	var middle: Vector3 = CAR.get_center()
	for eye: Vector3 in found:
		var out: float = Vector2(eye.x - middle.x, eye.z - middle.z).length()
		assert_between(out, NEAR - TOLERANCE, FAR + TOLERANCE, "a pose off the ring")
		assert_between(eye.y, LOW - TOLERANCE, HIGH + TOLERANCE, "a pose outside the lift")


func test_no_pose_stands_on_the_car() -> void:
	# The filter that stops the whole thing being a lie. The pack's colliders are
	# solid from both sides, so an eye inside the shell sees the inside of every
	# panel and would mark the underside of the car reachable — which is exactly
	# the mud this class exists to stop being laid.
	var found: PackedVector3Array = PanelReach.eyes(CAR, NEAR, FAR, LOW, HIGH)
	var footprint: Rect2 = Rect2(
		Vector2(CAR.position.x, CAR.position.z), Vector2(CAR.size.x, CAR.size.z)
	)
	for eye: Vector3 in found:
		assert_false(footprint.has_point(Vector2(eye.x, eye.z)), "a pose inside the bodywork")


func test_the_inner_ring_loses_the_poses_that_would_be_inside_the_car() -> void:
	# A sedan is four metres long, so the inner fence really does run through it
	# nose to tail: the ring at that radius keeps its flanks and drops its ends.
	var whole: int = PanelReach.RING_SAMPLES * PanelReach.ANGLE_SAMPLES * PanelReach.HEIGHT_SAMPLES
	var found: PackedVector3Array = PanelReach.eyes(CAR, NEAR, FAR, LOW, HIGH)
	assert_lt(found.size(), whole, "nothing was dropped, so the filter is not running")
	assert_gt(
		found.size(),
		PanelReach.ANGLE_SAMPLES * PanelReach.HEIGHT_SAMPLES,
		"more than the outer ring survived"
	)


func test_a_car_the_ring_clears_keeps_every_pose() -> void:
	var small: AABB = AABB(Vector3(-0.2, 0.0, -0.2), Vector3(0.4, 1.0, 0.4))
	var found: PackedVector3Array = PanelReach.eyes(small, NEAR, FAR, LOW, HIGH)
	assert_eq(
		found.size(), PanelReach.RING_SAMPLES * PanelReach.ANGLE_SAMPLES * PanelReach.HEIGHT_SAMPLES
	)


# ---- what those poses aim at --------------------------------------------------


func test_the_lattice_fills_the_car_and_stops_at_its_corners() -> void:
	var found: PackedVector3Array = PanelReach.targets(CAR)
	assert_gt(found.size(), 0, "no targets at all")
	var grown: AABB = CAR.grow(TOLERANCE)
	for target: Vector3 in found:
		assert_true(grown.has_point(target), "a target outside the car's box")
	assert_true(found.has(CAR.position), "the near corner is not aimed at")
	assert_true(found.has(CAR.end), "nor the far one")


func test_the_lattice_is_spaced_by_the_constant_that_says_so() -> void:
	# One step every [constant PanelReach.TARGET_SPACING], plus the far end, on
	# each axis — which is what makes the count predictable rather than a number
	# somebody wrote down after running it.
	var along: int = int(CAR.size.z / PanelReach.TARGET_SPACING) + 1
	var across: int = int(CAR.size.x / PanelReach.TARGET_SPACING) + 1
	var up: int = int(CAR.size.y / PanelReach.TARGET_SPACING) + 1
	assert_eq(PanelReach.targets(CAR).size(), along * across * up)


func test_the_lattice_is_capped_so_a_bus_does_not_cast_a_million_rays() -> void:
	var bus: AABB = AABB(Vector3.ZERO, Vector3(40.0, 40.0, 40.0))
	var most: int = PanelReach.MOST_TARGET_STEPS + 1
	assert_eq(PanelReach.targets(bus).size(), most * most * most)


func test_a_panel_thinner_than_a_step_still_gets_a_lattice() -> void:
	# A pane of glass is millimetres through, and [method PanelReach.targets] is
	# handed whole cars rather than panels — but the floor of one step is what
	# stops any degenerate axis dividing by zero.
	var pane: AABB = AABB(Vector3.ZERO, Vector3(0.01, 1.0, 1.0))
	assert_gt(PanelReach.targets(pane).size(), 0)
