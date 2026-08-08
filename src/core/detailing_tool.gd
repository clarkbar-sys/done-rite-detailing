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
## is every one of these but the power wash.
##
## [b]An artist's frame is not the game's, and only one of them can be wrong
## here.[/b] [ToolModel] fits a mesh axis by axis into [member extent], so a model
## has to arrive with its long axis on [code]+Y[/code] and the end it emits from
## at the top — which is where the [CylinderMesh] it replaces put them, and where
## [ViewModel] hangs the [code]Muzzle[/code] marker. Three of the four models on
## the belt were authored that way. The pressure washer was authored Z-up, with
## its barrel at the [code]-Y[/code] end of the mesh, so fitted as it arrives it
## sprays out of its own hose end.
##
## [b]A row here rather than an edit to the file or a branch in [ToolModel].[/b]
## The asset is a CC-BY download this project keeps byte for byte — see
## [code]assets/models/pressure_washer/ATTRIBUTION.txt[/code] — and "which way up
## did this artist model it" is a fact about one asset, which is what this table
## is for. [ToolModel] applies it before it measures the box, so [member extent]
## goes on describing the tool the player actually ends up holding.
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
	# A wand: long, aimed, and the only metal on the belt. Modelled now — see
	# [code]assets/models/pressure_washer/ATTRIBUTION.txt[/code] — and the model is
	# what all three numbers below come from.
	#
	# [b]All three, because the fit is per axis.[/b] [ToolModel] maps the mesh's own
	# box onto this one axis by axis, and the mesh is not a bare barrel: it is
	# 5.632 x 21.391 x 14.655 in its own units, a pipe with a gas bottle strapped
	# across it. The old 0.06 x 0.72 x 0.06 would have squashed that to a third of
	# its width and a twelfth of its depth. These three are the mesh's own box at
	# one scale, so the fit is uniform to a tenth of a per cent and the pipe stays
	# round.
	#
	# [b]And the scale is the hand's clearance budget rather than taste.[/b] This is
	# the one tool that stays in the hand and turns about it, so what it spends is
	# the corner of this box: it has to stay inside the 0.45 m a held thing may
	# reach and in front of the camera's 0.05 m near plane, at rest and at every
	# press the glass allows. Both are measured — in
	# [code]tests/integration/test_view_model.gd[/code] and
	# [code]tests/integration/test_play_screen_wand.gd[/code] — and both failed on
	# the way here rather than in theory. At the 0.72 m the barrel used to be, the
	# corner reaches 0.495 m and comes to 0.03 m of the lens; at 0.60 m the reach is
	# fine and the lens is still only 0.037 m away. At 0.55 m the corner is 0.391 m
	# out and clears the near plane by 0.068 m at rest and 0.072 m aimed.
	#
	# So the tool is a fifth shorter than the barrel it replaces and several times
	# bulkier, which is the trade this model is: a thin 6 cm tube could be long
	# because it was thin, and a pipe with a bottle across it cannot.
	#
	# [b]And it is turned end over end, because the artist's frame is not this
	# one.[/b] The download is authored Z-up — the wrapper node the exporter writes
	# carries the quarter turn that would say so, and [ToolModel] never looks at a
	# node — so in the mesh's own space the barrel is at [code]-Y[/code] and the
	# hose end is at [code]+Y[/code]. Fitted as it arrives, the wand sprays out of
	# the end nearest the hand: reported as "the washer is shooting out the opposite
	# end", which is exactly what it was doing. Half a turn about [code]Z[/code]
	# rather than about [code]X[/code], and that is the axis with the argument: both
	# put the barrel at the top, and only this one leaves the mesh's own up —
	# [code]+Z[/code], the side the barrel sits on above the bottle — pointing out
	# of the screen at the player once [method ViewModel._held_pose] has tipped the
	# wand away. About [code]X[/code] the player would be shown its underside.
	tools.append(
		DetailingTool.new(
			Id.POWER_WASH,
			"Power Wash",
			Shape.CYLINDER,
			Vector3(0.145, 0.550, 0.377),
			Color(0.78, 0.80, 0.84),
			0.9,
			0.25,
			"res://assets/models/pressure_washer/homemade_flamethrower.glb",
			Vector3(0.0, 0.0, 180.0)
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
	# rather than a primitive. The colour is what the roll-up draws it in and is
	# unchanged — the other blue on the belt, deliberately a long way from the
	# rag's.
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
	# A trigger sprayer, and one of the three tools on the belt whose art came from
	# outside the project — see
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
