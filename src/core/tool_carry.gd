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
## [b]Why a class and not a branch in [ViewModel].[/b] The power wash is the
## first tool that needs to know where the aim is, and it will not be the last —
## a sponge that wants to lie flat against the panel it is dragged along, a
## bottle that tips as it sprays. Each of those is a different rule about the
## same three inputs, and a viewmodel that grew an `if` per tool would be a
## single function nobody can change one tool inside of. A carry is that rule,
## alone, with a name.
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
## [param toward] is the point the aim is on, read in the hand's own space, and
## [param raise] is how far into aiming the player is — 0 with the finger off the
## glass, 1 with the tool fully brought up. Both are ignored here, because a
## sponge is held the way a sponge is held whatever anybody is pointing at, and
## both are the whole of [WandCarry].
func pose(_toward: Vector3, _raise: float) -> Transform3D:
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
