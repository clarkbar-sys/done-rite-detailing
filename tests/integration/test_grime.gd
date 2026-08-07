## Integration test for [Grime] — the mud on a car, with real panels under it.
##
## [b]On [code]tests/fixtures/plain_car.tscn[/code] rather than on the game's own
## car.[/b] Nothing here is a statement about the blockout: that a hit reaches the
## right map, that a bottle needs bare paint, that each panel is told what its
## product looks like — all of it is true of any car with a panel, a window and a
## wheel. Running it against [code]src/world/car.tscn[/code] bought nothing and
## cost a suite full of [code]"Hood"[/code] and [code]"WheelFrontLeft"[/code],
## which is a suite that goes red the day somebody renames a panel for reasons
## that have nothing to do with grime. The fixture's own docs have the split, and
## [code]tests/integration/test_car.gd[/code] is the contract that stops this file
## passing while the real car has lost its groups.
##
## Panels are asked for by [enum Surface.Kind] rather than by name even so. There
## is no reason for this file to know what the fixture calls its slabs either.
##
## Under tests/integration/ for the reason [code]tests/integration/test_car.gd[/code]
## is: every map here is sized from a panel's own box, the fixture's panels are
## CSG, CSG meshes are built deferred, and a car asked before a frame has passed
## reports panels with no size at all. That trap is the whole reason
## [method Garage._lay_on_the_grime] waits, and it is pinned by its own test
## below rather than left to be rediscovered.
##
## The three passes are here too, for the same reason: what a wash, a cleaner and
## a rag [i]do[/i] to a texel is [GrimeMap]'s business and is tested there, but
## that a bottle reaches the right panel with the right product on it is wiring,
## and wiring is what breaks between a scene file and a shader.
##
## What is [i]not[/i] here is the arithmetic — where a point lands in a mask and
## what a wash does to it are [code]tests/unit/test_box_projection.gd[/code] and
## [code]tests/unit/test_grime_map.gd[/code]. This is about the wiring: that
## every panel got one, that a world-space hit reaches the right one, and that
## the overlay went on without taking the paint off.
extends GutTest

const CAR: String = "res://tests/fixtures/plain_car.tscn"

## Every kind the fixture carries, so a loop over "all of them" cannot quietly
## stop covering one.
const KINDS: Array[Surface.Kind] = [Surface.Kind.BODY, Surface.Kind.GLASS, Surface.Kind.WHEEL]

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


## Every panel of [param kind], in the order the car lists them.
func _panels_of(kind: Surface.Kind) -> Array[Node3D]:
	var found: Array[Node3D] = []
	for panel: Node3D in _car.panels():
		if _car.kind_of(panel) == kind:
			found.append(panel)
	return found


## One panel of [param kind], or null if the car has none — which is a failure
## worth reporting rather than a crash, so every caller asserts on it.
func _a_panel_of(kind: Surface.Kind) -> Node3D:
	var found: Array[Node3D] = _panels_of(kind)
	return null if found.is_empty() else found[0]


## A brush wide enough to cover a whole face of [param panel], so a test that
## wants a patch finished gets one whatever size the panel is.
##
## Measured off the panel rather than written down, and that is not fussiness: a
## patch is a fraction of a panel's own box, so 0.6 m covers one comfortably on a
## bonnet and does not reach the corner of one on the car's whole shell. A fixed
## radius here silently stopped finishing patches the moment these tests started
## asking for "a body panel" instead of naming the bonnet.
func _whole_face_of(panel: Node3D) -> float:
	return _box_around(panel).size.length()


## The skin of a panel: the node its box and its overlay are actually on — see
## [method Car.skin_of]. Asked of the car rather than assumed to be the panel,
## because that is the whole of what this issue widened and a test that reached
## straight past it for the panel's own overlay would go on passing after it
## stopped being true.
func _skin(panel: Node3D) -> GeometryInstance3D:
	return _car.skin_of(panel)


## Where a panel's box actually is, in the room.
func _box_around(panel: Node3D) -> AABB:
	var skin: GeometryInstance3D = _skin(panel)
	return skin.global_transform * skin.get_aabb()


# ---- what got laid on ---------------------------------------------------------


func test_every_panel_of_the_car_has_mud_on_it() -> void:
	assert_true(_grime.is_laid(), "grime was laid at all")
	assert_eq(
		_grime.panels().size(), _car.panels().size(), "one map per panel, no more and no less"
	)
	for panel: Node3D in _car.panels():
		assert_not_null(_grime.map_of(panel), "%s has no map" % panel.name)


func test_every_kind_of_surface_has_a_panel_with_a_map_on_it() -> void:
	# The point of a car being panels rather than one solid: paint, glass and
	# rubber are separately addressable, which is what the tools route on. By
	# kind and not by name, so this says what it means rather than listing the
	# fixture's furniture back at it.
	for kind: Surface.Kind in KINDS:
		var panel: Node3D = _a_panel_of(kind)
		assert_not_null(panel, "the car has no panel of kind %d" % kind)
		if panel != null:
			assert_not_null(_grime.map_of(panel), "%s has no map" % panel.name)


func test_a_fresh_car_is_entirely_filthy() -> void:
	assert_almost_eq(_grime.remaining(), 1.0, 0.0001)


func test_a_map_is_sized_from_the_panel_it_is_on() -> void:
	# The deferred-build trap, stated as a test. A map built a frame too early is
	# sized from a zero box, and every wash on it would land in the same texel.
	for panel: Node3D in _car.panels():
		var box: AABB = _grime.map_of(panel).box()
		assert_gt(box.size.length(), 0.0, "%s got a zero-sized map" % panel.name)
		assert_eq(box, _skin(panel).get_aabb(), "%s's map is not its own box" % panel.name)


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
	var wheel: Node3D = _a_panel_of(Surface.Kind.WHEEL)
	assert_not_null(wheel, "the car has no wheel")
	if wheel == null:
		return
	assert_not_null(_skin(wheel).material_overlay, "no grime on the wheel")
	assert_null(_skin(wheel).material_override, "the wheel's own materials were replaced")


func test_every_panel_gets_its_own_mask_to_sample() -> void:
	# One texture each. A shared one would be twelve panels showing the same mud
	# and washing all of them at once, which reads as a lighting bug rather than
	# as a shared texture.
	var seen: Array[RID] = []
	for panel: Node3D in _car.panels():
		var paint: ShaderMaterial = _skin(panel).material_overlay as ShaderMaterial
		assert_not_null(paint, "%s has no grime material" % panel.name)
		if paint == null:
			continue
		var mask: Texture2D = paint.get_shader_parameter("grime_mask")
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
	for panel: Node3D in _car.panels():
		var paint: ShaderMaterial = _skin(panel).material_overlay as ShaderMaterial
		if paint == null:
			continue
		var box: AABB = _grime.map_of(panel).box()
		var origin: Vector3 = paint.get_shader_parameter("box_origin")
		var size: Vector3 = paint.get_shader_parameter("box_size")
		assert_eq(origin, box.position, String(panel.name))
		assert_eq(size, box.size, String(panel.name))


# ---- washing it ---------------------------------------------------------------


func test_a_world_space_hit_washes_the_panel_it_landed_on() -> void:
	var hood: Node3D = _a_panel_of(Surface.Kind.BODY)
	assert_not_null(hood, "the car has no bodywork")
	if hood == null:
		return
	var box: AABB = _box_around(hood)
	var on_top: Vector3 = Vector3(box.get_center().x, box.end.y, box.get_center().z)
	var before: float = _grime.map_of(hood).remaining()
	_grime.wash(hood, on_top, Vector3.UP, 0.3, 0.9)
	assert_lt(_grime.map_of(hood).remaining(), before, "the bonnet did not get washed")


func test_washing_the_bonnet_leaves_the_boot_lid_alone() -> void:
	# The whole feature in one assertion, and the thing that would be impossible
	# to see from any single camera angle if it were wrong.
	# Two panels of the same kind, deliberately: a shared map would be likeliest
	# between the panels a projection treats alike.
	var body: Array[Node3D] = _panels_of(Surface.Kind.BODY)
	assert_gt(body.size(), 1, "the car needs two body panels for this to mean anything")
	if body.size() < 2:
		return
	var hood: Node3D = body[0]
	var deck: Node3D = body[1]
	var box: AABB = _box_around(hood)
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
	var hood: Node3D = _a_panel_of(Surface.Kind.BODY)
	assert_not_null(hood, "the car has no bodywork")
	if hood == null:
		return
	# Collected off the signal itself rather than through `watch_signals`, because
	# what is being asserted is the panel *name* that came with it — the patch
	# index is the map's own business and a test that pinned it would go red the
	# first time somebody turned the ding's granularity up.
	var rang: Array[String] = []
	_grime.patch_finished.connect(
		func(panel: String, _patch: int, _stage: GrimeMap.Stage) -> void: rang.append(panel)
	)
	var box: AABB = _box_around(hood)
	var on_top: Vector3 = Vector3(box.get_center().x, box.end.y, box.get_center().z)
	var rung: int = 0
	for _sweep: int in 60:
		rung += _grime.wash(hood, on_top, Vector3.UP, _whole_face_of(hood), 0.1)
	assert_gt(rung, 0, "washing the bonnet flat never finished a patch")
	assert_eq(rang.size(), rung, "every finished patch was announced exactly once")
	assert_eq(rang[0], String(hood.name), "and it said which panel it was on")


# ---- the three passes, on real panels -----------------------------------------


## Washes a panel flat at a point, so the passes after the first have bare paint
## to work on.
func _wash_bare(panel: Node3D, at: Vector3, outward: Vector3) -> void:
	for _sweep: int in 60:
		_grime.wash(panel, at, outward, 0.5, 0.2)


## The middle of the top of a panel, in world space — where a tool pointed down at
## the car from above would land.
func _on_top_of(panel: Node3D) -> Vector3:
	var box: AABB = _box_around(panel)
	return Vector3(box.get_center().x, box.end.y, box.get_center().z)


func test_a_cleaner_covers_the_paint_the_wash_bared() -> void:
	var hood: Node3D = _a_panel_of(Surface.Kind.BODY)
	assert_not_null(hood, "the car has no bodywork")
	if hood == null:
		return
	var on_top: Vector3 = _on_top_of(hood)
	_wash_bare(hood, on_top, Vector3.UP)
	_grime.foam(hood, on_top, Vector3.UP, 0.3, 0.9)
	assert_gt(_grime.map_of(hood).product(), 0.0, "the sponge left nothing on the bonnet")


func test_a_cleaner_on_a_muddy_panel_does_nothing() -> void:
	# The ordering rule, through the real stack rather than on a bare map: a
	# bottle on a car nobody has washed moves nothing, because there is no bare
	# paint under it to cover.
	var deck: Node3D = _a_panel_of(Surface.Kind.BODY)
	assert_not_null(deck, "the car has no bodywork")
	if deck == null:
		return
	assert_eq(_grime.foam(deck, _on_top_of(deck), Vector3.UP, 0.3, 1.0), 0)
	assert_almost_eq(_grime.map_of(deck).product(), 0.0, 0.0001)
	assert_almost_eq(_grime.map_of(deck).remaining(), 1.0, 0.0001, "and it took mud off")


func test_the_rag_turns_that_product_into_shine() -> void:
	var hood: Node3D = _a_panel_of(Surface.Kind.BODY)
	assert_not_null(hood, "the car has no bodywork")
	if hood == null:
		return
	var on_top: Vector3 = _on_top_of(hood)
	_wash_bare(hood, on_top, Vector3.UP)
	_grime.foam(hood, on_top, Vector3.UP, 0.3, 0.9)
	var covered: float = _grime.map_of(hood).product()
	_grime.buff(hood, on_top, Vector3.UP, 0.3, 0.9)
	assert_almost_eq(
		_grime.map_of(hood).shine(), covered, 0.0001, "the shine is not the product that was on it"
	)
	assert_gt(_grime.shine(), 0.0, "and the car as a whole noticed")


func test_finishing_a_patch_says_which_step_it_was() -> void:
	# One signal, three stages. A listener that wants to tell a wash from a buff
	# has the argument to do it with — and the ding, which does not care, ignores
	# it.
	var hood: Node3D = _a_panel_of(Surface.Kind.BODY)
	assert_not_null(hood, "the car has no bodywork")
	if hood == null:
		return
	var stages: Array[GrimeMap.Stage] = []
	_grime.patch_finished.connect(
		func(_named: String, _patch: int, stage: GrimeMap.Stage) -> void: stages.append(stage)
	)
	var on_top: Vector3 = _on_top_of(hood)
	for _sweep: int in 60:
		_grime.wash(hood, on_top, Vector3.UP, _whole_face_of(hood), 0.1)
	assert_true(stages.has(GrimeMap.Stage.WASHED), "washing a patch flat announced no stage")
	assert_false(stages.has(GrimeMap.Stage.BUFFED), "and something claimed to be finished")


# ---- what each panel is made of ------------------------------------------------


func test_each_panel_is_told_what_its_cleaner_looks_like() -> void:
	# The whole of "one channel, three products": the mask has nowhere to record
	# which bottle left the film, so the colour is a uniform set per panel when
	# the overlay is built. A panel that never got one would draw its suds in
	# whatever the shader defaults to, which is white on a tyre.
	for panel: Node3D in _car.panels():
		var paint: ShaderMaterial = _skin(panel).material_overlay as ShaderMaterial
		assert_not_null(paint, "%s has no grime material" % panel.name)
		if paint == null:
			continue
		var colour: Color = paint.get_shader_parameter("product_colour")
		assert_eq(
			colour,
			Surface.product_colour(_car.kind_of(panel)),
			"%s got the wrong product" % panel.name
		)


func test_the_glass_and_the_wheels_get_their_own_products() -> void:
	# And that a panel's group actually reached the shader, which is the one link
	# in that chain nothing else here would notice breaking. That the *real* car
	# still carries those groups is `tests/integration/test_car.gd`'s job.
	assert_eq(_product_on(Surface.Kind.GLASS), Surface.GLASS_PRODUCT, "the glass")
	assert_eq(_product_on(Surface.Kind.WHEEL), Surface.WHEEL_PRODUCT, "the wheel")
	assert_eq(_product_on(Surface.Kind.BODY), Surface.BODY_PRODUCT, "the bodywork")


## The product colour the overlay on a panel of [param kind] was actually handed.
## Read out into a typed local because [method ShaderMaterial.get_shader_parameter]
## hands back a [Variant], and this project's warning levels treat passing one to
## a typed parameter as an error rather than as a cast.
func _product_on(kind: Surface.Kind) -> Color:
	var panel: Node3D = _a_panel_of(kind)
	if panel == null:
		return Color.TRANSPARENT
	var paint: ShaderMaterial = _skin(panel).material_overlay as ShaderMaterial
	if paint == null:
		return Color.TRANSPARENT
	var colour: Color = paint.get_shader_parameter("product_colour")
	return colour
