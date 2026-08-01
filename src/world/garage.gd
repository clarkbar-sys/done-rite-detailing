## The driveway: a grey plane for the car to sit on, green planes either side
## for the grass, a green box for the car, and a camera that either circles the
## car or stands beside it looking at it.
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
## [b]The key light casts no shadow, on purpose.[/b] This was a garage once,
## with walls and a ceiling directly overhead; a shadow-casting key lit that box
## from one side and left the other in near-black. The two [OmniLight3D]s do the
## shaping outdoors too, so the directional stays a plain fill rather than
## growing shadows nobody has tuned for an open driveway yet.
##
## [b]The camera is driven here; the arithmetic is not.[/b] [CameraOrbit] is a
## [RefCounted] in [code]src/core/[/code] and knows nothing about cameras, which
## is what lets a full revolution be a unit test instead of half a minute of
## real frames — the Node-free tier rule from STANDARDS.md "Coverage" (R3).
##
## [b]Two shots, one driveway.[/b] The title screen circles the car to show it
## off; the game stands beside it at head height, close enough that the car
## fills the frame the way it would if you had walked up to it with a sponge.
## That is [member first_person], and it is an export like every other
## difference between the two screens — both of them instance this same scene
## and differ in nothing but the values below, so the room still has no idea
## which one it is in.
##
## [b]And that standing eye can now walk.[/b] [member walkaround] hands the
## circle the standing shot was cut out of back to the player: left and right on
## the HUD's pad walk you around the car, up and down raise and lower your eye.
## It is deliberately a rail and not a character — there is no body, no collision
## against the room, and no way to face away from the car — because the target is
## a web page on a phone, where there is no mouse to capture and a virtual stick
## costs a thumb the player needs for the tool belt. Circling the thing you are
## working on is what a detailer physically does anyway, so the rail is close to
## free.
##
## [b]The rail is not a circle, though, and that is the interesting half.[/b] The
## car is 4.3 m long and 1.9 m wide, so one fixed radius is either scraping the
## doors or standing a metre and a half off the bumper. What is held instead is
## the gap between the eye and the bodywork: every physics frame a ray goes out
## level toward the middle of the car, and [Standoff] eases the radius until the
## paint is [member standoff_metres] away square on. The camera hugs the
## car's outline rather than a circle drawn around it, and the day the green box
## becomes a real car with wing mirrors, the ray finds those too — nothing here
## says "box" anywhere.
##
## [b]Which is why the car grew a [StaticBody3D].[/b] It is the only thing in the
## room a ray can hit, and it is a sibling of the mesh with its own unscaled
## transform rather than a child of it: everything in this room is a unit
## [BoxMesh] scaled into place, a [CollisionShape3D] inherits that scale, and a
## non-uniformly scaled shape is the one thing the physics server asks not to be
## handed. The cost is the car's size written down twice, and
## [code]tests/integration/test_garage.gd[/code] asserts the two still agree
## rather than trusting whoever resizes the car next to remember.
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
## [i]Why it isn't needed yet.[/i] Because the eye is kept far enough from the
## car that nothing in the room can get between it and the lens, and that is a
## measurement rather than a hope. Parked at [member eye_position] the anchor
## stands 0.79 m clear of the car's box — the nearest thing in the room to it by
## a wide margin, since the edge of the modeled ground is metres away — and
## 0.50 m in front of a 0.05 m near plane; the longest held proxy, the power
## wash wand, still finishes 0.50 m clear of the car.
##
## [i]And the eye has since learned to walk[/i], which is what the previous
## version of this paragraph said would end it. It didn't, and the reason is
## worth writing down rather than being pleased about: a walk at the parked
## distance really does fail — 0.31 m of anchor clearance against a 0.45 m reach,
## measured, at the corner where the hand swings across the bodywork — and what
## fixed it was [member standoff_metres] standing the walk further off the car
## than the parked shot ever stood. So the clearance is still a number and not a
## hope, it is just a number the standoff now keeps rather than the scene file.
## All of it is asserted against the car's own bounding box: the parked anchor in
## [code]tests/integration/test_play_screen.gd[/code], every angle of a lap in
## [code]tests/integration/test_play_screen_walk.gd[/code], and every proxy
## corner in [code]tests/integration/test_view_model.gd[/code]. The day something
## needs the eye nearer the paint than a held tool is long, those go red and the
## second viewport gets built then — with something real to look at rather than
## as insurance against a camera that cannot move.
class_name Garage
extends SubViewportContainer

## Whether the camera circles the car. The title screen leaves it on to show
## the car off; the play screen turns it off and stands still instead.
##
## Ignored entirely when [member first_person] is set: an eye in someone's head
## does not orbit, and a screen that asked for both would otherwise drag the
## camera off the showcase circuit mid-stride.
@export var orbiting: bool = true

## Where on its circle the camera starts, in degrees. [code]0[/code] is head-on
## from the front of the room. Unused in first person, where the shot is a
## position and not an angle on a circle.
@export var start_angle_degrees: float = 0.0

## How far the camera stands from the car, on the ground plane. Kept under the
## modeled ground's 6.2 m half-width so the camera never orbits off the edge of
## the driveway and grass.
@export var orbit_radius: float = 5.6

## How far above the middle of the car the camera sits. Well above rather than
## level: from its own waist height a car reads as a brick and the ground reads
## as nothing at all, because the ground — the thing that says how big the space
## is — is edge-on and invisible.
@export var orbit_height: float = 2.6

## How fast the camera circles. 12°/s is a full turn every thirty seconds —
## slow enough to sit behind a title screen without pulling the eye off the
## button.
##
## Only the unattended circuit's speed. What a player's thumb is worth is
## [member turn_degrees_per_second], and the two are separate numbers because
## they are answers to different questions: one is how fast a title card should
## drift, the other is how fast a person walks.
@export var orbit_degrees_per_second: float = 12.0

## Whether the camera is a person standing on the driveway rather than a
## showcase rig circling the car. Off by default, because the scene's own job —
## the shot behind the title card — is the orbit; the game turns it on.
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
## frame instead of sitting in the middle of it. Well inside the modeled
## ground's 6.2 m half-width, and outside the car's own box so the eye is not
## standing in the bodywork; the tests hold both.
##
## The angle is not an export because there is nothing to choose: the camera
## looks at the car, the same way the orbit does.
@export var eye_position: Vector3 = Vector3(1.9, 1.7, 1.7)

## Whether the player can walk that eye around the car. Ignored unless
## [member first_person] is set — there is nobody to walk otherwise, and the
## title screen's showcase circuit is not a thing anybody should be able to grab
## the wheel of.
##
## Off by default for the same reason [member first_person] is: the room's own
## job is the shot behind the title card, and the game turns the rest on.
@export var walkaround: bool = false

## How fast holding left or right walks the eye around the car, in degrees per
## second. At the radius the standoff settles on, 40°/s is about 1.6 m/s along
## the paint — a walk with somewhere to be, which is right for a control you have
## to hold down. Slower reads as a stuck button.
@export var turn_degrees_per_second: float = 40.0

## How fast holding up or down moves the eye, in metres per second. The whole
## range below is a shade over a second and a half at this rate; the point of the
## axis is to get an eye onto a roof or down to a sill, not to fly.
@export var lift_metres_per_second: float = 0.9

## The lowest the eye may be driven, in metres above the floor. Crouched at a
## wheel arch rather than lying under the car — there is nothing under there to
## look at yet, and a camera below the floor renders the room from outside it.
@export var eye_height_min: float = 1.1

## The highest the eye may be driven. Above the car's 1.4 m roof by a metre, so
## the roof and the bonnet can be looked down at. Not a matter of taste: past
## about here the ray below starts measuring to the roof rather than to a
## flank, and the eye leans in over the car instead of standing beside it.
@export var eye_height_max: float = 2.4

## How much clear air to keep between the eye and the nearest bodywork, in
## metres, measured square on to the panel and level with the floor.
##
## A long way back from the 0.95 m the parked stance stands at
## ([member eye_position]), and the number came out of a browser rather than out
## of a spreadsheet. At the parked distance a 75° lens sees 1.84 m of frame, and
## the car is 1.9 m wide: walking around it at that range is a wall of green
## sliding sideways, with no way to tell a door from a wing. Screenshotted, on an
## emulated Pixel 7, which is where this got settled. At 2.2 m the frame is
## 3.4 m, the corner of the car and the room behind it are both in shot, and the
## movement reads as movement.
##
## It also buys the room the [ViewModel] needs. The tool in the player's hand
## hangs 0.45 m in front of the lens and swings across the bodywork as the eye
## comes round a corner; the parked distance puts it inside the car there —
## measured, at 0.31 m of clearance against a 0.45 m reach.
## [code]tests/integration/test_play_screen_walk.gd[/code] holds that margin at
## every angle of a lap rather than at the one the scene starts on.
@export var standoff_metres: float = 2.2

## How fast the standoff is allowed to correct the radius, in metres per second.
## Slow enough to read as the camera easing around the corner of a bumper;
## snapping to the answer instead would yank the shot every time the ray crossed
## an edge of the bodywork.
@export var standoff_correction_speed: float = 1.5

## The tightest the standoff may pull the orbit in.
##
## A backstop for a ray that hit nothing sensible, and not the thing that keeps
## the eye out of the paint — that is [member standoff_metres], which settles the
## radius at 3.15 m alongside the car and 4.35 m off its nose, both a long way
## clear of this. Set below either, because a fence that binds during normal play
## would quietly stop the camera hugging the car at exactly the angles the whole
## mechanism exists for.
@export var standoff_radius_min: float = 1.6

var _orbit: CameraOrbit = null
var _drive: OrbitDrive = null
var _standoff: Standoff = null

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
		if walkaround:
			_take_up_the_walk()
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
	#
	# A walk owns its circle outright, and drives it on the physics clock below
	# where the ray it measures with is allowed to be cast. So this is the
	# unattended circuit and nothing else.
	if _orbit == null or _drive != null or not orbiting:
		return
	_orbit.advance(delta)
	_aim()


## The walk, on the physics clock rather than the frame clock.
##
## Not a preference: [method _hold_the_standoff] casts a ray, and a space state
## may only be queried while physics is stepping. Doing the movement here as well
## keeps the whole camera in one place per tick — a camera moved on one clock and
## measured on the other is a camera that measures where it used to be.
func _physics_process(delta: float) -> void:
	if _drive == null:
		return
	_drive.drive(_orbit, delta)
	_hold_the_standoff(delta)
	_aim()


## Takes the player's intent — [param turn] to walk around the car,
## [param lift] to raise or lower the eye, both in [code]-1..1[/code] — and does
## nothing at all if this room is not one anybody can walk in.
##
## The room takes the numbers and not the buttons. What is on screen is the play
## screen's business (a pad today, a stick or a swipe later), and none of that
## should be able to reach in here; what arrives is "walk right", which is the
## only part the camera has an opinion about.
func steer(turn: float, lift: float) -> void:
	if _drive == null:
		return
	_drive.steer(turn, lift)


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


## Stands the camera on the driveway at [member eye_position], looking at the
## car.
##
## Called once, from [method _ready], and never again: the eye does not move.
## When it learns to, this is the function that grows a body under it, and
## nothing above it changes.
func _stand() -> void:
	_camera.global_position = eye_position
	_face_car()


## Turns where the player is standing into a circle they can walk around.
##
## [b]Derived from [member eye_position] rather than exported again.[/b] The
## angle, the radius and the height all fall out of where the standing shot
## already put the eye, so [method _stand] above has just placed the camera on
## the first point of this circle and the walk starts from exactly there. A
## second set of numbers would be a second answer to "where does the player begin"
## and the two would drift the first time anybody retuned the shot.
##
## The height fences arrive here as heights above the [i]car[/i], because that is
## what [member CameraOrbit.height] measures, while the exports are heights above
## the floor — which is what a person tuning "how low can you crouch" is actually
## thinking about.
func _take_up_the_walk() -> void:
	var focus: Vector3 = _car.global_position
	var offset: Vector3 = eye_position - focus
	var flat: Vector2 = Vector2(offset.x, offset.z)
	_orbit = CameraOrbit.new(flat.length(), offset.y, 0.0)
	# `atan2(x, z)` and not the usual `(y, x)`: this orbit measures its angle from
	# +Z toward +X (see [method CameraOrbit.eye]), so the arguments swap.
	_orbit.angle_degrees = rad_to_deg(atan2(offset.x, offset.z))
	_drive = OrbitDrive.new(
		turn_degrees_per_second,
		lift_metres_per_second,
		eye_height_min - focus.y,
		eye_height_max - focus.y
	)
	# The far fence is the showcase circuit's own radius, which is already the
	# number that keeps a camera off the edge of the modeled ground. One fence,
	# stated once, and ground that is made bigger moves both at the same time.
	_standoff = Standoff.new(
		standoff_metres, standoff_radius_min, orbit_radius, standoff_correction_speed
	)


## Measures how far the car actually is and lets [Standoff] close the gap.
##
## [b]The ray is cast level, from the eye's spot on the floor raised to the
## middle of the car, and not from the eye itself.[/b] That is the whole trick,
## and both of the obvious alternatives were tried and are worse:
##
## - [i]Straight ahead from the eye[/i] misses the car outright from any height
##   above its 1.4 m roof — which is a standing adult — so the standoff would do
##   nothing at exactly the height the game is played at.
## - [i]From the eye, aimed down at the middle of the car[/i] always hits, but
##   what it hits depends on how tall you are: measured at 1.7 m the ray finds a
##   flank, and ten centimetres higher it finds the roof instead. The gap then
##   stops being a horizontal distance the radius can do anything about, and the
##   camera drifts in over the bonnet as the player raises their eye.
##
## A level ray at the car's own mid-height cannot do either. It hits a vertical
## face every time, from every height, so how far you are standing from the car
## stops depending on how tall you are — which is also true of people.
##
## [b]And the gap is measured along the panel's own normal[/b], not as the length
## of the ray. Down at a corner the ray runs in diagonally and its length
## overstates the clearance by half again, so a camera holding the ray's length
## constant would cut the corners of the car. Projecting onto the normal makes
## the path the car's outline pushed out by [member standoff_metres] — which is
## the line somebody walking round a car actually takes.
##
## A ray that hits nothing leaves the radius alone. That is the honest answer to
## having no measurement — the alternative is inventing one, and inventing one
## moves the camera on the strength of a query that failed.
func _hold_the_standoff(delta: float) -> void:
	var focus: Vector3 = _car.global_position
	var eye: Vector3 = _orbit.eye(focus)
	var probe: Vector3 = Vector3(eye.x, focus.y, eye.z)
	var space: PhysicsDirectSpaceState3D = _camera.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(probe, focus))
	if hit.is_empty():
		return
	var surface: Vector3 = hit["position"]
	var outward: Vector3 = hit["normal"]
	_orbit.radius = _standoff.correct(_orbit.radius, (probe - surface).dot(outward), delta)


## Turns the camera onto the car.
##
## The car's position is read every time instead of being cached, because the
## thing being looked at is a node — the day it moves, the camera follows it for
## free rather than politely aiming at where it used to be.
func _face_car() -> void:
	_camera.look_at(_car.global_position)
