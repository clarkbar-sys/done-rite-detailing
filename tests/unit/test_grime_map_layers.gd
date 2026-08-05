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


## How many different patches are named in [param rung].
##
## What "the ding rings once each" is asserted with below, in place of the count
## of one face's patches these tests used to compare against. The brush is a ball
## of a radius in metres and no longer stops at the edge of the face it started on
## — [code]tests/unit/test_grime_map_reach.gd[/code] is that — so how many patches
## a two-metre splash ends up reaching is a fact about the brush, and a number
## written down here would be this file asserting the brush's shape by accident.
##
## Reporting the same patch twice is still exactly the bug worth catching: a bell
## that rang on every tick a patch was already finished would be a slot machine
## with the arm stuck down. That is what this catches, and it catches it whatever
## the splash turns out to cover.
func _distinct(rung: PackedInt32Array) -> int:
	var seen: Dictionary = {}
	for patch: int in rung:
		seen[patch] = true
	return seen.size()


## The whole job on the whole of the right-hand face, all three tools in order.
##
## [b]A brush wider than the face, and that is the point of having this as well as
## the three helpers above.[/b] The brush falls off from the centre of its splash,
## so a radius that fits inside the tile leaves a fringe the tool is too weak to
## finish — genuinely unfinished ground, which a second pass is right to be paid
## for. Only a face taken all the way to saturated can tell "this was already done"
## from "there was a little more of it to do".
func _work_a_face_through() -> void:
	_wash_bare(_middle(), 2.0)
	_foam_over(_middle(), 2.0)
	_buff_out(_middle(), 2.0)


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


# ---- the work ledger ---------------------------------------------------------
#
# What [method GrimeMap.worked] counts, which is what the score is paid from. The
# assertions here are all identities against the mask rather than against
# remembered numbers: the ledger and the pixels are two accounts of the same
# transfers, so any drift between them is the bug worth catching, and no tuning
# commit can make one of these go red on its own.


func test_a_fresh_panel_has_had_no_work_done_on_it() -> void:
	for stage: GrimeMap.Stage in [
		GrimeMap.Stage.WASHED, GrimeMap.Stage.FOAMED, GrimeMap.Stage.BUFFED
	]:
		assert_eq(_map.worked(stage), 0.0, "stage %d starts with work already done" % stage)


func test_washing_banks_work_against_the_wash_and_nothing_else() -> void:
	_wash_bare(_middle(), 0.2)
	assert_gt(_map.worked(GrimeMap.Stage.WASHED), 0.0, "washing banked no work")
	assert_eq(_map.worked(GrimeMap.Stage.FOAMED), 0.0, "washing banked work against the cleaner")
	assert_eq(_map.worked(GrimeMap.Stage.BUFFED), 0.0, "washing banked work against the rag")


## The ledger and the mask, counting the same mud two ways. Unconditional now that
## the jet moves nothing but mud: it was once only true on a panel nobody had
## foamed, because the water went on moving units after the dirt was gone.
func test_the_wash_ledger_agrees_with_the_mud_that_actually_left() -> void:
	_work_it_over()
	var gone: float = (1.0 - _map.remaining()) * float(_map.patches())
	assert_almost_eq(
		_map.worked(GrimeMap.Stage.WASHED), gone, TOLERANCE, "the wash ledger and the mask disagree"
	)


## The same identity for the last pass, and this one holds unconditionally:
## nothing but the rag makes shine, and nothing takes it away.
func test_the_buff_ledger_agrees_with_the_shine_on_the_panel() -> void:
	_work_it_over()
	var shone: float = _map.shine() * float(_map.patches())
	assert_almost_eq(
		_map.worked(GrimeMap.Stage.BUFFED),
		shone,
		TOLERANCE,
		"the buff ledger and the mask disagree"
	)


## The wage's oldest hazard, closed at the source rather than in the ledger: there
## is no longer a foam/rinse/foam loop to pay for, because the jet takes nothing
## off a covered spot. The map used to keep a per-patch high-water mark to stop the
## loop scoring twice, and this is the test that says the mark is not missed —
## every trigger in the game, held on one square, adds nothing after the first
## time through.
##
## Over a whole face rather than a spot, because "finished" has to mean finished
## and not finished in the middle — [method _work_a_face_through] has why the
## distinction is what decides whether this test proves anything.
func test_working_a_finished_face_over_again_banks_nothing() -> void:
	_work_a_face_through()
	var banked: PackedFloat64Array = PackedFloat64Array()
	for stage: int in GrimeMap.Stage.size():
		banked.append(_map.worked(stage))
	assert_gt(banked[GrimeMap.Stage.BUFFED], 0.0, "the face never finished, so this proves nothing")
	for _turn: int in 3:
		_work_a_face_through()
	for stage: int in GrimeMap.Stage.size():
		assert_almost_eq(
			_map.worked(stage),
			banked[stage],
			TOLERANCE,
			"stage %d paid for ground it had already paid for" % stage
		)


## And the ledger is not simply frozen after the first pass: ground the player
## has never covered pays whenever they get to it.
func test_covering_ground_never_covered_before_banks_work() -> void:
	_wash_bare(_middle(), 0.4)
	_foam_over(_middle(), 0.1)
	var banked: float = _map.worked(GrimeMap.Stage.FOAMED)
	_foam_over(_middle(), 0.4)
	assert_gt(_map.worked(GrimeMap.Stage.FOAMED), banked, "a wider pass banked nothing new")


## Never down, whatever order the tools go in — the score reads a difference
## against this, and a total that could fall would be a wage that could be
## clawed back.
func test_the_ledger_only_ever_goes_up() -> void:
	var highest: PackedFloat64Array = PackedFloat64Array()
	highest.resize(GrimeMap.Stage.size())
	for _round: int in 3:
		_work_it_over()
		for stage: int in highest.size():
			assert_gte(_map.worked(stage), highest[stage], "stage %d went backwards" % stage)
			highest[stage] = _map.worked(stage)


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
	var rung: PackedInt32Array = PackedInt32Array()
	for _sweep: int in 200:
		rung.append_array(_map.foam(_middle(), Vector3.RIGHT, 2.0, 0.05))
	assert_gt(rung.size(), 0, "nothing was ever reported covered")
	assert_eq(rung.size(), _distinct(rung), "a patch rang more than once")


func test_finishing_a_patch_outright_is_reported_once() -> void:
	_wash_bare(_middle(), 2.0)
	for _sweep: int in 200:
		_map.foam(_middle(), Vector3.RIGHT, 2.0, 0.05)
	var rung: int = 0
	for _sweep: int in 200:
		rung += _map.buff(_middle(), Vector3.RIGHT, 2.0, 0.05).size()
	# Against the patches that actually came out finished, which the last stage is
	# the one stage that can be asked directly. Both halves of "once each" in one
	# comparison: a patch that rang twice makes this too high and one that never
	# rang makes it too low.
	var finished: int = 0
	for patch: int in _map.patches():
		if _map.is_patch_finished(patch):
			finished += 1
	assert_gt(rung, 0, "nothing was ever reported finished")
	assert_eq(rung, finished, "a patch rang more than once, or one never rang")
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


# ---- and the water leaves the bottle's work alone ------------------------------


func test_the_wash_leaves_the_product_on() -> void:
	# What the player asked for and what [method GrimeMap.wash] argues: the jet
	# takes dirt off and touches nothing else lying on the paint. The order of the
	# job survives it — a cleaner still draws from bare paint and only the water
	# makes any — so what is dropped is the punishment and not the rule.
	_wash_bare(_middle(), 0.4)
	_foam_over(_middle(), 0.4)
	var covered: float = _map.product_at(_middle(), Vector3.RIGHT)
	assert_gt(covered, 0.9, "the spot was not covered first")
	# Held rather than pressed once, and at full strength: a jet that took product
	# off at all would have taken all of it off over forty passes of this.
	for _sweep: int in 40:
		_map.wash(_middle(), Vector3.RIGHT, 0.4, 1.0)
	assert_almost_eq(
		_map.product_at(_middle(), Vector3.RIGHT),
		covered,
		TOLERANCE,
		"the jet rinsed the product off"
	)


func test_the_wash_over_a_covered_spot_banks_nothing_and_rings_nothing() -> void:
	# The other side of the same change. The jet on ground with no mud left has
	# nothing to draw from at all, so it moves no units, pays no wage and reports
	# no patch — where it used to go on moving product for as long as the trigger
	# was held, which is what the ledger and the ding both had to be careful about.
	_wash_bare(_middle(), 2.0)
	_foam_over(_middle(), 2.0)
	var banked: float = _map.worked(GrimeMap.Stage.WASHED)
	var rung: int = 0
	for _sweep: int in 60:
		rung += _map.wash(_middle(), Vector3.RIGHT, 2.0, 0.2).size()
	assert_eq(rung, 0, "washing an already-clean patch rang the bell")
	assert_eq(_map.worked(GrimeMap.Stage.WASHED), banked, "and it was paid for as work")


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


func test_the_wash_stops_at_the_mud_on_a_part_soaped_texel() -> void:
	# The clamp doing the work, on the case where both buckets have something in
	# them. A texel left part muddy and then part soaped has product sitting next to
	# dirt, and water enough to take twice the mud off takes the mud off and stops
	# — the source is the dirt, so there is nothing for the surplus to reach.
	_map.wash(_middle(), Vector3.RIGHT, 0.4, 0.5)
	_map.foam(_middle(), Vector3.RIGHT, 0.4, 1.0)
	var mud: float = _map.mud_at(_middle(), Vector3.RIGHT)
	var product: float = _map.product_at(_middle(), Vector3.RIGHT)
	assert_gt(mud, 0.1, "the spot should still be part muddy for this to mean anything")
	assert_gt(product, 0.1, "and part soaped")
	_map.wash(_middle(), Vector3.RIGHT, 0.4, mud * 2.0)
	assert_almost_eq(_map.mud_at(_middle(), Vector3.RIGHT), 0.0, TOLERANCE, "the mud stayed on")
	assert_almost_eq(
		_map.product_at(_middle(), Vector3.RIGHT), product, TOLERANCE, "the surplus took product"
	)


func test_the_jet_cannot_open_a_covered_patch_back_up() -> void:
	# The ding's old trap, closed at the source. A covered patch used to be one the
	# jet could strip and the bottle could then cover again, arriving at a state it
	# had already rung for — so the middle stage's report had to know how far the
	# patch had ever got. Now there is no way back: the water leaves the coat on, so
	# a second bottle over the same face finds nothing to draw from and says so.
	_wash_bare(_middle(), 2.0)
	var first: PackedInt32Array = PackedInt32Array()
	for _sweep: int in 200:
		first.append_array(_map.foam(_middle(), Vector3.RIGHT, 2.0, 0.05))
	assert_gt(first.size(), 0, "the face did not come up covered the first time")
	assert_eq(first.size(), _distinct(first), "and a patch rang twice on the way there")
	var covered: float = _map.product()
	for _sweep: int in 60:
		_map.wash(_middle(), Vector3.RIGHT, 2.0, 0.2)
	assert_almost_eq(_map.product(), covered, TOLERANCE, "the jet took the coat back off")
	var again: int = 0
	for _sweep: int in 200:
		again += _map.foam(_middle(), Vector3.RIGHT, 2.0, 0.05).size()
	assert_eq(again, 0, "a covered face rang a second time")


func test_covering_a_patch_that_was_only_part_done_still_rings() -> void:
	# And the guard against overcorrecting into a map that rings once and then goes
	# quiet: a patch that never came up covered has genuinely not finished the pass,
	# so finishing it later is a first time and rings like one.
	_wash_bare(_middle(), 2.0)
	# A brush too narrow to finish any of them: the point is the corner the four
	# patches of the face meet at, so each gets a quarter of the splash and none
	# comes up covered.
	var partial: int = 0
	for _sweep: int in 200:
		partial += _map.foam(_middle(), Vector3.RIGHT, 0.3, 0.05).size()
	assert_eq(partial, 0, "the narrow brush finished a patch, so the wide one below proves nothing")
	var rung: PackedInt32Array = PackedInt32Array()
	for _sweep: int in 400:
		rung.append_array(_map.foam(_middle(), Vector3.RIGHT, 2.0, 0.05))
	assert_gt(rung.size(), 0, "covering the face for the first time did not ring")
	assert_eq(rung.size(), _distinct(rung), "and a patch rang twice on the way there")
