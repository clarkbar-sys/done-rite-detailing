## Unit tests for [BoxProjection] — the arithmetic that turns "you hit the car
## here" into "so write to this texel".
##
## Under tests/unit/ because it is maths on an [AABB], a point and a normal, with
## no scene tree and no image anywhere near it. The boxes are made up rather than
## read off a real panel, for the reason
## [code]tests/unit/test_nearest_point.gd[/code] gives: a test that asked the
## [Car] for its shape would go red when somebody moved a wing, and it would be
## reporting a change to the car rather than a bug in this.
##
## [b]The test that matters most is [method test_opposite_faces_do_not_share_a_texel].[/b]
## Everything else here is arithmetic that would be caught the first time
## somebody looked at the debug view; that one is the reason this file exists
## instead of a triplanar sample in the shader, and its failure mode — washing
## one flank of the car cleans the other — is invisible from any single camera
## angle.
extends GutTest

## A metre cube on the origin. Most of what follows only needs a box with a
## known middle and known faces.
const CUBE: AABB = AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)

## Something door-shaped: four metres long, one and a half high, thin. The box
## that makes the difference between a circle in metres and a circle in texels
## visible.
const FLANK: AABB = AABB(Vector3(-0.1, 0.0, -2.0), Vector3(0.2, 1.5, 4.0))

## A ten-thousandth, for coordinates that are all in [code]0..1[/code].
const TOLERANCE: float = 0.0001

# ---- which face ---------------------------------------------------------------


func test_each_axis_picks_its_own_face() -> void:
	assert_eq(BoxProjection.face_for(Vector3.RIGHT), BoxProjection.Face.RIGHT)
	assert_eq(BoxProjection.face_for(Vector3.LEFT), BoxProjection.Face.LEFT)
	assert_eq(BoxProjection.face_for(Vector3.UP), BoxProjection.Face.TOP)
	assert_eq(BoxProjection.face_for(Vector3.DOWN), BoxProjection.Face.BOTTOM)
	assert_eq(BoxProjection.face_for(Vector3.BACK), BoxProjection.Face.FRONT)
	assert_eq(BoxProjection.face_for(Vector3.FORWARD), BoxProjection.Face.BACK)


func test_the_dominant_axis_wins_when_a_normal_is_off_square() -> void:
	# Every normal on the car is off-square to some degree — a bonnet slopes, a
	# windscreen rakes — so "mostly up" has to land on the top and not wander.
	assert_eq(BoxProjection.face_for(Vector3(0.2, 0.9, -0.3)), BoxProjection.Face.TOP)
	assert_eq(BoxProjection.face_for(Vector3(-0.8, 0.4, 0.1)), BoxProjection.Face.LEFT)


func test_the_sign_is_read_and_not_dropped() -> void:
	# The whole reason this is not triplanar: `abs()` on the normal would put
	# these two on the same face.
	assert_ne(
		BoxProjection.face_for(Vector3(0.9, 0.1, 0.0)),
		BoxProjection.face_for(Vector3(-0.9, 0.1, 0.0)),
	)


func test_a_normal_on_the_seam_lands_on_one_side_of_it() -> void:
	# Exactly 45° between two faces. Which one it picks is arbitrary; that it
	# picks the same one every time is not, because a normal that flickered
	# between two faces would flicker between two texels.
	var seam: Vector3 = Vector3(1.0, 1.0, 0.0).normalized()
	assert_eq(BoxProjection.face_for(seam), BoxProjection.face_for(seam))
	assert_eq(BoxProjection.face_for(seam), BoxProjection.Face.RIGHT)


# ---- where on the face --------------------------------------------------------


func test_the_middle_of_a_face_is_the_middle_of_its_tile() -> void:
	var tile: Vector2 = BoxProjection.tile_uv(CUBE, Vector3.ZERO, BoxProjection.Face.RIGHT)
	assert_almost_eq(tile, Vector2(0.5, 0.5), Vector2.ONE * TOLERANCE)


func test_a_corner_of_the_box_is_a_corner_of_the_tile() -> void:
	var at: Vector3 = Vector3(0.5, -0.5, -0.5)
	var tile: Vector2 = BoxProjection.tile_uv(CUBE, at, BoxProjection.Face.RIGHT)
	assert_almost_eq(tile, Vector2.ZERO, Vector2.ONE * TOLERANCE)


func test_a_point_past_the_box_is_clamped_onto_it() -> void:
	# A ray hits the built mesh and the box is measured around it, so rounding at
	# an edge really does put hits a hair outside. Off the tile is not a texel.
	var tile: Vector2 = BoxProjection.tile_uv(
		CUBE, Vector3(0.0, 40.0, -9.0), BoxProjection.Face.RIGHT
	)
	assert_almost_eq(tile, Vector2(0.0, 1.0), Vector2.ONE * TOLERANCE)


func test_each_face_measures_along_the_two_axes_that_are_not_its_own() -> void:
	assert_eq(
		BoxProjection.tile_axes(BoxProjection.Face.RIGHT), Vector2i(Vector3.AXIS_Z, Vector3.AXIS_Y)
	)
	assert_eq(
		BoxProjection.tile_axes(BoxProjection.Face.TOP), Vector2i(Vector3.AXIS_X, Vector3.AXIS_Z)
	)
	assert_eq(
		BoxProjection.tile_axes(BoxProjection.Face.FRONT), Vector2i(Vector3.AXIS_X, Vector3.AXIS_Y)
	)


# ---- and where in the atlas ---------------------------------------------------


func test_every_face_gets_its_own_corner_of_the_atlas() -> void:
	# Six tiles, three across and two down, none of them overlapping. Asserted as
	# "the middle of each face is in that face's cell" rather than by writing the
	# six coordinates down, so the test says the property instead of the answer.
	for face: int in BoxProjection.FACES:
		var uv: Vector2 = BoxProjection.atlas_uv(Vector2(0.5, 0.5), face as BoxProjection.Face)
		var column: int = face % BoxProjection.COLUMNS
		var row: int = face / BoxProjection.COLUMNS
		assert_almost_eq(
			uv,
			Vector2(
				(float(column) + 0.5) / float(BoxProjection.COLUMNS),
				(float(row) + 0.5) / float(BoxProjection.ROWS)
			),
			Vector2.ONE * TOLERANCE,
			"face %d is in the wrong cell" % face
		)


func test_the_whole_atlas_is_inside_the_texture() -> void:
	for face: int in BoxProjection.FACES:
		for corner: Vector2 in [Vector2.ZERO, Vector2.ONE]:
			var uv: Vector2 = BoxProjection.atlas_uv(corner, face as BoxProjection.Face)
			assert_between(uv.x, 0.0, 1.0, "face %d ran off the side" % face)
			assert_between(uv.y, 0.0, 1.0, "face %d ran off the bottom" % face)


func test_opposite_faces_do_not_share_a_texel() -> void:
	# The one that would have gone wrong under a triplanar projection, and the
	# reason the class docs argue about it at length: the two flanks of the car
	# are the same plane at the same coordinates under `abs(normal)`, so washing
	# the driver's door would have cleaned the passenger's door with it.
	var right: Vector2 = BoxProjection.uv_for(CUBE, Vector3(0.5, 0.1, 0.2), Vector3.RIGHT)
	var left: Vector2 = BoxProjection.uv_for(CUBE, Vector3(-0.5, 0.1, 0.2), Vector3.LEFT)
	assert_gt(right.distance_to(left), 0.2, "the two flanks landed on top of each other")


func test_a_point_and_its_normal_are_enough_to_place_it() -> void:
	# The whole projection in one call, checked against the two halves done by
	# hand — so `uv_for` cannot quietly stop agreeing with what paints the mask.
	var at: Vector3 = Vector3(0.2, 0.5, -0.3)
	var face: BoxProjection.Face = BoxProjection.face_for(Vector3.UP)
	assert_almost_eq(
		BoxProjection.uv_for(CUBE, at, Vector3.UP),
		BoxProjection.atlas_uv(BoxProjection.tile_uv(CUBE, at, face), face),
		Vector2.ONE * TOLERANCE
	)


# ---- how big the brush is -----------------------------------------------------


func test_a_round_brush_is_an_ellipse_on_a_panel_that_is_not_square() -> void:
	# Four metres long and one and a half high: a 20 cm splash of water covers a
	# twentieth of the length and an eighth of the height. One radius in tile
	# coordinates would have washed an oval.
	var radius: Vector2 = BoxProjection.tile_radius(FLANK, BoxProjection.Face.RIGHT, 0.2)
	assert_almost_eq(radius.x, 0.05, TOLERANCE, "along the panel")
	assert_almost_eq(radius.y, 0.2 / 1.5, TOLERANCE, "up it")


func test_a_flat_axis_does_not_produce_an_infinity() -> void:
	# A brush measured against a zero-thickness axis. Nothing on the car is flat,
	# but a mask built before the CSG has been generated would be — and an
	# infinite radius is a loop over every texel there is.
	var flat: AABB = AABB(Vector3.ZERO, Vector3(1.0, 0.0, 1.0))
	var radius: Vector2 = BoxProjection.tile_radius(flat, BoxProjection.Face.FRONT, 0.1)
	assert_true(is_finite(radius.y), "a flat axis gave back %f" % radius.y)
