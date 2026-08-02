## The camera, with an opinion about how wide it is allowed to be.
##
## [b]The problem, measured on the real scene stack at both window sizes.[/b]
## This camera is [code]KEEP_WIDTH[/code], so the field of view in
## [code]garage.tscn[/code] is the angle across the frame and the angle up and
## down is whatever the viewport's shape makes it. At the 16:9 the game is
## designed at, 75° across gives 46.7° down, and the car fills 74% of the width
## and 82% of the height — the shot as it was framed. On a phone held upright it
## is the same 75° across and [b]114.8° down[/b], because
## [code]window/stretch/aspect[/code] is [code]"expand"[/code] (see
## [code]project.godot[/code]) and a portrait window grows the viewport downward
## rather than letterboxing it. A Pixel 7 in a browser lands on 1280x2609. The car
## drops to 22.5% of the frame's height and the rest is sky and driveway.
##
## So the one number somebody chose quietly became a second number nobody chose,
## and the second one is the one the player sees.
##
## [b]The fix is to stop treating the horizontal angle as the constant.[/b]
## [member max_vertical_fov_degrees] is a ceiling on the vertical angle, and the
## horizontal one is narrowed until the vertical fits under it. [LensFit] carries
## the trigonometry and is Node-free so the table of aspect ratios is a unit test;
## what is here is the part that needs a real viewport.
##
## [b]It costs the wide screen nothing[/b] — at 16:9 the design lens is already
## under the ceiling, so the fit hands it straight back and the desktop shot is
## unchanged. Asserted both ways round in
## [code]tests/integration/test_play_screen_lens.gd[/code] rather than assumed.
##
## [b]Why this is a script on the camera and not three more functions in
## [Garage].[/b] The room is already the longest file in the project and sits
## exactly on `.gdlintrc`'s 1000-line cap — which is the file telling you it has
## enough jobs. This one is genuinely the camera's own: a lens is a property of
## the thing doing the looking, the viewmodel that has to be re-framed with it is
## already a child of this node, and the room goes on knowing only that it has a
## [Camera3D] to point at the car.
##
## [b]It is a fit and not a dolly.[/b] Nothing here moves the camera. Where the
## eye stands is [Standoff]'s business and is the number that keeps a held tool
## out of the paint; this only decides how much of the room that eye takes in. The
## two are kept separate on purpose — walking the camera in to fill the frame
## would spend a clearance budget that exists for a different reason.
class_name Lens
extends Camera3D

## The most vertical field of view the shot may have, in degrees, before the lens
## is narrowed to bring it back under.
##
## 70° is a wide-but-ordinary first-person lens; past about there the picture
## reads as a fisheye rather than as a room. At this ceiling a phone's lens
## narrows to 37.9° across, and the car goes from 22.5% of the frame's height to
## 50.3% of it — from a car parked across the driveway to a wing and a door, which
## is the distance the work is actually done at.
##
## An export, so the two screens that instance this room can disagree about it the
## way they disagree about everything else: a title card is a showpiece and may
## well want to see more car than the shot you work in does.
##
## Zero or less means "no ceiling", and hands back the lens the scene file asked
## for whatever shape the window is.
@export var max_vertical_fov_degrees: float = 70.0

## The lens the shot was framed at, read off the scene file once and never
## written back to.
##
## Kept because [method _fit] runs again on every resize, and a fit computed from
## the camera's *current* field of view would ratchet: narrow it for a portrait
## phone, turn the phone sideways, and the already-narrowed lens would be narrowed
## again. This is the fixed point every fit is computed from, which is what lets
## the shot come back when the window does.
var _design_fov: float = 0.0


func _ready() -> void:
	_design_fov = fov
	# Re-fitted on every resize rather than only at startup: the web build's canvas
	# follows the browser window, and a phone turned on its side changes the shape
	# of the viewport without reloading anything.
	get_viewport().size_changed.connect(_fit)
	_fit()


## Narrows the lens until the shot stops being a fisheye, and re-frames the hand
## to match.
##
## [b]A viewport with no area is not something to fit to.[/b] It happens — a
## container that has not been laid out yet reports zero — and dividing the
## framing by it would hand the camera a garbage lens. Left alone instead, because
## the resize this is connected to calls back the moment there is something real
## to measure.
func _fit() -> void:
	var frame: Vector2 = get_viewport().get_visible_rect().size
	if frame.x <= 0.0 or frame.y <= 0.0:
		return
	fov = LensFit.horizontal_fov(_design_fov, max_vertical_fov_degrees, frame.x / frame.y)
	# Told rather than left to notice. The hand is placed as a fraction of the
	# frame, so it has to move when the frame does — and it has to move *after* the
	# lens has, which two independent listeners on the same signal could not
	# promise. Absent on a screen that has no hands, which the title card is.
	var hand: ViewModel = get_node_or_null("ViewModel") as ViewModel
	if hand == null:
		return
	hand.fit_to_lens(_design_fov, fov)
