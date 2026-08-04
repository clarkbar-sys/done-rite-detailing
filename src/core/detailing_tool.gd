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

## What a player would call it. The roll-up is icons, so this is what its
## tooltip reads; it is also what a label or a save file will want, and inventing
## it per caller later is how five spellings of "Tire & Engine Cleaner" happen.
var display_name: String

## Which of the business's four services this tool is doing — a [Service]
## constant, never a string written here.
##
## [b]This is the whole of "the game demonstrates the service menu".[/b] The
## three passes the job is made of already [i]are[/i] three of the four things
## Done Rite sells; until now they were called Power Wash, Sponge and Drying Rag,
## which are the names of the objects rather than the names of the work. Carrying
## the service alongside the object costs one string per tool and turns the belt
## into the menu — see [ToolBeltHud.ToolIcon.carry] and [ScoreHud.score] for the
## two places a player reads it.
##
## [b]The rag is [constant Service.PROTECT_AND_MAINTAIN] and not the "Dry" of
## Hand Wash & Dry[/b], which is the one mapping worth arguing rather than
## asserting. By its name the rag dries; by what it does in this game it is the
## buff pass — [GrimeMap] will not let it touch a panel that has no product on
## it, and what it leaves behind is shine. "Vehicle-care options that help
## preserve shine" is the site's own blurb for Protect & Maintain, so the pass is
## sorted by the work it does rather than by the noun on the tool.
##
## [constant Service.INTERIOR_DEEP_CLEAN] is on no tool here, and that is not an
## oversight: the car has no inside. [Service] has the note.
var service: String

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


func _init(
	tool_id: Id,
	name_shown: String,
	service_done: String,
	proxy_shape: Shape,
	proxy_extent: Vector3,
	proxy_albedo: Color,
	proxy_metallic: float,
	proxy_roughness: float
) -> void:
	id = tool_id
	display_name = name_shown
	service = service_done
	shape = proxy_shape
	extent = proxy_extent
	albedo = proxy_albedo
	metallic = proxy_metallic
	roughness = proxy_roughness


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
			Service.HAND_WASH_AND_DRY,
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
			Service.HAND_WASH_AND_DRY,
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
			Service.PROTECT_AND_MAINTAIN,
			Shape.PLANE,
			Vector3(0.32, 0.0, 0.28),
			Color(0.20, 0.42, 0.85),
			0.0,
			0.9
		)
	)
	# A spray bottle. The other blue on the belt, and deliberately a long way
	# from the rag's: lighter, greener, and a different silhouette besides.
	tools.append(
		DetailingTool.new(
			Id.WINDOW_CLEANER,
			"Window Cleaner",
			Service.HAND_WASH_AND_DRY,
			Shape.CYLINDER,
			Vector3(0.10, 0.26, 0.10),
			Color(0.16, 0.66, 0.92),
			0.0,
			0.35
		)
	)
	# Near-black rather than black: a true 0,0,0 takes no light at all, so it
	# would read as a hole in the frame instead of a bottle.
	tools.append(
		DetailingTool.new(
			Id.TIRE_ENGINE_CLEANER,
			"Tire & Engine Cleaner",
			Service.WHEEL_AND_TIRE_SHINE,
			Shape.CYLINDER,
			Vector3(0.11, 0.30, 0.11),
			Color(0.09, 0.09, 0.10),
			0.0,
			0.5
		)
	)
	return tools
