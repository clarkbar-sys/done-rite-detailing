## The power wash: a wand that lies along the line from the hand to whatever the
## player is aiming at, rather than at a fixed angle in it.
##
## [b]What this is for.[/b] The jet has to come out of the end of the wand and
## land on the mark, and it has to do that while the water is still an
## effect nobody has written yet. A wand held at a hand-tuned angle can only
## manage that by having the particles ignore the mesh they leave — spawned at
## the nozzle and then sent somewhere the wand is not pointing — which reads as
## water bending in mid-air the moment anything is emitted along the barrel. So
## the alignment is settled here, in the pose, once, and everything downstream
## gets to be honest: born at the nozzle, pushed along the wand.
##
## [b]Pointing the wand at the mark also puts the nozzle on the line to it.[/b]
## That is the property worth stating, because "parallel to the aim" and "on the
## line to the mark" are different things and only the second one lets a jet land
## on the mark. The wand turns about the hand, so every point along it — the
## nozzle included — sits on the ray that leaves the hand along the wand's own
## axis. Aim that ray at the mark and the nozzle is a point on the segment
## between the hand and the mark, which makes the wand's axis and the
## nozzle-to-mark line one line rather than two parallel ones. It holds for any
## grip, at any distance, and it is asserted in
## [code]tests/unit/test_wand_carry.gd[/code] as the distance from the nozzle to
## that segment rather than as an angle somebody eyeballed.
##
## [b]It is not aimed while it is not aiming.[/b] At rest the wand goes back to
## the pose the table in [ViewModel] gives it — across the corner of the frame,
## well off the view axis. Two reasons, and the first is the honest one: a
## cylinder pointed down the barrel is a disc, and a tool that reads as a disc
## whenever the player is not touching the glass is a worse tool than one that
## is only aligned while it matters.
## [code]tests/integration/test_view_model.gd[/code] holds that rule for every
## cylinder on the belt and this is why the power wash still passes it. The
## second is clearance: the resting pose is what the parked stance was measured
## against, and letting go of the glass puts the wand back inside the numbers the
## room's own docs recorded.
##
## [b]And it arrives there, rather than snapping.[/b] [param raise] is the eased
## 0-to-1 from [method ToolAim.raise_amount], and the two poses are blended
## through it — so bringing a wand up to aim is a movement with a duration, the
## same shape as the swing it happens alongside.
class_name WandCarry
extends ToolCarry

## The wand's own long axis, and the end the water comes out of. [code]+Y[/code]
## because that is the axis a [CylinderMesh] is built along — see
## [method ViewModel._mesh_for] — so the nozzle is the top of the cylinder and
## the butt is the bottom of it.
##
## A modelled wand has to agree with that rather than the other way round: the
## mesh is fitted into the same box the cylinder filled and this is still where
## the water leaves, which is why the pressure washer's own frame is righted by
## [member DetailingTool.model_turn] before it ever gets here.
const AXIS: Vector3 = Vector3.UP

## How nearly the aim has to be pointed back down the wand before there is no
## rotation to compute.
##
## The shortest arc from [constant AXIS] to a direction is undefined when the
## direction is exactly opposite it — every arc is equally short — and a
## [Quaternion] built from that pair comes back as a NaN that takes the whole
## proxy off screen. The fence on [member ToolAim.pitch_limit_degrees] means the
## aim never comes near it, so this is a guard against a caller that has no fence
## rather than against the game.
const FLIPPED: float = -0.9999

var _length: float


func _init(held: Transform3D, length: float) -> void:
	super(held)
	_length = maxf(length, 0.0)


## Where the wand sits this frame: its resting pose blended [param raise] of the
## way toward pointing at [param toward].
##
## [method Transform3D.interpolate_with] rather than a blend of the two angles,
## because the resting pose is a rotation and an offset and the aimed one is a
## rotation about the hand — interpolating the transforms takes the shortest path
## through both at once, which is the arc a wrist actually travels.
##
## [param _outward] is ignored, and that is the whole difference between this and
## [ReachCarry]: the water is thrown from a step back, so which way the paint
## faces changes nothing about how the wand is held. A tool that arrives at the
## panel has to care; one that shoots at it does not.
func pose(toward: Vector3, _outward: Vector3, raise: float) -> Transform3D:
	var lifted: float = clampf(raise, 0.0, 1.0)
	if lifted <= 0.0:
		return _rest
	return _rest.interpolate_with(aligned(toward), lifted)


## The pose that lays the whole wand on the line from the hand to [param toward],
## which is read in the hand's own space.
##
## The origin is the hand itself: the wand turns about the anchor and is not slid
## along its own axis first, unlike the resting grip. That is what keeps the
## nozzle on the line — see the class docs — and it is also what keeps the wand
## inside the reach the shot promises: half the box the tool is fitted into, plus
## the grip the resting pose slides it down by, comes to 0.422 m against the
## 0.45 m every other tool is already allowed. Half a length rather than half a
## box while the wand was a 6 cm barrel; it is a modelled pressure washer with a
## bottle across it now, and the corner of that box is what spends the budget —
## see [method DetailingTool.catalogue], where the size is picked to fit it.
##
## Falls back to the resting pose for a direction there is no rotation to build
## from: a zero-length one, or one pointed back down the wand (see
## [constant FLIPPED]).
func aligned(toward: Vector3) -> Transform3D:
	var along: Vector3 = toward.normalized()
	if along.is_zero_approx() or along.dot(AXIS) <= FLIPPED:
		return _rest
	return Transform3D(Basis(Quaternion(AXIS, along)), Vector3.ZERO)


## Yes: the wand is the tool the whole marker pair was invented for.
func has_ends() -> bool:
	return true


## Where the nozzle sits in the wand's own space — the end the water leaves, and
## the end a jet gets parented to.
##
## Read from here rather than written out beside the mesh so the marker
## [ViewModel] hangs there and the arithmetic above cannot disagree about which
## end of the wand is which.
func nozzle() -> Vector3:
	return AXIS * _length * 0.5


## The other end: where the hose goes, and what the far end of the alignment is
## measured from.
func butt() -> Vector3:
	return -AXIS * _length * 0.5


## Yes: what the wand is pointed at moves while the eye walks, even on a frame
## where the swing itself has settled.
func tracks_the_aim() -> bool:
	return true
