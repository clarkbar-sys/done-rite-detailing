## The ground the car is parked on: a modeled driveway, the lawn either side of
## it, and the banks that close the place in — one imported mesh, stood on the
## room's own floor.
##
## [b]It replaces three scaled boxes and a wood of rolled primitives.[/b] The
## driveway used to be a unit [BoxMesh] 4.4 m across, the grass two more either
## side of it, and the tree line fourteen cylinders-and-spheres planted from
## fixed seeds around the edge of the lawn. All of that was a blockout in the
## same sense the car's was — the shapes and their sizes were the design
## decision, and none of it should have been waiting on an artist. This is the
## artist arriving: [i]Sunken Driveway Parking Spot[/i], a concrete pad let into
## a grass field that rises away from it on every side.
## [code]assets/models/driveway/ATTRIBUTION.txt[/code] carries the credit, the
## menu carries the copy of it a player can read, and #114 is where the swap was
## argued.
##
## [b]This scene exists because the model's origin is not the room's.[/b] The
## glTF is authored Z-up, about a point 0.403 m below its own concrete, with the
## pad's footprint 0.125 m to one side of that point and 0.247 m along it.
## Godot's importer fixes the first of those and none of the rest, so something
## has to hold the one transform that turns the model's metres into a floor —
## and putting it here rather than in [code]src/world/garage.tscn[/code] is what
## lets the room go back to holding a single node called [code]Ground[/code],
## standing at the origin, the way it held three boxes standing at theirs. The
## numbers are in [code]src/world/ground.tscn[/code] beside the model they are
## about.
##
## [b]The scale is a fifth over the model's own metres, and it is the camera that
## asks for it.[/b] The showcase circuit sweeps a 5.6 m disc around the car
## ([member Garage.orbit_radius]), and the model at 1:1 reaches 5.04 m either
## side of the concrete — 0.56 m short, so the eye would spend part of every lap
## past the edge of the world it is looking into. At 1.25 the outer edge stands
## 6.30 m out, which is the old lawn's fence again with 0.7 m to spare, and the
## same quarter puts the walk's own standoff — 2.55 m from the middle of the car
## — on concrete rather than out over the kerb, because the pad goes from 2.35 m
## half-width to 2.94 m. What it costs is that a kerbstone is a fifth larger
## than the person who modeled it meant, at ten metres, in a game about the paint
## on a car. [code]tests/integration/test_ground.gd[/code] does the sum against
## [Garage]'s own radius rather than trusting the 6.30 written here.
##
## [b]Nothing out here has a collider, and that is the same decision the trees
## were held to.[/b] The room casts a ray for the camera's standoff and another
## for the aim mark, and both are asking a question about the [Car]. Ground with
## a body would let a finger on the horizon mark a bank of grass, and would give
## the walk something to hug that is not the paint. The import brings none in —
## no node in the model carries the [code]-col[/code] suffix that would generate
## one — and a test says so rather than leaving it to the next person to
## re-import with a box ticked.
##
## [b]What it is for, beyond being drawn.[/b] Three questions the rest of the
## room used to answer by reading a box's scale off the scene file: how high the
## drive is ([method drive]), which is where a car of any height gets sat; how
## far the modeled ground reaches ([method extent]), which is the fence the
## camera and everything held in front of it stay inside; and how high the grass
## is at a given spot ([method settle]), which is what [Grove] plants its trees
## on now that the lawn is a slope instead of a box with a flat top. All three
## are measured off the meshes themselves, so ground that is re-placed or
## re-scaled moves them together and nothing has to remember to follow.
class_name Ground
extends Node3D

## Which mesh in the imported model is the concrete a car can be parked on.
##
## An [code]@export[/code] because the name is the model's rather than ours: the
## importer derives it from the glTF node, and a name this project did not choose
## belongs in the scene file next to the model it came with, where re-importing a
## differently-named pad is one line to fix instead of a script to open.
@export var concrete: NodePath


## Where the top of the drive is and how much of it there is, as a box in world
## space — the concrete itself, not the field it is let into.
##
## [b]This is the room's floor, measured rather than declared.[/b] Every car in
## the pack is authored about its own mid-height and the ten are 1.04 m to 1.77 m
## tall, so [method Garage._park_the_car] has to lift each one by half of itself
## onto something; that something is [code]drive().end.y[/code], which this scene
## puts at zero and would go on reporting truthfully if it did not. The width and
## depth are here for the same reason — a car parked on ground it overhangs is a
## thing a test can notice before a player does.
##
## An empty box if [member concrete] names nothing, which is the honest answer to
## having no measurement and the one that makes a caller's arithmetic obviously
## wrong rather than quietly wrong.
func drive() -> AABB:
	var slab: VisualInstance3D = get_node_or_null(concrete) as VisualInstance3D
	if slab == null:
		return AABB()
	return slab.global_transform * slab.get_aabb()


## Every mesh the ground is made of, merged into one box in world space: the
## drive, the lawn and the banks together.
##
## What the fences are read off. The camera circles inside it, the walk stays
## inside it, and a held tool's corners stay inside it — see
## [code]tests/integration/test_garage.gd[/code] and its neighbours, which used
## to read the same number off the right-hand grass box's scale.
func extent() -> AABB:
	var pieces: Array[AABB] = []
	_gather(self, pieces)
	if pieces.is_empty():
		return AABB()
	var whole: AABB = pieces[0]
	for piece: AABB in pieces:
		whole = whole.merge(piece)
	return whole


## How high the ground is under each of [param spots], in world metres —
## the answer to "I want to stand something here, what is it standing on".
##
## [b]The third thing measured off the model rather than declared, and the one
## that only exists because the ground stopped being flat.[/b] [method drive]
## and [method extent] were both once a number read off a scaled box. So was
## this: the trees the blockout carried stood at [code]y = 0[/code] because the
## lawn they stood on was a box 0.2 m thick with its top there, and every tree
## in the wood could be planted from the same constant. The modeled lawn rises
## out of the drive to 1.17 m and does it unevenly, so a constant now buries a
## trunk on the bank or floats one over the hollow. [Grove] asks this instead.
##
## [b]NAN where there is no ground, and that is the useful part.[/b] The lawn
## wraps three sides of the pad and the fourth is open — the end the car drives
## in from — and the outer edge is a hard edge with sky past it, so "is there
## ground at this spot" is a real question with a real no. A caller that plants
## on NAN gets a tree at no height at all rather than one hanging in the air at
## zero, which is the difference between a test noticing and a player noticing.
##
## [b]It takes every spot at once because the walk is the cost.[/b] Nothing out
## here has a collider — see the class docs, and the two rays that is protecting
## — so there is no physics query to make and the height has to come off the
## triangles themselves. That is one pass over all 31,420 of them, and it is the
## same pass whether it is asked about one spot or fifty. Asked one at a time by
## a grove of nine, it would be nine passes for no more answer. Measured on the
## headless Linux box the numbers in [code]scripts/perf-probe.gd[/code] were
## taken on: 35 ms for the whole call, once, at [method Grove.plant].
##
## The spots' own Y is ignored — what is asked is where the column of air above
## and below each [code]x, z[/code] meets the ground, and the highest surface it
## meets is the one that answers, so a spot over the drive gets the concrete
## rather than the underside of the slab it is cut into.
func settle(spots: PackedVector3Array) -> PackedFloat32Array:
	var found: PackedFloat32Array = PackedFloat32Array()
	found.resize(spots.size())
	found.fill(NAN)
	if spots.is_empty():
		return found
	# The spots bucketed by a coarse cell of the ground plane, so the loop below
	# can ask "is any spot near this triangle" with one dictionary lookup instead
	# of by trying all of them. Without it the inner test runs spots x triangles
	# times, which is the whole cost of the pass for a grove of any size.
	var buckets: Dictionary[Vector2i, PackedInt32Array] = {}
	for spot: int in spots.size():
		var cell: Vector2i = _cell(spots[spot].x, spots[spot].z)
		if not buckets.has(cell):
			buckets[cell] = PackedInt32Array()
		var sharing: PackedInt32Array = buckets[cell]
		sharing.append(spot)
		buckets[cell] = sharing
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var drawn: MeshInstance3D = node as MeshInstance3D
		if drawn == null or drawn.mesh == null:
			continue
		_drop_onto(drawn, spots, buckets, found)
	return found


## Which bucket of [method settle]'s grid the point [param x], [param z] falls
## in. Two metres, which is wider than any triangle in the model — so a triangle
## touches four cells at worst and the lookups stay a handful.
func _cell(x: float, z: float) -> Vector2i:
	return Vector2i(int(floorf(x * 0.5)), int(floorf(z * 0.5)))


## Raises [param found] to whatever of [param drawn]'s triangles stands over any
## of [param spots], using [param buckets] to skip the ones standing over none.
func _drop_onto(
	drawn: MeshInstance3D,
	spots: PackedVector3Array,
	buckets: Dictionary[Vector2i, PackedInt32Array],
	found: PackedFloat32Array
) -> void:
	var faces: PackedVector3Array = drawn.mesh.get_faces()
	var placed: Transform3D = drawn.global_transform
	var corner: int = 0
	while corner + 2 < faces.size():
		var a: Vector3 = placed * faces[corner]
		var b: Vector3 = placed * faces[corner + 1]
		var c: Vector3 = placed * faces[corner + 2]
		corner += 3
		var low: Vector2i = _cell(minf(a.x, minf(b.x, c.x)), minf(a.z, minf(b.z, c.z)))
		var high: Vector2i = _cell(maxf(a.x, maxf(b.x, c.x)), maxf(a.z, maxf(b.z, c.z)))
		for across: int in range(low.x, high.x + 1):
			for along: int in range(low.y, high.y + 1):
				var cell: Vector2i = Vector2i(across, along)
				if not buckets.has(cell):
					continue
				for spot: int in buckets[cell]:
					var here: float = _over(a, b, c, spots[spot])
					if not is_nan(here) and (is_nan(found[spot]) or here > found[spot]):
						found[spot] = here
	return


## How high the triangle [param a], [param b], [param c] is directly above or
## below [param spot], or NAN when the spot is not under it at all.
##
## Barycentric on the ground plane rather than a ray cast against the triangle
## in space: the question is always asked straight down, so dropping Y turns it
## into a point-in-triangle test and an interpolation, and a triangle standing
## exactly on its edge — a wall of the sunken pad, seen from above — has no area
## to be inside of and is skipped by the same divisor that would be zero.
func _over(a: Vector3, b: Vector3, c: Vector3, spot: Vector3) -> float:
	var area: float = (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
	if is_zero_approx(area):
		return NAN
	var at_a: float = ((b.z - c.z) * (spot.x - c.x) + (c.x - b.x) * (spot.z - c.z)) / area
	var at_b: float = ((c.z - a.z) * (spot.x - c.x) + (a.x - c.x) * (spot.z - c.z)) / area
	var at_c: float = 1.0 - at_a - at_b
	if at_a < 0.0 or at_b < 0.0 or at_c < 0.0:
		return NAN
	return at_a * a.y + at_b * b.y + at_c * c.y


## Adds the world-space box of every [VisualInstance3D] under [param branch] to
## [param into], depth first.
func _gather(branch: Node, into: Array[AABB]) -> void:
	for child: Node in branch.get_children():
		var visual: VisualInstance3D = child as VisualInstance3D
		if visual != null:
			into.append(visual.global_transform * visual.get_aabb())
		_gather(child, into)
