## Integration test for the done map — the grid in the top-left corner that fills
## in as the car is finished.
##
## Under tests/integration/ because nothing here is true of the script on its
## own: the tiles are rectangles at the design resolution, the fills come from
## real [GrimeMap]s laid on a real car, and "it is in the corner nothing else
## uses" is a statement about three other controls' corners.
##
## On [code]tests/fixtures/plain_car.tscn[/code] rather than the game's own car,
## for the reason [code]tests/integration/test_grime.gd[/code] gives: a tile a
## panel is true of any car, and a suite that named [code]"Hood"[/code] would go
## red the day the blockout is reshaped for reasons that have nothing to do with
## this board. That the game's twelve panels each get one is asserted through the
## real stack in [code]tests/integration/test_play_screen_wash.gd[/code].
##
## The map is added [i]over[/i] a full-screen button on purpose, the same way
## [code]tests/integration/test_tool_belt_hud.gd[/code] and
## [code]tests/integration/test_motion_pad.gd[/code] do it. "Intercepts no input"
## cannot be checked by asserting the map stayed quiet; a root [Control] that
## swallowed the tap would also stay quiet. The button underneath is the witness,
## and it stands in for the garage's [SubViewportContainer]. It matters more for
## this control than for either of those: this one is on screen for the whole
## game, so a rectangle it swallowed would be a dead corner the player never gets
## back.
extends GutTest

const DONE_MAP: String = "res://src/ui/done_map.tscn"
const CAR: String = "res://tests/fixtures/plain_car.tscn"

## Above GUT's own output layer, so a finger aimed at the map lands on the map —
## GUI picking goes to the highest [CanvasLayer] first and the runner draws its
## log at 128. [code]tests/integration/test_motion_pad.gd[/code] has the
## measurement.
const ABOVE_THE_RUNNER: int = 200

## Enough sweeps of a tool held flat on a face to move a panel measurably along.
## How fast a jet works is a tuning number in [Garage]; nothing here is asserting
## on it, so the work is done through [Grime] directly and repeated until the
## arithmetic has somewhere to go.
const SWEEPS: int = 60

## How much of a pass one sweep spends. Small enough that no single call saturates
## the face, which is what makes the three passes below actually run in order.
const AMOUNT: float = 0.1

## Close enough for a fraction and for a position in design pixels.
const TOLERANCE: float = 0.001

var _map: DoneMap = null
var _car: Car = null
var _grime: Grime = null
var _underneath: Button = null
var _underneath_presses: int = 0
var _window_size_before: Vector2i = Vector2i.ZERO


func before_each() -> void:
	_underneath_presses = 0
	# A headless window is 64x64, which is smaller than one tap target — every
	# rectangle below would be clamped into nonsense and the corner assertions
	# would pass or fail for a reason that has nothing to do with this board.
	# `content_scale_size` is the design resolution from project.godot. Put back
	# in after_each: every suite shares this window.
	var root: Window = get_tree().root
	_window_size_before = root.size
	root.size = root.content_scale_size
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = ABOVE_THE_RUNNER
	add_child_autofree(layer)
	# The stand-in for the garage: a control that covers the whole screen and sits
	# below the map, exactly like the SubViewportContainer does on the play screen.
	var underneath: Button = Button.new()
	underneath.set_anchors_preset(Control.PRESET_FULL_RECT)
	_underneath = underneath
	layer.add_child(_underneath)
	_underneath.pressed.connect(_record_underneath)
	var packed_car: PackedScene = load(CAR) as PackedScene
	assert_not_null(packed_car, "could not load %s" % CAR)
	var packed_map: PackedScene = load(DONE_MAP) as PackedScene
	assert_not_null(packed_map, "could not load %s" % DONE_MAP)
	if packed_car == null or packed_map == null:
		return
	var car: Car = packed_car.instantiate() as Car
	_car = car
	add_child_autofree(_car)
	_grime = Grime.new()
	add_child_autofree(_grime)
	var map: DoneMap = packed_map.instantiate() as DoneMap
	_map = map
	layer.add_child(_map)
	# The frame [Grime] needs before a CSG panel has a size — see its class docs.
	await wait_process_frames(1)
	_grime.lay_on(_car)
	_map.bind(_grime)


func after_each() -> void:
	get_tree().root.size = _window_size_before


func _record_underneath() -> void:
	_underneath_presses += 1


func _tap(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var touch: InputEventScreenTouch = InputEventScreenTouch.new()
		touch.position = at
		touch.pressed = pressed
		Input.parse_input_event(touch)
	Input.flush_buffered_events()


## A brush wide enough to cover a whole face of [param panel], so a pass held on
## it has somewhere to go whatever size the fixture's slabs are.
func _whole_face_of(panel: CSGShape3D) -> float:
	return (panel.global_transform * panel.get_aabb()).size.length()


## The middle of the top face of [param panel], in world space — a point every
## pass below is aimed at, so all three land in the same texels.
func _on_top_of(panel: CSGShape3D) -> Vector3:
	var box: AABB = panel.global_transform * panel.get_aabb()
	return Vector3(box.get_center().x, box.end.y, box.get_center().z)


## Runs the whole job over one face of [param panel]: water, then a cleaner, then
## the rag. Through [Grime] rather than through a crosshair, because what this
## suite is about is the board reading the maps — that a held press reaches them
## at all is [code]tests/integration/test_play_screen_wash.gd[/code].
func _finish_a_face_of(panel: CSGShape3D) -> void:
	var at: Vector3 = _on_top_of(panel)
	var radius: float = _whole_face_of(panel)
	for _sweep: int in SWEEPS:
		_grime.wash(panel, at, Vector3.UP, radius, AMOUNT)
	for _sweep: int in SWEEPS:
		_grime.foam(panel, at, Vector3.UP, radius, AMOUNT)
	for _sweep: int in SWEEPS:
		_grime.buff(panel, at, Vector3.UP, radius, AMOUNT)


## Where the tile for the panel called [param named] is on the board, or -1.
func _tile_for(named: String) -> int:
	for index: int in _map.count():
		if _map.panel_name(index) == named:
			return index
	return -1


## The rectangle a tap target occupies in each of the three corners the rest of
## the HUD owns — the belt's [b]T[/b], the pad's circle and the grime board's
## [b]~[/b] — measured the way those controls measure themselves rather than
## copied out of them as numbers.
func _corners_already_taken() -> Array[Rect2]:
	var slot: float = ceilf(TouchTarget.min_design_size())
	var screen: Vector2 = _map.size
	var margin: float = ToolBeltHud.MARGIN
	return [
		Rect2(Vector2(margin, screen.y - margin - slot), Vector2(slot, slot)),
		Rect2(Vector2(screen.x - margin - slot, screen.y - margin - slot), Vector2(slot, slot)),
		Rect2(Vector2(screen.x - margin - slot, margin), Vector2(slot, slot)),
	]


# ---- what is on the board ----------------------------------------------------


func test_a_tile_for_every_panel_of_the_car() -> void:
	assert_eq(_map.count(), _car.panels().size(), "one tile per panel, no more and no less")
	for panel: CSGShape3D in _car.panels():
		assert_gte(_tile_for(String(panel.name)), 0, "%s has no tile" % panel.name)


func test_a_map_with_nothing_bound_to_it_draws_nothing() -> void:
	# The frame between the room existing and the grime being laid on it, and the
	# title screen, which never lays any at all. Both have to be a board that is
	# simply not there rather than an empty grid or an error.
	_map.bind(null)
	assert_eq(_map.count(), 0, "a map of no grime still had tiles")
	assert_eq(_map.board_rect(), Rect2(), "and drew a board to put them on")
	_map.refresh()
	assert_eq(_map.done(), 0.0, "and claimed the car was getting somewhere")


func test_a_fresh_car_has_filled_in_nothing() -> void:
	_map.refresh()
	assert_eq(_map.done(), 0.0, "a car nobody has touched is not started")
	for index: int in _map.count():
		assert_eq(_map.fill_of(index), 0.0, "%s started filled in" % _map.panel_name(index))


# ---- does it follow the car --------------------------------------------------


func test_finishing_a_panel_fills_its_tile_and_only_its_tile() -> void:
	# The whole point of a grid rather than a bar: "which bits are left" is the
	# half of the question a single number cannot answer, so the tile that moves
	# has to be the panel that was worked.
	var worked: CSGShape3D = _car.panels()[0]
	var tile: int = _tile_for(String(worked.name))
	assert_gte(tile, 0, "the panel worked on has no tile")
	if tile < 0:
		return
	_finish_a_face_of(worked)
	_map.refresh()
	assert_gt(_map.fill_of(tile), 0.0, "%s was buffed and its tile is empty" % worked.name)
	for index: int in _map.count():
		if index == tile:
			continue
		assert_eq(
			_map.fill_of(index), 0.0, "%s filled in without being touched" % _map.panel_name(index)
		)


func test_the_heading_is_the_car_and_not_the_panel() -> void:
	# The tile is one panel's shine and the heading is the whole car's, which is
	# [method Grime.shine] and not an average of anything this board worked out
	# for itself. Finishing one face of one panel of four moves both, and moves
	# the heading by strictly less.
	var worked: CSGShape3D = _car.panels()[0]
	_finish_a_face_of(worked)
	_map.refresh()
	assert_almost_eq(_map.done(), _grime.shine(), TOLERANCE, "the heading is not the car's shine")
	assert_gt(_map.done(), 0.0, "a buffed face left the car reading as untouched")
	assert_lt(_map.done(), _map.fill_of(_tile_for(String(worked.name))), "one panel is the car")


func test_a_fill_only_ever_rises() -> void:
	# Shine is the one channel that cannot go backwards, and it is why the board
	# reads this and not the mask: washing a panel that has already been finished
	# leaves the shine alone, where the mud and the product it would otherwise
	# have drawn both move.
	var worked: CSGShape3D = _car.panels()[0]
	_finish_a_face_of(worked)
	_map.refresh()
	var tile: int = _tile_for(String(worked.name))
	var after_the_job: float = _map.fill_of(tile)
	for _sweep: int in SWEEPS:
		_grime.wash(worked, _on_top_of(worked), Vector3.UP, _whole_face_of(worked), AMOUNT)
	_map.refresh()
	assert_almost_eq(_map.fill_of(tile), after_the_job, TOLERANCE, "a jet undid the buffing")


# ---- where it sits -----------------------------------------------------------


func test_the_board_is_in_the_corner_nothing_else_uses() -> void:
	var board: Rect2 = _map.board_rect()
	assert_eq(
		board.position,
		Vector2(ToolBeltHud.MARGIN, ToolBeltHud.MARGIN),
		"not in the top-left corner"
	)
	for taken: Rect2 in _corners_already_taken():
		assert_false(board.intersects(taken), "the board covers a corner already spoken for")


func test_a_tile_is_sized_off_a_tap_target() -> void:
	# Not because anything here is tapped — nothing is — but because that number
	# is the one place in the project that knows how hard a phone squeezes the
	# design. See [constant DoneMap.TILES_PER_TARGET].
	var side: float = ceilf(TouchTarget.min_design_size() / DoneMap.TILES_PER_TARGET)
	for index: int in _map.count():
		assert_eq(_map.tile_rect(index).size, Vector2(side, side), "a tile is a different size")


func test_the_tiles_do_not_overlap_each_other_or_leave_the_board() -> void:
	var board: Rect2 = _map.board_rect()
	for index: int in _map.count():
		var tile: Rect2 = _map.tile_rect(index)
		assert_true(board.encloses(tile), "tile %d hangs off the board" % index)
		for other: int in _map.count():
			if other == index:
				continue
			assert_false(
				tile.intersects(_map.tile_rect(other)), "tiles %d and %d overlap" % [index, other]
			)


func test_the_board_intercepts_no_input() -> void:
	# The one that has to hold for the whole game: a permanent HUD that ate its
	# own rectangle would be a corner of the car nobody can aim at, and it would
	# look like a bug in the raycast.
	_tap(_map.board_rect().get_center())
	await wait_process_frames(1)
	assert_eq(_underneath_presses, 1, "a tap on the board never reached the room behind it")
