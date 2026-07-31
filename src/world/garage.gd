## The detailing bay: a box of a room, a green box for the car, red boxes for
## the toolboxes along the back wall, and a camera that circles the car.
##
## It is boxes on purpose. Everything here is one unit [BoxMesh] scaled into
## place, so the whole level is readable in the scene file and none of it is
## waiting on an artist; the shapes and their sizes are the design decision, and
## a real mesh drops in later without moving anything else.
##
## [b]Why the [SubViewport][/b]. In the root viewport, 2D always composites over
## 3D — and [code]src/main/main.tscn[/code] has a full-screen [ColorRect]
## background under every screen, so a [Node3D] added straight to a screen would
## render behind it and never be seen at all. A [SubViewportContainer] draws its
## viewport as a canvas item instead, which puts the world into the same layer
## order the screens already use, and gives the 3D content its own [World3D] so
## the [WorldEnvironment] in here can't reach anything else.
##
## [b]The key light casts no shadow, on purpose.[/b] The room is a sealed box,
## so with shadows on, its own ceiling shadows everything inside it and the
## whole interior falls back to ambient — measured, by rendering it: flat, near
## black, and not obviously a lighting bug at all. The two [OmniLight3D]s
## overhead are the shop's own strip lights and do the shaping; the directional
## is a fill that ignores the ceiling. The alternative — take the ceiling off
## and let a real sun in — buys a shadow under the car and costs the room its
## roof, and this camera looks up enough to see the hole.
##
## [b]The camera is driven here; the arithmetic is not.[/b] [CameraOrbit] is a
## [RefCounted] in [code]src/core/[/code] and knows nothing about cameras, which
## is what lets a full revolution be a unit test instead of half a minute of
## real frames — the Node-free tier rule from STANDARDS.md "Coverage" (R3).
##
## Both screens that show the room instance this same scene and differ only in
## the exports below, so the room has no idea which one it is in.
class_name Garage
extends SubViewportContainer

## Whether the camera circles the car. The title screen leaves it on to show
## the car off; the play screen turns it off and holds the shot.
@export var orbiting: bool = true

## Where on its circle the camera starts, in degrees. [code]0[/code] is head-on
## from the front of the room; the play screen uses a three-quarter angle so the
## cut out of the title screen reads as a chosen shot rather than a camera that
## stopped.
@export var start_angle_degrees: float = 0.0

## How far the camera stands from the car, on the ground plane. Kept under the
## room's 6 m half-width so the camera never ends up inside a wall.
@export var orbit_radius: float = 5.6

## How far above the middle of the car the camera sits. Well above rather than
## level: from its own waist height a car reads as a brick and the room reads as
## nothing at all, because the floor — the thing that says how big the room is —
## is edge-on and invisible. Kept under the 4.5 m ceiling for the same reason
## the radius is kept under the walls.
@export var orbit_height: float = 2.6

## How fast the camera circles. 12°/s is a full turn every thirty seconds —
## slow enough to sit behind a title screen without pulling the eye off the
## button.
@export var orbit_degrees_per_second: float = 12.0

var _orbit: CameraOrbit = null

@onready var _camera: Camera3D = %Camera
@onready var _car: Node3D = %Car


func _ready() -> void:
	_orbit = CameraOrbit.new(orbit_radius, orbit_height, orbit_degrees_per_second)
	_orbit.angle_degrees = start_angle_degrees
	# Aimed once here rather than waiting for the first `_process`: a screen that
	# never orbits would otherwise keep whatever transform the scene file
	# happened to save, and the first frame of one that does would be a jump.
	_aim()


func _process(delta: float) -> void:
	if not orbiting:
		return
	_orbit.advance(delta)
	_aim()


## Puts the camera where the orbit says it should be, looking at the car.
##
## The car's position is read every time instead of being cached, because the
## thing being circled is a node — the day it moves, the camera follows it for
## free rather than politely orbiting where it used to be.
func _aim() -> void:
	var focus: Vector3 = _car.global_position
	_camera.global_position = _orbit.eye(focus)
	_camera.look_at(focus)
