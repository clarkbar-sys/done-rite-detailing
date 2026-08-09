## Integration test for [ToolModel] — the modelled mesh the two spray bottles,
## the sponge and the power wash are drawn as.
##
## Under tests/integration/ because a [ToolModel] is a node and because it loads
## a real asset: the whole class is about what comes out of
## [code]assets/models/[/code] and what shape it is once it has, neither of which
## a unit test with no resource server behind it could answer. That they are then
## held, swapped and posed like every other tool is
## [code]tests/integration/test_view_model.gd[/code]'s job, and is not repeated
## here.
##
## [b]What is asserted is the substitution[/b], exactly as it is for [ClothRag].
## A modelled tool has to be a drop-in for the primitive it replaces, because
## everything downstream — the roll-up icon, [ReachCarry]'s standoff, the nozzle
## marker, and every clearance the viewmodel measures — still reads the
## catalogue's [member DetailingTool.extent] and would go on describing a bottle
## that is no longer there. So: exactly that box, centred exactly where the
## cylinder was, whatever scale the export happened to be saved at.
extends GutTest

## A ten-thousandth of a metre, and the same tolerance
## [code]test_view_model.gd[/code] measures its sizes at.
const TOLERANCE: float = 0.0001

## How closely a fitted normal has to agree with the direction the fit's own
## arithmetic puts it — the inverse transpose of a diagonal fit, which is the
## component-wise divide [ToolModel] documents. A dot product, so this is about
## a hundredth of a degree, and what is left at that scale is float32 rounding:
## measured, the worst vertex on either bottle agrees to 0.9999998.
const TURNED: float = 0.9999

## And how far a normal that was [i]not[/i] turned has to be from that, which is
## what stops the test above from passing on a fit that copied the array across
## untouched.
##
## Asserted rather than assumed because it is not a given: it depends entirely on
## how lopsided the fit is, and both bottles' fits are nearly uniform. Measured,
## worst vertex, fit left out: 0.992 for the window bottle and 0.993 for the tyre
## bottle at their catalogue extents, and 0.814 for both at [constant LOPSIDED] —
## one number twice, because the two bottles are one mesh and that extent is one
## box. Those first two are the thin margin this constant sits inside, and the
## reason the same measurement is made at both extents.
const UNTURNED_MAX: float = 0.999

## A fit nothing on the belt would ever ask for: a bottle stretched to a metre
## tall while it stays a tenth of a metre across. Here because the two real
## extents are only 2.6:1 and a normal carried through that unchanged is wrong by
## an amount a threshold could plausibly miss. Nothing about the fit treats it as
## a special case, which is the point of testing at it.
const LOPSIDED: Vector3 = Vector3(0.1, 1.0, 0.1)

## How far apart a fit's three factors have to be before "what would leaving the
## normals alone cost" is a question with an answer.
##
## A ratio of the largest to the smallest, and 1.01 is a long way from every fit
## on the belt: the window bottle's is 1.29, the tyre bottle's 1.26, and the
## pressure washer's is exactly 1 — that wand is drawn at the size the catalogue
## holds it (see [code]scripts/build-pressure-washer.py[/code]), so its fit is the
## identity and there is nothing left for a reciprocal to do. So this separates a
## fit that is uniform by design from every fit that is merely gentle, and it does
## not sit near enough to either to be tuning.
const LOPSIDED_ENOUGH: float = 1.01

## The most triangles a modelled tool may arrive on the belt with.
##
## Ten thousand, and it is a size on disk rather than a frame budget. Measured on
## the pinned Godot, importing the same [code].glb[/code] with the sidecar's mesh
## switches flipped: this project's import settings turn a triangle into about
## 28.5 bytes of [code].scn[/code] once the LOD chain and the shadow mesh are
## counted — and both of those shrink with the source, which is why the triangle
## count is the only lever worth pulling. So this is roughly "an imported model
## may not cost more than 0.29 MB". What the belt actually carries: 8,496
## triangles for each bottle, 348 for the pressure washer, 276 for the sponge.
##
## [b]It guards a re-bake, not a refactor.[/b] The two bottles were 68,096
## triangles each — 1.94 MB of [code].scn[/code] apiece, 3.9 MB of the exported
## [code].pck[/code] for two props held in the corner of the frame — until
## [code]scripts/build-tire-cleaner.py[/code] grew a mesh simplifier. A bake that
## quietly stopped simplifying would put every byte of that back, and nothing
## else in this suite would notice: the box, the centre, the materials and the
## normals all come out identical either way.
const TRIANGLE_CEILING: int = 10000

## How far off its own axis the top face of a bottle may sit, in metres.
##
## [code]#189[/code] measured this when it moved the water to the end of the
## wand: the [code]Muzzle[/code] marker is at the top of the catalogue's box on
## the box's own axis, and both bottles' top faces sat 9 mm from it — "a bottle
## cap, not a 120 mm miss", which is why [SprayMist] was left alone. That 9 mm is
## the shoulder of a moulded cap and it is a fact about the asset, so this is it
## with half again for room: measured on the bottles the bake writes today, 9.2
## mm for the tyre cleaner and 9.2 mm for the window cleaner, against 9.2 mm and
## 8.9 mm for the full-resolution meshes they replaced.
##
## Here rather than in [code]test_play_screen_jet.gd[/code] because it is a
## property of the model: a simplifier is free to notice that a cap is nearly
## flat and spend its triangles elsewhere, and the first thing that would say so
## is the product leaving the bottle beside its own nozzle.
const CAP_OFF_AXIS: float = 0.015

## How wide the top of a bottle may be, in metres. A trigger sprayer's cap is
## 25 x 30 mm on this model and the shoulder below it is the full 100 mm of the
## body, so this separates "the cap survived" from "the cap was collapsed into
## the shoulder" without sitting near either.
const CAP_WIDE: float = 0.05

## How out of step with its own surface a single triangle's texturing may be —
## see [method _thinnest_texturing] for what the ratio is.
##
## A hundredth, which is where the artist put it: measured on the full-resolution
## download the bottles are baked from, its own worst triangle is at 0.0094, on
## the trigger. So this is not a tolerance chosen to let the current bake through
## — it is the floor the source itself sits on, and the bake clears it by nearly
## five times over at 0.048.
##
## What it catches is the one thing a mesh simplifier can do to this asset that
## no measurement of its size or its shape would notice. Both bottles are one
## printed label and five moulded parts wrapped in 256 px maps, and a collapse
## that pulled two corners of a triangle onto a straight line in UV space would
## smear a stripe of that label across the plastic while leaving the silhouette,
## the box and the triangle count all exactly as expected.
const UV_THINNEST: float = 0.01

## A path with nothing behind it, for the one test that asks what a missing model
## does. Under [code]assets/models/[/code] rather than somewhere obviously fake so
## that it is the same kind of path a typo in the catalogue would produce.
const NOWHERE: String = "res://assets/models/nothing_here.glb"

## How much thicker one end of the wand has to be than the other before the two
## can be told apart by measurement rather than by eye. Twice over, against a real
## 9.6 — a margin, and deliberately not a threshold anybody has to tune: the ends
## of this model are the 12 mm nozzle the water leaves and the 36 mm hose swivel
## it arrives through, and nothing between them is close.
const BLUNTER: float = 2.0

## How wide the top of the wand may be, in metres, and still be the thing water
## comes out of. [constant WashJet.NOZZLE] is the hole the droplets are born in
## and it is a centimetre of radius, so this is that doubled into a diameter with
## a little over: a nozzle, and not the shoulder of a bottle or the flat of a
## strap that happens to sit square on the axis.
const NOZZLE_WIDE: float = 0.025

## How thin a slice off the top of a mesh counts as its end face, in metres. A
## millimetre: thick enough to take a whole ring of a round nozzle rather than the
## one vertex that happens to be highest, and thinner than anything that could
## widen the slice into the taper below it.
const END_FACE: float = 0.001

## What counts as "the end" of a fitted tool when its two ends are being compared:
## the tenth of its length nearest each. Small enough that the wand's grip and its
## trigger are in neither — they are what a hand is on, and both are wider than
## the nozzle — and large enough to take a whole ring of a round part rather than
## the one vertex that happens to be furthest along.
const AN_END: float = 0.1


## Every tool in the catalogue that names a model. Read off the catalogue rather
## than listed here, so the third bottle is covered by these tests on the day it
## is added rather than on the day somebody remembers this file.
func _modelled() -> Array[DetailingTool]:
	var modelled: Array[DetailingTool] = []
	for tool: DetailingTool in DetailingTool.catalogue():
		if not tool.model.is_empty():
			modelled.append(tool)
	return modelled


func _built(tool: DetailingTool, extent: Vector3) -> ToolModel:
	var built: ToolModel = ToolModel.new(tool.model, extent, tool.model_turn)
	autofree(built)
	return built


## The turn [param tool] asks for, as the [Basis] [ToolModel] will build from it.
## Zero for every tool on the belt today, which is the identity — so every
## measurement below reads the same as it did before turns existed, and goes on
## reading correctly for the next borrowed model that has to be righted.
func _turn_of(tool: DetailingTool) -> Basis:
	return Basis.from_euler(tool.model_turn * (PI / 180.0))


## The mesh inside [param model_path]'s imported scene.
##
## Loaded here rather than borrowed from [ToolModel], on purpose: what the
## normal tests below measure is the arithmetic that class does to this array, so
## a test that read the array back through it would be grading the fit against
## itself.
##
## Depth first, and that is not tidiness. Every asset here is written by this
## project as one mesh at the root of its file, so today the mesh is one node
## under the imported scene — but the pressure washer was a Sketchfab download
## until [code]#162[/code] and its mesh was two nodes down, under the wrapper the
## exporter writes as well. A search of the root's own children found nothing
## there and handed every test below a null to measure, and the next download will
## arrive the same way.
func _source_mesh(model_path: String) -> Mesh:
	var scene: Node = (load(model_path) as PackedScene).instantiate()
	autofree(scene)
	return _mesh_under(scene)


## The first mesh at or under [param node], depth first.
func _mesh_under(node: Node) -> Mesh:
	var here: MeshInstance3D = node as MeshInstance3D
	if here != null and here.mesh != null:
		return here.mesh
	for child: Node in node.get_children():
		var found: Mesh = _mesh_under(child)
		if found != null:
			return found
	return null


## The fit [ToolModel] will use for [param tool] at [param extent] — its
## documented contract, which is the catalogue's box over the source mesh's own,
## measured after whatever turn the tool asks for.
func _fit_of(tool: DetailingTool, extent: Vector3) -> Vector3:
	var turned: AABB = (
		Transform3D(_turn_of(tool), Vector3.ZERO) * _source_mesh(tool.model).get_aabb()
	)
	return extent / turned.size


## The worst agreement, over every vertex of every surface, between the normal
## [param fitted] ended up with and the source normal righted by [param turn] and
## then turned by [param by].
##
## Pass the reciprocal of the fit and this measures whether the fit turned its
## normals correctly; pass [constant Vector3.ONE] and it measures how wrong
## leaving them alone would have been. A signed dot product, because a turn is
## what is being checked and a normal that came out backwards is not a pass.
##
## [param turn] is the model's own righting and is applied either way, because it
## is not the arithmetic under test: a rigid turn of both sides of a dot product
## changes nothing about what the fit did, and leaving it off the right-hand side
## would report every normal on a turned model as 180° wrong.
func _worst_turned(fitted: Mesh, source: Mesh, turn: Basis, by: Vector3) -> float:
	var worst: float = 1.0
	for surface: int in source.get_surface_count():
		var was: Array = source.surface_get_arrays(surface)
		var now: Array = fitted.surface_get_arrays(surface)
		var before: PackedVector3Array = was[Mesh.ARRAY_NORMAL]
		var after: PackedVector3Array = now[Mesh.ARRAY_NORMAL]
		for at: int in before.size():
			worst = minf(worst, after[at].dot((turn * before[at] * by).normalized()))
	return worst


## The area of the cross-section [param mesh] has at one end of its long axis, in
## square metres: the [code]+Y[/code] end for [param at_top] and the
## [code]-Y[/code] end otherwise.
##
## The [code]x[/code] by [code]z[/code] box around every vertex in the outer
## [constant AN_END] of the mesh's own height, which is how a pipe is told from a
## flat: it is the measurement that says which end of a tool is its nozzle without
## anybody writing down which way the artist happened to work.
func _cross_section(mesh: Mesh, at_top: bool) -> float:
	var box: AABB = mesh.get_aabb()
	var deep: float = box.size.y * AN_END
	var from: float = box.end.y - deep if at_top else box.position.y
	var to: float = box.end.y if at_top else box.position.y + deep
	var across: AABB = AABB()
	var found: bool = false
	for surface: int in mesh.get_surface_count():
		var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex: Vector3 in vertices:
			if vertex.y < from or vertex.y > to:
				continue
			across = across.expand(vertex) if found else AABB(vertex, Vector3.ZERO)
			found = true
	return across.size.x * across.size.z


## How many triangles [param mesh] draws, over every surface it has.
func _triangles(mesh: Mesh) -> int:
	var drawn: int = 0
	for surface: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		@warning_ignore("integer_division")
		drawn += indices.size() / 3
	return drawn


## The two bottles, which are the only tools a mesh simplifier has ever touched.
func _bottles() -> Array[DetailingTool]:
	var catalogue: Array[DetailingTool] = DetailingTool.catalogue()
	return [
		catalogue[DetailingTool.Id.WINDOW_CLEANER],
		catalogue[DetailingTool.Id.TIRE_ENGINE_CLEANER],
	]


## The smallest patch of texture any one triangle of [param mesh] is drawn from,
## as a share of the patch that triangle would get at the surface's own average
## density — so 1.0 is a triangle mapped exactly as evenly as its surface is, and
## 0.0 is one whose three corners landed on a straight line in the texture.
##
## Scale free on purpose. The six parts of a bottle are mapped at wildly
## different densities — the nozzle spreads about 640 UV units² over a square
## metre where the body spreads 11 — so an absolute floor would be six different
## amounts of nothing, and the only question worth asking is whether a triangle
## is out of step with the surface it belongs to.
func _thinnest_texturing(mesh: Mesh) -> float:
	var thinnest: float = 1.0
	for surface: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var densities: PackedFloat32Array = PackedFloat32Array()
		var total: float = 0.0
		for at: int in range(0, indices.size(), 3):
			var first: int = indices[at]
			var second: int = indices[at + 1]
			var third: int = indices[at + 2]
			var area: float = (
				(points[second] - points[first]).cross(points[third] - points[first]).length()
			)
			if area <= 0.0:
				continue
			var mapped: float = absf((uvs[second] - uvs[first]).cross(uvs[third] - uvs[first]))
			densities.append(mapped / area)
			total += mapped / area
		if densities.is_empty():
			continue
		var average: float = total / densities.size()
		for density: float in densities:
			thinnest = minf(thinnest, density / average)
	return thinnest


## The box around the topmost [constant END_FACE] of [param mesh] — the face the
## water leaves, for a tool whose business end is at [code]+Y[/code].
##
## Its own box rather than the mesh's, because what is being asked is where that
## face sits across the wand and how wide it is, and both are answers about those
## vertices alone.
func _nozzle_face(mesh: Mesh) -> AABB:
	var top: float = mesh.get_aabb().end.y - END_FACE
	var face: AABB = AABB()
	var found: bool = false
	for surface: int in mesh.get_surface_count():
		var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex: Vector3 in vertices:
			if vertex.y < top:
				continue
			face = face.expand(vertex) if found else AABB(vertex, Vector3.ZERO)
			found = true
	return face


# ---- the drop-in ------------------------------------------------------------


func test_the_belt_carries_at_least_one_modelled_tool() -> void:
	# Everything below iterates the catalogue, so an empty list would make this
	# whole suite pass by testing nothing at all.
	assert_gt(_modelled().size(), 0, "no tool names a model — these tests would be vacuous")


func test_a_model_fills_exactly_the_box_the_catalogue_gives_it() -> void:
	# The substitution, said as plainly as it can be said: the mesh occupies the
	# extent the primitive occupied, on all three axes.
	for tool: DetailingTool in _modelled():
		var box: AABB = _built(tool, tool.extent).get_aabb()
		assert_almost_eq(box.size.x, tool.extent.x, TOLERANCE, "%s: width" % tool.display_name)
		assert_almost_eq(box.size.y, tool.extent.y, TOLERANCE, "%s: height" % tool.display_name)
		assert_almost_eq(box.size.z, tool.extent.z, TOLERANCE, "%s: depth" % tool.display_name)


func test_a_model_is_centred_where_the_cylinder_was() -> void:
	# A [CylinderMesh] straddles its own origin, and the poses in
	# [method ViewModel._held_pose] grip a tool along that origin's own axis. A
	# mesh that filled the right box but sat off to one side of it would be a
	# bottle held by the air beside it.
	for tool: DetailingTool in _modelled():
		var centre: Vector3 = _built(tool, tool.extent).get_aabb().get_center()
		assert_almost_eq(centre.length(), 0.0, TOLERANCE, "%s is off-centre" % tool.display_name)


func test_the_fit_ignores_whatever_scale_the_export_was_saved_at() -> void:
	# The reason the fit reads the mesh's own box instead of the node scale the
	# [code].glb[/code] carries: the bottles are real 27 cm sprayers in real
	# metres, the sponge is a real 16 cm sponge, and the wand is drawn at the exact
	# size the catalogue hands it — three different relationships between a file
	# and a tool, and the fit is not allowed to care which it is looking at. Asked
	# by fitting each asset into a box nothing else would ask for, and requiring it
	# to land there. The wand is the one that would notice a class that had started
	# quietly trusting the file, because it is the one the file happens to agree
	# with at its own extent.
	for tool: DetailingTool in _modelled():
		var box: AABB = _built(tool, LOPSIDED).get_aabb()
		assert_almost_eq(box.size.x, LOPSIDED.x, TOLERANCE, "%s: width" % tool.display_name)
		assert_almost_eq(box.size.y, LOPSIDED.y, TOLERANCE, "%s: height" % tool.display_name)


func test_the_catalogue_and_not_the_file_is_what_makes_the_bottles_different_sizes() -> void:
	# The catalogue gives the two bottles different extents on purpose — [method
	# ViewModel._held_pose] leans them apart so a glance at the corner of the
	# screen tells them apart — and the files they are drawn from say nothing
	# about that. Since [code]scripts/build-window-cleaner.py[/code] made the
	# window bottle out of the tyre one, the files cannot say anything about it:
	# they are the same geometry in two liveries, down to the millimetre. So the
	# source boxes are asserted equal and the fitted ones are asserted different,
	# which is the whole claim of this test with nothing left to infer.
	var window: DetailingTool = DetailingTool.catalogue()[DetailingTool.Id.WINDOW_CLEANER]
	var tire: DetailingTool = DetailingTool.catalogue()[DetailingTool.Id.TIRE_ENGINE_CLEANER]
	var window_source: Vector3 = _source_mesh(window.model).get_aabb().size
	var tire_source: Vector3 = _source_mesh(tire.model).get_aabb().size
	assert_almost_eq(window_source.y, tire_source.y, TOLERANCE, "the two files disagree on height")
	var window_box: AABB = _built(window, window.extent).get_aabb()
	var tire_box: AABB = _built(tire, tire.extent).get_aabb()
	assert_gt(tire_box.size.y, window_box.size.y, "the tyre bottle is the taller of the two")
	assert_lt(tire_box.size.y, 0.5, "and neither of them is furniture")


func test_a_model_made_of_several_parts_arrives_with_all_of_them() -> void:
	# The tyre bottle is six modelled parts — body, neck, nozzle, two caps and a
	# trigger — flattened into one mesh of six surfaces by
	# [code]scripts/build-tire-cleaner.py[/code], because [method
	# ToolModel._first_mesh] takes one mesh and would otherwise hand the player a
	# bottle with no trigger on it. Both halves of that are asserted here: the
	# bake keeps the parts in one mesh, and the fit keeps every one of them.
	for tool: DetailingTool in _modelled():
		var source: Mesh = _source_mesh(tool.model)
		var fitted: Mesh = _built(tool, tool.extent).mesh
		assert_gt(source.get_surface_count(), 0, "%s: the import found no surface" % tool.model)
		assert_eq(
			fitted.get_surface_count(),
			source.get_surface_count(),
			"%s: the fit dropped a part of the model" % tool.display_name
		)


# ---- which way up the model arrives -----------------------------------------


func test_the_wand_is_thinnest_at_the_end_the_water_leaves() -> void:
	# The bug this pins was reported as "the washer is shooting out the opposite
	# end", and it was: the download the wand used to be drawn from was authored
	# Z-up with its barrel at the mesh's own [code]-Y[/code], [ToolModel] never
	# looks at the node that would say so, and the nozzle marker [ViewModel] hangs
	# off the wand is at [code]+Y[/code] whatever arrives there. So the jet left
	# the hose end.
	#
	# Measured as a shape rather than as a rotation, because "the nozzle is at the
	# top" is the thing that has to be true and how the asset gets that way — a
	# turn in the catalogue then, the way it is drawn now — is only how it is
	# currently spelled. A wand is a pipe: the tenth of it nearest the muzzle is a
	# thin round section, and the tenth nearest the butt is the wide hose swivel.
	# Measured, at the catalogue extent: 0.000135 m² at the muzzle against
	# 0.001296 m² at the butt, nine times over, so [constant BLUNTER] is nowhere
	# near either.
	var wand: DetailingTool = DetailingTool.catalogue()[DetailingTool.Id.POWER_WASH]
	var mesh: Mesh = _built(wand, wand.extent).mesh
	assert_lt(
		_cross_section(mesh, true) * BLUNTER,
		_cross_section(mesh, false),
		"the wand's muzzle end is not the thin one — it is fitted upside down"
	)


func test_the_same_wand_turned_end_over_end_is_upside_down() -> void:
	# What keeps the test above from passing on a model that happens to be roughly
	# symmetrical end to end, and what keeps [member DetailingTool.model_turn]
	# honest now that no tool on the belt asks for one: build the same asset with a
	# half-turn nobody wants and the thin end has to arrive at the bottom. So the
	# turn is applied, it is applied about the axis it says, and the wand really
	# does have two distinguishable ends.
	#
	# The turn the flamethrower used to carry, and not an arbitrary one, because
	# that is the case the row exists for: the next borrowed model that arrives
	# lying the wrong way up is righted by putting it back.
	var wand: DetailingTool = DetailingTool.catalogue()[DetailingTool.Id.POWER_WASH]
	var over: ToolModel = ToolModel.new(wand.model, wand.extent, Vector3(0.0, 0.0, 180.0))
	autofree(over)
	assert_lt(
		_cross_section(over.mesh, false) * BLUNTER,
		_cross_section(over.mesh, true),
		"a half-turn left the wand the same way up, so the turn did nothing"
	)


func test_the_water_leaves_the_wand_where_the_nozzle_marker_is() -> void:
	# Issue #162, and the half of it no test could have caught: the water was
	# leaving a point 12 cm from the end of the nozzle, and every assertion about
	# the jet passed the whole time. [ViewModel] hangs the [code]Muzzle[/code]
	# marker at [method ToolCarry.nozzle] — the top of the catalogue's box, on the
	# box's own axis — and [ToolSight] fires [WashJet] from there, so what the
	# marker means is "the model's business end is here". The flamethrower's was
	# not: its box was sized by the gas bottle strapped across it, which put the
	# barrel's end face 46 mm off the axis in X and 121 mm in Z.
	#
	# So this is the property the marker rests on, asserted where it can be
	# measured: the topmost slice of the fitted mesh is a nozzle-sized face and it
	# is centred on the box's own axis. Measured on the wand this project draws:
	# 11.6 mm across and centred to a ten-thousandth.
	var wand: DetailingTool = DetailingTool.catalogue()[DetailingTool.Id.POWER_WASH]
	var mesh: Mesh = _built(wand, wand.extent).mesh
	var face: AABB = _nozzle_face(mesh)
	assert_almost_eq(face.get_center().x, 0.0, TOLERANCE, "the nozzle is off the wand's axis in x")
	assert_almost_eq(face.get_center().z, 0.0, TOLERANCE, "the nozzle is off the wand's axis in z")
	# And it is a nozzle rather than the flat top of something else that happens
	# to be centred: a hole the water can plausibly have come out of, which is
	# [constant WashJet.NOZZLE]'s centimetre with room to spare.
	assert_lt(maxf(face.size.x, face.size.z), NOZZLE_WIDE, "the top of the wand is not a nozzle")


func test_a_turn_leaves_the_box_and_the_centre_exactly_where_they_were() -> void:
	# The turn is applied before the box is measured — see [method
	# ToolModel._fitted] — precisely so that it cannot move the tool: the catalogue
	# extent has the hand's whole clearance budget in it (see [method
	# DetailingTool.catalogue]) and a model that grew or wandered when somebody
	# righted it would spend that budget silently. Asserted against a quarter turn
	# as well as the half-turn and the none, because a half-turn about Z leaves a
	# box the same size by symmetry and would prove very little on its own.
	var wand: DetailingTool = DetailingTool.catalogue()[DetailingTool.Id.POWER_WASH]
	for turn: Vector3 in [wand.model_turn, Vector3(0.0, 0.0, 180.0), Vector3(90.0, 0.0, 0.0)]:
		var built: ToolModel = ToolModel.new(wand.model, wand.extent, turn)
		autofree(built)
		var box: AABB = built.get_aabb()
		assert_almost_eq(box.size.x, wand.extent.x, TOLERANCE, "turned %v: width" % turn)
		assert_almost_eq(box.size.y, wand.extent.y, TOLERANCE, "turned %v: height" % turn)
		assert_almost_eq(box.size.z, wand.extent.z, TOLERANCE, "turned %v: depth" % turn)
		assert_almost_eq(box.get_center().length(), 0.0, TOLERANCE, "turned %v: centre" % turn)


# ---- what the model brings that a cylinder could not -------------------------


func test_the_models_own_textures_survive_the_fit() -> void:
	# The whole reason these are models. The fit rebuilds every surface vertex by
	# vertex, so the material has to be carried across by hand — and a fit that
	# dropped it would leave a correctly-sized white bottle, which looks enough
	# like a design decision to survive a review. Every surface and not just the
	# first: the tyre bottle wears six materials, and five of them going missing
	# is the same bug wearing a smaller hat.
	for tool: DetailingTool in _modelled():
		var mesh: Mesh = _built(tool, tool.extent).mesh
		assert_not_null(mesh, "%s has no mesh at all" % tool.display_name)
		if mesh == null:
			continue
		for at: int in mesh.get_surface_count():
			var surface: StandardMaterial3D = mesh.surface_get_material(at) as StandardMaterial3D
			assert_not_null(surface, "%s: the import's material %d" % [tool.display_name, at])
			if surface == null:
				continue
			assert_not_null(surface.albedo_texture, "%s: and texture %d" % [tool.display_name, at])


func test_no_two_modelled_tools_share_one_texture() -> void:
	# Two tools that came out of the same tin of paint are one tool as far as a
	# glance at the corner of the screen is concerned — which is the whole of what
	# separates the two bottles now that they are one mesh in two liveries. So this
	# is no longer a guard against history repeating: it is the assertion the
	# window bottle's blue rests on. Surface 0 and not all six on purpose, and the
	# bake is why: [code]scripts/build-window-cleaner.py[/code] recolours the body
	# and copies the caps, the neck, the nozzle and the trigger across byte for
	# byte, so five of the six really are the same tin and the body is the one that
	# must not be. Each of these is also extracted beside its [code].glb[/code] as
	# a PNG named after it, and a re-bake that renamed one onto another's file
	# would be silent everywhere else.
	var textures: Array[Texture2D] = []
	for tool: DetailingTool in _modelled():
		var surface: StandardMaterial3D = (
			_built(tool, tool.extent).mesh.surface_get_material(0) as StandardMaterial3D
		)
		assert_false(textures.has(surface.albedo_texture), "%s reuses a skin" % tool.display_name)
		textures.append(surface.albedo_texture)


# ---- what a model is allowed to cost, and what it may not spend to get there -


func test_no_modelled_tool_brings_more_triangles_than_the_belt_can_afford() -> void:
	# The load-time guard. See [constant TRIANGLE_CEILING]: an imported mesh costs
	# about 28.5 bytes a triangle in the exported [code].pck[/code], the two
	# bottles were 68,096 triangles apiece, and that was 3.9 MB of the download
	# spent on two props that occupy a corner of the frame. Asserted here because
	# this is the file that already loads every modelled asset, and because
	# nothing else in the suite would fail on a bake that stopped simplifying.
	#
	# Every modelled tool and not just the bottles: the ceiling is what a tool on
	# this belt is worth, and the next borrowed model arrives with whatever the
	# artist happened to save.
	for tool: DetailingTool in _modelled():
		var triangles: int = _triangles(_built(tool, tool.extent).mesh)
		assert_gt(triangles, 0, "%s: the fit drew no triangles at all" % tool.display_name)
		assert_lt(
			triangles,
			TRIANGLE_CEILING,
			"%s: %d triangles — has the bake stopped simplifying?" % [tool.display_name, triangles]
		)


func test_the_top_of_each_bottle_is_still_the_cap_the_marker_stands_on() -> void:
	# What [code]#189[/code] left behind. [ViewModel] hangs the [code]Muzzle[/code]
	# marker at the top of the catalogue's box on the box's own axis and [ToolSight]
	# sprays from it, so "the product leaves the can where the can is" is a claim
	# about where the top of the mesh is — and that issue measured it at 9 mm for
	# both bottles and left [SprayMist] alone on the strength of it.
	#
	# A simplifier is exactly the thing that could quietly spend that: a cap is a
	# nearly-flat disc and the cheapest triangles on the whole bottle to collapse.
	# So the same measurement, pinned. Measured on the bake this repository ships:
	# 9.2 mm off the axis for both, against 9.2 mm and 8.9 mm for the
	# full-resolution meshes they replaced.
	for tool: DetailingTool in _bottles():
		var face: AABB = _nozzle_face(_built(tool, tool.extent).mesh)
		var centre: Vector3 = face.get_center()
		assert_lt(
			Vector2(centre.x, centre.z).length(),
			CAP_OFF_AXIS,
			"%s: the top of the bottle has wandered off the marker" % tool.display_name
		)
		# And it is still a cap rather than the shoulder the cap used to sit on.
		assert_lt(
			maxf(face.size.x, face.size.z),
			CAP_WIDE,
			"%s: the top of the bottle is no longer cap-sized" % tool.display_name
		)


func test_no_triangle_on_a_bottle_has_had_its_texturing_pulled_flat() -> void:
	# The guard on the one cost a mesh simplifier can pay in the texture rather
	# than in the geometry — see [constant UV_THINNEST]. Asked of the imported
	# asset rather than of the fitted proxy on purpose: the fit is a non-uniform
	# scale, so it changes each triangle's area by an amount that depends on which
	# way the triangle faces, and the property under test is a fact about the
	# [code].glb[/code].
	#
	# The two bottles and not every modelled tool, because they are the only
	# assets in this project that a simplifier has ever run over: the wand and the
	# sponge are written out triangle by triangle by their own build scripts.
	for tool: DetailingTool in _bottles():
		assert_gt(
			_thinnest_texturing(_source_mesh(tool.model)),
			UV_THINNEST,
			"%s: a triangle samples the texture along a line" % tool.display_name
		)


# ---- the arithmetic the fit has to get right --------------------------------


func test_normals_are_turned_by_the_inverse_of_the_fit() -> void:
	# A normal carried through a non-uniform scale unchanged no longer stands off
	# the surface it belongs to, and what that looks like is a bottle lit as though
	# it were still the shape it was in Blender.
	#
	# Measured against where the fit's own arithmetic puts each normal rather than
	# against the face it sits on, and that is a deliberate change: the tyre
	# bottle is smooth shaded, so its normals are not square-on to their own
	# triangles in the source either and "square-on to the face" stopped being a
	# statement about the fit. Turning each source normal by the reciprocal of the
	# fit says the same thing about flat and smooth shading alike.
	for tool: DetailingTool in _modelled():
		var source: Mesh = _source_mesh(tool.model)
		var fitted: Mesh = _built(tool, tool.extent).mesh
		var by: Vector3 = Vector3.ONE / _fit_of(tool, tool.extent)
		var worst: float = _worst_turned(fitted, source, _turn_of(tool), by)
		assert_gt(worst, TURNED, "%s: a normal is not where the fit puts it" % tool.display_name)


func test_normals_survive_a_fit_far_more_lopsided_than_any_tool_asks_for() -> void:
	# The same measurement where the error would be large. The tyre bottle's real
	# fit is nearly uniform — 1.08, 1.12, 1.37 — so a normal left alone is only
	# about 7° out there, which is a small enough error to hide behind a threshold
	# somebody nudges; at this fit it is 35° out and nothing hides it.
	for tool: DetailingTool in _modelled():
		var source: Mesh = _source_mesh(tool.model)
		var fitted: Mesh = _built(tool, LOPSIDED).mesh
		var by: Vector3 = Vector3.ONE / _fit_of(tool, LOPSIDED)
		var worst: float = _worst_turned(fitted, source, _turn_of(tool), by)
		assert_gt(worst, TURNED, "%s: a normal is not where the fit puts it" % tool.display_name)


func test_a_fit_that_left_the_normals_alone_would_fail_the_two_tests_above() -> void:
	# What keeps those two honest. They compare the fitted normals against a
	# turn computed here, and if that turn were close enough to no turn at all
	# they would both pass over a class that copied the array across untouched —
	# which is the exact bug they exist for. So: measure the same worst vertex
	# against the untouched normal, and require it to miss.
	#
	# [b]Except where the fit really is uniform, which is not a loophole.[/b] The
	# power wash's catalogue extent is its mesh's own box — the wand is drawn at
	# the size the game holds it, see [method DetailingTool.catalogue] — so its
	# three fit factors are exactly 1, and a normal turned by the reciprocal of
	# that [i]is[/i] the normal left alone. There is nothing to prove at that
	# extent and no bug that could hide there.
	# [constant LOPSIDED] still asks the question of every tool including that one,
	# and the count at the end is what stops "skip it" from quietly becoming
	# "skip them all".
	var proved: int = 0
	for tool: DetailingTool in _modelled():
		for extent: Vector3 in [tool.extent, LOPSIDED]:
			var fit: Vector3 = _fit_of(tool, extent)
			if maxf(fit.x, maxf(fit.y, fit.z)) / minf(fit.x, minf(fit.y, fit.z)) < LOPSIDED_ENOUGH:
				continue
			var fitted: Mesh = _built(tool, extent).mesh
			var worst: float = _worst_turned(
				fitted, _source_mesh(tool.model), _turn_of(tool), Vector3.ONE
			)
			assert_lt(
				worst,
				UNTURNED_MAX,
				(
					"%s at %v: the fit is too near uniform to prove anything"
					% [tool.display_name, extent]
				)
			)
			proved += 1
	assert_gt(proved, 0, "every fit was skipped, so this test proved nothing at all")


func test_a_model_that_is_not_there_is_an_empty_proxy_rather_than_a_broken_belt() -> void:
	# A missing asset is a tool you cannot see, which is noticed in the first
	# second of play. The alternative — a null mesh assigned into a belt that is
	# built in [method ViewModel._ready] — is the title screen never loading, and
	# it is worth the two lines to not have to tell those two apart from a bug
	# report.
	var missing: ToolModel = ToolModel.new(NOWHERE, Vector3.ONE)
	autofree(missing)
	assert_null(missing.mesh, "a model that is not there draws nothing")
	# The other half, and the reason it is asserted rather than ignored: silence
	# here would be a tool that is invisible for a reason nobody can find. The
	# loader says the file is missing and the class says which path asked for it,
	# and asserting both is also what tells GUT these two errors were the point of
	# the test rather than a fault in it.
	assert_engine_error_count(1, "the loader has to say the file is not there")
	assert_push_error(NOWHERE, "and the class has to say what it was looking for")
