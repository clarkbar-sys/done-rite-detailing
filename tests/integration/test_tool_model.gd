## Integration test for [ToolModel] — the modelled mesh the two spray bottles and
## the sponge are drawn as.
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
## how lopsided the fit is, and the tyre bottle's is nearly uniform. Measured,
## worst vertex, fit left out: 0.925 for the window bottle and 0.993 for the tyre
## bottle at their catalogue extents, 0.614 and 0.814 at [constant LOPSIDED]. The
## first of those is the thin margin this constant sits inside, and the reason
## the same measurement is made at both extents.
const UNTURNED_MAX: float = 0.999

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


## The mesh inside [param model_path]'s imported scene.
##
## Loaded here rather than borrowed from [ToolModel], on purpose: what the
## normal tests below measure is the arithmetic that class does to this array, so
## a test that read the array back through it would be grading the fit against
## itself.
func _source_mesh(model_path: String) -> Mesh:
	var scene: Node = (load(model_path) as PackedScene).instantiate()
	autofree(scene)
	for child: Node in scene.get_children():
		var found: MeshInstance3D = child as MeshInstance3D
		if found != null:
			return found.mesh
	return null


## The fit [ToolModel] will use for [param tool] at [param extent] — its
## documented contract, which is the catalogue's box over the source mesh's own.
func _fit_of(tool: DetailingTool, extent: Vector3) -> Vector3:
	return extent / _source_mesh(tool.model).get_aabb().size


## The worst agreement, over every vertex of every surface, between the normal
## [param fitted] ended up with and the source normal turned by [param by].
##
## Pass the reciprocal of the fit and this measures whether the fit turned its
## normals correctly; pass [constant Vector3.ONE] and it measures how wrong
## leaving them alone would have been. A signed dot product, because a turn is
## what is being checked and a normal that came out backwards is not a pass.
func _worst_turned(fitted: Mesh, source: Mesh, by: Vector3) -> float:
	var worst: float = 1.0
	for surface: int in source.get_surface_count():
		var was: Array = source.surface_get_arrays(surface)
		var now: Array = fitted.surface_get_arrays(surface)
		var before: PackedVector3Array = was[Mesh.ARRAY_NORMAL]
		var after: PackedVector3Array = now[Mesh.ARRAY_NORMAL]
		for at: int in before.size():
			worst = minf(worst, after[at].dot((before[at] * by).normalized()))
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
	# [code].glb[/code] carries: the window bottle is a unit cylinder with its
	# extent on the node as half-extents, so honouring that would ship it at twice
	# its size, and the tyre bottle is a real sprayer in real metres, which is a
	# third size again. Asked by fitting each asset into a box nothing else would
	# ask for, and requiring it to land there.
	for tool: DetailingTool in _modelled():
		var box: AABB = _built(tool, LOPSIDED).get_aabb()
		assert_almost_eq(box.size.x, LOPSIDED.x, TOLERANCE, "%s: width" % tool.display_name)
		assert_almost_eq(box.size.y, LOPSIDED.y, TOLERANCE, "%s: height" % tool.display_name)


func test_the_catalogue_and_not_the_file_is_what_makes_the_bottles_different_sizes() -> void:
	# The catalogue gives the two bottles different extents on purpose — [method
	# ViewModel._held_pose] leans them apart so a glance at the corner of the
	# screen tells them apart — and the files they are drawn from say nothing
	# about that. They are not even close to agreeing: the window bottle is a
	# 2 x 2.33 x 2 unit cylinder and the tyre bottle is a 27 cm sprayer in real
	# metres, so a fit that took its size from the file would put a bottle in the
	# player's hand that is taller than they are.
	var window: DetailingTool = DetailingTool.catalogue()[DetailingTool.Id.WINDOW_CLEANER]
	var tire: DetailingTool = DetailingTool.catalogue()[DetailingTool.Id.TIRE_ENGINE_CLEANER]
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
	# glance at the corner of the screen is concerned. Kept as a test after the
	# tyre bottle stopped being a re-skin of the window one, because what it
	# guards is not that history: every one of these is extracted beside its
	# [code].glb[/code] as a PNG named after it, and a re-export that renames one
	# onto another's file is silent everywhere else.
	var textures: Array[Texture2D] = []
	for tool: DetailingTool in _modelled():
		var surface: StandardMaterial3D = (
			_built(tool, tool.extent).mesh.surface_get_material(0) as StandardMaterial3D
		)
		assert_false(textures.has(surface.albedo_texture), "%s reuses a skin" % tool.display_name)
		textures.append(surface.albedo_texture)


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
		var worst: float = _worst_turned(fitted, source, by)
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
		var worst: float = _worst_turned(fitted, source, by)
		assert_gt(worst, TURNED, "%s: a normal is not where the fit puts it" % tool.display_name)


func test_a_fit_that_left_the_normals_alone_would_fail_the_two_tests_above() -> void:
	# What keeps those two honest. They compare the fitted normals against a
	# turn computed here, and if that turn were close enough to no turn at all
	# they would both pass over a class that copied the array across untouched —
	# which is the exact bug they exist for. So: measure the same worst vertex
	# against the untouched normal, and require it to miss.
	for tool: DetailingTool in _modelled():
		for extent: Vector3 in [tool.extent, LOPSIDED]:
			var fitted: Mesh = _built(tool, extent).mesh
			var worst: float = _worst_turned(fitted, _source_mesh(tool.model), Vector3.ONE)
			assert_lt(
				worst,
				UNTURNED_MAX,
				(
					"%s at %v: the fit is too near uniform to prove anything"
					% [tool.display_name, extent]
				)
			)


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
