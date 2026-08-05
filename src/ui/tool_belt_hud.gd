## The tool belt's UI half: a round badge in the bottom-left corner that rolls
## the five tools up out of it, and puts them away again.
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
## [b]The icons are drawn silhouettes on the brand's own plate.[/b] A round dark
## badge — [method Brand.badge], which is [method Brand.pill] at a square size,
## so a belt badge and the Start button are bent by the same arithmetic — with
## that tool's outline stroked on top of it in a tint derived from its
## [member DetailingTool.albedo]. See [ToolIcon] for the stroke table and for why
## a tint rather than the raw albedo.
##
## The alternative, a [SubViewport] per tool rendering the real mesh, was
## rejected on cost: that is five more render targets on a page that already has
## one, to fill a 164 px badge on a phone. Deriving the colour from the
## catalogue is the part that matters, because it is what stops the badge and the
## mesh in the player's hands from drifting into two different blues.
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

## What the corner is called, for a pointer that hovers and for a screen reader.
## The picture on it is [BeltMark]; this is the word for it.
const TOGGLE_TOOLTIP: String = "Tools"

## The square every glyph in this file is laid out on, and the only unit the
## stroke tables below are written in. Points are in [code]0..24[/code] with y
## running down, the way the screen does, so a table reads the same way it draws
## — no mental flip between writing a shape and looking at it.
const GLYPH_GRID: float = 24.0

## How far in from the plate's edge the picture is drawn, as a fraction of the
## smaller side. The tap target is the whole button; the picture is smaller than
## the target on purpose, because the target is sized for a fingertip and a
## 164 px sponge is not a picture, it is a wall.
##
## The number is what leaves the glyph inside the disc rather than inside the
## square: at this inset the glyph's own square is 48% of the plate across, so
## its corners sit well inside a circle that is 100% of it.
const GLYPH_INSET: float = 0.26

## Stroke weight, in glyph-grid units — so it scales with the badge instead of
## being a pixel count that is right at one size and hairline at every other.
const GLYPH_WIDTH: float = 2.0

## How many segments a glyph circle is bent into. Enough that a tyre is round at
## 164 px, few enough that the table stays a table.
const RING_SEGMENTS: int = 16

var _belt: ToolBelt = null
var _icons: Array[ToolIcon] = []
var _slots: Array[Vector2] = []
var _collapsed_slot: Vector2 = Vector2.ZERO
var _expanded: bool = false
var _expansion: float = 0.0
var _tween: Tween = null
var _mark: BeltMark = null

@onready var _holder: Control = %Icons
@onready var _toggle: Button = %Toggle


func _ready() -> void:
	_toggle.tooltip_text = TOGGLE_TOOLTIP
	# The picture rides on the button rather than being drawn by it, because a
	# [Button] subclass cannot be named by a .tscn without its own script file and
	# this one is an inner class. Full-rect and unpickable, so the thing a finger
	# actually hits is still the button underneath it.
	_mark = BeltMark.new()
	_mark.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toggle.add_child(_mark)
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
	# Here rather than in [method _apply_expansion]: the state flips once, the
	# tween runs eight times, and rebuilding four styleboxes a frame to say the
	# same thing four frames running is work nobody asked for.
	_dress_toggle()
	_animate_to(1.0 if _expanded else 0.0)


## Flips between rolled out and put away — what the toggle does, exposed so a
## key binding can do the same thing later without re-deriving the state.
func toggle() -> void:
	set_expanded(not _expanded)


## The corner button itself. For tests, and for anything that wants to point the
## player at it.
func toggle_button() -> Button:
	return _toggle


## The picture on the corner button — three tool heads on a belt line, or an
## [b]x[/b] while the roll-up is out. Public for the same reason
## [method ToolIcon.fill_color] is: what the corner is saying is a thing a test
## can read, and a corner that went on saying "tools" while the tools were
## already out would be a bug nobody notices in code and everybody notices in a
## thumb.
func toggle_mark() -> BeltMark:
	return _mark


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
	# After the size is written, never before: a badge is a disc because its
	# corner radius is half its height, and the height it is half of is this one.
	_dress_toggle()
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


## Puts the brand on the corner button: a round plate in all four of the states
## Godot will ask for, and the picture that goes on it.
##
## [b]All four, because Godot falls back to the theme for any it is not given[/b]
## — styling only [code]normal[/code] would leave the hover and the press wearing
## the engine's grey, which is the one moment the button is being used. The title
## screen's [method TitleScreen._dress] pays for the same thing in the same coin.
##
## [b]Red while the tools are out.[/b] On the site red is what a thing you press
## wears, and here it is what the thing you have already pressed wears — the
## equipped badge is red for exactly the same reason. A corner that stayed dark
## with the roll-up open would be the only part of this HUD not saying what state
## it is in, and the [b]x[/b] would be doing that work alone.
func _dress_toggle() -> void:
	if _toggle == null:
		return
	var side: float = _toggle.size.y
	if side <= 0.0:
		return
	var plate: Color = Brand.RED if _expanded else Brand.PANEL
	_toggle.add_theme_stylebox_override("normal", Brand.badge(plate, side))
	_toggle.add_theme_stylebox_override(
		"hover", Brand.badge(plate.lightened(Brand.HOVER_LIFT), side)
	)
	_toggle.add_theme_stylebox_override("pressed", Brand.badge(Brand.RED_DARK, side))
	_toggle.add_theme_stylebox_override("focus", Brand.focus_ring(side))
	if _mark != null:
		_mark.set_open(_expanded)


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


## Draws [param paths] — a glyph in [constant GLYPH_GRID] units — onto
## [param on], centred inside a control [param within] pixels across, stroked in
## [param ink].
##
## Shared by the badges and the corner mark because they are the same picture
## problem twice: a table of points on a square grid, scaled to whatever the
## layout ended up handing the control. Written once so a glyph cannot end up
## drawn at one weight on the belt and another in the corner.
##
## Stroke width scales with the glyph rather than being a fixed pixel count. The
## design is rendered at about a third on a phone, so a 6 px line drawn at 1280
## is 2 px in a hand — thin enough to alias away against a lit garage, which is
## exactly the failure [TouchTarget] documents for tap targets, wearing a
## different coat.
static func stroke_glyph(
	on: CanvasItem, paths: Array[PackedVector2Array], within: Vector2, ink: Color
) -> void:
	var side: float = minf(within.x, within.y)
	if side <= 0.0:
		return
	var box: Rect2 = Rect2(Vector2.ZERO, within).grow(-side * GLYPH_INSET)
	var unit: float = minf(box.size.x, box.size.y) / GLYPH_GRID
	var origin: Vector2 = box.get_center() - Vector2(GLYPH_GRID, GLYPH_GRID) * unit * 0.5
	for path: PackedVector2Array in paths:
		var points: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in path:
			points.append(origin + point * unit)
		on.draw_polyline(points, ink, GLYPH_WIDTH * unit, true)


## A closed loop of [constant RING_SEGMENTS] points around [param centre] at
## [param radius], in glyph-grid units.
##
## Circles are tessellated into the same stroke table as everything else rather
## than drawn with [method CanvasItem.draw_arc], so a glyph is one kind of thing
## — a list of paths — and the drawing above is one loop over it. At sixteen
## segments a wheel is a wheel at any size this HUD is rendered at.
static func glyph_ring(centre: Vector2, radius: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for step: int in RING_SEGMENTS + 1:
		var angle: float = TAU * float(step) / float(RING_SEGMENTS)
		points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	return points


## One tool's badge: the brand's round plate with that tool drawn on it.
##
## A [Button] rather than a [Control] with [method Control._gui_input], because
## what makes a tap work on a phone is the engine turning it into a click and
## [BaseButton] handling that — the same path the Start button takes, and the
## one the integration test exercises through [code]Input[/code].
##
## [b]Why a drawn silhouette and not the shape the tool renders as.[/b] The badge
## used to be [member DetailingTool.shape] — a circle for a cylinder, a square
## for a box, a bar for a plane — which made three of the five badges the same
## circle, told apart by colour alone. That is one channel carrying the whole
## job, and it is the channel that fails first: in sunlight, at a glance, and for
## roughly one man in twelve. Five silhouettes put the same information in the
## shape, where it survives all three. The table is points on a grid, drawn in
## [method _draw] the way the primitives were, so it is still greppable, still
## diffable, and still costs no asset pipeline.
##
## [b]A tint rather than the albedo.[/b] What a tool is made of and what its
## badge is drawn in stopped being the same number here — see
## [method Brand.badge_tint] for the whole of that argument. The short version is
## that the Tire & Engine bottle is near-black on purpose and was therefore
## invisible on any dark plate, and lightening the badge is the fix that does not
## touch the bottle in the player's hands.
##
## [b]Equipped is a red plate, not a dimmed one.[/b] The old badge faded the tool
## you were holding and drew a ring round it in a colour nothing else on the belt
## used. Faded is the universal look of a control that is broken, and the ring
## was a sixth colour on a five-colour belt. Red is what the site puts on the
## thing you have pressed, white is the only colour that goes on top of it, and
## neither is new.
class ToolIcon:
	extends Button

	var _tool: DetailingTool = null
	var _equipped: bool = false

	## The stroke table: [param id]'s silhouette, as paths on a
	## [constant GLYPH_GRID]-unit square with y running down the way the screen
	## does.
	##
	## Static and public because it is geometry rather than state, which makes it
	## checkable without a badge to hang it on —
	## [code]tests/integration/test_tool_belt_hud.gd[/code] asserts every tool has
	## one and that none of them draw outside the grid they claim to be on.
	static func glyph(id: DetailingTool.Id) -> Array[PackedVector2Array]:
		var paths: Array[PackedVector2Array] = []
		match id:
			DetailingTool.Id.POWER_WASH:
				# A lance out of the bottom-left corner with a pistol grip under
				# it, and the fan leaving the nozzle.
				paths.append(PackedVector2Array([Vector2(4, 20), Vector2(16, 8)]))
				paths.append(PackedVector2Array([Vector2(4, 20), Vector2(7, 23)]))
				paths.append(PackedVector2Array([Vector2(17, 7), Vector2(22, 2)]))
				paths.append(PackedVector2Array([Vector2(18, 8.5), Vector2(23, 7)]))
				paths.append(PackedVector2Array([Vector2(17, 10), Vector2(21, 13)]))
			DetailingTool.Id.SPONGE:
				# A block, wider than it is thick — the thing that says "sponge"
				# and not "dice" — with three suds rising off it.
				(
					paths
					. append(
						PackedVector2Array(
							[
								Vector2(3, 13),
								Vector2(21, 13),
								Vector2(21, 20),
								Vector2(3, 20),
								Vector2(3, 13),
							]
						)
					)
				)
				paths.append(ToolBeltHud.glyph_ring(Vector2(7, 8), 2.6))
				paths.append(ToolBeltHud.glyph_ring(Vector2(12.5, 5), 3.0))
				paths.append(ToolBeltHud.glyph_ring(Vector2(17.5, 8.5), 2.2))
			DetailingTool.Id.DRYING_RAG:
				# A cloth: square at the top where it is held, rippling at the
				# bottom where it is not, with a hem stitched across it.
				(
					paths
					. append(
						PackedVector2Array(
							[
								Vector2(4, 5),
								Vector2(20, 5),
								Vector2(20, 14),
								Vector2(16, 18),
								Vector2(12, 14),
								Vector2(8, 18),
								Vector2(4, 14),
								Vector2(4, 5),
							]
						)
					)
				)
				paths.append(PackedVector2Array([Vector2(4, 8.5), Vector2(20, 8.5)]))
			DetailingTool.Id.WINDOW_CLEANER:
				# A trigger bottle. The trigger is the half that matters: without
				# it this is the same bottle as the tire cleaner.
				(
					paths
					. append(
						PackedVector2Array(
							[
								Vector2(7, 12),
								Vector2(17, 12),
								Vector2(17, 21),
								Vector2(7, 21),
								Vector2(7, 12),
							]
						)
					)
				)
				(
					paths
					. append(
						PackedVector2Array(
							[
								Vector2(9, 12),
								Vector2(9, 7),
								Vector2(15, 7),
								Vector2(15, 9.5),
								Vector2(11, 9.5),
							]
						)
					)
				)
				paths.append(PackedVector2Array([Vector2(15, 8), Vector2(19, 6)]))
				paths.append(PackedVector2Array([Vector2(11, 9.5), Vector2(10, 12)]))
			DetailingTool.Id.TIRE_ENGINE_CLEANER:
				# A tyre, and the jets going at it. The wheel is what tells this
				# one apart from the other bottle on the belt, which is why the
				# bottle is not drawn at all.
				paths.append(ToolBeltHud.glyph_ring(Vector2(10, 15), 7.0))
				paths.append(ToolBeltHud.glyph_ring(Vector2(10, 15), 3.0))
				paths.append(PackedVector2Array([Vector2(17, 4), Vector2(14, 7)]))
				paths.append(PackedVector2Array([Vector2(21, 6), Vector2(17, 10)]))
				paths.append(PackedVector2Array([Vector2(23, 11), Vector2(20, 14)]))
		return paths

	func _ready() -> void:
		# The plate is a stylebox and a stylebox is built at a size, so it has to
		# be rebuilt when the layout hands this badge a different one.
		resized.connect(_dress)
		_dress()

	## Tells this badge which tool it stands for. Separate from
	## [method Object._init] because [Button] has its own and a subclass that
	## replaces it has to keep calling it.
	func carry(shown: DetailingTool) -> void:
		_tool = shown
		tooltip_text = shown.display_name
		_dress()
		queue_redraw()

	## Marks this badge as the tool in the player's hands.
	func set_equipped(value: bool) -> void:
		if value == _equipped:
			return
		_equipped = value
		_dress()
		queue_redraw()

	## The colour the plate under the glyph is filled with: [constant Brand.RED]
	## for the tool in your hands, [constant Brand.PANEL] for the rest.
	##
	## Public because it is what the integration test asserts on. Asserting on the
	## value the drawing code actually uses, rather than on a flag that is supposed
	## to make it use that value, is the difference between a test that pins the
	## behaviour and one that pins the bookkeeping.
	func plate_color() -> Color:
		return Brand.RED if _equipped else Brand.PANEL

	## The colour [method _draw] strokes the silhouette in: white on the equipped
	## plate, and otherwise this tool's own colour lifted until it can be seen
	## against the plate. Same reasoning as [method plate_color].
	func fill_color() -> Color:
		if _tool == null:
			return Color(0.0, 0.0, 0.0, 0.0)
		if _equipped:
			return Brand.WHITE
		return Brand.badge_tint(_tool.albedo)

	## Puts the round plate on, in all four of the states Godot will ask for. Any
	## state left unstyled falls back to the engine's grey rectangle — which is
	## what this whole pass is here to get rid of, so leaving `hover` out would
	## reintroduce it for exactly as long as a thumb is on the badge.
	func _dress() -> void:
		var side: float = size.y
		if side <= 0.0:
			return
		var plate: Color = plate_color()
		add_theme_stylebox_override("normal", Brand.badge(plate, side))
		add_theme_stylebox_override("hover", Brand.badge(plate.lightened(Brand.HOVER_LIFT), side))
		add_theme_stylebox_override("pressed", Brand.badge(Brand.RED_DARK, side))
		add_theme_stylebox_override("focus", Brand.focus_ring(side))

	func _draw() -> void:
		if _tool == null:
			return
		ToolBeltHud.stroke_glyph(self, glyph(_tool.id), size, fill_color())


## The picture on the corner button: three tool heads on a belt line, and an
## [b]x[/b] while the roll-up is out.
##
## [b]Why the corner stopped being a letter.[/b] It was a [b]T[/b], chosen
## because a glyph the font already has cannot go missing. What it could do
## instead was mean nothing — a T on a dark square is initialism, not an icon,
## and it said the same thing whether the tools were out or not. The mark says
## what the corner is for while it is closed and what pressing it will do while
## it is open, which is the one job a toggle has.
##
## A [Control] rather than more drawing inside [ToolBeltHud] because the corner
## button moves, and a picture that lived in the HUD's own [method _draw] would
## have to be told where the button went. Anchored to it instead, and
## [constant Control.MOUSE_FILTER_IGNORE] so the thing a finger hits is still the
## button underneath.
class BeltMark:
	extends Control

	var _open: bool = false

	## The stroke table for both faces of the corner: the tools, or the [b]x[/b].
	## Static and public for the reason [method ToolIcon.glyph] is.
	static func glyph(open: bool) -> Array[PackedVector2Array]:
		var paths: Array[PackedVector2Array] = []
		if open:
			paths.append(PackedVector2Array([Vector2(7, 7), Vector2(17, 17)]))
			paths.append(PackedVector2Array([Vector2(17, 7), Vector2(7, 17)]))
			return paths
		paths.append(PackedVector2Array([Vector2(3, 17), Vector2(21, 17)]))
		paths.append(ToolBeltHud.glyph_ring(Vector2(6.5, 11), 2.7))
		(
			paths
			. append(
				PackedVector2Array(
					[
						Vector2(9.5, 8),
						Vector2(14.5, 8),
						Vector2(14.5, 14),
						Vector2(9.5, 14),
						Vector2(9.5, 8),
					]
				)
			)
		)
		paths.append(ToolBeltHud.glyph_ring(Vector2(17.5, 11), 2.7))
		return paths

	func _ready() -> void:
		resized.connect(queue_redraw)

	## Whether the corner is currently saying [i]close[/i] rather than
	## [i]tools[/i].
	func is_open() -> bool:
		return _open

	## Flips the mark. Idempotent, so the HUD can assert the state it wants rather
	## than track the one it is in.
	func set_open(value: bool) -> void:
		if value == _open:
			return
		_open = value
		queue_redraw()

	func _draw() -> void:
		# White on both plates: it is 15:1 on the dark one and the only colour the
		# brand puts on top of the red one.
		ToolBeltHud.stroke_glyph(self, glyph(_open), size, Brand.WHITE)
