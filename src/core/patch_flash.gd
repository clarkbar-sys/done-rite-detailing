## The bright square a patch throws when it finishes a step of the job: one small
## image per panel, at patch resolution, holding how lit each patch is right now
## and which of the three passes lit it.
##
## [b]The visual half of the ding.[/b] [Grime] already emits
## [signal Grime.patch_finished] on exactly the transition worth celebrating, and
## until now the only thing listening was the bell. A patch coming clean moved a
## few hundred texels slightly and made a noise; nothing on screen said "that one
## is done". This is the thing that says it.
##
## [b]Its own class rather than three more methods on [GrimeMap].[/b] The map is
## the state of a panel — what is on it, and what a tool has moved. A flash is not
## state: it is a decaying picture of something that has already happened, it is
## gone a third of a second later, and nothing about the job's rules depends on
## it. Keeping it out means [GrimeMap]'s conservation arithmetic — the part of
## this project worth being frightened of — is not touched at all by making the
## game look better.
##
## [b]One pixel per patch, which is the resolution the effect actually wants.[/b]
## The grime mask is 192 × 128 a panel because water lands in shapes; a patch is
## finished or it is not, so its flash is 12 × 8 and a nearest-neighbour sample in
## the shader lights the exact square that just rang. Painting one is a single
## [method Image.set_pixel] rather than a loop over a few hundred, and the whole
## thing is 384 bytes — which is also why this uploads on every write instead of
## batching behind a dirty flag the way [GrimeMap] has to.
##
## [b]RGBA8 for a value that needs one and a half channels.[/b] Red is how lit the
## patch is and green is which pass lit it, so the shader can throw water at a
## wash, the panel's own cleaner at a foam and gold at a buff without a second
## texture to keep in step. The two spare channels are the price of using the
## format the mask has already proved works on the web build, which renders in
## Compatibility on a [code]nothreads[/code] template (STANDARDS.md has why); 288
## wasted bytes a panel is not worth finding out whether a single-channel texture
## is one of the things that behaves differently there.
class_name PatchFlash
extends RefCounted

## How long a patch stays lit for, in seconds.
##
## Tuned against the bell rather than by eye. [constant Bell.PATCH_SECONDS] is
## 0.36, and a light that outlasts its own ding reads as a second event rather
## than as the same one — so this is slightly shorter, and the square is dark
## again while the note is still ringing out.
const SECONDS: float = 0.3

## The highest [enum GrimeMap.Stage] there is, which is what a stage is divided by
## to fit in a channel. Three stages numbered 0, 1, 2, so a wash stores 0, a foam
## 0.5 and a buff 1 — and [code]grime.gdshader[/code] reads them back at those
## thresholds.
const LAST_STAGE: float = 2.0

var _across: int
var _down: int
var _image: Image = null
var _texture: ImageTexture = null
var _level: PackedFloat32Array = PackedFloat32Array()
var _stage: PackedFloat32Array = PackedFloat32Array()
var _lit: int = 0


## [param grid] is how many patches the panel is diced into, across and down —
## [method GrimeMap.patch_grid], and it has to come from there rather than be
## worked out again here. The shader samples this texture through the same atlas
## coordinates it samples the mask through, so a flash image that disagreed with
## the map about the patch grid would light the wrong square.
func _init(grid: Vector2i) -> void:
	_across = maxi(grid.x, 1)
	_down = maxi(grid.y, 1)
	_image = Image.create_empty(_across, _down, false, Image.FORMAT_RGBA8)
	_image.fill(Color(0.0, 0.0, 0.0, 1.0))
	_texture = ImageTexture.create_from_image(_image)
	_level.resize(_across * _down)
	_stage.resize(_across * _down)


## The flash map, for the overlay to sample. The same texture for the life of the
## panel — it is updated in place, so a material handed this once never has to be
## handed it again.
func texture() -> ImageTexture:
	return _texture


## The flash map as an image, for a test that wants to read a pixel rather than
## trust a level.
##
## Here for the same reason [method GrimeMap.image] is, and it is not a
## convenience. [method Texture2D.get_image] reads back through the rendering
## server, and headless — which is where this project's tests run — there is
## nothing on the other end of that to have received the upload, so it hands back
## a blank. The [Image] is the thing being uploaded [i]from[/i] and is the only
## copy assertable without a rendering device.
func image() -> Image:
	return _image


## Lights [param patch] up, having just finished [param stage].
##
## Re-lighting one that is still glowing restarts it at full rather than adding to
## it. A patch can only finish a given stage once, so the case this covers is the
## next stage landing on a square that is still lit from the last one — and there
## the honest picture is the newer event's colour at full brightness, not a
## brighter smear of two.
func flare(patch: int, stage: GrimeMap.Stage) -> void:
	if patch < 0 or patch >= _level.size():
		return
	if _level[patch] <= 0.0:
		_lit += 1
	_level[patch] = 1.0
	_stage[patch] = float(stage) / LAST_STAGE
	_write(patch)
	_texture.update(_image)


## Dims every lit patch by [param seconds] worth of [constant SECONDS], and
## returns whether anything is still lit afterwards.
##
## The return is what lets a caller stop asking: with nothing glowing this is a
## single comparison, so a car sitting untouched costs one branch a frame per
## panel rather than a texture upload.
func fade(seconds: float) -> bool:
	if _lit <= 0:
		return false
	if seconds <= 0.0:
		return true
	var step: float = seconds / SECONDS
	for patch: int in _level.size():
		if _level[patch] <= 0.0:
			continue
		_level[patch] = maxf(_level[patch] - step, 0.0)
		if _level[patch] <= 0.0:
			_lit -= 1
		_write(patch)
	_texture.update(_image)
	return _lit > 0


## How many patches are glowing right now.
func lit() -> int:
	return _lit


## How lit one patch is, as [code]0..1[/code]. Out-of-range patches read zero
## rather than erroring, for the reason [method GrimeMap.is_patch_clean] does the
## same: a caller asking about a patch that is not there is asking a question with
## an honest answer.
func level(patch: int) -> float:
	if patch < 0 or patch >= _level.size():
		return 0.0
	return _level[patch]


## Which stage lit one patch, as the shader reads it: 0 for a wash, 0.5 for a
## cleaner, 1 for the rag. Meaningless on a patch that is not lit.
func stage_at(patch: int) -> float:
	if patch < 0 or patch >= _stage.size():
		return 0.0
	return _stage[patch]


## Puts one patch's two numbers into the pixel that stands for it.
##
## The patch index is laid out the way [GrimeMap] lays it out — row-major across
## the whole atlas — because that is the index the signal carries and there is no
## second ordering worth inventing.
func _write(patch: int) -> void:
	var at: Vector2i = Vector2i(patch % _across, patch / _across)
	_image.set_pixel(at.x, at.y, Color(_level[patch], _stage[patch], 0.0, 1.0))
