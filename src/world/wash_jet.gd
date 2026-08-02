## The power wash's water, as water: a few hundred droplets thrown out of the
## nozzle at the paint, going blue-to-red down the throw and dying where they
## land.
##
## [b]This is the thing the cone was scaffolding for.[/b] What stood here was a
## solid cone of geometry from the nozzle to the mark, and its own class docs
## said as much: "the water will be a [GPUParticles3D] ... the geometry here is
## what stands in until then. It is here so the shape and the reach can be looked
## at and tuned before anything is emitted, which is much easier to do against a
## solid than against a particle count." The shape and the reach have been looked
## at and are unchanged. What was one surface saying where the water goes is now
## a few hundred things going there.
##
## [b]The three promises the cone made are kept, and kept the same way.[/b]
## [method landing] is the mark, [method spread] is
## [member Garage.wash_radius_metres] at that mark, and both are still read back
## out of the thing that draws rather than out of a field sitting beside it —
## off the emitter's own lifetime and spread angle now, where the transform's
## basis used to carry them. So this is still the physics drawn rather than an
## illustration of it: water that took longer to arrive than the trigger takes to
## clean, or fanned wider than the patch being cleaned, fails the same assertions
## it failed as a cone.
##
## [b]One speed, and the lifetime is what varies.[/b] Droplets leave at
## [constant SPEED] whatever the range, and live exactly long enough to cross it
## ([constant OVERSHOOT] aside) — so walking closer shortens the throw rather than
## slowing the water, which is what a pressure washer does and what the constant
## rate the [i]other[/i] way round would have got wrong. It also thickens the
## spray as you close in for free: the same [constant DROPS] in flight over a
## shorter throw is more of them per metre, which is the first thing standing
## closer ought to buy.
##
## [b]Nothing is randomised about that lifetime[/b], on purpose. It is the number
## [method landing] reads the throw back out of, and a random one would make the
## reach an average rather than a fact. The spray gets its ragged edge from the
## cone it is fired into, the sphere it is fired from and the size the droplets
## are drawn at — three places where randomness costs nothing that is being
## asserted on.
##
## [b]No gravity.[/b] Real water sags, and at these ranges it would sag a long
## way: a quarter-second flight under 9.8 m/s² drops 30 cm, which is most of the
## way off a door. The jet's whole job is to land on the mark the game has just
## drawn — the mud comes off there ([method Garage._spend_the_trigger]) — so a
## sag is not character, it is the water and the cleaning disagreeing about where
## the player is pointing. Zero, stated here rather than left at a default, so
## that the day somebody wants a droop it is a number they change rather than a
## line they add.
##
## [b]And no collision, which is a decision and not an omission.[/b] Godot can do
## it — [member ParticleProcessMaterial.collision_mode] plus a
## [GPUParticlesCollisionSDF3D] baked over the car — and it would cost a bake to
## keep in step with a CSG car that is still changing shape weekly, a texture in
## memory on a web build, and a per-particle SDF lookup on a phone. What it would
## buy is small, because the droplets already die at the mark and the mark is on
## the surface: what is actually visible without it is the odd droplet crossing a
## panel edge for a tenth of a second at a shallow angle. Water that goes through
## the car a little is a much better trade than a bake that goes stale.
##
## [b]Blue at the nozzle, red where it lands[/b] — the cone's gradient, in the
## colour ramp instead of in vertex colours. Water is at pressure where it leaves
## the wand and spent where it arrives, and the red end is the same red the
## crosshair used to be ([constant AimMarker.COLOR]) in the same place it used to
## be, so a player who learned "red is where my tool is pointed" still has that.
## The last stretch of the ramp fades to nothing as well as to red, which is what
## keeps the far end of the throw from reading as a flat wall of droplets all
## stopping at once.
##
## [b]And each droplet is at most [constant OPACITY] of the way opaque[/b], which
## is the cone's third of an alpha nudged up because it now means one droplet
## rather than the whole volume — and a droplet is a soft-edged blob, so most of
## its area is fainter than that again. A few of them overlap wherever the spray
## is thick, so the core of the jet comes out near solid while the paint stays
## visible through its edges: the read the cone needed a flat alpha to fake, done
## by there being more water in the middle of a jet.
##
## [b]Emitted into the world, not into this node.[/b] [member
## GPUParticles3D.local_coords] is off, so a droplet is placed once, at the nozzle
## as it was when it left, and keeps going wherever the wand goes afterwards.
## Water that follows the wand around is a hose being waved; water that is left
## behind by it is a jet. It also means this node's own transform is orthonormal
## and only says [i]where the nozzle is and which way it points[/i] — the reach
## and the width live on the emitter, and a non-uniform basis would have squashed
## every billboard in flight.
##
## [b]Owned by the room and put on the nozzle, rather than parented to it.[/b]
## The plan of record was to hang this off [code]ViewModel.MUZZLE[/code]. With
## world-space emission the two are the same water, and this way the room keeps
## the thing that knows [member Garage.wash_radius_metres] instead of the
## viewmodel growing an opinion about how wide the jet is. What it costs is that
## the emitter is placed on the physics tick and the wand is posed on the frame
## clock, so the water can leave from up to one frame behind the nozzle — a
## centimetre, at a walking pace, out of a hole a centimetre across.
##
## [b]Unshaded and shadowless[/b], for [AimMarker]'s reasons and the cone's: lit
## droplets would take the colour of the two strip lights and go dim on the far
## side of the car, and water that cast shadows would speckle the panel it is
## being sprayed at.
class_name WashJet
extends Node3D

## What the emitter child is called, so a test can reach the water rather than
## counting children.
const WATER: String = "Water"

## The colour at the nozzle: water under pressure, and a blue no tool on the
## belt wears (see [member DetailingTool.albedo]) so the jet can never be
## mistaken for the wand throwing a colour.
const TIP: Color = Color(0.24, 0.60, 1.0, 1.0)

## The colour where it lands. The crosshair's own red — see [constant
## AimMarker.COLOR] — because this end of the throw is doing that mark's job now,
## and a player who learned "red is where my tool is pointed" should not have to
## learn it twice.
const SPRAY: Color = Color(0.95, 0.13, 0.16, 1.0)

## How opaque the middle of one droplet renders, 0 to 1. See the class docs: a
## bit under half is what lets the thick middle of the jet stack up to something
## solid while the paint stays visible through the edges. Its own edges are
## softer than this again — [method _drop] fades every droplet to nothing at its
## rim — so the number is the most any single one of them can be.
const OPACITY: float = 0.45

## How far along the throw the fade to nothing starts, 0 at the nozzle to 1 at
## the end of a droplet's life. The last quarter or so, which is enough to take
## the flat front off a wall of droplets that all stop at the same distance
## without eating into the red that is doing the crosshair's job.
const SPENT: float = 0.72

## How fast the water leaves the nozzle, in metres per second. Fast enough that
## the throw is a quarter of a second at the range a car is washed from — a jet
## rather than a lob — and slow enough that a droplet is drawn a handful of times
## on the way rather than teleporting from the wand to the paint.
const SPEED: float = 9.0

## How far past the mark a droplet lives, as a multiple of the throw. The water
## is meant to break over the panel rather than stop in the air in front of it,
## and without collision the only way to look like it hit something is to be
## briefly inside it. A seventh of the throw is a few centimetres at these ranges
## — see the class docs on why going through the car is the cheap half of this
## trade. [method landing] divides it back out, so the reach this class reports
## is the mark and not the overshoot.
const OVERSHOOT: float = 1.15

## How many droplets are in the air at once. Three hundred covers the landing
## patch without the middle of the jet turning into a solid bar, and it is a count
## a phone browser can push every frame — this is the only particle system in the
## game.
const DROPS: int = 300

## How big one droplet is drawn, in metres, before [constant SMALLEST] and
## [constant BIGGEST] vary it, and before [method _drop] fades its edges away.
##
## Ten centimetres against a 0.4 m landing radius, which sounds far too big and
## is not: the drawn drop is a soft round blob inside that square, so the width
## that reads is a good deal less than the number. It was half this to begin with,
## which screenshotted as a fine mist somebody had aimed at the car rather than as
## a jet — the size is the one number here that has to be looked at rather than
## reasoned about, because it is the only one whose meaning depends on the texture
## drawn inside it.
const DROPLET: float = 0.10

## The range the per-droplet size is drawn from, as a multiple of
## [constant DROPLET]. A jet of identically sized dots reads as a texture rather
## than as water.
const SMALLEST: float = 0.5
const BIGGEST: float = 1.1

## How much of its final size a droplet is born at. Water leaves a nozzle as a
## stream and arrives as spray, so the droplets grow as they fly — the cheapest
## honest version of breaking up, and the thing that keeps the first few
## centimetres out of the nozzle looking like a jet rather than like a cloud.
const BREAKUP: float = 0.4

## How many pixels across the droplet's own texture is built. Sixty-four for a
## blob a few dozen pixels wide on screen at the most: it is a radial fade with
## no detail in it, and the only thing more resolution buys is memory.
const DROP_PIXELS: int = 64

## How wide the hole the water comes out of is, as a radius in metres. A
## centimetre or so: enough that the spray has a source rather than a point, and
## far smaller than anything downstream of it.
const NOZZLE: float = 0.012

## How far the emitter's own visibility box reaches, in metres. A particle system
## is culled as one object, and this box is measured in this node's space while
## the water is out in the world's — so it has to hold the longest throw
## [i]plus[/i] however far the player has walked while a droplet was in the air.
## Six metres is well past both, and the box is only ever tested against the
## frustum.
const CARRY: float = 6.0

## A mark this close to the nozzle is the wand standing in the paint, and a throw
## this short has nowhere to go. Two centimetres — the clearance
## [constant AimMarker.LIFT] keeps, borrowed as a floor rather than as a gap,
## since the water no longer needs to stop short of anything.
const POINT_BLANK: float = 0.02

## When the jet is too near the reference axis to build a basis against. Squared
## length of a cross product, so about a quarter of a degree of parallelism —
## reached only by a jet fired straight up or straight down, which the aim's own
## pitch fence rules out; here so that a caller without one cannot produce a
## zero-length axis.
const TOO_PARALLEL: float = 0.0001

## The direction the water is thrown in, in this node's own space: down
## [code]-Z[/code], which is the axis a [GPUParticles3D] emits along and the axis
## [method spray] points at the mark.
const FAR_END: Vector3 = Vector3(0.0, 0.0, -1.0)

var _water: GPUParticles3D = null
var _flight: ParticleProcessMaterial = null


func _ready() -> void:
	_flight = _thrown()
	_water = _emitter(_flight)
	add_child(_water)


## Puts the jet between [param from] — the nozzle — and [param onto], the point
## on the paint the tool is pointed at, spreading to [param radius] where it
## lands.
##
## [b]Nozzle to mark and not "along the wand".[/b] The two are the same line once
## the wand has finished coming up ([WandCarry] guarantees it, and
## [code]tests/integration/test_play_screen_wand.gd[/code] holds it), and they are
## briefly different while it is still swinging. Fired this way the water always
## reaches the paint: it converges onto the wand rather than lagging behind it,
## which is the more honest of the two now that the water has a travel time of
## its own.
##
## [b]Three numbers, in three places that cannot disagree.[/b] Where the nozzle is
## and which way it points go on this node's transform; how long the throw is goes
## on the emitter's lifetime; how wide it fans goes on the process material's
## spread angle. [method landing] and [method spread] read the last two back, so
## there is no fourth copy of the reach anywhere.
##
## A degenerate call — a mark on top of the nozzle, or a jet with no width —
## stows rather than emitting water with nowhere to go.
func spray(from: Vector3, onto: Vector3, radius: float) -> void:
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
	# Orthonormal, deliberately: this transform says where the water starts and
	# which way it goes and nothing else. The reach and the width are the two
	# lines below, on the emitter, where a stretched billboard cannot come of them.
	global_transform = Transform3D(Basis(across, across.cross(forward), -forward), from)
	_water.lifetime = reach * OVERSHOOT / SPEED
	# The half-angle that puts exactly `radius` on the mark from here — so walking
	# closer visibly narrows the jet, the same way it narrows the patch being
	# cleaned.
	_flight.spread = rad_to_deg(atan(radius / reach))
	_water.emitting = true


## Takes the trigger off: the finger is up, or the tool in hand is not the one
## that sprays.
##
## Stops emitting rather than hiding, so the water already in the air finishes
## its flight and lands. A jet that vanishes mid-throw is the one thing about
## letting go that a solid cone got wrong for free.
func stow() -> void:
	_water.emitting = false


## Whether water is leaving the nozzle right now. The trigger, in other words —
## not "is there anything on screen", which stays true for a quarter of a second
## after this goes false.
func is_spraying() -> bool:
	return _water.emitting


## Where the water lands, in the world — the middle of the patch it arrives on.
##
## Read back off the throw the emitter is actually flying rather than out of a
## field, so it is the drawn water being asserted on and not a number the drawing
## might have ignored.
func landing() -> Vector3:
	return global_transform * (FAR_END * _throw())


## How wide the spray is where it lands, as a radius in metres. Read the same way
## and for the same reason as [method landing]: the spread angle the droplets are
## actually fired into, at the range they actually reach.
func spread() -> float:
	return tan(deg_to_rad(_flight.spread)) * _throw()


## How far the water gets before it dies, in metres — [constant SPEED] for as
## long as it lives, with [constant OVERSHOOT] taken back off so that what this
## reports is the mark rather than the few centimetres past it.
func _throw() -> float:
	return _water.lifetime * SPEED / OVERSHOOT


## The emitter, wired to [param flight] and to a billboard of the water.
##
## [b]Sorted back to front[/b] rather than drawn in the order they were born:
## a few hundred transparent quads blended in emission order change appearance as
## the camera walks around them, which reads as the jet flickering.
##
## [b]Stepped on the frame clock[/b] — [member GPUParticles3D.fixed_fps] of zero
## — because the default 30 is a visible stutter on something crossing two metres
## in a quarter of a second, and this system is small enough that the saving is
## not worth spending.
func _emitter(flight: ParticleProcessMaterial) -> GPUParticles3D:
	var water: GPUParticles3D = GPUParticles3D.new()
	water.name = WATER
	water.emitting = false
	water.amount = DROPS
	water.process_material = flight
	water.draw_pass_1 = _droplet()
	water.material_override = _mist()
	water.local_coords = false
	water.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	water.fixed_fps = 0
	water.visibility_aabb = AABB(Vector3.ONE * -CARRY, Vector3.ONE * (CARRY * 2.0))
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return water


## How the water flies: out of a nozzle-sized hole, down [constant FAR_END] into
## whatever cone [method spray] has set, at one speed, in a straight line.
##
## The spread is left at whatever the class was built with and is set for real on
## the first press; every other number here is fixed and is never touched again.
func _thrown() -> ParticleProcessMaterial:
	var flight: ParticleProcessMaterial = ParticleProcessMaterial.new()
	flight.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	flight.emission_sphere_radius = NOZZLE
	flight.direction = FAR_END
	flight.initial_velocity_min = SPEED
	flight.initial_velocity_max = SPEED
	# See the class docs: water that sags misses the mark the game has just drawn.
	flight.gravity = Vector3.ZERO
	flight.scale_min = SMALLEST
	flight.scale_max = BIGGEST
	flight.scale_curve = _breakup()
	flight.color_ramp = _ramp()
	return flight


## The droplet itself: a quad, because it is billboarded at the camera by
## [method _mist] and every other face of a sphere would be work nobody sees.
func _droplet() -> QuadMesh:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(DROPLET, DROPLET)
	return quad


## What makes the quad above look like a drop of water rather than like a square:
## a radial fade from an opaque middle to nothing at the rim, multiplied over the
## droplet's colour by [method _mist].
##
## [b]Built in code, like every other surface in this room.[/b] A painted sprite
## sheet is what a real spray effect would use and it is the right answer the day
## there is an artist; until then a texture whose whole content is "round, and
## soft at the edges" is four lines here rather than a PNG in the repository that
## nobody can diff. Rendered without it, the jet is a few hundred hard-edged
## squares — screenshotted, and it reads as confetti rather than as water.
func _drop() -> GradientTexture2D:
	var fade: Gradient = Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 1.0])
	fade.colors = PackedColorArray([Color.WHITE, Color(Color.WHITE, 0.0)])
	var drop: GradientTexture2D = GradientTexture2D.new()
	drop.gradient = fade
	drop.width = DROP_PIXELS
	drop.height = DROP_PIXELS
	drop.fill = GradientTexture2D.FILL_RADIAL
	# Middle to edge, so the gradient above runs out along the radius rather than
	# across the square.
	drop.fill_from = Vector2(0.5, 0.5)
	drop.fill_to = Vector2(0.5, 1.0)
	return drop


## What the water is made of.
##
## [b]Billboarded[/b], so a droplet is round from wherever the player is standing
## rather than edge-on from half of them, and [b]scaled with it[/b], because a
## billboard that ignores the particle's own scale throws away
## [method _breakup]'s growth and both ends of the size range.
##
## [b]Unshaded[/b], for [AimMarker]'s reason: the same water on both sides of the
## car. [b]Vertex colours as albedo[/b], which is how a particle's colour reaches
## its mesh at all — the ramp in [method _ramp] arrives here as a vertex colour
## per droplet, and is multiplied by [method _drop]'s round fade to get one drop
## of water. [b]No depth write[/b], because droplets overlap by the dozen and
## none of them should punch a hole in the one behind it. The depth [i]test[/i] is
## left on, which is what makes water that flies into a panel disappear into it
## rather than smear across it.
func _mist() -> StandardMaterial3D:
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


## The blue-to-red run down the throw, plus the fade that takes the flat front
## off the far end of it. Three stops: [constant TIP] at the nozzle,
## [constant SPRAY] at [constant SPENT], and the same red gone to nothing by the
## time the droplet dies.
func _ramp() -> GradientTexture1D:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, SPENT, 1.0])
	gradient.colors = PackedColorArray(
		[
			Color(TIP, OPACITY),
			Color(SPRAY, OPACITY),
			Color(SPRAY, 0.0),
		]
	)
	var ramp: GradientTexture1D = GradientTexture1D.new()
	ramp.gradient = gradient
	return ramp


## How a droplet grows on the way: [constant BREAKUP] of its size at the nozzle,
## all of it by the time it arrives. See that constant — this is the stream
## coming apart into spray, and it is one curve rather than a second particle
## system.
func _breakup() -> CurveTexture:
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, BREAKUP))
	curve.add_point(Vector2(1.0, 1.0))
	var growth: CurveTexture = CurveTexture.new()
	growth.curve = curve
	return growth
