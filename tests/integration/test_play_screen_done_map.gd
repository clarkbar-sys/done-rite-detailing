## Integration test for the wiring behind the done map: the play screen binding
## the room's grime to the board in the corner, and keeping it current.
##
## [b]Why a suite of its own.[/b] [code]tests/integration/test_done_map.gd[/code]
## is about the board — the tiles, the fills, the corner — and it runs on
## [code]tests/fixtures/plain_car.tscn[/code] on purpose, so that a suite about a
## grid does not go red when somebody reshapes the blockout. What is left over is
## the pair of facts only the real screen can answer: that the board is bound to
## the car the player is actually looking at, and that something is asking it for
## a fresh reading. Neither is observable from the scene on its own.
##
## [b]Through [code]play_screen.tscn[/code] rather than
## [code]main.tscn[/code].[/b] The suites that press through the whole stack do
## it because a press has controls above and below it to get past
## ([code]test_play_screen_trigger.gd[/code] records what that cost when it was
## skipped). Nothing here is a press: the work is done through [Grime] directly,
## the way [code]test_play_screen_wash.gd[/code] rings the bell, so the screen
## under test is the only screen this needs.
extends GutTest

const PLAY_SCREEN: String = "res://src/screens/play_screen.tscn"

## Above GUT's own output layer, so nothing in this scene is drawn under the
## runner's log.
const ABOVE_THE_RUNNER: int = 200

## Long enough for [Garage] to have laid the grime on a car whose panels have
## been built — the frame [method Grime.lay_on] cannot be called before.
const SETTLE_FRAMES: int = 4

## Enough sweeps of a tool held flat on a face to move a panel measurably along.
## How long a held tool takes is a tuning number in [Garage] and nothing here is
## asserting on it.
const SWEEPS: int = 60

## How much of a pass one sweep spends.
const AMOUNT: float = 0.1

var _screen: GameScreen = null
var _window_size_before: Vector2i = Vector2i.ZERO


func before_each() -> void:
	# A headless window is 64x64, which is smaller than one tap target, and the
	# board's own rectangles are measured against the design resolution. Put back
	# in after_each: every suite shares this window.
	var root: Window = get_tree().root
	_window_size_before = root.size
	root.size = root.content_scale_size
	var packed: PackedScene = load(PLAY_SCREEN) as PackedScene
	assert_not_null(packed, "could not load %s" % PLAY_SCREEN)
	if packed == null:
		return
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = ABOVE_THE_RUNNER
	add_child_autofree(layer)
	var screen: GameScreen = packed.instantiate() as GameScreen
	_screen = screen
	layer.add_child(_screen)
	await wait_process_frames(SETTLE_FRAMES)


func after_each() -> void:
	get_tree().root.size = _window_size_before


func _garage() -> Garage:
	return _screen.get_node("Garage") as Garage


func _car() -> Car:
	return _garage().get_node("%Car") as Car


func _grime() -> Grime:
	return _garage().grime()


func _map() -> DoneMap:
	return _screen.get_node("DoneMap") as DoneMap


## One panel of [param kind] on the real car. Asked for by what it is made of
## rather than by name, for the reason [code]test_play_screen_wash.gd[/code]
## gives: a rename of the blockout should not turn a test about the board into a
## test about nothing.
func _a_panel_of(kind: Surface.Kind) -> CSGShape3D:
	for panel: CSGShape3D in _car().panels():
		if _car().kind_of(panel) == kind:
			return panel
	return null


## Runs the whole job over the top face of [param panel]: water, then a cleaner,
## then the rag — the only order that puts any shine on it.
func _finish_a_face_of(panel: CSGShape3D) -> void:
	var box: AABB = panel.global_transform * panel.get_aabb()
	var at: Vector3 = Vector3(box.get_center().x, box.end.y, box.get_center().z)
	# A brush wide enough to cover a whole face whatever size the panel is —
	# measured off it rather than written down, exactly as the wash suite does.
	var radius: float = box.size.length()
	for _sweep: int in SWEEPS:
		_grime().wash(panel, at, Vector3.UP, radius, AMOUNT)
	for _sweep: int in SWEEPS:
		_grime().foam(panel, at, Vector3.UP, radius, AMOUNT)
	for _sweep: int in SWEEPS:
		_grime().buff(panel, at, Vector3.UP, radius, AMOUNT)


## Which tile is the panel called [param named], or -1.
func _tile_for(named: String) -> int:
	for index: int in _map().count():
		if _map().panel_name(index) == named:
			return index
	return -1


func test_the_board_is_bound_to_the_car_the_player_is_looking_at() -> void:
	# Bound on [signal Garage.grimed] rather than in `_ready`, because the maps do
	# not exist for a frame after the room does. A board that bound early would be
	# empty for the whole game, and this is what would catch it.
	assert_true(_grime().is_laid(), "the room never laid any grime")
	assert_eq(_map().count(), _car().panels().size(), "the map is not a picture of this car")


func test_the_screen_keeps_the_board_current() -> void:
	# The polling loop, from the outside. Nothing signals the board that a rag
	# moved — see [method DoneMap.refresh] — so if the screen stops asking, the
	# corner quietly freezes at "nothing done" and the game looks broken in the
	# one place that is meant to say how it is going. No `refresh()` is called
	# here on purpose: the frames are the test.
	var panel: CSGShape3D = _a_panel_of(Surface.Kind.BODY)
	assert_not_null(panel, "the car has no bodywork")
	if panel == null:
		return
	var tile: int = _tile_for(String(panel.name))
	assert_gte(tile, 0, "%s has no tile on the map" % panel.name)
	assert_eq(_map().fill_of(tile), 0.0, "a fresh car started part-finished")
	_finish_a_face_of(panel)
	await wait_process_frames(2)
	assert_gt(_map().fill_of(tile), 0.0, "%s was buffed and its tile stayed empty" % panel.name)
	assert_gt(_map().done(), 0.0, "and the car as a whole read as untouched")
