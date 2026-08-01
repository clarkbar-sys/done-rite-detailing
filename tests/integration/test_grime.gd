## Integration test for [Grime] — the mud on the real car, with real panels
## under it.
##
## Under tests/integration/ for the reason [code]tests/integration/test_car.gd[/code]
## is: every map here is sized from a panel's [method CSGShape3D.get_aabb], CSG
## meshes are built deferred, and a car asked before a frame has passed reports
## panels with no size at all. That trap is the whole reason
## [method Garage._lay_on_the_grime] waits, and it is pinned by its own test
## below rather than left to be rediscovered.
##
## What is [i]not[/i] here is the arithmetic — where a point lands in a mask and
## what a wash does to it are [code]tests/unit/test_box_projection.gd[/code] and
## [code]tests/unit/test_grime_map.gd[/code]. This is about the wiring: that
## every panel got one, that a world-space hit reaches the right one, and that
## the overlay went on without taking the paint off.
extends GutTest

const CAR: String = "res://src/world/car.tscn"

## Panels the blockout has had since it replaced the green box, named so that a
## map going missing on one of them is a failure with the panel's name in it.
const NAMED: Array[String] = ["Body", "Hood", "Roof", "Windshield", "WheelFrontLeft"]

var _car: Car = null
var _grime: Grime = null


func before_each() -> void:
	var packed: PackedScene = load(CAR) as PackedScene
	assert_not_null(packed, "could not load %s" % CAR)
	if packed == null:
		return
	var car: Car = packed.instantiate() as Car
	_car = car
	add_child_autofree(_car)
	_grime = Grime.new()
	add_child_autofree(_grime)
	# The frame the class docs are about. Every measurement below is taken
	# against panels that have been built.
	await wait_process_frames(1)
	_grime.lay_on(_car)


func _panel(named: String) -> CSGShape3D:
	for panel: CSGShape3D in _car.panels():
		if String(panel.name) == named:
			return panel
	return null


# ---- what got laid on ---------------------------------------------------------


func test_every_panel_of_the_car_has_mud_on_it() -> void:
	assert_true(_grime.is_laid(), "grime was laid at all")
	assert_eq(
		_grime.panels().size(), _car.panels().size(), "one map per panel, no more and no less"
	)
	for panel: CSGShape3D in _car.panels():
		assert_not_null(_grime.map_of(panel), "%s has no map" % panel.name)


func test_the_panels_a_detailer_would_name_are_among_them() -> void:
	# The point of the CSG blockout being panels rather than one solid: the mud is
	# on the bonnet and the windscreen by name, which is what the tools are going
	# to route on.
	for named: String in NAMED:
		var panel: CSGShape3D = _panel(named)
		assert_not_null(panel, "the car has no %s" % named)
		if panel != null:
			assert_not_null(_grime.map_of(panel), "%s has no map" % named)


func test_a_fresh_car_is_entirely_filthy() -> void:
	assert_almost_eq(_grime.remaining(), 1.0, 0.0001)


func test_a_map_is_sized_from_the_panel_it_is_on() -> void:
	# The deferred-build trap, stated as a test. A map built a frame too early is
	# sized from a zero box, and every wash on it would land in the same texel.
	for panel: CSGShape3D in _car.panels():
		var box: AABB = _grime.map_of(panel).box()
		assert_gt(box.size.length(), 0.0, "%s got a zero-sized map" % panel.name)
		assert_eq(box, panel.get_aabb(), "%s's map is not its own box" % panel.name)


func test_grime_that_was_never_laid_on_a_car_says_so() -> void:
	# The title screen's showcase room never lays any — nobody is standing in it
	# to wash anything — so every caller has to be able to ask.
	var bare: Grime = Grime.new()
	add_child_autofree(bare)
	assert_false(bare.is_laid())
	assert_eq(bare.panels().size(), 0)
	assert_almost_eq(bare.remaining(), 0.0, 0.0001)


# ---- the overlay --------------------------------------------------------------


func test_the_mud_is_drawn_over_the_paint_rather_than_instead_of_it() -> void:
	# An overlay and not an override, which is what keeps a wheel a near-black
	# tyre with a silver rim instead of one flat colour — see the class docs.
	# Asserted on the wheel specifically, because it is the panel with two
	# materials in it and so the only one where the difference shows.
	var wheel: CSGShape3D = _panel("WheelFrontLeft")
	assert_not_null(wheel, "the car has no WheelFrontLeft")
	if wheel == null:
		return
	assert_not_null(wheel.material_overlay, "no grime on the wheel")
	assert_null(wheel.material_override, "the wheel's own materials were replaced")


func test_every_panel_gets_its_own_mask_to_sample() -> void:
	# One texture each. A shared one would be twelve panels showing the same mud
	# and washing all of them at once, which reads as a lighting bug rather than
	# as a shared texture.
	var seen: Array[RID] = []
	for panel: CSGShape3D in _car.panels():
		var paint: ShaderMaterial = panel.material_overlay as ShaderMaterial
		assert_not_null(paint, "%s has no grime material" % panel.name)
		if paint == null:
			continue
		var mask: Texture2D = paint.get_shader_parameter("mud_mask")
		assert_not_null(mask, "%s has no mask" % panel.name)
		if mask == null:
			continue
		assert_false(seen.has(mask.get_rid()), "%s shares its mask with another panel" % panel.name)
		seen.append(mask.get_rid())


func test_the_shader_is_told_the_box_it_has_to_project_into() -> void:
	# The one place two files have to agree about arithmetic: the shader repeats
	# the projection the CPU paints with, and it can only do that if it is handed
	# the same box. A panel whose uniforms disagreed with its map would draw the
	# mud somewhere other than where the water is taking it off.
	for panel: CSGShape3D in _car.panels():
		var paint: ShaderMaterial = panel.material_overlay as ShaderMaterial
		if paint == null:
			continue
		var box: AABB = _grime.map_of(panel).box()
		var origin: Vector3 = paint.get_shader_parameter("box_origin")
		var size: Vector3 = paint.get_shader_parameter("box_size")
		assert_eq(origin, box.position, String(panel.name))
		assert_eq(size, box.size, String(panel.name))


# ---- washing it ---------------------------------------------------------------


func test_a_world_space_hit_washes_the_panel_it_landed_on() -> void:
	var hood: CSGShape3D = _panel("Hood")
	assert_not_null(hood, "the car has no Hood")
	if hood == null:
		return
	var box: AABB = hood.global_transform * hood.get_aabb()
	var on_top: Vector3 = Vector3(box.get_center().x, box.end.y, box.get_center().z)
	var before: float = _grime.map_of(hood).remaining()
	_grime.wash(hood, on_top, Vector3.UP, 0.3, 0.9)
	assert_lt(_grime.map_of(hood).remaining(), before, "the bonnet did not get washed")


func test_washing_the_bonnet_leaves_the_boot_lid_alone() -> void:
	# The whole feature in one assertion, and the thing that would be impossible
	# to see from any single camera angle if it were wrong.
	var hood: CSGShape3D = _panel("Hood")
	var deck: CSGShape3D = _panel("Deck")
	assert_not_null(hood, "the car has no Hood")
	assert_not_null(deck, "the car has no Deck")
	if hood == null or deck == null:
		return
	var box: AABB = hood.global_transform * hood.get_aabb()
	_grime.wash(
		hood, Vector3(box.get_center().x, box.end.y, box.get_center().z), Vector3.UP, 0.4, 1.0
	)
	assert_almost_eq(_grime.map_of(deck).remaining(), 1.0, 0.0001)


func test_washing_something_that_is_not_the_car_does_nothing() -> void:
	# A tool pointed at the driveway. Zero rather than an error: "you missed" is
	# a normal thing for a player to do, not a bug.
	var stranger: Node3D = Node3D.new()
	add_child_autofree(stranger)
	assert_eq(_grime.wash(stranger, Vector3.ZERO, Vector3.UP, 0.2, 1.0), 0)


func test_finishing_a_patch_says_which_panel_it_was_on() -> void:
	var hood: CSGShape3D = _panel("Hood")
	assert_not_null(hood, "the car has no Hood")
	if hood == null:
		return
	# Collected off the signal itself rather than through `watch_signals`, because
	# what is being asserted is the panel *name* that came with it — the patch
	# index is the map's own business and a test that pinned it would go red the
	# first time somebody turned the ding's granularity up.
	var rang: Array[String] = []
	_grime.patch_cleared.connect(func(panel: String, _patch: int) -> void: rang.append(panel))
	var box: AABB = hood.global_transform * hood.get_aabb()
	var on_top: Vector3 = Vector3(box.get_center().x, box.end.y, box.get_center().z)
	var rung: int = 0
	for _sweep: int in 60:
		rung += _grime.wash(hood, on_top, Vector3.UP, 0.6, 0.1)
	assert_gt(rung, 0, "washing the bonnet flat never finished a patch")
	assert_eq(rang.size(), rung, "every finished patch was announced exactly once")
	assert_eq(rang[0], "Hood", "and it said which panel it was on")
