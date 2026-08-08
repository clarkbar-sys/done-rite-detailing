## What the drying rag is made of: a [StandardMaterial3D] that wears a woven pile
## instead of being one flat blue rectangle.
##
## [b]The problem it solves.[/b] [ClothRag] made the rag [i]move[/i] like cloth —
## it hangs, it trails, it gathers itself back up — and then drew that motion on a
## surface with no texture of any kind. A sheet lit as a single albedo reads as
## painted card no matter how well it folds, and the fold is the thing the player
## is meant to notice. Fabric is mostly a surface property, so this is where it
## goes.
##
## [b]Everything here is generated, not imported.[/b] Three [NoiseTexture2D]s and
## a couple of gradients, built the first time a rag is put on the belt: a few
## hundred kilobytes of VRAM, nothing in the pack, nothing to license and nothing
## for an artist to keep in sync with a colour that lives in
## [method DetailingTool.catalogue]. A tiled photograph of a towel would look
## better in a still and worse in motion — it would carry its own lighting, baked
## from wherever it was photographed, into a room with two strip lights and a sky.
##
## [b]What each map is doing, because "add noise" is not a look.[/b] Microfibre
## reads as three things at once and each one has a map:
##
## - [b]the pile[/b] — split fibres standing off the weave, which is the fuzz you
##   see before you see anything else. Cellular noise as a normal map
##   ([method _pile]): hundreds of little rounded cells with dark creases between
##   them, a few millimetres each — see [constant WARP] for why that is coarser
##   than a real fibre and why it was measured rather than assumed.
## - [b]the nap[/b] — that the loops lie in a direction, so the cloth is not the
##   same in both axes. [constant WARP] and [constant WEFT] tile the maps
##   unevenly, which stretches every cell into a streak running the width of the
##   rag: one number, no second texture, and no shader.
## - [b]the matte[/b] — that a towel has no highlight to speak of, but is not
##   uniformly dull either, because the tips of the pile catch light the sunk
##   parts do not. [method _sheen] varies the catalogue's roughness downward by a
##   fifth at most, never upward: [member DetailingTool.roughness] stays the
##   ceiling, so the rag can never come out glossier than the tool says it is.
##
## [b]And one thing that is not a map:[/b] [member BaseMaterial3D.rim_enabled].
## Rim lighting is a cheap stand-in for light scattering through the fuzz at
## grazing angles — the pale halo along the edge of a towel held up against a
## window. It is the single most fabric-like thing in this file and it costs a
## branch in the shader.
##
## [b]Why a [StandardMaterial3D] and not a shader.[/b] The room's other surfaces
## are standard materials and the two shaders it does have (grime, sky) exist
## because they do things no material can — sampling a CPU-side mask, drawing a
## sky. A weave is not one of those things: it is bump, roughness and a tint, and
## those are the slots this class already has. Staying standard also means the
## rag keeps everything the renderer gives the rest of the room for free, and that
## [method ViewModel._material_for] can go on setting
## [member BaseMaterial3D.albedo_color] from the catalogue on the way past.
class_name Microfiber
extends StandardMaterial3D

## How many times the weave repeats across the rag's width, and down its length.
##
## The rag is 32 cm by 28 cm ([method DetailingTool.catalogue]), so eleven across
## puts a tile at just under 3 cm and nineteen down puts one at about 1.5 cm.
## Together with [constant PILE_FREQUENCY] that lands a single loop of the pile
## at roughly 3 mm by 1.6 mm — coarser than the real thing, and deliberately: a
## rag drawn at true fibre scale is a flat blue rectangle with a faint grain on
## it at the distance this is actually held, which was the picture this class was
## written to get away from. Rendered both ways before this number was picked.
##
## [b]The two differ on purpose and that is the nap.[/b] Tiling harder down than
## across squashes every cell into a short streak running the width of the cloth,
## so the pile has a direction, and the light that runs along it does not run
## across it. Equal numbers would be a sheet of gravel.
const WARP: float = 11.0
const WEFT: float = 19.0

## How big each generated map is, per side. Two hundred and fifty-six is enough
## for a tile this small to stay crisp at arm's length and is a sixteenth of the
## memory of the 1024 that would be the reflex — measured against the tiling
## above, where a texel lands at about a tenth of a millimetre on the cloth.
const WEAVE: int = 256

## Seeds, one per map, and all different: three maps generated from one seed are
## three copies of the same pattern, so the creases in the pile would line up
## exactly with the dark threads and the dull patches. Fabric does not do that.
const PILE_SEED: int = 6041
const NAP_SEED: int = 1187
const SHEEN_SEED: int = 9323

## How large a feature the pile's cellular noise makes, in cycles per pixel:
## about twenty-nine pixels a cell against [constant WEAVE], which is the loop
## [constant WARP] converts into millimetres.
const PILE_FREQUENCY: float = 0.035

## How fine the tonal variation is — [b]finer than the pile, not coarser[/b],
## which is the opposite of the obvious way round and was arrived at by looking.
## Tone that varies more slowly than the fibres do reads as blotches of
## camouflage on a rag this size, because there is nothing at that scale for the
## eye to attribute them to; varying it inside a loop reads as thread. Fractal,
## so the scales under it come along too.
const NAP_FREQUENCY: float = 0.05
const NAP_OCTAVES: int = 3

## And the roughness map, at about the size of one cell of the pile: a towel is
## dull everywhere and slightly less dull where the loops stand up, which is a
## per-loop fact rather than a per-fibre one.
const SHEEN_FREQUENCY: float = 0.03

## How hard the pile is pushed off the surface. Both halves of "fuzzy" are here:
## [constant BUMP] is how much relief the cellular noise is turned into, and
## [constant PROUD] scales the result on the way into the shader.
##
## High-ish, because the relief being stood in for is a fraction of a millimetre
## and the whole trick of a normal map is to light a surface as though it were
## deeper than it is. Past about three on [constant PROUD] the sheet starts to
## look like crumpled foil — the shading stops agreeing with the silhouette
## [ClothRag] is drawing, which is the one thing a normal map must not do.
const BUMP: float = 12.0
const PROUD: float = 2.2

## The darkest and palest the tonal map goes, as grey. Albedo is multiplied by
## this, so the cloth sits between three-quarters and nine-tenths of whatever
## colour the catalogue gave it: a weave that reads at a glance, and a rag that
## is still recognisably the blue on the roll-up rather than a navy one.
const DARKEST: float = 0.76
const PALEST: float = 0.94

## The same, for roughness. See the class docs: the top of the range is 1.0
## because roughness is multiplied by this too, and the catalogue's own figure
## has to stay the ceiling.
const SUNK: float = 0.8
const TIPS: float = 1.0

## How much light bleeds around the edge of the fuzz, and how much of the cloth's
## own colour it carries with it.
##
## A fifth is a visible softening at grazing angles and nothing at all face-on,
## which is where a towel differs from paper. The tint is most of the way to the
## albedo rather than all of it: real fibre scatter comes back paler than the
## cloth, because it has been through the fibre rather than off it.
const HALO: float = 0.18
const HALO_TINT: float = 0.65

## How wide a border is blended in to make each map tile seamlessly, as a
## fraction of the texture. A tenth, which is [NoiseTexture2D]'s own default and
## is generous enough to hide the join in noise this fine — the alternative is a
## visible grid at [constant WARP] by [constant WEFT] across one rag.
const SKIRT: float = 0.1


## A fresh weave. Every map is generated here rather than shared between rags,
## which costs nothing worth measuring: [ViewModel] builds one material per tool
## once, and there is exactly one rag on the belt.
func _init() -> void:
	uv1_scale = Vector3(WARP, WEFT, 1.0)
	normal_enabled = true
	normal_texture = _pile()
	normal_scale = PROUD
	albedo_texture = _nap()
	roughness_texture = _sheen()
	roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	# Anisotropic filtering, which is the one place a rag differs from the room's
	# boxes enough to want it: this material is nineteen tiles of fine noise on a
	# sheet the player sees at a slant every time it drapes, and trilinear alone
	# turns that into either shimmer or mush depending on the angle.
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	rim_enabled = true
	rim = HALO
	rim_tint = HALO_TINT
	# The rag's own two-sidedness, which came with it from
	# [method ViewModel._material_for] and belongs here now: a cloth has no back,
	# so a renderer that refused to draw one would be right about a mesh that is
	# wrong. [ClothRag] draws a single sheet of triangles and the player sees the
	# far side of it every time it folds.
	cull_mode = BaseMaterial3D.CULL_DISABLED


## The pile: cellular noise turned into relief.
##
## [constant FastNoiseLite.RETURN_DISTANCE2_SUB] rather than plain distance,
## because it is the return that puts a ridge between neighbouring cells instead
## of a cone inside each one — loops of thread pressed together, which is what
## the surface of a microfibre cloth is, rather than a field of little hills.
func _pile() -> NoiseTexture2D:
	var fibres: FastNoiseLite = FastNoiseLite.new()
	fibres.noise_type = FastNoiseLite.TYPE_CELLULAR
	fibres.seed = PILE_SEED
	fibres.frequency = PILE_FREQUENCY
	fibres.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	fibres.cellular_jitter = 1.0
	var map: NoiseTexture2D = _map(fibres)
	map.as_normal_map = true
	map.bump_strength = BUMP
	return map


## The tonal variation, as a greyscale multiplied into the catalogue's colour:
## fractal noise, ramped between [constant DARKEST] and [constant PALEST] so the
## rag is mottled rather than repainted.
func _nap() -> NoiseTexture2D:
	var patches: FastNoiseLite = FastNoiseLite.new()
	patches.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	patches.seed = NAP_SEED
	patches.frequency = NAP_FREQUENCY
	patches.fractal_octaves = NAP_OCTAVES
	var map: NoiseTexture2D = _map(patches)
	map.color_ramp = _between(DARKEST, PALEST)
	return map


## The matte, likewise: where the pile is sunk it is a shade less rough than the
## tips that catch the light. See the class docs for why this only ever goes
## down.
func _sheen() -> NoiseTexture2D:
	var patches: FastNoiseLite = FastNoiseLite.new()
	patches.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	patches.seed = SHEEN_SEED
	patches.frequency = SHEEN_FREQUENCY
	var map: NoiseTexture2D = _map(patches)
	map.color_ramp = _between(SUNK, TIPS)
	return map


## One generated map, with the settings every one of the three shares.
##
## [member NoiseTexture2D.seamless] is not optional at this tiling: eleven by
## fifteen repeats of a map with a visible join is a grid of joins, and the grid
## is the first thing an eye finds on a flat surface.
func _map(source: FastNoiseLite) -> NoiseTexture2D:
	var map: NoiseTexture2D = NoiseTexture2D.new()
	map.noise = source
	map.width = WEAVE
	map.height = WEAVE
	map.seamless = true
	map.seamless_blend_skirt = SKIRT
	map.generate_mipmaps = true
	return map


## A greyscale ramp from [param darkest] to [param palest] — what turns a noise
## that runs the whole way from black to white into one that only varies by as
## much as a piece of cloth does.
func _between(darkest: float, palest: float) -> Gradient:
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(darkest, darkest, darkest))
	ramp.set_color(1, Color(palest, palest, palest))
	return ramp
