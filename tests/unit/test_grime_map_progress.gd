## Unit tests for [method GrimeMap.progress] — the number the done readout
## prints, and the reason it moves under every tool rather than only under the
## rag.
##
## Split from [code]tests/unit/test_grime_map.gd[/code] the way the layers suite
## is, and covering the claim neither of them makes: that the three passes each
## carry a third of the job, that no tool ever walks the number backwards, and
## that it lands on exactly one when the panel calls itself finished.
extends GutTest

## The same door-sized panel the other GrimeMap suites use, for the same reason:
## not square on any axis, so a swapped axis has somewhere to show.
const PANEL: AABB = AABB(Vector3(-0.1, 0.0, -1.5), Vector3(0.2, 1.2, 3.0))

const TILE: int = 16
const PATCHES: int = 2
const TOLERANCE: float = 0.0001

## Passes of a tool at full strength over one face — the margin
## [code]tests/integration/test_play_screen_done.gd[/code] allows itself, for
## the reason it gives: the brush is subtractive and clamped, so a bucket
## empties in two or three and eight is margin.
const PRESSES: int = 8

var _map: GrimeMap = null


func before_each() -> void:
	_map = GrimeMap.new(PANEL, TILE, PATCHES)


## Runs one pass of the job over every face of the panel: a brush wider than the
## panel, aimed at the middle of its box through each of the six normals in
## turn, which covers every texel of every tile in one press each. The same
## sweep the integration suite does through [Grime], done here straight into the
## map.
func _run_a_pass(stage: GrimeMap.Stage) -> void:
	var middle: Vector3 = PANEL.get_center()
	var wide: float = maxf(PANEL.size.x, maxf(PANEL.size.y, PANEL.size.z)) * 2.0
	var faces: Array[Vector3] = [
		Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD
	]
	for axis: Vector3 in faces:
		for _press: int in PRESSES:
			match stage:
				GrimeMap.Stage.WASHED:
					_map.wash(middle, axis, wide, 1.0)
				GrimeMap.Stage.FOAMED:
					_map.foam(middle, axis, wide, 1.0)
				_:
					_map.buff(middle, axis, wide, 1.0)


func test_a_fresh_panel_has_made_no_progress() -> void:
	assert_eq(_map.progress(), 0.0, "a car nobody has touched is partly done")


func test_washing_alone_moves_the_number() -> void:
	# The claim the readout hangs on: the corner climbs from the first pass of
	# the jet, not from the first pass of the rag. Shine staying at zero here is
	# the old behaviour this reading exists to replace.
	_run_a_pass(GrimeMap.Stage.WASHED)
	assert_almost_eq(_map.progress(), 1.0 / 3.0, TOLERANCE, "a washed panel is a third of the job")
	assert_almost_eq(_map.shine(), 0.0, TOLERANCE, "with no shine on it yet")


func test_the_product_going_on_is_the_second_third() -> void:
	_run_a_pass(GrimeMap.Stage.WASHED)
	_run_a_pass(GrimeMap.Stage.FOAMED)
	assert_almost_eq(_map.progress(), 2.0 / 3.0, TOLERANCE, "washed and covered is two thirds")


func test_the_rag_spending_product_does_not_walk_it_backwards() -> void:
	# The buff moves units out of the product bucket, and a covered term read off
	# product alone would fall as the rag worked — the readout going *down* under
	# the last tool. Covered is product plus shine, so one press of the rag can
	# only ever move the number up.
	_run_a_pass(GrimeMap.Stage.WASHED)
	_run_a_pass(GrimeMap.Stage.FOAMED)
	var covered: float = _map.progress()
	_map.buff(PANEL.get_center(), Vector3.RIGHT, 0.3, 0.5)
	assert_gt(_map.progress(), covered, "the rag took progress away")


func test_a_finished_panel_reads_exactly_one() -> void:
	_run_a_pass(GrimeMap.Stage.WASHED)
	_run_a_pass(GrimeMap.Stage.FOAMED)
	_run_a_pass(GrimeMap.Stage.BUFFED)
	assert_true(_map.is_finished(), "the job was not actually finished, so this proves nothing")
	# Equality and not a tolerance: the whole reading is integer totals over an
	# integer capacity, and the hundred in the corner arrives off the floor of
	# this — a progress that could only get within an epsilon of one would be a
	# readout stuck at 99.
	assert_eq(_map.progress(), 1.0, "and progress does not agree")
