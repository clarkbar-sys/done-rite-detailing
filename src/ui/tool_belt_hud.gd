## The tool belt's UI half: a [b]T[/b] in the bottom-left corner that rolls the
## five tools up out of it, and puts them away again.
##
## This is the roll-up and nothing else. It does not own a [ToolBelt], it is
## handed one by [method bind], and picking an icon emits [signal tool_selected]
## rather than equipping anything — the play screen keeps owning game state, so
## a second way to switch tools (a number key, a scroll wheel, a radial menu)
## plugs into the same belt without going through this scene. Nothing listens to
## the signal yet, on purpose.
##
## [b]Why it lives in src/ui/ and not src/core/.[/b] It is a [Control], and
## [code]scripts/check-test-map.sh[/code] R3 keeps [code]src/core/[/code] to
## classes a unit test can construct without a [SceneTree]. The belt is that
## tier; the thing that draws it is this one.
##
## [b]The icons are flat 2D shapes, drawn from the catalogue's own fields.[/b]
## A circle per [constant DetailingTool.Shape.CYLINDER], a square for the box, a
## bar for the plane, each filled with that tool's [member DetailingTool.albedo]
## — see [ToolIcon]. The alternative, a [SubViewport] per tool rendering the real
## mesh, was rejected on cost: that is five more render targets on a page that
## already has one, to fill a 164 px badge on a phone. Reading `albedo` and
## `shape` straight off the catalogue is the part that matters, because it is
## what stops the icon and the mesh in the player's hands from drifting into two
## different blues.
##
## [b]The corner eats input, and that is the trap.[/b] The play screen draws the
## garage through a [SubViewportContainer], which is a canvas item, so this HUD
## sits above it in the tree. A [Control] defaults to
## [constant Control.MOUSE_FILTER_STOP], so a full-rect root would swallow every
## click on the whole screen forever — collapsed or not. The root and the
## [code]Icons[/code] holder are both [constant Control.MOUSE_FILTER_IGNORE] in
## the scene file for exactly that reason: only the six buttons are pickable,
## and while collapsed the holder is hidden so its five are not pickable either.
## [code]tests/integration/test_tool_belt_hud.gd[/code] proves it from the other
## side, by putting a button underneath and checking the tap reaches it.
class_name ToolBeltHud
extends Control

## Emitted when the player picks a tool off the roll-up. Carries both the id and
## the position on the belt: a listener that wants to call
## [method ToolBelt.equip] has the id, and one that wants
## [method ToolBelt.equip_at] — or wants to know which number key would have
## done the same thing — has the index, without either having to look the other
## up.
signal tool_selected(id: DetailingTool.Id, index: int)

## How long the roll-up takes to open or close. Short on purpose: this is a
## weapon switch, not a menu, and anything long enough to notice is long enough
## to be in the way of the next tap.
const EXPAND_SECONDS: float = 0.14

## Distance from the screen edge to the roll-up, in design pixels.
const MARGIN: float = 12.0

## Space between two neighbouring targets, in design pixels. Not decoration: two
## tap targets flush against each other turn a slightly-off tap into the wrong
## tool rather than into nothing, and nothing is the better failure.
const GAP: float = 10.0

## What the toggle says. A letter and not an icon because there is no asset
## pipeline yet and a glyph the font already has cannot go missing.
const TOGGLE_TEXT: String = "T"

var _belt: ToolBelt = null
var _icons: Array[ToolIcon] = []
var _slots: Array[Vector2] = []
var _collapsed_slot: Vector2 = Vector2.ZERO
var _expanded: bool = false
var _expansion: float = 0.0
var _tween: Tween = null

@onready var _holder: Control = %Icons
@onready var _toggle: Button = %Toggle


func _ready() -> void:
	_toggle.text = TOGGLE_TEXT
	_toggle.pressed.connect(_on_toggle_pressed)
	# The roll-up is anchored to a corner but laid out by hand (see
	# [method _relayout]), so it has to be told when the corner moved. `resized`
	# fires on the root because the scene is full-rect, which makes it the same
	# event as "the window changed shape".
	resized.connect(_relayout)
	# Collapsed on entry, every time, with no animation to play out — a screen
	# that opens mid-roll would be showing the player a state they never asked
	# for. This is also why the flag is reset here and not just left at its
	# initial value: `bind()` may already have run.
	_expanded = false
	_holder.visible = false
	_rebuild()


## Hands this roll-up the belt it draws.
##
## The HUD deliberately does not build a [ToolBelt] of its own. If it did, the
## thing the player is looking at and the thing the game is simulating would be
## two different objects that happen to have been constructed the same way, and
## the first bug would be a roll-up that rings a tool nobody is holding.
##
## Safe to call before or after the scene enters the tree, and safe to call
## twice: the previous belt is disconnected first, so a screen that re-binds on
## a new game does not end up refreshing against a belt it threw away.
func bind(belt: ToolBelt) -> void:
	if _belt != null and _belt.equipped_changed.is_connected(_on_equipped_changed):
		_belt.equipped_changed.disconnect(_on_equipped_changed)
	_belt = belt
	if _belt != null:
		_belt.equipped_changed.connect(_on_equipped_changed)
	if is_node_ready():
		_rebuild()


## Whether the five tool icons are out.
func is_expanded() -> bool:
	return _expanded


## Rolls the tools out ([param value] true) or puts them away.
##
## Idempotent, so a caller can assert a state rather than track one; asking for
## the state it is already in does not restart the tween.
func set_expanded(value: bool) -> void:
	if value == _expanded:
		return
	_expanded = value
	if _expanded:
		# Shown before the tween rather than after, or the first frame of the
		# roll-out would have nothing in it to animate.
		_holder.visible = true
	_animate_to(1.0 if _expanded else 0.0)


## Flips between rolled out and put away — what the toggle does, exposed so a
## key binding can do the same thing later without re-deriving the state.
func toggle() -> void:
	set_expanded(not _expanded)


## The [b]T[/b] itself. For tests, and for anything that wants to point the
## player at it.
func toggle_button() -> Button:
	return _toggle


## How many tool icons the roll-up is currently drawing — the size of the belt
## it was bound to, or zero if it has not been bound.
func icon_count() -> int:
	return _icons.size()


## The icon at [param index] on the belt, or [code]null[/code] if there isn't
## one. Index 0 is the icon nearest the toggle, which is [method ToolBelt.tools]
## order, which is the order the number keys will bind to.
func icon_at(index: int) -> ToolIcon:
	if index < 0 or index >= _icons.size():
		return null
	return _icons[index]


func _on_toggle_pressed() -> void:
	toggle()


func _on_icon_pressed(index: int) -> void:
	if _belt == null or index < 0 or index >= _belt.size():
		return
	tool_selected.emit(_belt.tools()[index].id, index)
	# Closing here rather than waiting to hear back: the belt refuses a swap to
	# the tool you are already holding ([method ToolBelt.equip] returns false),
	# so a roll-up that only closed on `equipped_changed` would stay open on
	# exactly the tap that means "never mind, I've got it".
	set_expanded(false)


func _on_equipped_changed(_tool: DetailingTool) -> void:
	# The tool itself is ignored and the index is re-read instead: what changes
	# here is which of *these icons* is ringed, and the belt is the one that
	# knows where a tool sits on it.
	_refresh_selection()


## Throws away the icons and builds one per tool on the bound belt.
##
## A rebuild rather than an update because the belt is five tools decided at
## construction; the day it is not, this is one call and the layout below
## already sizes itself from [method ToolBelt.size].
func _rebuild() -> void:
	for icon: ToolIcon in _icons:
		_holder.remove_child(icon)
		icon.queue_free()
	_icons.clear()
	if _belt != null:
		var tools: Array[DetailingTool] = _belt.tools()
		for index: int in tools.size():
			var icon: ToolIcon = ToolIcon.new()
			icon.carry(tools[index])
			icon.pressed.connect(_on_icon_pressed.bind(index))
			_holder.add_child(icon)
			_icons.append(icon)
	_relayout()
	_refresh_selection()


## Places the toggle and works out where each icon sits when the roll-up is out.
##
## [b]The arithmetic that shapes this, because it does not come out the way the
## design says.[/b] Every one of these six controls has to clear
## [method TouchTarget.min_design_size] on both axes, which is 164 design px
## today, and the design is 1280x720. A single upward column of five icons plus
## the toggle wants 6 x 164 = 984 px of a 720 px screen; the icons alone want
## 820. It does not fit, and no amount of trimming [constant MARGIN] and
## [constant GAP] makes it — three icons above the toggle is the ceiling even
## with both at zero.
##
## The two ways of "fixing" that were both rejected as the bug this project
## already paid for once: shrinking the icons below the minimum is what made the
## Start button unhittable on a phone (see [TouchTarget]), and overlapping them
## so the column fits leaves each icon a usable strip far narrower than it
## measures, which is the same failure wearing a passing test.
##
## So the column wraps. It rises out of the corner as specified, and when it
## runs out of headroom it starts another column to its right — index 0 stays
## nearest the toggle, belt order is preserved reading up-then-right, and every
## target keeps its full size. On a screen tall enough for five it is a plain
## single column with no code change; today it is 3 + 2.
func _relayout() -> void:
	# Rounded up, and that is not tidiness. [Vector2] is float32 and
	# [method TouchTarget.min_design_size] is a float64: asking for 163.84 gets a
	# control 163.839996 wide, which is *below* the minimum, and a test that
	# asserts the minimum honestly fails on it. Measured — that is how this line
	# got written. Rounding down to save a third of a pixel would be conceding
	# the exact argument [TouchTarget] exists to win.
	var slot: float = ceilf(TouchTarget.min_design_size())
	var square: Vector2 = Vector2(slot, slot)
	var step: float = slot + GAP
	_toggle.custom_minimum_size = square
	_toggle.size = square
	_toggle.position = Vector2(MARGIN, size.y - MARGIN - slot)
	# The icons start life stacked on the toggle, so the roll-out reads as them
	# coming out of the corner rather than fading in where they will end up.
	_collapsed_slot = _toggle.position
	var headroom: float = size.y - MARGIN * 2.0 - slot
	# At least one, or a window shorter than a single target would divide by
	# nothing and the whole roll-up would vanish instead of overflowing visibly.
	var per_column: int = maxi(1, floori(headroom / step))
	_slots.clear()
	for index: int in _icons.size():
		var row: int = index % per_column
		@warning_ignore("integer_division")
		var column: int = index / per_column
		var icon: ToolIcon = _icons[index]
		icon.custom_minimum_size = square
		icon.size = square
		(
			_slots
			. append(
				Vector2(
					MARGIN + float(column) * step,
					size.y - MARGIN - slot - float(row + 1) * step,
				)
			)
		)
	_apply_expansion(_expansion)


func _refresh_selection() -> void:
	var equipped: int = -1
	if _belt != null:
		equipped = _belt.equipped_index()
	for index: int in _icons.size():
		_icons[index].set_equipped(index == equipped)


## Drives the roll-up between put away ([param amount] 0) and fully out (1).
##
## One function for both directions, and the only place icon positions are
## written, so the tween below cannot leave the roll-up in a shape that
## [method _relayout] would not have produced.
func _apply_expansion(amount: float) -> void:
	_expansion = amount
	_holder.modulate.a = amount
	if _slots.size() != _icons.size():
		return
	for index: int in _icons.size():
		_icons[index].position = _collapsed_slot.lerp(_slots[index], amount)


func _animate_to(target: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	# Ease out, so the icons leave the corner fast and settle — the opposite
	# reads as sluggish at this duration even though it takes the same time.
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_apply_expansion, _expansion, target, EXPAND_SECONDS)
	if target <= 0.0:
		# Hidden only once it has finished closing: hiding on the first frame
		# would make the roll-up disappear rather than roll up, and leaving it
		# shown would keep five invisible buttons eating taps in the corner.
		_tween.tween_callback(_hide_holder)


func _hide_holder() -> void:
	_holder.visible = false


## One tool's badge: a flat silhouette in that tool's own colour.
##
## A [Button] rather than a [Control] with [method Control._gui_input], because
## what makes a tap work on a phone is the engine turning it into a click and
## [BaseButton] handling that — the same path the Start button takes, and the
## one the integration test exercises through [code]Input[/code].
##
## [b]Why the shape and not the mesh.[/b] Three of the five tools are cylinders,
## so three of these are the same circle, and they are told apart by colour —
## which is what [member DetailingTool.albedo] is documented to be for: the two
## blues on the belt are deliberately far apart so peripheral vision can do it.
## Reading [member DetailingTool.extent] to give each cylinder its own aspect
## ratio was considered and dropped: it makes the badge a scale model of a
## 0.06 m wand, which at this size is a hairline, and the silhouette stops
## saying "cylinder" at all.
##
## [b]Dimmed and ringed, not just dimmed.[/b] The spec fades the equipped tool
## out. Faded on its own is the universal look of a control that is broken, and
## the one icon you cannot pick — because it is already in your hands — is the
## one the eye should land on first. So the fill is dimmed as specified and a
## ring is drawn at full strength around it. The ring is drawn here rather than
## applied as [member CanvasItem.modulate] precisely so the dimming cannot reach
## it; a ring that fades with the fill says nothing the fill did not already say.
class ToolIcon:
	extends Button

	## How much of the fill's alpha survives on the tool you are holding.
	const DIM_ALPHA: float = 0.35

	## Thickness of the selection ring, in design pixels.
	const RING_WIDTH: float = 5.0

	## Ring colour. Deliberately not one of the tool colours — it has to read as
	## "this slot", not as another tool.
	const RING_COLOR: Color = Color(1.0, 0.95, 0.55, 1.0)

	## How far in from the button's edge the silhouette is drawn, as a fraction
	## of the smaller side. The tap target is the whole button; the picture is
	## smaller than the target on purpose, because the target is sized for a
	## fingertip and a 164 px sponge is not a picture, it is a wall.
	const SHAPE_INSET: float = 0.28

	## How far in from the button's edge the ring is drawn, same units.
	const RING_INSET: float = 0.06

	## The proportion of the badge's height a [constant DetailingTool.Shape.PLANE]
	## bar takes. Low enough to read as "a flat thing", not as a squashed box.
	const BAR_HEIGHT: float = 0.38

	var _tool: DetailingTool = null
	var _equipped: bool = false

	## Tells this badge which tool it stands for. Separate from
	## [method Object._init] because [Button] has its own and a subclass that
	## replaces it has to keep calling it.
	##
	## [b]The tooltip names the service as well as the tool[/b] — "Sponge — Hand
	## Wash & Dry" — which is the belt's half of making the game a demonstration
	## of what is being sold rather than a game that happens to share a name with
	## it. [member DetailingTool.service] has that argument.
	##
	## A tooltip reaches a mouse and not a thumb, and this is the corner of a
	## phone screen. That is a real limit rather than an oversight, and it is why
	## the service is also printed by [method ScoreHud.score], where every player
	## sees it on every patch: this line is the desk's version of the same
	## sentence, not the only place it is said.
	func carry(shown: DetailingTool) -> void:
		_tool = shown
		tooltip_text = "%s — %s" % [shown.display_name, shown.service]
		queue_redraw()

	## Marks this badge as the tool in the player's hands.
	func set_equipped(value: bool) -> void:
		if value == _equipped:
			return
		_equipped = value
		queue_redraw()

	## The colour [method _draw] fills the silhouette with — the tool's own
	## albedo, dimmed when it is the one being held.
	##
	## Public because it is what the integration test asserts on. Asserting on
	## the value the drawing code actually uses, rather than on a flag that is
	## supposed to make it use that value, is the difference between a test that
	## pins the behaviour and one that pins the bookkeeping.
	func fill_color() -> Color:
		if _tool == null:
			return Color(0.0, 0.0, 0.0, 0.0)
		var fill: Color = _tool.albedo
		fill.a = DIM_ALPHA if _equipped else 1.0
		return fill

	## Thickness of the ring [method _draw] puts around this badge, or zero when
	## there is no ring. Same reasoning as [method fill_color].
	func ring_width() -> float:
		return RING_WIDTH if _equipped else 0.0

	func _draw() -> void:
		if _tool == null:
			return
		var side: float = minf(size.x, size.y)
		var box: Rect2 = Rect2(Vector2.ZERO, size).grow(-side * SHAPE_INSET)
		var inner: float = minf(box.size.x, box.size.y)
		var fill: Color = fill_color()
		match _tool.shape:
			DetailingTool.Shape.CYLINDER:
				draw_circle(box.get_center(), inner * 0.5, fill)
			DetailingTool.Shape.BOX:
				var square: Vector2 = Vector2(inner, inner)
				draw_rect(Rect2(box.get_center() - square * 0.5, square), fill)
			DetailingTool.Shape.PLANE:
				var bar: Vector2 = Vector2(box.size.x, box.size.y * BAR_HEIGHT)
				draw_rect(Rect2(box.get_center() - bar * 0.5, bar), fill)
		var width: float = ring_width()
		if width > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size).grow(-side * RING_INSET), RING_COLOR, false, width)
