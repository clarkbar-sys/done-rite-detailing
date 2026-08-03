## What comes out of the two bottles: a short, soft cone of product thrown from
## the can's nozzle at the paint a few inches in front of it.
##
## [b]It is [WashJet]'s trick at a tenth of the scale, and the differences are
## the point.[/b] The water is a jet — three hundred fast droplets crossing two
## metres from a wand held at the hip. This is an aerosol: a hundred and fifty
## slow ones crossing a quarter of a metre from a can [ReachCarry] has already
## carried out to the panel. Everything below falls out of that one sentence — slower,
## smaller, wider, fainter, and gone almost as soon as it has left.
##
## [b]The colour is the product, and it is why this is not just a paler
## [WashJet].[/b] Glass cleaner sprays blue and tyre cleaner sprays green,
## because that is what they leave behind — [method Surface.product_from] is
## asked, so the mist in the air and the film on the panel are the same colour
## from the same place and cannot drift apart. It is also the only feedback in
## the game that says [i]which bottle you are holding[/i] while you are looking at
## the car rather than at the corner of the screen.
##
## [b]Pale where it leaves and full-strength where it lands[/b], which is the
## opposite way round from the water and is right for the same reason the water's
## is. A jet is bright at the nozzle because it is under pressure and dull when it
## arrives spent; an aerosol leaves as a fine haze that is barely coloured at all
## and gathers into the product's own colour as the droplets grow and crowd
## together. [constant HAZE] is that, and it is one call to
## [method Color.lightened] rather than a second colour per bottle to keep in step.
##
## [b]It sprays whatever the panel is made of.[/b] Pointing the tyre cleaner at a
## window still puts green mist in the air and still does nothing to the glass —
## the refusal lives in [method Garage._spend_the_trigger] and stays there. A can
## that visibly stopped working when it was aimed at the wrong thing would read as
## a broken can; one that sprays and achieves nothing reads as the wrong bottle,
## which is the thing worth learning. That is the same argument that method
## already makes about doing nothing rather than working slowly, applied to what
## the player can see rather than to what the texture does.
##
## [b]No gravity, no collision, emitted into the world, unshaded[/b] — all four
## for [WashJet]'s reasons, which are written out at length there and are not
## weaker here: over a ten-centimetre throw a sag would be invisible and a
## collision bake would be no cheaper. The one that is worth restating is the
## world-space emission, because at this range it is the whole of why the mist
## reads as leaving the can: the droplets are put down at the nozzle and stay
## where they were put, so a can moved across a panel lays a trail behind it
## instead of dragging a cone around with it.
##
## [b]Owned by the room and stood on the nozzle[/b], exactly like the water, and
## for the same reason: [Garage] is what knows how wide a cleaner reaches
## ([member Garage.scrub_radius_metres]) and which bottle is in hand, and the
## viewmodel should not grow an opinion about either.
class_name SprayMist
extends Node3D

## What the emitter child is called, so a test can reach the mist rather than
## counting children.
const MIST: String = "Mist"

## How much lighter than the product itself the spray is where it leaves the
## nozzle, 0 to 1. Just under half — see the class docs: an aerosol starts as a
## haze with barely any colour in it and gathers into the product as it lands.
const HAZE: float = 0.45

## How opaque the middle of one droplet renders, 0 to 1. Fainter than the water's,
## because there are fewer of them and the whole cone is on screen at once at this
## range — at the jet's opacity a hundred and fifty of them over a quarter of a
## metre is a solid lozenge of paint rather than a spray.
const OPACITY: float = 0.42

## How far along its life a droplet starts fading to nothing, 0 at the nozzle to
## 1 at the end. Earlier than the water's, so the far edge of the cone is soft
## rather than a wall of droplets stopping on the paint — over a throw this short
## there is no room for a hard front to read as anything but a smear.
const SPENT: float = 0.55

## How fast the product leaves the can, in metres per second. Four, which crosses
## the standoff in about a fifteenth of a second: fast enough to be a spray rather
## than a puff, and slow enough that a droplet is drawn a handful of times on the
## way instead of appearing already landed.
const SPEED: float = 4.0

## How far past the mark a droplet lives, as a multiple of the throw. A fifth
## over, for [constant WashJet.OVERSHOOT]'s reason — the mist has to break over
## the panel rather than stop in the air in front of it — and a fifth of a quarter
## of a metre is five centimetres. [method landing] divides it back out.
const OVERSHOOT: float = 1.2

## How many droplets are in the air at once. A hundred and fifty: half the jet's,
## over a tenth of its throw, which is a far denser cone than the water makes and
## is what a can of anything actually produces.
const DROPS: int = 180

## How big one droplet is drawn, in metres, before [constant SMALLEST] and
## [constant BIGGEST] vary it. Under half the jet's, which is the same ratio as
## the reach: a droplet sized for a two-metre throw is a blob the size of the
## whole cone at a quarter of one.
const DROPLET: float = 0.08

## The range the per-droplet size is drawn from, as a multiple of
## [constant DROPLET]. Wider than the jet's, because a cone this short shows every
## droplet at once and identical ones read as a texture.
const SMALLEST: float = 0.4
const BIGGEST: float = 1.2

## How much of its final size a droplet is born at. Lower than the water's: an
## aerosol atomises immediately and the growth is most of what says so.
const BREAKUP: float = 0.4

## How many pixels across the droplet's own texture is built. Half the jet's,
## because these are drawn a good deal smaller and the content is still nothing
## but "round, and soft at the edges".
const DROP_PIXELS: int = 32

## How wide the hole the product comes out of is, as a radius in metres. Half a
## centimetre — a nozzle rather than a hose.
const NOZZLE: float = 0.006

## How far the emitter's own visibility box reaches, in metres. Measured in this
## node's space while the mist is out in the world's, so it has to hold the throw
## plus however far the can has travelled while a droplet was in the air. Three
## metres is past the whole reach of the hand.
const CARRY: float = 3.0

## A mark this close to the nozzle is the can standing in the paint. The same two
## centimetres [WashJet] uses, and here it is the one that can actually be reached
## — the standoff is only a quarter of a metre.
const POINT_BLANK: float = 0.02

## When the spray is too near the reference axis to build a basis against.
## Squared length of a cross product, so about a quarter of a degree — reached
## only by a can pointed straight up or straight down.
const TOO_PARALLEL: float = 0.0001

## The direction the product is thrown in, in this node's own space: down
## [code]-Z[/code], which is the axis a [GPUParticles3D] emits along.
const FAR_END: Vector3 = Vector3(0.0, 0.0, -1.0)

var _mist: GPUParticles3D = null
var _flight: ParticleProcessMaterial = null
var _fade: Gradient = null
var _product: Color = Color(0.0, 0.0, 0.0, 0.0)


func _ready() -> void:
	_flight = _thrown()
	_mist = _emitter(_flight)
	add_child(_mist)


## Puts the spray between [param from] — the can's nozzle — and [param onto], the
## point on the paint it is pointed at, spreading to [param radius] where it lands
## and coloured [param product].
##
## The same three-numbers-in-three-places arrangement [method WashJet.spray]
## documents: where and which way on this node's transform, how far on the
## emitter's lifetime, how wide on the process material's spread. [method landing]
## and [method spread] read the last two back, so there is no fourth copy of the
## reach anywhere.
##
## A degenerate call — a mark on top of the nozzle, or a spray with no width —
## stows rather than emitting product with nowhere to go.
func spray(from: Vector3, onto: Vector3, radius: float, tint: Color) -> void:
	var along: Vector3 = onto - from
	var reach: float = along.length()
	if reach <= POINT_BLANK or radius <= 0.0:
		stow()
		return
	var forward: Vector3 = along / reach
	var across: Vector3 = forward.cross(Vector3.UP)
	if across.length_squared() < TOO_PARALLEL:
		across = forward.cross(Vector3.RIGHT)
	across = across.normalized()
	# Orthonormal for [method WashJet.spray]'s reason: this transform says where the
	# mist starts and which way it goes, and a stretched basis would squash every
	# billboard in flight.
	global_transform = Transform3D(Basis(across, across.cross(forward), -forward), from)
	_mist.lifetime = reach * OVERSHOOT / SPEED
	# `asin` of the flown distance, and not [method WashJet.spray]'s `atan` of the
	# reach. Both answer "what half-angle puts `radius` on the mark", and they agree
	# to a percent for a jet, which fans about ten degrees — a droplet fired at a
	# small angle arrives at very nearly the same depth as one fired straight ahead,
	# so treating the landing as a flat plane costs nothing. A can sprays at fifty,
	# where it costs everything: every droplet flies the same distance whatever
	# angle it left at, so the mist lands on a piece of a sphere and `tan` overstates
	# how wide that is by half again. Measured rather than reasoned about — the first
	# version of this used `atan`, asked for a fan twice as wide as the throw was
	# long, and rendered as a faint ball around the nozzle.
	_flight.spread = rad_to_deg(asin(clampf(radius / (reach * OVERSHOOT), 0.0, 1.0)))
	_repaint(tint)
	_mist.emitting = true


## Takes the finger off: the trigger is up, or the tool in hand is not one of the
## two that spray.
##
## Stops emitting rather than hiding, so whatever is already in the air lands
## instead of blinking out — the same rule the water keeps, and at this range it
## is the difference between a can that stops and a can that is switched off.
func stow() -> void:
	_mist.emitting = false


## Whether product is leaving the can right now.
func is_spraying() -> bool:
	return _mist.emitting


## What is being sprayed, as a colour. What a test asks instead of unpicking a
## gradient, and the answer that has to match [method Surface.product_from] for
## the bottle in hand.
func product() -> Color:
	return _product


## Where the spray lands, in the world — the middle of the patch it arrives on.
## Read back off the throw the emitter is actually flying, for
## [method WashJet.landing]'s reason.
func landing() -> Vector3:
	return global_transform * (FAR_END * _throw())


## How wide the cone is where it lands, as a radius in metres — how far off the
## axis the outermost droplet gets, which for a fan this wide is the distance it
## flew rather than the depth it reached. See [method spray] for why that
## distinction is the whole difference between a spray and a smudge.
func spread() -> float:
	return sin(deg_to_rad(_flight.spread)) * _throw() * OVERSHOOT


## How far the product gets before it dies, in metres, with
## [constant OVERSHOOT] taken back off so this reports the mark rather than the
## couple of centimetres past it.
func _throw() -> float:
	return _mist.lifetime * SPEED / OVERSHOOT


## Repaints the ramp in [param tint], and does nothing at all when it has not
## changed — which is every tick of a held press, because a bottle does not change
## what is in it. A [GradientTexture1D] re-renders whenever its gradient does, so
## setting the same three colours sixty times a second would be sixty uploads of
## an identical texture.
func _repaint(tint: Color) -> void:
	if _product == tint:
		return
	_product = tint
	_fade.set_color(0, Color(tint.lightened(HAZE), OPACITY))
	_fade.set_color(1, Color(tint, OPACITY))
	_fade.set_color(2, Color(tint, 0.0))


## The emitter, wired to [param flight] and to a billboard of the droplet.
## Sorted back to front and stepped on the frame clock for
## [method WashJet._emitter]'s reasons.
func _emitter(flight: ParticleProcessMaterial) -> GPUParticles3D:
	var mist: GPUParticles3D = GPUParticles3D.new()
	mist.name = MIST
	mist.emitting = false
	mist.amount = DROPS
	mist.process_material = flight
	mist.draw_pass_1 = _droplet()
	mist.material_override = _haze()
	mist.local_coords = false
	mist.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	mist.fixed_fps = 0
	mist.visibility_aabb = AABB(Vector3.ONE * -CARRY, Vector3.ONE * (CARRY * 2.0))
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mist


## How the product flies: out of a nozzle-sized hole, down [constant FAR_END]
## into whatever cone [method spray] has set, at one speed, in a straight line.
func _thrown() -> ParticleProcessMaterial:
	var flight: ParticleProcessMaterial = ParticleProcessMaterial.new()
	flight.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	flight.emission_sphere_radius = NOZZLE
	flight.direction = FAR_END
	flight.initial_velocity_min = SPEED
	flight.initial_velocity_max = SPEED
	flight.gravity = Vector3.ZERO
	flight.scale_min = SMALLEST
	flight.scale_max = BIGGEST
	flight.scale_curve = _breakup()
	flight.color_ramp = _ramp()
	return flight


## The droplet: a quad, billboarded by [method _haze].
func _droplet() -> QuadMesh:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(DROPLET, DROPLET)
	return quad


## The round soft fade that makes a quad look like a speck of spray rather than
## like a square. Built in code for [method WashJet._drop]'s reason.
func _drop() -> GradientTexture2D:
	var fade: Gradient = Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 1.0])
	fade.colors = PackedColorArray([Color.WHITE, Color(Color.WHITE, 0.0)])
	var drop: GradientTexture2D = GradientTexture2D.new()
	drop.gradient = fade
	drop.width = DROP_PIXELS
	drop.height = DROP_PIXELS
	drop.fill = GradientTexture2D.FILL_RADIAL
	drop.fill_from = Vector2(0.5, 0.5)
	drop.fill_to = Vector2(0.5, 1.0)
	return drop


## What the mist is made of. Billboarded, scaled with the particle, unshaded,
## vertex-coloured and depth-write-off — all five for
## [method WashJet._mist]'s reasons.
func _haze() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.albedo_texture = _drop()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## The haze-to-product run down the throw, plus the fade that takes the flat front
## off the far end of it.
##
## Built once with three stops in it and repainted in place by [method _repaint],
## rather than rebuilt per bottle: the offsets never change and only the colours
## do, so the gradient this class keeps is the shape of the spray and the bottle
## only supplies its colour.
func _ramp() -> GradientTexture1D:
	_fade = Gradient.new()
	_fade.offsets = PackedFloat32Array([0.0, SPENT, 1.0])
	_fade.colors = PackedColorArray([Color.TRANSPARENT, Color.TRANSPARENT, Color.TRANSPARENT])
	var ramp: GradientTexture1D = GradientTexture1D.new()
	ramp.gradient = _fade
	return ramp


## How a droplet grows on the way: [constant BREAKUP] of its size at the nozzle,
## all of it by the time it arrives. The stream coming apart into spray, as one
## curve rather than a second particle system.
func _breakup() -> CurveTexture:
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, BREAKUP))
	curve.add_point(Vector2(1.0, 1.0))
	var growth: CurveTexture = CurveTexture.new()
	growth.curve = curve
	return growth
