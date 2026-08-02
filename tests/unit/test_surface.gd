## Unit tests for [Surface] — which bottle goes with which kind of panel.
##
## The whole class is two lookups, and both of them are the kind of thing that is
## obviously right until somebody reorders an enum. What is actually being pinned
## here is the property the lookups exist for: every kind has exactly one cleaner,
## and no two kinds share one. A table that drifted into giving the sponge to the
## windows would be invisible in play — the tool would work, on the wrong thing.
extends GutTest

## Every kind there is, so the loops below cannot quietly stop covering one that
## was added after they were written.
const KINDS: Array[Surface.Kind] = [Surface.Kind.BODY, Surface.Kind.GLASS, Surface.Kind.WHEEL]


func test_every_kind_of_surface_has_a_cleaner() -> void:
	var belt: ToolBelt = ToolBelt.new()
	for kind: Surface.Kind in KINDS:
		# On the belt, not merely a valid enum value: a cleaner the player cannot
		# pick up is a panel that cannot be finished.
		assert_true(belt.index_of(Surface.cleaner_for(kind)) >= 0, "kind %d" % kind)


func test_no_two_kinds_share_a_cleaner() -> void:
	# The property that makes [method Garage._spend_the_trigger]'s single
	# comparison a complete rule. If two kinds named the same bottle, one of them
	# would be unreachable and the other would work in two places.
	var seen: Array[DetailingTool.Id] = []
	for kind: Surface.Kind in KINDS:
		var cleaner: DetailingTool.Id = Surface.cleaner_for(kind)
		assert_false(seen.has(cleaner), "kind %d shares its cleaner" % kind)
		seen.append(cleaner)


func test_the_cleaners_are_the_ones_a_detailer_would_reach_for() -> void:
	# The mapping itself, stated once so that changing it is a decision rather
	# than a diff nobody reads.
	assert_eq(Surface.cleaner_for(Surface.Kind.BODY), DetailingTool.Id.SPONGE)
	assert_eq(Surface.cleaner_for(Surface.Kind.GLASS), DetailingTool.Id.WINDOW_CLEANER)
	assert_eq(Surface.cleaner_for(Surface.Kind.WHEEL), DetailingTool.Id.TIRE_ENGINE_CLEANER)


func test_neither_the_wash_nor_the_rag_is_anybody_s_cleaner() -> void:
	# They work on every panel, and they are routed by identity rather than by
	# surface. A kind that named one of them would be a panel whose middle pass
	# could be done with water.
	for kind: Surface.Kind in KINDS:
		var cleaner: DetailingTool.Id = Surface.cleaner_for(kind)
		assert_ne(cleaner, DetailingTool.Id.POWER_WASH, "kind %d" % kind)
		assert_ne(cleaner, DetailingTool.Id.DRYING_RAG, "kind %d" % kind)


func test_every_kind_has_a_product_colour() -> void:
	for kind: Surface.Kind in KINDS:
		# Visible against something. A product at zero alpha or pure black would
		# be a step of the job the player cannot see themselves doing.
		var colour: Color = Surface.product_colour(kind)
		assert_gt(colour.get_luminance(), 0.05, "kind %d is too dark to see" % kind)


func test_the_products_are_told_apart_by_colour() -> void:
	# The reason one channel can carry three products: the colour is a per-panel
	# uniform, so the only thing that makes suds read as suds and glass cleaner
	# read as glass cleaner is that these are far apart. Two products a shade
	# apart would be a mask that looks broken rather than a game that looks
	# layered.
	for kind: Surface.Kind in KINDS:
		for other: Surface.Kind in KINDS:
			if kind == other:
				continue
			var apart: Color = Surface.product_colour(kind) - Surface.product_colour(other)
			var gap: float = absf(apart.r) + absf(apart.g) + absf(apart.b)
			assert_gt(gap, 0.5, "kinds %d and %d look the same" % [kind, other])


func test_an_unknown_kind_gets_the_sponge() -> void:
	# The defaulting [constant Surface.WHEEL_GROUP] documents, from the other
	# side: paint is what a panel is when nobody has said otherwise, so a kind
	# nobody has handled yet is treated as bodywork rather than crashing a frame.
	var unknown: Surface.Kind = KINDS.size() as Surface.Kind
	assert_eq(Surface.cleaner_for(unknown), DetailingTool.Id.SPONGE)
	assert_eq(Surface.product_colour(unknown), Surface.BODY_PRODUCT)
