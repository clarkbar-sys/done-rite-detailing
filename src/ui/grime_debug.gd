## Every panel's grime mask, drawn flat, with a button to put them up.
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
##
## [b]A button as well as a key, and the button is the point.[/b] This started
## keyboard-only on the reasoning that a developer's view of a texture does not
## need a touch control. That was wrong in the only way that matters: the game is
## played on a phone, the thing this view diagnoses is a projection that behaves
## differently under a thumb than under a mouse, and a diagnostic you cannot open
## on the device with the bug is not a diagnostic. So the toggle is a tap target
## the same size as the belt's, in the corner the belt does not use, and
## [kbd]G[/kbd] still works for whoever has a keyboard.
##
## [b]The board also carries a "Debug Tools" switch[/b] that has nothing to do
## with grime: it is the one place in the game a developer's eye is expected to
## be looking, so it is where [Garage.debug_tools] lives its UI life too — see
## [signal debug_tools_toggled]. Off by default and unconnected to anything of
## the masks' own: a player who opens this panel to check "am I getting anywhere"
## is not thereby asking the power wash to drop its cone for a bare crosshair, so
## the two switches are independent rather than one flipping the other.
class_name GrimeDebug
extends Control

## The player flipped the "Debug Tools" switch inside this panel. [param
## enabled] is its new state, handed to whoever wants to act on it —
## [code]src/screens/play_screen.gd[/code] forwards it straight to
## [member Garage.debug_tools], which swaps the power wash's cone for the plain
## crosshair.
signal debug_tools_toggled(enabled: bool)

## What the toggle says. A glyph the font already has rather than an icon, for
## the reason [constant ToolBeltHud.TOGGLE_TEXT] is a letter: there is no asset
## pipeline yet and a character cannot go missing.
const TOGGLE_TEXT: String = "~"

## How wide each panel's thumbnail is drawn, in design pixels. The masks are
## three tiles by two, so the height follows from this and the aspect rather than
## being a second number that could disagree with it.
const THUMBNAIL_WIDTH: float = 108.0

## How many thumbnails to a row. Four across and twelve panels is three rows,
## which keeps the board clear of the belt's own corner.
const COLUMNS: int = 4

@onready var _toggle: Button = %Toggle
@onready var _board: PanelContainer = %Board
@onready var _grid: GridContainer = %Grid
@onready var _title: Label = %Title
@onready var _debug_tools: CheckButton = %DebugTools


func _ready() -> void:
	_toggle.text = TOGGLE_TEXT
	_toggle.pressed.connect(_on_toggle_pressed)
	_debug_tools.toggled.connect(_on_debug_tools_toggled)
	_grid.columns = COLUMNS
	_board.visible = false
	resized.connect(_relayout)
	_relayout()


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


## Whether the masks are on screen. The toggle itself always is.
func is_shown() -> bool:
	return _board.visible


## Shows or hides the masks.
func set_shown(shown: bool) -> void:
	_board.visible = shown


## Flips it — what the button does, and what [kbd]G[/kbd] does.
func toggle() -> void:
	set_shown(not _board.visible)


## The button, so a test can tap the thing a player taps rather than calling the
## method behind it.
func toggle_button() -> Button:
	return _toggle


## Whether "Debug Tools" is switched on right now. Public for the same reason
## [method is_shown] is: a caller should be able to ask rather than assume it
## agrees with the last signal it happened to catch.
func debug_tools_enabled() -> bool:
	return _debug_tools.button_pressed


## The switch itself, so a test can tap the thing a player taps rather than
## flip [member CheckButton.button_pressed] behind its back.
func debug_tools_button() -> CheckButton:
	return _debug_tools


## Reports how much of the car is still dirty in the heading, so the board
## answers "am I getting anywhere" as well as "is it landing in the right place".
func report(remaining: float) -> void:
	_title.text = "GRIME MASKS — %d%% left" % roundi(remaining * 100.0)


## Puts the toggle in the top-left corner and the board directly under it.
##
## [b]The top corner, because the bottom one is taken.[/b] [ToolBeltHud] lays its
## own toggle out at [constant ToolBeltHud.MARGIN] from the bottom left and rolls
## its icons up out of it, and [MotionPad] owns the bottom-right corner. A board in
## the bottom corner — which is where this one started — sits straight on top of
## the belt's [b]T[/b].
##
## Sized off [method TouchTarget.min_design_size] rather than off a number
## written here, so this target and the belt's are the same size for the same
## reason, and both change together the day that minimum does.
func _relayout() -> void:
	if _toggle == null:
		return
	# Rounded up for the reason [method ToolBeltHud._relayout] records at length:
	# [Vector2] is float32, and asking for 163.84 gets a control fractionally
	# *below* the minimum it is supposed to clear.
	var slot: float = ceilf(TouchTarget.min_design_size())
	_toggle.custom_minimum_size = Vector2(slot, slot)
	_toggle.size = Vector2(slot, slot)
	_toggle.position = Vector2(ToolBeltHud.MARGIN, ToolBeltHud.MARGIN)
	_board.position = Vector2(ToolBeltHud.MARGIN, ToolBeltHud.MARGIN + slot + ToolBeltHud.GAP)


func _on_toggle_pressed() -> void:
	toggle()


func _on_debug_tools_toggled(enabled: bool) -> void:
	debug_tools_toggled.emit(enabled)


## One panel's mask with its name under it.
func _thumbnail(named: String, map: GrimeMap) -> Control:
	var stack: VBoxContainer = VBoxContainer.new()
	stack.name = named
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view: TextureRect = TextureRect.new()
	view.texture = map.texture()
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.custom_minimum_size = Vector2(
		THUMBNAIL_WIDTH, THUMBNAIL_WIDTH * float(BoxProjection.ROWS) / float(BoxProjection.COLUMNS)
	)
	stack.add_child(view)
	var caption: Label = Label.new()
	caption.text = named
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_size_override("font_size", 11)
	stack.add_child(caption)
	return stack
