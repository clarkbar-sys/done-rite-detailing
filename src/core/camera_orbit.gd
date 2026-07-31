## Where a camera stands while it circles a point, as arithmetic rather than as
## a node.
##
## The menu's slow turn around the car is why this exists, but none of that
## needs a [Camera3D], a [SceneTree] or a frame — it is an angle advanced by a
## delta and a position read back off a circle. Keeping it separate is the
## Node-free tier rule from STANDARDS.md "Coverage" (R3):
## [code]src/world/garage.gd[/code] owns the camera and calls this, and
## [code]tests/unit/test_camera_orbit.gd[/code] drives a full revolution in a
## loop with no scene at all.
##
## Distances are metres and angles are degrees — degrees because every number
## that reaches here comes from a designer tuning an [code]@export[/code] in the
## inspector, and radians are a poor thing to type into one.
class_name CameraOrbit
extends RefCounted

## A whole turn. [method advance] keeps [member angle_degrees] inside it, so a
## camera left running for an hour holds the same precision as one a second old
## — a float that has grown to six digits has spent them, and the wobble shows
## up as a camera that stutters only after a long idle, which is a horrible bug
## to be handed.
const FULL_TURN: float = 360.0

## How far the camera stands from the point it is looking at, measured flat on
## the ground plane rather than eye-to-focus.
var radius: float = 0.0

## How far above the focus point the eye sits.
var height: float = 0.0

## How fast the camera travels around the circle. Positive sweeps from [code]+Z
## [/code] toward [code]+X[/code]; negative goes back the other way.
var degrees_per_second: float = 0.0

## Where the camera is on its circle right now. [code]0[/code] puts it due
## [code]+Z[/code] of the focus.
var angle_degrees: float = 0.0


## No defaults on purpose. The tuning numbers belong to the scene that owns the
## camera, where they are [code]@export[/code]s someone can see and change; a
## second set of defaults here would be a second answer to the same question,
## and the two would drift.
func _init(orbit_radius: float, orbit_height: float, speed_degrees_per_second: float) -> void:
	radius = orbit_radius
	height = orbit_height
	degrees_per_second = speed_degrees_per_second


## Moves the camera [param delta] seconds further around its circle.
func advance(delta: float) -> void:
	angle_degrees = wrapf(angle_degrees + degrees_per_second * delta, 0.0, FULL_TURN)


## Where the camera stands to look at [param focus].
##
## [param focus] is passed in rather than stored because the thing being circled
## is a node that can move, and a copy of its position taken once at
## construction would quietly stop being true the first time it did.
func eye(focus: Vector3) -> Vector3:
	var radians: float = deg_to_rad(angle_degrees)
	return focus + Vector3(sin(radians) * radius, height, cos(radians) * radius)
