## Integration test for [Grime] laid on a [MeshCar] — the half of the panel
## contract [code]tests/integration/test_grime.gd[/code] cannot exercise, because
## its fixture is CSG.
##
## [b]What this is actually checking.[/b] Issue #138 named two things about the
## pack's own materials that could plausibly stop [member
## GeometryInstance3D.material_overlay] from rendering: the glass and lamp
## lenses ship with [constant BaseMaterial3D.CULL_DISABLED] (a shell with no
## thickness, seen from both sides), and every part carries a packed
## metallic-roughness texture the imported material is never touched by. Neither
## turns out to matter to the overlay — Godot draws
## [code]material_overlay[/code] as a second pass with its own render state,
## independent of what the base material's cull mode or texture set is — but
## "turns out" is exactly the kind of claim this project does not leave to a
## paragraph. So every panel of every style is asserted to actually be carrying
## a live [ShaderMaterial] with sane parameters, and the glass and wheel panels
## get it asserted a second time by name, because those are the two the issue
## called out.
##
## Runs over [constant MeshCar.STYLES] for the same reason
## [code]tests/integration/test_mesh_car.gd[/code] does: a mesh car is ten
## real models and not one hand-built scene, and a suite that only tried the
## sedan would go green on the day a pickup's tyre lost its overlay.
##
## No [code]await[/code] anywhere, for the reason [code]test_mesh_car.gd[/code]
## gives at length: a [MeshInstance3D]'s box is exact the frame it is instanced,
## so [method Grime.lay_on] needs none of the wait a CSG car's does.
extends GutTest

const SCENE: String = "res://src/world/mesh_car.tscn"

const WHEELS: Array[String] = ["Wheel1", "Wheel2", "Wheel3", "Wheel4"]


func _car_of(style: String) -> MeshCar:
	var packed: PackedScene = load(SCENE) as PackedScene
	assert_not_null(packed, "could not load %s" % SCENE)
	var car: MeshCar = packed.instantiate() as MeshCar
	car.style = style
	add_child_autofree(car)
	return car


func _panel(car: MeshCar, named: String) -> Node3D:
	for panel: Node3D in car.panels():
		if String(panel.name) == named:
			return panel
	return null


func _laid_grime(car: MeshCar) -> Grime:
	var grime: Grime = Grime.new()
	add_child_autofree(grime)
	grime.lay_on(car)
	return grime


func _overlay_of(car: MeshCar, panel: Node3D) -> ShaderMaterial:
	return car.skin_of(panel).material_overlay as ShaderMaterial


func test_every_panel_of_every_style_gets_a_live_overlay() -> void:
	# The general claim: seven panels, ten styles, seventy overlays, all present
	# and all a ShaderMaterial rather than whatever the pack shipped.
	for style: String in MeshCar.STYLES:
		var car: MeshCar = _car_of(style)
		var grime: Grime = _laid_grime(car)
		assert_true(grime.is_laid(), "%s: grime never laid" % style)
		for panel: Node3D in car.panels():
			var overlay: ShaderMaterial = _overlay_of(car, panel)
			assert_not_null(overlay, "%s: %s has no overlay at all" % [style, panel.name])


func test_the_overlay_s_parameters_agree_with_the_map_it_was_built_from() -> void:
	# Not just present — wired to the right map. A shader with a null mask draws
	# nothing at all, and a box that disagrees with GrimeMap's washes the wrong
	# spot; both are silent failures a raycast test would not catch.
	for style: String in MeshCar.STYLES:
		var car: MeshCar = _car_of(style)
		var grime: Grime = _laid_grime(car)
		for panel: Node3D in car.panels():
			var overlay: ShaderMaterial = _overlay_of(car, panel)
			if overlay == null:
				continue
			var map: GrimeMap = grime.map_of(panel)
			var mask: Texture2D = overlay.get_shader_parameter("grime_mask")
			assert_not_null(mask, "%s: %s's overlay has no mask" % [style, panel.name])
			if mask != null:
				assert_eq(mask.get_rid(), map.texture().get_rid(), "%s: %s" % [style, panel.name])
			var flash: Texture2D = overlay.get_shader_parameter("patch_flash")
			assert_not_null(flash, "%s: %s's overlay has no flash texture" % [style, panel.name])
			var box: AABB = car.skin_of(panel).get_aabb()
			var origin: Vector3 = overlay.get_shader_parameter("box_origin")
			assert_eq(origin, box.position, "%s: %s" % [style, panel.name])
			var size: Vector3 = overlay.get_shader_parameter("box_size")
			assert_eq(size, box.size, "%s: %s" % [style, panel.name])
			var colour: Color = overlay.get_shader_parameter("product_colour")
			assert_eq(
				colour, Surface.product_colour(car.kind_of(panel)), "%s: %s" % [style, panel.name]
			)


func test_the_double_sided_glass_still_carries_a_working_overlay() -> void:
	# The concern #138 named by name: Glass and Optics ship with
	# BaseMaterial3D.CULL_DISABLED, a setting that lives on the base material and
	# has no bearing on material_overlay, which is drawn as its own pass with its
	# own render_mode (grime.gdshader: `cull_back`). Asserted directly rather than
	# inferred from the general loop above, because this is the specific claim
	# the issue asked to have checked.
	for style: String in MeshCar.STYLES:
		var car: MeshCar = _car_of(style)
		var grime: Grime = _laid_grime(car)
		for named: String in MeshCar.GLASS_PARTS:
			var panel: Node3D = _panel(car, named)
			assert_not_null(panel, "%s: no %s" % [style, named])
			if panel == null:
				continue
			var skin: MeshInstance3D = car.skin_of(panel) as MeshInstance3D
			var base: StandardMaterial3D = (
				skin.get_surface_override_material(0) as StandardMaterial3D
			)
			if named == MeshCar.GLASS_PART:
				assert_not_null(base, "%s: the glass lost its own material" % style)
				if base != null:
					assert_eq(
						base.cull_mode,
						BaseMaterial3D.CULL_DISABLED,
						"%s: glass is not double-sided any more" % style
					)
			var overlay: ShaderMaterial = _overlay_of(car, panel)
			assert_not_null(
				overlay, "%s: %s has no overlay despite CULL_DISABLED on the base" % [style, named]
			)
			if overlay == null:
				continue
			var mask: Texture2D = overlay.get_shader_parameter("grime_mask")
			assert_not_null(mask, "%s: %s overlay has no mask" % [style, named])
			assert_not_null(grime.map_of(panel), "%s: %s has no grime map" % [style, named])


func test_the_wheels_own_orm_map_does_not_stop_their_overlay() -> void:
	# The other concern named: a wheel's own material can carry a packed
	# metallic-roughness texture (and, on the SUV, a body-coloured hub cap as a
	# second surface) that this game never touches — proving the overlay is
	# unaffected is proving material_overlay is genuinely a second pass and not
	# something that only works on a plain StandardMaterial3D.
	for style: String in MeshCar.STYLES:
		var car: MeshCar = _car_of(style)
		var grime: Grime = _laid_grime(car)
		for named: String in WHEELS:
			var panel: Node3D = _panel(car, named)
			assert_not_null(panel, "%s: no %s" % [style, named])
			if panel == null:
				continue
			var overlay: ShaderMaterial = _overlay_of(car, panel)
			assert_not_null(overlay, "%s: %s has no overlay" % [style, named])
			if overlay == null:
				continue
			var colour: Color = overlay.get_shader_parameter("product_colour")
			assert_eq(colour, Surface.product_colour(Surface.Kind.WHEEL))
			assert_not_null(grime.map_of(panel), "%s: %s has no grime map" % [style, named])


func test_the_overlay_never_replaces_the_panel_s_own_material() -> void:
	# The whole point of an overlay over an override, restated against the real
	# pack: the paint, the tyre texture and the packed ORM map are all still
	# there underneath. Grime.gd's class docs have the argument; this is the
	# assertion that the pack does not quietly break it.
	for style: String in MeshCar.STYLES:
		var car: MeshCar = _car_of(style)
		_laid_grime(car)
		for panel: Node3D in car.panels():
			var skin: GeometryInstance3D = car.skin_of(panel)
			assert_null(
				skin.material_override, "%s: %s's own material was replaced" % [style, panel.name]
			)
