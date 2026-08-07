## Integration test for the mesh car's colliders — point 4 of the panel contract
## in [code]src/world/car.gd[/code], on all ten styles: what a ray comes back
## holding when it is fired at a part of the car.
##
## [b]Why it is a file of its own.[/b] Everything in here needs the physics clock
## — a space state may only be queried while physics is stepping — and nothing in
## [code]tests/integration/test_mesh_car.gd[/code] does. Splitting them keeps the
## [code]await[/code] out of the file whose whole point is that a mesh car needs
## no frame to be measured.
##
## [b]The ten are parked twenty metres apart rather than instanced one at a time.[/b]
## Ten cars at the origin would be ten cars inside each other, and every ray in
## here would answer with whichever body the physics server happened to list
## first. Twenty metres is four car lengths past the longest of them, so a five
## metre ray cast at one can never reach another, and every position below is
## taken from the car's own transform rather than from the world origin.
##
## [b]And the rays are aimed at the geometry, not at numbers written down here.[/b]
## A test that fired at [code](0.9, 0.4, 1.2)[/code] would be a test about the
## sedan; these compute where to fire from the panel's own triangles, so the same
## assertion means the same thing on a pickup and on a sports car.
extends GutTest

const SCENE: String = "res://src/world/mesh_car.tscn"

## How far apart the ten are parked. See the class docs.
const SPACING: float = 20.0

## How far out a ray starts when it is fired square at a face. A hand's width:
## far enough to be outside the panel it is aimed at, close enough that the ray
## has no room to find something else on the way in.
const STANDOFF: float = 0.15

## How many of a panel's faces [method _answers_for_its_own_faces] fires at.
## Evenly spaced through the mesh rather than the first two dozen, which on a
## glTF is one corner of one part.
const SAMPLES: int = 24

const WHEELS: Array[String] = ["Wheel1", "Wheel2", "Wheel3", "Wheel4"]


## The ten styles, parked in a row, one physics frame away from being hittable.
func _the_ten() -> Array[MeshCar]:
	var packed: PackedScene = load(SCENE) as PackedScene
	assert_not_null(packed, "could not load %s" % SCENE)
	var cars: Array[MeshCar] = []
	for index: int in range(MeshCar.STYLES.size()):
		# Into a typed local first: GUT's add_child_autofree is untyped.
		var car: MeshCar = packed.instantiate() as MeshCar
		car.style = MeshCar.STYLES[index]
		car.position = Vector3(index * SPACING, 0.0, 0.0)
		add_child_autofree(car)
		cars.append(car)
	return cars


func _panel(car: MeshCar, named: String) -> Node3D:
	for panel: Node3D in car.panels():
		if String(panel.name) == named:
			return panel
	return null


## What a ray from [param from] to [param to] comes back holding, or
## [code]null[/code] for a ray that hit nothing.
func _hit(car: MeshCar, from: Vector3, to: Vector3) -> Node3D:
	var space: PhysicsDirectSpaceState3D = car.get_world_3d().direct_space_state
	var found: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	if found.is_empty():
		return null
	var struck: Object = found["collider"]
	return struck as Node3D


## The widest triangle of [param panel]'s skin, in world space, as a centre and
## an outward-facing normal.
##
## The widest, because it is the part of a panel a player can plausibly point at:
## on the glass it is a windscreen or a door window rather than the sliver at the
## edge of a pillar. Outward-facing is decided against the car's own middle, since
## a triangle's winding says which side its normal is on and nothing about which
## side of the car it is on.
func _widest_face(car: MeshCar, panel: Node3D) -> PackedVector3Array:
	var skin: GeometryInstance3D = car.skin_of(panel)
	var mesh: MeshInstance3D = skin as MeshInstance3D
	var faces: PackedVector3Array = mesh.mesh.get_faces()
	var widest: float = -1.0
	var answer: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
	for corner: int in range(0, faces.size(), 3):
		var a: Vector3 = skin.global_transform * faces[corner]
		var b: Vector3 = skin.global_transform * faces[corner + 1]
		var c: Vector3 = skin.global_transform * faces[corner + 2]
		var cross: Vector3 = (b - a).cross(c - a)
		var area: float = cross.length() * 0.5
		if area <= widest:
			continue
		widest = area
		var centre: Vector3 = (a + b + c) / 3.0
		var outward: Vector3 = cross.normalized()
		if outward.dot(centre - car.global_position) < 0.0:
			outward = -outward
		answer = PackedVector3Array([centre, outward])
	return answer


## How many of [param panel]'s own faces answer with [param panel] when a ray is
## fired square at them from [constant STANDOFF] out, out of how many were tried.
func _answers_for_its_own_faces(car: MeshCar, panel: Node3D) -> Vector2i:
	var skin: GeometryInstance3D = car.skin_of(panel)
	var mesh: MeshInstance3D = skin as MeshInstance3D
	var faces: PackedVector3Array = mesh.mesh.get_faces()
	var total: int = faces.size() / 3
	var step: int = maxi(1, total / SAMPLES)
	var itself: int = 0
	var tried: int = 0
	for face: int in range(0, total, step):
		var corner: int = face * 3
		var a: Vector3 = skin.global_transform * faces[corner]
		var b: Vector3 = skin.global_transform * faces[corner + 1]
		var c: Vector3 = skin.global_transform * faces[corner + 2]
		var centre: Vector3 = (a + b + c) / 3.0
		var outward: Vector3 = (b - a).cross(c - a).normalized()
		if outward.dot(centre - car.global_position) < 0.0:
			outward = -outward
		tried += 1
		if _hit(car, centre + outward * STANDOFF, centre - outward * 0.02) == panel:
			itself += 1
	return Vector2i(itself, tried)


# ---- one ray per kind of part -------------------------------------------------


func test_a_ray_into_the_flank_comes_back_holding_the_bodywork() -> void:
	# Level with the car's middle and square onto its side, which is where a player
	# standing beside it with a sponge is pointing. Checked against panels() and not
	# only against a name, exactly as the contract test does: the node the ray hands
	# back has to be a member of the very list Grime keyed its maps on, or a tool
	# lands on the car and finds nothing to clean.
	await wait_physics_frames(1)
	for car: MeshCar in _the_ten():
		var focus: Vector3 = car.global_position
		var hit: Node3D = _hit(car, focus + Vector3(5.0, 0.0, 0.0), focus)
		assert_not_null(hit, "%s: a ray at mid-height must find the car" % car.style)
		if hit == null:
			continue
		assert_true(car.panels().has(hit), "%s: %s is not a panel" % [car.style, hit.name])
		assert_eq(hit.name, &"Body", "%s: side on at mid-height, a ray meets the shell" % car.style)
		assert_eq(car.kind_of(hit), Surface.Kind.BODY, "%s: and the shell is paint" % car.style)


func test_a_ray_up_from_under_each_wheel_comes_back_holding_that_wheel() -> void:
	# From below, because a tyre is the lowest thing on the car and the fender above
	# it is the widest — a ray fired horizontally at a wheel meets the arch over it
	# first, which is the bodywork correctly answering for itself. Four separate
	# assertions per car, because a wheel wrapped into the wrong body is a bug that
	# only shows on one corner.
	await wait_physics_frames(1)
	for car: MeshCar in _the_ten():
		for named: String in WHEELS:
			var wheel: Node3D = _panel(car, named)
			var axle: Vector3 = wheel.global_position
			var hit: Node3D = _hit(car, Vector3(axle.x, axle.y - 4.0, axle.z), axle)
			assert_eq(hit, wheel, "%s: a ray up at %s found %s" % [car.style, named, hit])
			if hit != null:
				assert_eq(car.kind_of(hit), Surface.Kind.WHEEL, "%s: %s" % [car.style, named])


func test_a_ray_square_at_the_widest_pane_comes_back_holding_the_glass() -> void:
	# The window cleaner's whole job, and the assertion that would have failed
	# quietly: the glass is a single-thickness shell sitting inside the bodywork, so
	# a ray that passed through it would come back holding the Body behind it and the
	# blue bottle would do nothing on the one panel it is for.
	await wait_physics_frames(1)
	for car: MeshCar in _the_ten():
		var glass: Node3D = _panel(car, MeshCar.GLASS_PART)
		var face: PackedVector3Array = _widest_face(car, glass)
		var hit: Node3D = _hit(car, face[0] + face[1] * STANDOFF, face[0] - face[1] * 0.02)
		assert_eq(hit, glass, "%s: a ray at the windscreen found %s" % [car.style, hit])
		if hit != null:
			assert_eq(car.kind_of(hit), Surface.Kind.GLASS, "%s: and glass is glass" % car.style)


func test_every_panel_answers_for_its_own_faces() -> void:
	# The general claim the three tests above are instances of: the collider is the
	# geometry, so a ray fired square at any face of a panel comes back holding that
	# panel. A majority and not all of them, and the shortfall is the pack's shape
	# rather than the collider's — lamp lenses are recessed into the bodywork and
	# wheels sit up inside their arches, so a face on the edge of one is genuinely
	# behind another panel and answering with it is the right answer. Measured over
	# all ten styles: the worst panel in the pack is the sports car's optics at 48 of
	# 72 faces, and the best are the eight panels that answer for every face they
	# have.
	await wait_physics_frames(1)
	for car: MeshCar in _the_ten():
		for panel: Node3D in car.panels():
			var tally: Vector2i = _answers_for_its_own_faces(car, panel)
			assert_gt(tally.x, 0, "%s: nothing can hit %s at all" % [car.style, panel.name])
			assert_gt(
				float(tally.x),
				float(tally.y) * 0.5,
				"%s: %s answers for %d of %d faces" % [car.style, panel.name, tally.x, tally.y]
			)


# ---- the colliders themselves -------------------------------------------------


func test_every_panel_carries_a_trimesh_of_its_own_triangles() -> void:
	# A convex hull would be cheaper and is the wrong shape by a mile: the arches
	# fill in, the greenhouse fuses to the roof, and a jet aimed between a wheel and
	# a sill lands on paint that is not there. Asserted by triangle count against the
	# mesh, which is what makes it "its own geometry" rather than "some concave
	# shape".
	for car: MeshCar in _the_ten():
		for panel: Node3D in car.panels():
			var body: StaticBody3D = panel as StaticBody3D
			assert_eq(body.get_shape_owners().size(), 1, "%s: %s" % [car.style, panel.name])
			var collider: CollisionShape3D = (
				body.get_node_or_null(NodePath("%sShape" % panel.name)) as CollisionShape3D
			)
			assert_not_null(collider, "%s: %s has no collider" % [car.style, panel.name])
			if collider == null:
				continue
			var shape: ConcavePolygonShape3D = collider.shape as ConcavePolygonShape3D
			assert_not_null(shape, "%s: %s is not a trimesh" % [car.style, panel.name])
			if shape == null:
				continue
			var mesh: MeshInstance3D = car.skin_of(panel) as MeshInstance3D
			assert_eq(
				shape.get_faces().size(),
				mesh.mesh.get_faces().size(),
				"%s: %s's collider is not its mesh" % [car.style, panel.name]
			)


func test_the_colliders_are_solid_from_both_sides() -> void:
	# ConcavePolygonShape3D.backface_collision, and it is not a detail. These parts
	# are shells with no thickness, and a triangle wound the other way lets a ray
	# pass straight through the panel it was aimed at. Measured across all ten
	# styles, firing square at 2,783 sampled faces from a hand's width out: with
	# backface collision off, 171 of those rays come back holding nothing at all —
	# the tool would find the tarmac behind a wheel arch. With it on, 7 do. Nothing
	# in the game casts a ray from inside a car, so every extra hit it allows is a
	# hit that was wanted.
	for car: MeshCar in _the_ten():
		for panel: Node3D in car.panels():
			var collider: CollisionShape3D = (
				panel.get_node_or_null(NodePath("%sShape" % panel.name)) as CollisionShape3D
			)
			var shape: ConcavePolygonShape3D = collider.shape as ConcavePolygonShape3D
			assert_true(shape.backface_collision, "%s: %s is one-sided" % [car.style, panel.name])


# ---- and what the hit is for --------------------------------------------------


func test_what_a_ray_hits_is_a_panel_the_grime_has_a_map_for() -> void:
	# End to end, and the reason any of the above matters: the node the raycast hands
	# back is the key Grime stored its map under, so a tool that lands on the car has
	# something to take off. It is the one place the two halves of the contract —
	# what a ray answers with, and what panels() handed to Grime — have to be the
	# same node.
	var packed: PackedScene = load(SCENE) as PackedScene
	var car: MeshCar = packed.instantiate() as MeshCar
	car.style = "sedan"
	add_child_autofree(car)
	var grime: Grime = Grime.new()
	add_child_autofree(grime)
	grime.lay_on(car)
	assert_true(grime.is_laid(), "no grime was laid at all")
	await wait_physics_frames(1)
	var focus: Vector3 = car.global_position
	var hit: Node3D = _hit(car, focus + Vector3(5.0, 0.0, 0.0), focus)
	assert_not_null(hit, "a ray at mid-height must find the car")
	if hit == null:
		return
	var map: GrimeMap = grime.map_of(hit)
	assert_not_null(map, "%s was hit and has no grime on it" % hit.name)
	if map == null:
		return
	assert_gt(map.box().size.length(), 0.0, "%s got a zero-sized map" % hit.name)
	assert_eq(map.box(), car.skin_of(hit).get_aabb(), "%s's map is not its own box" % hit.name)
