## Integration test for the square a patch lights up when it finishes a step —
## [PatchFlash] on real panels, fed by [Grime].
##
## Split from [code]tests/integration/test_grime.gd[/code], which covers the same
## class's masks and the three passes over them. One file would be the obvious
## place for all of it and is over gdlint's public-method ceiling; the seam is the
## honest one, because everything here is about the half of a finished patch that
## is drawn rather than the half that is counted, and nothing there is.
##
## [b]What is being pinned is that the light and the ding cannot come apart.[/b]
## [GrimeMap] decides that a patch has finished, [Grime] emits
## [signal Grime.patch_finished] and lights the square from the same list, and the
## overlay samples that square through the same atlas coordinates it samples the
## mask through. Three files have to agree about a patch index for the right bit
## of car to flash, and the failure when they do not is not an error — it is a
## light in the wrong place, which reads as a projection bug and sends whoever
## finds it to [BoxProjection].
##
## The decay itself is [code]tests/unit/test_patch_flash.gd[/code]'s, for the
## reason that file records: it is arithmetic on a number handed in, and it does
## not need a car to run on. What is here is the wiring — that every panel got its
## own, that it is the shape the mask is diced into, and that something is driving
## the fade at all.
##
## On [code]tests/fixtures/plain_car.tscn[/code] and after a frame, for the two
## reasons [code]tests/integration/test_grime.gd[/code] gives at length: nothing
## here is a statement about the blockout, and a map built before the CSG is
## built is sized from a zero box.
extends GutTest

const CAR: String = "res://tests/fixtures/plain_car.tscn"

const TOLERANCE: float = 0.0001

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
	# The frame the class docs are about.
	await wait_process_frames(1)
	_grime.lay_on(_car)


## Every panel of [param kind], in the order the car lists them.
func _panels_of(kind: Surface.Kind) -> Array[Node3D]:
	var found: Array[Node3D] = []
	for panel: Node3D in _car.panels():
		if _car.kind_of(panel) == kind:
			found.append(panel)
	return found


## One panel of [param kind], or null if the car has none.
func _a_panel_of(kind: Surface.Kind) -> Node3D:
	var found: Array[Node3D] = _panels_of(kind)
	return null if found.is_empty() else found[0]


## The skin of a panel: the node its box and its overlay are actually on — see
## [method Car.skin_of], and its twin in
## [code]tests/integration/test_grime.gd[/code] for why it is asked of the car
## rather than assumed to be the panel.
func _skin(panel: Node3D) -> GeometryInstance3D:
	return _car.skin_of(panel)


## Where a panel's box actually is, in the room.
func _box_around(panel: Node3D) -> AABB:
	var skin: GeometryInstance3D = _skin(panel)
	return skin.global_transform * skin.get_aabb()


## The middle of the top of a panel, in world space — where a tool pointed down at
## the car from above would land.
func _on_top_of(panel: Node3D) -> Vector3:
	var box: AABB = _box_around(panel)
	return Vector3(box.get_center().x, box.end.y, box.get_center().z)


## A brush wide enough to cover a whole face of [param panel], so a test that
## wants a patch finished gets one whatever size the panel is — measured off the
## panel for the reason its twin in
## [code]tests/integration/test_grime.gd[/code] records.
func _whole_face_of(panel: Node3D) -> float:
	return _box_around(panel).size.length()


## Washes a panel flat from above, which is the only pass that finishes patches
## without needing one of the other two to have run first.
func _wash_flat(panel: Node3D) -> void:
	for _sweep: int in 60:
		_grime.wash(panel, _on_top_of(panel), Vector3.UP, _whole_face_of(panel), 0.1)


# ---- what got laid on ----------------------------------------------------------


func test_every_panel_gets_its_own_flashes_to_sample() -> void:
	# The same argument as the mask, and the same failure if it is shared: one
	# flash map across the car would light the matching square on all twelve panels
	# at once. Checked against the shader's uniform rather than against
	# [method Grime.flash_of], because the uniform is the one the game reads.
	var seen: Array[RID] = []
	for panel: Node3D in _car.panels():
		var paint: ShaderMaterial = _skin(panel).material_overlay as ShaderMaterial
		assert_not_null(paint, "%s has no grime material" % panel.name)
		if paint == null:
			continue
		var flashes: Texture2D = paint.get_shader_parameter("patch_flash")
		assert_not_null(flashes, "%s has no flash map" % panel.name)
		if flashes == null:
			continue
		assert_false(
			seen.has(flashes.get_rid()), "%s shares its flashes with another panel" % panel.name
		)
		seen.append(flashes.get_rid())


func test_the_flashes_are_diced_the_same_way_the_mask_is() -> void:
	# One grid, two consumers. The shader samples both maps through the same atlas
	# coordinates, so a flash image of a different shape would light the square
	# next to the one that rang — see [method GrimeMap.patch_grid].
	for panel: Node3D in _car.panels():
		var grid: Vector2i = _grime.map_of(panel).patch_grid()
		var image: Image = _grime.flash_of(panel).image()
		assert_eq(Vector2i(image.get_width(), image.get_height()), grid, String(panel.name))


func test_a_fresh_car_has_nothing_lit_on_it() -> void:
	for panel: Node3D in _car.panels():
		assert_eq(_grime.flash_of(panel).lit(), 0, String(panel.name))


func test_flashes_asked_for_on_something_that_is_not_the_car_are_absent() -> void:
	# A stray hit on the driveway, which is a normal thing for a player to produce.
	var stranger: Node3D = Node3D.new()
	add_child_autofree(stranger)
	assert_null(_grime.flash_of(stranger))


# ---- lighting up ---------------------------------------------------------------


func test_finishing_a_patch_lights_the_patch_it_finished() -> void:
	# The visual half of the ding, and the reason it is fed from where the signal
	# is emitted rather than from a listener: the square that lights and the bell
	# that rings are two uses of one list, so they cannot come apart.
	var hood: Node3D = _a_panel_of(Surface.Kind.BODY)
	assert_not_null(hood, "the car has no bodywork")
	if hood == null:
		return
	var rang: Array[int] = []
	_grime.patch_finished.connect(
		func(_named: String, patch: int, _stage: GrimeMap.Stage) -> void: rang.append(patch)
	)
	_wash_flat(hood)
	assert_gt(rang.size(), 0, "washing the bonnet flat never finished a patch")
	if rang.is_empty():
		return
	var flash: PatchFlash = _grime.flash_of(hood)
	assert_eq(flash.lit(), rang.size(), "a different number of squares lit than patches rang")
	for patch: int in rang:
		assert_almost_eq(
			flash.level(patch), 1.0, TOLERANCE, "patch %d rang but did not light" % patch
		)


func test_a_square_lit_by_the_water_says_it_was_the_water() -> void:
	# Three passes, three colours — see `flash_tint` in `grime.gdshader`. A stage
	# that did not survive the trip from the signal to the pixel would pop the
	# wrong colour, which is the kind of wrong nothing errors about.
	var hood: Node3D = _a_panel_of(Surface.Kind.BODY)
	assert_not_null(hood, "the car has no bodywork")
	if hood == null:
		return
	var rang: Array[int] = []
	_grime.patch_finished.connect(
		func(_named: String, patch: int, _stage: GrimeMap.Stage) -> void: rang.append(patch)
	)
	_wash_flat(hood)
	assert_gt(rang.size(), 0, "washing the bonnet flat never finished a patch")
	if rang.is_empty():
		return
	assert_almost_eq(_grime.flash_of(hood).stage_at(rang[0]), 0.0, TOLERANCE)


func test_washing_the_bonnet_lights_nothing_on_the_boot_lid() -> void:
	# [code]test_grime.gd[/code]'s central assertion, asked of the light rather
	# than of the mask: two panels of the same kind, because a shared flash map
	# would be likeliest between the panels a projection treats alike.
	var body: Array[Node3D] = _panels_of(Surface.Kind.BODY)
	assert_gt(body.size(), 1, "the car needs two body panels for this to mean anything")
	if body.size() < 2:
		return
	_wash_flat(body[0])
	assert_gt(_grime.flash_of(body[0]).lit(), 0, "the bonnet did not light at all")
	assert_eq(_grime.flash_of(body[1]).lit(), 0, "the boot lid lit up too")


# ---- going out again -----------------------------------------------------------


func test_the_flashes_go_out_on_their_own() -> void:
	# The one thing in [Grime] that runs on a clock. Driven by frames rather than by
	# calling [method PatchFlash.fade] directly, because what is being pinned is
	# that [method Grime._process] is wired to it at all — the unit tests already
	# own the decay itself.
	var hood: Node3D = _a_panel_of(Surface.Kind.BODY)
	assert_not_null(hood, "the car has no bodywork")
	if hood == null:
		return
	_wash_flat(hood)
	assert_gt(_grime.flash_of(hood).lit(), 0, "nothing lit up to go out again")
	# Comfortably longer than [constant PatchFlash.SECONDS] at any frame rate CI
	# runs at, and bounded rather than a `while`: a test that can hang is a job
	# that times out with no output.
	for _frame: int in 120:
		await wait_process_frames(1)
		if _grime.flash_of(hood).lit() == 0:
			break
	assert_eq(_grime.flash_of(hood).lit(), 0, "the squares never went out")
