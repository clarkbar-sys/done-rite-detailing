## Unit tests for [PanelResolution] — the arithmetic that turns a panel's own
## box into the tile resolution its [GrimeMap] is built at.
##
## Under tests/unit/ for the reason [code]tests/unit/test_box_projection.gd[/code]
## gives: this is maths on an [AABB], nothing else, and it stays that way whether
## it is run against a made-up box or a real panel's.
extends GutTest

## A wheel-sized box: two thirds of a metre across, the number
## [code]tests/fixtures/blockout_car.tscn[/code] and the pack's own wheels both use. Below
## [constant PanelResolution.MIN_TILE_PIXELS]'s reach, so this is what proves the
## floor holds.
const WHEEL: AABB = AABB(Vector3(-0.33, -0.11, -0.33), Vector3(0.66, 0.22, 0.66))

## A door-shaped box close to the one the blockout was originally tuned
## against: about two metres on its longest axis, which
## [constant PanelResolution.TEXELS_PER_METRE] is calibrated to land on the old
## flat [code]64[/code] for.
const DOOR: AABB = AABB(Vector3(-0.75, 0.0, -1.0), Vector3(1.5, 0.9, 2.0))

## A [MeshCar] body's rough shape: a touch over four metres long, the sedan
## reference length from [code]scripts/build-car-pack.py[/code].
const SEDAN_BODY: AABB = AABB(Vector3(-0.95, -0.7, -2.15), Vector3(1.9, 1.4, 4.3))

## Longer than any style in the pack — see [code]tests/integration/test_mesh_car.gd[/code]'s
## [code]LENGTH_M[/code] band — so this is what proves the ceiling holds rather
## than an unbounded panel spending unbounded memory.
const LIMOUSINE_BODY: AABB = AABB(Vector3(-0.95, -0.7, -4.5), Vector3(1.9, 1.4, 9.0))

## A box with one axis flattened to nothing, the shape a degenerate panel or a
## test fixture might hand this by mistake.
const FLAT: AABB = AABB(Vector3(-1.0, 0.0, -1.0), Vector3(2.0, 0.0, 2.0))


func test_a_wheel_sized_panel_is_floored_at_the_old_flat_number() -> void:
	# 0.66 m * 32 px/m is about 21 px — coarser than the blockout's wheels ever
	# were. The floor is exactly the old constant, so nothing on the car gets
	# blockier for this landing.
	assert_eq(PanelResolution.tile_pixels_for(WHEEL), PanelResolution.MIN_TILE_PIXELS)


func test_a_door_sized_panel_lands_near_the_old_flat_number() -> void:
	# The whole point of the calibration: a panel about the size the blockout was
	# tuned against comes out at (or just above) the number that panel always had.
	var pixels: int = PanelResolution.tile_pixels_for(DOOR)
	assert_gte(pixels, PanelResolution.MIN_TILE_PIXELS, "a two-metre panel undershot the floor")
	assert_lte(pixels, PanelResolution.MIN_TILE_PIXELS + 10, "and overshot it by more than a hair")


func test_a_sedan_body_is_sized_up_from_the_flat_number() -> void:
	# 4.3 m * 32 px/m is about 138, clamped to the ceiling — this is the panel
	# PanelResolution exists for, and it must actually be finer than the old flat
	# 64 to be worth the change.
	var pixels: int = PanelResolution.tile_pixels_for(SEDAN_BODY)
	assert_eq(pixels, PanelResolution.MAX_TILE_PIXELS)
	assert_gt(
		pixels, PanelResolution.MIN_TILE_PIXELS, "a car-length body must beat the old flat 64"
	)


func test_nothing_in_the_pack_can_ask_for_more_than_the_ceiling() -> void:
	# A limousine well past the longest style measured in the pack — proof the
	# memory bound is a real ceiling and not a number that happens not to bite
	# yet.
	assert_eq(PanelResolution.tile_pixels_for(LIMOUSINE_BODY), PanelResolution.MAX_TILE_PIXELS)


func test_the_longest_axis_decides_it_not_the_others() -> void:
	# A box wide on one axis and thin on the other two should be sized off the
	# wide one, the same way a face's own tile is — see BoxProjection's class
	# docs on why the dominant axis is what a face is measured against.
	var wide_and_flat: AABB = AABB(Vector3(-2.0, 0.0, -0.1), Vector3(4.0, 0.02, 0.2))
	assert_eq(
		PanelResolution.tile_pixels_for(wide_and_flat),
		PanelResolution.tile_pixels_for(AABB(Vector3.ZERO, Vector3(4.0, 4.0, 4.0))),
		"a 4 m panel should size the same whichever axis carries the length",
	)


func test_a_flattened_box_still_answers_something_sane() -> void:
	# The degenerate case: an axis of zero must not produce a zero, a negative or
	# an infinity — just the floor, the same as any other panel too small to want
	# raising.
	var pixels: int = PanelResolution.tile_pixels_for(FLAT)
	assert_eq(pixels, PanelResolution.MIN_TILE_PIXELS)


func test_the_answer_is_monotonic_in_the_longest_axis() -> void:
	# Bigger panels never get a smaller number than smaller ones — the property
	# that makes "the body is the panel that needed this" true in general and not
	# just for the sedan.
	var small: int = PanelResolution.tile_pixels_for(AABB(Vector3.ZERO, Vector3(1.0, 1.0, 1.0)))
	var big: int = PanelResolution.tile_pixels_for(AABB(Vector3.ZERO, Vector3(3.0, 1.0, 1.0)))
	assert_gte(big, small)
