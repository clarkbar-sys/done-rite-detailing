## What the sponge squeezes out: white suds pushed out of its own footprint,
## creeping outward along the panel and sitting where they land.
##
## [b]The first effect in this room that is not a cone from a point.[/b] The
## water ([WashJet]) and the product ([SprayMist]) are both a nozzle throwing
## something at a target, because both tools have a nozzle. A sponge has a face.
## Pressed against paint it does not throw anything anywhere — it squeezes, and
## the foam comes out at the edges of the thing doing the squeezing. So the
## emission shape here is a [i]ring[/i] rather than a cone, laid in the panel's
## own plane, and the motion is outward across the paint rather than toward it.
## That is the whole difference between this and a third [SprayMist], and it is
## why [method ToolCarry.has_ends] answering "no" for the sponge is the right
## answer rather than a gap to paper over.
##
## [b]Born on the sponge and spreading to the patch it is cleaning.[/b] Two
## radii, and they are two different facts: the ring is the rim of the sponge's
## own footprint ([member DetailingTool.extent], read by [method ToolSight.sight]
## where the catalogue is in scope), and the distance the foam creeps is whatever
## it takes to reach [member Garage.scrub_radius_metres] — the patch
## [method Garage._spend_the_trigger] is actually laying product on. So the suds
## start at the edge of the thing you can see and finish at the edge of the work,
## and neither number is invented here. [method rim] and [method reach] read both
## back off the emitter for [method WashJet.landing]'s reason: what is asserted on
## is the thing that draws, not a field sitting beside it.
##
## [b]They slow down instead of stopping.[/b] [constant CREEP] is what a squeeze
## pushes foam out at, and [method _settling] runs it down to nothing over a
## droplet's life — foam that left at a constant speed and then vanished mid-slide
## would read as something blown across the paint. Because that ramp is symmetric,
## a bubble covers exactly [constant SETTLING] of [constant CREEP] times its
## lifetime, which is the arithmetic [method squeeze] inverts to set the lifetime
## in the first place.
##
## [b]No gravity[/b], for [WashJet]'s reason and one more: suds on a vertical door
## really do run, but they run over seconds and the trigger is held for a fraction
## of one. What a sag would actually produce is foam sliding off the bottom of the
## patch the sponge is cleaning, which is the picture and the work disagreeing.
##
## [b]Emitted into the world, not into this node[/b] — [WashJet]'s argument, and
## it matters more here than anywhere. Foam sits where it is put. A sponge dragged
## along a wing lays a band of suds behind it; foam parented to the sponge would be
## a wig being waved.
##
## [b]The colour is the panel's own product[/b] and is handed in rather than
## chosen: [method Surface.product_from] for the sponge is
## [constant Surface.BODY_PRODUCT], which is the white
## [code]src/world/grime.gdshader[/code] draws the film in. The suds in the air and
## the film on the paint cannot drift apart, which is the same promise [SprayMist]
## keeps for the two bottles.
##
## [b]Owned by the room and stood on the mark[/b], like the other two effects, for
## [SprayMist]'s reason: [Garage] is what knows how wide a sponge cleans, and the
## viewmodel should not grow a second opinion about it.
class_name SpongeSuds
extends Node3D

## What the emitter child is called, so a test can reach the foam rather than
## counting children.
const SUDS: String = "Suds"

## How opaque the middle of one bubble renders, 0 to 1. Half — thicker than
## either spray, because foam is the one thing here that is meant to obscure the
## paint rather than hang in front of it, and because there is no depth for it to
## stack up through: every bubble is on the same plane.
const OPACITY: float = 0.5

## How far into its life a bubble is fully there, 0 at the rim to 1 at the end.
## A tenth, which is a squeeze rather than a fade-in — long enough that suds are
## not born at full strength on the sponge's own edge, short enough that they are
## foam by the time they have left it.
const LATHER: float = 0.12

## How far along its life a bubble starts going. Foam does not stop, it thins and
## pops, so the last third of the slide is spent disappearing — which is also
## what keeps the outer edge of the patch soft rather than a ring of suds all
## ending at the same radius.
const SPENT: float = 0.62

## How fast the squeeze pushes foam out at the sponge's rim, in metres per
## second. A quarter of a metre a second, run down to nothing by
## [method _settling]: at the sizes below that is about a second of visible
## creep, which is slow enough to read as foam spreading and fast enough that a
## short press still produces some.
const CREEP: float = 0.25

## What fraction of [constant CREEP] a bubble averages over its life — the mean
## of [method _settling], which runs from full to nothing and is symmetric about
## its middle, so exactly half. Written down because [method squeeze] divides by
## it to turn a distance into a lifetime and [method reach] multiplies by it to
## turn that lifetime back into a distance.
const SETTLING: float = 0.5

## How many bubbles are in the air at once. The most of the three effects, and
## measured rather than reasoned about: foam reads as foam by being crowded, and
## at the mist's count the ring rendered as a wreath of separate dots orbiting the
## sponge rather than as lather being squeezed out of it. Only ever one emitter is
## running, so this is not three hundred more particles on the frame — it is the
## same budget spent on the tool that is in hand.
const BUBBLES: int = 320

## How big one bubble is drawn, in metres, before [constant SMALLEST] and
## [constant BIGGEST] vary it. Seven and a half centimetres against a patch about
## twenty across — the same "a soft round blob is narrower than the square it is
## drawn in" that [constant WashJet.DROPLET] records at length, and the other half
## of the crowding [constant BUBBLES] is for.
const BUBBLE: float = 0.075

## The range the per-bubble size is drawn from, as a multiple of
## [constant BUBBLE]. The widest range of the three effects, on purpose: suds are
## lumpy, and identically sized ones read as a printed texture rather than as
## something the sponge just made.
const SMALLEST: float = 0.35
const BIGGEST: float = 1.3

## How much of its final size a bubble is born at. Foam swells as it comes out
## from under the sponge, which is [constant WashJet.BREAKUP]'s trick doing the
## opposite job — a stream coming apart there, a lather building up here.
const SWELL: float = 0.45

## How many pixels across the bubble's own texture is built. The mist's, for the
## mist's reason: the content is "round, and soft at the edges" and nothing else.
const BUBBLE_PIXELS: int = 32

## How far inside the rim the band of foam starts, as a fraction of it. Suds are
## squeezed out of a face rather than off a wire, so they are born across the
## last quarter or so of the sponge's own footprint — a ring with no thickness
## reads as an outline drawn around the tool.
const BAND: float = 0.72

## How thick the band is measured along the panel's normal, in metres. A
## centimetre: enough that the foam has a body rather than being painted onto a
## plane, and far less than anything it is being drawn beside.
const SLAB: float = 0.01

## How far off the paint the ring sits, in metres. A shade over a centimetre —
## less than [constant AimMarker.LIFT], because the crosshair has to clear the
## bodywork and the foam has to sit on it.
const LIFT: float = 0.012

## How far the emitter's own visibility box reaches, in metres. Measured in this
## node's space while the foam is out in the world's, so it has to hold the
## spread plus however far the sponge has travelled while a bubble was alive.
## Three metres is past the whole reach of the hand — [constant SprayMist.CARRY]'s
## number, for its reason.
const CARRY: float = 3.0

## The axis the ring is built around, in this node's own space: [code]+Y[/code],
## which [method squeeze] puts on the panel's normal. So the ring lies in the
## paint's own plane and the foam creeps across it rather than into it.
const FLAT: Vector3 = Vector3.UP

## When the panel's normal is too near the reference axis to build a basis
## against. Squared length of a cross product, so about a quarter of a degree —
## [ReachCarry]'s guard, here for its reason rather than because a panel like
## that is expected.
const TOO_PARALLEL: float = 0.0001

## What to cross with when the normal is the reference axis itself: the roof
## looked straight down at, and the floor of a wheel arch.
const FALLBACK: Vector3 = Vector3.RIGHT

var _suds: GPUParticles3D = null
var _flight: ParticleProcessMaterial = null
var _fade: Gradient = null
var _product: Color = Color(0.0, 0.0, 0.0, 0.0)


func _ready() -> void:
	_flight = _squeezed()
	_suds = _emitter(_flight)
	add_child(_suds)


## Puts foam around the sponge: a ring of radius [param rim] laid on the paint at
## [param at], which faces [param outward], creeping out to [param reach] and
## coloured [param tint].
##
## [b]Three numbers in three places that cannot disagree[/b], the same
## arrangement [method WashJet.spray] documents and with one of them moved: where
## and which way go on this node's transform, how wide the sponge is goes on the
## process material's ring, and how far the foam gets goes on the emitter's
## lifetime. [method rim] and [method reach] read the last two back, so there is
## no second copy of either.
##
## A degenerate call — a sponge with no footprint, a patch no wider than the
## sponge, or a mark with no measured normal — stows rather than emitting foam
## with nowhere to go.
func squeeze(
	at: Vector3, outward: Vector3, rim_radius: float, reach_radius: float, tint: Color
) -> void:
	var up: Vector3 = outward.normalized()
	if up.is_zero_approx() or rim_radius <= 0.0 or reach_radius <= rim_radius:
		stow()
		return
	# Orthonormal, for [method WashJet.spray]'s reason: this transform says where
	# the ring is and which way the paint faces, and a stretched basis would squash
	# every bubble sitting in it.
	global_transform = Transform3D(_lying_on(up), at + up * LIFT)
	_flight.emission_ring_radius = rim_radius
	_flight.emission_ring_inner_radius = rim_radius * BAND
	# The slide, inverted: a bubble averages [constant SETTLING] of
	# [constant CREEP], so this is exactly how long it takes the outermost foam to
	# arrive at the edge of the patch the sponge is cleaning.
	_suds.lifetime = (reach_radius - rim_radius) / (CREEP * SETTLING)
	_repaint(tint)
	_suds.emitting = true


## Takes the sponge off the paint: the trigger is up, or the tool in hand is not
## the sponge.
##
## Stops emitting rather than hiding, for the reason the other two effects stop
## that way — and it is at its most obvious here, because foam that vanished the
## instant the finger came up would take the whole lather with it while the
## player was still looking at the panel they had just soaped.
func stow() -> void:
	_suds.emitting = false


## Whether the sponge is squeezing right now. The trigger, not "is there anything
## on screen" — the last of the foam outlives this by about a second.
func is_squeezing() -> bool:
	return _suds.emitting


## What is being squeezed out, as a colour. What a test asks instead of unpicking
## a gradient, and the answer that has to match [method Surface.product_from] for
## the sponge.
func product() -> Color:
	return _product


## How wide the ring the foam is born on is, as a radius in metres — the sponge's
## own footprint, read back off the emission shape it was actually set on.
func rim() -> float:
	return _flight.emission_ring_radius


## How far out the foam gets before it dies, as a radius in metres. The ring plus
## the slide, and the slide is read off the lifetime the emitter is actually
## running — so foam that spread further than the patch being cleaned fails the
## same assertion the water's reach does.
func reach() -> float:
	return rim() + _suds.lifetime * CREEP * SETTLING


## Repaints the ramp in [param tint], and does nothing when it has not changed —
## [method SprayMist._repaint]'s reason, and the sponge changes what is in it even
## less often than a bottle does.
func _repaint(tint: Color) -> void:
	if _product == tint:
		return
	_product = tint
	_fade.set_color(0, Color(tint, 0.0))
	_fade.set_color(1, Color(tint, OPACITY))
	_fade.set_color(2, Color(tint, OPACITY))
	_fade.set_color(3, Color(tint, 0.0))


## A basis whose [code]+Y[/code] is [param up] — [method ReachCarry._lying_on]'s
## shape, against a world axis rather than the frame's own up.
##
## The roll is not fixed to anything on purpose, unlike the sponge's: a ring is
## round, so which way round it is built is not a fact anybody can see. What has
## to be true is only that [constant FLAT] ends up on the panel's normal, which is
## what puts the foam in the paint's plane.
func _lying_on(up: Vector3) -> Basis:
	var across: Vector3 = up.cross(Vector3.UP)
	if across.length_squared() < TOO_PARALLEL:
		across = up.cross(FALLBACK)
	across = across.normalized()
	return Basis(across, up, across.cross(up))


## The emitter, wired to [param flight] and to a billboard of one bubble. Sorted
## back to front and stepped on the frame clock for [method WashJet._emitter]'s
## reasons.
func _emitter(flight: ParticleProcessMaterial) -> GPUParticles3D:
	var suds: GPUParticles3D = GPUParticles3D.new()
	suds.name = SUDS
	suds.emitting = false
	suds.amount = BUBBLES
	suds.process_material = flight
	suds.draw_pass_1 = _bubble()
	suds.material_override = _lather()
	suds.local_coords = false
	suds.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	suds.fixed_fps = 0
	suds.visibility_aabb = AABB(Vector3.ONE * -CARRY, Vector3.ONE * (CARRY * 2.0))
	suds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return suds


## How the foam moves: born in a flat band around [constant FLAT], with no
## velocity of its own, pushed away from the middle of that band at
## [constant CREEP] and slowing to a stop.
##
## [b]Radial velocity rather than a direction and a spread[/b], which is what
## makes this a ring instead of a cone. A cone has one axis and everything in it
## goes the same way; foam squeezed out of a sponge goes a different way at every
## point of the rim, and "away from the middle" is that in one property rather
## than in a mesh full of baked normals.
func _squeezed() -> ParticleProcessMaterial:
	var flight: ParticleProcessMaterial = ParticleProcessMaterial.new()
	flight.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	flight.emission_ring_axis = FLAT
	flight.emission_ring_height = SLAB
	flight.initial_velocity_min = 0.0
	flight.initial_velocity_max = 0.0
	flight.radial_velocity_min = CREEP
	flight.radial_velocity_max = CREEP
	flight.radial_velocity_curve = _settling()
	# See the class docs: foam that ran down the door would be the picture and the
	# work disagreeing about which patch is being cleaned.
	flight.gravity = Vector3.ZERO
	flight.scale_min = SMALLEST
	flight.scale_max = BIGGEST
	flight.scale_curve = _swell()
	flight.color_ramp = _ramp()
	return flight


## One bubble: a quad, billboarded by [method _lather].
func _bubble() -> QuadMesh:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(BUBBLE, BUBBLE)
	return quad


## The round soft fade that makes a quad look like a blob of foam rather than
## like a square. Built in code for [method WashJet._drop]'s reason.
func _blob() -> GradientTexture2D:
	var fade: Gradient = Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 1.0])
	fade.colors = PackedColorArray([Color.WHITE, Color(Color.WHITE, 0.0)])
	var blob: GradientTexture2D = GradientTexture2D.new()
	blob.gradient = fade
	blob.width = BUBBLE_PIXELS
	blob.height = BUBBLE_PIXELS
	blob.fill = GradientTexture2D.FILL_RADIAL
	blob.fill_from = Vector2(0.5, 0.5)
	blob.fill_to = Vector2(0.5, 1.0)
	return blob


## What the foam is made of. Billboarded, scaled with the particle, unshaded,
## vertex-coloured and depth-write-off — all five for [method WashJet._mist]'s
## reasons, and the last one earns its keep here: every bubble is on one plane, so
## without it they would punch holes in each other rather than pile up into
## lather.
func _lather() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.albedo_texture = _blob()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## The lather-up-and-pop run across the slide: nothing at the rim,
## [constant OPACITY] by [constant LATHER], held to [constant SPENT], gone by the
## end.
##
## Built once with four stops in it and repainted in place by [method _repaint],
## for [method SprayMist._ramp]'s reason: the offsets are the shape of a squeeze
## and only the colour belongs to the product.
func _ramp() -> GradientTexture1D:
	_fade = Gradient.new()
	_fade.offsets = PackedFloat32Array([0.0, LATHER, SPENT, 1.0])
	_fade.colors = PackedColorArray(
		[Color.TRANSPARENT, Color.TRANSPARENT, Color.TRANSPARENT, Color.TRANSPARENT]
	)
	var ramp: GradientTexture1D = GradientTexture1D.new()
	ramp.gradient = _fade
	return ramp


## How the squeeze runs out: all of [constant CREEP] at the rim, nothing by the
## end of a bubble's life. Symmetric about its middle, which is what makes
## [constant SETTLING] exactly a half and lets [method reach] be arithmetic rather
## than a guess.
func _settling() -> CurveTexture:
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var slide: CurveTexture = CurveTexture.new()
	slide.curve = curve
	return slide


## How a bubble grows on the way out: [constant SWELL] of its size under the
## sponge, all of it once it is clear. Lather building up, as one curve rather
## than a second particle system.
func _swell() -> CurveTexture:
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, SWELL))
	curve.add_point(Vector2(1.0, 1.0))
	var growth: CurveTexture = CurveTexture.new()
	growth.curve = curve
	return growth
