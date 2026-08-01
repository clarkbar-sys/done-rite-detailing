## The dirt on one panel: an image of how much mud is left, and the bookkeeping
## that can answer "is this bit done" without looking at the image again.
##
## One of these per panel of the [Car], laid out by [Grime] and sampled by
## [code]grime.gdshader[/code] through [method texture]. [BoxProjection] says
## where a point on the panel lands in it; this owns what is stored there and
## what happens when a tool is held on it.
##
## [b]Painted on the CPU, into an [Image].[/b] The obvious alternative is to
## render brush quads into a [SubViewport] and let the GPU do it, which is faster
## and is what a shipping game with a 2048² mask per panel would do. It is the
## wrong trade here for two reasons. The web build renders in Compatibility on
## the [code]nothreads[/code] template (STANDARDS.md has both), so a
## render-to-texture path is a second thing to get working and a second thing to
## keep working across two renderers. And a viewport cannot be asserted on
## headlessly — where an [Image] can, which is why washing the bonnet and
## checking that the boot lid is untouched is a unit test in this project rather
## than a screenshot somebody looked at once. At 64² a tile the whole car is
## about 1.2 MB and a brush touches a few hundred pixels a tick; there is no
## performance problem here to solve yet.
##
## [b]Four channels, one of them used.[/b] The mud the power wash takes off is
## the red channel and that is all this slice moves. Green and blue are spoken
## for — the film a sponge works on and the water a cloth dries — because the
## job is layered rather than single: mud, then detail, then buff. Allocating
## them now costs a format and nothing else, and it means the sponge is a
## different channel rather than a second texture, a second projection and a
## second set of bookkeeping.
##
## [b]Why the totals are kept and not counted.[/b] "Am I done here" could be
## answered by summing the image, and that is a scan of every pixel of every
## panel every time anybody asks. Instead each wash subtracts what it actually
## removed from a running total per patch, which is work proportional to the
## brush rather than to the texture — and it is the same number that a progress
## bar, a per-panel score and the ding all want.
##
## [b]The totals are counted in whole texel-units, and that took two goes.[/b] An
## [Image] stores eight bits a channel, so a pixel's mud is really one of 256
## steps and not a real number at all. The first version tracked the totals as
## floats and subtracted the unrounded amount, which drifts two ways at once: away
## from what the pixels actually hold, and — because a [PackedFloat32Array] only
## carries about seven digits — away from itself, by far more than any sensible
## epsilon. Measured, not reasoned about: a patch whose every pixel read exactly
## zero still had enough residue left in a float32 total to never be called clean,
## so the ding never rang.
##
## So the total is an integer count of 1/255ths, the arithmetic is exact, and
## "clean" is [code]== 0[/code] rather than "under some epsilon". A patch is
## finished when the pixels say it is, which is the only definition that cannot
## drift.
class_name GrimeMap
extends RefCounted

## Mud on a fresh panel: all of it.
const FILTHY: float = 1.0

## The steps of mud one pixel holds, which is what eight bits of channel buys.
## The totals below count these rather than fractions — see the class docs.
const UNITS: int = 255

## The smallest brush, in pixels of radius. A wash whose splash is smaller than a
## texel would otherwise round to nothing and the player would hold the trigger
## on a spot that never changes — which reads as a broken tool rather than as a
## mask that is too coarse for the range they are standing at.
const FINEST_BRUSH: float = 0.75

var _box: AABB
var _tile_pixels: int
var _patches_across: int
var _patches_down: int
var _image: Image = null
var _texture: ImageTexture = null
var _left: PackedInt32Array = PackedInt32Array()
var _full: int = 0
var _left_total: int = 0
var _dirty: bool = false


## [param panel_box] is the panel's own bounding box in the space points will be
## given in — panel-local, in practice, because that is the space that does not
## move when the car does. Not [code]box[/code], which is what it wants to be
## called: a parameter that shadows a method of the same class is a compile error
## under this project's warning levels rather than a style note.
##
## [param tile_pixels] is the resolution of one face of the atlas, so the image
## is three of them across and two down. [param patches_per_tile] is how finely
## each face is diced for the purpose of saying "this bit is done" — it is the
## granularity of the ding, and it is a knob rather than a constant because how
## often that fires is a matter of taste rather than of correctness.
func _init(panel_box: AABB, tile_pixels: int, patches_per_tile: int) -> void:
	_box = panel_box
	_tile_pixels = maxi(tile_pixels, 1)
	var per_tile: int = maxi(patches_per_tile, 1)
	_patches_across = BoxProjection.COLUMNS * per_tile
	_patches_down = BoxProjection.ROWS * per_tile
	_image = Image.create_empty(
		BoxProjection.COLUMNS * _tile_pixels,
		BoxProjection.ROWS * _tile_pixels,
		false,
		Image.FORMAT_RGBA8
	)
	# Red is the mud and the alpha is only there because the format has one.
	# Green and blue are deliberately left empty rather than seeded — see the
	# class docs: they are allocated for the sponge and the cloth, and neither of
	# those exists yet, so seeding them now would be inventing a number that
	# nothing reads and every debug view would have to explain.
	_image.fill(Color(FILTHY, 0.0, 0.0, 1.0))
	_texture = ImageTexture.create_from_image(_image)
	_seed_the_totals()


## The mask, for a shader to sample or a debug view to draw. The same texture for
## the life of the map — it is updated in place, so a material that was handed
## this once never has to be handed it again.
func texture() -> ImageTexture:
	return _texture


## The mask as an image, for a test that wants to read a pixel rather than trust
## a total.
func image() -> Image:
	return _image


## The box this map was built against, in the space [method wash] takes points
## in.
func box() -> AABB:
	return _box


## How many patches this panel is diced into.
func patches() -> int:
	return _patches_across * _patches_down


## How much of this panel's mud is still on it, as [code]0..1[/code].
func remaining() -> float:
	if _full <= 0:
		return 0.0
	return float(_left_total) / float(_full)


## Whether every patch on the panel is done.
##
## [b]It will not become true in play, and that is known.[/b] A box has six faces
## and the car does not: the underside of the bonnet is a face of the bonnet's
## box, it is seeded with mud like every other, and no jet of water will ever
## reach it. So this is the honest question with an answer nobody can reach yet,
## and the thing that will make it reachable is seeding mud only where the player
## can get at it — one function, when there is a reason to write it. Until then
## the ding rides on patches, which are reachable, and [method remaining] is
## reported as the fraction it actually is.
func is_clean() -> bool:
	return _left_total == 0


## Whether one patch is done, by its index in [method patches].
func is_patch_clean(patch: int) -> bool:
	if patch < 0 or patch >= _left.size():
		return false
	return _left[patch] == 0


## How much mud is left at a point on the panel, as [code]0..1[/code]. What the
## shader will read there, for a test that wants to check the paint rather than
## the arithmetic.
func mud_at(point: Vector3, normal: Vector3) -> float:
	var uv: Vector2 = BoxProjection.uv_for(_box, point, normal)
	var x: int = clampi(int(uv.x * float(_image.get_width())), 0, _image.get_width() - 1)
	var y: int = clampi(int(uv.y * float(_image.get_height())), 0, _image.get_height() - 1)
	return _image.get_pixel(x, y).r


## Takes [param amount] of mud off the panel around [param point], over a brush
## of [param radius_metres], for a surface facing [param normal] — all three in
## the panel's own space.
##
## Returns the patches that this call finished off, so the caller can ring one
## bell per patch rather than watching for the change itself. Empty when nothing
## completed, which is nearly every call.
##
## [b]Subtractive and clamped, not multiplicative.[/b] An exponential falloff
## toward clean feels better under the hand and never arrives — the last few
## percent asymptote and the ding is unreachable. So the amount comes straight
## off and stops at zero, and the softness is spent on the shape of the brush
## across its radius instead, where it does not cost the player an ending.
##
## [b]The brush stops at the edge of its face.[/b] Pixels are only touched inside
## the tile the point landed in, so a wash held on the very edge of the bonnet
## does not bleed round onto the wing — and equally does not reach round it, so
## the last centimetre of a corner takes a second press from the other side. The
## honest fix is to paint by world-space distance across every face whose normal
## faces the water, which is a loop over more tiles and the same arithmetic; it
## is not worth it until somebody notices the corner.
func wash(point: Vector3, normal: Vector3, radius_metres: float, amount: float) -> PackedInt32Array:
	var finished: PackedInt32Array = PackedInt32Array()
	if amount <= 0.0:
		return finished
	var face: BoxProjection.Face = BoxProjection.face_for(normal)
	var tile: Vector2 = BoxProjection.tile_uv(_box, point, face)
	var reach: Vector2 = _brush_pixels(face, radius_metres)
	var centre: Vector2 = tile * float(_tile_pixels)
	var origin: Vector2i = _tile_origin(face)
	var from: Vector2i = _corner(centre - reach)
	var to: Vector2i = _corner(centre + reach)
	for y: int in range(from.y, to.y + 1):
		for x: int in range(from.x, to.x + 1):
			var away: Vector2 = (Vector2(x, y) + Vector2(0.5, 0.5) - centre) / reach
			var falloff: float = 1.0 - away.length_squared()
			if falloff <= 0.0:
				continue
			_scrub(origin + Vector2i(x, y), amount * falloff, finished)
	# Uploaded once per call and only when a pixel actually moved: a trigger held
	# on a spot that is already clean should not cost a texture upload a tick.
	if _dirty:
		_texture.update(_image)
		_dirty = false
	return finished


## Takes mud off one pixel of the atlas and keeps the totals honest about it.
##
## [param at] is in image coordinates, not tile ones. Appends to [param finished]
## when this is the pixel that finishes its patch off.
func _scrub(at: Vector2i, amount: float, finished: PackedInt32Array) -> void:
	var pixel: Color = _image.get_pixel(at.x, at.y)
	# In whole texel-units on both sides of the subtraction, so the total moves by
	# exactly what the pixel moved by and can never disagree with it — the class
	# docs have what went wrong when it could.
	var was: int = roundi(pixel.r * float(UNITS))
	if was <= 0:
		return
	var left: int = clampi(roundi((pixel.r - amount) * float(UNITS)), 0, was)
	# A jet too weak to move a pixel by a whole unit moves it by none. The
	# alternative — rounding every touch down to at least one — would let a
	# vanishingly light brush wash the car given enough ticks.
	if left == was:
		return
	var patch: int = _patch_at(at)
	_left[patch] -= was - left
	_left_total -= was - left
	pixel.r = float(left) / float(UNITS)
	_image.set_pixel(at.x, at.y, pixel)
	_dirty = true
	# Reported on the transition and only once, without a flag to remember it by:
	# a patch already at zero has no pixel with anything left on it, so every
	# scrub of one returns above and never reaches here.
	if _left[patch] == 0:
		finished.append(patch)


## The brush's radius in pixels on each axis, never smaller than
## [constant FINEST_BRUSH].
func _brush_pixels(face: BoxProjection.Face, radius_metres: float) -> Vector2:
	var radius: Vector2 = BoxProjection.tile_radius(_box, face, radius_metres)
	return Vector2(
		maxf(radius.x * float(_tile_pixels), FINEST_BRUSH),
		maxf(radius.y * float(_tile_pixels), FINEST_BRUSH),
	)


## The top-left pixel of a face's tile in the atlas.
func _tile_origin(face: BoxProjection.Face) -> Vector2i:
	var column: int = int(face) % BoxProjection.COLUMNS
	var row: int = int(face) / BoxProjection.COLUMNS
	return Vector2i(column * _tile_pixels, row * _tile_pixels)


## A point in tile pixels, clamped to a pixel inside the tile.
func _corner(at: Vector2) -> Vector2i:
	var last: int = _tile_pixels - 1
	return Vector2i(clampi(int(floorf(at.x)), 0, last), clampi(int(floorf(at.y)), 0, last))


## Which patch an image pixel belongs to.
func _patch_at(at: Vector2i) -> int:
	var column: int = at.x * _patches_across / _image.get_width()
	var row: int = at.y * _patches_down / _image.get_height()
	return row * _patches_across + column


## Fills in how much mud each patch starts with, which is one unit per pixel it
## covers, without walking the image to count them.
##
## The spans are worked out the same way [method _patch_at] assigns pixels, so a
## patch grid that does not divide the atlas evenly still adds up to exactly the
## number of pixels there are — a patch that was short by a pixel would be a
## patch that never rang.
func _seed_the_totals() -> void:
	_left.resize(patches())
	var widths: PackedInt32Array = _spans(_image.get_width(), _patches_across)
	var heights: PackedInt32Array = _spans(_image.get_height(), _patches_down)
	_full = 0
	for row: int in _patches_down:
		for column: int in _patches_across:
			var mud: int = widths[column] * heights[row] * UNITS
			_left[row * _patches_across + column] = mud
			_full += mud
	_left_total = _full


## How many pixels fall into each of [param count] patches across
## [param pixels] of atlas.
static func _spans(pixels: int, count: int) -> PackedInt32Array:
	var spans: PackedInt32Array = PackedInt32Array()
	spans.resize(count)
	for index: int in count:
		var starts: int = (index * pixels + count - 1) / count
		var ends: int = ((index + 1) * pixels + count - 1) / count
		spans[index] = ends - starts
	return spans
