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
## [b]The icons are 16x16 pixel sprites on the brand's own plate.[/b] A round dark
## badge — [method Brand.badge], which is [method Brand.pill] at a square size,
## so a belt badge and the Start button are bent by the same arithmetic — with
## that tool drawn on top of it a pixel at a time, in tones derived from its
## [member DetailingTool.albedo]. See [ToolIcon] for the sprite tables, and
## [method sprite_palette] for why a character in one is a [i]role[/i] rather than
## a colour.
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

## The square the [i]stroke[/i] glyphs in this project are laid out on, and the
## only unit their tables are written in. Points are in [code]0..24[/code] with y
## running down, the way the screen does, so a table reads the same way it draws
## — no mental flip between writing a shape and looking at it.
##
## [b]The belt itself no longer uses this[/b] — its six marks are sprites, see
## [constant SPRITE_GRID]. It stays here, with [method stroke_glyph] and
## [method glyph_ring], because [CarArrow] and [SoundToggle] are still strokes and
## are still drawn through it. Those two are single shapes on their own plates
## where an outline is the whole picture; a tool badge is a picture of an object,
## which is the thing an outline was failing at.
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

## The pixel grid every sprite in this file is drawn on: rows of this many
## characters, this many of them, one character per pixel, with y running down —
## so a table in the source is a picture of the badge it draws.
const SPRITE_GRID: int = 16

## The roles a sprite character may be, in the order [method sprite_palette]
## hands their colours back. Any other character — [code].[/code], which is what
## the tables use — is transparent and draws nothing.
##
## A string of characters rather than a [Dictionary] keyed by them: a palette is
## then a [PackedColorArray] indexed by [method String.find], which is a typed
## array of the eight colours a sprite may contain and is checkable as one.
const ROLES: String = "#BSHDWwO"

## How far in from the plate's edge a sprite is drawn, as a fraction of the
## smaller side — [constant GLYPH_INSET]'s job for the pixel grid, and the same
## reasoning: the tap target is a fingertip's, and a 164 px sponge is not a
## picture, it is a wall.
##
## The number is what leaves the sprite inside the [i]disc[/i] rather than inside
## its bounding square. A square inscribed in a circle is 1/sqrt(2) — a hair over
## 70% — of it across, and 0.15 in from both sides is exactly that 70%, so the
## sprite's corners sit just inside a plate that is 100%.
const SPRITE_INSET: float = 0.15

## How much darker [code]S[/code] is than the base it is a shade of, and
## [code]D[/code] — grips, triggers, the deep half of a thing — darker again.
##
## [b]Neither is checked against [constant Brand.BADGE_CONTRAST], on purpose.[/b]
## Only the base is (see [method ToolIcon.fill_color]), because a shade is read
## against the pixels it touches and not against the plate: it is always enclosed
## by base and ink, never by plate. Holding every tone to 4.5:1 on a near-black
## panel would mean a shade lighter than the thing it shades — the sprite would
## have to go tonally flat to pass a test written to keep it readable.
const SHADE_DROP: float = 0.26
const DEEP_DROP: float = 0.5

## How much lighter [code]H[/code] is — a lit top face, the side the strip lights
## are on.
const HIGHLIGHT_LIFT: float = 0.3

## How much darker [code]w[/code] is than [code]W[/code]: the far end of a fan,
## where the water has broken up and stopped catching the light. The same
## reasoning [constant WashJet.SPRAY] is the far end of [constant WashJet.TIP] by.
const WATER_DROP: float = 0.3

## Suds, and the shine off a wet panel: [code]O[/code]. White-ish rather than
## [constant Brand.WHITE], because a bubble is water and takes a little of the
## sky with it — and because the one thing on the belt that is flat white should
## go on being the ring round the badge you are holding.
const SUDS: Color = Color(0.96, 0.98, 1.0)

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


## The picture on the corner button — the three bars of a menu mark, or an
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
## Shared by [CarArrow] and [SoundToggle] because they are the same picture
## problem twice: a table of points on a square grid, scaled to whatever the
## layout ended up handing the control. Written once so a glyph cannot end up
## drawn at one weight on one corner of the screen and another on the other.
##
## [b]The belt's own six marks stopped coming through here[/b] — see
## [method paint_sprite]. The short version is that a stroke carries a shape and
## nothing else, and five tools told apart by outline alone at the ~50 px a phone
## renders this design at is one channel doing the whole job again.
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


## The eight colours [param base] implies, in [constant ROLES] order — what a
## sprite's characters mean.
##
## [b]This is the part of the pixel pass that must not be fudged.[/b]
## [DetailingTool]'s class docs promise that a tool's colour lives in the
## catalogue so "the icon in the roll-up and the mesh in the player's hands cannot
## disagree", and a sprite carrying its own hex values would break that promise
## quietly — five tables of literals that start out matching the catalogue and
## drift the first time somebody repaints a bottle. So a character is a role and
## the roles are computed: [code]B[/code] is the base it was handed,
## [code]S[/code] and [code]D[/code] are that base darkened, [code]H[/code] is it
## lightened. Change an albedo and all four move together.
##
## [b][code]W[/code] and [code]w[/code] are the deliberate exception, and
## [code]O[/code] with them.[/b] Water and suds belong to the [i]pass[/i] rather
## than to the bottle — the jet is the same water whichever tool throws it, so
## tinting it per tool would say the power wash sprays something different from
## the tyre cleaner. The blue comes from [constant PatchFlash.WASH_TINT], which is
## the colour the paint itself flashes when a patch comes clean, so the belt and
## the car cannot end up two different blues.
##
## [b][code]#[/code] is a constant and is shared by every sprite.[/b] An outline
## tinted per tool would go on being one channel wearing a second coat: what
## separates a sprite from its plate is that the edge is nearly black whatever the
## thing inside it is made of.
static func sprite_palette(base: Color) -> PackedColorArray:
	return PackedColorArray(
		[
			Brand.INK,
			base,
			base.darkened(SHADE_DROP),
			base.lightened(HIGHLIGHT_LIFT),
			base.darkened(DEEP_DROP),
			PatchFlash.WASH_TINT,
			PatchFlash.WASH_TINT.darkened(WATER_DROP),
			SUDS,
		]
	)


## Draws [param rows] — a sprite on the [constant SPRITE_GRID] grid — onto
## [param on], centred inside a control [param within] pixels across, with each
## character coloured by [param palette] the way [constant ROLES] says.
##
## [b]Why a grid of rectangles and not a texture.[/b] Five authored PNGs would
## bring an import step, five binaries nobody can diff in review, and a
## texture-filter setting that will be wrong exactly once — and none of them could
## derive a colour from the catalogue, which is the property [method
## sprite_palette] exists to keep. A table of strings keeps everything the stroke
## tables had: greppable, diffable, and constructible in a test with no
## [SceneTree] behind it. The [SubViewport] this class's docs reject is rejected
## for the same money it always was.
##
## Nearest-neighbour by construction, because there is no sampling anywhere in
## here: a pixel is a [method CanvasItem.draw_rect] the size the layout worked
## out, so the badge is crisp at 164 px, at the ~50 px a phone renders it at, and
## at every size in between.
##
## An unknown character draws nothing rather than erroring, which is what makes
## [code].[/code] transparent without being a role of its own — and what a
## well-formedness test asserts from the other side, so a typo is a red suite
## rather than a hole in a badge.
static func paint_sprite(
	on: CanvasItem, rows: PackedStringArray, within: Vector2, palette: PackedColorArray
) -> void:
	var side: float = minf(within.x, within.y)
	if side <= 0.0:
		return
	var box: Rect2 = Rect2(Vector2.ZERO, within).grow(-side * SPRITE_INSET)
	var pixel: float = minf(box.size.x, box.size.y) / float(SPRITE_GRID)
	var origin: Vector2 = box.get_center() - Vector2.ONE * pixel * float(SPRITE_GRID) * 0.5
	var square: Vector2 = Vector2(pixel, pixel)
	for down: int in rows.size():
		var row: String = rows[down]
		for across: int in row.length():
			var role: int = ROLES.find(row[across])
			if role < 0 or role >= palette.size():
				continue
			var at: Vector2 = origin + Vector2(float(across), float(down)) * pixel
			on.draw_rect(Rect2(at, square), palette[role])


## One tool's badge: the brand's round plate with that tool drawn on it.
##
## A [Button] rather than a [Control] with [method Control._gui_input], because
## what makes a tap work on a phone is the engine turning it into a click and
## [BaseButton] handling that — the same path the Start button takes, and the
## one the integration test exercises through [code]Input[/code].
##
## [b]Why a drawn picture and not the shape the tool renders as.[/b] The badge
## used to be [member DetailingTool.shape] — a circle for a cylinder, a square
## for a box, a bar for a plane — which made three of the five badges the same
## circle, told apart by colour alone. That is one channel carrying the whole
## job, and it is the channel that fails first: in sunlight, at a glance, and for
## roughly one man in twelve. Putting the information in the shape survives all
## three.
##
## [b]And why the shape then stopped being an outline.[/b] Five stroked
## silhouettes were the first answer to that, and they did not read at the size
## they are actually looked at. Weight was not the problem — a heavier stroke was
## mocked up and gives a heavier version of the same picture. Shape was: the rag
## was a rectangle with a wobble on its bottom edge and read as a table, the
## sponge's three equal suds in a row read as a face, and the power wash was four
## disconnected segments that resolved into a hockey stick with no nozzle and no
## water in it. Only the tyre survived a glance, because a circle inside a circle
## is the one shape a 2-unit stroke can still carry at 50 px.
##
## A [constant ToolBeltHud.SPRITE_GRID] sprite fixes both halves at once: it gives
## each tool [i]mass[/i] instead of an edge, and a second and third tone instead
## of a single flat colour. It is still a table in the script, still diffable in
## review, and still costs no asset pipeline — see
## [method ToolBeltHud.paint_sprite] for what was weighed against it.
##
## [b]Tones derived from the albedo, not written down beside it.[/b] What a tool
## is made of and what its badge is drawn in stopped being the same number when
## the Tire & Engine bottle — near-black on purpose — turned out to be invisible
## on any dark plate; [method Brand.badge_tint] has that whole argument, and
## lightening the badge is the fix that does not touch the bottle in the player's
## hands. Every other tone in the sprite is computed from that one, so the promise
## [DetailingTool]'s docs make survives the format change. See
## [method ToolBeltHud.sprite_palette].
##
## [b]Equipped is a red plate with a white ring, and the sprite keeps its own
## colours.[/b] Two treatments have been thrown away here already: fading the tool
## you are holding, which is the universal look of a control that is broken, and
## then drawing it as a flat white silhouette on the red plate, which was right
## while a badge was an outline and became the worst badge on the belt the moment
## the others had three tones in them — the one icon the eye is meant to land on
## first would have been the only one with no picture left in it. So the sprite is
## drawn in the tool's own tones, lifted against the red rather than against the
## panel ([method fill_color]), and the second channel the red plate needs comes
## from [method Brand.picked_badge] instead: a white hairline round the plate,
## which survives greyscale and does not touch the picture.
class ToolIcon:
	extends Button

	var _tool: DetailingTool = null
	var _equipped: bool = false

	## The sprite table: [param id] as [constant ToolBeltHud.SPRITE_GRID] rows of
	## [constant ToolBeltHud.SPRITE_GRID] characters, each one a role in
	## [constant ToolBeltHud.ROLES] or [code].[/code] for nothing at all, with y
	## running down the way the screen does — so the table below is a picture of the
	## badge it draws.
	##
	## Static and public because it is data rather than state, which makes it
	## checkable without a badge to hang it on —
	## [code]tests/integration/test_tool_belt_hud.gd[/code] asserts every tool has
	## one, that each is well formed, and that no two tools draw the same picture.
	static func sprite(id: DetailingTool.Id) -> PackedStringArray:
		match id:
			DetailingTool.Id.POWER_WASH:
				# A spray gun in profile — body, barrel, pistol grip — with a fan
				# leaving the nozzle. The old glyph had neither a nozzle nor any
				# water in it, which is how it came to read as a hockey stick.
				return PackedStringArray(
					[
						"................",
						"................",
						"..............WW",
						"..#######....www",
						".#BBBBBBB##.WWWW",
						".#BBBBBBBBS#wwww",
						".#BBBBBBBBS#WWWW",
						".#BBBBBBBBS#wwww",
						".#SSSBBBB##.WWWW",
						".#DDD####....www",
						".#DDD#........WW",
						".#DDD#..........",
						".#DDD#..........",
						".#DDD#..........",
						".#DDD#..........",
						"..###...........",
					]
				)
			DetailingTool.Id.SPONGE:
				# A block with a lit top face and pores in it, and two suds coming
				# off it. The suds are deliberately different sizes and at different
				# heights: two equal circles side by side is what made the old glyph
				# read as a face.
				return PackedStringArray(
					[
						"...OO...........",
						"..O..O..........",
						"..O..O....O.....",
						"...OO....OO.....",
						"................",
						"................",
						"..############..",
						".#HHHHHHHHHHHH#.",
						".#HHHHHHHHHHHH#.",
						".#BBBBBBBBBBSB#.",
						".#BBSBBBSBBBBB#.",
						".#BBBBBBBBBSBB#.",
						".#BBBSBBBSBBBB#.",
						".#SSSSSSSSSSSS#.",
						"..############..",
						"................",
					]
				)
			DetailingTool.Id.DRYING_RAG:
				# A cloth held along a straight top edge and hanging in two lobes,
				# with a fold down it and a shine coming off it. The lobes are what
				# stop it being a table; the shine is what says buff rather than
				# wipe, which is the pass this tool actually is.
				return PackedStringArray(
					[
						"......O.........",
						".....OOO........",
						"..####O#######..",
						".#BBBBBBBBBBBB#.",
						".#BBBBBBBBBBBB#.",
						".#SSSSSSSSSSSS#.",
						".#BBBBBBBBBBBB#.",
						".#BBBBBBBSBBBB#.",
						".#BBBBBBBSSBBB#.",
						".#BBBBBBBBSSBBO.",
						".#BBBBBBBBBSSOOO",
						".#BBBBBBBBBBSSO.",
						".#BBBB#BBBB#BS#.",
						"..#BB#.#BB#.#B#.",
						"...##...##...#..",
						"................",
					]
				)
			DetailingTool.Id.WINDOW_CLEANER:
				# A trigger sprayer, nozzle right, with the cone coming out of it.
				# The trigger is still the half that matters: without it this is the
				# same bottle as the tyre cleaner.
				return PackedStringArray(
					[
						"................",
						".............ww.",
						"....#####...WWWW",
						"...#BBBBB##.wwww",
						"...#BBBBBBB#WWWW",
						"...#BBBBB##.wwww",
						"...#DDDD#....WW.",
						"...##BBB##......",
						"..#BBBBBBB#.....",
						"..#BBBBBBB#.....",
						"..#HHHHHHH#.....",
						"..#HHHHHHH#.....",
						"..#BBBBBBB#.....",
						"..#BBBBBBB#.....",
						"..#SSSSSSS#.....",
						"...#######......",
					]
				)
			DetailingTool.Id.TIRE_ENGINE_CLEANER:
				# A tyre with tread blocks round a rim, and the jet going at it. The
				# wheel is still what tells this apart from the other bottle on the
				# belt, which is why the bottle is not drawn at all — unchanged
				# reasoning from the glyph this replaces.
				return PackedStringArray(
					[
						".............WWW",
						"............wwww",
						"....SSSSS..WWWWW",
						"...S#BBB#S..wwww",
						"..SB#BBB#BS..WWW",
						".SBB#####BBS....",
						"S###SHHHS###S...",
						"SBB#HHHHH#BBS...",
						"SBB#HHHHH#BBS...",
						"SBB#HHHHH#BBS...",
						"S###SHHHS###S...",
						".SBB#####BBS....",
						"..SB#BBB#BS.....",
						"...S#BBB#S......",
						"....SSSSS.......",
						"................",
					]
				)
		return PackedStringArray()

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

	## The colour the plate under the sprite is filled with: [constant Brand.RED]
	## for the tool in your hands, [constant Brand.PANEL] for the rest.
	##
	## Public because it is what the integration test asserts on. Asserting on the
	## value the drawing code actually uses, rather than on a flag that is supposed
	## to make it use that value, is the difference between a test that pins the
	## behaviour and one that pins the bookkeeping.
	func plate_color() -> Color:
		return Brand.RED if _equipped else Brand.PANEL

	## The sprite's [code]B[/code]: this tool's own colour, lifted only as far as it
	## takes to be seen on the plate it is actually being drawn on. Every other tone
	## in the badge is derived from it — see [method ToolBeltHud.sprite_palette].
	##
	## [b]The base and not the whole palette, because the base is the one tone the
	## plate has to be cleared against.[/b] A shade or a highlight is enclosed by
	## base and ink and is read against those; only [code]B[/code] is what the badge
	## reads as from across a phone screen. [constant ToolBeltHud.SHADE_DROP] has
	## the rest of that argument, and the integration suite asserts this pair.
	##
	## Same reasoning as [method plate_color] for why it is public.
	func fill_color() -> Color:
		if _tool == null:
			return Color(0.0, 0.0, 0.0, 0.0)
		return Brand.badge_tint(_tool.albedo, plate_color())

	## Puts the round plate on, in all four of the states Godot will ask for. Any
	## state left unstyled falls back to the engine's grey rectangle — which is
	## what this whole pass is here to get rid of, so leaving `hover` out would
	## reintroduce it for exactly as long as a thumb is on the badge.
	func _dress() -> void:
		var side: float = size.y
		if side <= 0.0:
			return
		var plate: Color = plate_color()
		add_theme_stylebox_override("normal", _plate(plate, side))
		add_theme_stylebox_override("hover", _plate(plate.lightened(Brand.HOVER_LIFT), side))
		add_theme_stylebox_override("pressed", _plate(Brand.RED_DARK, side))
		add_theme_stylebox_override("focus", Brand.focus_ring(side))

	## One state's plate: the brand's badge, wearing the white ring while this is
	## the tool in the player's hands.
	##
	## The ring goes on every state rather than only on `normal`, or it would blink
	## off under a thumb — which is the moment the belt is being read.
	func _plate(fill: Color, side: float) -> StyleBoxFlat:
		if _equipped:
			return Brand.picked_badge(fill, side)
		return Brand.badge(fill, side)

	func _draw() -> void:
		if _tool == null:
			return
		var palette: PackedColorArray = ToolBeltHud.sprite_palette(fill_color())
		ToolBeltHud.paint_sprite(self, sprite(_tool.id), size, palette)


## The picture on the corner button: the three bars of a menu mark, and an
## [b]x[/b] while the roll-up is out.
##
## [b]Why the corner stopped being a letter.[/b] It was a [b]T[/b], chosen
## because a glyph the font already has cannot go missing. What it could do
## instead was mean nothing — a T on a dark square is initialism, not an icon,
## and it said the same thing whether the tools were out or not. The mark says
## what the corner is for while it is closed and what pressing it will do while
## it is open, which is the one job a toggle has.
##
## [b]And why it then stopped being a picture of the tools.[/b] The first answer
## to that was three tool heads hanging on a belt line — literally what is inside
## the corner. It is the right idea one level too literal: a 16x16 grid gives each
## head about four pixels across, so at the ~50 px a phone renders this badge at
## the heads are three blobs over a rule, and what a player reads is a shape they
## have to learn rather than one they already know. Three bars are the mark every
## surface on a phone already uses for [i]this opens[/i], they need no colour and
## no second tone to be read, and they are the one picture that cannot lose detail
## as it shrinks because it has none to lose. The corner is a menu; it now looks
## like one.
##
## [b]The bars are this game's only menu mark, and that is what makes them
## unambiguous.[/b] Nothing else here opens from a corner, so they can mean the
## tool belt and nothing else. The day a second one wants them, that stops being
## true and the corner needs its picture back — which is what this note is for.
##
## A [Control] rather than more drawing inside [ToolBeltHud] because the corner
## button moves, and a picture that lived in the HUD's own [method _draw] would
## have to be told where the button went. Anchored to it instead, and
## [constant Control.MOUSE_FILTER_IGNORE] so the thing a finger hits is still the
## button underneath.
##
## [b]It went pixel with the five badges, which makes six marks and not five.[/b]
## The corner is drawn through the same helper the badges are and always has been,
## and it sits on the same belt a thumb reads in one glance. Left as a stroke it
## would have been the only thin thing on a belt of solid ones — which reads as a
## mark that has not finished loading rather than as a deliberate difference.
class BeltMark:
	extends Control

	var _open: bool = false

	## The sprite for both faces of the corner: the menu mark's three bars, or the
	## [b]x[/b]. Static and public for the reason [method ToolIcon.sprite] is.
	##
	## Only [code]B[/code] and [code]S[/code] appear in either. The corner is not a
	## tool and has no albedo to derive anything from — it is drawn in
	## [constant Brand.WHITE], which needs no lifting on either plate — so a
	## highlight would have nowhere above it to go, and an ink outline would be a
	## black edge round the one mark on this HUD that is meant to read as a symbol
	## rather than as an object.
	static func sprite(open: bool) -> PackedStringArray:
		if open:
			return PackedStringArray(
				[
					"................",
					"................",
					"................",
					"................",
					"...BB......BB...",
					"....BB....BB....",
					".....BB..BB.....",
					"......BBBB......",
					"......BBBB......",
					"......BBBB......",
					".....BB..BB.....",
					"....BB....BB....",
					"...BB......BB...",
					"................",
					"................",
					"................",
				]
			)
		# Three bars, each two pixels of white over one of shade, with two clear
		# pixels between them — and the gap is the measured half. Drawn first at one
		# pixel of gap, which is the spacing the bars want at 164 px and the spacing
		# that closes up at 50: the sprite grid is 70% of the plate, so a phone
		# renders a sprite pixel at about two device pixels and a one-pixel gap is a
		# seam rather than a space. At two it is still three bars in a thumbnail.
		# The white rows sit at 2-3, 7-8 and 12-13, which centres their mass on the
		# grid exactly; the shade rows hang below as depth, not as mass.
		return PackedStringArray(
			[
				"................",
				"................",
				"..BBBBBBBBBBBB..",
				"..BBBBBBBBBBBB..",
				"..SSSSSSSSSSSS..",
				"................",
				"................",
				"..BBBBBBBBBBBB..",
				"..BBBBBBBBBBBB..",
				"..SSSSSSSSSSSS..",
				"................",
				"................",
				"..BBBBBBBBBBBB..",
				"..BBBBBBBBBBBB..",
				"..SSSSSSSSSSSS..",
				"................",
			]
		)

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
		var palette: PackedColorArray = ToolBeltHud.sprite_palette(Brand.WHITE)
		ToolBeltHud.paint_sprite(self, sprite(_open), size, palette)
