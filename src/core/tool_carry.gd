## How a tool sits in the hand, frame by frame. The default is "it doesn't move",
## and that is most of the belt.
##
## The hand is an anchor in the corner of the frame and [ToolAim] swings it;
## what hangs off that anchor is a mesh in a pose, and that pose used to be one
## fixed [Transform3D] per tool for all five of them. This is the same
## arrangement written down as a thing a tool is allowed to differ in: four tools
## carry one of these, which hands back the pose it was built with and ignores
## everything else, and the power wash carries a [WandCarry], which points itself
## down the line to whatever the player is aiming at.
##
## [b]Why a class and not a branch in [ViewModel].[/b] The power wash was the
## first tool that needed to know where the aim is, and it was not the last: the
## sponge that wants to lie flat against the panel it is dragged along and the
## bottle that tips as it sprays are both here now, as [ReachCarry]. Each is a
## different rule about the same three inputs, and a viewmodel that grew an `if`
## per tool would be a single function nobody can change one tool inside of. A
## carry is that rule, alone, with a name.
##
## [b]Why not a flag on [DetailingTool].[/b] The catalogue is data the roll-up
## icons read as well, and an icon is not held by anybody — the same reason the
## poses live in the viewmodel rather than in the catalogue. How a thing is
## carried is about framing and aiming, which are facts about a first-person
## camera and not about what a pressure washer is.
##
## [b]A [RefCounted] and not a [Node].[/b] A carry is arithmetic about a pose —
## no mesh, no camera, no tree — which is the Node-free tier from STANDARDS.md
## "Coverage" (R3), and it is what lets [WandCarry]'s whole geometric claim be a
## unit test rather than something somebody checks by looking at it.
class_name ToolCarry
extends RefCounted

var _rest: Transform3D


func _init(held: Transform3D) -> void:
	_rest = held


## How a hand holds the thing when nobody is pointing it anywhere. What the
## proxy is built in, and what every carry falls back to.
func rest_pose() -> Transform3D:
	return _rest


## Where the tool sits this frame, in the hand's own space.
##
## [param toward] is the point the aim is on, read in the hand's own space;
## [param outward] is the surface normal of the paint under it, read in the same
## space; and [param raise] is how far into aiming the player is — 0 with the
## finger off the glass, 1 with the tool fully brought up. All three are ignored
## here, because a tool held at a fixed angle is held that way whatever anybody
## is pointing at.
##
## [b]The normal is a separate argument rather than something a carry could work
## out.[/b] A point on the paint says nothing about which way the paint faces,
## and the difference between a sponge lying flat on a door and one lying flat on
## the roof is exactly that. It comes from the same raycast the mark does — see
## [method ViewModel.mark_at] — so a carry never has to guess it.
func pose(_toward: Vector3, _outward: Vector3, _raise: float) -> Transform3D:
	return _rest


## Whether this carry has anything new to say on a frame where the swing has
## already arrived.
##
## [ViewModel] stops paying for a settled hand, which is nearly every frame. A
## carry that only ever returns one pose is happy with that; one that follows the
## aim is not, because what it is pointed at keeps moving while the eye walks
## even when the two angles have stopped.
func tracks_the_aim() -> bool:
	return false


## Whether this tool has ends worth marking: a nozzle something is emitted from,
## and the other end of the same axis.
##
## No by default, which is most of the belt — a sponge has no business end, it
## has a face. The tools that say yes get a [Marker3D] at each end from
## [method ViewModel._build], and those markers are what an effect is stood on
## and what a test measures the alignment from.
func has_ends() -> bool:
	return false


## Where the nozzle sits in the tool's own space — the point water or mist leaves
## from.
##
## The middle of the tool unless a carry says otherwise, which is the honest
## answer for something with no nozzle: a caller that emits from here without
## asking [method has_ends] first gets the middle of the sponge rather than a
## null it has to check.
func nozzle() -> Vector3:
	return Vector3.ZERO


## The other end of the same axis. Derived from [method nozzle] rather than
## stated again, so the two cannot end up describing different tools.
func butt() -> Vector3:
	return -nozzle()
