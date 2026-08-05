## Unit tests for how far [GrimeMap]'s brush reaches — the ball of paint that
## replaced a disc stuck on one face of one panel.
##
## [b]This is the suite the gritty corners bought.[/b] The brush used to clamp
## every pixel it touched into the tile the hit landed in, so a wash held on the
## edge of a panel stopped dead at the edge and the last centimetre round the
## corner could only be had by walking to the other side and pressing again. The
## old [method GrimeMap._brush] docs described the fix and declined to write it;
## everything below is what writing it has to keep true.
##
## Split from [code]tests/unit/test_grime_map.gd[/code] and
## [code]tests/unit/test_grime_map_layers.gd[/code], which cover the same class's
## bookkeeping and its three passes. The seam is the same honest one those two
## have between them: nothing here cares what a bucket does, and everything here
## needs a panel with more than one face in play — which the door-shaped panel
## they share is deliberately never asked about.
##
## [b]Boxes made up rather than read off the [Car][/b], for
## [code]tests/unit/test_box_projection.gd[/code]'s reason: a test that asked the
## real car for a corner would go red when somebody reshaped a wing, and it would
## be reporting a change to the blockout rather than a bug in the brush.
extends GutTest

## A metre cube on the origin. The shape for corners: every face is the same size,
## so "it reached round the edge" is a distance and not an aspect ratio.
const CUBE: AABB = AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)

## Ten centimetres thick, a metre the other two ways. The shape for the far side:
## a brush of any sensible radius held on the front of this is well within reach
## of the back of it, so nothing but the facing test is keeping it out.
const SLAB: AABB = AABB(Vector3(-0.05, 0.0, -0.5), Vector3(0.1, 1.0, 1.0))

## Small and fast, and the same number the sibling suites use. A texel on
## [constant CUBE] is 6.25 cm, which is small against every radius below and
## large enough that [constant GrimeMap.FINEST_BRUSH] has something to floor.
const TILE: int = 16

const PATCHES: int = 2

## A ten-thousandth, for numbers that are all fractions of one.
const TOLERANCE: float = 0.0001

## Enough of a tool to move a visible number of units in one touch, so every
## assertion below is about where the paint went rather than how much.
const ONE_PRESS: float = 0.5


## The top-front edge of [constant CUBE] — a point on the seam between two faces,
## which is the whole subject of this file.
func _edge() -> Vector3:
	return Vector3(0.0, 0.5, 0.5)


# ---- round the corner ---------------------------------------------------------


func test_a_press_on_an_edge_reaches_both_faces_of_it() -> void:
	# The complaint, in one assertion. A quarter-metre brush on the top-front edge
	# is on the top and on the front, and before this it was only ever on whichever
	# one the ray's normal happened to name.
	var map: GrimeMap = GrimeMap.new(CUBE, TILE, PATCHES)
	map.wash(_edge(), Vector3.UP, 0.25, ONE_PRESS)
	assert_lt(map.mud_at(Vector3(0.0, 0.5, 0.4), Vector3.UP), GrimeMap.FILTHY, "the face it hit")
	assert_lt(
		map.mud_at(Vector3(0.0, 0.4, 0.5), Vector3.BACK), GrimeMap.FILTHY, "the face round the edge"
	)


func test_the_wrap_falls_off_with_distance_like_the_rest_of_the_brush() -> void:
	# Round the corner is not a second brush with rules of its own — it is the same
	# ball, so the texel nearer the hit keeps less mud than the one further along.
	var map: GrimeMap = GrimeMap.new(CUBE, TILE, PATCHES)
	map.wash(_edge(), Vector3.UP, 0.3, ONE_PRESS)
	var near: float = map.mud_at(Vector3(0.0, 0.4, 0.5), Vector3.BACK)
	var far: float = map.mud_at(Vector3(0.0, 0.25, 0.5), Vector3.BACK)
	assert_lt(near, far, "the wrap did not fade with distance")


func test_a_press_in_the_middle_of_a_face_does_not_wrap_at_all() -> void:
	# The other half of the rule, and the one that stops "reaches round corners"
	# quietly meaning "paints every face it is not behind". Half a metre from the
	# front of the cube, a 20 cm brush is nowhere near it.
	var map: GrimeMap = GrimeMap.new(CUBE, TILE, PATCHES)
	map.wash(Vector3(0.0, 0.5, 0.0), Vector3.UP, 0.2, ONE_PRESS)
	assert_almost_eq(
		map.mud_at(Vector3(0.0, 0.45, 0.5), Vector3.BACK),
		GrimeMap.FILTHY,
		TOLERANCE,
		"the front of the cube was washed from the middle of the roof"
	)


# ---- and not through the panel ------------------------------------------------


func test_a_brush_does_not_reach_through_to_the_far_side() -> void:
	# The one thing a ball of paint must never do. The slab is 10 cm thick and the
	# brush is 30, so the back of it is comfortably inside the radius and the only
	# thing keeping the water off it is the facing test. Without that, washing a
	# door from outside would clean the inside of it too.
	var map: GrimeMap = GrimeMap.new(SLAB, TILE, PATCHES)
	map.wash(Vector3(0.05, 0.5, 0.0), Vector3.RIGHT, 0.3, ONE_PRESS)
	assert_lt(map.mud_at(Vector3(0.05, 0.5, 0.1), Vector3.RIGHT), GrimeMap.FILTHY, "the near side")
	assert_almost_eq(
		map.mud_at(Vector3(-0.05, 0.5, 0.0), Vector3.LEFT),
		GrimeMap.FILTHY,
		TOLERANCE,
		"the water came out of the other side of the panel"
	)


func test_the_underside_is_safe_from_a_wash_over_the_top() -> void:
	var map: GrimeMap = GrimeMap.new(CUBE, TILE, PATCHES)
	map.wash(_edge(), Vector3.UP, 0.3, ONE_PRESS)
	assert_almost_eq(
		map.mud_at(Vector3(0.0, -0.5, 0.4), Vector3.DOWN),
		GrimeMap.FILTHY,
		TOLERANCE,
		"the underside was washed from above"
	)


# ---- measured in metres, not in texels ----------------------------------------


func test_a_hit_inside_its_own_box_still_works_at_full_strength() -> void:
	# A box is drawn around a built mesh, so a hit on anything that is not a flat
	# slab — a tapered nose, a wheel, a mirror — sits some way inside its own box.
	# Charging the brush for that gap would make a curved panel need a bigger tool
	# than a flat one at the same range, so the face the tool actually hit measures
	# in its own plane and ignores it. 20 cm in is a long way in on a metre cube.
	var sunk: GrimeMap = GrimeMap.new(CUBE, TILE, PATCHES)
	var flush: GrimeMap = GrimeMap.new(CUBE, TILE, PATCHES)
	sunk.wash(Vector3(0.0, 0.3, 0.0), Vector3.UP, 0.25, ONE_PRESS)
	flush.wash(Vector3(0.0, 0.5, 0.0), Vector3.UP, 0.25, ONE_PRESS)
	assert_almost_eq(
		sunk.mud_at(Vector3(0.0, 0.5, 0.0), Vector3.UP),
		flush.mud_at(Vector3(0.0, 0.5, 0.0), Vector3.UP),
		TOLERANCE,
		"the hit was charged for how deep inside its box it landed"
	)


func test_a_brush_finer_than_a_texel_still_moves_the_one_it_is_on() -> void:
	# What [constant GrimeMap.FINEST_BRUSH] is for, kept true now that it is spent
	# in metres rather than in pixels. A tool that moved nothing at all would read
	# as broken rather than as a mask too coarse for the range it is being used at.
	var map: GrimeMap = GrimeMap.new(CUBE, TILE, PATCHES)
	map.wash(Vector3(0.0, 0.5, 0.0), Vector3.UP, 0.001, ONE_PRESS)
	assert_lt(
		map.mud_at(Vector3(0.0, 0.5, 0.0), Vector3.UP),
		GrimeMap.FILTHY,
		"a sub-texel brush rounded away to nothing"
	)


# ---- and the rules did not change --------------------------------------------


func test_the_face_round_the_corner_plays_by_the_same_bucket_rules() -> void:
	# The wrap is not a back door into the mask. A cleaner still draws from bare
	# paint over there, which means the water still has to have been first — the
	# ordering the whole class rests on, asserted on the face that the brush only
	# reaches by going round an edge.
	var at: Vector3 = Vector3(0.0, 0.4, 0.5)
	var map: GrimeMap = GrimeMap.new(CUBE, TILE, PATCHES)
	map.foam(_edge(), Vector3.UP, 0.3, ONE_PRESS)
	assert_almost_eq(
		map.product_at(at, Vector3.BACK), 0.0, TOLERANCE, "foam went onto a muddy face"
	)
	for _sweep: int in 40:
		map.wash(_edge(), Vector3.UP, 0.3, ONE_PRESS)
	map.foam(_edge(), Vector3.UP, 0.3, ONE_PRESS)
	assert_gt(map.product_at(at, Vector3.BACK), 0.0, "foam never reached the washed face")


func test_nothing_is_created_or_destroyed_round_a_corner() -> void:
	# The conservation law, checked where it is easiest to break it: a texel that
	# two faces' worth of arithmetic have both had an opinion about. The four
	# buckets still add up to one.
	var at: Vector3 = Vector3(0.0, 0.4, 0.5)
	var map: GrimeMap = GrimeMap.new(CUBE, TILE, PATCHES)
	for _sweep: int in 20:
		map.wash(_edge(), Vector3.UP, 0.3, 0.2)
		map.foam(_edge(), Vector3.UP, 0.3, 0.2)
		map.buff(_edge(), Vector3.UP, 0.3, 0.2)
	var total: float = (
		map.mud_at(at, Vector3.BACK)
		+ map.product_at(at, Vector3.BACK)
		+ map.shine_at(at, Vector3.BACK)
		+ map.bare_at(at, Vector3.BACK)
	)
	assert_almost_eq(total, 1.0, TOLERANCE, "a unit went missing round the corner")
