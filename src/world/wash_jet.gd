## The power wash's water, as a cone of geometry running from the nozzle to the
## paint: what the crosshair used to say, said by the tool itself.
##
## [b]Why the power wash stopped using the crosshair.[/b] A ring on the panel
## answers "where is the tool pointed", which is the right question for a sponge
## or a rag — you put those [i]on[/i] the car, at a point, and a mark at that
## point is the whole story. A pressure washer is not used at a point. It is
## aimed from a standoff, it spreads with range, and the thing the player needs
## to see is the volume between the nozzle and the paint: how wide the water
## lands, whether the panel is inside it, and whether the wand is really pointed
## where they think it is. A flat reticle can say none of that, and it says the
## one thing it can say in a place — on the paint — where the water is about to
## cover it up anyway.
##
## [b]A cone and not a beam.[/b] A real washer's fan is narrow: a tight cone that
## reads as a triangle from the side and as a disc from behind it. That is
## exactly the shape [method Garage._spend_the_trigger] already washes with —
## [member Garage.wash_radius_metres] of paint, centred on the mark — so the cone
## is not an illustration of the physics, it [i]is[/i] the physics, drawn. Its
## half-angle is whatever puts that radius on the mark from wherever the nozzle
## happens to be standing, which means walking closer visibly narrows the cone
## the same way it narrows the patch being cleaned.
##
## [b]Blue at the tip, red at the base.[/b] Vertex colours down the cone rather
## than two meshes or a shader: water is at pressure where it leaves the nozzle
## and spent where it lands, and the red end is the same red the crosshair used
## to be, in the same place the crosshair used to be, so the thing the mark said
## is still being said. One material, one mesh, and the gradient is in the
## geometry where a diff can read it.
##
## [b]And it is [constant OPACITY] of the way opaque[/b], because it is a solid
## standing in for something that will not be solid. At full alpha a cone this
## size is a wall across the middle of the frame and the car behind it is gone;
## at a third it reads as a volume you can see the paint through, which is what
## water looks like and what a blockout needs to be to be usable.
##
## [b]This is scaffolding and is meant to be thrown away.[/b] The water will be a
## [GPUParticles3D] hung off [code]ViewModel.MUZZLE[/code] — the marker exists,
## the wand is already aligned to the mark for it ([WandCarry]), and the geometry
## here is what stands in until then. It is here so the shape and the reach can
## be looked at and tuned before anything is emitted, which is much easier to do
## against a solid than against a particle count.
##
## [b]Built in code, unshaded, shadowless[/b] — all three for the same reasons
## [AimMarker] is: the sizes are the design decision and belong somewhere a diff
## reads, a lit jet would take the colour of the two strip lights and go dim on
## the far side of the car, and a piece of world-space UI that cast a shadow
## would paint a cone's shadow across the panel it is describing.
class_name WashJet
extends Node3D

## What the mesh child is called, so a test can reach the material and the
## vertices rather than counting children.
const CONE: String = "Cone"

## The colour at the nozzle: water under pressure, and a blue no tool on the
## belt wears (see [member DetailingTool.albedo]) so the jet can never be
## mistaken for the wand throwing a colour.
const TIP: Color = Color(0.24, 0.60, 1.0, 1.0)

## The colour where it lands. The crosshair's own red — see [constant
## AimMarker.COLOR] — because this end of the cone is doing that mark's job now,
## and a player who learned "red is where my tool is pointed" should not have to
## learn it twice.
const SPRAY: Color = Color(0.95, 0.13, 0.16, 1.0)

## How opaque the whole thing renders, 0 to 1. See the class docs: a third is
## the difference between a volume you can see the car through and a lid over
## the middle of the screen.
const OPACITY: float = 0.33

## How many faces go round the cone. Twenty-four is smooth enough that the base
## reads as a disc rather than as a polygon at the range a car is washed from,
## and it is 48 triangles — nothing, for something built once and never rebuilt.
const SEGMENTS: int = 24

## How far short of the paint the cone stops, in metres. Two centimetres, the
## same clearance [constant AimMarker.LIFT] keeps and for the same reason: a base
## disc that ended exactly on the panel would be coplanar with it at its centre,
## and coplanar surfaces flicker. The cone's [i]angle[/i] is unaffected — the
## radius is shortened in proportion — so the width the player reads off the base
## is still the width the water lands at, a centimetre further on.
const PULLBACK: float = 0.02

## When the jet is too near the reference axis to build a basis against. Squared
## length of a cross product, so about a quarter of a degree of parallelism —
## reached only by a jet fired straight up or straight down, which the aim's own
## pitch fence rules out; here so that a caller without one cannot produce a
## zero-length axis.
const TOO_PARALLEL: float = 0.0001

## The far end of the unit cone, in its own space: the apex sits at the origin
## and the base is one unit down [code]-Z[/code], which is the axis
## [method spray] scales by the reach and the axis a [GPUParticles3D] will emit
## along when it replaces all of this.
const FAR_END: Vector3 = Vector3(0.0, 0.0, -1.0)


func _ready() -> void:
	visible = false
	var cone: MeshInstance3D = MeshInstance3D.new()
	cone.name = CONE
	cone.mesh = _cone()
	cone.material_override = _water()
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cone)


## Puts the jet between [param from] — the nozzle — and [param onto], the point
## on the paint the tool is pointed at, spreading to [param radius] where it
## lands.
##
## [b]Nozzle to mark and not "along the wand".[/b] The two are the same line once
## the wand has finished coming up ([WandCarry] guarantees it, and
## [code]tests/integration/test_play_screen_wand.gd[/code] holds it), and they are
## briefly different while it is still swinging. Drawn this way the cone always
## reaches the paint: it converges onto the wand rather than lagging behind it,
## which is what the water will do anyway once it has a travel time.
##
## A degenerate call — a mark on top of the nozzle, or a jet with no width —
## stows rather than drawing a cone with nothing to divide by.
func spray(from: Vector3, onto: Vector3, radius: float) -> void:
	var along: Vector3 = onto - from
	var reach: float = along.length()
	if reach <= PULLBACK or radius <= 0.0:
		stow()
		return
	var forward: Vector3 = along / reach
	var across: Vector3 = forward.cross(Vector3.UP)
	if across.length_squared() < TOO_PARALLEL:
		across = forward.cross(Vector3.RIGHT)
	across = across.normalized()
	# Shortened by [constant PULLBACK], and the radius shortened with it so the
	# cone keeps the angle that would have put `radius` on the mark itself.
	var length: float = reach - PULLBACK
	# Not `spread`, which is what it wants to be called: a local that shadows a
	# method in the same class is a compile error under this project's warning
	# levels rather than a style note. [method ToolAim.pointing] has the same scar.
	var wide: float = radius * length / reach
	# The three columns of the basis are the unit cone's own axes, scaled: its
	# `X` and `Y` become the width where the water lands and its `-Z` becomes the
	# whole reach. Written out rather than a `look_at` and a scale, because a
	# non-uniform scale is the entire point here and composing it by hand is the
	# version that says so.
	global_transform = Transform3D(
		Basis(across * wide, across.cross(forward) * wide, -forward * length), from
	)
	visible = true


## Takes the jet away: the trigger is off, or the tool in hand is not the one
## that sprays.
func stow() -> void:
	visible = false


## Whether there is water on screen right now.
func is_spraying() -> bool:
	return visible


## The middle of the cone's far end, in the world — where the water lands, read
## back off the transform rather than out of a field, so it is the drawn cone
## being asserted on and not a number the drawing might have ignored.
func landing() -> Vector3:
	return global_transform * FAR_END


## How wide the cone is where it lands, as a radius in metres. Read the same way
## and for the same reason as [method landing].
func spread() -> float:
	return global_basis.x.length()


## The unit cone: apex at the origin in [constant TIP], base a unit down
## [code]-Z[/code] in [constant SPRAY], with the cap on.
##
## [b]The cap earns its keep.[/b] Seen from behind the nozzle — which is where
## the player always is — the far disc is the footprint the water covers, drawn
## at the size and the angle it actually covers it at. That is the single most
## useful thing this whole mesh says, and an open cone would leave it as a rim.
##
## Colours per vertex rather than per surface: one mesh, one material, and the
## blue-to-red run is a property of the geometry rather than of a shader nobody
## can diff.
func _cone() -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for step: int in SEGMENTS:
		var here: Vector3 = _rim(step)
		var next: Vector3 = _rim(step + 1)
		_wedge(surface, Vector3.ZERO, TIP, here, next)
		_wedge(surface, FAR_END, SPRAY, here, next)
	return surface.commit()


## One triangle from [param point] out to two neighbouring points on the base
## ring — the wall of the cone when the point is the apex, the cap when it is the
## middle of the base. Winding is not stated because the material draws both
## faces; see [method _water].
func _wedge(
	surface: SurfaceTool, point: Vector3, tint: Color, here: Vector3, next: Vector3
) -> void:
	surface.set_color(tint)
	surface.add_vertex(point)
	surface.set_color(SPRAY)
	surface.add_vertex(next)
	surface.set_color(SPRAY)
	surface.add_vertex(here)


## One point on the unit cone's base ring, [param step] of [constant SEGMENTS] of
## the way round it.
func _rim(step: int) -> Vector3:
	var turn: float = TAU * float(step) / float(SEGMENTS)
	return Vector3(cos(turn), sin(turn), FAR_END.z)


## What the water is made of.
##
## [b]Unshaded[/b], for [AimMarker]'s reason: the same jet on both sides of the
## car. [b]Double-sided[/b], because the player stands at the apex and is
## therefore looking at the inside of the cone — under default culling the whole
## thing would be invisible from the one place it is ever seen from.
## [b]Vertex colours as albedo[/b], multiplied by an [constant OPACITY] white, so
## the gradient lives in the mesh and the transparency is one number here.
## [b]No depth write[/b], which is the default for an alpha-blended material and
## is stated rather than assumed: the cone crosses the wand and the paint, and a
## transparent surface that wrote depth would punch a hole in whichever of them
## drew second.
func _water() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 1.0, 1.0, OPACITY)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	return material
