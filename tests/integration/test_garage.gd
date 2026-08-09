## Integration test for the garage — the driveway, and the camera that circles
## it.
##
## Under tests/integration/ because everything here needs the scene to exist and
## a frame to happen: the camera is aimed in `_ready()` and moved in `_process`,
## and the point of most of these is that the engine really is driving it. The
## arithmetic underneath is [code]tests/unit/test_camera_orbit.gd[/code]'s job
## and is not repeated here.
extends GutTest

const GARAGE: String = "res://src/world/garage.tscn"

## Close enough for positions in metres — a tenth of a millimetre.
const TOLERANCE: float = 0.0001

var _garage: Garage = null

## The style the bay parked for itself, so [method before_each] can put it back
## after one of the arrow tests has shown a different one — see there.
var _style_before: String = ""


## One room for the whole file. Twenty-four rooms was twenty-four copies of a
## driveway's worth of imported mesh, a wood and a car out of the pack, and the
## great majority of what this file asks of one is where things are rather than
## what they do.
##
## [b]Two things move, and [method before_each] puts both of them back.[/b] That
## is the condition on sharing a fixture: a test that leaves the room changed
## couples the suite into an order-dependent one, which passes in file order and
## fails in any other. The two are [member Garage.orbiting], which one test
## switches off, and which of the ten is parked, which the arrow tests change on
## purpose. Checked by running the file with its tests in reverse.
##
## [b]What deliberately is not put back is the camera's angle round the car.[/b]
## Half the tests here drive [method Garage._process] to make it move — that is
## the point of them — and no assertion in the file is about where on the circle
## it ended up: they are about the distance it stands at, the thing it points at,
## and how far one second of it goes. The one test that really is about the first
## frame builds its own room, and says so.
##
## Measured on a four-core box with this suite run on its own: 13.4 s to 4.5 s,
## of which about 0.9 s is Godot starting up either way. It does not fall as far
## as the two suites next door because half of what is left is real waiting — the
## frames [method test_the_camera_moves_on_its_own] and its neighbours need, and
## the ten re-parkings [method test_a_car_parked_by_the_arrows_is_sat_on_the_tarmac_too]
## asks for.
##
## [method add_child] rather than [method GutTest.add_child_autofree]: GUT empties
## its autofree list after every *test*, so a fixture registered with it here
## would be freed out from under test two.
func before_all() -> void:
	_garage = _a_room()
	if _garage == null:
		return
	add_child(_garage)
	await wait_process_frames(1)
	var parked: MeshCar = _garage.car() as MeshCar
	_style_before = "" if parked == null else parked.style


## [method Node.free] and not [method Node.queue_free]: GUT counts the test
## script's children the moment `after_all` returns, and a queued free has not
## happened yet — the room would be reported as a leak on its way out.
func after_all() -> void:
	if _garage != null:
		_garage.free()
		_garage = null


## The explicit reset the shared room is worth, and deliberately only these two —
## see [method before_all] for what is not on the list and why.
##
## The re-park is skipped outright when the right car is already there, rather
## than left to [method Garage.show_style]'s own no-op, because of the frame
## below: this costs a rebuild and a frame after one of the arrow tests and
## nothing at all after the other twenty-one.
func before_each() -> void:
	if _garage == null:
		return
	_garage.orbiting = true
	var parked: MeshCar = _garage.car() as MeshCar
	if parked == null or parked.style == _style_before:
		return
	_garage.show_style(_style_before)
	# A frame, so the car it replaced is actually gone rather than queued — the
	# same wait test_grove.gd's replant makes, and for the same reason: without it
	# the felled panels are still alive when the test that follows finishes and
	# GUT reports twenty-one orphans against it.
	await wait_process_frames(1)


## A room, instanced but not yet in a tree — the caller adds it and decides how
## long it lives. [method before_all]'s room outlives every test in the file and
## so cannot go through GUT's autofree; the one test that builds its own wants
## exactly the opposite.
func _a_room() -> Garage:
	var packed: PackedScene = load(GARAGE) as PackedScene
	assert_not_null(packed, "could not load %s" % GARAGE)
	if packed == null:
		return null
	# Into a typed local first: add_child is untyped.
	var garage: Garage = packed.instantiate() as Garage
	return garage


func _camera() -> Camera3D:
	return _garage.get_node("%Camera") as Camera3D


func _car() -> Car:
	return _garage.get_node("%Car") as Car


## The ground the room is standing on, which is now a mesh and knows its own
## size.
func _ground() -> Ground:
	return _garage.get_node("%Ground") as Ground


## How far the car is from the outer edge of the modeled ground, read off the
## ground itself rather than written down again here. The narrower of the two
## sides, because the model is not perfectly square about its own drive and what
## hangs off this is an absolute value.
func _ground_half_width() -> float:
	var box: AABB = _ground().extent()
	return minf(absf(box.position.x), box.end.x)


## The height of the concrete under [param parked], read off the ground the same
## way [method Garage._park_the_car] reads it.
##
## Deliberately `settle()` at the car's own spot and not `drive().end.y`. The
## concrete is a pad sunk between kerb walls, so the box round the mesh tops out
## 0.345 m over the surface, and a test that read the box would have agreed with
## a room that parked ten cars in mid-air — which is exactly what happened until
## #167. Asking the same question the room asks is the whole point of reading it
## at all: they agree about where the concrete is because they both ask the
## concrete.
func _tarmac_under(parked: Car) -> float:
	return _ground().settle(PackedVector3Array([parked.global_position]))[0]


func test_the_room_instantiates() -> void:
	assert_not_null(_garage, "the garage must instantiate as a Garage")


func test_it_has_a_car_and_a_camera_to_look_at_it_with() -> void:
	assert_not_null(_car(), "the garage needs a car in it")
	assert_not_null(_camera(), "the garage needs a camera")
	assert_true(_camera().current, "the camera must be the one its viewport uses")


func test_the_camera_is_aimed_before_the_first_frame() -> void:
	# `_ready()` aims it, so whatever transform the scene file happens to have
	# saved never reaches the screen. Without this, a screen that never orbits
	# would show the camera's parked-at-the-origin view instead of the car.
	#
	# ON A ROOM OF ITS OWN, and it is the only test in this file that gets one.
	# "Before the first frame" is a claim about a room that has not had one, and
	# the shared room has had every frame the tests above it asked for — the aim
	# would still come out right, because it is recomputed every frame, and the
	# test would no longer be able to tell that apart from `_ready()` doing it.
	# One extra room out of twenty-four is what the claim costs.
	var fresh: Garage = _a_room()
	assert_not_null(fresh, "could not build a room that has not had a frame")
	if fresh == null:
		return
	add_child_autofree(fresh)
	var car: Node3D = fresh.get_node("%Car") as Node3D
	var eye: Camera3D = fresh.get_node("%Camera") as Camera3D
	var to_car: Vector3 = (car.global_position - eye.global_position).normalized()
	var looking: Vector3 = -eye.global_transform.basis.z
	assert_almost_eq(looking.dot(to_car), 1.0, TOLERANCE, "the camera must look at the car")


func test_the_camera_stands_the_orbit_distance_from_the_car() -> void:
	var eye: Vector3 = _camera().global_position
	var car: Vector3 = _car().global_position
	var flat: Vector2 = Vector2(eye.x - car.x, eye.z - car.z)
	assert_almost_eq(flat.length(), _garage.orbit_radius, TOLERANCE)
	assert_almost_eq(eye.y - car.y, _garage.orbit_height, TOLERANCE)


func test_the_camera_moves_on_its_own() -> void:
	# The one that proves the engine is driving this. Everything below calls
	# `_process` by hand for a number it can predict; if the node were not
	# processing at all, only this test would notice.
	var before: Vector3 = _camera().global_position
	await wait_process_frames(30)
	assert_gt(_camera().global_position.distance_to(before), 0.0, "the menu camera must turn")


func test_a_second_of_orbit_moves_it_the_width_of_a_second() -> void:
	# Called directly so the distance is a number rather than however many
	# frames the machine felt like giving us. The chord of the arc it sweeps:
	# two radii and the sine of half the angle.
	var before: Vector3 = _camera().global_position
	_garage._process(1.0)
	var half_sweep: float = deg_to_rad(_garage.orbit_degrees_per_second) * 0.5
	var chord: float = 2.0 * _garage.orbit_radius * sin(half_sweep)
	assert_almost_eq(_camera().global_position.distance_to(before), chord, TOLERANCE)


func test_it_keeps_looking_at_the_car_as_it_goes() -> void:
	# The aim is recomputed every frame, so a camera that circles but forgets to
	# turn — the classic version of this bug — fails here rather than in a build.
	_garage._process(7.5)
	var to_car: Vector3 = (_car().global_position - _camera().global_position).normalized()
	var looking: Vector3 = -_camera().global_transform.basis.z
	assert_almost_eq(looking.dot(to_car), 1.0, TOLERANCE)


func test_a_parked_camera_holds_still() -> void:
	# What the play screen turns off. Through the exported property rather than
	# by reaching into the orbit, because the property is the whole interface
	# the screens have to this scene.
	_garage.orbiting = false
	var before: Vector3 = _camera().global_position
	_garage._process(5.0)
	await wait_process_frames(10)
	assert_almost_eq(_camera().global_position.distance_to(before), 0.0, TOLERANCE)


func test_the_camera_never_orbits_off_the_edge_of_the_ground() -> void:
	# The camera circles the middle of the driveway at a fixed radius, so the
	# only thing keeping it over the modeled ground is that radius being the
	# smaller number. Nothing on screen would say it had stopped being true —
	# the view would just start showing empty space at two points in every turn.
	assert_lt(
		_garage.orbit_radius, _ground_half_width(), "the camera circle must fit on the ground"
	)


func test_the_room_orbits_unless_a_screen_says_otherwise() -> void:
	# The defaults are the title screen's shot, and the title screen overrides
	# nothing but the starting angle. If either of these flipped, the title card
	# would come up on a motionless view from somebody's eye socket.
	assert_true(_garage.orbiting, "the room's own shot is the slow circuit")
	assert_false(
		_garage.first_person, "standing on the driveway is the game's idea, not the room's"
	)
	assert_false(_garage.walkaround, "and so is walking about in it")
	# The play screen instances this same scene, and a demo working the car while
	# somebody is standing in it holding their own wand would be two players in one
	# bay. Playing itself is a thing a screen asks for, like everything else here.
	assert_false(_garage.attracting, "and so is playing itself while nobody is playing")


func test_steering_a_room_nobody_is_standing_in_is_ignored() -> void:
	# The title screen instances this same scene, and its camera is not anybody's
	# to drive. Asking anyway has to be a no-op rather than a crash on a drive
	# that was never built — the play screen calls `steer` every single frame, and
	# a screen that stopped being first person must not take the game down.
	#
	# Measured against the showcase circuit's own speed rather than against "it
	# did not move": the circuit is still turning underneath, and a steered camera
	# that moved by exactly the circuit's chord moved by nothing else.
	_garage.steer(1.0, 1.0)
	var before: Vector3 = _camera().global_position
	_garage._process(1.0)
	var half_sweep: float = deg_to_rad(_garage.orbit_degrees_per_second) * 0.5
	var chord: float = 2.0 * _garage.orbit_radius * sin(half_sweep)
	assert_almost_eq(_camera().global_position.distance_to(before), chord, TOLERANCE)


# ---- the car's collider: what the walkaround camera measures against ---------


func test_every_panel_of_the_car_is_something_a_ray_can_find() -> void:
	# Geometry is invisible to a raycast unless something arms it, and the standoff
	# would then measure nothing, find no hit, and hold whatever radius it started
	# with — a bug that looks exactly like the feature not being wired up. It used
	# to be one hand-built box shape that could go stale; it is now something each
	# panel has to carry, which can be forgotten one panel at a time.
	#
	# [method Car.panels] deliberately does not read that — see its docs: a panel
	# that cannot be hit has to fail here rather than quietly leave the car. So
	# this is where the parked car's half of the contract is held, and it is a
	# mesh-car assertion about a mesh car, cast to say so. The blockout's half is
	# `use_collision` and is held in `tests/integration/test_car.gd`.
	#
	# The shape, and not merely the body: a StaticBody3D with an empty
	# CollisionShape3D under it is a node the physics server knows about and a ray
	# passes straight through, which is the failure this is looking for.
	var panels: Array[Node3D] = _car().panels()
	assert_gt(panels.size(), 0, "the car needs panels")
	for panel: Node3D in panels:
		var body: StaticBody3D = panel as StaticBody3D
		assert_not_null(body, "%s is not a body; this test is about the mesh car" % panel.name)
		if body == null:
			continue
		var armed: int = 0
		for child: Node in body.get_children():
			var collider: CollisionShape3D = child as CollisionShape3D
			if collider != null and collider.shape != null:
				armed += 1
		assert_gt(armed, 0, "%s must be something a ray can hit" % panel.name)


func test_the_standoff_ray_finds_the_car_and_can_name_what_it_hit() -> void:
	# The whole reason the car is panels rather than one solid. `intersect_ray`
	# hands back the CSG root itself, so what comes out of a hit is the panel's
	# own node — which is what the grime this game is about will need in order to
	# dirty a bonnet without dirtying the wheels.
	#
	# Cast the way `_hold_the_standoff` casts it: level, at the car's own
	# mid-height, in at the middle of the car.
	# A frame for CSG to build its meshes, then a physics step for the bodies it
	# generated to be in the space a query can see.
	await wait_physics_frames(1)
	var focus: Vector3 = _car().global_position
	var probe: Vector3 = focus + Vector3(4.0, 0.0, 0.0)
	var space: PhysicsDirectSpaceState3D = _camera().get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(probe, focus))
	assert_false(hit.is_empty(), "a ray at the car's mid-height must find the car")
	if hit.is_empty():
		return
	# Checked against `panels()` rather than against a type: what point 4 of the
	# panel contract promises is that the collider IS a panel, and a mesh car's
	# would be a StaticBody3D rather than a CSGShape3D.
	var struck: Object = hit["collider"]
	var panel: Node3D = struck as Node3D
	assert_not_null(panel, "what a ray hits must be a node in the room")
	assert_true(_car().panels().has(panel), "what a ray hits must be a panel of the car")
	if panel != null:
		# Whichever of the ten is parked today. Mid-height on a car is the door
		# skin — below the glass and above the sill — on every style in the pack,
		# which is the property that lets the standoff measure a vertical face from
		# any eye height. A style whose greenhouse reached down to its own middle
		# would fail here, and would deserve to.
		assert_eq(panel.name, &"Body", "level at mid-height, side on, the ray meets the flank")


func test_the_car_is_sat_on_the_tarmac_and_not_in_it() -> void:
	# What Garage._park_the_car buys, and the thing the scene file used to say with
	# a single 0.7 that was really half the blockout's height. The ten styles are
	# 1.04 m to 1.77 m tall and all of them are authored about their own middle, so
	# a fixed lift sinks the tall ones and floats the short ones — 18 cm either
	# way, which is a wheel through the drive.
	#
	# The floor is read off the driveway rather than assumed to be zero, for the
	# same reason `_ground_half_width` reads the ground: the room is allowed to
	# move and this is a statement about the two of them together. It is the same
	# call `Garage._park_the_car` makes, which is the point — the room and this
	# test agree about where the concrete is because they ask the concrete.
	var tarmac: float = _tarmac_under(_car())
	var box: AABB = _car().bounds()
	assert_false(is_nan(tarmac), "there must be concrete under the car to park it on")
	assert_gt(box.size.y, 0.0, "a car with no box is not parked anywhere")
	assert_almost_eq(box.position.y, tarmac, TOLERANCE, "the tyres must be on the drive")


func test_the_room_hands_back_the_car_it_parked() -> void:
	# The accessor the menu picks its car through. Typed as [Car] on purpose — this
	# room hosts whichever car it is handed, and every fixture under
	# tests/fixtures/ is one — so what is asserted is that it is the same node the
	# unique name resolves to, not that it is a [MeshCar].
	assert_eq(_garage.car(), _car(), "the room must hand back the car standing in it")


func test_the_bay_can_park_a_different_one_of_the_ten() -> void:
	# What the menu's arrows drive. The room is already running by then — the car
	# is parked, the camera is aimed at it and the walk is measured from it — so
	# this is a swap under all of that rather than a second room.
	var parked: MeshCar = _garage.car() as MeshCar
	assert_not_null(parked, "the bay must park a MeshCar for a style to mean anything")
	if parked == null:
		return
	var other: String = CarChoice.stepped(parked.style, 1, MeshCar.STYLES)
	_garage.show_style(other)
	assert_eq(parked.style, other, "the bay ignored the style it was shown")
	assert_eq(_garage.car(), parked, "the car was replaced rather than restyled")


func test_a_car_parked_by_the_arrows_is_sat_on_the_tarmac_too() -> void:
	# The one thing a swap could not inherit from the car it replaced. Every style
	# is authored about its own mid-height and they are 1.04 m to 1.77 m tall, so a
	# car dropped in at the last one's height is up to 18 cm through the drive or
	# hovering over it. Garage.show_style re-parks for exactly this, and all ten are
	# walked because the pair that breaks it is whichever two are furthest apart.
	for style: String in MeshCar.STYLES:
		_garage.show_style(style)
		var tarmac: float = _tarmac_under(_garage.car())
		var box: AABB = _garage.car().bounds()
		assert_false(is_nan(tarmac), "no concrete under the %s to park it on" % style)
		assert_almost_eq(box.position.y, tarmac, TOLERANCE, "the %s is not on the drive" % style)


func test_showing_the_style_that_is_already_parked_changes_nothing() -> void:
	# The menu calls this on the way in with whatever the room drew, so the
	# no-op has to be a real one: a rebuild here would throw away the car the
	# player is looking at and put an identical one back, one frame later and one
	# paint colour along.
	var parked: MeshCar = _garage.car() as MeshCar
	if parked == null:
		return
	var panels: Array[Node3D] = parked.panels()
	var colour: Color = parked.paint.albedo_color
	_garage.show_style(parked.style)
	assert_eq(parked.panels(), panels, "the car was rebuilt for no reason")
	assert_eq(parked.paint.albedo_color, colour, "and repainted while it was at it")


func test_a_car_parked_by_the_arrows_is_still_something_a_ray_can_find() -> void:
	# Point 4 of the car contract, asked again after a swap. A restyle that left the
	# old bodies in the physics space — or built the new ones without shapes — is a
	# room where the standoff measures a car that is not there and every tool goes
	# through the paint. `remove_child` before `queue_free` is what makes the first
	# half of that true, and neither half is visible without a ray to ask.
	var parked: MeshCar = _garage.car() as MeshCar
	if parked == null:
		return
	_garage.show_style(CarChoice.stepped(parked.style, 1, MeshCar.STYLES))
	# A physics step, so the bodies the swap just built are in the space a query
	# can see — and the ones it removed are out of it.
	await wait_physics_frames(1)
	var focus: Vector3 = parked.global_position
	var probe: Vector3 = focus + Vector3(4.0, 0.0, 0.0)
	var space: PhysicsDirectSpaceState3D = _camera().get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(probe, focus))
	assert_false(hit.is_empty(), "a level ray missed the car the arrows parked")
	if hit.is_empty():
		return
	# Through an Object first: a Dictionary hands back Variant, and this project's
	# warning levels treat casting one straight to a node as unsafe.
	var struck: Object = hit["collider"]
	var panel: Node3D = struck as Node3D
	assert_true(parked.panels().has(panel), "the ray met a panel of the car that left")


func test_no_panel_is_scaled() -> void:
	# The rule the old hand-built collider existed to satisfy, now enforced across
	# every panel instead: a non-uniformly scaled shape is the one thing the
	# physics server asks not to be handed, and a panel's collider is generated
	# from the panel's own transform. The room's walls are unit boxes scaled into
	# place; the car is authored at its real size precisely so this never comes up.
	for panel: Node3D in _car().panels():
		var scaling: Vector3 = panel.global_transform.basis.get_scale()
		assert_almost_eq(
			scaling.distance_to(Vector3.ONE), 0.0, TOLERANCE, "%s is scaled" % panel.name
		)


func test_the_view_model_anchor_is_hidden_while_the_camera_circles() -> void:
	# Both screens instance this one scene, so the anchor is here on the title
	# screen too — and a tool hanging in the corner of an outside-in shot of a car
	# reads as a rendering fault, not as something being held. It exists and it is
	# switched off, and `is_visible_in_tree` rather than `visible` because what
	# matters is that nothing under it is drawn.
	var anchor: Node3D = _garage.get_node("%ViewModel") as Node3D
	assert_not_null(anchor, "the anchor is part of the room's scene, not the play screen's")
	assert_false(anchor.is_visible_in_tree(), "nobody is standing here to hold anything")


# ---- the sky: what is over the driveway, and what it is not allowed to light --


func _environment() -> Environment:
	var world: WorldEnvironment = _garage.get_node("View/World/Environment") as WorldEnvironment
	return world.environment


## Where the room puts the sun, or [constant Vector3.ZERO] if it does not say.
##
## Read off the [ShaderMaterial] in the scene, which is why `garage.tscn` sets
## this one uniform rather than leaving it at the shader's default like every
## other number in the look. A shader's compiled-in defaults are only readable
## through [method RenderingServer.shader_get_parameter_default], and under the
## headless server this suite and CI both run on, that answers `null` for
## everything — measured here, by writing the test that way first and watching
## it fail against a shader that was perfectly correct.
func _sky_sun_direction() -> Vector3:
	var sky: Sky = _environment().sky
	var material: ShaderMaterial = sky.sky_material as ShaderMaterial
	var raw: Variant = material.get_shader_parameter(&"sun_direction")
	if typeof(raw) != TYPE_VECTOR3:
		return Vector3.ZERO
	return raw


func test_the_driveway_has_a_sky_over_it() -> void:
	var environment: Environment = _environment()
	assert_eq(
		environment.background_mode,
		Environment.BG_SKY,
		"the room's background is a sky, not a flat colour"
	)
	assert_not_null(environment.sky, "BG_SKY with no Sky resource renders the clear colour")
	var material: ShaderMaterial = environment.sky.sky_material as ShaderMaterial
	assert_not_null(material, "the sky is this project's shader, not a built-in material")
	if material != null:
		assert_eq(material.shader.resource_path, "res://src/world/sky.gdshader")


func test_the_sky_is_a_backdrop_and_not_a_light() -> void:
	# The two lines that keep "add a sky" from silently becoming "relight the
	# whole game". Reflections off is the load-bearing one: its default is BG,
	# which starts mirroring the sky the moment the background becomes one, and
	# the first thing anyone would see is the power wash turning to chrome in
	# their own hands. `src/world/view_model.gd`'s class docs are the long
	# version, and this is what stops that paragraph from quietly going stale.
	var environment: Environment = _environment()
	assert_eq(
		environment.reflected_light_source,
		Environment.REFLECTION_SOURCE_DISABLED,
		"the sky must not become a radiance map behind anybody's back"
	)
	assert_eq(
		environment.ambient_light_source,
		Environment.AMBIENT_SOURCE_COLOR,
		"the ambient stays the tuned grey the strip lights were balanced against"
	)


func test_the_painted_sun_is_above_the_horizon() -> void:
	# The bug this exists to stop is the one that was found writing the shader,
	# and it is silent: a sun direction with a negative Y draws no disc and no
	# halo anywhere in the sky, because every part of the sky the player can see
	# is on the other side of the horizon from it. Nothing errors, nothing warns,
	# the sun is simply not there — which is exactly what happened when the disc
	# was aimed at the room's own `Key`, whose basis Z points 42° BELOW the
	# skyline. A number, not a screenshot somebody remembers taking.
	var sun: Vector3 = _sky_sun_direction()
	assert_gt(sun.length(), 0.0, "sun_direction must be a vec3 uniform with something in it")
	assert_gt(sun.y, 0.0, "a sun below the horizon is a sun nobody can see")
