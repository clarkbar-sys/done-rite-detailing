## Unit tests for [GrimeMap]'s later two passes — the product a cleaner lays on
## and the shine a rag buffs out of it.
##
## Split from [code]tests/unit/test_grime_map.gd[/code], which covers the same
## class's first pass and its bookkeeping. One file would be the obvious place
## for all of it and is over gdlint's public-method ceiling; the seam is the
## honest one, because everything here needs a panel that has already been washed
## and nothing there does.
##
## What is being pinned throughout is the conservation law rather than any
## individual number: every tool moves units between buckets and none of them
## invents or loses one, which is what makes the job layered without a line of
## sequencing logic anywhere. [GrimeMap]'s class docs argue it; this is what the
## argument bought.
extends GutTest

## The same door-sized panel the first-pass tests use, for the same reason: not
## square on any axis, so a swapped axis has somewhere to show.
const PANEL: AABB = AABB(Vector3(-0.1, 0.0, -1.5), Vector3(0.2, 1.2, 3.0))

const TILE: int = 16
const PATCHES: int = 2
const TOLERANCE: float = 0.0001

var _map: GrimeMap = null


func before_each() -> void:
	_map = GrimeMap.new(PANEL, TILE, PATCHES)


## The middle of the panel's right-hand face, which is where everything below
## points its tools.
func _middle() -> Vector3:
	return Vector3(0.1, 0.6, 0.0)


## Washes a spot flat, so what follows can start from bare paint rather than from
## a panel that still has mud in the way. Bounded rather than a `while`, because a
## test that can hang is a CI job that times out with no output.
func _wash_bare(at: Vector3, radius: float) -> void:
	for _sweep: int in 400:
		_map.wash(at, Vector3.RIGHT, radius, 0.05)


## Covers a spot completely, and [method _buff_out] finishes one off.
##
## [b]Held rather than pressed once, and that is not a detail.[/b] A single call
## at full strength does not saturate the texel under the point, because the brush
## falls off from the centre of the [i]splash[/i] and the sample sits up to half a
## texel off it — so the pixel a test reads back is a fraction short. Every tool
## in this game is held rather than clicked, so looping is also what the game
## does; a test that pressed once would be asserting against a stronger tool than
## the player has.
func _foam_over(at: Vector3, radius: float) -> void:
	for _sweep: int in 200:
		_map.foam(at, Vector3.RIGHT, radius, 0.05)


func _buff_out(at: Vector3, radius: float) -> void:
	for _sweep: int in 200:
		_map.buff(at, Vector3.RIGHT, radius, 0.05)


## Which patch a point on the right-hand face belongs to, worked out the way the
## map does it rather than by knowing the answer.
func _patch_under(at: Vector3) -> int:
	var image: Image = _map.image()
	var uv: Vector2 = BoxProjection.uv_for(PANEL, at, Vector3.RIGHT)
	var x: int = clampi(int(uv.x * float(image.get_width())), 0, image.get_width() - 1)
	var y: int = clampi(int(uv.y * float(image.get_height())), 0, image.get_height() - 1)
	var across: int = BoxProjection.COLUMNS * PATCHES
	return (
		(y * BoxProjection.ROWS * PATCHES / image.get_height()) * across
		+ (x * across / image.get_width())
	)


## Runs all three tools over a stretch of the panel in a messy interleaving, so
## the assertions that follow are not looking at the tidy sequence that works by
## construction.
func _work_it_over() -> void:
	for step: int in 40:
		var along: float = -0.6 + 0.03 * float(step)
		var at: Vector3 = Vector3(0.1, 0.6, along)
		_map.wash(at, Vector3.RIGHT, 0.2, 0.11)
		_map.foam(at, Vector3.RIGHT, 0.25, 0.07)
		_map.buff(at, Vector3.RIGHT, 0.15, 0.09)


# ---- the conveyor: mud, then product, then shine -------------------------------


func test_a_cleaner_does_nothing_to_a_muddy_panel() -> void:
	# The first of the three ordering rules, and the point of the whole bucket
	# model: this is not a refusal anybody wrote. A cleaner draws from bare paint,
	# a fresh panel has none, so there is nothing to move. No gate to forget at a
	# call site, and no way to soap a car that has not been washed.
	assert_eq(_map.foam(_middle(), Vector3.RIGHT, 0.4, 1.0).size(), 0)
	assert_almost_eq(_map.product(), 0.0, TOLERANCE, "product went onto mud")
	assert_almost_eq(_map.remaining(), 1.0, TOLERANCE, "and the cleaner moved mud")


func test_a_rag_does_nothing_to_a_bare_panel() -> void:
	# The third rule, the same way: the rag draws from product, and paint that has
	# never been treated has none. So a player who washes and then reaches
	# straight for the cloth gets no shine — they have to pick up a bottle first.
	_wash_bare(_middle(), 0.4)
	assert_gt(_map.bare_at(_middle(), Vector3.RIGHT), 0.9, "the spot did not come clean")
	assert_eq(_map.buff(_middle(), Vector3.RIGHT, 0.4, 1.0).size(), 0)
	assert_almost_eq(_map.shine(), 0.0, TOLERANCE, "shine appeared out of nothing")


func test_a_cleaner_covers_the_paint_the_water_bared() -> void:
	_wash_bare(_middle(), 0.4)
	_foam_over(_middle(), 0.4)
	assert_gt(_map.product_at(_middle(), Vector3.RIGHT), 0.9, "the spot was not covered")
	assert_almost_eq(
		_map.bare_at(_middle(), Vector3.RIGHT), 0.0, TOLERANCE, "and bare paint was left under it"
	)


func test_the_rag_turns_product_into_shine() -> void:
	# One transfer and not two: the shine a panel ends up with is exactly the
	# product that was put on it, which is why a half-soaped panel cannot be
	# buffed to a full shine.
	_wash_bare(_middle(), 0.4)
	_foam_over(_middle(), 0.4)
	var covered: float = _map.product_at(_middle(), Vector3.RIGHT)
	_buff_out(_middle(), 0.4)
	assert_almost_eq(_map.product_at(_middle(), Vector3.RIGHT), 0.0, TOLERANCE, "product was left")
	assert_almost_eq(
		_map.shine_at(_middle(), Vector3.RIGHT), covered, TOLERANCE, "the shine is not what went on"
	)


func test_a_spot_taken_all_the_way_through_is_finished() -> void:
	# The whole job on one texel, and the definition of done: every unit in the
	# shine bucket, arrived at by having passed through the other two.
	_wash_bare(_middle(), 0.4)
	_foam_over(_middle(), 0.4)
	_buff_out(_middle(), 0.4)
	assert_eq(_map.shine_at(_middle(), Vector3.RIGHT), 1.0, "the middle is not fully buffed")
	# The texel and not its patch: this brush is a couple of texels across and a
	# patch here is eight, so the spot is finished and the patch around it is not.
	# [method test_finishing_a_patch_outright_is_reported_once] is the patch's own
	# version of this, with a brush wide enough to mean it.
	assert_false(_map.is_patch_finished(_patch_under(_middle())), "the patch cannot be done yet")


func test_half_a_wash_is_all_a_cleaner_can_cover() -> void:
	# The ceiling rises as the water works rather than a gate flipping: a spot
	# that is a third washed takes a third of a coat, and the rest of the bottle
	# goes nowhere until the jet comes back.
	_map.wash(_middle(), Vector3.RIGHT, 0.4, 0.4)
	var bared: float = _map.bare_at(_middle(), Vector3.RIGHT)
	assert_between(bared, 0.2, 0.8, "the spot should be part-washed for this to mean anything")
	_map.foam(_middle(), Vector3.RIGHT, 0.4, 1.0)
	assert_almost_eq(
		_map.product_at(_middle(), Vector3.RIGHT),
		bared,
		TOLERANCE,
		"product exceeded the bare paint"
	)


# ---- and the buckets always add up ---------------------------------------------


func test_nothing_a_tool_does_creates_or_destroys_a_unit() -> void:
	# The conservation law, asserted on the pixels rather than on the totals that
	# claim to describe them. Every tool moves units between buckets; if any of
	# them rounded on both sides of a transfer, a texel would quietly lose a unit
	# of itself and could never be finished. Run over a messy interleaving rather
	# than a tidy sequence, because the tidy one is the case that works.
	_work_it_over()
	var image: Image = _map.image()
	for y: int in image.get_height():
		for x: int in image.get_width():
			var pixel: Color = image.get_pixel(x, y)
			var held: float = pixel.r + pixel.g + pixel.b
			assert_between(
				held, 0.0, 1.0 + TOLERANCE, "pixel %d,%d holds more than itself" % [x, y]
			)


func test_the_running_totals_match_the_pixels_they_claim_to_describe() -> void:
	# The same drift guard the mud total has always had, extended to the two
	# channels that go up as well as down. A total that disagreed with the image
	# would call a patch finished while product was still on it — invisible in the
	# arithmetic and obvious on the car.
	_work_it_over()
	var mud: float = 0.0
	var product: float = 0.0
	var shine: float = 0.0
	var image: Image = _map.image()
	for y: int in image.get_height():
		for x: int in image.get_width():
			var pixel: Color = image.get_pixel(x, y)
			mud += pixel.r
			product += pixel.g
			shine += pixel.b
	var pixels: float = float(image.get_width() * image.get_height())
	assert_almost_eq(_map.remaining(), mud / pixels, TOLERANCE, "the mud total")
	assert_almost_eq(_map.product(), product / pixels, TOLERANCE, "the product total")
	assert_almost_eq(_map.shine(), shine / pixels, TOLERANCE, "the shine total")


# ---- what each stage reports finishing -----------------------------------------


func test_covering_a_patch_is_reported_once() -> void:
	# The middle stage's own ding. It fires when a patch has no mud and no bare
	# paint left — which is to say, when there is nothing more a bottle can do to
	# it — and it cannot fire twice, because a patch in that state has nothing left
	# for a cleaner to draw from.
	_wash_bare(_middle(), 2.0)
	var rung: int = 0
	for _sweep: int in 200:
		rung += _map.foam(_middle(), Vector3.RIGHT, 2.0, 0.05).size()
	assert_eq(rung, PATCHES * PATCHES, "a patch rang more than once, or one never rang")


func test_finishing_a_patch_outright_is_reported_once() -> void:
	_wash_bare(_middle(), 2.0)
	for _sweep: int in 200:
		_map.foam(_middle(), Vector3.RIGHT, 2.0, 0.05)
	var rung: int = 0
	for _sweep: int in 200:
		rung += _map.buff(_middle(), Vector3.RIGHT, 2.0, 0.05).size()
	assert_eq(rung, PATCHES * PATCHES, "a patch rang more than once, or one never rang")
	assert_true(_map.is_patch_finished(_patch_under(_middle())), "and the patch does not say so")


func test_a_patch_is_only_finished_when_it_is_buffed_and_not_when_it_is_clean() -> void:
	# The distinction the whole change is about: the power wash used to be the
	# end of the job, and now it is the first third of it. A patch with the mud
	# off is clean and is not finished.
	_wash_bare(_middle(), 2.0)
	var face: int = _patch_under(_middle())
	assert_true(_map.is_patch_clean(face), "the mud is off")
	assert_false(_map.is_patch_finished(face), "but the job is not done")
	# And the same distinction one level up. Both are false here only because a
	# box has faces nobody can reach — [method GrimeMap.is_clean] says why — so
	# what is being pinned is that finishing is the stricter of the two.
	assert_false(_map.is_finished(), "a panel with no shine on it is not finished")


# ---- and the water undoes the bottle -------------------------------------------


func test_the_wash_takes_product_off_as_well_as_mud() -> void:
	# The lesson the whole ordering exists to teach: spray a panel you have just
	# treated and you rinse the treatment off, so there is no way to leave the
	# water till last and still finish. Not a rule written anywhere — the wash
	# simply draws from both of the buckets that are things lying on the paint.
	_wash_bare(_middle(), 0.4)
	_foam_over(_middle(), 0.4)
	assert_gt(_map.product_at(_middle(), Vector3.RIGHT), 0.9, "the spot was not covered first")
	# Held rather than pressed once, for the reason [method _foam_over] records:
	# the brush falls off from the centre of the splash and the sample sits up to
	# half a texel off it, so a single call leaves a fraction behind.
	_wash_bare(_middle(), 0.4)
	assert_almost_eq(
		_map.product_at(_middle(), Vector3.RIGHT), 0.0, TOLERANCE, "the jet left the product on"
	)
	assert_gt(_map.bare_at(_middle(), Vector3.RIGHT), 0.9, "and it did not go back to bare paint")


func test_the_wash_leaves_a_buffed_panel_alone() -> void:
	# The one thing water is not allowed to undo. A stray jet across a finished
	# wing costing the player three passes of work is a punishment for imprecision
	# rather than a rule anybody can learn — [method GrimeMap.wash] has the
	# argument.
	_wash_bare(_middle(), 0.4)
	_foam_over(_middle(), 0.4)
	_buff_out(_middle(), 0.4)
	var shone: float = _map.shine_at(_middle(), Vector3.RIGHT)
	assert_gt(shone, 0.9, "the spot was not finished first")
	for _sweep: int in 40:
		_map.wash(_middle(), Vector3.RIGHT, 0.4, 1.0)
	assert_almost_eq(
		_map.shine_at(_middle(), Vector3.RIGHT), shone, TOLERANCE, "the jet stripped the shine"
	)


func test_the_wash_takes_the_mud_before_the_product() -> void:
	# Order rather than a split, because they are the same water. A texel that is
	# part muddy and part soaped should come clean in the order a jet would take
	# them off, which also keeps a half-washed panel behaving sensibly under a
	# player sweeping back and forth over it.
	_map.wash(_middle(), Vector3.RIGHT, 0.4, 0.5)
	_map.foam(_middle(), Vector3.RIGHT, 0.4, 1.0)
	var mud: float = _map.mud_at(_middle(), Vector3.RIGHT)
	var product: float = _map.product_at(_middle(), Vector3.RIGHT)
	assert_gt(mud, 0.1, "the spot should still be part muddy for this to mean anything")
	assert_gt(product, 0.1, "and part soaped")
	# Less water than there is mud, so a jet that went for the product first would
	# be visible as product coming off while mud stayed put.
	_map.wash(_middle(), Vector3.RIGHT, 0.4, mud * 0.5)
	assert_lt(_map.mud_at(_middle(), Vector3.RIGHT), mud, "the mud did not come off first")
	assert_almost_eq(
		_map.product_at(_middle(), Vector3.RIGHT), product, TOLERANCE, "the product went first"
	)


func test_rinsing_product_off_a_clean_patch_rings_nothing() -> void:
	# The trap the extra guard in [method GrimeMap._touch] exists for. With the mud
	# already gone the wash goes on moving units, and "this patch has no mud" is
	# true on every one of them — so a check on the patch's state alone would ring
	# a bell per tick for as long as the trigger was held.
	_wash_bare(_middle(), 2.0)
	_foam_over(_middle(), 2.0)
	var rung: int = 0
	for _sweep: int in 60:
		rung += _map.wash(_middle(), Vector3.RIGHT, 2.0, 0.2).size()
	assert_eq(rung, 0, "washing product off an already-clean patch rang the bell")


func test_a_patch_rinsed_bare_can_be_covered_and_ring_again() -> void:
	# And the other side of it: the covering ding is allowed to fire twice,
	# because the player really did do the work twice. What must not repeat is a
	# bell for a transition that never happened.
	_wash_bare(_middle(), 2.0)
	var first: int = 0
	for _sweep: int in 200:
		first += _map.foam(_middle(), Vector3.RIGHT, 2.0, 0.05).size()
	assert_eq(first, PATCHES * PATCHES, "the face did not come up covered the first time")
	for _sweep: int in 60:
		_map.wash(_middle(), Vector3.RIGHT, 2.0, 0.2)
	var again: int = 0
	for _sweep: int in 200:
		again += _map.foam(_middle(), Vector3.RIGHT, 2.0, 0.05).size()
	assert_eq(again, first, "re-covering a rinsed face did not report the same patches")
