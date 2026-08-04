## The driveway: a grey plane for the car to sit on, green planes either side
## for the grass, a [Car] parked on it, and a camera that either circles the car
## or stands beside it looking at it.
##
## The ground is boxes on purpose. Every plane of it is one unit [BoxMesh]
## scaled into place, so the whole level is readable in the scene file and none
## of it is waiting on an artist; the shapes and their sizes are the design
## decision, and a real mesh drops in later without moving anything else.
##
## The car used to be one of those boxes. It is now a CSG blockout in the same
## 4.3 × 1.9 × 1.4 m envelope and the same place, for the same reason — a shape
## nobody has to open Blender to change. What it is made of, and why it is made
## of twelve separate pieces, is [code]src/world/car.gd[/code]'s business; this
## scene only cares that it is a thing with a position and an outline.
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
## circle the standing shot was cut out of back to the player: reaching left or
## right on the glass walks you around the car, up or down raises and lowers your
## eye. It is deliberately a rail and not a character — there is no body, no
## collision against the room, and no way to face away from the car — because the
## target is a web page on a phone, where there is no mouse to capture and a drawn
## stick costs both a thumb and a third of the picture. Circling the thing you are
## working on is what a detailer physically does anyway, so the rail is close to
## free.
##
## [b]And when nobody is walking it, the room walks it itself.[/b] [member attracting]
## is the arcade cabinet's demo: the car goes under mud, a tool works it panel by
## panel through all three passes, the eye walks round to whatever is being worked,
## and when the last panel is buffed the mud goes back on and it starts again. It is
## what the title screen shows instead of a car nobody is touching.
##
## The rule it is built on is that it gets no privileges. [AttractRoutine] decides
## what a person would do next and [AttractWalk] decides how hard they would reach,
## and both answers go in through [method steer], [method aim_at] and the
## [ToolBelt] — the three doors a player has, and the only three. So there is no
## demo branch in the trigger, the aim, the standoff or the grime, the attract mode
## cannot show a wash the game would not have given, and the day one of those breaks
## the title screen breaks with it rather than papering over it. The single
## exception is putting the mud back at the end of a lap ([method _on_lapped]),
## which is a cabinet restarting rather than something a player does.
##
## [b]The rail is not a circle, though, and that is the interesting half.[/b] The
## car is 4.3 m long and 1.9 m wide, so one fixed radius is either scraping the
## doors or standing a metre and a half off the bumper. What is held instead is
## the gap between the eye and the bodywork: every physics frame a ray goes out
## level toward the middle of the car, and [Standoff] eases the radius until the
## paint is [member standoff_metres] away square on. The camera hugs the
## car's outline rather than a circle drawn around it, and now that the green box
## has become a car with a tapered nose and wing mirrors, the ray finds those too
## — exactly as the previous version of this paragraph said it would. Nothing
## here says "box" anywhere.
##
## [b]Which is why the car has to be something a ray can hit.[/b] It is the only
## thing out here that is — the ground has no collider and nothing else is
## modelled. It no longer needs a hand-built collider to be it:
## every panel of the [Car] is a CSG root with [member CSGShape3D.use_collision]
## set, so the body is generated from the same brushes that make the mesh and
## cannot drift from it. That deleted a [BoxShape3D] that used to sit beside the
## mesh carrying the car's size a second time, along with the test whose whole
## job was catching the two disagreeing — and it means the ray now measures to
## the panel it actually hit rather than to a box drawn around everything.
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
##
## [b]And the hand can now be pointed at the car.[/b] A finger on the glass is an
## aim: the tool swings toward wherever it landed ([ToolAim], applied by
## [ViewModel]) and the mark goes on the nearest bodywork to it ([AimMarker]).
## Holding is aiming and letting go is not, so [method release_aim] puts the mark
## away and lets the hand fall back to rest —
## which is the shape the trigger will keep when there is something for it to
## spray.
##
## Three things about it are worth knowing before changing any of it.
##
## [i]The tool follows the finger; the mark follows the car.[/i] They are
## deliberately not the same point. Press the sky above the roof and the hand
## swings at the sky, because that is where you pointed, while the mark snaps to
## the nearest paint — because "nothing" is not a useful thing to mark
## and the player is plainly asking about the roof. On the car, which is nearly
## every press, the two coincide and the distinction never comes up.
##
## [i]And the room hands the mark to the hand as well as to the sight[/i],
## which is the one thing the paragraph above has an exception for. The hand
## hangs half a metre in front of the lens and off to one side of it, so a tool
## turned merely parallel to the aim points past the mark by that offset — near
## enough to look right, far enough that a jet would visibly miss. So
## [ViewModel] is told where the mark actually is — and which way the paint faces
## there, which is what lets a tool be put [i]on[/i] it rather than merely at it.
## The power wash lays itself along the line to it ([WandCarry]) and the other
## four travel to it ([ReachCarry]). [method ViewModel.mark_at] carries the
## argument for why a tool follows the mark rather than the finger even where the
## two disagree.
##
## [i]It resolves on the physics clock[/i], for the same reason the walk does:
## it casts a ray, and a space state may only be queried while physics is
## stepping. So [method aim_at] records where the finger is and
## [method _resolve_aim] answers it on the next tick — which also means a finger
## dragged across the glass costs one raycast per tick rather than one per event.
##
## [i]The panel it names is real.[/i] Every piece of the [Car] is a CSG root with
## its own collider, so the hit comes back as [code]"Hood"[/code] or
## [code]"DoorLeft"[/code] rather than as "the car" — which is the thing the
## grime work needs and the reason [signal aimed] carries a name at all.
##
## [i]And a press that misses by a hair is caught before any of that.[/i] The aim
## is answered in three tiers, each strictly wider than the one above it, and
## [method _under_the_finger] is where they are stacked: the exact ray, then a
## sphere the width of the held tool swept down the same line ([AimSweep]), then
## the nearest-panel fallback ([method _nearest_on_the_car]). The middle tier is
## the one that earns its keep on a touchscreen — [ThumbLift] throws the aim a
## thumb's width up the glass on purpose, and over a low car that regularly puts
## the ray in the sky — and what it buys is not a hit where there was none, but a
## hit with a [i]measured normal[/i] where the bottom tier could only invent one.
## [AimSweep] has the whole argument, including why it is not the first tier.
##
## [b]And the tools that work the paint draw their own sight.[/b] The water the
## power wash throws, the product the two bottles spray, the suds the sponge
## squeezes out and the crosshair all three retired are one decision and live in
## one place — [ToolSight], which has the argument for each of them and for why
## the ring is now debug-only. What the room owns is the two numbers those
## effects are drawn at ([member wash_radius_metres] and
## [member scrub_radius_metres], which are the patches [method _spend_the_trigger]
## is about to work on) and the switch that takes them away ([member debug_tools]).
##
## [i]The mark is still made whichever sight is showing[/i] — see [AimMarker] — so
## the panel readout, the wand's alignment and the trigger all read exactly what
## they read before. What changes is what is drawn on top of it.
class_name Garage
extends SubViewportContainer

## The panel the mark is on, or [code]""[/code] when nothing is marked —
## emitted only when the answer changes, so a finger held still on one door is
## one signal rather than sixty a second.
##
## A name and not a node: what is on the other end of this is a readout today and
## a job sheet later, and neither should be able to reach into the car and move
## something. The room is the only thing that owns the geometry.
signal aimed(panel: String)

## The car has mud on it and [method grime] is worth asking. Emitted once, a
## frame after [method _ready], and never on a screen that is not first person.
##
## A signal rather than something a caller can poll for, because the wait is not
## optional and it is not obvious — see [method _lay_on_the_grime]. Anything that
## wants to draw the masks has to be told when there are masks.
signal grimed

## How far past the nearest-point post [method _nearest_on_the_car] casts its
## second ray, as a fraction of the distance to it. A tenth over, because the
## post sits on a box that is slightly larger than the panel inside it — a ray
## stopped exactly at the post would land just short of the paint on every panel
## whose box is loose, which is all of them.
const PAST_THE_POST: float = 1.1

## How far off the middle of the car a panel has to sit, in metres, before the
## demo walks the eye round to it.
##
## The tub, the cabin and the roof are all centred on the car, and the angle of a
## point that is nearly at the middle of a circle is nearly meaningless — it flips
## from one side of the car to the other over a centimetre. So a panel with no side
## to it does not move the eye at all, which is the right answer as well as the
## stable one: a roof is in shot from everywhere, and the alternative is a camera
## that lurches off to the nose the moment the demo reaches the one panel it never
## needed to walk to.
##
## The eye's height is not gated by this. Every panel has a height whether or not
## it has a side, and a wheel and a roof are the two the demo most obviously has to
## look at from different levels.
const NO_SIDE_TO_IT: float = 0.35

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

## Whether the room plays itself when nobody is holding the controls: mud goes on
## the car, a tool works it panel by panel through all three passes, the eye walks
## round to whatever is being worked, and when the last panel is buffed the mud
## goes back on and it starts again. The title screen turns it on; the game turns
## it off, because the game has a player.
##
## Ignored unless [member first_person] and [member walkaround] are both set, and
## for the same reason the second is ignored without the first: there has to be
## somebody standing in the room before there is anything for a script to stand in
## for, and there has to be a walk before anything can be walked. Off by default,
## like every other difference between the two screens.
##
## [b]It drives the room through the player's own controls[/b] — [method steer] for
## the walk, [method aim_at] and [method release_aim] for the trigger, and
## [ToolBelt] for the swaps — rather than through a mode of its own. So there is no
## second answer anywhere below to "what does the power wash do to a muddy door",
## and an attract mode that looked wrong would be the game looking wrong.
## [AttractRoutine] is what it decides to do; [AttractWalk] is how hard it pushes.
@export var attracting: bool = false

## How long the demo spends on one pass over one panel, in seconds.
##
## Four, so a panel is washed, cleaned and buffed in twelve — short enough that
## somebody who glances at the screen sees a whole panel change, long enough that
## the jet visibly takes territory rather than flicking over. A full lap of a
## twelve-panel car is a little over two minutes, which is the loop nobody is
## expected to sit through and everybody is welcome to.
@export var attract_seconds_per_pass: float = 4.0

## How close the eye has to be to the work, in degrees around the car, before the
## walk starts easing off instead of pushing flat out. See [AttractWalk] for why
## there is a band at all rather than a camera that walks until it arrives.
##
## Forty is about a second of walking at [member turn_degrees_per_second], which
## is the arrival a car being circled looks right slowing into.
@export var attract_turn_ease_degrees: float = 40.0

## The same band for the eye's height, in metres. Smaller than the turn's in the
## sense that matters — the whole vertical range is 1.3 m — so the eye settles onto
## a wheel or a roof rather than creeping the last of the way.
@export var attract_lift_ease_metres: float = 0.6

## How far above the work the demo stands its eye, in metres.
##
## Above rather than level with it, because the camera looks at the middle of the
## car whatever height it is at ([method _face_car]): an eye level with a roof sees
## the roof edge on and an eye level with a wheel is lying on the tarmac. Half a
## metre up is the angle somebody working on a panel actually looks down it at.
@export var attract_eye_rise_metres: float = 0.5

## How far left or right of straight ahead the held tool may be swung, in
## degrees. A backstop rather than a frame edge: it was picked to sit inside the
## 75° design lens's half-angle, but [Lens] narrows that on a tall window, and
## every press is on the glass and so already inside the frame.
@export var aim_yaw_degrees: float = 32.0

## How far up or down. Tighter than the yaw because a car is wide and low: see
## [member ToolAim.pitch_limit_degrees].
@export var aim_pitch_degrees: float = 24.0

## How fast the hand swings toward a new aim, in degrees per second. The full
## width of the cone in about a fifth of a second — fast enough to feel like a
## response to the press rather than a decision about it, slow enough that the
## eye follows the tool across instead of finding it already there.
@export var aim_swing_degrees_per_second: float = 320.0

## How far the aiming ray is cast, in metres. Comfortably past the far edge of
## the modeled ground, so a press at the horizon is answered by "hit nothing"
## because there is nothing there rather than because the ray ran out.
@export var aim_reach: float = 40.0

## How wide the power wash's jet is where it lands, as a radius in metres.
##
## This and [member wash_per_second] were both about four times too small when
## they shipped, and the way they were wrong is worth writing down because it is
## not a bug and it fails like one.
##
## The first pair — a 0.16 m jet at 0.7 a second, chosen as "a hand's width, and
## about a second and a half to clean a spot" — is defensible on paper and
## unusable in the game. Measured, through the real scene stack: a full second of
## held trigger took 0.0004 of the car off, which is four minutes of unbroken
## sweeping for one flank. The patch it cleared was about 16 cm across on a 4.3 m
## car, so on a phone, where the whole car is a few hundred pixels, a second of
## work moved a handful of them. It was reported as "I can't wash it off", which
## is exactly right: a tool that works this slowly is indistinguishable from a
## tool that does not work, and no amount of it being technically correct helps.
##
## The lesson from that pass was that neither number means anything on its own —
## what matters is the jet against the size of the car and the size of the car
## against the screen. Half a metre of radius is where that lesson landed, and it
## was right for as long as this radius was invisible: nothing on screen was that
## size, only the mud it cleared was.
##
## [WashJet] changed that. It puts this radius on screen as the patch the water
## lands on, and half a metre of radius put a 0.9 m circle of spray at the far
## end of the jet — wider across than the car's own wheels (0.33 m radius each,
## see [code]src/world/car.gd[/code]) — which reads as a wheel-sized ball landing
## on the paint rather than as a mark. The lesson above still holds; it is just
## being applied against a new picture rather than an old one. A fifth of a
## metre keeps the jet a size a hand plausibly holds and clears in the same
## second or so [member wash_per_second] already promises — it costs more
## sweeping to cover the whole car, which is the honest side effect of a smaller
## brush and not a second regression to measure away.
##
## Not distance-dependent, and that is a simplification rather than a decision:
## real water spreads and loses pressure with range, which is a reason to stand
## close, which is a mechanic. It wants the standoff and the reach to mean
## something first.
##
## Doubled from the fifth of a metre above to two fifths: a wider patch of
## water at the far end of [WashJet] reads as more pressure behind the wand, and
## doubling [member wash_per_second] alongside it keeps the time to clean a
## single spot the same — this widens the patch a press covers rather than
## changing how long a press takes.
@export var wash_radius_metres: float = 0.4

## How much mud a held jet takes off a spot per second, where [code]1.0[/code] is
## all of it.
##
## Under half a second from filthy to clean in the middle of the jet, and longer
## at its edge. Fast enough that a press is visibly an action rather than a
## contribution — see [member wash_radius_metres] for what the cautious version
## of these two numbers felt like.
##
## Doubled alongside [member wash_radius_metres]: a wider jet with the same
## strength would take longer to clear, which reads as the water having gotten
## weaker rather than wider.
@export var wash_per_second: float = 5.0

## How wide the three cleaners reach, as a radius in metres. Half the jet's:
## water is thrown from a step back and a sponge is pressed against the paint.
@export var scrub_radius_metres: float = 0.22

## How much product a held cleaner lays down per second, where [code]1.0[/code]
## is full cover. Slower than the jet: the wash is the coarse pass over the whole
## car, and the cleaners are the pass where a window or a wheel is picked out.
@export var scrub_per_second: float = 3.0

## How wide the drying rag reaches. A cloth is a bigger thing than a sponge.
@export var buff_radius_metres: float = 0.3

## How much product a held rag turns into shine per second. The fastest of the
## three: it is the last pass over ground already covered twice, and the reveal
## is meant to be the reward rather than a third round of work.
@export var buff_per_second: float = 4.5

## Whether a tool running in this room can be heard — the water and the pump, the
## bottles' hiss, the rag's squeak, the sponge's squelch. [ToolRacket] is what
## makes them and [ToolNoise] is what they are made of.
##
## Off by default and switched on by the play screen alone, which is the split the
## bell already has — [signal Grime.patch_finished] is connected by the play screen
## and deliberately left dangling by the title screen — and it is switched on here
## for the same reason: the title screen runs this identical room with the game
## playing itself behind the card, and it stays silent on purpose. A browser will not
## let a page make a noise until somebody has pressed something — so a title card that
## ran a pressure washer at a player who has not touched it yet would be an odd first
## impression at a desk and impossible on the web, where Start is still the press
## that unlocks audio for everything. [Chime] has the whole argument.
##
## Read once, in [method _take_up_aiming]: this decides whether the room has
## anything to make a noise with at all, rather than muting one it built anyway.
@export var noisy: bool = false

## Whether every tool wears the plain crosshair instead of the effect it draws for
## itself. Off by default, so what ships is the water, the product and the foam:
## they are the things a player is meant to be looking at. Switched on —
## [code]src/screens/play_screen.gd[/code] wires this to the "~" panel's "Debug
## Tools" button — all three are stowed and the bare crosshair shows through under
## every tool, which is the developer's view of where the aim landed with nothing
## drawn over it.
##
## [b]This is the only place the ring is drawn now[/b], which makes it more useful
## rather than less. Every tool shows where it is working by working there, so the
## question "is the effect in the wrong place, or is the mud" has no other way of
## being asked — see [method ToolSight.sight], which has the argument for retiring
## it from play.
##
## Only the sight changes. [method _spend_the_trigger] still spends the same
## water on the same patch either way, so a bug chased with this on is the same
## bug with it off.
var debug_tools: bool = false

var _orbit: CameraOrbit = null
var _drive: OrbitDrive = null
var _standoff: Standoff = null
var _sight: ToolSight = null
var _sweep: AimSweep = null
var _racket: ToolRacket = null
var _grime: Grime = null
var _routine: AttractRoutine = null
var _running_order: Array[CSGShape3D] = []
var _aiming: bool = false
var _aim_at: Vector2 = Vector2.ZERO
var _marked: String = ""

@onready var _camera: Camera3D = %Camera
@onready var _car: Car = %Car

## Where held things render: a [ViewModel] parented to the camera, so it travels
## with the eye and never has to be re-aimed. What hangs in it is that class's
## business; where it hangs is this one's.
##
## Its pose lives in the scene file, like the room's box sizes, and the three
## numbers there are the whole "this is in your hand" illusion. 0.45 m down the
## camera's own -Z, because at a 75° horizontal field of view that depth makes
## the visible frame 0.69 m wide — so 0.17 m to the right is halfway to the right
## edge and 0.15 m down is near the bottom of a 16:9 frame. A tool sitting there
## rises into the corner of the shot, which is what a held thing looks like; dead
## centre at arm's length is not. Halfway is the decision and the metres only the
## notation, which a narrowed lens moves — see [method ViewModel.fit_to_lens].
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
		_take_up_aiming()
		if walkaround:
			_take_up_the_walk()
		return
	_orbit = CameraOrbit.new(orbit_radius, orbit_height, orbit_degrees_per_second)
	_orbit.angle_degrees = start_angle_degrees
	# Aimed once here rather than waiting for the first `_process`: a screen that
	# never orbits would otherwise keep whatever transform the scene file
	# happened to save, and the first frame of one that does would be a jump.
	_place_the_eye()


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
	_place_the_eye()


## The walk, on the physics clock rather than the frame clock.
##
## Not a preference: [method _hold_the_standoff] casts a ray, and a space state
## may only be queried while physics is stepping. Doing the movement here as well
## keeps the whole camera in one place per tick — a camera moved on one clock and
## measured on the other is a camera that measures where it used to be.
## Aiming rides the same clock, and for the same reason — it casts a ray too. It
## is settled before the walk moves the eye rather than after, so a press is
## answered against the frame the player was actually looking at when their
## finger landed on it.
##
## Ahead of the `_drive` test on purpose: a room can be aimed in without being
## one you can walk around, and a screen that set [member first_person] without
## [member walkaround] would otherwise have a tool that never moves.
##
## The demo goes first of all, because it is standing in for the player and the
## player's presses arrive before the tick rather than during it. What it does is
## press the glass and ask for a walk, so everything below reads them the same way
## it reads a real one's.
func _physics_process(delta: float) -> void:
	_run_the_demo(delta)
	_resolve_aim(delta)
	if _drive == null:
		return
	_drive.drive(_orbit, delta)
	_hold_the_standoff(delta)
	_place_the_eye()


## Takes the player's intent — [param turn] to walk around the car,
## [param lift] to raise or lower the eye, both in [code]-1..1[/code] — and does
## nothing at all if this room is not one anybody can walk in.
##
## The room takes the numbers and not the buttons. What is on screen is the play
## screen's business (a band round the edge of the glass today, a stick or a swipe
## later), and none of that should be able to reach in here; what arrives is "walk
## right", which is the only part the camera has an opinion about.
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


## Points the held tool at [param where], a point in this container's own local
## coordinates — which is to say, where the player is touching the picture of the
## room.
##
## [b]A point on the glass and not a direction in the world[/b], for exactly the
## reason [method steer] takes two numbers instead of two buttons: what is on
## screen is the play screen's business and where the camera is looking is this
## one's, and the only thing that has to cross between them is where the finger
## landed. A caller that had to turn a touch into a world ray would need the
## camera, the sub-viewport and its scaling — which is three pieces of this room
## in a file that should not have any.
##
## Recorded rather than answered: see [method _resolve_aim] for why the ray waits
## for the physics tick. Ignored outside first person — the title screen's
## showcase circuit has nobody standing behind it.
func aim_at(where: Vector2) -> void:
	if not first_person:
		return
	_aim_at = where
	_aiming = true


## The player has lifted their finger. The mark comes off the car and the hand
## falls back to rest.
##
## Holding the glass is firing and letting go is not — so this is the release
## half of the trigger, and the thing that will one day also stop the water.
func release_aim() -> void:
	_aiming = false


## What the aim is drawn with, or [code]null[/code] on a screen that never took up
## aiming — the title screen's showcase circuit has nobody pointing anything.
##
## Public, along with the three forwards below, so a test can ask where the mark
## actually landed and where the water and the product actually went, rather than
## trusting a signal to have meant it. The forwards are kept rather than replaced
## by [code]sight().marker()[/code] because where the mark is has been a question
## about the room since long before there was a [ToolSight] to keep it in
## — and they stop at three, because a fourth would be this file growing an
## accessor per effect all over again. The sponge's foam is reached through
## [method ToolSight.sponge_suds], which is where it lives.
func tool_sight() -> ToolSight:
	return _sight


## Where the aim landed on the paint — and, under [member debug_tools], the
## crosshair drawn there.
func aim_marker() -> AimMarker:
	return null if _sight == null else _sight.marker()


## The power wash's water.
func wash_jet() -> WashJet:
	return null if _sight == null else _sight.wash_jet()


## What the two bottles spray.
func spray_mist() -> SprayMist:
	return null if _sight == null else _sight.spray_mist()


## What the running tool sounds like, or [code]null[/code] in a room that is not
## [member noisy] — which is every room but the one the game is played in.
##
## Not a fourth forward through [ToolSight], which the three above deliberately
## stop at: the racket is not part of the sight and is not reached through it. It
## is public for the same reason they are, though — a test asking "does holding
## the trigger make a noise" has to be able to ask the thing making it, and a
## signal saying a noise was requested would be a test of this file's intentions
## rather than of the game's audio.
func tool_racket() -> ToolRacket:
	return _racket


## The mud on the car, or [code]null[/code] on a screen that never took up
## aiming. Not laid on the panels until [signal grimed] has been emitted.
##
## Public for the same reason [method view_model] is: the play screen has a debug
## view that draws these masks, and it must draw [i]these[/i] rather than build a
## set of its own.
func grime() -> Grime:
	return _grime


## Puts the camera where the orbit says it should be, looking at the car.
##
## Named for the eye and not for aiming, because aiming is now something the
## player does with a tool a few functions below and one word cannot mean both.
func _place_the_eye() -> void:
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


## Gives the hand something to swing on and the room something to draw the aim
## with. Both only exist in first person, which is the only mode with a player
## in it.
##
## [b]The sight is a sibling of the car, not a child of it.[/b] It is UI that
## happens to be drawn in world space, and hanging it inside the car would put it
## in the way of everything that walks the car's children looking for panels
## ([method Car.panels]) — for marks and sprays that are already positioned in
## world coordinates and gain nothing from the parenting.
##
## [b]The two radii go in here and nowhere else.[/b] The room is what knows how
## wide each tool reaches, because those are the patches the trigger works on; the
## sight is what draws them at that size. Handing them over at construction is what
## keeps the picture and the work one number rather than two.
##
## [b]The racket is built here too, and only when this room is [member noisy].[/b]
## It is the sight's opposite number — what the tool sounds like against what it
## looks like — so it is made alongside it, out of the same "there is somebody
## standing here holding something" that the whole function is about. A silent
## room simply never has one, which is what the null checks below are reading; a
## racket built and then muted would be a set of players mixing silence for the
## life of the title screen.
##
## Not a child of the car's parent, unlike the sight: it is not drawn anywhere and
## has no place in the world. It hangs off the room itself, which is the thing
## whose lifetime it should share.
func _take_up_aiming() -> void:
	_view_model.take_up_aiming(
		ToolAim.new(aim_yaw_degrees, aim_pitch_degrees, aim_swing_degrees_per_second)
	)
	_sight = ToolSight.new(wash_radius_metres, scrub_radius_metres)
	_sight.name = "ToolSight"
	_car.get_parent().add_child(_sight)
	# Built here rather than per press for the reason [AimSweep] gives: it owns two
	# engine objects that would otherwise be allocated twice a tick for as long as a
	# finger is dragging across the sky. Given the same reach the exact ray is cast
	# at, because it is the same aim asked a wider question.
	_sweep = AimSweep.new(aim_reach)
	if noisy:
		_racket = ToolRacket.new()
		_racket.name = "ToolRacket"
		add_child(_racket)
	_grime = Grime.new()
	_grime.name = "Grime"
	_car.get_parent().add_child(_grime)
	_lay_on_the_grime()


## Puts mud on the car, a frame after there is a car to put it on.
##
## [b]The wait is the whole function.[/b] Every mask is sized from its panel's
## [method CSGShape3D.get_aabb] and CSG meshes are built deferred, so a car asked
## during [method Node._ready] reports panels with no size — and a mask built
## against a zero box is a projection with nothing to divide by. [Car] documents
## the same trap for [method Car.bounds], which is where it was first paid for.
##
## Started and not awaited by the caller: [method _ready] has nothing further to
## do about grime, and making it wait would push every screen's first frame
## behind this.
func _lay_on_the_grime() -> void:
	await get_tree().process_frame
	if not is_instance_valid(_grime) or not is_instance_valid(_car):
		return
	_grime.lay_on(_car)
	# Here rather than in `_ready()` for the reason the grime itself is: the running
	# order is sorted by how big each panel is, and a panel asked before its CSG has
	# been built reports a zero box — so a demo set up a frame earlier would work the
	# car in whatever order the scene tree happened to list it.
	if attracting and _drive != null:
		_take_up_the_demo()
	grimed.emit()


## Turns a press on the glass into a mark on the paint and a tool pointed at it.
##
## [b]Why this is a physics tick and not a handler.[/b] It casts a ray, and a
## space state may only be queried while physics is stepping — the same
## constraint that put the walk on this clock. It also makes a drag cheap: a
## finger sliding across the screen fires an event per pixel of movement and this
## answers the latest one once per tick, so the cost of aiming does not depend on
## how fast somebody's thumb is moving.
##
## Nothing is emitted while the answer stays the same. A finger held on one door
## is one [signal aimed] rather than sixty a second, which matters because the
## thing on the other end of it draws text.
##
## [b]And the press is now worth something.[/b] A held trigger with the power wash
## in hand takes [member wash_per_second] of mud a second off wherever it landed
## — [method _spend_the_trigger] below is that, and it is deliberately the last
## thing this does. The mark goes on the paint whether or not any tool would do
## anything there, because the mark is a statement about where you are pointing
## rather than about what you are achieving.
func _resolve_aim(delta: float) -> void:
	if _sight == null:
		return
	if not _aiming:
		_view_model.lower()
		# Unconditionally, and before the early return below: both effects stop when
		# the finger comes off the glass, whether or not the panel under it changed.
		# The noise stops on the same line for the same reason — what a tool sounds
		# like and what it looks like are one statement, made in one place.
		_sight.hold_fire()
		if _racket != null:
			_racket.hush()
		if _marked.is_empty():
			return
		_marked = ""
		_sight.marker().unmark()
		aimed.emit(_marked)
		return
	var at: Vector2 = _aim_at * _picture_scale()
	var from: Vector3 = _camera.project_ray_origin(at)
	var facing: Vector3 = _camera.project_ray_normal(at)
	# The tool follows the finger and the mark follows the car — see the class
	# docs. This is that split, and it is one line: the hand is pointed at the
	# press, whatever the press turns out to have landed on.
	_view_model.aim_toward(_camera.global_basis.inverse() * facing)
	# Asked of the belt once a tick and handed down, rather than asked again by each
	# of the three things below that need it. Still every tick — which is the
	# property [method _sight_the_aim] was written for, so that a tool swapped while
	# the finger is down changes the sight, the sweep and the trigger on the same
	# tick — but now there is one copy of the answer instead of three.
	var held: DetailingTool = _view_model.belt().equipped()
	var found: Dictionary = _under_the_finger(from, facing, _reach_of(held.id))
	if found.is_empty():
		return
	var surface: Vector3 = found["position"]
	var outward: Vector3 = found["normal"]
	var panel: Node = found["collider"]
	_sight_the_aim(surface, outward, held)
	# Where it landed, which the hand needs and the direction above cannot carry: a
	# tool held below and to one side of the lens has to be pointed at the mark
	# rather than along the ray to reach it. See [method ViewModel.mark_at], which
	# is also where the one case these two deliberately disagree in is written down.
	_view_model.mark_at(surface, outward)
	_spend_the_trigger(found, held.id, delta)
	var named: String = "" if panel == null else String(panel.name)
	if named == _marked:
		return
	_marked = named
	aimed.emit(_marked)


## Draws the aim the way the tool in hand wants it drawn: water for the power
## wash, product for the two bottles, foam for the sponge, and — for the rag,
## which puts nothing back on the paint — the rag itself, sitting on the spot.
##
## [b]The mark is made first and always[/b], whichever sight is showing. It is
## what the panel readout names, what the wand lines itself up with, and what the
## trigger spends water on — see [AimMarker] — so this function only ever decides
## what is drawn on top of it.
##
## Draws the aim the way the tool in hand wants it drawn, which is [ToolSight]'s
## whole subject and none of this class's.
##
## What is decided here is only what that needs handing: which tool is in the
## player's hands, and where its business end is. [param held] is read off the belt
## once a tick by [method _resolve_aim] and the muzzle is asked of the viewmodel
## here, rather than either being wired up on a swap — so a tool changed while the
## finger is down changes the sight on the same tick and there is no second copy of
## "which tool is this" to fall out of step with the first. The tool itself comes
## over rather than its id, because the sponge's foam is drawn at the size of the
## sponge — see [method ToolSight.sight], which has the argument.
func _sight_the_aim(surface: Vector3, outward: Vector3, held: DetailingTool) -> void:
	_sight.sight(surface, outward, held, _view_model.muzzle_of(held.id), debug_tools)
	# The same tool, on the same tick, said out loud. Deliberately not under
	# [member debug_tools]: that switch trades what a tool draws for a crosshair so
	# a bug in the drawing can be seen past, and a developer looking at where the
	# aim landed has no reason to be working in silence.
	if _racket != null:
		_racket.run(held.id)


## What the tool in the player's hand does to the paint the press landed on.
##
## [b]The water goes where the mark is.[/b] Wherever the mark is sitting on real
## bodywork — whether the ray landed there or the aim snapped there — that is
## where the tool is pointed, and the game has just said so with the tool itself:
## water thrown at the spot, product sprayed at it, or a sponge or rag put down on
## it.
##
## This shipped the other way round for a day and it was wrong. The first rule was
## "only a ray that actually hit", reasoned about a player at a desk pointing at
## the sky beside the car, where refusing is obviously right. It is obviously
## wrong on a touchscreen, which is the platform this game is actually played on:
## the aim is taken a thumb's width above the finger ([ThumbLift] has why), so a
## thumb on the flank of a low, wide car routinely sends the ray just over the
## roof. The mark snaps back onto the paint and the tool goes there with it, which
## shows the player exactly where they are aimed — and the old rule then declined
## to spend any water there. A mark on the paint that does nothing is not a fair
## rule the player has to learn, it is a broken tool.
##
## What is still refused is [code]surface[/code] being false: a point clamped onto
## a bounding box, which is not on the mesh and whose normal is invented facing
## the player. That one is excluded because [BoxProjection] would pick a face off
## a normal nobody measured, not because of anything about fairness.
##
## [b]All five tools now, and the routing is the whole function.[/b] The job is
## three passes over every panel — the power wash takes mud off any of them, one
## of the three cleaners lays product on the surface it is for, and the drying rag
## buffs that into a shine anywhere.
##
## [b]Only the cleaners are refused, and only for the wrong surface.[/b] What
## keeps the three passes in order is not this function — it is [GrimeMap]'s
## buckets, where a cleaner draws from bare paint and a rag draws from product, so
## soaping a muddy wing or buffing a dry one moves nothing without anybody
## checking. The one rule that cannot be expressed that way is which bottle goes
## with which surface, because a sponge and a window cleaner are indistinguishable
## to a texture. So it is the only rule written here, it is one comparison against
## [method Surface.cleaner_for], and it fails by doing nothing.
##
## Doing nothing rather than working slowly, deliberately. A tool that half-works
## on the wrong surface teaches the player to hold the trigger longer; a tool that
## does not work at all teaches them to pick up the other bottle, which is the
## thing worth learning.
##
func _spend_the_trigger(found: Dictionary, held: DetailingTool.Id, delta: float) -> void:
	if _grime == null or not _grime.is_laid() or not found.get("surface", false):
		return
	# Read out into typed locals rather than passed straight through: a
	# [Dictionary] hands back [Variant], and this project's warning levels treat
	# handing one to a typed parameter as an error rather than as a cast.
	var panel: Node = found["collider"]
	var surface: Vector3 = found["position"]
	var outward: Vector3 = found["normal"]
	# How wide the brush is comes from [method _reach_of] rather than from the
	# export named on each branch below, so that the patch this works on and the
	# window [AimSweep] opened to find it are one number rather than two.
	var reach: float = _reach_of(held)
	if held == DetailingTool.Id.POWER_WASH:
		_grime.wash(panel, surface, outward, reach, wash_per_second * delta)
		return
	if held == DetailingTool.Id.DRYING_RAG:
		_grime.buff(panel, surface, outward, reach, buff_per_second * delta)
		return
	if held != Surface.cleaner_for(_car.kind_of(panel)):
		return
	_grime.foam(panel, surface, outward, reach, scrub_per_second * delta)


## How wide [param held] works, as a radius in metres.
##
## The one place the belt is turned into a size, and it is read twice: it is the
## patch [method _spend_the_trigger] lays down, and it is the window [AimSweep]
## forgives a near miss by. Those are deliberately the same number — the argument
## is [AimSweep]'s, and it is that the forgiveness a player gets should be the
## width of the brush they can already see.
##
## Three answers and five tools, because the three cleaners are one size: a bottle
## and a sponge are both pressed against the paint, and only the wash is thrown
## from a step back and only the rag is a cloth. The same grouping
## [method _spend_the_trigger] routes on, said once instead of at each branch.
func _reach_of(held: DetailingTool.Id) -> float:
	if held == DetailingTool.Id.POWER_WASH:
		return wash_radius_metres
	if held == DetailingTool.Id.DRYING_RAG:
		return buff_radius_metres
	return scrub_radius_metres


## What the press landed on: the panel the ray hit, the panel a tool-wide sphere
## swept down the same line touched, or failing both the nearest bit of car to it.
##
## Shaped like the engine's own [method PhysicsDirectSpaceState3D.intersect_ray]
## result — [code]position[/code], [code]normal[/code], [code]collider[/code] —
## including when it is assembled by hand below, so the caller has one shape to
## read rather than four and cannot forget which case it is in.
##
## Plus one key the engine does not set: [code]surface[/code], true when the
## position and the normal came off real geometry and false when they were
## reconstructed from a bounding box.
##
## It is not "did the ray hit" — three of the four answers below come off real
## geometry and all three set it. It is "is this a place on the car, with the
## car's own normal", which is the only question anything writing to a texture can
## use: everything that draws is happy with an approximation and says so by
## ignoring this, and a projection fed an invented normal picks the wrong face of
## the wrong panel. See [method _spend_the_trigger], which had this rule wrong
## once.
##
## [b]Three tiers, each strictly wider than the one above it, in that order for a
## reason.[/b] The exact ray is first because where it hits it is exactly right,
## and it answers nearly every press. [AimSweep] is second and not first because a
## swept sphere stops at the first thing it touches, which at a grazing angle is
## the roof edge rather than the door being pointed at — asked only after the ray
## came back empty, it has no exact answer left to steal. [param reach] is how wide
## the tool in hand works ([method _reach_of]), which is the window it forgives by.
##
## The nearest-panel fallback stays underneath both, unchanged, because it is the
## only one of the three that always answers: a sphere the width of a sponge is
## bounded by definition, and a press at the horizon should still put the mark on
## the car rather than nowhere. What the sweep took off it is the cases where it
## was reduced to inventing a normal — see [method _nearest_on_the_car].
func _under_the_finger(from: Vector3, facing: Vector3, reach: float) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = _camera.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, from + facing * aim_reach)
	)
	if not hit.is_empty():
		hit["surface"] = true
		return hit
	var swept: Dictionary = _sweep.onto(space, from, facing, reach)
	if not swept.is_empty():
		return swept
	return _nearest_on_the_car(space, from, facing)


## The nearest bit of car to a ray that hit nothing.
##
## [b]Two passes, because a box is not a car.[/b] [NearestPoint] works on one
## [AABB] per panel, which is cheap and is enough to answer "which panel, and
## roughly where on it" — but a box around a wing mirror is much bigger than the
## mirror, so the point it returns is beside the bodywork rather than on it, and
## it has no surface normal at all. So the answer is used as an aiming post: a
## second ray goes from the eye to just past that point, and if it hits, the mark
## goes on the real surface with the real panel's real normal.
##
## [b]When even that misses[/b] the box point is used as-is, faced at the player.
## It is the honest answer to "nearest bit of car" and it is visibly approximate,
## which beats showing nothing at all — but it is also the one answer nothing may
## clean, because its normal was invented rather than measured, so a press that
## lands here draws a working tool that moves no mud.
##
## [b]That last case is rarer than it was, and [AimSweep] is why.[/b] The presses
## it used to catch were mostly near misses — a thumb-lifted aim just over the
## roofline, or a ray threading the gap between a wheel and its arch — and those
## are now answered a tier above this with a real normal off real paint. What is
## left down here is the genuinely distant press: the sky well above the car, the
## tarmac metres to one side. Which is the right shape for it. A last resort that
## fires on a near miss is a bug wearing a fallback's clothes; a last resort that
## fires when the player is plainly not pointing at the car is doing its job.
func _nearest_on_the_car(
	space: PhysicsDirectSpaceState3D, from: Vector3, facing: Vector3
) -> Dictionary:
	var panels: Array[CSGShape3D] = _car.panels()
	var boxes: Array[AABB] = []
	for panel: CSGShape3D in panels:
		boxes.append(panel.global_transform * panel.get_aabb())
	var nearest: int = NearestPoint.nearest_box(boxes, from, facing)
	if nearest < 0:
		return {}
	var post: Vector3 = NearestPoint.in_box_from_ray(boxes[nearest], from, facing)
	var reach: Vector3 = post - from
	var probe: Dictionary = space.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, from + reach * PAST_THE_POST)
	)
	# The probe really did hit the car, so it carries the car's own normal and is
	# somewhere a tool can be used — it only needed a post put in front of it to
	# be found. The box point below did not: it is a corner of a bounding box with
	# a normal pointed back at the player because there was nothing to measure one
	# from, and that is the one answer nothing may write to.
	if not probe.is_empty():
		probe["surface"] = true
		return probe
	return {
		"position": post,
		"normal": (from - post).normalized(),
		"collider": panels[nearest],
		"surface": false,
	}


## How much bigger the picture on the glass is than the viewport the world is
## rendered into, so a press can be turned into a point the camera understands.
##
## [code]stretch[/code] is on in [code]garage.tscn[/code], which keeps the
## [SubViewport] the same size as this container and makes this [code](1, 1)[/code]
## today. It is computed rather than assumed because
## [member SubViewportContainer.stretch_shrink] exists, is exactly the setting
## somebody reaches for when the web build needs to render at half resolution on
## a phone, and would otherwise silently halve every aim in the game.
func _picture_scale() -> Vector2:
	var view: SubViewport = _camera.get_viewport() as SubViewport
	if view == null or size.x <= 0.0 or size.y <= 0.0:
		return Vector2.ONE
	return Vector2(view.size) / size


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


## Works out the order the demo goes round the car in and hands it to an
## [AttractRoutine], along with a [ToolBelt] swap and a walk it will drive through
## the player's own controls.
##
## [b]Biggest panel first, and measured rather than listed.[/b] The whole point of
## an attract mode is what somebody sees from across a room, and what they see is
## the tub, the cabin and the bonnet changing colour — not a wing mirror being
## detailed for twelve seconds. So the running order is [method Car.panels] sorted
## by how much car is in each one. A list of panel names in the right order would
## be the same thing written down, and it would be wrong the first time somebody
## added a window — which is the argument [method Car.kind_of] already makes about
## reading a group instead of a name.
##
## A lap ends with the mud going back on, which is [method _on_lapped] and is the
## one thing here a player could not do.
func _take_up_the_demo() -> void:
	_running_order = _car.panels()
	_running_order.sort_custom(_bigger_first)
	var kinds: Array[Surface.Kind] = []
	for panel: CSGShape3D in _running_order:
		kinds.append(_car.kind_of(panel))
	_routine = AttractRoutine.new(kinds, attract_seconds_per_pass)
	_routine.lapped.connect(_on_lapped)


## Whether [param first] is more car than [param second], by the volume of the box
## around it. Local rather than global on purpose: a comparison between two panels
## of the same car needs no transform, and the boxes are the same either way for a
## car nobody has scaled — which [code]tests/integration/test_garage.gd[/code]
## already holds.
func _bigger_first(first: CSGShape3D, second: CSGShape3D) -> bool:
	return first.get_aabb().get_volume() > second.get_aabb().get_volume()


## One tick of the demo: hold whatever the pass calls for, walk the eye round to
## the work, and point at it.
##
## Does nothing at all on a room that never took the demo up, which is every room
## the game is actually played in — the null check is the mode test, the same way
## it is for the orbit and the walk.
func _run_the_demo(delta: float) -> void:
	if _routine == null:
		return
	_routine.advance(delta)
	var panel: CSGShape3D = _running_order[_routine.stop()]
	var box: AABB = panel.global_transform * panel.get_aabb()
	# Asked of the belt every tick rather than wired to a swap, for the reason
	# [method _sight_the_aim] reads the belt every tick: `equip` refuses the tool
	# already in hand, so this is a comparison and not a swap, and there is no
	# second copy of "which tool should the demo be holding" to fall out of step.
	_view_model.belt().equip(_routine.tool())
	_lead_the_eye(box.get_center())
	_press_the_glass(_routine.aim_over(box))


## Pushes the walk toward the panel at [param panel], in the two numbers a thumb
## would have pushed it with.
##
## [b]To the panel, not to the sweep.[/b] The eye is led to the middle of the thing
## being worked and left there for all three passes, while the tool does the
## wandering — which is both what a person does and the only version that holds
## still. Following the aim instead means following a point that runs the length of
## the car three times a pass, and the tub's box is the whole car: the eye would
## spend every pass chasing the nose and the tail and arriving at neither.
##
## [code]atan2(x, z)[/code] and not the usual [code](y, x)[/code], for
## [method _take_up_the_walk]'s reason: this orbit measures its angle from
## [code]+Z[/code] toward [code]+X[/code], so the arguments swap.
##
## The height goes over as a height above the [i]car[/i], because that is what
## [member CameraOrbit.height] is and what [AttractWalk] therefore steers. The
## floor is this file's business and does not need to be anybody else's.
func _lead_the_eye(panel: Vector3) -> void:
	var offset: Vector3 = panel - _car.global_position
	var turn: float = 0.0
	if Vector2(offset.x, offset.z).length() > NO_SIDE_TO_IT:
		turn = AttractWalk.turn_toward(
			_orbit.angle_degrees, rad_to_deg(atan2(offset.x, offset.z)), attract_turn_ease_degrees
		)
	steer(
		turn,
		AttractWalk.lift_toward(
			_orbit.height, offset.y + attract_eye_rise_metres, attract_lift_ease_metres
		)
	)


## Puts the demo's finger on the picture of [param work], or takes it off when
## there is no picture of it to put a finger on.
##
## [b]It really does press the glass.[/b] The obvious shortcut is a second
## entry point that takes a point in the world and skips the projection, and it is
## the thing worth not building: [method aim_at] is where a press becomes a ray, a
## mark, a swung tool and a spent trigger, and a demo that entered the game
## anywhere else would be a second path through all of it — the one that still
## worked on the day the first one broke. So the work is projected onto the glass
## and handed back in through the door a thumb uses.
##
## [b]Off the glass is a release and not a clamp.[/b] Behind the lens, or past the
## edge of the frame, the projection has no answer — [method Camera3D.unproject_position]
## on a point behind the camera returns a mirrored one, which would aim the tool at
## the opposite side of the room — so the demo lets go instead, exactly the way a
## player who could not see what they were aiming at would. It happens while the eye
## is still walking round to a panel on the far side of the car, and what it looks
## like is somebody lowering the wand as they walk.
##
## In this container's own coordinates, which is what [method aim_at] takes:
## [method Camera3D.unproject_position] answers in the sub-viewport's pixels, and
## [method _picture_scale] is the ratio between the two.
func _press_the_glass(work: Vector3) -> void:
	if _camera.is_position_behind(work):
		release_aim()
		return
	var at: Vector2 = _camera.unproject_position(work) / _picture_scale()
	if not Rect2(Vector2.ZERO, size).has_point(at):
		release_aim()
		return
	aim_at(at)


## The demo has washed, cleaned and buffed every panel, so the car gets dirty
## again and it starts over.
##
## [b]The one thing in the demo a player cannot do[/b], and it is deliberately not
## dressed up as one. A cabinet's demo restarts; it does not drive a second car in.
## [method Grime.lay_on] says calling it twice replaces what was there, which is
## exactly this, and it is the only line of the attract mode that reaches past the
## controls a player has.
func _on_lapped() -> void:
	_grime.lay_on(_car)


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
