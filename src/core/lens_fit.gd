## The lens, fitted to the shape of the glass it is looking through.
##
## [b]The problem this solves, measured rather than argued about.[/b] The camera
## in [code]src/world/garage.tscn[/code] is [code]KEEP_WIDTH[/code], so its
## [member Camera3D.fov] is the [i]horizontal[/i] angle and the vertical one
## falls out of however tall the viewport happens to be. That is a fine deal on
## the 16:9 the game is designed at — 75° across gives 46.7° up and down, and the
## car fills 74% of the frame's width and 82% of its height. It is a terrible
## deal on a phone held upright, which is what this game actually ships to:
## [code]window/stretch/aspect[/code] is [code]"expand"[/code] (see
## [code]project.godot[/code], which has the measurements behind that choice), so
## a portrait window does not letterbox — it grows the viewport downward. A
## Pixel 7 in a browser lands on a 1280x2609 viewport, and 75° across that is
## [b]114.8° from top to bottom[/b]. The car drops to 22.5% of the frame's height
## and the shot is mostly sky and driveway.
##
## All four of those numbers came off the real scene stack at both window sizes,
## not off a whiteboard.
##
## [b]So the horizontal angle stops being a constant.[/b] What is held instead is
## a ceiling on the vertical one: on a screen tall enough that the design lens
## would fisheye, the horizontal field of view is narrowed until the vertical fits
## under the cap. On 16:9 the cap is slack and nothing moves at all — verified,
## the desktop shot is identical before and after.
##
## [b]It is a fit and not a zoom, and the difference matters.[/b] Nothing here
## moves the camera. The eye still stands where [Standoff] puts it, which is the
## number that keeps a held tool out of the paint; this only decides how much of
## the room that eye's lens takes in. The two are separate on purpose — walking
## the camera closer to fill the frame would spend a clearance budget that exists
## for a different reason.
##
## [b]Node-free[/b] (STANDARDS.md "Coverage" R3): a viewport's size belongs to
## [code]src/world/garage.gd[/code], and the trigonometry that decides what lens
## to point through it belongs here, where every aspect ratio is a row in a unit
## test rather than a window somebody resized.
class_name LensFit
extends RefCounted

## The widest a lens may be, in degrees. Not a taste boundary — past this the
## projection stops being invertible in any useful way, and Godot itself clamps
## [member Camera3D.fov] to 179.
const WIDEST: float = 179.0


## The horizontal field of view to actually use, in degrees.
##
## [param design_degrees] is the lens the shot was framed at — the number in the
## scene file. [param max_vertical_degrees] is the ceiling on the vertical angle,
## and [param aspect] is the viewport's width over its height.
##
## Never wider than the design lens, whatever the cap allows: this exists to
## rescue a shot on a tall screen, not to open one up on a wide one. A 21:9
## monitor would otherwise be handed a lens nobody framed anything at.
##
## A cap of zero or less means "no ceiling", and a nonsense aspect means "I have
## nothing to fit to" — both hand back the design lens unchanged, because the
## honest answer to having no measurement is to leave the shot alone.
static func horizontal_fov(
	design_degrees: float, max_vertical_degrees: float, aspect: float
) -> float:
	if max_vertical_degrees <= 0.0 or aspect <= 0.0 or not is_finite(aspect):
		return design_degrees
	var capped: float = minf(max_vertical_degrees, WIDEST)
	var widest: float = rad_to_deg(2.0 * atan(tan(deg_to_rad(capped) * 0.5) * aspect))
	return minf(design_degrees, widest)


## The vertical field of view a horizontal one works out to on a viewport of this
## [param aspect], in degrees.
##
## The inverse of the sum [method horizontal_fov] solves, and public because it
## is what a test asserts the ceiling with — checking the angle that was capped
## rather than the angle that was set to cap it.
static func vertical_fov(horizontal_degrees: float, aspect: float) -> float:
	if aspect <= 0.0 or not is_finite(aspect):
		return horizontal_degrees
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(horizontal_degrees) * 0.5) / aspect))


## Half the width of what the lens can see at [param depth] metres in front of it.
##
## The unit the held tool is placed in. [code]src/world/garage.tscn[/code] hangs
## the [ViewModel] anchor a fixed number of metres off the camera's own axis, and
## those metres were chosen against the design lens as "halfway to the edge of the
## frame" — so a narrower lens has to move them in, or the hand slides out of shot
## entirely. Measured at the 70° ceiling on a phone: left alone, the anchor lands
## at 1.05 of the frame's width, which is to say off the right-hand edge of it.
static func half_frame(fov_degrees: float, depth: float) -> float:
	return depth * tan(deg_to_rad(fov_degrees) * 0.5)
