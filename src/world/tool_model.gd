## A tool drawn as a modelled mesh instead of as a primitive — which, so far, is
## the two spray bottles.
##
## [b]What this is for.[/b] [DetailingTool] says a tool is a shape, a size and a
## colour, and [method ViewModel._mesh_for] has always turned that into a
## [CylinderMesh], a [BoxMesh] or a [PlaneMesh]. That was the plan rather than an
## accident — "a real model drops in later without moving anything else", as that
## class puts it — and this is the later. A tool that names a
## [member DetailingTool.model] is drawn by the glTF at that path; a tool that
## does not is drawn by its primitive exactly as before.
##
## [b]The model is fitted into the box the primitive occupied, and that is the
## whole rule.[/b] The catalogue's [member DetailingTool.extent] is what the
## roll-up icon is drawn from, what [method ViewModel._carry_for] measures a
## standoff against, and what [ReachCarry] puts a nozzle at the end of. A mesh
## that arrived at its own size would leave all three describing a bottle that is
## no longer there — so the source mesh's own bounding box is mapped onto the
## catalogue's extent and centred on the origin, which is where a [CylinderMesh]
## of that extent already sat. Every clearance the viewmodel's tests measure — the
## near plane, the car, the ground — then means the same thing it meant about the
## primitive, because it is measured against the same box.
##
## [b]The [code].glb[/code]'s own scale is deliberately thrown away.[/b] The
## window bottle is authored in Blender as a unit cylinder with a
## [code](0.1, 0.26, 0.1)[/code] scale on the node — its catalogue extent read as
## half-extents, so the exported bottle is twice the size the catalogue asks for.
## The tyre bottle has the opposite problem and it is not a mistake either: it is
## a real 27 cm trigger sprayer modelled in real metres, which is a perfectly good
## number and is not the 30 cm the catalogue gives that tool. Honouring either
## file would hand the player a bottle at a size nothing else in the game agrees
## with. Reading the mesh's box instead makes the export's scale irrelevant:
## re-export the same shape at any scale at all and the thing in the player's
## hand does not move.
##
## [b]Fitted by rebuilding the mesh, not by scaling the node.[/b] The proxy's
## transform is rewritten every frame by its [ToolCarry] out of an orthonormal
## basis (see [method ViewModel._carry_the_equipped]), so a scale left on the node
## survives exactly until the first press. A scaled child node would survive that,
## and would then be a child — which [method ViewModel._build] hangs the
## [code]Muzzle[/code] and [code]Butt[/code] markers off, and whose count is how
## [code]tests/integration/test_view_model.gd[/code] asks which tools spray. So
## the scale goes into the vertices once, at startup, and what hangs on the belt
## is an ordinary [MeshInstance3D] with an ordinary mesh in it: [method
## MeshInstance3D.get_aabb] answers honestly, and nothing downstream has to know
## this class exists.
##
## [b]Normals are divided by the fit, not multiplied by it.[/b] The fit is
## non-uniform — a bottle is taller than it is wide and the source cylinder is
## not — and a normal carried through a non-uniform scale unchanged is a normal
## that no longer stands off the surface it belongs to, which reads as a bottle
## lit from the wrong angle rather than as a bug. The inverse transpose of a
## diagonal matrix is the reciprocal of its diagonal, so that is a component-wise
## divide; tangents are directions [i]along[/i] the surface and take the fit
## itself. Neither is expensive per vertex and both are paid once, while the
## screen is loading: measured in [method ViewModel._build], the window bottle's
## 2,352 vertices take 5 ms and the tyre bottle's 37,286 take 37 ms. The second
## of those is a real number rather than a rounding error, and it is the price of
## a model this class deliberately does not decimate — see
## [code]scripts/build-tire-cleaner.py[/code], which says the same thing about
## the triangle count.
class_name ToolModel
extends MeshInstance3D

## What a tangent carries beyond its direction: three components of axis and a
## fourth of handedness, which is a sign and must survive the fit untouched.
const TANGENT_STRIDE: int = 4


## Builds the proxy for [param model_path], fitted into [param extent] metres.
##
## Leaves itself empty rather than half-built if the path holds no mesh — a
## missing model is a tool you cannot see, which is visible immediately, where a
## missing model that also took the belt down with it would be a black screen.
func _init(model_path: String, extent: Vector3) -> void:
	var source: Mesh = _mesh_in(model_path)
	if source == null:
		push_error("ToolModel: no mesh in %s" % model_path)
		return
	mesh = _fitted(source, extent)


## The mesh inside the scene at [param model_path], or [code]null[/code] if there
## is not one.
##
## An imported [code].glb[/code] is a [PackedScene] — a root [Node3D] with the
## meshes hung under it — so the scene is instantiated, the mesh lifted out of it
## and the scene thrown away. The mesh survives that because a [Mesh] is a
## [Resource] and the instance was only ever holding a reference to it.
static func _mesh_in(model_path: String) -> Mesh:
	var packed: PackedScene = load(model_path) as PackedScene
	if packed == null:
		return null
	var scene: Node = packed.instantiate()
	var found: MeshInstance3D = _first_mesh(scene)
	var source: Mesh = null
	if found != null:
		source = found.mesh
	scene.free()
	return source


## The first [MeshInstance3D] at or under [param node], depth first.
##
## "The first" rather than "the one" because a [code].glb[/code] may carry
## anything an artist left in the scene — an empty, a camera, a light — and the
## bottles are one mesh each. A model that grows a second one wants a class that
## keeps the hierarchy, not a silent second answer from here.
##
## [b]One mesh each is a property of the assets, and it is maintained.[/b] The
## tyre bottle is six modelled parts — body, neck, nozzle, two caps and a trigger
## — and [code]scripts/build-tire-cleaner.py[/code] flattens them into one mesh of
## six surfaces on the way in, for exactly this contract. Read that way round,
## the bake is what keeps the belt simple rather than this class being naive
## about art.
static func _first_mesh(node: Node) -> MeshInstance3D:
	var here: MeshInstance3D = node as MeshInstance3D
	if here != null and here.mesh != null:
		return here
	for child: Node in node.get_children():
		var found: MeshInstance3D = _first_mesh(child)
		if found != null:
			return found
	return null


## [param source] rebuilt at the size [param extent] gives it, centred on its own
## origin.
##
## Surface by surface, and each surface keeps the material the import gave it —
## the texture on these bottles is the entire reason they are models rather than
## coloured cylinders, so a fit that dropped it would have thrown away the point.
##
## Returns [code]null[/code] for a mesh with no width to measure, which is a mesh
## with nothing in it.
static func _fitted(source: Mesh, extent: Vector3) -> ArrayMesh:
	var box: AABB = source.get_aabb()
	if box.size.x <= 0.0 or box.size.y <= 0.0 or box.size.z <= 0.0:
		return null
	var fit: Vector3 = extent / box.size
	var centred: Vector3 = -box.get_center() * fit
	var built: ArrayMesh = ArrayMesh.new()
	for surface: int in source.get_surface_count():
		var arrays: Array = source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		arrays[Mesh.ARRAY_VERTEX] = _placed(vertices, fit, centred)
		# Guarded rather than assumed: which of these a surface carries is decided by
		# the import settings on the asset ([code].glb.import[/code]'s
		# [code]ensure_tangents[/code], among others), and a mesh with no tangents is
		# a null in the array rather than an empty one.
		if arrays[Mesh.ARRAY_NORMAL] != null:
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			arrays[Mesh.ARRAY_NORMAL] = _turned(normals, Vector3.ONE / fit)
		if arrays[Mesh.ARRAY_TANGENT] != null:
			var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
			arrays[Mesh.ARRAY_TANGENT] = _leaned(tangents, fit)
		built.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		built.surface_set_material(surface, source.surface_get_material(surface))
	return built


## [param vertices] scaled by [param fit] and slid by [param offset] — the fit
## itself, which is the one array where the transform is the obvious one.
static func _placed(
	vertices: PackedVector3Array, fit: Vector3, offset: Vector3
) -> PackedVector3Array:
	var placed: PackedVector3Array = PackedVector3Array()
	placed.resize(vertices.size())
	for at: int in vertices.size():
		placed[at] = vertices[at] * fit + offset
	return placed


## [param directions] turned by [param by] and re-normalised.
static func _turned(directions: PackedVector3Array, by: Vector3) -> PackedVector3Array:
	var turned: PackedVector3Array = PackedVector3Array()
	turned.resize(directions.size())
	for at: int in directions.size():
		turned[at] = (directions[at] * by).normalized()
	return turned


## [param tangents] turned by [param fit], keeping every fourth float — the
## handedness — exactly as it was. Flattened rather than a
## [PackedVector3Array] because that is the format
## [method ArrayMesh.add_surface_from_arrays] reads them back in.
static func _leaned(tangents: PackedFloat32Array, fit: Vector3) -> PackedFloat32Array:
	var leaned: PackedFloat32Array = tangents.duplicate()
	for at: int in range(0, leaned.size() - TANGENT_STRIDE + 1, TANGENT_STRIDE):
		var along: Vector3 = Vector3(leaned[at], leaned[at + 1], leaned[at + 2])
		along = (along * fit).normalized()
		leaned[at] = along.x
		leaned[at + 1] = along.y
		leaned[at + 2] = along.z
	return leaned
