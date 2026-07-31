## Unit tests for [ToolBelt] — what the player is carrying, and which one is in
## their hands.
##
## Under tests/unit/ because a [ToolBelt] is a [RefCounted]: every equip rule
## below is checked without a scene, a camera or a mesh. That equipping actually
## *changes what you see* is
## [code]tests/integration/test_view_model.gd[/code]'s job.
extends GutTest

var _belt: ToolBelt = null
var _swaps: Array[DetailingTool] = []


func before_each() -> void:
	_belt = ToolBelt.new()
	_swaps = []
	_belt.equipped_changed.connect(_record)


func _record(tool_equipped: DetailingTool) -> void:
	_swaps.append(tool_equipped)


func test_the_belt_carries_the_whole_catalogue() -> void:
	assert_eq(_belt.size(), DetailingTool.catalogue().size(), "the belt carries every tool")


func test_the_belt_starts_with_something_in_hand() -> void:
	# There is no empty-handed state, so nothing downstream has to null-check.
	assert_not_null(_belt.equipped(), "the player always holds something")


func test_the_belt_starts_on_the_power_wash() -> void:
	assert_eq(_belt.equipped().id, DetailingTool.Id.POWER_WASH, "the belt starts at its first tool")
	assert_eq(_belt.equipped_index(), 0)


func test_it_says_nothing_on_its_own() -> void:
	# Construction must not fire the swap signal — a listener that connects after
	# the belt exists would miss it, and one that connects before would get a
	# swap it never asked for.
	assert_eq(_swaps.size(), 0, "building a belt is not a swap")


func test_equipping_a_different_tool_changes_what_is_held() -> void:
	assert_true(_belt.equip(DetailingTool.Id.SPONGE), "equipping a carried tool must succeed")
	assert_eq(_belt.equipped().id, DetailingTool.Id.SPONGE)


func test_equipping_a_different_tool_announces_it_once() -> void:
	_belt.equip(DetailingTool.Id.SPONGE)
	assert_eq(_swaps.size(), 1, "one swap, one signal")
	if _swaps.size() != 1:
		return
	assert_eq(_swaps[0].id, DetailingTool.Id.SPONGE, "the signal must carry the new tool")


func test_equipping_what_is_already_held_says_nothing() -> void:
	# The roll-up closes on any pick, so this path runs every time a player taps
	# the tool they already have. It must not restart the viewmodel's swap.
	assert_false(_belt.equip(DetailingTool.Id.POWER_WASH), "re-equipping changed nothing")
	assert_eq(_swaps.size(), 0, "re-equipping the held tool must be silent")
	assert_eq(_belt.equipped().id, DetailingTool.Id.POWER_WASH, "and must not drop it either")


func test_every_tool_on_the_belt_can_be_equipped() -> void:
	for tool_carried: DetailingTool in _belt.tools():
		_belt.equip(tool_carried.id)
		assert_eq(
			_belt.equipped().id, tool_carried.id, "%s is unreachable" % tool_carried.display_name
		)


func test_walking_the_whole_belt_announces_every_swap() -> void:
	# Starts on the first tool, so the first equip in this loop is a no-op and
	# the belt announces one fewer swap than it has tools.
	for tool_carried: DetailingTool in _belt.tools():
		_belt.equip(tool_carried.id)
	assert_eq(_swaps.size(), _belt.size() - 1, "every genuine swap is announced exactly once")


func test_the_equipped_index_follows_the_equipped_tool() -> void:
	_belt.equip(DetailingTool.Id.WINDOW_CLEANER)
	var index: int = _belt.equipped_index()
	assert_eq(
		_belt.tools()[index].id, DetailingTool.Id.WINDOW_CLEANER, "the index must point at it"
	)


func test_equipping_by_position_works() -> void:
	assert_true(_belt.equip_at(2), "the third tool is on the belt")
	assert_eq(_belt.equipped_index(), 2)
	assert_eq(_belt.equipped().id, _belt.tools()[2].id)


func test_equipping_past_the_end_of_the_belt_is_refused() -> void:
	# `1`-`5` on a shorter belt is a thing that will happen; it must do nothing
	# rather than wrap round to a tool the player did not ask for.
	var held: DetailingTool = _belt.equipped()
	assert_false(_belt.equip_at(_belt.size()), "there is no tool past the end")
	assert_false(_belt.equip_at(-1), "there is no tool before the start")
	assert_eq(_belt.equipped(), held, "a refused equip must leave the belt alone")
	assert_eq(_swaps.size(), 0, "a refused equip announces nothing")


func test_an_unknown_tool_is_refused_and_changes_nothing() -> void:
	var held: DetailingTool = _belt.equipped()
	# An id past the end of the enum: what a stale saved game or a renumbered
	# UI button would hand in. It must not half-equip and must not crash.
	var unknown: DetailingTool.Id = DetailingTool.Id.values().size() as DetailingTool.Id
	assert_false(_belt.equip(unknown), "an unknown tool is not on the belt")
	assert_eq(_belt.equipped(), held, "a refused equip must leave the belt alone")
	assert_eq(_swaps.size(), 0, "a refused equip announces nothing")


func test_it_finds_where_each_tool_sits() -> void:
	for index: int in _belt.size():
		assert_eq(
			_belt.index_of(_belt.tools()[index].id), index, "index_of must agree with the belt"
		)


func test_it_reports_a_missing_tool_as_absent() -> void:
	var unknown: DetailingTool.Id = DetailingTool.Id.values().size() as DetailingTool.Id
	assert_eq(_belt.index_of(unknown), -1, "a tool not carried is at no index")
