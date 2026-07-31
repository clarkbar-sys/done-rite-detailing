## The detailing bay: a box of a room, a green box for the car, red boxes for
## the toolboxes along the back wall, and a camera that either circles the car
## or stands in the bay looking at it.
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
## [b]Two shots, one room.[/b] The title screen circles the car to show it off;
## the game stands inside the bay at head height, close enough that the car
## fills the frame the way it would if you had walked up to it with a sponge.
## That is [member first_person], and it is an export like every other
## difference between the two screens — both of them instance this same scene
## and differ in nothing but the values below, so the room still has no idea
## which one it is in.
##
## [b]The viewmodel hangs off this camera, and is kept inside the near plane
## rather than given a camera of its own.[/b] A mesh parented to a camera punches
## through the world the moment the world comes closer to the lens than the mesh
## is; the textbook fix is a second camera with its own cull mask and its own
## near/far, composited over the first. It is not built here, and both halves of
## that were checked rather than assumed.
##
## [i]What it would cost.[/i] A [Camera3D] cannot composite over another
## [Camera3D] in the same viewport — exactly one is [code]current[/code] — and
## this room already renders through a [SubViewport] with
## [code]own_world_3d[/code]. So "its own camera" really means a second
## [SubViewportContainer] stacked over this one, with a transparent background, a
## shared [World3D], a render layer carved out of every mesh in the room, and a
## script copying the eye transform across every frame. Four new moving parts,
## for a camera that is bolted to the floor.
##
## [i]Why it isn't needed yet.[/i] The eye is parked — walking and mouselook are
## deliberately a later epic — so the clearance is a fixed number rather than a
## hope, and it was measured rather than hoped at: with the eye at
## [member eye_position], the anchor stands 0.79 m clear of the car's box, which
## is the nearest thing in the room to it by a wide margin (the walls are metres
## away), and 0.50 m in front of a 0.05 m near plane. Held proxies eat into that:
## the longest of them, the power wash wand, still finishes 0.50 m clear of the
## car. All of it is asserted against the car's own bounding box — the anchor in
## [code]tests/integration/test_play_screen.gd[/code], every proxy corner in
## [code]tests/integration/test_view_model.gd[/code] — so the day the eye learns
## to walk, those go red and the second viewport gets built then, with something
## real to look at rather than as insurance against a camera that cannot move.
class_name Garage
extends SubViewportContainer

## Whether the camera circles the car. The title screen leaves it on to show
## the car off; the play screen turns it off and stands still instead.
##
## Ignored entirely when [member first_person] is set: an eye in someone's head
## does not orbit, and a screen that asked for both would otherwise drag the
## camera out through a wall.
@export var orbiting: bool = true

## Where on its circle the camera starts, in degrees. [code]0[/code] is head-on
## from the front of the room. Unused in first person, where the shot is a
## position and not an angle on a circle.
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

## Whether the camera is a person standing in the bay rather than a showcase
## rig circling the car. Off by default, because the room's own job — the shot
## behind the title card — is the orbit; the game turns it on.
##
## It is a mode and not just "a parked orbit camera" because the two disagree
## about everything: the orbit is a radius and a height around the car and
## always looks in at it from outside, and a person is a position in the room at
## the height of their own eyes. Parking the orbit gives you the showcase shot
## frozen mid-circle, which is what this screen used to be and what #41 was
## filed about.
@export var first_person: bool = false

## Where the player stands, in metres, when [member first_person] is set.
##
## 1.7 m up is eye height. The rest is a spot beside the car's front quarter:
## 2.55 m from the middle of the car on the floor, which puts the near flank
## about 0.95 m away — one step back from arm's reach, the distance you would
## actually stand at to wash a panel, and close enough that the car fills the
## frame instead of sitting in the middle of it. Well inside the room's 6 m
## half-width and well under its 4.5 m ceiling, and outside the car's own box so
## the eye is not standing in the bodywork; the tests hold all three.
##
## The angle is not an export because there is nothing to choose: the camera
## looks at the car, the same way the orbit does.
@export var eye_position: Vector3 = Vector3(1.9, 1.7, 1.7)

var _orbit: CameraOrbit = null

@onready var _camera: Camera3D = %Camera
@onready var _car: Node3D = %Car

## Where held things render: a [ViewModel] parented to the camera, so it travels
## with the eye and never has to be re-aimed. What hangs in it is that class's
## business; where it hangs is this one's.
##
## Its pose lives in the scene file, like the room's box sizes, and the three
## numbers there are the whole "this is in your hand" illusion. 0.45 m down the
## camera's own -Z, because at a 75° horizontal field of view that depth makes
## the visible frame 0.69 m wide — so 0.17 m to the right is halfway to the right
## edge and 0.15 m down is near the bottom of a 16:9 frame. A tool sitting there
## rises into the corner of the shot with its far end running off the bottom of
## the screen, which is what a held thing looks like; dead centre at arm's length
## is what a thing floating in front of your face looks like.
@onready var _view_model: ViewModel = %ViewModel


func _ready() -> void:
	# The anchor ships hidden in the scene file and is switched on here, because
	# both screens instance this same scene: a viewmodel is a thing in the hands
	# of somebody standing in the room, and hanging one off the corner of the
	# title screen's slow circuit of the car would read as a rendering bug rather
	# than as a held tool. Hidden rather than deleted so the play screen and the
	# title screen keep running the identical scene.
	_view_model.visible = first_person
	if first_person:
		_stand()
		return
	_orbit = CameraOrbit.new(orbit_radius, orbit_height, orbit_degrees_per_second)
	_orbit.angle_degrees = start_angle_degrees
	# Aimed once here rather than waiting for the first `_process`: a screen that
	# never orbits would otherwise keep whatever transform the scene file
	# happened to save, and the first frame of one that does would be a jump.
	_aim()


func _process(delta: float) -> void:
	# `_orbit` is null in first person — there is no circle to advance — so the
	# null check is the mode test and `orbiting` is only asked about afterwards.
	# Checking `orbiting` alone would crash a screen that set both.
	if _orbit == null or not orbiting:
		return
	_orbit.advance(delta)
	_aim()


## The hands the eye is looking past, and through them the [ToolBelt] driving
## what is in them.
##
## Public because the room owns the viewmodel but not the game: the play screen
## has a roll-up that needs to change the equipped tool, and it must change
## [i]this[/i] belt rather than build one of its own — two belts is a UI that
## rings one tool while the player holds another. Handing out the node instead
## of forwarding a `belt()` of our own keeps the room from growing an opinion
## about the belt it is merely carrying.
##
## Present on the title screen too, where it is hidden and nobody asks.
func view_model() -> ViewModel:
	return _view_model


## Puts the camera where the orbit says it should be, looking at the car.
func _aim() -> void:
	_camera.global_position = _orbit.eye(_car.global_position)
	_face_car()


## Stands the camera in the bay at [member eye_position], looking at the car.
##
## Called once, from [method _ready], and never again: the eye does not move.
## When it learns to, this is the function that grows a body under it, and
## nothing above it changes.
func _stand() -> void:
	_camera.global_position = eye_position
	_face_car()


## Turns the camera onto the car.
##
## The car's position is read every time instead of being cached, because the
## thing being looked at is a node — the day it moves, the camera follows it for
## free rather than politely aiming at where it used to be.
func _face_car() -> void:
	_camera.look_at(_car.global_position)
