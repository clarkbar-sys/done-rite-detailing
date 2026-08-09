## Integration test for the [Ground] — the modeled driveway the room stands on,
## and the promises the room makes about it.
##
## Under tests/integration/ because every measurement here is of an imported
## mesh: the boxes come off [method VisualInstance3D.get_aabb] through a chain of
## transforms the glTF importer built, which is a scene tree or it is nothing.
##
## What is checked is the join between the model and the room, and it is checked
## against the room rather than against numbers copied out of it: the ground says
## how far it reaches, the garage says how far the camera swings, and the car
## pack says how long a car is. All three halves of that go red if any one of
## them moves — which is the whole reason the ground is asked instead of being
## described in a constant up here.
##
## The one thing deliberately not tested is how it looks. That is #114's business
## and a screenshot's; what a test can hold is that it is the right size, in the
## right place, and made of nothing a ray can hit.
extends GutTest

const GARAGE: String = "res://src/world/garage.tscn"
const GROUND: String = "res://src/world/ground.tscn"

## Close enough for a length in metres — a tenth of a millimetre.
const TOLERANCE: float = 0.0001

## How far the top of the kerb stands over the pad it fences, in metres — which
## is also, after #167 lays the pad on the room's origin plane, where
## [method Ground.drive]'s box tops out in world space.
##
## Measured off the mesh rather than declared: the concrete's two faces are
## 0.1270 and 0.40322 up the model's own axis and the scene stands it a quarter
## over, so the gap is 0.27622 x 1.25. It is written down here because it is the
## number the bug was worth: every car in the pack was parked on it instead of on
## the pad, and a change that quietly closes the sinking would otherwise look
## like a pass.
const KERB: float = 0.3453

## The longest car in the pack, in metres, and the widest. The pickup on both
## counts — see [code]src/world/mesh_car.gd[/code] — and the numbers are here
## rather than measured because what is being asked below is whether the concrete
## is big enough for the biggest thing that can be parked on it, which is a
## question about the drive and not about today's car.
const LONGEST_CAR: float = 5.19
const WIDEST_CAR: float = 2.07

var _garage: Garage = null


## One room for the whole file, because not one test below writes to it.
##
## [b]That is the safety condition, and it is the whole of it.[/b] A shared
## fixture is only shareable while every test that reads it leaves it exactly as
## it found it — press a button, spend a second, move a camera, and the suite
## quietly becomes order-dependent, which passes in file order and fails in any
## other. Everything here asks the ground how big it is and where its concrete
## stands; nothing here moves anything. Checked by running the file with its
## tests in reverse — see the note in [method after_all].
##
## What it buys, measured on a four-core box with this suite run on its own:
## 7.3 s to 1.8 s, of which about 0.9 s is Godot starting up either way. The room
## is `garage.tscn` entire — a driveway's worth of imported mesh, a wood, a car
## out of the pack — and building it fourteen times to ask fourteen questions
## about a driveway that never changes was the whole of the difference.
##
## [method add_child] rather than [method GutTest.add_child_autofree]: GUT's
## autofree list is emptied after every *test*, so a fixture registered with it
## in `before_all` is freed out from under test two. [method after_all] is where
## a fixture of this lifetime is freed, and it has to be — GUT warns about a test
## script that still has children when the file is done.
func before_all() -> void:
	var packed: PackedScene = load(GARAGE) as PackedScene
	assert_not_null(packed, "could not load %s" % GARAGE)
	if packed == null:
		return
	# Into a typed local first, for the reason tests/integration/test_garage.gd
	# gives: add_child is untyped.
	var garage: Garage = packed.instantiate() as Garage
	_garage = garage
	add_child(_garage)
	await wait_process_frames(1)


## [method Node.free] and not [method Node.queue_free]: GUT counts the test
## script's children the moment `after_all` returns, and a queued free has not
## happened yet — the room would be reported as a leak on its way out. This is
## the same call GUT's own autofree makes.
func after_all() -> void:
	if _garage != null:
		_garage.free()
		_garage = null


func _ground() -> Ground:
	return _garage.get_node("%Ground") as Ground


func _car() -> Car:
	return _garage.get_node("%Car") as Car


func test_the_room_stands_on_a_modeled_ground() -> void:
	assert_not_null(_ground(), "the garage needs a Ground under its world")


func test_the_concrete_is_the_room_s_own_floor() -> void:
	# The line src/world/ground.tscn exists to make true. The model is authored
	# about a point 0.127 m below the face a car parks on, and every car in the
	# pack is sat on whatever that face measures — so a placement that forgot the
	# offset would bury ten cars in the tarmac by the same 0.127 and nothing else
	# in the suite would say why.
	#
	# The floor is the pad, asked for with settle(), and not drive().end.y. Those
	# were the same assertion until #167 and they were never the same statement:
	# the concrete is a pad sunk between kerb walls, so the box round the mesh
	# tops out on the kerb and a room that treats the box's lid as the floor parks
	# its cars in mid-air. Both are pinned here, a third of a metre apart, so that
	# the sunken shape is a thing the suite says out loud rather than a surprise
	# waiting in the model.
	var pad: PackedFloat32Array = _ground().settle(PackedVector3Array([Vector3.ZERO]))
	assert_false(is_nan(pad[0]), "there must be concrete under the middle of the room")
	assert_almost_eq(pad[0], 0.0, TOLERANCE, "the pad must be the floor")
	assert_almost_eq(_ground().drive().end.y, KERB, TOLERANCE, "and the kerb must stand over it")


func test_the_concrete_is_centred_on_the_car() -> void:
	# The other two thirds of that placement. The pad's footprint is off its own
	# origin in both directions, so without the offsets the car would be parked a
	# hand's width to one side of its own drive and a third of a metre down it.
	var drive: AABB = _ground().drive()
	var middle: Vector3 = drive.position + drive.size * 0.5
	assert_almost_eq(middle.x, 0.0, 0.01, "the drive must be centred across the car")
	assert_almost_eq(middle.z, 0.0, 0.01, "the drive must be centred along the car")


func test_the_longest_car_in_the_pack_fits_on_the_drive() -> void:
	# What the concrete is for. The pack is 3.26 m of compact to 5.19 m of pickup
	# and the room parks whichever one the player picked, so the drive has to hold
	# the longest of them with room to walk round rather than the one that happens
	# to be standing there in this test.
	var drive: AABB = _ground().drive()
	assert_gt(drive.size.z, LONGEST_CAR, "the pickup must fit on the drive end to end")
	assert_gt(drive.size.x, WIDEST_CAR, "and across it")
	# And today's car really is on it, which is the same statement about the one
	# style that is actually parked.
	var car: AABB = _car().bounds()
	assert_gt(drive.size.z, car.size.z, "the parked car must fit on the drive")
	assert_gt(drive.size.x, car.size.x, "and across it")


func test_the_ground_runs_past_the_circle_the_camera_sweeps() -> void:
	# The fence the model was scaled to clear, and the reason the scale is 1.25
	# rather than the artist's own 1.0: at its own metres the ground reaches
	# 5.04 m either side of the drive and the camera circles at 5.6, so the eye
	# would spend four points of every lap looking in from past the edge of the
	# world. Asked of the garage rather than written down, so a shot that is
	# re-framed wider has to come back here.
	var box: AABB = _ground().extent()
	var half_width: float = minf(absf(box.position.x), box.end.x)
	var half_depth: float = minf(absf(box.position.z), box.end.z)
	assert_gt(half_width, _garage.orbit_radius, "the camera circle must fit across the ground")
	assert_gt(half_depth, _garage.orbit_radius, "and along it")


func test_the_walk_stands_on_concrete_and_not_on_the_lawn() -> void:
	# The second thing the scale buys, and the one a player would actually notice:
	# the first-person shot stands the eye 2.55 m from the middle of the car, and
	# at the model's own metres the pad is 2.35 m wide either side of the car —
	# so the player would be standing out on the grass looking over a kerb.
	var drive: AABB = _ground().drive()
	var eye: Vector3 = _garage.eye_position
	assert_lt(absf(eye.x), drive.end.x, "the eye must stand on the drive, not beside it")
	assert_lt(absf(eye.z), drive.end.z, "and not off the end of it")


func test_nothing_out_here_is_something_a_ray_can_hit() -> void:
	# The same promise the trees this replaced were held to, and it matters more
	# now: the room casts a ray for the camera's standoff and another for the aim
	# mark, and both are asking a question about the car. A bank of grass with a
	# body on it would answer them.
	#
	# The whole branch rather than the model's top node: collision comes in one
	# mesh at a time, from a `-col` suffix on a glTF node, so a re-import that
	# generated bodies would generate them down here.
	for node: Node in _ground().find_children("*", "", true, false):
		assert_null(node as CollisionObject3D, "%s is something a ray can hit" % node.name)
		assert_null(node as CollisionShape3D, "%s is a collision shape" % node.name)


func test_the_ground_is_drawn() -> void:
	# The failure the two boxes above cannot see: an import that brought in the
	# node tree and no meshes would satisfy every measurement made through
	# `extent()`… except that `extent()` is measured off the meshes, so it would
	# come back empty. Which is what this actually asserts — that there is
	# geometry, and that it is the size of a driveway rather than of a point.
	var box: AABB = _ground().extent()
	assert_gt(box.size.x, 10.0, "the ground must be a driveway's worth of mesh")
	assert_gt(box.size.z, 10.0, "in both directions")
	var drawn: int = 0
	for node: Node in _ground().find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh != null and mesh.mesh != null:
			drawn += 1
	assert_gt(drawn, 0, "the ground must be made of meshes")


func test_the_ground_is_a_scene_of_its_own() -> void:
	# It is instanced by the room and by nothing else today, but the split is the
	# point: the placement arithmetic lives beside the model rather than in the
	# room's scene file, so this has to stand up on its own.
	var packed: PackedScene = load(GROUND) as PackedScene
	assert_not_null(packed, "could not load %s" % GROUND)
	if packed == null:
		return
	var alone: Ground = packed.instantiate() as Ground
	assert_not_null(alone, "the ground scene must be a Ground")
	add_child_autofree(alone)
	await wait_process_frames(1)
	var pad: PackedFloat32Array = alone.settle(PackedVector3Array([Vector3.ZERO]))
	assert_false(is_nan(pad[0]), "the ground must carry its own concrete")
	assert_almost_eq(pad[0], 0.0, TOLERANCE, "on its own origin, wherever it stands")


func test_a_ground_that_cannot_find_its_concrete_says_so_with_an_empty_box() -> void:
	# The honest answer to having no measurement, and the same one
	# `Garage._hold_the_standoff` gives a ray that hit nothing. It matters because
	# the caller is `_park_the_car`: a wrong number here moves ten cars, and a
	# zero-size box is the version of being wrong that a test can see.
	var lost: Ground = Ground.new()
	autofree(lost)
	lost.concrete = NodePath("NoSuchNode")
	assert_eq(lost.drive().size, Vector3.ZERO, "no concrete is an empty box")
	assert_eq(lost.extent().size, Vector3.ZERO, "and nothing drawn is an empty box")
	var nowhere: PackedFloat32Array = lost.settle(PackedVector3Array([Vector3.ZERO]))
	assert_eq(nowhere.size(), 1, "one answer per spot asked about, always")
	assert_true(is_nan(nowhere[0]), "and nothing to stand on is NAN")


func test_the_ground_says_how_high_the_concrete_is_where_the_car_stands() -> void:
	# What settle() is for, asked in the one place the model's own shape makes
	# interesting. It measures the surface a thing standing here would rest on,
	# which in the middle of the drive is the concrete pad. [method drive] is a
	# different measurement of the same mesh — the whole slab as a single box —
	# and the slab is a sunken pad with kerb walls standing up either side of it,
	# so its box reaches from the bottom of the pad to the top of those walls. The
	# two therefore disagree by the depth of the sinking, and that is a fact about
	# the model rather than a bug in either measurement.
	#
	# IT IS ALSO, MEASURED, WHY THE PARKED CAR USED TO FLOAT. Garage._park_the_car
	# sat every car on drive().end.y — the top of the kerb, not the surface of the
	# pad — so the ten cars in the pack stood 0.345 m above the concrete they
	# looked parked on. #167 fixed it at both ends: the room asks settle() for the
	# surface under the car, and src/world/ground.tscn was re-placed off the
	# drivable face rather than off the kerb, which is what turned these two
	# numbers from a 0-over-a--0.345 into a 0.3453-over-a-0. The pair of them is
	# still the interesting thing and it is still the same distance apart, which
	# is the assertion that survives being re-placed again.
	var here: PackedFloat32Array = _ground().settle(PackedVector3Array([Vector3.ZERO]))
	var drive: AABB = _ground().drive()
	assert_false(is_nan(here[0]), "there must be concrete under the car")
	assert_almost_eq(here[0], 0.0, TOLERANCE, "the pad under the car is the room's floor")
	assert_almost_eq(drive.end.y, KERB, TOLERANCE, "and the slab's box tops out on the kerb")
	assert_between(here[0], drive.position.y, drive.end.y, "the pad is part of the slab")
	assert_lt(here[0], drive.end.y, "the pad is sunk below the top of the kerb it is let into")


func test_the_lawn_stands_above_the_drive_and_climbs_away_from_it() -> void:
	# The fact the trees are planted on and the reason a constant would not do.
	# The model is a pad let into a field that rises on every closed side, so a
	# spot out on a bank has to come back higher than the concrete does, and a
	# spot further out has to come back higher again. Two banks rather than one,
	# because a settle() that had its X and Z crossed would still pass on a single
	# sample taken down the middle.
	var drive: float = _ground().drive().end.y
	for side: float in [-1.0, 1.0]:
		var up: PackedFloat32Array = _ground().settle(
			PackedVector3Array([Vector3(side * 4.5, 0.0, 0.0), Vector3(side * 5.8, 0.0, 0.0)])
		)
		assert_false(is_nan(up[0]), "no ground on the near side of a bank")
		assert_false(is_nan(up[1]), "no ground on the crest of a bank")
		assert_gt(up[0], drive, "the lawn must stand above the drive")
		assert_gt(up[1], up[0], "and climb away from it")


func test_there_is_no_ground_past_the_edge_of_the_model() -> void:
	# The other half of settle()'s contract, and the half a caller can only get
	# wrong in one direction. The model's outer edge is a hard edge with sky past
	# it — no backdrop, nothing underneath — so "how high is the grass out there"
	# has to answer "there is no grass out there" rather than zero. A grove that
	# believed zero would plant a tree standing in mid-air off the side of the
	# world. Asked a metre past the ground's own reach, so it moves with the model.
	var box: AABB = _ground().extent()
	var past: PackedVector3Array = PackedVector3Array(
		[
			Vector3(box.end.x + 1.0, 0.0, 0.0),
			Vector3(box.position.x - 1.0, 0.0, 0.0),
			Vector3(0.0, 0.0, box.end.z + 1.0),
			Vector3(0.0, 0.0, box.position.z - 1.0),
		]
	)
	for height: float in _ground().settle(past):
		assert_true(is_nan(height), "the model grew ground past its own edge")


func test_asking_about_nothing_is_answered_with_nothing() -> void:
	# The empty call, which is worth a line because settle() walks 31,420
	# triangles before it can say anything and the caller with no spots to ask
	# about is a grove that planted no rows. It returns rather than walking them.
	assert_eq(_ground().settle(PackedVector3Array()).size(), 0, "no spots, no answers")
