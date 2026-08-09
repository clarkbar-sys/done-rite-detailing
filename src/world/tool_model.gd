## A tool drawn as a modelled mesh instead of as a primitive — which, so far, is
## the two spray bottles, the sponge and the power wash.
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
## [b]The [code].glb[/code]'s own scale is deliberately thrown away.[/b] The two
## bottles are one piece of geometry in two liveries — a real 27 cm trigger
## sprayer modelled in real metres, which is a perfectly good number and is
## neither the 26 cm nor the 30 cm the catalogue gives the two tools drawn from
## it. That is the case at its plainest: the same mesh has to arrive in the hand
## at two sizes, and a file can only claim one. The sponge is a second answer —
## a 16 cm one, which is a real sponge and is not the 24 cm the catalogue hands
## the player. Honouring either file would put a tool in the hand at a size
## nothing else in the game agrees with. Reading the mesh's box instead makes the
## export's scale irrelevant: re-export the same shape at any scale at all and
## the thing in the player's hand does not move.
##
## [b]The wand is the case that proves that reading is the right one[/b], by
## being the one file that already agrees: it is drawn at exactly its catalogue
## extent ([code]scripts/build-pressure-washer.py[/code]), so its fit works out as
## the identity. Nothing here treats that as a special case and nothing may start
## to — re-draw that wand at half the size and the tool in the hand must not move
## either. It was a Sketchfab download whose vertices were in no unit at all, 21
## of them end to end with the scale that would make them metres left on a node
## this class never looks at, and the arithmetic that took that in is the same
## arithmetic that takes this in.
##
## [b]Its orientation is not thrown away, and the turn that fixes one is data.[/b]
## The fit is axis by axis, so a mesh has to arrive with its long axis on
## [code]+Y[/code] and its business end at the top — which is where a
## [CylinderMesh] put them, and which is what [method ViewModel._build] hangs the
## [code]Muzzle[/code] marker off. All four models on the belt honour it as
## authored today; the power wash did not while it was a Sketchfab download whose
## own frame was Z-up, with the barrel it is meant to spray out of at the
## [code]-Y[/code] end of its mesh, so fitted as it arrived the water left the
## butt. So a model may name a turn — [member DetailingTool.model_turn] — and it
## is applied [i]before[/i] the box is measured, which is what keeps the
## catalogue's extent describing the tool the player ends up holding. In the table
## rather than in here, because "which way up did this artist model it" is a fact
## about one asset and this class must not grow a list of them.
##
## [b]The top of the box is a stronger promise than "which way up", and it is not
## this class's to keep.[/b] The marker is hung at the top of the extent [i]on the
## box's own axis[/i], so a model whose business end is the highest thing in it
## but sits off to one side — a wand with a bottle strapped across it, sizing the
## box by the bottle — passes every check here and still sprays out of thin air.
## That was [code]#162[/code]. A fit cannot notice it: the box is all this class
## is given, and where the nozzle is inside that box is a fact about the asset.
## It is asserted where the assets are, in
## [code]tests/integration/test_tool_model.gd[/code].
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
## non-uniform — the catalogue's box is never quite the mesh's own proportions,
## and both bottles come out about a quarter deeper than they are modelled, which
## is what the extent buys — and a normal carried through that unchanged is one
## that no longer stands off the surface it belongs to, which reads as a bottle
## lit from the wrong angle rather than as a bug. The inverse transpose of a
## diagonal matrix is the reciprocal of its diagonal, so that is a component-wise
## divide; tangents are directions [i]along[/i] the surface and take the fit
## itself. Neither is expensive per vertex and both are paid once, while the
## screen is loading: measured here on the pinned Godot, one build of each
## bottle, each bottle's 5,982 vertices take about 18 ms, so the pair costs about
## 36 ms of the bay's load. That is a real number rather than a rounding error,
## and it is roughly half what it was — the bottles were 37,286 vertices and
## 33 ms each until [code]scripts/build-tire-cleaner.py[/code] grew a mesh
## simplifier, and that script is where the whole argument for the triangle
## budget is written down. Not a sixth of what it was, note, which is what a
## sixth of the vertices might have promised: a good part of the cost is loading
## the imported scene and rebuilding six surfaces, and neither of those got
## smaller. The sponge is the other end of that range: 224 vertices at about
## 9 ms, nearly all of it that same fixed cost, because everything that makes it
## look like a sponge is in its normal map rather than in its geometry.
##
## [b]Which is what makes the sponge the one to look at if this arithmetic is
## ever wrong.[/b] Its fit is a genuinely lopsided (1.47, 2.46, 1.56): a 16 cm
## sponge into a box proportionally 67% thicker, see
## [code]scripts/build-sponge.py[/code] — and it is six broad faces and a bevel,
## where a bottle spreads the same error over thousands of small ones and it
## reads as lighting.
class_name ToolModel
extends MeshInstance3D

## What a tangent carries beyond its direction: three components of axis and a
## fourth of handedness, which is a sign and must survive the fit untouched.
const TANGENT_STRIDE: int = 4

## Degrees to radians, for [member DetailingTool.model_turn]. Degrees in the
## catalogue for the same reason [method ViewModel._held_pose] uses them: half a
## turn is what somebody deciding it actually thinks in.
const PER_DEGREE: float = PI / 180.0


## Builds the proxy for [param model_path], turned [param turn_degrees] and then
## fitted into [param extent] metres.
##
## [param turn_degrees] is [member DetailingTool.model_turn] and is zero for a
## model authored the way up the game holds it, which is most of them. It is
## applied first and the box is measured after, so [param extent] describes the
## turned mesh — see [method _fitted].
##
## Leaves itself empty rather than half-built if the path holds no mesh — a
## missing model is a tool you cannot see, which is visible immediately, where a
## missing model that also took the belt down with it would be a black screen.
func _init(model_path: String, extent: Vector3, turn_degrees: Vector3 = Vector3.ZERO) -> void:
	var source: Mesh = _mesh_in(model_path)
	if source == null:
		push_error("ToolModel: no mesh in %s" % model_path)
		return
	mesh = _fitted(source, extent, Basis.from_euler(turn_degrees * PER_DEGREE))


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
## belt's models are one mesh each. A model that grows a second one wants a class
## that keeps the hierarchy, not a silent second answer from here.
##
## [b]One mesh each is a property of the assets, and it is maintained.[/b] The
## tyre bottle is six modelled parts — body, neck, nozzle, two caps and a trigger
## — and [code]scripts/build-tire-cleaner.py[/code] flattens them into one mesh of
## six surfaces on the way in, for exactly this contract; the sponge arrives four
## nodes deep under a Sketchfab exporter chain and
## [code]scripts/build-sponge.py[/code] flattens that the same way. Read that way
## round, the bakes are what keep the belt simple rather than this class being
## naive about art.
static func _first_mesh(node: Node) -> MeshInstance3D:
	var here: MeshInstance3D = node as MeshInstance3D
	if here != null and here.mesh != null:
		return here
	for child: Node in node.get_children():
		var found: MeshInstance3D = _first_mesh(child)
		if found != null:
			return found
	return null


## [param source] turned by [param turn], rebuilt at the size [param extent]
## gives it, and centred on its own origin.
##
## Surface by surface, and each surface keeps the material the import gave it —
## the texture on these bottles is the entire reason they are models rather than
## coloured cylinders, so a fit that dropped it would have thrown away the point.
##
## [b]The turn happens first, and the box is measured afterwards.[/b] It has to:
## the fit is per axis, so measuring the mesh as authored and turning it after
## would hand a model that arrives lying down the length the catalogue meant for
## its width. Measuring the turned box instead means [param extent] describes the
## tool the player holds whatever frame its artist worked in. A rigid turn also
## composes with the rest of this without a special case — it goes in front of the
## fit on the vertices, in front of the reciprocal on the normals, and in front of
## the fit again on the tangents.
##
## The turned box is the source box turned, rather than the turned vertices
## measured again: exact at the right angles [member DetailingTool.model_turn]
## allows, and one pass of arithmetic rather than one pass over the mesh.
##
## Returns [code]null[/code] for a mesh with no width to measure, which is a mesh
## with nothing in it.
static func _fitted(source: Mesh, extent: Vector3, turn: Basis) -> ArrayMesh:
	var box: AABB = Transform3D(turn, Vector3.ZERO) * source.get_aabb()
	if box.size.x <= 0.0 or box.size.y <= 0.0 or box.size.z <= 0.0:
		return null
	var fit: Vector3 = extent / box.size
	var centred: Vector3 = -box.get_center() * fit
	var built: ArrayMesh = ArrayMesh.new()
	for surface: int in source.get_surface_count():
		var arrays: Array = source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		arrays[Mesh.ARRAY_VERTEX] = _placed(vertices, turn, fit, centred)
		# Guarded rather than assumed: which of these a surface carries is decided by
		# the import settings on the asset ([code].glb.import[/code]'s
		# [code]ensure_tangents[/code], among others), and a mesh with no tangents is
		# a null in the array rather than an empty one.
		if arrays[Mesh.ARRAY_NORMAL] != null:
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			arrays[Mesh.ARRAY_NORMAL] = _turned(normals, turn, Vector3.ONE / fit)
		if arrays[Mesh.ARRAY_TANGENT] != null:
			var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
			arrays[Mesh.ARRAY_TANGENT] = _leaned(tangents, turn, fit)
		built.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		built.surface_set_material(surface, source.surface_get_material(surface))
	return built


## [param vertices] turned by [param turn], scaled by [param fit] and slid by
## [param offset] — the fit itself, which is the one array where the transform is
## the obvious one.
static func _placed(
	vertices: PackedVector3Array, turn: Basis, fit: Vector3, offset: Vector3
) -> PackedVector3Array:
	var placed: PackedVector3Array = PackedVector3Array()
	placed.resize(vertices.size())
	for at: int in vertices.size():
		placed[at] = turn * vertices[at] * fit + offset
	return placed


## [param directions] turned by [param turn], then by [param by], and
## re-normalised. Two turns and not one because they are different things: the
## first is the model's own righting, which is rigid, and the second is the
## reciprocal of a non-uniform fit.
static func _turned(directions: PackedVector3Array, turn: Basis, by: Vector3) -> PackedVector3Array:
	var turned: PackedVector3Array = PackedVector3Array()
	turned.resize(directions.size())
	for at: int in directions.size():
		turned[at] = (turn * directions[at] * by).normalized()
	return turned


## [param tangents] turned by [param turn] and then by [param fit], keeping every
## fourth float — the handedness — exactly as it was. A rigid turn cannot change
## handedness, so the sign is as safe here as it was before there was one.
## Flattened rather than a [PackedVector3Array] because that is the format
## [method ArrayMesh.add_surface_from_arrays] reads them back in.
static func _leaned(tangents: PackedFloat32Array, turn: Basis, fit: Vector3) -> PackedFloat32Array:
	var leaned: PackedFloat32Array = tangents.duplicate()
	for at: int in range(0, leaned.size() - TANGENT_STRIDE + 1, TANGENT_STRIDE):
		var along: Vector3 = Vector3(leaned[at], leaned[at + 1], leaned[at + 2])
		along = (turn * along * fit).normalized()
		leaned[at] = along.x
		leaned[at + 1] = along.y
		leaned[at + 2] = along.z
	return leaned
