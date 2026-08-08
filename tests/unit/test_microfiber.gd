## Unit test for [Microfiber] — the weave the drying rag is drawn with.
##
## Under tests/unit/ because a material needs no [SceneTree]: it is a [Resource]
## that builds three [NoiseTexture2D]s in its constructor and then holds still.
## That the rag actually wears one is
## [code]tests/integration/test_view_model.gd[/code]'s, and that the sheet it is
## painted onto carries a tangent frame to read it in is
## [code]tests/integration/test_cloth_rag.gd[/code]'s.
##
## [b]What is worth asserting about a look, and what is not.[/b] Nobody can test
## "it looks like a towel", and a test that pinned every constant would fail on
## every retune while proving nothing — the numbers are meant to be turned. What
## it does assert is the three promises the class makes to the rest of the game,
## each of which is a thing a reviewer would otherwise have to take on trust:
##
## - it is still a [StandardMaterial3D] that [method ViewModel._material_for] can
##   paint the catalogue's colour onto;
## - it never makes the rag glossier than [member DetailingTool.roughness] says,
##   because roughness is multiplied by the map rather than replaced by it;
## - every map is generated, seamless, and distinct from the others.
extends GutTest

## The catalogue's own figures for the rag, which the material is expected to
## accept without argument — see [method DetailingTool.catalogue].
const RAG_COLOUR: Color = Color(0.20, 0.42, 0.85)
const RAG_ROUGHNESS: float = 0.9

var _weave: Microfiber = null


func before_each() -> void:
	_weave = Microfiber.new()


## The three generated maps, in one place so a test can say "every map" and mean
## it — a fourth added to [method Microfiber._init] and not to this list would go
## unchecked, so this is the one thing here worth keeping in step by hand.
func _maps() -> Array[NoiseTexture2D]:
	var maps: Array[NoiseTexture2D] = []
	maps.append(_weave.normal_texture as NoiseTexture2D)
	maps.append(_weave.albedo_texture as NoiseTexture2D)
	maps.append(_weave.roughness_texture as NoiseTexture2D)
	return maps


# ---- what the rest of the game is promised --------------------------------


func test_it_is_a_standard_material_the_catalogue_can_still_paint() -> void:
	# The whole reason this is a StandardMaterial3D subclass rather than a
	# ShaderMaterial: ViewModel goes on setting the same three fields on it that it
	# sets on every other tool, and the roll-up, the tests and anyone reading the
	# catalogue go on agreeing about what colour the rag is.
	_weave.albedo_color = RAG_COLOUR
	_weave.roughness = RAG_ROUGHNESS
	assert_true(_weave is StandardMaterial3D, "a material ViewModel can paint")
	assert_eq(_weave.albedo_color, RAG_COLOUR, "and the colour it painted")
	assert_almost_eq(_weave.roughness, RAG_ROUGHNESS, 0.0001, "and the roughness")


func test_the_cloth_is_drawn_from_both_sides() -> void:
	# Moved here from ViewModel with the rest of the rag's surface. A cloth has no
	# back — [ClothRag] is one sheet of triangles — so a rag that culled its far
	# face would vanish in halves every time it folded toward the eye.
	assert_eq(_weave.cull_mode, BaseMaterial3D.CULL_DISABLED, "no back to cull")


func test_the_weave_can_only_ever_make_the_rag_duller() -> void:
	# The ceiling from the class docs, as arithmetic rather than as a promise:
	# roughness is multiplied by this map, so a ramp that reached past 1.0 would
	# let a towel come out glossier than the catalogue says a towel is.
	assert_lte(Microfiber.TIPS, 1.0, "the palest the roughness map goes")
	assert_gt(Microfiber.SUNK, 0.0, "and it does not sand the rag flat either")
	assert_lt(Microfiber.SUNK, Microfiber.TIPS, "with the sunk parts the duller")


func test_the_colour_is_shaded_rather_than_replaced() -> void:
	# The same shape of promise on the albedo side. The map multiplies the
	# catalogue's colour, so a ramp reaching black would paint a rag that is not the
	# blue on the roll-up, and one reaching 1.0 everywhere would not be a weave.
	assert_gt(Microfiber.DARKEST, 0.5, "still recognisably the catalogue's colour")
	assert_lte(Microfiber.PALEST, 1.0, "and never brighter than it")
	assert_lt(Microfiber.DARKEST, Microfiber.PALEST, "with something in between")


# ---- and what the maps themselves have to be ------------------------------


func test_every_map_is_generated_seamless_and_mipmapped() -> void:
	# Seamlessness is not decoration at this tiling: the maps repeat eleven by
	# nineteen times across one rag, so a join is not a join, it is a grid — and a
	# grid is the first thing an eye finds on a flat surface. Mipmaps for the
	# matching reason at the other end of the range.
	for map: NoiseTexture2D in _maps():
		assert_not_null(map, "the rag wears three generated maps")
		if map == null:
			continue
		assert_true(map.seamless, "tiled this hard, a join would be a grid")
		assert_true(map.generate_mipmaps, "and it is seen at a slant")
		assert_eq(map.width, Microfiber.WEAVE, "square, at the documented size")
		assert_eq(map.height, Microfiber.WEAVE)


func test_no_two_maps_are_the_same_noise() -> void:
	# Three maps off one seed are three copies of one pattern, which is the failure
	# that looks like a success: the cloth would still be textured, and every crease
	# in the pile would sit exactly on a dark thread and a dull patch. Fabric does
	# not do that, and neither does this.
	var seeds: Array[int] = []
	for map: NoiseTexture2D in _maps():
		var source: FastNoiseLite = map.noise as FastNoiseLite
		assert_not_null(source, "each map is noise rather than a loaded image")
		if source == null:
			continue
		assert_false(seeds.has(source.seed), "and no two of them are the same noise")
		seeds.append(source.seed)


func test_the_pile_is_read_in_the_direction_the_nap_runs() -> void:
	# The nap, which is one number rather than a second texture: the maps are tiled
	# harder down the rag than across it, so every cell comes out a streak running
	# the width of the cloth. Equal tiling would be a sheet of gravel — see
	# [constant Microfiber.WARP].
	assert_gt(Microfiber.WEFT, Microfiber.WARP, "the nap has a direction")
	assert_eq(
		_weave.uv1_scale,
		Vector3(Microfiber.WARP, Microfiber.WEFT, 1.0),
		"and it is the tiling that gives it one"
	)


func test_the_fuzz_is_lit_as_well_as_shaped() -> void:
	# Rim light is the cheapest true thing in the file: light scattering through a
	# raised pile at grazing angles, which is the pale halo along the edge of a
	# towel held up to a window and the one cue no normal map can fake.
	assert_true(_weave.rim_enabled, "the fuzz catches light at the edges")
	assert_true(_weave.normal_enabled, "and is shaped as well as lit")
	assert_gt(_weave.normal_scale, 0.0, "with the pile standing off the sheet")
