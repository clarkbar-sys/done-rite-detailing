## Every panel's grime mask, drawn flat, so you can see what the water is
## actually writing.
##
## This is the proof that the projection works, and it is the thing you look at
## when it does not: mud is red, clean is black, and a jet of water held on the
## near flank should darken a hole in exactly one tile of exactly one panel. If
## the hole opens somewhere else, the face choice is wrong; if it opens in two
## places, the projection is sharing texels; if it opens in the right place on
## the wrong panel, the hit is being resolved against the wrong collider. None of
## those three are distinguishable from looking at the car.
##
## [b]Six tiles a panel, laid out as the atlas is.[/b] Each thumbnail is one
## panel's whole mask: the top row is [code]+X -X +Y[/code] and the bottom is
## [code]-Y +Z -Z[/code] ([enum BoxProjection.Face] is the same order). So the
## two halves of the top row are the two flanks of that panel, and a wash that
## bled between them would be visible as two holes rather than one.
##
## Nearest-neighbour filtering, deliberately: this is a view of texels and a
## smoothed one would hide the resolution, which is one of the things you are
## looking at it to judge.
class_name GrimeDebug
extends PanelContainer

## How wide each panel's thumbnail is drawn, in pixels. The masks are three tiles
## by two, so the height follows from this and the aspect rather than being a
## second number that could disagree with it.
const THUMBNAIL_WIDTH: float = 108.0

## How many thumbnails to a row. Four across and twelve panels is three rows,
## which fits beside the tool roll-up without covering the car.
const COLUMNS: int = 4

@onready var _grid: GridContainer = %Masks
@onready var _title: Label = %Title


func _ready() -> void:
	_grid.columns = COLUMNS
	visible = false


## Draws the masks of [param grime], replacing whatever was shown before.
##
## Safe to call on grime that has not been laid on a car yet — it draws nothing,
## which is the honest picture of a car with no mud on it rather than an error.
func bind(grime: Grime) -> void:
	for old: Node in _grid.get_children():
		_grid.remove_child(old)
		old.queue_free()
	if grime == null:
		return
	for panel: CSGShape3D in grime.panels():
		var map: GrimeMap = grime.map_of(panel)
		if map == null:
			continue
		_grid.add_child(_thumbnail(String(panel.name), map))


## Whether the masks are on screen.
func is_shown() -> bool:
	return visible


## Shows or hides the masks.
func set_shown(shown: bool) -> void:
	visible = shown


## Flips it, for a key that toggles.
func toggle() -> void:
	set_shown(not visible)


## Reports how much of the car is still dirty in the heading, so the overlay
## answers "am I getting anywhere" as well as "is it landing in the right place".
func report(remaining: float) -> void:
	_title.text = "GRIME MASKS — %d%% left" % roundi(remaining * 100.0)


## One panel's mask with its name under it.
func _thumbnail(named: String, map: GrimeMap) -> Control:
	var stack: VBoxContainer = VBoxContainer.new()
	stack.name = named
	var view: TextureRect = TextureRect.new()
	view.texture = map.texture()
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.custom_minimum_size = Vector2(
		THUMBNAIL_WIDTH, THUMBNAIL_WIDTH * float(BoxProjection.ROWS) / float(BoxProjection.COLUMNS)
	)
	stack.add_child(view)
	var caption: Label = Label.new()
	caption.text = named
	caption.add_theme_font_size_override("font_size", 11)
	stack.add_child(caption)
	return stack
