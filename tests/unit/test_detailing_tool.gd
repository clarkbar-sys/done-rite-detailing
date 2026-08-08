## Unit tests for [DetailingTool] — the five tools as data.
##
## Under tests/unit/ because a [DetailingTool] is a [RefCounted]: the whole
## catalogue is built and read here in microseconds, with no scene and no
## renderer. That the proxies described here are actually *rendered* is
## [code]tests/integration/test_view_model.gd[/code]'s job.
##
## Most of these assert the catalogue against the spec it was written from
## rather than against itself. A test that says "the sponge is whatever colour
## the sponge is" passes forever and protects nothing.
extends GutTest

var _tools: Array[DetailingTool] = []


func before_each() -> void:
	_tools = DetailingTool.catalogue()


func _by_id(id: DetailingTool.Id) -> DetailingTool:
	for tool_carried: DetailingTool in _tools:
		if tool_carried.id == id:
			return tool_carried
	return null


func test_the_catalogue_has_all_five_tools() -> void:
	assert_eq(_tools.size(), DetailingTool.Id.size(), "every declared tool must be built")


func test_every_tool_in_the_enum_is_in_the_catalogue() -> void:
	# By id and not by count: five entries where two are the same tool would pass
	# the test above and leave one tool unreachable forever.
	for id: DetailingTool.Id in DetailingTool.Id.values():
		assert_not_null(_by_id(id), "tool %d is declared but never built" % id)


func test_the_catalogue_is_in_declaration_order() -> void:
	# The belt, the roll-up and the number keys all take their order from here,
	# so this is the promise that makes those three agree.
	var ids: Array[int] = []
	for tool_carried: DetailingTool in _tools:
		ids.append(tool_carried.id)
	assert_eq(ids, DetailingTool.Id.values(), "belt order must follow the enum")


func test_each_call_builds_fresh_tools() -> void:
	# The catalogue is a function and not a shared constant precisely so that one
	# caller cannot recolour every other caller's tools.
	var other: Array[DetailingTool] = DetailingTool.catalogue()
	assert_ne(_tools[0], other[0], "two callers must not share one mutable tool")


func test_every_tool_is_named() -> void:
	for tool_carried: DetailingTool in _tools:
		assert_ne(tool_carried.display_name, "", "tool %d has no name" % tool_carried.id)


func test_tools_are_the_shapes_the_design_asked_for() -> void:
	assert_eq(_by_id(DetailingTool.Id.POWER_WASH).shape, DetailingTool.Shape.CYLINDER)
	assert_eq(_by_id(DetailingTool.Id.SPONGE).shape, DetailingTool.Shape.BOX)
	assert_eq(_by_id(DetailingTool.Id.DRYING_RAG).shape, DetailingTool.Shape.PLANE)
	assert_eq(_by_id(DetailingTool.Id.WINDOW_CLEANER).shape, DetailingTool.Shape.CYLINDER)
	assert_eq(_by_id(DetailingTool.Id.TIRE_ENGINE_CLEANER).shape, DetailingTool.Shape.CYLINDER)


func test_the_sponge_is_stretched_and_not_a_cube() -> void:
	# "yellow cube stretched" — a tool that drifts back to a cube reads as a
	# dice, so the stretch is the spec and not a nicety.
	var sponge: DetailingTool = _by_id(DetailingTool.Id.SPONGE)
	assert_ne(sponge.extent.x, sponge.extent.y, "the sponge must not be a cube")
	assert_gt(sponge.extent.x, sponge.extent.y, "the sponge is wider than it is thick")


func test_the_power_wash_is_the_metal_one() -> void:
	# Silver is a material, not a colour: without this the wand is a grey
	# plastic tube.
	assert_gt(_by_id(DetailingTool.Id.POWER_WASH).metallic, 0.5, "the wand must read as metal")


func test_nothing_else_on_the_belt_is_metal() -> void:
	for tool_carried: DetailingTool in _tools:
		if tool_carried.id == DetailingTool.Id.POWER_WASH:
			continue
		assert_lt(
			tool_carried.metallic, 0.5, "%s must not read as metal" % tool_carried.display_name
		)


func test_the_two_blue_tools_are_told_apart_by_colour() -> void:
	# Both are blue by spec, and colour is the whole thing that identifies a tool
	# in peripheral vision — so "both blue" must not become "the same blue".
	var rag: Color = _by_id(DetailingTool.Id.DRYING_RAG).albedo
	var cleaner: Color = _by_id(DetailingTool.Id.WINDOW_CLEANER).albedo
	var distance: float = (
		(Vector3(rag.r, rag.g, rag.b) - Vector3(cleaner.r, cleaner.g, cleaner.b)).length()
	)
	assert_gt(distance, 0.2, "the rag and the window cleaner are indistinguishable")


func test_no_two_tools_share_a_colour() -> void:
	# The general form of the test above, across the whole belt.
	for outer: int in _tools.size():
		for inner: int in range(outer + 1, _tools.size()):
			assert_ne(
				_tools[outer].albedo,
				_tools[inner].albedo,
				(
					"%s and %s look identical"
					% [_tools[outer].display_name, _tools[inner].display_name]
				)
			)


func test_the_black_tool_is_not_pure_black() -> void:
	# A true 0,0,0 takes no light and reads as a hole in the frame.
	var albedo: Color = _by_id(DetailingTool.Id.TIRE_ENGINE_CLEANER).albedo
	assert_gt(albedo.r + albedo.g + albedo.b, 0.0, "a pure black proxy is a hole, not a bottle")


func test_every_proxy_is_big_enough_to_see() -> void:
	# A zero extent in a dimension the shape actually uses is an invisible tool,
	# and the only way to notice is to look. The plane's unused `y` is exempt.
	for tool_carried: DetailingTool in _tools:
		assert_gt(tool_carried.extent.x, 0.0, "%s has no width" % tool_carried.display_name)
		if tool_carried.shape == DetailingTool.Shape.PLANE:
			assert_gt(tool_carried.extent.z, 0.0, "%s has no depth" % tool_carried.display_name)
		else:
			assert_gt(tool_carried.extent.y, 0.0, "%s has no height" % tool_carried.display_name)


func test_everything_but_the_rag_is_drawn_by_a_model() -> void:
	# Which tools have art and which are still primitives, said once here so that
	# nothing downstream has to keep its own list. The rag is the last one without
	# a model, and it is not an oversight — [ViewModel] draws it from
	# [member DetailingTool.shape], through [ClothRag], and will go on doing so
	# until somebody exports one.
	var modelled: Array[DetailingTool.Id] = [
		DetailingTool.Id.POWER_WASH,
		DetailingTool.Id.SPONGE,
		DetailingTool.Id.WINDOW_CLEANER,
		DetailingTool.Id.TIRE_ENGINE_CLEANER,
	]
	for tool_carried: DetailingTool in _tools:
		assert_eq(
			not tool_carried.model.is_empty(),
			modelled.has(tool_carried.id),
			"%s: drawn by a model?" % tool_carried.display_name
		)


func test_every_model_a_tool_names_is_really_there() -> void:
	# A path typed into a table is a path nobody runs until the tool is equipped,
	# and a missing one draws nothing at all — see [ToolModel], which refuses to
	# take the belt down over it. This is the check that turns "the bottle is
	# invisible" into a failing test instead of a bug report.
	for tool_carried: DetailingTool in _tools:
		if tool_carried.model.is_empty():
			continue
		assert_true(
			ResourceLoader.exists(tool_carried.model),
			"%s names %s, which is not there" % [tool_carried.display_name, tool_carried.model]
		)


func test_no_two_tools_are_drawn_by_the_same_model() -> void:
	# The two bottles are the same geometry in two liveries and are two separate
	# exports because of it. One path used twice would be two identical bottles,
	# which is the readability budget [member DetailingTool.albedo] documents,
	# spent silently.
	var named: Array[String] = []
	for tool_carried: DetailingTool in _tools:
		if tool_carried.model.is_empty():
			continue
		assert_false(named.has(tool_carried.model), "%s shares a model" % tool_carried.display_name)
		named.append(tool_carried.model)


func test_a_tool_is_a_primitive_unless_it_says_otherwise() -> void:
	# The default matters: every caller that built a tool before models existed
	# still builds one that renders exactly as it did.
	var built: DetailingTool = DetailingTool.new(
		DetailingTool.Id.SPONGE,
		"Test Tool",
		DetailingTool.Shape.BOX,
		Vector3.ONE,
		Color.WHITE,
		0.0,
		0.5
	)
	assert_eq(built.model, "", "a tool with no model named is drawn by its primitive")


func test_a_tool_keeps_what_it_was_built_with() -> void:
	var built: DetailingTool = DetailingTool.new(
		DetailingTool.Id.SPONGE,
		"Test Tool",
		DetailingTool.Shape.BOX,
		Vector3(1.0, 2.0, 3.0),
		Color(0.1, 0.2, 0.3),
		0.4,
		0.5,
		"res://nowhere.glb"
	)
	assert_eq(built.model, "res://nowhere.glb")
	assert_eq(built.id, DetailingTool.Id.SPONGE)
	assert_eq(built.display_name, "Test Tool")
	assert_eq(built.shape, DetailingTool.Shape.BOX)
	assert_eq(built.extent, Vector3(1.0, 2.0, 3.0))
	assert_eq(built.albedo, Color(0.1, 0.2, 0.3))
	assert_almost_eq(built.metallic, 0.4, 0.0001)
	assert_almost_eq(built.roughness, 0.5, 0.0001)
