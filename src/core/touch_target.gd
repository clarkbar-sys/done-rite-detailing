## How big a control has to be before a finger can reliably hit it.
##
## This exists because "the Start button doesn't work on mobile" turned out not
## to be an input bug at all — the tap reaches the button fine, the button was
## just 18 CSS pixels tall on a phone, so most taps missed it and the screen
## looked dead. A number that only lives in a designer's head gets shrunk by the
## next person, so it lives here and
## [code]tests/integration/test_title_screen.gd[/code] gates the Start button
## against it.
##
## [b]Reference pixels[/b] below means the unit a phone reports its screen in —
## CSS pixels in a browser, dp on Android, points on iOS. All three are the same
## idea: roughly 1/96 inch, independent of how many hardware pixels are packed
## into it.
class_name TouchTarget
extends RefCounted

## The smallest comfortable tap target, in reference pixels. Android's Material
## guideline is 48 dp and Apple's is 44 pt; this takes the stricter of the two,
## because the cost of being generous is a slightly bigger button and the cost
## of being wrong is a game that appears not to respond.
const MIN_REFERENCE_PX: float = 48.0

## The narrowest screen the game is meant to be playable on, in reference
## pixels: an iPhone SE or a small Android in portrait. It sets the worst case,
## since the narrower the screen the harder the design is squeezed into it.
const NARROWEST_SCREEN_PX: float = 375.0

## Fallback for [method design_width] if the setting ever goes missing — the
## value `project.godot` ships with today.
const DEFAULT_DESIGN_WIDTH: float = 1280.0


## The project's base viewport width, in design pixels.
##
## Read from `project.godot` rather than written down twice: the whole point of
## [method min_design_size] is to follow the design, and a copy of 1280 here
## would quietly stop being true the day someone changes the base resolution.
## Via `str()` and not `float()`, which this project's type gates reject for a
## [Variant] argument: `ProjectSettings.get_setting` cannot promise a number, so
## the value is read as text and parsed. A setting that is somehow not a number
## parses as 0.0, which fails the tests below rather than passing silently.
static func design_width() -> float:
	var setting: Variant = ProjectSettings.get_setting(
		"display/window/size/viewport_width", DEFAULT_DESIGN_WIDTH
	)
	return str(setting).to_float()


## The smallest a control may be, in design pixels, and still be tappable on the
## narrowest screen in [constant NARROWEST_SCREEN_PX].
##
## One ratio, and nothing subtler than that. `window/stretch/mode` is
## `canvas_items`, so the engine scales the whole design into the window: a
## control's size on screen is its design size times
## `screen_width / design_width`. Rearranged, staying above
## [constant MIN_REFERENCE_PX] on screen needs
## `MIN_REFERENCE_PX * design_width / screen_width` design pixels — 164 of them
## for a 375 px screen and a 1280 px design.
##
## Wider screens are strictly easier: they scale the design down less, or not at
## all, so a control that clears this clears it everywhere.
static func min_design_size() -> float:
	return MIN_REFERENCE_PX * design_width() / NARROWEST_SCREEN_PX
