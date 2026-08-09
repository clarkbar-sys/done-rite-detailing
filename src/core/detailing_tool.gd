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
## [b]Four of them have now dropped in, and nothing else moved.[/b] The two spray
## bottles, the sponge and the power wash carry a [member model] — a glTF under
## [code]assets/models/[/code], downloaded or baked out of [code]src-models/[/code]
## — and [ToolModel] fits it into exactly the [member extent] box the primitive
## occupied. So this table still decides how big a bottle is, the roll-up still
## draws its icon from the same row, and the one tool with no model in its row is
## still a primitive. What a model brings that a primitive could not is a texture,
## which is the whole reason to have one.
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
## promise, arriving for the two spray bottles, then the sponge, and now for the
## power wash.
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
## [b]And [member shape] goes on meaning what it meant.[/b] The sponge is still a
## [constant Shape.BOX] with a model in the same row: the roll-up draws that box,
## and it is the shape the fit puts the mesh in whether or not a primitive is
## built from it. A modelled tool that quietly stopped declaring a shape would
## leave the icon with nothing to draw.
##
## A path rather than a [PackedScene] because this is data: the catalogue is
## built by a unit test with no renderer behind it, and a [code]preload[/code]
## here would drag two meshes and their textures into every one of those runs.
var model: String

## How far [member model] has to be turned, in degrees, before it is the way up
## the game holds it. [code]Vector3.ZERO[/code] for a mesh that already is, which
## is every model on the belt today.
##
## [b]An artist's frame is not the game's, and only one of them can be wrong
## here.[/b] [ToolModel] fits a mesh axis by axis into [member extent], so a model
## has to arrive with its long axis on [code]+Y[/code] and the end it emits from
## at the top — which is where the [CylinderMesh] it replaces put them, and where
## [ViewModel] hangs the [code]Muzzle[/code] marker. A download that was authored
## Z-up arrives lying on its side, or end over end, and fitted as it comes it
## sprays out of its own hose end. That is not hypothetical: the power wash was a
## Sketchfab flamethrower until [code]#162[/code] and this row is what stood it
## the right way up.
##
## [b]A row here rather than an edit to the file or a branch in [ToolModel].[/b]
## A borrowed model is kept byte for byte — the licence it arrives under is a
## reason and the diffability is another — and "which way up did this artist model
## it" is a fact about one asset, which is what this table is for. [ToolModel]
## applies it before it measures the box, so [member extent] goes on describing
## the tool the player actually ends up holding.
##
## [b]Zero everywhere is not the same as unused.[/b] The wand that replaced the
## flamethrower is drawn by this project rather than downloaded
## ([code]scripts/build-pressure-washer.py[/code]), so it is authored the way up
## the game wants and asks for no turn — and the next borrowed model may well ask
## for one again. [code]tests/integration/test_tool_model.gd[/code] keeps this
## honest by turning that same wand on purpose and requiring it to come out
## upside down.
##
## [b]Right angles only.[/b] This is for righting a frame, not for posing a tool —
## posing is [method ViewModel._held_pose]'s, and a tool turned a few degrees here
## would be turned in the roll-up's box as well as in the hand. [ToolModel]
## measures the turned box off the unturned one, which is exact at multiples of
## 90° and slack at anything else, so an odd angle here would quietly fit the mesh
## into something smaller than [member extent] says.
var model_turn: Vector3


func _init(
	tool_id: Id,
	name_shown: String,
	proxy_shape: Shape,
	proxy_extent: Vector3,
	proxy_albedo: Color,
	proxy_metallic: float,
	proxy_roughness: float,
	proxy_model: String = "",
	proxy_model_turn: Vector3 = Vector3.ZERO
) -> void:
	id = tool_id
	display_name = name_shown
	shape = proxy_shape
	extent = proxy_extent
	albedo = proxy_albedo
	metallic = proxy_metallic
	roughness = proxy_roughness
	model = proxy_model
	model_turn = proxy_model_turn


## The five tools, in belt order.
##
## A function that builds them rather than a `const` array: a [Color] is fine in
## a constant but a [DetailingTool] is an object, and a single shared instance
## handed to every caller is a mutable global in a hat. Five allocations at
## startup is not a cost worth designing around.
static func catalogue() -> Array[DetailingTool]:
	var tools: Array[DetailingTool] = []
	# A wand: long, aimed, and the only metal on the belt. Modelled, and the one
	# model on the belt this project draws rather than borrows — see
	# [code]scripts/build-pressure-washer.py[/code], which is where the shape is
	# argued and where these three numbers are also written down.
	#
	# [b]The box and the mesh are the same box, which is the point.[/b] Every other
	# model arrives at its artist's scale and [ToolModel] fits it to whatever this
	# row says; this one is drawn at 42 x 550 x 60 mm, so the fit is the identity
	# and the centring is zero. That is not an optimisation — nothing about
	# [ToolModel] changes, and re-scaling the file would move nothing — it is so
	# that the one thing the model and this table have to agree about is a pair of
	# literals: the nozzle is the topmost point of the mesh, on its own axis, and
	# [member ViewModel.MUZZLE] is hung at [code](0, extent.y / 2, 0)[/code]. Those
	# two being the same point is what makes the water leave the nozzle.
	#
	# [b]It was not, and that was [code]#162[/code].[/b] The flamethrower this
	# replaced was 5.632 x 21.391 x 14.655 in its own units — a pipe with a gas
	# bottle strapped across it — and the bottle is what sized the box. Fitted, the
	# middle of its barrel's end face came out 46 mm off the box's axis in X and
	# 121 mm in Z, so the water left a point in mid-air 120 mm from the nozzle,
	# measured in the running game. No amount of tuning [WashJet] could have fixed
	# that: the marker was exactly where this table said, and the model was not.
	#
	# [b]And the scale is the hand's clearance budget rather than taste.[/b] This is
	# the one tool that stays in the hand and turns about it, so what it spends is
	# the corner of this box: it has to stay inside the 0.45 m a held thing may
	# reach and in front of the camera's 0.05 m near plane, at rest and at every
	# press the glass allows. Both are measured — in
	# [code]tests/integration/test_view_model.gd[/code] and
	# [code]tests/integration/test_play_screen_wand.gd[/code] — and both failed on
	# the way to the 0.55 m below rather than in theory. At the 0.72 m the original
	# barrel was, the corner reaches 0.495 m and comes to 0.03 m of the lens; at
	# 0.60 m the reach is fine and the lens is still only 0.037 m away. The length
	# is unchanged from the flamethrower's and the other two axes are a third and a
	# sixth of it, so a wand that already cleared both now clears them by more.
	tools.append(
		DetailingTool.new(
			Id.POWER_WASH,
			"Power Wash",
			Shape.CYLINDER,
			Vector3(0.042, 0.550, 0.060),
			Color(0.78, 0.80, 0.84),
			0.9,
			0.25,
			"res://assets/models/pressure_washer/pressure_washer.glb"
		)
	)
	# Stretched, as specified — a cube reads as a dice, and the thing that says
	# "sponge" is that it is wider than it is thick. Modelled since #155, and the
	# box is unchanged by that: it is what the roll-up draws, what [ReachCarry]
	# halves for the standoff, and the box the mesh is fitted into. The yellow is
	# the roll-up's, not the mesh's — see [member model].
	tools.append(
		DetailingTool.new(
			Id.SPONGE,
			"Sponge",
			Shape.BOX,
			Vector3(0.24, 0.10, 0.17),
			Color(0.93, 0.82, 0.16),
			0.0,
			0.95,
			"res://assets/models/sponge/sponge.glb"
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
	# A spray bottle, and the first tool on the belt that was given a modelled mesh
	# rather than a primitive. It is now the tyre cleaner's trigger sprayer with
	# its grey plastic recoloured — see
	# [code]scripts/build-window-cleaner.py[/code] — which makes this colour do a
	# second job: it is still the blue the roll-up draws the icon in, deliberately
	# a long way from the rag's, and it is now also the blue the bake paints the
	# bottle itself. One number, so the badge in the corner and the thing in the
	# hand cannot end up two shades apart, which is exactly what the class docs
	# above say the colour is here for.
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
	# A trigger sprayer, and one of the four tools on the belt whose art came from
	# outside the project — the window bottle above is this same mesh in a blue
	# livery, so the two of them are one download between them. See
	# [code]assets/models/cleaning_spray/ATTRIBUTION.txt[/code], and the sponge's and
	# the pressure washer's above it.
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
