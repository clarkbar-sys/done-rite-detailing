## Unit tests for [GrimeMap] — what is sitting on one panel, and the bookkeeping
## that says when a bit of it is done.
##
## Under tests/unit/ despite owning an [Image] and an [ImageTexture]: neither
## needs a scene tree, a renderer or a frame, which is the rule this project
## sorts by. That this is testable at all without rendering anything is the whole
## reason the mask is painted on the CPU rather than into a [SubViewport] — the
## class docs argue it, and this file is what the argument bought.
extends GutTest

## A door-sized panel, in the panel's own space. Not square on any axis, on
## purpose: a map that only ever saw cubes would let an axis get swapped
## somewhere and nothing would notice.
const PANEL: AABB = AABB(Vector3(-0.1, 0.0, -1.5), Vector3(0.2, 1.2, 3.0))

## Small and fast. The atlas is three of these across and two down, so a map here
## is 48x32 — big enough to have an inside and an outside to a brush, small
## enough that a test can walk every pixel of it.
const TILE: int = 16

## Two patches to a tile, which is twelve to a panel. Few enough to reason about
## and more than one, which is what a test of "did the right patch ring" needs.
const PATCHES: int = 2

## A ten-thousandth, for numbers that are all fractions of one.
const TOLERANCE: float = 0.0001

var _map: GrimeMap = null


func before_each() -> void:
	_map = GrimeMap.new(PANEL, TILE, PATCHES)


## The middle of the panel's right-hand face, which is where most of what follows
## points the water.
func _middle() -> Vector3:
	return Vector3(0.1, 0.6, 0.0)


## Washes the middle of the right-hand face until nothing more comes off, and
## says how many patches finished. Bounded rather than a `while`, because a test
## that can hang is a CI job that times out with no output.
func _wash_it_clean(at: Vector3, radius: float) -> int:
	var rung: int = 0
	for _sweep: int in 400:
		rung += _map.wash(at, Vector3.RIGHT, radius, 0.05).size()
	return rung


# ---- what a fresh panel looks like --------------------------------------------


func test_a_fresh_panel_is_filthy_everywhere() -> void:
	assert_almost_eq(_map.remaining(), 1.0, TOLERANCE)
	assert_almost_eq(_map.mud_at(_middle(), Vector3.RIGHT), GrimeMap.FILTHY, TOLERANCE)
	assert_almost_eq(_map.mud_at(Vector3(0.0, 1.2, 0.0), Vector3.UP), GrimeMap.FILTHY, TOLERANCE)
	assert_false(_map.is_clean(), "and it is not done")


func test_the_atlas_is_three_tiles_by_two() -> void:
	assert_eq(_map.image().get_width(), TILE * BoxProjection.COLUMNS)
	assert_eq(_map.image().get_height(), TILE * BoxProjection.ROWS)


func test_a_fresh_panel_has_no_product_no_shine_and_no_bare_paint() -> void:
	# The one seeding the conservation law allows: every unit in the mud bucket.
	# A panel that started with bare paint on it would be a panel a sponge works
	# on before the water has run.
	assert_almost_eq(_map.product(), 0.0, TOLERANCE, "the product")
	assert_almost_eq(_map.shine(), 0.0, TOLERANCE, "the shine")
	assert_almost_eq(_map.bare_at(_middle(), Vector3.RIGHT), 0.0, TOLERANCE, "the bare paint")
	assert_false(_map.is_finished(), "and it is certainly not done")


func test_the_patch_count_is_the_atlas_diced_by_the_knob() -> void:
	assert_eq(_map.patches(), BoxProjection.COLUMNS * PATCHES * BoxProjection.ROWS * PATCHES)


# ---- what washing does --------------------------------------------------------


func test_washing_takes_mud_off_where_the_water_lands() -> void:
	# The brush is deliberately several texels across here. A jet only a texel
	# wide still works — [method test_a_jet_smaller_than_a_texel_still_does_something]
	# holds that — but the pixel under the point is then offset from the middle of
	# the splash by up to half a texel, so how much comes off *at the sample* is a
	# statement about the resolution rather than about the wash.
	_map.wash(_middle(), Vector3.RIGHT, 0.4, 0.4)
	assert_lt(_map.mud_at(_middle(), Vector3.RIGHT), GrimeMap.FILTHY - 0.3)
	assert_lt(_map.remaining(), 1.0, "and the total noticed")


func test_washing_one_face_leaves_the_others_alone() -> void:
	# The property the six-plane projection exists for, asserted on the thing that
	# actually stores it rather than on the arithmetic that places it.
	_wash_it_clean(_middle(), 0.6)
	assert_almost_eq(
		_map.mud_at(Vector3(-0.1, 0.6, 0.0), Vector3.LEFT),
		GrimeMap.FILTHY,
		TOLERANCE,
		"the other flank was washed too"
	)
	assert_almost_eq(
		_map.mud_at(Vector3(0.0, 1.2, 0.0), Vector3.UP),
		GrimeMap.FILTHY,
		TOLERANCE,
		"the top was washed too"
	)


func test_the_brush_falls_off_toward_its_edge() -> void:
	# Soft across its radius rather than a disc with a hard rim, so a jet held
	# still leaves a gradient and not a coin.
	_map.wash(_middle(), Vector3.RIGHT, 0.5, 0.5)
	var centre: float = _map.mud_at(_middle(), Vector3.RIGHT)
	var edge: float = _map.mud_at(_middle() + Vector3(0.0, 0.0, 0.42), Vector3.RIGHT)
	assert_lt(centre, edge, "the middle of the jet should take more off than its edge")


func test_a_jet_smaller_than_a_texel_still_does_something() -> void:
	# At the far end of the reach a brush can round to nothing, and a tool that
	# visibly does nothing reads as broken rather than as out of range.
	_map.wash(_middle(), Vector3.RIGHT, 0.00001, 0.5)
	assert_lt(_map.mud_at(_middle(), Vector3.RIGHT), GrimeMap.FILTHY)


func test_washing_nothing_takes_nothing_off() -> void:
	assert_eq(_map.wash(_middle(), Vector3.RIGHT, 0.2, 0.0).size(), 0)
	assert_almost_eq(_map.remaining(), 1.0, TOLERANCE)


# ---- and when it is done ------------------------------------------------------


func test_a_spot_can_be_washed_all_the_way_to_nothing() -> void:
	# The reason the brush subtracts instead of multiplying: an exponential
	# approach to clean never arrives, and a patch that cannot reach zero is a
	# ding the player can never earn. Worth its own test because the failure is
	# not visible — the paint looks clean either way.
	_wash_it_clean(_middle(), 0.3)
	assert_eq(
		_map.mud_at(_middle(), Vector3.RIGHT), 0.0, "the middle of the jet is not fully clean"
	)


func test_finishing_a_patch_is_reported_once() -> void:
	var rung: int = _wash_it_clean(_middle(), 2.0)
	assert_gt(rung, 0, "nothing was ever reported clean")
	# Every patch of the face, and no patch twice — a bell that rang on every tick
	# the patch was already clean would be a slot machine with the arm stuck down.
	assert_eq(rung, PATCHES * PATCHES, "a patch rang more than once, or one never rang")


func test_a_patch_that_has_rung_stays_clean() -> void:
	_wash_it_clean(_middle(), 2.0)
	var face: int = _patch_under(_middle())
	assert_true(_map.is_patch_clean(face), "the patch under the jet")
	assert_false(
		_map.is_patch_clean(_patch_under(Vector3(-0.1, 0.6, 0.0))), "and not one elsewhere"
	)


func test_a_patch_index_nobody_has_is_not_clean() -> void:
	# Rather than throwing: the caller is a signal handler and "out of range" is
	# not a thing worth crashing a frame over.
	assert_false(_map.is_patch_clean(-1))
	assert_false(_map.is_patch_clean(_map.patches()))


func test_the_whole_panel_is_only_done_when_every_face_is() -> void:
	# Six faces on a box and the player can only ever reach some of them, which
	# is why the ding rides on patches. This is the honest question still
	# answering honestly: one face washed is not a washed panel.
	_wash_it_clean(_middle(), 2.0)
	assert_false(_map.is_clean(), "one face of six is not a clean panel")
	assert_between(_map.remaining(), 0.5, 0.99, "and the total is most of the way still dirty")


# ---- the totals stay honest ---------------------------------------------------


func test_the_running_total_matches_the_pixels_it_claims_to_describe() -> void:
	# The drift this is guarding against is silent and one-directional: an
	# eight-bit image rounds every write, and a total that subtracted the
	# unrounded amount would creep toward claiming a patch is finished while mud
	# is still on it. So the total is checked against a walk of the actual image
	# after a few hundred overlapping washes.
	for step: int in 300:
		var along: float = -1.4 + 0.01 * float(step)
		_map.wash(Vector3(0.1, 0.6, along), Vector3.RIGHT, 0.15, 0.07)
	var counted: float = 0.0
	var image: Image = _map.image()
	for y: int in image.get_height():
		for x: int in image.get_width():
			counted += image.get_pixel(x, y).r
	var pixels: float = float(image.get_width() * image.get_height())
	assert_almost_eq(_map.remaining(), counted / pixels, TOLERANCE)


func test_the_box_is_kept_for_whoever_has_to_project_into_it() -> void:
	assert_eq(_map.box(), PANEL)


func test_the_texture_is_the_same_one_after_a_wash() -> void:
	# Updated in place rather than replaced, so a material handed this once never
	# has to be handed it again — a wash that swapped the texture would leave
	# every panel showing the mud it had when the shader was built.
	var before: ImageTexture = _map.texture()
	_map.wash(_middle(), Vector3.RIGHT, 0.2, 0.5)
	assert_same(_map.texture(), before)


## Which patch a point on the right-hand face belongs to, worked out the way the
## map does it rather than by knowing the answer.
func _patch_under(at: Vector3) -> int:
	var image: Image = _map.image()
	var normal: Vector3 = Vector3.RIGHT if at.x > 0.0 else Vector3.LEFT
	var uv: Vector2 = BoxProjection.uv_for(PANEL, at, normal)
	var x: int = clampi(int(uv.x * float(image.get_width())), 0, image.get_width() - 1)
	var y: int = clampi(int(uv.y * float(image.get_height())), 0, image.get_height() - 1)
	var across: int = BoxProjection.COLUMNS * PATCHES
	return (
		(y * BoxProjection.ROWS * PATCHES / image.get_height()) * across
		+ (x * across / image.get_width())
	)
