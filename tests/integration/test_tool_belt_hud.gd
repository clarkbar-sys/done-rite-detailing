## Integration test for the tool belt's roll-up.
##
## Under tests/integration/ because almost nothing here is true of the script on
## its own: the icons are built in [method ToolBeltHud.bind], their rectangles
## come from a layout pass, and the two facts that actually matter — every
## target is big enough to hit, and the collapsed roll-up eats nothing — are
## only observable once the scene is in a tree at the design resolution.
##
## The HUD is added [i]over[/i] a full-screen button on purpose. "Intercepts no
## input" cannot be checked by asserting the HUD stayed quiet; a root [Control]
## that swallowed the tap would also stay quiet. The button underneath is the
## witness — the play screen's [SubViewportContainer] is what it stands in for.
extends GutTest

const TOOL_BELT_HUD: String = "res://src/ui/tool_belt_hud.tscn"

## Long enough for the expand/collapse tween to have finished, with room to
## spare. Derived from the HUD's own constant rather than written down again, so
## a snappier roll-up does not silently start being measured mid-flight.
const SETTLE_SECONDS: float = ToolBeltHud.EXPAND_SECONDS * 2.0

var _hud: ToolBeltHud = null
var _belt: ToolBelt = null
var _underneath: Button = null
var _picked_ids: Array[int] = []
var _picked_indices: Array[int] = []
var _underneath_presses: int = 0
var _window_size_before: Vector2i = Vector2i.ZERO


func before_each() -> void:
	_picked_ids = []
	_picked_indices = []
	_underneath_presses = 0
	# A headless window is 64x64 — smaller than a single tap target, small
	# enough that every rectangle in this file would be clamped into nonsense
	# and the size and overlap assertions would pass or fail for a reason that
	# has nothing to do with the roll-up. `content_scale_size` is the design
	# resolution from project.godot, so this makes a coordinate here mean what
	# it means on screen. Put back in after_each: every suite shares this window.
	var root: Window = get_tree().root
	_window_size_before = root.size
	root.size = root.content_scale_size
	# The stand-in for the garage: a control that covers the whole screen and
	# sits below the HUD, exactly like the SubViewportContainer does on the play
	# screen. Typed locals before add_child_autofree because GUT's helper is
	# untyped, and autofree is what keeps a failing assertion below from being
	# reported as a leak against whichever test runs next.
	var underneath: Button = Button.new()
	underneath.set_anchors_preset(Control.PRESET_FULL_RECT)
	_underneath = underneath
	add_child_autofree(_underneath)
	_underneath.pressed.connect(_record_underneath)
	var packed: PackedScene = load(TOOL_BELT_HUD) as PackedScene
	assert_not_null(packed, "could not load %s" % TOOL_BELT_HUD)
	if packed == null:
		return
	var hud: ToolBeltHud = packed.instantiate() as ToolBeltHud
	_hud = hud
	add_child_autofree(_hud)
	_hud.tool_selected.connect(_record_pick)
	_belt = ToolBelt.new()
	_hud.bind(_belt)
	# `_ready()` has already fired inside add_child; the frame is only here to
	# let layout settle before any rectangle is read.
	await wait_process_frames(1)


func after_each() -> void:
	get_tree().root.size = _window_size_before


func _record_pick(id: DetailingTool.Id, index: int) -> void:
	_picked_ids.append(id)
	_picked_indices.append(index)


func _record_underneath() -> void:
	_underneath_presses += 1


## Rolls the tools out and waits for the tween, so the icons are measured where
## they come to rest rather than somewhere along the way.
func _open() -> void:
	_hud.set_expanded(true)
	await wait_seconds(SETTLE_SECONDS)


func _close() -> void:
	_hud.set_expanded(false)
	await wait_seconds(SETTLE_SECONDS)


## Taps the screen at [param at], the way a finger does: a touch event, not the
## mouse click a desktop test would send.
##
## Through `Input` rather than `Viewport.push_input()` deliberately, and for the
## same reason the title screen's test does it — nothing in [Button] reads a
## touch event, so what actually makes a tap work is the engine turning it into
## a click first, and that emulation lives in `Input`. Pushing the touch
## straight at the viewport would skip the exact step these tests exist to
## prove, and pass while the game was broken.
func _tap(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var touch: InputEventScreenTouch = InputEventScreenTouch.new()
		touch.position = at
		touch.pressed = pressed
		Input.parse_input_event(touch)
	Input.flush_buffered_events()


func test_the_scene_is_a_tool_belt_hud() -> void:
	# The play screen will cast to [ToolBeltHud] to call bind(); a scene that
	# lost its script would be a silent no-op there.
	assert_not_null(_hud, "the roll-up must instantiate as a ToolBeltHud")


func test_it_starts_collapsed() -> void:
	# Every time the play screen loads, not just the first — a roll-up that
	# remembered being open would be covering the car the moment you arrived.
	assert_false(_hud.is_expanded(), "the roll-up starts put away")


func test_it_draws_one_icon_per_tool_on_the_belt() -> void:
	assert_eq(_hud.icon_count(), _belt.size(), "one icon per tool, sized from the belt")


func test_it_draws_nothing_until_it_is_bound() -> void:
	# The HUD is handed a belt rather than building one, so an unbound roll-up
	# is empty rather than showing a second, imaginary inventory.
	var packed: PackedScene = load(TOOL_BELT_HUD) as PackedScene
	var lone: ToolBeltHud = packed.instantiate() as ToolBeltHud
	add_child_autofree(lone)
	await wait_process_frames(1)
	assert_eq(lone.icon_count(), 0, "an unbound roll-up invents no tools")


func test_the_icons_are_in_belt_order() -> void:
	# Index 0 nearest the toggle, which is [method ToolBelt.tools] order, which
	# is the order the number keys will bind to. One list or three that drift.
	await _open()
	var tools: Array[DetailingTool] = _belt.tools()
	var toggle_top: float = _hud.toggle_button().get_global_rect().position.y
	var previous_top: float = toggle_top
	for index: int in tools.size():
		var icon: ToolBeltHud.ToolIcon = _hud.icon_at(index)
		assert_not_null(icon, "belt slot %d must have an icon" % index)
		assert_eq(
			icon.tooltip_text,
			tools[index].display_name,
			"icon %d must stand for the tool at that place on the belt" % index
		)
		# The equipped badge is white on red and is checked in its own test below;
		# what is being pinned here is that every *other* badge is drawn in the
		# colour of the tool sitting at its own index, rather than at some other.
		if index != _belt.equipped_index():
			assert_eq(
				icon.fill_color().to_html(false),
				Brand.badge_tint(tools[index].albedo).to_html(false),
				"icon %d must be drawn in its own tool's colour" % index
			)
		previous_top = icon.get_global_rect().position.y
	assert_lt(previous_top, toggle_top + 1.0, "the roll-up grows upward out of the corner")


func test_pressing_the_toggle_expands_and_pressing_again_collapses() -> void:
	_hud.toggle_button().pressed.emit()
	assert_true(_hud.is_expanded(), "the corner rolls the tools out")
	_hud.toggle_button().pressed.emit()
	assert_false(_hud.is_expanded(), "the corner puts them away again")


func test_a_tap_on_the_toggle_rolls_the_tools_out() -> void:
	# Through a real touch rather than the signal, so a toggle that is somehow
	# unhittable on a phone fails here rather than in a browser.
	_tap(_hud.toggle_button().get_global_rect().get_center())
	await wait_process_frames(1)
	assert_true(_hud.is_expanded(), "a tap on the corner must roll the tools out")


# ---- sizing: the phone-shaped half, and the reason this file exists ----------


func test_every_target_is_big_enough_for_a_finger() -> void:
	# The bug this pins is the Start button's, one layout further along: six tap
	# targets stacked in a corner is exactly what a design scaled to a third on
	# a phone eats first. [TouchTarget] has the arithmetic and the sources.
	await _open()
	var minimum: float = TouchTarget.min_design_size()
	var toggle: Button = _hud.toggle_button()
	assert_gte(toggle.size.x, minimum, "the corner is too narrow to hit on a phone")
	assert_gte(toggle.size.y, minimum, "the corner is too short to hit on a phone")
	for index: int in _hud.icon_count():
		var icon: ToolBeltHud.ToolIcon = _hud.icon_at(index)
		assert_gte(icon.size.x, minimum, "icon %d is too narrow to hit on a phone" % index)
		assert_gte(icon.size.y, minimum, "icon %d is too short to hit on a phone" % index)


func test_no_two_targets_overlap() -> void:
	# The other half of "big enough": a target that measures 164 px but has a
	# neighbour sitting on half of it is 82 px of usable strip, and the test
	# above would still be green. This is what stops the column being made to
	# fit by letting the icons overlap.
	await _open()
	var rects: Array[Rect2] = [_hud.toggle_button().get_global_rect()]
	for index: int in _hud.icon_count():
		rects.append(_hud.icon_at(index).get_global_rect())
	for first: int in rects.size():
		for second: int in range(first + 1, rects.size()):
			assert_false(
				rects[first].intersects(rects[second]),
				"targets %d and %d overlap: %s vs %s" % [first, second, rects[first], rects[second]]
			)


func test_every_target_is_on_screen() -> void:
	# The reason the column wraps. Five 164 px icons plus the toggle want 984 px
	# of a 720 px design, so a single upward column puts two of them off the top
	# — reachable by nobody, and invisible to the size test above.
	await _open()
	var screen: Rect2 = Rect2(Vector2.ZERO, _hud.size)
	var corner: Rect2 = _hud.toggle_button().get_global_rect()
	assert_true(screen.encloses(corner), "the corner must be on screen")
	for index: int in _hud.icon_count():
		assert_true(
			screen.encloses(_hud.icon_at(index).get_global_rect()),
			"icon %d is off screen and cannot be tapped" % index
		)


# ---- the brand, on the belt --------------------------------------------------


func test_every_badge_is_a_disc_in_the_brands_own_colours() -> void:
	# The failure this pins is what the whole pass is for: an unstyled [Button] is
	# a grey rectangle with square corners and a border that is nobody's
	# --line, and five of them in the corner of a lit garage is a HUD that does not
	# belong to the game it is drawn over. Read back off the control rather than
	# trusted, because a stylebox built and never applied looks identical in the
	# source and blank on screen.
	await _open()
	for index: int in _hud.icon_count():
		var icon: ToolBeltHud.ToolIcon = _hud.icon_at(index)
		var box: StyleBoxFlat = icon.get_theme_stylebox("normal") as StyleBoxFlat
		assert_not_null(box, "icon %d is still wearing the engine's own button" % index)
		if box == null:
			continue
		assert_eq(box.bg_color, icon.plate_color(), "icon %d's plate" % index)
		assert_eq(
			box.corner_radius_top_left,
			roundi(icon.size.y / 2.0),
			"icon %d must be a disc, not a card" % index
		)


func test_every_badge_glyph_can_be_seen_on_its_own_plate() -> void:
	# Colour was doing this job alone and failing it — Tire & Engine Cleaner's
	# albedo is 1.02:1 on --panel, which is a badge you cannot see. Asserted here
	# as well as in the unit test because this is the pair that actually reaches
	# the screen: the colour the icon draws with, against the plate it draws on.
	await _open()
	for index: int in _hud.icon_count():
		var icon: ToolBeltHud.ToolIcon = _hud.icon_at(index)
		assert_gte(
			Brand.contrast_ratio(icon.fill_color(), icon.plate_color()),
			Brand.BADGE_CONTRAST,
			"icon %d is invisible on its own plate" % index
		)


func test_every_tool_has_its_own_silhouette_and_it_stays_on_the_grid() -> void:
	# Shape carries what colour was carrying alone, so "every tool has a shape" is
	# a claim worth checking rather than an intention. The bounds half is the bug
	# a stroke table develops silently: a point at 30 on a 24-unit grid draws
	# outside the plate and looks like a rendering glitch, not like a typo.
	var seen: Array[String] = []
	for carried: DetailingTool in DetailingTool.catalogue():
		var paths: Array[PackedVector2Array] = ToolBeltHud.ToolIcon.glyph(carried.id)
		assert_gt(paths.size(), 0, "%s has no silhouette" % carried.display_name)
		var shape: String = str(paths)
		assert_false(
			seen.has(shape), "%s draws the same picture as another tool" % carried.display_name
		)
		seen.append(shape)
		for path: PackedVector2Array in paths:
			assert_gt(
				path.size(), 1, "%s has a stroke with nothing to stroke" % carried.display_name
			)
			for point: Vector2 in path:
				assert_between(
					point.x, 0.0, ToolBeltHud.GLYPH_GRID, "%s off grid" % carried.display_name
				)
				assert_between(
					point.y, 0.0, ToolBeltHud.GLYPH_GRID, "%s off grid" % carried.display_name
				)


func test_the_equipped_icon_is_a_red_plate_and_no_other_is() -> void:
	# The tool you are already holding is the one the eye should land on first —
	# and it is the one icon you cannot usefully press, so the old treatment faded
	# it, which is the universal look of a control that is broken. Red is what the
	# site puts on the thing you have pressed and white is the only colour that
	# goes on top of it; neither is a colour this belt did not already have.
	# Asserted on the values [method ToolBeltHud.ToolIcon._draw] actually uses,
	# not on a flag that is supposed to make it use them.
	await _open()
	var equipped: int = _belt.equipped_index()
	for index: int in _hud.icon_count():
		var icon: ToolBeltHud.ToolIcon = _hud.icon_at(index)
		if index == equipped:
			assert_eq(icon.plate_color(), Brand.RED, "the tool in your hands wears the accent")
			assert_eq(
				icon.fill_color(), Brand.WHITE, "and is drawn in the one colour that goes on it"
			)
		else:
			assert_eq(icon.plate_color(), Brand.PANEL, "icon %d is not the one being held" % index)
			assert_ne(icon.fill_color(), Brand.WHITE, "icon %d keeps its own colour" % index)


func test_the_red_plate_follows_the_belt() -> void:
	# Through the belt's own signal rather than by calling the handler, so a
	# connection dropped in bind() fails here rather than on screen.
	await _open()
	var was: int = _belt.equipped_index()
	_belt.equip(DetailingTool.Id.DRYING_RAG)
	var now: int = _belt.index_of(DetailingTool.Id.DRYING_RAG)
	assert_ne(now, was, "the test needs a tool that isn't already equipped")
	assert_eq(_hud.icon_at(now).plate_color(), Brand.RED, "the accent moves to the new tool")
	assert_eq(_hud.icon_at(was).plate_color(), Brand.PANEL, "and leaves the old one")


# ---- the corner ---------------------------------------------------------------


func test_the_corner_wears_the_brand_and_says_what_it_is_for() -> void:
	# It used to be a letter on the engine's grey rectangle. A T is initialism
	# rather than an icon, and it said the same thing whether the tools were out
	# or not — which is the one job a toggle's picture has.
	var box: StyleBoxFlat = _hud.toggle_button().get_theme_stylebox("normal") as StyleBoxFlat
	assert_not_null(box, "the corner is still wearing the engine's own button")
	if box == null:
		return
	assert_eq(box.bg_color, Brand.PANEL, "closed, the corner is a dark plate")
	assert_eq(box.border_color, Brand.LINE, "with the brand's own lit edge")
	assert_eq(_hud.toggle_button().text, "", "and no letter left on top of it")


func test_the_corner_says_close_while_the_tools_are_out() -> void:
	assert_false(_hud.toggle_mark().is_open(), "put away, the corner says tools")
	await _open()
	assert_true(_hud.toggle_mark().is_open(), "out, it says close rather than saying tools twice")
	var box: StyleBoxFlat = _hud.toggle_button().get_theme_stylebox("normal") as StyleBoxFlat
	assert_eq(box.bg_color, Brand.RED, "and wears the accent, like the badge you have picked")
	await _close()
	assert_false(_hud.toggle_mark().is_open(), "and goes back to saying tools")


# ---- picking: emits, and nothing else ---------------------------------------


func test_picking_an_icon_emits_the_tool_id_and_its_place_on_the_belt() -> void:
	await _open()
	var index: int = _belt.index_of(DetailingTool.Id.WINDOW_CLEANER)
	_hud.icon_at(index).pressed.emit()
	assert_eq(_picked_ids.size(), 1, "picking a tool must emit exactly once")
	if _picked_ids.size() != 1:
		return
	assert_eq(_picked_ids[0], int(DetailingTool.Id.WINDOW_CLEANER), "the id of the tool picked")
	assert_eq(_picked_indices[0], index, "and where it sits on the belt")


func test_picking_a_tool_does_not_equip_it() -> void:
	# This commit is the UI half only: the signal goes out and the play screen
	# will decide what it means. A HUD that equipped things itself would be a
	# second owner of game state.
	await _open()
	var before: int = _belt.equipped_index()
	_hud.icon_at(_belt.index_of(DetailingTool.Id.SPONGE)).pressed.emit()
	assert_eq(_belt.equipped_index(), before, "the roll-up asks; it does not equip")


func test_picking_a_tool_puts_the_roll_up_away() -> void:
	await _open()
	_hud.icon_at(0).pressed.emit()
	assert_false(_hud.is_expanded(), "picking a tool closes the roll-up")


func test_a_tap_on_an_icon_emits() -> void:
	await _open()
	var index: int = _belt.index_of(DetailingTool.Id.TIRE_ENGINE_CLEANER)
	_tap(_hud.icon_at(index).get_global_rect().get_center())
	await wait_process_frames(1)
	assert_eq(_picked_indices, [index], "a tap on an icon must pick that tool")


# ---- collapsed, the roll-up is not there ------------------------------------


func test_a_tap_where_a_collapsed_icon_would_be_reaches_what_is_underneath() -> void:
	# The layering trap, from the far side. While collapsed, everything except
	# the T has to be as absent to the input system as it is to the eye — and
	# the way to prove that is not "the HUD stayed quiet" (a control that ate
	# the tap is also quiet) but "the thing below it heard the tap".
	await _open()
	var slot: Vector2 = _hud.icon_at(0).get_global_rect().get_center()
	await _close()
	_underneath_presses = 0
	_tap(slot)
	await wait_process_frames(1)
	assert_eq(_picked_ids.size(), 0, "a collapsed roll-up picks nothing")
	assert_eq(_underneath_presses, 1, "and lets the tap through to the game behind it")


func test_a_tap_in_open_space_reaches_what_is_underneath() -> void:
	# The full-rect root is the real hazard here: a [Control] defaults to
	# MOUSE_FILTER_STOP, so a HUD anchored to the whole screen would swallow
	# every click in the game forever, expanded or not.
	_underneath_presses = 0
	_tap(_hud.size * 0.5)
	await wait_process_frames(1)
	assert_eq(_underneath_presses, 1, "the HUD covers the screen but must not eat it")
