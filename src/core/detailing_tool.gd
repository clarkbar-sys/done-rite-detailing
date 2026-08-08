## One tool on the belt: what it's called, and what it looks like.
##
## Five of these are the whole inventory, built by [method catalogue]. A tool is
## data and nothing else — it has no idea it will be rendered, which is what
## lets the entire belt be exercised by a unit test instead of a running scene.
##
## [b]The proxy lives here, not in the scene.[/b] Every tool carries the shape,
## size and colour it renders as, so the icon in the roll-up and the mesh in the
## player's hands read the same fields and cannot disagree. Put the colour in a
## scene file instead and you get two of them, agreeing right up until someone
## edits one — and "the icon is a different blue from the bottle" is exactly the
## kind of bug nobody files and everybody notices.
##
## Primitives on purpose, for the same reason [Garage] is boxes: the shape and
## the size [i]are[/i] the design decision, they are readable here rather than
## buried in a mesh nobody can diff, and a real model drops in later without
## moving anything else.
##
## [b]Two of them have now dropped in, and nothing else moved.[/b] The spray
## bottles carry a [member model] — a glTF exported out of
## [code]src-models/[/code] — and [ToolModel] fits it into exactly the
## [member extent] box the cylinder occupied. So this table still decides how big
## a bottle is, the roll-up still draws its icon from the same row, and the three
## tools with no model in their row are still primitives. What a model brings that
## a primitive could not is a texture, which is the whole reason to have one.
class_name DetailingTool
extends RefCounted

## Which tool this is. The order these are declared in is the order the belt
## carries them, the order the roll-up draws them, and the order the number keys
## bind to — one list, so those three can never drift apart.
enum Id {
	POWER_WASH,
	SPONGE,
	DRYING_RAG,
	WINDOW_CLEANER,
	TIRE_ENGINE_CLEANER,
}

## The primitive a tool stands in as. Named rather than "whichever mesh resource
## the scene happened to use", because the viewmodel and the roll-up icon both
## have to make the same choice from the same value.
enum Shape {
	CYLINDER,
	BOX,
	PLANE,
}

## Which tool this is.
var id: Id

## What a player would call it. Not shown anywhere yet — the roll-up is icons —
## but it is what a tooltip, a label or a save file will want, and inventing it
## per caller later is how five spellings of "Tire & Engine Cleaner" happen.
var display_name: String

## The primitive this tool renders as.
var shape: Shape

## The proxy's extent in metres, as width/height/depth. Read per shape: a
## [CylinderMesh] takes [code]x[/code] as its diameter and [code]y[/code] as its
## height and ignores [code]z[/code]; a [PlaneMesh] takes [code]x[/code] and
## [code]z[/code] and ignores [code]y[/code]. Kept as one [Vector3] rather than
## a shape-shaped union so the catalogue below stays a table you can read down.
var extent: Vector3

## The proxy's albedo. This is the whole readability budget: you should be able
## to tell which tool you are holding from the colour alone, in peripheral
## vision, without reading a label — which is why the two blues below are
## deliberately far apart rather than two shades of the same one.
var albedo: Color

## How metallic the proxy is, 0 to 1. Silver is a material and not a colour: a
## grey cylinder at [code]0.0[/code] reads as plastic no matter how light the
## grey is, which is the difference between a pressure washer and a toy.
var metallic: float

## How rough the proxy is, 0 to 1. Paired with [member metallic] because the two
## only mean anything together — a metallic surface at full roughness is a
## smudge, and a mirror-smooth cloth is not a cloth.
var roughness: float

## The modelled mesh this tool is drawn by in the player's hands, as a
## [code]res://[/code] path, or [code]""[/code] for a tool still drawn as the
## primitive above. This is the "a real model drops in later" the class docs
## promise, arriving for the two spray bottles.
##
## [b]Everything above still applies to a tool that has one.[/b] [ToolModel]
## fits the mesh into exactly the [member extent] box the primitive occupied, so
## the size is still this table's to decide and the roll-up icon is still drawn
## from the same numbers as the thing in your hands. What a model does replace is
## the surface: it brings its own texture, so [member albedo], [member metallic]
## and [member roughness] stop painting the mesh and go on describing it — which
## is what the roll-up reads them for, and why they are not deleted for a tool
## that has a model.
##
## A path rather than a [PackedScene] because this is data: the catalogue is
## built by a unit test with no renderer behind it, and a [code]preload[/code]
## here would drag two meshes and their textures into every one of those runs.
var model: String


func _init(
	tool_id: Id,
	name_shown: String,
	proxy_shape: Shape,
	proxy_extent: Vector3,
	proxy_albedo: Color,
	proxy_metallic: float,
	proxy_roughness: float,
	proxy_model: String = ""
) -> void:
	id = tool_id
	display_name = name_shown
	shape = proxy_shape
	extent = proxy_extent
	albedo = proxy_albedo
	metallic = proxy_metallic
	roughness = proxy_roughness
	model = proxy_model


## The five tools, in belt order.
##
## A function that builds them rather than a `const` array: a [Color] is fine in
## a constant but a [DetailingTool] is an object, and a single shared instance
## handed to every caller is a mutable global in a hat. Five allocations at
## startup is not a cost worth designing around.
static func catalogue() -> Array[DetailingTool]:
	var tools: Array[DetailingTool] = []
	# A wand: thin, long, and the only metal on the belt.
	tools.append(
		DetailingTool.new(
			Id.POWER_WASH,
			"Power Wash",
			Shape.CYLINDER,
			Vector3(0.06, 0.72, 0.06),
			Color(0.78, 0.80, 0.84),
			0.9,
			0.25
		)
	)
	# Stretched, as specified — a cube reads as a dice, and the thing that says
	# "sponge" is that it is wider than it is thick.
	tools.append(
		DetailingTool.new(
			Id.SPONGE,
			"Sponge",
			Shape.BOX,
			Vector3(0.24, 0.10, 0.17),
			Color(0.93, 0.82, 0.16),
			0.0,
			0.95
		)
	)
	# A plane has no thickness at all, so this one is the flattest thing on the
	# belt by definition; see [Shape] and the viewmodel for why it also has to be
	# double-sided.
	tools.append(
		DetailingTool.new(
			Id.DRYING_RAG,
			"Drying Rag",
			Shape.PLANE,
			Vector3(0.32, 0.0, 0.28),
			Color(0.20, 0.42, 0.85),
			0.0,
			0.9
		)
	)
	# A spray bottle, and the first tool on the belt to be a modelled mesh rather
	# than a primitive. The colour is what the roll-up draws it in and is unchanged
	# — the other blue on the belt, deliberately a long way from the rag's.
	tools.append(
		DetailingTool.new(
			Id.WINDOW_CLEANER,
			"Window Cleaner",
			Shape.CYLINDER,
			Vector3(0.10, 0.26, 0.10),
			Color(0.16, 0.66, 0.92),
			0.0,
			0.35,
			"res://assets/models/cleaning_spray/window_cleaner.glb"
		)
	)
	# A trigger sprayer, and the only tool on the belt whose art came from outside
	# the project — see [code]assets/models/cleaning_spray/ATTRIBUTION.txt[/code].
	# The colour is the roll-up's business and not the model's, and the same note
	# applies to it: near-black rather than black, because a true 0,0,0 icon takes
	# no light at all and reads as a hole in the badge instead of as a bottle.
	tools.append(
		DetailingTool.new(
			Id.TIRE_ENGINE_CLEANER,
			"Tire & Engine Cleaner",
			Shape.CYLINDER,
			Vector3(0.11, 0.30, 0.11),
			Color(0.09, 0.09, 0.10),
			0.0,
			0.5,
			"res://assets/models/cleaning_spray/tire_cleaner.glb"
		)
	)
	return tools
