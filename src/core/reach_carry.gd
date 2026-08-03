## The four tools that are used [i]at[/i] the paint rather than fired at it: the
## sponge and the rag go onto the panel, the two bottles hover a few inches off
## it and spray.
##
## [b]What this is for.[/b] [WandCarry] solved half of the problem — a tool that
## knows where the aim is — for the one tool whose product crosses the gap by
## itself. The other four have no jet: a sponge that stays in the corner of the
## frame while mud disappears two metres away is a game where the tool and the
## work are in different places, and a bottle held at the hip cannot be seen
## spraying anything. So they travel: while the finger is down, the tool leaves
## the hand and arrives on the mark, and the work happens where the player can
## see it happening.
##
## [b]One class, two settings, and the settings are the whole difference.[/b]
##
## [codeblock]
##                     standoff   tilt      what it looks like
## sponge, rag          ~0 m      0°        lying flat on the panel
## window, tire bottle  ~0.1 m    150°      held off it, nozzle pointed at it
## [/codeblock]
##
## [member _standoff] is how far off the paint the tool's working end sits, and
## [member _tilt] is the angle between the tool's own [code]+Y[/code] and the
## surface normal — [code]0°[/code] lying along it, [code]180°[/code] pointed
## straight into the paint. A can at exactly 180° is a disc seen end-on from the
## player's side, which is [ViewModel]'s "no cylinder points down the barrel"
## rule arriving from a new direction; 150° leans it thirty degrees off so its
## length reads, and leans it [i]upward[/i], which is the way a hand holds a can
## it is spraying downward at something.
##
## A tool that is not a cylinder has no meaningful nozzle, so [member _length] is
## zero for the sponge and the rag and the standoff is measured to the tool's own
## middle instead. That is the one place the two settings above are not
## symmetrical, and it is why the sponge's standoff has to include half its own
## thickness — see [method ViewModel._carry_for], which does that arithmetic
## where the extents live.
##
## [b]It arrives rather than teleporting[/b], exactly like the wand:
## [param raise] is the eased 0-to-1 from [method ToolAim.raise_amount] and the
## two poses are blended through it. Letting go brings the tool back to the hand
## the same way. That matters more here than it does for the wand, because the
## distance travelled is the whole reach to the car rather than a turn of the
## wrist — a sponge that appeared on the paint between two frames would read as a
## rendering fault rather than as an arm.
##
## [b]And the resting pose is untouched.[/b] Nothing about how these four sit in
## the hand has changed; [method ViewModel._held_pose] still says it, and it is
## still what the near-plane and ground clearance tests measure. This is only
## what happens between a press and a release.
##
## A [RefCounted] like every other carry, for [ToolCarry]'s reason: it is
## arithmetic about a pose, so the geometry below is a unit test rather than
## something somebody checks by looking at it.
class_name ReachCarry
extends ToolCarry

## The tool's own long axis, and the end that works. [code]+Y[/code] because that
## is the axis a [CylinderMesh] is built along and the axis a [BoxMesh]'s height
## runs up — see [method ViewModel._mesh_for] — so the nozzle is the top of a
## bottle and the flat face of the sponge is the bottom of the box.
const AXIS: Vector3 = Vector3.UP

## Which way is up in the hand's own frame, and so the direction a tilted bottle
## leans toward. The hand is the camera turned by the aim and the camera is
## level, so this really is up as the player sees it.
##
## The same vector as [constant AXIS] and emphatically not the same thing: one is
## a fact about how the mesh was built and the other is a fact about how the shot
## is framed. They are written separately so that changing either does not
## silently change the other.
const UPRIGHT: Vector3 = Vector3.UP

## Degrees to radians, for [member _tilt]. Degrees on the outside because that is
## what a person tuning a pose thinks in — the same choice
## [member ViewModel.PER_DEGREE] and [member ToolAim.PER_DEGREE] make.
const PER_DEGREE: float = PI / 180.0

## When two directions are too near parallel to build a basis against. Squared
## length of a cross product, so about a quarter of a degree — reached only by a
## panel whose normal is dead level with the reference axis, and here so that
## such a panel cannot produce a zero-length axis rather than because one is
## expected.
const TOO_PARALLEL: float = 0.0001

## What to cross with when [constant UPRIGHT] itself is the direction being
## crossed. Reached by a panel whose normal is dead level with the frame's own up
## — the roof looked straight down at, and the floor of a wheel arch — which is
## rare rather than impossible, and is why this is here at all.
const FALLBACK: Vector3 = Vector3.RIGHT

var _standoff: float
var _tilt: float
var _length: float


func _init(held: Transform3D, standoff: float, tilt_degrees: float, length: float) -> void:
	super(held)
	_standoff = maxf(standoff, 0.0)
	_tilt = tilt_degrees * PER_DEGREE
	_length = maxf(length, 0.0)


## Where the tool sits this frame: its resting pose blended [param raise] of the
## way toward working on the paint at [param toward], which faces [param outward].
## Both points are read in the hand's own space.
##
## [method Transform3D.interpolate_with] for [WandCarry]'s reason — the reach and
## the turn are one movement rather than a translation followed by a rotation.
func pose(toward: Vector3, outward: Vector3, raise: float) -> Transform3D:
	var lifted: float = clampf(raise, 0.0, 1.0)
	if lifted <= 0.0:
		return _rest
	return _rest.interpolate_with(worked(toward, outward), lifted)


## The pose that puts the tool on the job: its working end [member _standoff]
## metres off the paint at [param toward], turned [member _tilt] off the surface
## normal [param outward].
##
## [b]The standoff is measured to the nozzle and not to the middle.[/b] A bottle
## placed by its own origin would stand further off the paint the longer it got,
## which is a tuning number that changes meaning every time somebody resizes a
## proxy. So the nozzle is put where it belongs and the body is hung back off it
## along the tool's own axis — which is what makes "a few inches away from the
## spot" a sentence about the spray rather than about the mesh.
##
## Falls back to the resting pose when there is no normal to work against — a
## zero-length one, or a mark on top of the hand — for [method WandCarry.aligned]'s
## reason: the alternative is a basis built from a degenerate cross product, which
## is a NaN and a proxy that vanishes rather than a tool held wrong.
func worked(toward: Vector3, outward: Vector3) -> Transform3D:
	var off: Vector3 = outward.normalized()
	if off.is_zero_approx():
		# No measured normal: face the tool back at the hand, which is the same
		# answer [method Garage._nearest_on_the_car] invents for a mark it could not
		# measure one for, and is right for a press that landed on nothing.
		off = (-toward).normalized()
	if off.is_zero_approx():
		return _rest
	var nose: Vector3 = _nose(off)
	return Transform3D(_lying_on(nose), toward + off * _standoff - nose * (_length * 0.5))


## Yes, and for a reason the wand's is not: what this is pointed at is a place on
## a panel, and both the place and the panel's facing keep moving while the eye
## walks even on a frame where the swing itself has stopped.
func tracks_the_aim() -> bool:
	return true


## Whether this tool sprays, which is the same question as whether it has a
## nozzle: a length of nothing is the sponge and the rag, and neither emits
## anything.
func has_ends() -> bool:
	return _length > 0.0


## Where the nozzle sits in the tool's own space — the end the mist leaves from,
## and the end [method worked] measures the standoff to.
func nozzle() -> Vector3:
	return AXIS * _length * 0.5


## Which way the tool's own [code]+Y[/code] points, for a panel facing
## [param off]: the normal itself at no tilt, and swung [member _tilt] toward the
## floor of the frame past that.
##
## The rotation axis is [code]UPRIGHT × off[/code] rather than the other way
## round, and the order is the whole of which way a bottle leans. Crossed that
## way the tilt carries the nozzle down and the body up, so a can ends up above
## the spot angled down at it; crossed the other way it ends up below the spot
## angled up at it, which is not how anybody holds a can.
func _nose(off: Vector3) -> Vector3:
	if is_zero_approx(_tilt):
		return off
	var across: Vector3 = UPRIGHT.cross(off)
	if across.length_squared() < TOO_PARALLEL:
		across = FALLBACK.cross(off)
	return off.rotated(across.normalized(), _tilt)


## A basis whose [code]+Y[/code] is [param up] — the same shape
## [method AimMarker._lying_on] builds, against a different reference and for one
## more reason.
##
## [b]The reference is [constant UPRIGHT] and not a world axis[/b], which is what
## fixes the roll rather than leaving it to whatever a cross product happened to
## produce. Crossed against the frame's own up, the tool's [code]+X[/code] comes
## out level on screen: a sponge lands on a door with its long edge horizontal,
## and it stays horizontal as the player walks around the car instead of slowly
## rotating in place. The crosshair does not care about its own roll — a ring is
## round — which is why that class can cross against anything convenient and this
## one cannot.
func _lying_on(up: Vector3) -> Basis:
	var across: Vector3 = UPRIGHT.cross(up)
	if across.length_squared() < TOO_PARALLEL:
		across = FALLBACK.cross(up)
	across = across.normalized()
	return Basis(across, up, across.cross(up))
