## The red crosshair on the paint: where the tool in your hands is pointed, drawn
## on the car rather than over it.
##
## [b]In the world and not on the HUD.[/b] A flat reticle at the touch point
## would have been fewer moving parts, and it would have answered a different
## question — it says where your finger is, which the player already knows,
## rather than where on the car that lands. Laid on the surface and turned to its
## normal, the ring skews with the panel it is sitting on, so a mark on the flank
## reads as being on the flank and one on the roof reads as being on the roof.
## That is the whole point of the thing: it is the first piece of feedback in
## this game that says the tool and the car are in the same space.
##
## It is also the placement the grime work (#45) needs. A patch of dirt goes
## exactly here — a point, a surface normal and a lift off the paint — so getting
## it right for a crosshair is getting it right once.
##
## [b]Built in code from the numbers below, not written out in a scene file.[/b]
## Same argument as [ViewModel]: three meshes and one material, whose sizes are
## the design decision and are readable here rather than buried in a
## [code].tscn[/code] nobody diffs.
##
## [b]Unshaded, on purpose.[/b] A lit crosshair takes the colour of the two strip
## lights and goes dim on whichever side of the car is facing away from them —
## so the feedback would be clearest exactly where the player needs it least.
## Unshaded, it is the same red everywhere, which is what a piece of UI drawn in
## world space should be.
##
## [b]And it is lifted off the surface[/b] by [constant LIFT], because a
## coplanar mesh and a car panel fight for the same pixel and the fight looks
## like a crosshair with holes in it. A centimetre is far enough to win and near
## enough that no viewing angle in this game shows it floating.
##
## [b]One tool draws its own instead.[/b] The power wash puts a [WashJet] between
## its nozzle and the paint, and a ring under the wide end of that cone is a
## second answer to a question the cone has already answered better — so the room
## turns the ring off with [method draw_crosshair] while the washer is in hand.
## What it does not turn off is the mark itself: [method mark] still records
## where the aim landed and [method marked_point] still answers, because where
## the tool is pointed is a fact about the aim rather than about which tool
## happens to be drawing it. Everything that reads this — the panel readout, the
## jet, the wand that lines up with it — goes on working unchanged.
class_name AimMarker
extends Node3D

## The crosshair's colour. Red because it is the one colour on the belt's
## palette that no tool uses (see [member DetailingTool.albedo]), so a mark can
## never be mistaken for a reflection of the thing making it.
const COLOR: Color = Color(0.95, 0.13, 0.16, 1.0)

## The ring's outer radius, in metres. About 9 cm on a 4.3 m car — big enough to
## find on a phone screen at arm's length from the paint, small enough to be
## pointing at somewhere rather than at everywhere.
const RING_OUTER: float = 0.09

## The ring's inner radius. The 1.4 cm difference is the ring's thickness; much
## thinner and it disappears at the shallow angles a walk around the car spends
## most of its time at.
const RING_INNER: float = 0.076

## How far the two bars reach, tip to tip. Longer than the ring is wide, so they
## read as a crosshair's arms crossing a sight rather than as spokes in a wheel.
const BAR_LENGTH: float = 0.26

## How wide the bars are.
const BAR_WIDTH: float = 0.012

## How thick everything is, off the surface. Flat enough to read as paint rather
## than as a part bolted to the car.
const BAR_DEPTH: float = 0.004

## How far off the surface the whole mark is lifted. See the class docs — this is
## the number that keeps it from z-fighting the panel it is drawn on.
##
## Two centimetres, which at the 2.2 m the eye stands off the paint is a
## hundredth of the distance — far too little for any viewing angle in this game
## to read as floating, and far more than the depth buffer needs.
##
## [b]What it does not fix, stated because it was measured rather than
## reasoned about.[/b] The mark is flat and lies tangent to the surface at its
## middle, so it only sits cleanly on a surface that is flat or convex across the
## 26 cm it spans. Press on the lip of a wheel arch and the fender rises back
## toward the eye around the mark and swallows most of the ring — screenshotted,
## at 1 cm and again at 2 cm, and the extra centimetre changed almost nothing
## because a crease is not a curve. Accepted rather than worked around: on a
## panel, which is where nearly every press lands and where all of the detailing
## work will happen, it reads correctly, and the alternative — drawing the mark
## on top of everything with the depth test off — would paint a crosshair over
## the player's own tool whenever the wand swung across it, which is worse and
## far more often. A patch of grime laid the same way will inherit exactly this,
## which is a better reason to solve it properly later than to paper over it now.
const LIFT: float = 0.02

## When a normal is too near the reference axis to build a basis against. Squared
## length of a cross product, so this is about a quarter of a degree of
## parallelism — far tighter than any panel normal comes to it, and there purely
## so a straight-up normal cannot produce a zero-length axis.
const TOO_PARALLEL: float = 0.0001

var _point: Vector3 = Vector3.ZERO
var _pieces: Array[MeshInstance3D] = []


func _ready() -> void:
	visible = false
	var paint: StandardMaterial3D = _paint()
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = RING_INNER
	ring.outer_radius = RING_OUTER
	_add("Ring", ring, paint, Basis.IDENTITY)
	var bar: BoxMesh = BoxMesh.new()
	bar.size = Vector3(BAR_LENGTH, BAR_DEPTH, BAR_WIDTH)
	# The same mesh twice, the second turned a quarter turn about the surface
	# normal. One resource, so the two arms of the crosshair cannot end up
	# different lengths.
	_add("BarAcross", bar, paint, Basis.IDENTITY)
	_add("BarAlong", bar, paint, Basis(Vector3.UP, PI * 0.5))


## Puts the crosshair on the surface at [param point], lying flat against a
## panel whose surface normal is [param outward].
func mark(point: Vector3, outward: Vector3) -> void:
	var up: Vector3 = outward.normalized()
	if up == Vector3.ZERO:
		up = Vector3.UP
	_point = point
	global_transform = Transform3D(_lying_on(up), point + up * LIFT)
	visible = true


## Takes the crosshair off the car. Called when the player lifts their finger:
## holding the glass is aiming, so letting go is not aiming, and a mark left
## behind would say the tool is still pointed at something.
func unmark() -> void:
	visible = false


## Whether the crosshair is on the car right now.
func is_marking() -> bool:
	return visible


## Whether the ring and bars are drawn at all.
##
## Separate from marking on purpose — see the class docs. A tool that shows the
## player where it is pointed by some better means says so here, and the mark
## goes on being made either way; a caller that never asks gets the crosshair,
## which is what four of the five tools want.
##
## Set on the pieces rather than on this node, because hiding the node itself is
## what [method unmark] means and one flag cannot be two states.
func draw_crosshair(drawn: bool) -> void:
	for piece: MeshInstance3D in _pieces:
		piece.visible = drawn


## Whether the crosshair itself would be seen if something were marked. What a
## test asks instead of reaching into the children by name.
func is_crosshair_drawn() -> bool:
	return not _pieces.is_empty() and _pieces[0].visible


## The point last marked, without the [constant LIFT] — the place on the
## bodywork, rather than where the mesh had to be put to be seen. This is the
## answer a test wants, and the one a patch of grime will want.
func marked_point() -> Vector3:
	return _point


## A basis whose [code]+Y[/code] is [param up], which is the axis a [TorusMesh]
## is built around and the one the bars are flattened along — so orienting the
## whole mark is a single rotation and the three meshes cannot disagree about
## which way is off the paint.
##
## The reference axis is swapped when the normal is too near it to cross with,
## which happens on exactly one surface in this game and it is the one the player
## looks down at most: the roof.
func _lying_on(up: Vector3) -> Basis:
	var across: Vector3 = up.cross(Vector3.FORWARD)
	if across.length_squared() < TOO_PARALLEL:
		across = up.cross(Vector3.RIGHT)
	across = across.normalized()
	return Basis(across, up, across.cross(up))


## The one material every piece of the mark shares. See the class docs on why it
## is unshaded; [code]CULL_DISABLED[/code] because a bar 4 mm thick seen from
## below is a back face, and a crosshair with a missing arm reads as a bug.
func _paint() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = COLOR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## One piece of the crosshair. Shadows off: a piece of UI that cast one would
## put a red ring's shadow on the car beside the red ring.
func _add(named: String, mesh: Mesh, paint: StandardMaterial3D, turned: Basis) -> void:
	var piece: MeshInstance3D = MeshInstance3D.new()
	piece.name = named
	piece.mesh = mesh
	piece.material_override = paint
	piece.basis = turned
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(piece)
	_pieces.append(piece)
