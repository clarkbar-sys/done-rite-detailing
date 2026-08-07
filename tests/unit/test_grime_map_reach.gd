## Unit tests for [GrimeMap] carrying a [PanelReach] — a panel that is only
## partly somewhere the player can put a tool.
##
## A third file beside [code]test_grime_map.gd[/code] (the mask and the water) and
## [code]test_grime_map_layers.gd[/code] (the three passes and the conservation
## between them) for the reason those two are separate from each other: this one
## is about a single question — what happens at a texel nobody can reach — and
## every test here is an answer to it.
##
## [b]The trap this file exists for.[/b] Bare paint is the bucket that is not
## stored: it is [constant GrimeMap.UNITS] less the other three. So a texel seeded
## with nothing at all is, read literally, a texel entirely covered in bare paint —
## and a cleaner drawing from bare would happily lay a full coat of product on the
## underside of the car and bank every unit of it against a total that was sized
## without it. The refusal is in [method GrimeMap._touch], before any pixel is read,
## and most of what follows is that refusal asserted from a different direction
## each time.
extends GutTest

## [code]test_grime_map.gd[/code]'s panel, tile and dicing, so all three files are
## describing the same map.
const PANEL: AABB = AABB(Vector3(-0.1, 0.0, -1.5), Vector3(0.2, 1.2, 3.0))
const TILE: int = 16
const PATCHES: int = 2

## Wider than the whole face, so one press covers a tile end to end and a test can
## work a face without dragging a brush across it.
const WIDE: float = 3.0

## Passes of a tool at full strength. Three would do — the brush is subtractive
## and clamped, so a bucket empties in a couple of presses even at the edge of the
## falloff — and eight is the margin that keeps this from being a test about the
## falloff curve.
const PRESSES: int = 8

## A ten-thousandth, for numbers that are all fractions of one.
const TOLERANCE: float = 0.0001

var _map: GrimeMap = null


func before_each() -> void:
	_map = GrimeMap.new(PANEL, TILE, PATCHES, _only_the_right_face())


## The middle of the panel's right-hand face.
func _middle() -> Vector3:
	return Vector3(0.1, 0.6, 0.0)


## The middle of the left-hand face, which nothing below can reach.
func _far_side() -> Vector3:
	return Vector3(-0.1, 0.6, 0.0)


## A mask covering the whole of the right-hand face and nothing else.
##
## One hit and a brush far wider than the face, rather than a lattice of hits:
## [method PanelReach.spread] stops at the seam between two tiles, so a single
## enormous splash fills exactly one face and cannot leak into the five beside it —
## which is both the fixture this file wants and, incidentally, that rule asserted.
func _only_the_right_face() -> PanelReach:
	var reach: PanelReach = PanelReach.new(PANEL, GrimeMap.patch_grid_for(PATCHES))
	reach.saw(_middle(), Vector3.RIGHT)
	reach.spread(100.0)
	return reach


## A mask covering a patch in the middle of the right-hand face and nothing more —
## 0.4 m of brush around one hit, which is a few cells each way.
func _a_spot_on_the_right_face() -> PanelReach:
	var reach: PanelReach = PanelReach.new(PANEL, GrimeMap.patch_grid_for(PATCHES))
	reach.saw(_middle(), Vector3.RIGHT)
	reach.spread(0.4)
	return reach


## Every pass of the job at [param at] on the face [param facing] points out of,
## in order. The normal is a parameter and not [constant Vector3.RIGHT] written
## three times, because half the point of this file is running the same job at a
## face nobody can reach and getting nothing for it.
func _do_the_whole_job(at: Vector3, facing: Vector3) -> void:
	for _press: int in PRESSES:
		_map.wash(at, facing, WIDE, 1.0)
	for _press: int in PRESSES:
		_map.foam(at, facing, WIDE, 1.0)
	for _press: int in PRESSES:
		_map.buff(at, facing, WIDE, 1.0)


# ---- what a masked panel is seeded with ---------------------------------------


func test_the_mud_goes_on_where_the_player_can_reach() -> void:
	assert_almost_eq(_map.mud_at(_middle(), Vector3.RIGHT), GrimeMap.FILTHY, TOLERANCE)


func test_and_nowhere_else() -> void:
	# The user-visible half of #144, in one line: this is the underside of the car.
	assert_almost_eq(_map.mud_at(_far_side(), Vector3.LEFT), 0.0, TOLERANCE, "the far flank")
	assert_almost_eq(
		_map.mud_at(Vector3(0.0, 0.0, 0.0), Vector3.DOWN), 0.0, TOLERANCE, "the underside"
	)
	assert_almost_eq(_map.mud_at(Vector3(0.0, 1.2, 0.0), Vector3.UP), 0.0, TOLERANCE, "the roof")


func test_a_masked_panel_still_reads_entirely_dirty() -> void:
	# Because the capacity was counted from the same mask the mud was laid through.
	# A panel that read a sixth dirty on the frame it was built would put a progress
	# bar five sixths of the way along before anybody had touched it.
	assert_almost_eq(_map.remaining(), 1.0, TOLERANCE)
	assert_false(_map.is_clean(), "and it is not clean")
	assert_true(_map.has_reach(), "and there is work on it")


func test_an_unreachable_texel_reads_as_bare_paint_and_that_is_the_trap() -> void:
	# Stated out loud rather than left implicit: bare paint is not stored, so a
	# texel holding nothing is a texel holding all of it. Everything below is about
	# this number not being spendable.
	assert_almost_eq(_map.bare_at(_far_side(), Vector3.LEFT), 1.0, TOLERANCE)


# ---- what a tool does there ---------------------------------------------------


func test_a_cleaner_cannot_draw_on_bare_paint_nobody_can_reach() -> void:
	var rung: PackedInt32Array = _map.foam(_far_side(), Vector3.LEFT, WIDE, 1.0)
	assert_eq(rung.size(), 0, "an unreachable face reported finished patches")
	assert_almost_eq(_map.product_at(_far_side(), Vector3.LEFT), 0.0, TOLERANCE, "at the texel")
	assert_almost_eq(_map.product(), 0.0, TOLERANCE, "and in the total")


func test_the_water_moves_nothing_on_a_face_nobody_can_reach() -> void:
	var rung: PackedInt32Array = _map.wash(_far_side(), Vector3.LEFT, WIDE, 1.0)
	assert_eq(rung.size(), 0, "there is no mud there to take off")
	assert_almost_eq(_map.remaining(), 1.0, TOLERANCE, "and the total moved")


func test_the_rag_moves_nothing_there_either() -> void:
	_map.foam(_far_side(), Vector3.LEFT, WIDE, 1.0)
	var rung: PackedInt32Array = _map.buff(_far_side(), Vector3.LEFT, WIDE, 1.0)
	assert_eq(rung.size(), 0)
	assert_almost_eq(_map.shine(), 0.0, TOLERANCE, "shine appeared where nobody can polish")


func test_a_patch_with_nothing_reachable_on_it_never_rings() -> void:
	# The whole job, run at a face the mask left empty. Not one bell, through any
	# pass — which is the thing a capacity of zero would otherwise make ring
	# immediately, because zero units of nothing is trivially all of it.
	_do_the_whole_job(_far_side(), Vector3.LEFT)
	var rung: int = 0
	for _press: int in PRESSES:
		rung += _map.wash(_far_side(), Vector3.LEFT, WIDE, 1.0).size()
		rung += _map.foam(_far_side(), Vector3.LEFT, WIDE, 1.0).size()
		rung += _map.buff(_far_side(), Vector3.LEFT, WIDE, 1.0).size()
	assert_eq(rung, 0)
	assert_almost_eq(_map.worked(GrimeMap.Stage.WASHED), 0.0, TOLERANCE, "and nothing was banked")


func test_a_brush_over_both_kinds_of_texel_only_moves_the_reachable_ones() -> void:
	# The mask here is a spot in the middle of the face and the brush is wider than
	# the whole face, so this one press lands on both kinds of texel at once —
	# which is the case a per-face fixture cannot produce and the case the game is
	# made of.
	_map = GrimeMap.new(PANEL, TILE, PATCHES, _a_spot_on_the_right_face())
	var edge: Vector3 = Vector3(0.1, 0.05, -1.45)
	assert_almost_eq(_map.mud_at(edge, Vector3.RIGHT), 0.0, TOLERANCE, "the corner starts bare")
	_do_the_whole_job(_middle(), Vector3.RIGHT)
	assert_almost_eq(_map.shine_at(_middle(), Vector3.RIGHT), 1.0, TOLERANCE, "the spot is done")
	assert_almost_eq(_map.shine_at(edge, Vector3.RIGHT), 0.0, TOLERANCE, "and the corner is not")
	assert_almost_eq(_map.product_at(edge, Vector3.RIGHT), 0.0, TOLERANCE, "nor covered")


# ---- what the totals then say -------------------------------------------------


func test_the_panel_can_actually_be_finished() -> void:
	# The reading that could not become true before #144, on either car: a box has
	# six faces and a car does not, so there was always a face of every panel
	# holding mud nobody could ever take off.
	_do_the_whole_job(_middle(), Vector3.RIGHT)
	assert_true(_map.is_clean(), "the mud is not all off")
	assert_true(_map.is_finished(), "and the panel does not call itself done")
	assert_almost_eq(_map.shine(), 1.0, TOLERANCE, "so the progress number cannot reach one")


func test_the_work_banked_is_the_reachable_patches_and_not_the_whole_panel() -> void:
	# One face of six, on a panel diced two patches to a tile: four of the map's
	# twenty-four patches. A wage paid per patch has to be paid for those four and
	# for nothing else.
	_do_the_whole_job(_middle(), Vector3.RIGHT)
	var per_tile: int = PATCHES * PATCHES
	assert_almost_eq(_map.worked(GrimeMap.Stage.WASHED), float(per_tile), TOLERANCE, "washed")
	assert_almost_eq(_map.worked(GrimeMap.Stage.FOAMED), float(per_tile), TOLERANCE, "foamed")
	assert_almost_eq(_map.worked(GrimeMap.Stage.BUFFED), float(per_tile), TOLERANCE, "buffed")


func test_the_totals_describe_exactly_the_texels_the_mask_left() -> void:
	# The conservation law, checked against the pixels rather than against itself.
	# Every texel outside the mask must still hold nothing at all after every tool
	# has been over it, and the mud left inside the mask has to be the fraction the
	# running total claims — the same walk `test_grime_map.gd` does over a whole
	# panel, done over the half of one that counts.
	for _press: int in 3:
		_map.wash(_middle(), Vector3.RIGHT, WIDE, 0.2)
		_map.foam(_middle(), Vector3.RIGHT, WIDE, 0.2)
		_map.buff(_middle(), Vector3.RIGHT, WIDE, 0.2)
		_map.wash(_far_side(), Vector3.LEFT, WIDE, 0.9)
		_map.foam(_far_side(), Vector3.LEFT, WIDE, 0.9)
	var image: Image = _map.image()
	var muddy: float = 0.0
	var reachable: int = 0
	var elsewhere: float = 0.0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var pixel: Color = image.get_pixel(x, y)
			if x < TILE and y < TILE:
				muddy += pixel.r
				reachable += 1
				continue
			elsewhere += pixel.r + pixel.g + pixel.b
	assert_eq(elsewhere, 0.0, "something was moved onto a texel nobody can reach")
	assert_almost_eq(_map.remaining(), muddy / float(reachable), TOLERANCE, "the mud total")


func test_a_panel_the_mask_left_empty_has_no_work_on_it_at_all() -> void:
	# A panel seen from nowhere — no ray ever landed on it. It is not "clean" in
	# any sense a player would recognise; it is a panel with nothing to do, and
	# [method GrimeMap.has_reach] is how a caller averaging over a car tells the two
	# apart rather than dividing by a capacity of zero.
	var blind: GrimeMap = GrimeMap.new(
		PANEL, TILE, PATCHES, PanelReach.new(PANEL, GrimeMap.patch_grid_for(PATCHES))
	)
	assert_false(blind.has_reach(), "there is work on a panel nobody looked at")
	assert_almost_eq(blind.mud_at(_middle(), Vector3.RIGHT), 0.0, TOLERANCE, "and mud on it")
	assert_eq(blind.wash(_middle(), Vector3.RIGHT, WIDE, 1.0).size(), 0, "and a bell to ring")


func test_no_mask_at_all_is_the_whole_panel_exactly_as_before() -> void:
	# The backward-compatible default, asserted rather than assumed: every fixture
	# and every other unit test in this project builds a map without a mask, and
	# they are all describing a panel that is filthy on all six faces.
	var whole: GrimeMap = GrimeMap.new(PANEL, TILE, PATCHES)
	assert_true(whole.has_reach())
	assert_almost_eq(whole.mud_at(_far_side(), Vector3.LEFT), GrimeMap.FILTHY, TOLERANCE)
	assert_almost_eq(whole.mud_at(Vector3(0.0, 1.2, 0.0), Vector3.UP), GrimeMap.FILTHY, TOLERANCE)
