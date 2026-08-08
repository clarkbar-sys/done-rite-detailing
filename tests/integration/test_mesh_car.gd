## Integration test for the mesh car — the ten real models, wrapped into the
## panels the rest of the game washes.
##
## [b]Every test in here runs over all ten styles.[/b] That is the whole point of
## the file: a mesh car is not one scene somebody authored, it is a rule applied
## to ten [code].glb[/code]s that were baked by a script, and a suite that checked
## the sedan would go green on the day the coupe lost its wheels. So the loops are
## over [constant MeshCar.STYLES], and the failure message always names the style.
##
## Under tests/integration/ because a car has to be in a tree to be built at all —
## [method MeshCar._build] runs in [method Node._ready]. It is deliberately
## [i]not[/i] under an [code]await[/code]: a [MeshInstance3D] has its box the
## moment it is in the tree, which is the half of the panel contract the blockout
## cannot demonstrate and [code]tests/integration/test_car_panel_contract.gd[/code]
## pins on a fixture. This is the same claim against the real models — see
## [method test_the_bounds_are_exact_on_the_frame_the_car_arrives].
##
## What is checked elsewhere: the colliders and everything a ray does with them are
## [code]tests/integration/test_mesh_car_hits.gd[/code], because they need the
## physics clock and nothing here does.
extends GutTest

const SCENE: String = "res://src/world/mesh_car.tscn"

## Where the pack lives, so the list of styles can be checked against the files
## rather than against itself.
const PACK_DIR: String = "res://assets/models/cars/"

## The seven parts every style is baked into, in the order
## [code]scripts/build-car-pack.py[/code] writes them.
const PARTS: Array[String] = ["Body", "Glass", "Optics", "Wheel1", "Wheel2", "Wheel3", "Wheel4"]

const WHEELS: Array[String] = ["Wheel1", "Wheel2", "Wheel3", "Wheel4"]

## The look this game settled on for glass in #58, and the numbers
## [code]tests/fixtures/blockout_car.tscn[/code] gives the blockout's windows.
const GLASS_COLOR: Color = Color(0.35, 0.62, 0.58, 1.0)

## A centimetre. The same tolerance [code]tests/integration/test_car.gd[/code]
## uses and for the same reason: these are shapes being asserted, not formulas.
const TOLERANCE: float = 0.01

## What a car is allowed to measure, in metres. Deliberately wide bands rather
## than ten sets of exact numbers — the pack's own proportions are the design
## decision (see [code]scripts/build-car-pack.py[/code], which fits one scale
## factor to the whole pack), and what would be a bug is a car that came out the
## size of a shoe or the size of a bus. Measured, over the ten: 3.26 m (compact)
## to 5.19 m (pickup) long, 1.61 to 2.07 wide, 1.04 (sport) to 1.77 (minivan)
## tall.
const LENGTH_M: Vector2 = Vector2(2.5, 6.5)
const WIDTH_M: Vector2 = Vector2(1.4, 2.5)
const HEIGHT_M: Vector2 = Vector2(0.9, 2.2)

var _chosen_before: String = ""


func before_each() -> void:
	# Every car built here with an empty style asks [CarChoice] what the player
	# picked, and the answer is process-wide — so a pick left behind by another
	# suite would decide what "nobody chose" means in this one. Cleared going in
	# and put back on the way out, the same care test_main_menu.gd takes over
	# [member Sound.muted].
	_chosen_before = CarChoice.chosen
	CarChoice.forget()


func after_each() -> void:
	CarChoice.choose(_chosen_before)


## One car of [param style], in the tree and building itself on the way in.
##
## [member MeshCar.style] is set before the node is added, which is the whole of
## the injection: a test asks for the pickup instead of instantiating cars until
## one turns up.
func _car_of(style: String) -> MeshCar:
	var packed: PackedScene = load(SCENE) as PackedScene
	assert_not_null(packed, "could not load %s" % SCENE)
	# Into a typed local first: GUT's add_child_autofree is untyped.
	var car: MeshCar = packed.instantiate() as MeshCar
	car.style = style
	add_child_autofree(car)
	return car


func _panel(car: MeshCar, named: String) -> Node3D:
	for panel: Node3D in car.panels():
		if String(panel.name) == named:
			return panel
	return null


func _names(car: MeshCar) -> Array[String]:
	var names: Array[String] = []
	for panel: Node3D in car.panels():
		names.append(String(panel.name))
	return names


# ---- the ten, and what each one is made of ------------------------------------


func test_the_ten_styles_are_the_ten_files_in_the_pack() -> void:
	# The list in the script against the files on disk, in both directions. It is
	# the one thing about MeshCar that a wrong answer would make invisible rather
	# than loud: a style dropped from the constant simply never gets picked, and a
	# style renamed in the pack fails at load for one car in ten.
	var found: Array[String] = []
	for file: String in DirAccess.get_files_at(PACK_DIR):
		if file.ends_with(".glb"):
			found.append(file.trim_suffix(".glb"))
	found.sort()
	var listed: Array[String] = []
	for style: String in MeshCar.STYLES:
		listed.append(style)
	listed.sort()
	assert_eq(found, listed, "MeshCar.STYLES and %s must be the same ten cars" % PACK_DIR)


func test_every_style_is_a_car_of_seven_panels() -> void:
	# The panels are what the whole game consumes — a map each, a turn each in the
	# attract loop, a collider each for a tool to hit. Seven and no more: the mesh
	# and the collision shape inside a panel are part of it, not panels of their
	# own, which is the recursion Car._gather stops.
	for style: String in MeshCar.STYLES:
		var car: MeshCar = _car_of(style)
		var names: Array[String] = _names(car)
		for part: String in PARTS:
			assert_has(names, part, "the %s is missing its %s" % [style, part])
		assert_eq(names.size(), PARTS.size(), "the %s has a panel it should not" % style)


func test_the_windows_and_the_lamps_are_both_glass() -> void:
	# Decision on #134, and the reason Optics is in the group at all: head- and
	# tail-lights are lenses, a detailer does them with the blue bottle, and giving
	# them a kind of their own would be a fourth cleaner nobody asked for. Also the
	# half of Car.kind_of that only a car with two glass panels can show — the group
	# is read, not the name, so a panel called "Optics" is glass because it was put
	# in the glass group.
	for style: String in MeshCar.STYLES:
		var car: MeshCar = _car_of(style)
		for named: String in MeshCar.GLASS_PARTS:
			var panel: Node3D = _panel(car, named)
			assert_not_null(panel, "the %s has no %s" % [style, named])
			if panel != null:
				assert_eq(car.kind_of(panel), Surface.Kind.GLASS, "%s %s" % [style, named])


func test_the_four_wheels_are_wheels() -> void:
	for style: String in MeshCar.STYLES:
		var car: MeshCar = _car_of(style)
		for named: String in WHEELS:
			var panel: Node3D = _panel(car, named)
			assert_not_null(panel, "the %s has no %s" % [style, named])
			if panel != null:
				assert_eq(car.kind_of(panel), Surface.Kind.WHEEL, "%s %s" % [style, named])


func test_the_shell_is_bodywork_and_carries_no_group_at_all() -> void:
	# Paint is the default and has no group of its own — Surface.WHEEL_GROUP has the
	# argument for why. Asserting the absence as well as the answer is what stops
	# this passing on a car whose body was put in some group that Car.kind_of
	# happens not to look at today.
	for style: String in MeshCar.STYLES:
		var car: MeshCar = _car_of(style)
		var body: Node3D = _panel(car, MeshCar.BODY_PART)
		assert_not_null(body, "the %s has no body" % style)
		if body == null:
			continue
		assert_eq(car.kind_of(body), Surface.Kind.BODY, "%s body" % style)
		assert_eq(body.get_groups().size(), 0, "%s: the body is the default, not a case" % style)


func test_nothing_on_a_mesh_car_is_trim() -> void:
	# The one group MeshCar deliberately never sets. Trim is geometry that can never
	# be cleaned, and this pack is an outside-only shell with none of it — every part
	# is bodywork, glass or rubber. Worth a test rather than a comment because trim
	# is invisible when it is wrong: a panel quietly marked trim loses its map, its
	# cleaner and its turn in the demo, and nothing anywhere says so.
	for style: String in MeshCar.STYLES:
		var car: MeshCar = _car_of(style)
		for panel: Node3D in car.panels():
			assert_false(panel.is_in_group(Car.TRIM_GROUP), "%s: %s is trim" % [style, panel.name])
		assert_eq(car.get_child_count(), PARTS.size(), "%s has something else in it" % style)


func test_every_panel_of_every_style_has_a_cleaner_for_it() -> void:
	# The property that matters more than any individual assignment above: there is
	# no panel on any of the ten that a player cannot finish because no bottle claims
	# it.
	var belt: ToolBelt = ToolBelt.new()
	for style: String in MeshCar.STYLES:
		var car: MeshCar = _car_of(style)
		for panel: Node3D in car.panels():
			var cleaner: DetailingTool.Id = Surface.cleaner_for(car.kind_of(panel))
			assert_true(belt.index_of(cleaner) >= 0, "%s: %s has no cleaner" % [style, panel.name])


# ---- the shape of a panel -----------------------------------------------------


func test_a_panel_is_a_body_with_the_pack_s_mesh_inside_it() -> void:
	# Points 1, 2 and 4 of the contract in src/world/car.gd, landing on two nodes
	# instead of one: the root is what a ray hands back, the mesh under it is what
	# carries the box and the overlay slot. Checked through Car.skin_of rather than
	# by reaching for a child, because that is the accessor every consumer reads a
	# panel's geometry through.
	for style: String in MeshCar.STYLES:
		var car: MeshCar = _car_of(style)
		for panel: Node3D in car.panels():
			assert_true(panel is StaticBody3D, "%s: %s is not a body" % [style, panel.name])
			var skin: GeometryInstance3D = car.skin_of(panel)
			assert_not_null(skin, "%s: %s has no skin" % [style, panel.name])
			if skin == null:
				continue
			assert_true(skin is MeshInstance3D, "%s: %s's skin is not a mesh" % [style, panel.name])
			assert_eq(
				skin.get_parent(), panel, "%s: %s's skin is not inside it" % [style, panel.name]
			)


func test_the_mesh_and_the_collider_in_a_panel_are_not_panels_of_their_own() -> void:
	# The recursion stops at the panel. A mesh counted as a panel would give the car
	# two maps for one piece of glass and hand the second to a node no raycast can
	# ever return.
	for style: String in MeshCar.STYLES:
		var car: MeshCar = _car_of(style)
		var names: Array[String] = _names(car)
		for part: String in PARTS:
			assert_does_not_have(
				names, "%sMesh" % part, "%s: %sMesh is part of a panel" % [style, part]
			)
			assert_does_not_have(
				names, "%sShape" % part, "%s: %sShape is part of a panel" % [style, part]
			)


# ---- how big it is ------------------------------------------------------------


func test_the_bounds_are_exact_on_the_frame_the_car_arrives() -> void:
	# No await anywhere in this file, and this is the test that means it. The CSG
	# blockout has to be waited a frame for because its meshes are built deferred —
	# src/world/car.gd says at length that this is CSG's tax and not the panel
	# contract's, and that a panel skinned with a MeshInstance3D is exact
	# immediately. That claim has been held by a fixture of four boxes since #136;
	# here it is against a real car with 7,000 triangles in it.
	var car: MeshCar = _car_of("sedan")
	assert_gt(car.bounds().size.length(), 0.0, "the car reported no size at all")
	assert_between(car.bounds().size.z, LENGTH_M.x, LENGTH_M.y, "and it is car-length immediately")


func test_every_style_measures_like_a_car() -> void:
	# Wide bands on purpose — see LENGTH_M. What this catches is a scale that is
	# wrong by a factor, a style baked empty, or a panel whose transform was dropped
	# on the way into its body and left the car spread across the driveway.
	for style: String in MeshCar.STYLES:
		var car: MeshCar = _car_of(style)
		var box: AABB = car.bounds()
		assert_between(box.size.z, LENGTH_M.x, LENGTH_M.y, "%s: length" % style)
		assert_between(box.size.x, WIDTH_M.x, WIDTH_M.y, "%s: width" % style)
		assert_between(box.size.y, HEIGHT_M.x, HEIGHT_M.y, "%s: height" % style)


func test_the_origin_is_mid_height_on_every_style() -> void:
	# What the garage needs and what the pack promises: the car's own position is
	# level with the middle of it, because the camera looks at that point and the
	# standoff ray is cast through it — an origin on the floor would aim the shot at
	# the tarmac (src/world/garage.gd). Measured as symmetry rather than against a
	# height written here, so it stays true for ten cars of ten different heights.
	for style: String in MeshCar.STYLES:
		var car: MeshCar = _car_of(style)
		var box: AABB = car.bounds()
		assert_almost_eq(box.position.y, -box.end.y, TOLERANCE, "%s: origin is mid-height" % style)
		assert_lt(box.position.y, 0.0, "%s: the wheels are below the origin" % style)


func test_the_wheels_reach_the_ground_the_car_is_parked_on() -> void:
	# The other half of "it sits on the floor rather than hovering or buried": the
	# bottom of the car is the bottom of a tyre, on all four corners, and not the
	# bottom of a sill.
	for style: String in MeshCar.STYLES:
		var car: MeshCar = _car_of(style)
		var ground: float = car.bounds().position.y
		for named: String in WHEELS:
			var skin: GeometryInstance3D = car.skin_of(_panel(car, named))
			var box: AABB = skin.global_transform * skin.get_aabb()
			assert_almost_eq(
				box.position.y, ground, TOLERANCE, "%s: %s on the floor" % [style, named]
			)


# ---- paint --------------------------------------------------------------------


func test_the_car_starts_painted_one_of_the_thirteen_colors() -> void:
	# Which colour is still Car's to pick — MeshCar picks a style and hands that
	# question straight back. What it adds is MeshCar.MAP_COMPENSATION, so the value
	# on the material is a colour off the list driven up to survive the pack's
	# greyscale map, and the list is checked through that rather than against it.
	var offered: Array[Color] = []
	for colour: Color in Car.PAINT_COLORS:
		offered.append(MeshCar.compensated(colour))
	for style: String in MeshCar.STYLES:
		var car: MeshCar = _car_of(style)
		assert_has(offered, car.paint.albedo_color, "%s: not a colour on the list" % style)


func test_the_paint_is_driven_up_to_survive_the_packs_greyscale_map() -> void:
	# The half the test above cannot see: it would pass just as happily if the
	# compensation were 1.0, because it builds its list with the same function the
	# car does. So this one takes the sum apart — the colour on the material,
	# divided back down, has to be an entry on the list, and the constant has to
	# actually lift.
	assert_gt(MeshCar.MAP_COMPENSATION, 1.0, "a compensation under 1 would darken it further")
	var painted: Color = _car_of("sedan").paint.albedo_color
	var plain: Color = Color(
		painted.r / MeshCar.MAP_COMPENSATION,
		painted.g / MeshCar.MAP_COMPENSATION,
		painted.b / MeshCar.MAP_COMPENSATION,
		painted.a,
	)
	var nearest: float = INF
	for colour: Color in Car.PAINT_COLORS:
		nearest = minf(
			nearest, Vector3(plain.r - colour.r, plain.g - colour.g, plain.b - colour.b).length()
		)
	assert_almost_eq(nearest, 0.0, 0.001, "the paint does not divide back to a colour on the list")
	assert_eq(painted.a, 1.0, "the tint changed the paint's opacity")


func test_the_compensation_stays_under_what_the_bay_can_show() -> void:
	# The ceiling MAP_COMPENSATION's docs are about, pinned so that raising it comes
	# with re-measuring rather than by feel. The bay sets no tonemap, so a channel
	# driven past 1.0 is one the renderer flattens to white, and Alpine White is the
	# brightest thing on the list and hits it first. Measured over the thirteen at
	# the showcase angle: 1.25 puts no body pixel at 255, and 1.30 puts 28.7% of
	# Alpine White's there.
	assert_lte(
		MeshCar.MAP_COMPENSATION,
		1.25,
		"past 1.25 the light end of the palette clips — re-measure before raising this"
	)


func test_the_paint_keeps_the_greyscale_map_the_pack_baked() -> void:
	# The tint only works because the body texture had its hue divided out (decision
	# 2 on #134, done in scripts/build-car-pack.py). Copying the pack's own material
	# rather than authoring one in the scene file is what keeps that map — and the
	# packed metallic-roughness map beside it — on the car.
	for style: String in MeshCar.STYLES:
		var car: MeshCar = _car_of(style)
		assert_not_null(car.paint.albedo_texture, "%s: the paint lost its texture" % style)
		assert_not_null(car.paint.roughness_texture, "%s: the paint lost its ORM map" % style)


func test_the_body_wears_the_car_s_own_paint() -> void:
	# Set as a surface override on the instance rather than written into the mesh,
	# which is a shared resource: painting into it would repaint every car of this
	# style ever loaded, including the ones already parked.
	for style: String in MeshCar.STYLES:
		var car: MeshCar = _car_of(style)
		var skin: MeshInstance3D = car.skin_of(_panel(car, MeshCar.BODY_PART)) as MeshInstance3D
		assert_eq(skin.get_surface_override_material(0), car.paint, "%s: body unpainted" % style)
		assert_null(skin.material_override, "%s: the body's own material was replaced" % style)


func test_two_cars_do_not_share_one_paint_job() -> void:
	# The blockout gets this from a local-to-scene sub-resource; here it comes from
	# the copy MeshCar takes of the pack's material. Same guarantee, and it has to be
	# tested the same way, because the failure looks identical: repaint one car in the
	# driveway and every car in the game changes colour with it.
	var one: MeshCar = _car_of("sedan")
	var other: MeshCar = _car_of("sedan")
	one.paint.albedo_color = Color(0.5, 0.5, 0.5)
	assert_ne(one.paint, other.paint, "two cars must not share one material")
	assert_ne(one.paint.albedo_color, other.paint.albedo_color, "or one paint job")


func test_the_suv_s_hub_caps_are_painted_with_the_car() -> void:
	# The one part of the pack that is not where you would look for it: the SUV's
	# wheels carry a second surface in the *body* material for the hub caps. Found by
	# comparing materials rather than by naming the body mesh, so a red SUV gets red
	# hub caps instead of four grey discs — and so the day another style grows one it
	# is painted without anybody noticing there was a decision to make.
	var car: MeshCar = _car_of("suv")
	var wheel: MeshInstance3D = car.skin_of(_panel(car, "Wheel1")) as MeshInstance3D
	assert_eq(wheel.mesh.get_surface_count(), 2, "the SUV wheel is a tyre and a hub cap")
	assert_eq(wheel.get_surface_override_material(1), car.paint, "the hub cap is body-coloured")
	assert_null(wheel.get_surface_override_material(0), "and the tyre is the pack's own")


# ---- glass --------------------------------------------------------------------


func test_the_windows_are_the_light_bluish_green_this_game_settled_on() -> void:
	# #58, against the pack, which ships its glass near-black at 68% alpha — the
	# exact look that issue was filed about. The numbers are the blockout's
	# (tests/fixtures/blockout_car.tscn), so the two cars' windows match while both exist.
	for style: String in MeshCar.STYLES:
		var car: MeshCar = _car_of(style)
		var glass: MeshInstance3D = car.skin_of(_panel(car, MeshCar.GLASS_PART)) as MeshInstance3D
		var worn: StandardMaterial3D = glass.get_surface_override_material(0) as StandardMaterial3D
		assert_not_null(worn, "%s: the windows are still the pack's" % style)
		if worn == null:
			continue
		assert_eq(worn, car.glass, "%s: the windows are not the scene's glass" % style)
		assert_eq(worn.albedo_color, GLASS_COLOR, "%s: the glass changed colour" % style)
		assert_eq(
			worn.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED, "%s: see-through" % style
		)
		assert_eq(worn.cull_mode, BaseMaterial3D.CULL_DISABLED, "%s: one-sided glass" % style)


func test_the_lamps_keep_their_own_lenses() -> void:
	# Optics is glass to the rules of the job and a red tail-light to look at, and
	# those are different questions. Painting it with the windows would throw away
	# the one texture on the car that says which end is the front.
	for style: String in MeshCar.STYLES:
		var car: MeshCar = _car_of(style)
		var lamps: MeshInstance3D = car.skin_of(_panel(car, "Optics")) as MeshInstance3D
		assert_null(lamps.get_surface_override_material(0), "%s: the lamps were repainted" % style)
		var lens: StandardMaterial3D = lamps.mesh.surface_get_material(0) as StandardMaterial3D
		assert_not_null(lens.albedo_texture, "%s: the lamps lost their texture" % style)


# ---- which car turns up -------------------------------------------------------


func test_a_test_can_ask_for_the_style_it_wants() -> void:
	# The injection, which is the whole reason every other test in this file can loop
	# over ten cars rather than instantiate until the one it wanted arrived.
	for style: String in MeshCar.STYLES:
		assert_eq(_car_of(style).style, style, "asked for the %s and got something else" % style)


func test_a_car_nobody_chose_a_style_for_picks_one_of_the_ten() -> void:
	# The game's own path: a car per game, one of ten, alongside one of thirteen
	# colours. Asserted as membership rather than as a distribution — the pick is one
	# draw from a list and a test that demanded variety would be a test that fails
	# once in ten thousand runs for no reason.
	#
	# Forgotten between cars because the draw is a car per *game* and not per car:
	# every screen builds its own room, so [CarChoice] takes the draw once and hands
	# the same answer to the rest of the run. Without this the loop below would be
	# twelve copies of one car, which is true and is not what this is asking.
	for _each: int in range(12):
		CarChoice.forget()
		var car: MeshCar = _car_of("")
		assert_has(MeshCar.STYLES, car.style, "an unasked-for car is not one of the ten")


func test_the_style_is_readable_after_the_car_is_built() -> void:
	# The export is a door on the way in and a readout on the way out — which is what
	# makes it the same shape as Car.paint, where the colour is picked in _ready and
	# left where a test can find it.
	var car: MeshCar = _car_of("")
	assert_false(car.style.is_empty(), "a built car must say which style it is")
	var skin: MeshInstance3D = car.skin_of(_panel(car, MeshCar.BODY_PART)) as MeshInstance3D
	var livery: StandardMaterial3D = skin.mesh.surface_get_material(0) as StandardMaterial3D
	assert_string_contains(
		livery.albedo_texture.resource_path, car.style, "the model is not the style it claims"
	)


func test_a_car_nobody_chose_a_style_for_is_the_one_the_player_picked() -> void:
	# What #143 put where the scene file's pin used to be, and the only change to
	# what an empty style means: it is still "nobody set this export", but the
	# question it now asks is the menu's rather than a random number generator's.
	# Every style, because the plumbing has no business caring which.
	for style: String in MeshCar.STYLES:
		CarChoice.choose(style)
		assert_eq(_car_of("").style, style, "the bay ignored the player and parked something else")


func test_a_style_set_on_the_car_still_beats_the_player() -> void:
	# The export's contract, unchanged and worth pinning precisely because there is
	# now something else with an opinion. Every suite in this repo that asks for a
	# particular car — this one, test_garage_styles.gd, test_mesh_car_hits.gd —
	# depends on the export winning.
	CarChoice.choose("pickup")
	assert_eq(_car_of("minivan").style, "minivan", "a car asked for by name must be that car")


# ---- swapping one for another, in place ---------------------------------------


func test_a_car_can_be_restyled_where_it_stands() -> void:
	# What the menu's arrows are made of. The car is already in a room by then —
	# parked, aimed at, walked around — so the swap has to happen under all of that
	# rather than by building a second car somewhere.
	var car: MeshCar = _car_of("sedan")
	car.restyle("pickup")
	assert_eq(car.style, "pickup", "the readout must agree with what was asked for")
	var skin: MeshInstance3D = car.skin_of(_panel(car, MeshCar.BODY_PART)) as MeshInstance3D
	var livery: StandardMaterial3D = skin.mesh.surface_get_material(0) as StandardMaterial3D
	assert_string_contains(
		livery.albedo_texture.resource_path, "pickup", "the model is not the style it claims"
	)


func test_the_car_it_replaces_is_gone_the_same_frame() -> void:
	# The bug this is here for: `queue_free` alone is deferred, so panels freed and
	# not removed would still be children for the rest of the frame — `panels()`
	# would answer with fourteen, `bounds()` would report a box drawn round two
	# cars at once, and the room re-sits the car on the tarmac from that box on the
	# very next line of Garage.show_style. No await, because the whole claim is
	# that a frame is not needed.
	var car: MeshCar = _car_of("compact")
	var before: AABB = car.bounds()
	car.restyle("pickup")
	assert_eq(car.panels().size(), PARTS.size(), "the old car is still hanging off this one")
	# The pack is +Z forward, so length is the z of the box: 3.26 m of compact
	# against 5.19 m of pickup. A box still drawn round both of them would be the
	# longer of the two either way, which is why the compact goes in first.
	var after: AABB = car.bounds()
	assert_gt(after.size.z, before.size.z, "the pickup is longer than the compact it replaced")


func test_a_restyled_car_keeps_the_colour_it_was_painted() -> void:
	# `_build` hands back a fresh copy of the pack's greyscale livery, so a rebuild
	# that did nothing about it would come out unpainted — and re-rolling the colour
	# instead would turn "look at the other nine" into a slot machine. What the
	# player is comparing across a press is the shape.
	var car: MeshCar = _car_of("sedan")
	var colour: Color = car.paint.albedo_color
	car.restyle("minivan")
	assert_eq(car.paint.albedo_color, colour, "the car was repainted for changing shape")


func test_a_restyled_car_is_painted_at_all() -> void:
	# The half the test above cannot see: it compares the new material against a
	# colour, and a rebuild that left `paint` pointing at the old car's material
	# would pass it while every panel on screen stayed grey. Asserted through a
	# panel's own override, which is what is actually drawn.
	var car: MeshCar = _car_of("sedan")
	car.restyle("suv")
	var skin: MeshInstance3D = car.skin_of(_panel(car, MeshCar.BODY_PART)) as MeshInstance3D
	assert_eq(skin.get_surface_override_material(0), car.paint, "the new body is not this car's")


func test_restyling_to_the_car_that_is_already_there_does_nothing() -> void:
	# Which is what makes the menu's "adopt whatever the room drew" call free: it
	# runs on the way into every menu and must not rebuild a car that is already
	# correct. Asserted on the panels themselves rather than on the style string,
	# because the string would agree either way.
	var car: MeshCar = _car_of("wagon")
	var panels: Array[Node3D] = car.panels()
	car.restyle("wagon")
	assert_eq(car.panels(), panels, "the car was rebuilt for no reason")
