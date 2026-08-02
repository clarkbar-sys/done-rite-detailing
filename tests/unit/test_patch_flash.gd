## Unit tests for [PatchFlash] — the decaying square a patch throws when it
## finishes a step of the job.
##
## [b]What is worth pinning here is the wiring to the shader, not the taste.[/b]
## How bright a flash is and how long it lasts are numbers somebody will turn up
## or down the first time they see the game move, and a test that asserted them
## would be a test that goes red for a tuning commit. What cannot be allowed to
## drift is the contract [code]grime.gdshader[/code] reads this through: red is
## the level, green is the stage at 0, 0.5 and 1, and patch [i]n[/i] is the pixel
## the map's own row-major index says it is. Get any of those wrong and the wrong
## square lights up — which looks like a projection bug, and would send whoever
## found it to [BoxProjection] rather than here.
##
## Under tests/unit/ because none of it needs a scene tree: the class is a
## [RefCounted] around a small [Image], and the frames that would normally drive
## the fade are a number handed to [method PatchFlash.fade]. That is also why the
## decay is testable at all — a flash driven off [member Node.process_delta] would
## only be assertable by waiting for it.
extends GutTest

## A grid that is not square and whose two axes are not multiples of each other,
## so a swapped row and column has somewhere to show. The real one is 12 × 8.
const GRID: Vector2i = Vector2i(5, 3)

## What a level read back off the class's own bookkeeping is allowed to be out by,
## which is nothing anybody meant — the levels are plain floats.
const TOLERANCE: float = 0.0001

## What a level read back off a [i]pixel[/i] is allowed to be out by: one step of
## an eight-bit channel.
##
## Not a looser tolerance for the same assertion — a different one, because it is
## measuring a different thing. An [Image] stores 8 bits a channel, so the stage a
## cleaner writes is 127/255 rather than 0.5 and a flash a quarter faded is
## 191/255 rather than 0.75. Asserting those to a float's precision is asserting
## that the format has more resolution than it has. [GrimeMap]'s class docs have
## the version of this that actually cost somebody an afternoon; here it is only
## worth knowing that the shader's own thresholds — 0.25 and 0.75 in `flash_tint`
## — sit nowhere near a channel step of any of the three values it separates.
const CHANNEL: float = 1.0 / 255.0

var _flash: PatchFlash = null


func before_each() -> void:
	_flash = PatchFlash.new(GRID)


## Every patch the grid holds, which is what an out-of-range index is measured
## against.
func _patches() -> int:
	return GRID.x * GRID.y


## What the shader would sample for [param patch] — read off the image rather than
## off the class's own levels, because the image is what is uploaded and the
## levels are only what it was built from. [method PatchFlash.image] says why it
## cannot be read back off the texture instead.
func _pixel(patch: int) -> Color:
	return _flash.image().get_pixel(patch % GRID.x, patch / GRID.x)


# ---- what a fresh one holds ----------------------------------------------------


func test_a_fresh_panel_has_nothing_lit() -> void:
	assert_eq(_flash.lit(), 0)
	for patch: int in _patches():
		assert_almost_eq(_flash.level(patch), 0.0, TOLERANCE, "patch %d" % patch)


func test_the_image_is_the_size_of_the_patch_grid() -> void:
	# Sized from [method GrimeMap.patch_grid] by the caller, so this is really an
	# assertion that nothing here quietly reshapes it — the shader samples this
	# through the same atlas coordinates as the mask, and a grid of a different
	# shape would light a square in the wrong place rather than fail.
	var image: Image = _flash.image()
	assert_eq(image.get_width(), GRID.x)
	assert_eq(image.get_height(), GRID.y)


func test_a_degenerate_grid_still_makes_an_image() -> void:
	# An [Image] of zero width cannot be created at all, so a caller that got a
	# patch grid from a panel with no size would take the whole game down rather
	# than draw nothing. One pixel is the smallest honest answer.
	var pinched: PatchFlash = PatchFlash.new(Vector2i(0, -4))
	var image: Image = pinched.image()
	assert_eq(image.get_width(), 1)
	assert_eq(image.get_height(), 1)


# ---- lighting one up -----------------------------------------------------------


func test_a_finished_patch_lights_up_fully() -> void:
	_flash.flare(7, GrimeMap.Stage.WASHED)
	assert_eq(_flash.lit(), 1)
	assert_almost_eq(_flash.level(7), 1.0, TOLERANCE)


func test_it_lights_the_square_the_patch_index_names_and_no_other() -> void:
	# The assertion this file exists for. Patch indices are row-major across the
	# whole atlas — [method GrimeMap._patch_at]'s ordering, and the one the signal
	# carries — so patch 7 on a five-wide grid is the third column of the second
	# row. Getting this wrong lights a square somewhere else on the car, which
	# reads as a projection bug and sends the next person to the wrong file.
	_flash.flare(7, GrimeMap.Stage.WASHED)
	assert_almost_eq(_pixel(7).r, 1.0, CHANNEL, "the patch that finished")
	for patch: int in _patches():
		if patch == 7:
			continue
		assert_almost_eq(_pixel(patch).r, 0.0, CHANNEL, "patch %d lit up too" % patch)


func test_each_pass_is_stored_as_the_shader_reads_it_back() -> void:
	# `flash_tint` in `grime.gdshader` splits at 0.25 and 0.75, so these three are
	# the values that pick water, the panel's own cleaner and gold. Asserted as the
	# numbers rather than through the enum, because the shader has no enum and
	# renumbering [enum GrimeMap.Stage] would silently repaint two of the three.
	_flash.flare(0, GrimeMap.Stage.WASHED)
	_flash.flare(1, GrimeMap.Stage.FOAMED)
	_flash.flare(2, GrimeMap.Stage.BUFFED)
	assert_almost_eq(_pixel(0).g, 0.0, CHANNEL, "a wash")
	assert_almost_eq(_pixel(1).g, 0.5, CHANNEL, "a cleaner")
	assert_almost_eq(_pixel(2).g, 1.0, CHANNEL, "the rag")


func test_relighting_a_glowing_patch_restarts_it_rather_than_stacking() -> void:
	# The case is the next stage landing on a square still lit from the last one.
	# The honest picture is the newer event at full brightness in its own colour,
	# not a brighter smear of two — and the level must not climb past one, or the
	# fade would take longer for no reason a player could see.
	_flash.flare(4, GrimeMap.Stage.WASHED)
	_flash.fade(PatchFlash.SECONDS * 0.5)
	_flash.flare(4, GrimeMap.Stage.BUFFED)
	assert_almost_eq(_flash.level(4), 1.0, TOLERANCE, "it did not restart")
	assert_eq(_flash.lit(), 1, "and it did not count twice")
	assert_almost_eq(_pixel(4).g, 1.0, CHANNEL, "it kept the older pass's colour instead")


func test_a_patch_that_is_not_there_is_ignored_rather_than_fatal() -> void:
	_flash.flare(-1, GrimeMap.Stage.WASHED)
	_flash.flare(_patches(), GrimeMap.Stage.WASHED)
	assert_eq(_flash.lit(), 0)
	assert_almost_eq(_flash.level(-1), 0.0, TOLERANCE)
	assert_almost_eq(_flash.level(_patches()), 0.0, TOLERANCE)
	assert_almost_eq(_flash.stage_at(_patches()), 0.0, TOLERANCE)


# ---- putting it out ------------------------------------------------------------


func test_a_flash_dims_as_time_passes() -> void:
	_flash.flare(3, GrimeMap.Stage.WASHED)
	assert_true(_flash.fade(PatchFlash.SECONDS * 0.25), "it went out in a quarter of its life")
	assert_almost_eq(_flash.level(3), 0.75, TOLERANCE)
	assert_almost_eq(_pixel(3).r, 0.75, CHANNEL, "and the texture followed it down")


func test_a_flash_is_out_after_its_own_lifetime() -> void:
	_flash.flare(3, GrimeMap.Stage.BUFFED)
	assert_false(_flash.fade(PatchFlash.SECONDS), "it was still lit")
	assert_eq(_flash.lit(), 0)
	assert_almost_eq(_flash.level(3), 0.0, TOLERANCE)
	assert_almost_eq(_pixel(3).r, 0.0, CHANNEL)


func test_a_long_frame_does_not_push_a_flash_below_nothing() -> void:
	# A tab that was backgrounded hands back a delta of whatever it liked. Clamped
	# rather than trusted, or the level goes negative, the lit count goes with it,
	# and every later flash on that panel is one short of ever clearing.
	_flash.flare(3, GrimeMap.Stage.WASHED)
	_flash.fade(PatchFlash.SECONDS * 40.0)
	assert_almost_eq(_flash.level(3), 0.0, TOLERANCE)
	assert_eq(_flash.lit(), 0)


func test_fading_a_dark_panel_says_there_was_nothing_to_do() -> void:
	# The return is what lets [method Grime._process] stay cheap on a car nobody is
	# touching — see that method. False on the first ask, without having walked the
	# grid at all.
	assert_false(_flash.fade(0.016))


func test_a_frame_of_no_time_leaves_a_flash_exactly_as_it_was() -> void:
	# The first frame after a pause hands back a zero delta. It has to be a no-op
	# rather than a step of zero size, because the answer still has to be "yes,
	# something is lit" — and it is the only case where nothing changed but the
	# caller should keep asking.
	_flash.flare(2, GrimeMap.Stage.FOAMED)
	assert_true(_flash.fade(0.0))
	assert_almost_eq(_flash.level(2), 1.0, TOLERANCE)


func test_two_patches_fade_together_and_independently() -> void:
	_flash.flare(1, GrimeMap.Stage.WASHED)
	_flash.fade(PatchFlash.SECONDS * 0.5)
	_flash.flare(9, GrimeMap.Stage.BUFFED)
	assert_eq(_flash.lit(), 2)
	# Long enough to finish the older one off and leave the newer one half lit,
	# which is the case a single shared timer would get wrong.
	assert_true(_flash.fade(PatchFlash.SECONDS * 0.5))
	assert_almost_eq(_flash.level(1), 0.0, TOLERANCE, "the older one")
	assert_almost_eq(_flash.level(9), 0.5, TOLERANCE, "the newer one")
	assert_eq(_flash.lit(), 1)


# ---- what the material was handed ----------------------------------------------


func test_the_texture_is_the_same_one_for_the_life_of_the_panel() -> void:
	# [method Grime._overlay] hands this over once and never again, so it has to be
	# updated in place. A class that swapped in a new [ImageTexture] per flash would
	# leave every material pointing at the first one and nothing would ever light
	# up on screen — while every assertion above still passed.
	var first: RID = _flash.texture().get_rid()
	_flash.flare(6, GrimeMap.Stage.WASHED)
	_flash.fade(PatchFlash.SECONDS * 0.5)
	assert_eq(_flash.texture().get_rid(), first)
