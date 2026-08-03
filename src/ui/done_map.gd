## The job, as a map of the car: one tile a panel, filling from the bottom as
## that panel is buffed, in the corner nothing else uses.
##
## This is the answer to the two questions a detailer actually has —
## [i]how much of this car have I finished[/i] and [i]which bits are left[/i] —
## and it is on screen all the time, because both of them are questions about
## what to do next rather than questions about the build.
##
## [b]It is not the debug board, and that is deliberate.[/b] [GrimeDebug] draws
## the same twelve panels and is genuinely the best picture of the job in the
## game, but it is a diagnostic: it lives behind a toggle, it is captioned
## [code]GRIME MASKS[/code], and it shows raw texels because telling a projection
## bug from a raycast one is what it is for. Smoothing it or summarising it into a
## player's view would cost it exactly the thing it exists to show. So this is a
## second view of the same state rather than a re-skin of the first, and the two
## are free to disagree about what is worth drawing.
##
## [b]Driven by [method GrimeMap.shine], not by the mask.[/b] Of the three
## channels it is the only one that answers "done": mud goes to zero a third of
## the way through the job, product goes up under a cleaner and back down under
## the rag, and shine only ever rises and reaches one exactly when a panel is
## finished. A tile filled by anything else would call a soaking-wet unpolished
## car half done.
##
## [b]A tile cannot quite fill today, and that is honest rather than broken.[/b]
## Every panel is seeded with mud on all six faces of its box, and the underside
## of the bonnet is not somewhere a jet of water can reach — [method
## GrimeMap.is_finished] records the same limitation from the other end. So the
## fill approaches the top and stops short, which is the true picture of the mask
## underneath it. The day mud is seeded only where a player can get at it, these
## tiles complete and nothing here changes.
##
## [b]Drawn rather than built out of nodes.[/b] Twelve tiles that each want a
## background, a fill of their own height and a rim is twelve [Control]s and a
## container fighting over who owns the fill's rectangle — where
## [method CanvasItem._draw] is three [method CanvasItem.draw_rect] calls in a
## loop over an array of floats. [MotionPad] is the same trade for the same
## reason. What that costs is that a tile is not a node anything can hang off, so
## the accessors below — [method tile_rect], [method fill_of] — are how a test
## asks where a tile is and how full it is.
##
## [b]The corner, and why this one.[/b] [ToolBeltHud] owns bottom-left,
## [MotionPad] owns bottom-right and [GrimeDebug]'s toggle owns top-right. Top
## left is what is left, and it is also the corner a scoreboard belongs in when
## high scores land — this grid is the obvious place to hang one.
##
## [b]It never takes part in input.[/b] The scene's root is
## [constant Control.MOUSE_FILTER_IGNORE], like the rest of the HUD and for the
## sharper version of the same reason: this one is on screen permanently, so a
## root that stopped input would put a dead rectangle over the car for the whole
## game rather than only while a panel is open.
class_name DoneMap
extends Control

## How many tiles to a row. Four, like [constant GrimeDebug.COLUMNS], so twelve
## panels are three rows — a block wider than it is tall, which is the shape that
## fits under a heading and over nothing else.
const COLUMNS: int = 4

## How many tiles fit across one tap target, which is where a tile gets its size
## from.
##
## [b]The tap target is the ruler here, not the floor.[/b] Nothing on this map is
## touched, so [method TouchTarget.min_design_size] is not a minimum this has to
## clear — it is the one number in the project that already knows how far the
## design is squeezed on a phone, and sizing off it is what keeps a tile legible
## in a hand without a second number being written down. A third of a target is
## about 16 CSS pixels a tile on the narrowest screen the game targets: a block a
## thumb could not hit reliably, and could read at a glance, which is exactly what
## this is.
const TILES_PER_TARGET: float = 3.0

## Space between two neighbouring tiles, in design pixels.
##
## Smaller than [constant ToolBeltHud.GAP], which is not an inconsistency: that
## gap exists so a slightly-off tap lands on nothing rather than on the wrong
## tool, and nothing here is tapped. This one is only wide enough to keep two
## filled tiles from reading as one wide bar.
const SEPARATION: float = 6.0

## The board's own inner margin, in design pixels — between its backdrop and the
## heading and tiles inside it.
const PADDING: float = 8.0

## How big the heading is drawn, in design pixels. The size
## [code]PanelReadout[/code] uses, for the reason written beside it: the design is
## rendered at about a third on a phone, so the debug board's 14 px caption is
## four CSS pixels in a hand. This one is for the player, so it is sized to be
## read there.
const TITLE_SIZE: int = 32

## The row the heading is drawn in, in design pixels — the font plus its
## descender and a little air. Written down rather than measured off the label,
## so where a tile sits does not depend on when a font finished loading.
const TITLE_HEIGHT: float = float(TITLE_SIZE) * 1.4

## What the heading says, with the car's own [method Grime.shine] in it. One
## number and not the debug board's two: [method Grime.remaining] is about the
## first pass, and a player who wants to know how much mud is left can look at
## the car.
const TITLE_FORMAT: String = "DONE %d%%"

## What the board is drawn on. Dark and mostly transparent for the reason
## [constant MotionPad.BASE_COLOR] is: this sits on top of the room the player is
## trying to look at, and it has to be findable without being a hole in the
## picture.
const BACKDROP_COLOR: Color = Color(0.05, 0.06, 0.08, 0.42)

## A panel with nothing done to it yet.
const EMPTY_COLOR: Color = Color(0.11, 0.12, 0.15, 0.72)

## How much of it is buffed. The blue [GrimeMap] keeps shine in, brightened to a
## colour rather than a channel value — a tile and a thumbnail of the same panel
## should not have to be read as two different pictures.
const SHINE_COLOR: Color = Color(0.42, 0.76, 1.0, 0.92)

## The line round a tile, and how thick it is drawn in design pixels. It is what
## makes an empty tile a tile rather than a hole in the backdrop.
const RIM_COLOR: Color = Color(0.88, 0.9, 0.94, 0.45)
const RIM_WIDTH: float = 2.0

var _grime: Grime = null
var _maps: Array[GrimeMap] = []
var _names: PackedStringArray = PackedStringArray()

## How full each tile is drawn, [code]0..1[/code], in [member _maps] order. Kept
## rather than read inside [method CanvasItem._draw], so a redraw the engine asks
## for — a window resize, a theme change — draws the same picture as the last one
## instead of walking twelve panels again.
var _fills: PackedFloat32Array = PackedFloat32Array()

var _done: float = 0.0

@onready var _title: Label = %Title


func _ready() -> void:
	_title.add_theme_font_size_override("font_size", TITLE_SIZE)
	_title.position = Vector2(ToolBeltHud.MARGIN + PADDING, ToolBeltHud.MARGIN + PADDING)
	_title.size = Vector2(_grid_width(), TITLE_HEIGHT)
	_show_the_heading()


## Hands this map the grime it draws, replacing whatever it was drawing before.
##
## Safe on grime that has not been laid on a car yet, and on [code]null[/code]:
## both draw nothing at all, which is the honest picture of a car nobody has put
## mud on. The play screen binds on [signal Garage.grimed] rather than in
## [method Node._ready] for exactly that reason — the maps do not exist for a
## frame after the room does.
##
## The panels are read once, here, and not on every [method refresh]: the car
## does not grow a wing mirror mid-game, and a walk over the scene tree every
## frame to find that out would be the expensive half of a cheap job.
func bind(grime: Grime) -> void:
	_grime = grime
	_maps = []
	_names = PackedStringArray()
	_fills = PackedFloat32Array()
	_done = 0.0
	if grime != null:
		for panel: CSGShape3D in grime.panels():
			var map: GrimeMap = grime.map_of(panel)
			if map == null:
				continue
			_maps.append(map)
			_names.append(String(panel.name))
			_fills.append(0.0)
	if is_node_ready():
		_show_the_heading()
	queue_redraw()


## Reads how far along every panel is and redraws if any of it moved.
##
## [b]Polled, not signalled, and that is the shape of the number rather than a
## shortcut.[/b] [signal Grime.patch_finished] fires when a patch of a panel
## completes a pass, which is not when a fill changes — a rag held on the wing
## raises its shine continuously, and a tile that only moved on a finished patch
## would sit still through the work and then jump. So the screen calls this each
## frame, and it costs a division per panel.
##
## What it does not cost is a redraw a frame. A car nobody is touching returns the
## same twelve numbers, nothing is marked dirty, and the canvas is left alone —
## which matters here and not in [GrimeDebug] because this board is up for the
## whole game rather than while somebody is looking at a texture.
func refresh() -> void:
	if _maps.is_empty():
		return
	var moved: bool = false
	for index: int in _maps.size():
		var shine: float = _maps[index].shine()
		if is_equal_approx(shine, _fills[index]):
			continue
		_fills[index] = shine
		moved = true
	if not moved:
		return
	# Asked of the grime rather than averaged out of the fills above. The car's
	# own progress is [method Grime.shine] and it is one number with one owner; a
	# second derivation here would be a heading that can disagree with the tiles
	# under it.
	_done = _grime.shine()
	_show_the_heading()
	queue_redraw()


## How many tiles there are — one per panel that has a mask on it, and zero
## before the grime is laid.
func count() -> int:
	return _maps.size()


## How full the tile at [param index] is drawn, [code]0..1[/code]. Zero for an
## index that is not on the board, so a caller asking about a panel this map has
## never heard of gets "nothing done" rather than an error.
func fill_of(index: int) -> float:
	if index < 0 or index >= _fills.size():
		return 0.0
	return _fills[index]


## Which panel the tile at [param index] is, or [code]""[/code] for an index that
## is not on the board.
##
## The grid is in [method Grime.panels] order and carries no captions — twelve
## names at a size a phone could read is a board bigger than the car it is
## about — so this is how a test names a tile, and it is what a future tooltip or
## a scoreboard row would read.
func panel_name(index: int) -> String:
	if index < 0 or index >= _names.size():
		return ""
	return _names[index]


## How much of the car is finished, [code]0..1[/code] — the number in the
## heading, kept from the last [method refresh].
func done() -> float:
	return _done


## Where the tile at [param index] is drawn, in this control's coordinates. An
## empty rectangle for an index that is not on the board.
##
## Public because a tile is not a node: "the map is in the corner nothing else
## uses" and "the tiles do not overlap each other" are the two things about this
## class that can only be checked against real rectangles at the design
## resolution, and this is what a test measures them with.
func tile_rect(index: int) -> Rect2:
	if index < 0 or index >= _maps.size():
		return Rect2()
	var side: float = tile_size()
	var step: float = side + SEPARATION
	var corner: Vector2 = Vector2(
		ToolBeltHud.MARGIN + PADDING + float(index % COLUMNS) * step,
		ToolBeltHud.MARGIN + PADDING + TITLE_HEIGHT + float(index / COLUMNS) * step
	)
	return Rect2(corner, Vector2(side, side))


## The whole board — backdrop, heading and every tile. Empty before the grime is
## laid, because a board with nothing on it is not drawn at all.
func board_rect() -> Rect2:
	if _maps.is_empty():
		return Rect2()
	var rows: int = ceili(float(_maps.size()) / float(COLUMNS))
	var columns: int = mini(_maps.size(), COLUMNS)
	var side: float = tile_size()
	return Rect2(
		Vector2(ToolBeltHud.MARGIN, ToolBeltHud.MARGIN),
		Vector2(
			PADDING * 2.0 + float(columns) * side + float(columns - 1) * SEPARATION,
			PADDING * 2.0 + TITLE_HEIGHT + float(rows) * side + float(rows - 1) * SEPARATION
		)
	)


## How big one tile is drawn, in design pixels.
##
## Rounded up for the reason [method ToolBeltHud._relayout] records at length:
## [Vector2] is float32 and the target it is measured against is a float64, so a
## size asked for as 54.6666 comes back fractionally under itself. Nothing here
## has a minimum to clear, but two tiles that disagree by a rounding error are
## a row that does not line up.
func tile_size() -> float:
	return ceilf(TouchTarget.min_design_size() / TILES_PER_TARGET)


## The backdrop and every tile on it. The heading is a [Label] and draws itself,
## over this — text is the one thing here that is worth a node, because a font is
## somebody else's problem.
##
## Nothing is measured against [member Control.size] anywhere in here, which is
## why — alone in this HUD — there is no relayout on [signal Control.resized].
## The other three corners hang off an edge that moves when the window changes
## shape; this one is anchored to the corner every coordinate system starts at.
func _draw() -> void:
	if _maps.is_empty():
		return
	draw_rect(board_rect(), BACKDROP_COLOR)
	for index: int in _maps.size():
		var tile: Rect2 = tile_rect(index)
		draw_rect(tile, EMPTY_COLOR)
		var filled: float = tile.size.y * _fills[index]
		if filled > 0.0:
			# Up from the bottom edge, so a tile fills the way a gauge does rather
			# than growing out of the corner it is drawn from.
			draw_rect(
				Rect2(
					tile.position + Vector2(0.0, tile.size.y - filled), Vector2(tile.size.x, filled)
				),
				SHINE_COLOR
			)
		draw_rect(tile, RIM_COLOR, false, RIM_WIDTH)


## Puts the car's progress in the heading, or takes the heading away entirely on
## a map with nothing bound to it — before the grime is laid there is no honest
## number to print, and "DONE 0%" would be a claim about a car that does not have
## any mud on it yet.
func _show_the_heading() -> void:
	_title.text = "" if _maps.is_empty() else TITLE_FORMAT % roundi(_done * 100.0)


## How wide the tiles run, ignoring the board's own padding — what the heading is
## given to sit across.
func _grid_width() -> float:
	return float(COLUMNS) * tile_size() + float(COLUMNS - 1) * SEPARATION
