## Integration test for [ToolModel] — the modelled mesh the two spray bottles are
## drawn as.
##
## Under tests/integration/ because a [ToolModel] is a node and because it loads
## a real asset: the whole class is about what comes out of
## [code]assets/models/[/code] and what shape it is once it has, neither of which
## a unit test with no resource server behind it could answer. That the bottles
## are then held, swapped and posed like every other tool is
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

## How square-on a vertex normal has to be to the triangle it belongs to.
##
## These meshes are flat shaded — measured on the source asset, every vertex
## normal agrees with its own face to within a millionth — so this is a tight
## fence rather than a generous one, and it is what makes the fit's
## inverse-transpose divide something a test can see. Measured with the divide
## taken out: the real fit falls to 0.93 and the lopsided fit below to 0.61,
## which is a bottle lit as though it were still the shape it was in Blender.
const SQUARE_ON: float = 0.999

## A fit nothing on the belt would ever ask for: a bottle stretched to a metre
## tall while it stays a tenth of a metre across. Here because the two real
## extents are only 2.6:1 and a normal carried through that unchanged is wrong by
## an amount a threshold could plausibly miss. Nothing about the fit treats it as
## a special case, which is the point of testing at it.
const LOPSIDED: Vector3 = Vector3(0.1, 1.0, 0.1)

## A path with nothing behind it, for the one test that asks what a missing model
## does. Under [code]assets/models/[/code] rather than somewhere obviously fake so
## that it is the same kind of path a typo in the catalogue would produce.
const NOWHERE: String = "res://assets/models/nothing_here.glb"


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
	var built: ToolModel = ToolModel.new(tool.model, extent)
	autofree(built)
	return built


## The worst agreement between a vertex normal and the triangle it sits on,
## across every triangle of [param mesh].
##
## The absolute dot product, because these bottles are exported double-sided and
## their winding is not consistent — half the faces have a normal pointing the
## other way down the same line, which says nothing about whether the fit turned
## it correctly. What is being measured is the angle between the normal and its
## own surface, and that is what the sign is being dropped from.
func _worst_normal(mesh: Mesh) -> float:
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var worst: float = 1.0
	for triangle: int in indices.size() / 3:
		var first: int = indices[triangle * 3]
		var second: int = indices[triangle * 3 + 1]
		var third: int = indices[triangle * 3 + 2]
		var across: Vector3 = vertices[second] - vertices[first]
		var down: Vector3 = vertices[third] - vertices[first]
		var face: Vector3 = across.cross(down)
		if face.is_zero_approx():
			continue
		face = face.normalized()
		for corner: int in [first, second, third]:
			worst = minf(worst, absf(face.dot(normals[corner].normalized())))
	return worst


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
	# [code].glb[/code] carries: both bottles are exported from a unit cylinder
	# scaled by the window cleaner's extent read as half-extents, so honouring that
	# would ship one bottle at twice its size and the other at the wrong one
	# entirely. Asked by fitting the same asset into a box nothing else would ask
	# for, and requiring it to land there.
	for tool: DetailingTool in _modelled():
		var box: AABB = _built(tool, LOPSIDED).get_aabb()
		assert_almost_eq(box.size.x, LOPSIDED.x, TOLERANCE, "%s: width" % tool.display_name)
		assert_almost_eq(box.size.y, LOPSIDED.y, TOLERANCE, "%s: height" % tool.display_name)


func test_two_tools_with_the_same_source_still_come_out_different_sizes() -> void:
	# Both bottles are the same mesh in two liveries, and the catalogue gives them
	# different extents on purpose — [method ViewModel._held_pose] leans them apart
	# so a glance at the corner of the screen tells them apart. A fit that took its
	# size from the file rather than from the catalogue would make them identical
	# and nothing else would notice.
	var window: DetailingTool = DetailingTool.catalogue()[DetailingTool.Id.WINDOW_CLEANER]
	var tire: DetailingTool = DetailingTool.catalogue()[DetailingTool.Id.TIRE_ENGINE_CLEANER]
	var window_box: AABB = _built(window, window.extent).get_aabb()
	var tire_box: AABB = _built(tire, tire.extent).get_aabb()
	assert_gt(tire_box.size.y, window_box.size.y, "the tyre bottle is the taller of the two")


# ---- what the model brings that a cylinder could not -------------------------


func test_the_models_own_texture_survives_the_fit() -> void:
	# The whole reason these are models. The fit rebuilds every surface vertex by
	# vertex, so the material has to be carried across by hand — and a fit that
	# dropped it would leave a correctly-sized white bottle, which looks enough
	# like a design decision to survive a review.
	for tool: DetailingTool in _modelled():
		var mesh: Mesh = _built(tool, tool.extent).mesh
		assert_not_null(mesh, "%s has no mesh at all" % tool.display_name)
		if mesh == null:
			continue
		var surface: StandardMaterial3D = mesh.surface_get_material(0) as StandardMaterial3D
		assert_not_null(surface, "%s: the import's material" % tool.display_name)
		if surface == null:
			continue
		assert_not_null(surface.albedo_texture, "%s: and its texture" % tool.display_name)


func test_the_two_bottles_do_not_share_one_texture() -> void:
	# They are the same geometry in two liveries, and the livery is the only thing
	# telling them apart at a glance once both are the same shape. Asserted because
	# the exported PNGs are both named after the window cleaner — see
	# [code]assets/models/cleaning_spray/[/code] — which is exactly the sort of
	# thing that quietly becomes one texture on the next re-export.
	var textures: Array[Texture2D] = []
	for tool: DetailingTool in _modelled():
		var surface: StandardMaterial3D = (
			_built(tool, tool.extent).mesh.surface_get_material(0) as StandardMaterial3D
		)
		assert_false(textures.has(surface.albedo_texture), "%s reuses a skin" % tool.display_name)
		textures.append(surface.albedo_texture)


# ---- the arithmetic the fit has to get right --------------------------------


func test_normals_still_stand_off_the_surface_they_belong_to() -> void:
	# A normal carried through a non-uniform scale unchanged no longer stands off
	# its own face, and what that looks like is a bottle lit as though it were the
	# shape it was in Blender. Measured against the triangles of the fitted mesh
	# rather than against the source, so it is the fit being asked and not the
	# exporter.
	for tool: DetailingTool in _modelled():
		var worst: float = _worst_normal(_built(tool, tool.extent).mesh)
		assert_gt(worst, SQUARE_ON, "%s: a normal has come off its face" % tool.display_name)


func test_normals_survive_a_fit_far_more_lopsided_than_any_tool_asks_for() -> void:
	# The same measurement where the error would be large. At the real extents a
	# normal left untransformed is wrong by about 20°, which is visible but is
	# within a threshold somebody might loosen; at this one it is wrong by 50° and
	# no plausible threshold hides it.
	for tool: DetailingTool in _modelled():
		var worst: float = _worst_normal(_built(tool, LOPSIDED).mesh)
		assert_gt(worst, SQUARE_ON, "%s: a normal has come off its face" % tool.display_name)


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
