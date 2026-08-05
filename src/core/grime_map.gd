## The state of one panel: an image of what is sitting on it at every texel, and
## the bookkeeping that can answer "is this bit done" without looking at the
## image again.
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
## [b]Four buckets in three channels, and they always add up to one.[/b] A texel
## is not "how dirty" — it is how a unit of surface is divided between four
## states, and the three channels are three of them:
##
## [codeblock]
## red     mud          what the power wash takes off
## green   product      what a cleaner puts on
## blue    shine        what the drying rag earns
## (none)  bare paint   1 - red - green - blue
## [/codeblock]
##
## Bare paint is the remainder and is not stored, because storing it would be a
## fourth number that has to agree with the other three. Every tool moves units
## from one bucket to another and never creates or destroys any, so the four
## always sum to [constant UNITS] — [method wash] takes mud to bare,
## [method foam] takes bare to product, [method buff] takes product to shine.
##
## [b]That conservation is the game's rules, not an accounting convenience.[/b]
## It is what makes the job layered without a single line of sequencing logic:
##
## - You cannot foam over mud, because [method foam] draws from bare and a muddy
##   texel has none. The jet has to make some first.
## - You cannot shine what you never foamed, because [method buff] draws from
##   product. A rag on bare paint moves nothing.
## - And the water is only ever the first pass, because it is the only thing that
##   makes bare paint and nothing anywhere puts mud back. A jet over a panel
##   somebody has already treated finds no mud and moves nothing at all.
## - "Finished" is one number — every unit in blue — and it is reachable only by
##   having gone through the other two.
##
## [b]And the units only travel one way round.[/b] Mud falls, bare paint is made
## by the water and spent by a bottle, product is spent by the rag, and nothing
## takes shine off — so no bucket a tool fills can be emptied back to where it
## came from. That is newer than the rest of this file: the jet used to draw
## product off with the mud, and [method wash] has why it no longer does and what
## the bookkeeping here stopped needing when it stopped.
##
## The alternative was three independent channels with a rule written next to
## each about what it is allowed to do to the others. This is the same rules
## expressed as arithmetic, and arithmetic cannot be forgotten at the one call
## site nobody thought about.
##
## [b]Why the totals are kept and not counted.[/b] "Am I done here" could be
## answered by summing the image, and that is a scan of every pixel of every
## panel every time anybody asks. Instead each touch adds what it actually moved
## to a running total per patch, which is work proportional to the brush rather
## than to the texture — and it is the same number that a progress bar, a
## per-panel score and the ding all want.
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
## So the totals are integer counts of 1/255ths, the arithmetic is exact, and
## every threshold below is [code]==[/code] rather than "within some epsilon". A
## patch is finished when the pixels say it is, which is the only definition that
## cannot drift. It is also what lets the conservation law above be stated as an
## equality: a transfer rounded on the way in and again on the way out would leak
## a unit a touch, and a texel that had quietly lost three units of itself could
## never be finished.
class_name GrimeMap
extends RefCounted

## A step of the job, used twice: as the thing a tool is doing, and as the thing
## a patch has just finished. One enum rather than two, because they are the same
## three steps read in two tenses and a second copy would be a second thing to
## keep in order.
enum Stage {
	## Mud to bare paint. The power wash, and it works on any panel.
	WASHED,
	## Bare paint to product. The sponge, the window cleaner and the tyre cleaner,
	## each on the surface [method Surface.cleaner_for] gives it.
	FOAMED,
	## Product to shine. The drying rag, and it too works on any panel — what
	## stops it being usable out of order is that there is nothing to move.
	BUFFED,
}

## Mud on a fresh panel: all of it.
const FILTHY: float = 1.0

## The steps of one bucket a pixel holds, which is what eight bits of channel
## buys. The totals below count these rather than fractions — see the class docs.
const UNITS: int = 255

## The smallest brush, in pixels of radius. A touch whose splash is smaller than
## a texel would otherwise round to nothing and the player would hold the trigger
## on a spot that never changes — which reads as a broken tool rather than as a
## mask that is too coarse for the range they are standing at.
const FINEST_BRUSH: float = 0.75

var _box: AABB
var _tile_pixels: int
var _patches_across: int
var _patches_down: int
var _image: Image = null
var _texture: ImageTexture = null
## Patches' worth of work done in each [enum Stage], indexed by it. See
## [method worked] for why it is measured in patches and why it is the one total
## on this class that is not an integer.
var _worked: PackedFloat64Array = PackedFloat64Array()
var _mud: PackedInt32Array = PackedInt32Array()
var _product: PackedInt32Array = PackedInt32Array()
var _shine: PackedInt32Array = PackedInt32Array()
var _capacity: PackedInt32Array = PackedInt32Array()
var _full: int = 0
var _mud_total: int = 0
var _product_total: int = 0
var _shine_total: int = 0
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
	# Every unit in the mud bucket and none in the other two, which is the one
	# seeding the conservation law allows: a fresh panel is entirely mud, so there
	# is no bare paint to foam and no product to buff until the water has run. The
	# alpha is only there because the format has one.
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


## The box this map was built against, in the space the tools take points in.
func box() -> AABB:
	return _box


## How many patches this panel is diced into.
func patches() -> int:
	return _patches_across * _patches_down


## The shape of that dicing — how many patches across the atlas and how many
## down.
##
## Public because a patch index is only meaningful against this grid, and
## anything drawing patches rather than counting them needs both numbers.
## [PatchFlash] sizes its image from this rather than working it out again from
## [constant BoxProjection.COLUMNS] and the patches-per-tile it was built with:
## two derivations of the same grid is two things that can disagree, and the
## symptom would be a flash lighting the square next to the one that rang.
func patch_grid() -> Vector2i:
	return Vector2i(_patches_across, _patches_down)


## How much of this panel's mud is still on it, as [code]0..1[/code].
func remaining() -> float:
	return _fraction(_mud_total)


## How much of this panel is under product right now, as [code]0..1[/code].
##
## It goes up under a cleaner and back down under the rag, which is the one
## reading here that is not monotonic — product is a step of the job rather than
## a score, and a panel that reads zero is either untouched or finished. Ask
## [method shine] to tell those apart.
func product() -> float:
	return _fraction(_product_total)


## How much of this panel is buffed to a shine, as [code]0..1[/code]. The
## progress number: it only ever goes up, and it reaches one exactly when the
## panel is done.
func shine() -> float:
	return _fraction(_shine_total)


## How much work this panel has had done on it in [param stage], ever, measured
## in patches' worth.
##
## [b]Patches' worth rather than texel-units, and that is the whole point of the
## number.[/b] A unit is a mask-resolution detail — it changes with
## [member Grime.tile_pixels] and it means nothing to anything outside this file
## — where a patch is the size the rest of the game already reasons in: it is
## what [signal Grime.patch_finished] counts, what the ding rides on and what the
## square on the car is drawn at. So one patch's worth of washing reads 1.0 here,
## and a caller that pays per patch can pay for part of one without knowing how
## big a texel is.
##
## [b]Only ever up, and every unit that moves is a unit that went forwards.[/b]
## That is a property of the tools rather than of the counting, and it is worth
## saying plainly because it used not to be true. While the jet took product off
## as well as mud, foam → rinse → foam was a loop the player could hold on one
## square for ever, laying fresh product each turn with the car no nearer done —
## so this total defended itself by counting how far each patch had ever got
## rather than how much had ever crossed it, and kept a per-patch high-water mark
## to do it with. [method wash] no longer takes product off. Nothing now empties a
## bucket back into the one it came from, so each of the three totals is its own
## high-water mark and the memory has gone with the rule that needed it.
##
## The property all three then share is the one a wage can be paid from: this is
## what the panel has [i]irreversibly[/i] had done to it, which is now simply what
## has been done to it — there is no longer any way to make a car worse, so there
## is nothing for a ledger that only goes forwards to disagree with.
##
## [b]A float where every other total on this class is an integer[/b], and the
## class docs above are emphatic about why those are integers — so this is worth
## saying plainly. Those count what the pixels hold, they are compared with
## [code]==[/code], and a float32 that had drifted by a hair meant a patch nobody
## could finish. This counts work that has already happened, nothing compares it
## to anything, and losing a ten-thousandth of a patch to rounding costs a
## fraction of a point of score. Sixty-four bits rather than the
## [PackedFloat32Array] elsewhere in the project all the same: it is a sum with
## no upper bound over a session, and float32 stops being able to add a
## thousandth to it after a few hours.
func worked(stage: Stage) -> float:
	return _worked[int(stage)]


## Whether every patch on the panel has had its mud taken off.
##
## [b]It will not become true in play, and that is known.[/b] A box has six faces
## and the car does not: the underside of the bonnet is a face of the bonnet's
## box, it is seeded with mud like every other, and no jet of water will ever
## reach it. So this is the honest question with an answer nobody can reach yet,
## and the thing that will make it reachable is seeding mud only where the player
## can get at it — one function, when there is a reason to write it. Until then
## the ding rides on patches, which are reachable, and the fractions above are
## reported as the fractions they actually are.
func is_clean() -> bool:
	return _mud_total == 0


## Whether every patch on the panel is buffed. Unreachable today for the same
## reason [method is_clean] is, and for one more besides: a face nobody can wash
## is a face nobody can foam either.
func is_finished() -> bool:
	return _shine_total == _full


## Whether one patch has had its mud taken off, by its index in [method patches].
func is_patch_clean(patch: int) -> bool:
	if patch < 0 or patch >= _mud.size():
		return false
	return _mud[patch] == 0


## Whether one patch is buffed all the way — the end of the job for that bit of
## the panel.
func is_patch_finished(patch: int) -> bool:
	if patch < 0 or patch >= _shine.size():
		return false
	return _shine[patch] == _capacity[patch]


## How much mud is left at a point on the panel, as [code]0..1[/code]. What the
## shader will read there, for a test that wants to check the paint rather than
## the arithmetic.
func mud_at(point: Vector3, normal: Vector3) -> float:
	return _pixel_at(point, normal).r


## How much product is sitting at a point on the panel, as [code]0..1[/code].
func product_at(point: Vector3, normal: Vector3) -> float:
	return _pixel_at(point, normal).g


## How much shine has been buffed into a point on the panel, as [code]0..1[/code].
func shine_at(point: Vector3, normal: Vector3) -> float:
	return _pixel_at(point, normal).b


## How much bare paint there is at a point — the bucket that is not stored, which
## is [code]1[/code] less the other three.
##
## Public because it is the thing a cleaner draws from, and a test that wants to
## know why a bottle did nothing should be able to ask directly rather than infer
## it from the other three.
func bare_at(point: Vector3, normal: Vector3) -> float:
	var pixel: Color = _pixel_at(point, normal)
	return clampf(1.0 - pixel.r - pixel.g - pixel.b, 0.0, 1.0)


## Takes [param amount] of mud off the panel around [param point], over a brush of
## [param radius_metres], for a surface facing [param normal] — all three in the
## panel's own space. What it takes off becomes bare paint.
##
## [b]Mud, and nothing else lying on the paint.[/b] The jet used to draw the
## product off with the dirt, on the argument that water does not politely stop at
## what you want it to and that a tool usable at any point in the job teaches the
## player nothing: spray a window you have just cleaned and it went back to bare
## glass, so the order stopped being advice.
##
## [b]The order did not rest on it, and the cost was not paid by the player who
## was out of order.[/b] What actually sequences the job is the buckets —
## [method foam] draws from bare paint and only the water makes any, so the water
## is the first pass whether or not it can undo the second, and a jet over a panel
## that has already been treated now simply finds no mud and moves nothing. Who
## the rule was really charging was the player working panel by panel: the jet's
## brush is the widest in the game and a car's panels sit against each other, so
## washing the door took the edge off the wing beside it that they had soaped a
## minute ago. That is an aim off by a tool's width, not a pass done in the wrong
## order.
##
## [b]Which is the argument shine was already exempted on.[/b] A stray jet costing
## the player work they have already done is a punishment for imprecision rather
## than a rule anybody can learn — and that was as true of the coat of foam laid
## ten seconds ago as of the wax under it. Exempting one bucket and not the other
## was the part that never held up; both are exempt now, and the water is the one
## pass that can only ever help.
##
## Returns the patches this call washed clean — clean of [i]mud[/i], which is the
## transition the bell is about. A patch whose mud has long gone reports nothing,
## because there is nothing left there for the jet to move at all.
func wash(point: Vector3, normal: Vector3, radius_metres: float, amount: float) -> PackedInt32Array:
	return _brush(point, normal, radius_metres, amount, Stage.WASHED)


## Lays [param amount] of product onto the bare paint around [param point].
##
## Bounded by how much bare paint is actually there, which is the whole of "you
## cannot soap a muddy car" — no check, no refusal, just nothing to draw from.
## Held on a half-washed spot it covers the washed half and stops.
##
## Returns the patches this call covered completely: no mud left and no bare paint
## left either, so there is nothing more a bottle can do to them. Once each, ever,
## and nothing has to remember which — a covered patch has no bare paint for a
## second coat to draw from, and nothing puts any back.
func foam(point: Vector3, normal: Vector3, radius_metres: float, amount: float) -> PackedInt32Array:
	return _brush(point, normal, radius_metres, amount, Stage.FOAMED)


## Wipes [param amount] of product off around [param point], turning it into
## shine as it goes.
##
## The rag does not remove and separately reward — it is one transfer, so the
## shine a panel ends up with is exactly the product that was put on it. A rag on
## bare paint has nothing to move and does nothing, which is the last of the three
## ordering rules and, like the other two, is arithmetic rather than a gate.
##
## Returns the patches this call finished outright.
func buff(point: Vector3, normal: Vector3, radius_metres: float, amount: float) -> PackedInt32Array:
	return _brush(point, normal, radius_metres, amount, Stage.BUFFED)


## Runs one tool over the mask: the brush shape, shared by all three, with
## [param stage] deciding which buckets each pixel moves units between.
##
## [b]Subtractive and clamped, not multiplicative.[/b] An exponential falloff
## toward done feels better under the hand and never arrives — the last few
## percent asymptote and the ding is unreachable. So the amount moves straight
## across and stops at the source, and the softness is spent on the shape of the
## brush across its radius instead, where it does not cost the player an ending.
##
## [b]The brush stops at the edge of its face.[/b] Pixels are only touched inside
## the tile the point landed in, so a wash held on the very edge of the bonnet
## does not bleed round onto the wing — and equally does not reach round it, so
## the last centimetre of a corner takes a second press from the other side. The
## honest fix is to paint by world-space distance across every face whose normal
## faces the water, which is a loop over more tiles and the same arithmetic; it
## is not worth it until somebody notices the corner.
func _brush(
	point: Vector3, normal: Vector3, radius_metres: float, amount: float, stage: Stage
) -> PackedInt32Array:
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
			_touch(origin + Vector2i(x, y), amount * falloff, stage, finished)
	# Uploaded once per call and only when a pixel actually moved: a trigger held
	# on a spot that is already done should not cost a texture upload a tick.
	if _dirty:
		_texture.update(_image)
		_dirty = false
	return finished


## Moves units between two buckets of one pixel and keeps the totals honest about
## it.
##
## [param at] is in image coordinates, not tile ones. Appends to [param finished]
## when this is the pixel that finishes its patch's [param stage] off.
##
## [b]The amount is rounded to whole units before anything moves[/b], and then
## clamped to what the source bucket actually holds. Both halves matter. Rounding
## first is what makes the transfer exact on both sides — the destination gains
## precisely what the source lost, which is the conservation the class docs are
## about, and rounding twice would leak a unit a touch. Clamping is what stops a
## strong tool overdrawing a nearly-empty bucket and pushing a total negative.
##
## A tool too weak to move a whole unit moves none. The alternative — rounding
## every touch up to at least one — would let a vanishingly light brush finish the
## car given enough ticks.
func _touch(at: Vector2i, amount: float, stage: Stage, finished: PackedInt32Array) -> void:
	var pixel: Color = _image.get_pixel(at.x, at.y)
	var mud: int = roundi(pixel.r * float(UNITS))
	var foamed: int = roundi(pixel.g * float(UNITS))
	var buffed: int = roundi(pixel.b * float(UNITS))
	var moved: int = mini(roundi(amount * float(UNITS)), _source(stage, mud, foamed, buffed))
	if moved <= 0:
		return
	var patch: int = _patch_at(at)
	match stage:
		Stage.WASHED:
			mud -= moved
			_mud[patch] -= moved
			_mud_total -= moved
		Stage.FOAMED:
			foamed += moved
			_product[patch] += moved
			_product_total += moved
		Stage.BUFFED:
			foamed -= moved
			buffed += moved
			_product[patch] -= moved
			_product_total -= moved
			_shine[patch] += moved
			_shine_total += moved
	_image.set_pixel(
		at.x,
		at.y,
		Color(
			float(mud) / float(UNITS),
			float(foamed) / float(UNITS),
			float(buffed) / float(UNITS),
			1.0
		)
	)
	_dirty = true
	# Every unit that reaches here is progress, and that is the tools' doing rather
	# than this function's. No tool empties a bucket back into the one it came from
	# — [method worked] has the argument and [method wash] the change that bought it
	# — so a touch that moved anything moved its patch forwards by exactly that
	# much. This used to be a second number worked out per stage, with a per-patch
	# high-water mark behind it to stop the foam/rinse/foam loop paying twice; there
	# is no loop left to stop, and the arithmetic that survives is the arithmetic
	# that was always doing the work.
	#
	# Banked against the capacity of the patch it happened on, so a unit of work is
	# a fraction of *this* patch and not of an average one — the grid does not have
	# to divide the atlas evenly for the arithmetic to be right, which is the same
	# thing [method _seed_the_totals] keeps capacities per patch for.
	if _capacity[patch] > 0:
		_worked[int(stage)] += float(moved) / float(_capacity[patch])
	# Reported on the transition and only once, without a flag to remember it by. A
	# patch that has finished a stage has nothing left in that stage's source bucket
	# and nothing refills it, so every later touch is stopped by the clamp above and
	# never reaches here. The transition rings once because it can only happen once.
	if _stage_finished(patch, stage):
		finished.append(patch)


## Which bucket [param stage] draws from, given one pixel's three stored ones.
##
## Bare paint is the interesting case and the reason this is a function rather
## than three lines at the call site: it is not stored, so a cleaner's source is
## everything the other three are not.
func _source(stage: Stage, mud: int, foamed: int, buffed: int) -> int:
	match stage:
		Stage.FOAMED:
			return UNITS - mud - foamed - buffed
		Stage.BUFFED:
			return foamed
	# The wash draws from the dirt and from nothing else. Product and shine are both
	# things the player put there, and [method wash] has why the water is not
	# allowed to take either of them back.
	return mud


## Whether [param patch] has just finished [param stage].
##
## The middle one is not "the product total reached capacity", because the rag
## takes product away again — a patch half foamed and half buffed is fully
## covered and a player has no more bottle work to do on it. What is actually
## being asked is that no bare paint and no mud remain, which is the same thing
## said in the buckets that only ever move forward.
func _stage_finished(patch: int, stage: Stage) -> bool:
	match stage:
		Stage.WASHED:
			return _mud[patch] == 0
		Stage.FOAMED:
			return _product[patch] + _shine[patch] == _capacity[patch]
	return _shine[patch] == _capacity[patch]


## What one pixel of the mask holds, at a point on the panel.
func _pixel_at(point: Vector3, normal: Vector3) -> Color:
	var uv: Vector2 = BoxProjection.uv_for(_box, point, normal)
	var x: int = clampi(int(uv.x * float(_image.get_width())), 0, _image.get_width() - 1)
	var y: int = clampi(int(uv.y * float(_image.get_height())), 0, _image.get_height() - 1)
	return _image.get_pixel(x, y)


## A running total as a fraction of the whole panel.
func _fraction(total: int) -> float:
	if _full <= 0:
		return 0.0
	return float(total) / float(_full)


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


## Fills in how many units each patch holds, which is [constant UNITS] per pixel
## it covers, without walking the image to count them.
##
## The spans are worked out the same way [method _patch_at] assigns pixels, so a
## patch grid that does not divide the atlas evenly still adds up to exactly the
## number of pixels there are — a patch that was short by a pixel would be a
## patch that never rang.
##
## [b]Capacity is kept as well as the three totals[/b], and it is what the two
## later stages are measured against. Mud could get away without it because it
## starts full and only falls, so zero is the answer; product and shine start
## empty and rise, and "how high is full here" is a different number for every
## patch on a grid that does not divide evenly.
func _seed_the_totals() -> void:
	var count: int = patches()
	# One running tally per stage of the job, all three starting at nothing done —
	# see [method worked]. Sized off the enum rather than off a literal three, so
	# a fourth pass is not a silent out-of-range on the first touch of it.
	_worked.resize(Stage.size())
	_worked.fill(0.0)
	_mud.resize(count)
	_product.resize(count)
	_shine.resize(count)
	_capacity.resize(count)
	var widths: PackedInt32Array = _spans(_image.get_width(), _patches_across)
	var heights: PackedInt32Array = _spans(_image.get_height(), _patches_down)
	_full = 0
	for row: int in _patches_down:
		for column: int in _patches_across:
			var patch: int = row * _patches_across + column
			var units: int = widths[column] * heights[row] * UNITS
			_capacity[patch] = units
			_mud[patch] = units
			_product[patch] = 0
			_shine[patch] = 0
			_full += units
	_mud_total = _full
	_product_total = 0
	_shine_total = 0


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
