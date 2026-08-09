## The Done Rite look — the palette, and the two shapes the brand is built out
## of — in one place.
##
## The game is named after a real business, and that business already has a
## look: [url=https://bespoke-cascaron-816d86.netlify.app]its site[/url] declares
## the whole thing in a single CSS [code]:root[/code] block and then draws every
## page out of two shapes — a red pill for anything you press, and a dark
## rounded card for anything you look at. This class is that block transcribed,
## so the game and the site cannot drift apart one hard-coded [Color] at a time.
##
## [b]What does not survive the port, and why.[/b] The site's pill and card are
## both CSS gradients ([code]135deg[/code] red to red-dark;
## [code]145deg[/code] #202026 to #0d0d10) and [StyleBoxFlat] has no gradient —
## it is a flat fill by name and by design. Faking one would mean a
## [StyleBoxTexture] over a [GradientTexture2D], which trades a readable
## constant for a texture nobody can grep. So the fills here are flat and the
## glow does the work the gradient was doing.
##
## The other thing the port has to answer for is what the brand is printed on.
## The site owns its background and makes it near-black; the game's is a lit
## garage it does not get to repaint, so the one colour used differently here is
## [constant INK] — a shadow under type rather than a page behind it.
##
## Node-free on purpose, like everything in [code]src/core/[/code]: a
## [StyleBoxFlat] is a [Resource], so every shape below can be built and
## measured in a unit test without a [SceneTree]. See
## [code]tests/unit/test_brand.gd[/code].
class_name Brand
extends RefCounted

## `--red`: the site's one accent. Anything the visitor is meant to press wears
## it, and nothing else does.
const RED: Color = Color("#e21b23")

## `--red-dark`: the far end of the button gradient. Here it is what a press
## looks like — the pill sinks to the colour it was already shading towards.
const RED_DARK: Color = Color("#a90f16")

## `--panel`: the fill behind a card. Not black, so a card reads as a panel
## lifted off the page rather than a hole cut in it.
const PANEL: Color = Color("#141418")

## `--line`: the hairline around every card and dark button. White at 9%, which
## is a highlight rather than a border — it catches the top edge and disappears
## everywhere else.
const LINE: Color = Color(1.0, 1.0, 1.0, 0.09)

## `--muted`: secondary type — the tagline under the wordmark, the paragraph
## under a heading.
const MUTED: Color = Color("#b9b9c1")

## `--black`: the page the site is printed on. The game has no such page — its
## type is laid over a lit garage, a yellow truck and a green verge — so here it
## is what secondary type is [i]shadowed[/i] with instead. Grey on white is the
## one way [constant MUTED] can fail, and the room behind it is not ours to
## darken.
const INK: Color = Color("#09090b")

## `--white`: primary type, and the only colour that goes on top of [constant RED].
const WHITE: Color = Color("#ffffff")

## `border-radius:30px` — the corner of a hero card.
const CARD_RADIUS: int = 30

## `padding:12px` — a card is a frame, so its content sits inset by this much on
## every side.
const CARD_INSET: int = 12

## `box-shadow:0 20px 60px rgba(0,0,0,.45)` — a card's drop shadow, split into
## the three numbers a [StyleBoxFlat] takes.
const CARD_SHADOW_DROP: int = 20
const CARD_SHADOW_SIZE: int = 60
const CARD_SHADOW_ALPHA: float = 0.45

## `box-shadow:0 12px 30px rgba(226,27,35,.26)` — the red glow under a pill.
## Same split, and the same reading of a CSS blur radius as a size: Godot grows
## the box by [member StyleBoxFlat.shadow_size] and fades it out, where CSS
## blurs it by that much, so the two are close enough to share a number and not
## close enough to pretend they are the same operation.
const PILL_SHADOW_DROP: int = 12
const PILL_SHADOW_SIZE: int = 30
const PILL_SHADOW_ALPHA: float = 0.26

## The shadow that keeps [constant MUTED] type readable over the room: dropped
## a little, spread a little, in [constant INK]. The site shadows its own
## headline the same way ([code]text-shadow:0 10px 30px[/code]); the numbers are
## smaller here because this is a caption rather than a six-rem heading, and
## because the shadow is doing a job the site's page colour did for free.
const TYPE_SHADOW_DROP: int = 3
const TYPE_SHADOW_SPREAD: int = 4
const TYPE_SHADOW_ALPHA: float = 0.6

## How much lighter the pill goes under the pointer. The site lifts its buttons
## two pixels instead ([code].btn:hover{transform:translateY(-2px)}[/code]),
## which a [StyleBox] cannot do — it draws inside a rect it does not get to
## move. Lightening is the same message in the vocabulary this engine has.
const HOVER_LIFT: float = 0.08

## Width of the focus ring, in design pixels. Thick enough to survive the
## roughly-a-third scale a phone renders this design at.
const FOCUS_RING_WIDTH: int = 4

## How visible the focus ring is. White, but not the full [constant WHITE] —
## the ring marks where the keyboard is, and should not read as a second button.
const FOCUS_RING_ALPHA: float = 0.55

## The most segments [StyleBoxFlat] will bend a corner into. The default (8) is
## a polygon at the radii a 176-pixel-tall button needs.
const CORNER_DETAIL: int = 20

## The contrast a badge's picture has to clear against the plate behind it.
##
## WCAG 2.1 puts non-text graphics at 3:1 and normal-size text at 4.5:1, and the
## higher number is the one used here on purpose: a tool badge is read the way a
## word is — glanced at once, in peripheral vision, over a lit garage that is
## brighter than any page this palette was designed for. The failure it exists
## for is measurable rather than aesthetic. Tire & Engine Cleaner's albedo is
## near-black, which is correct for a bottle standing in a garage and
## [b]1.02:1[/b] against [constant PANEL] — a badge you cannot see is not a
## dimmer badge, it is an empty plate.
const BADGE_CONTRAST: float = 4.5

## How many steps [method badge_tint] may take on its way to the floor above.
##
## The last step is [code]lightened(1.0)[/code], which is white and clears any
## floor, so the search always terminates — and it terminates at the [i]least[/i]
## lightening that works, which is what keeps a tint the tool's own colour rather
## than a pastel of it. Fifty is a 2% step: fine enough that nothing is lifted
## further than it had to be, coarse enough to be a loop and not a solver.
const TINT_STEPS: int = 50

## The two halves of the sRGB transfer function, as
## [url=https://www.w3.org/TR/WCAG21/#dfn-relative-luminance]WCAG 2.1[/url]
## writes them. Transcribed rather than taken from [method Color.srgb_to_linear]
## for the reason the palette above is transcribed twice: the numbers being
## checked and the numbers doing the checking should not be the same numbers.
const SRGB_KNEE: float = 0.04045
const SRGB_SLOPE: float = 12.92
const SRGB_OFFSET: float = 0.055
const SRGB_SCALE: float = 1.055
const SRGB_GAMMA: float = 2.4

## The three channel weights relative luminance is a sum of, and the constant the
## ratio is offset by so that black against black is 1:1 rather than a divide by
## zero.
const LUMA_RED: float = 0.2126
const LUMA_GREEN: float = 0.7152
const LUMA_BLUE: float = 0.0722
const LUMA_FLOOR: float = 0.05


## The site's pill button ([code].btn[/code]) in [param fill], sized for a
## control [param height] design pixels tall.
##
## The height is a parameter rather than the CSS [code]border-radius:999px[/code]
## because the engine and the browser disagree about what an over-large radius
## means, and only one of them is being tested here: half the height is a pill
## by arithmetic, at any size, with nothing clamping anything.
static func pill(fill: Color, height: float) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(roundi(height / 2.0))
	box.corner_detail = CORNER_DETAIL
	# Tied to the fill rather than fixed at red, so the pressed pill's glow sinks
	# with it instead of hovering under a button that has already gone dark.
	box.shadow_color = Color(fill, PILL_SHADOW_ALPHA)
	box.shadow_size = PILL_SHADOW_SIZE
	box.shadow_offset = Vector2(0.0, float(PILL_SHADOW_DROP))
	return box


## The keyboard's marker for a pill of the same [param height]: the ring, and
## nothing under it.
##
## Transparent by necessity, not taste. Godot draws the [code]focus[/code]
## stylebox [i]over[/i] whichever state box is already there, so an opaque one
## would erase the press — and this screen hands focus to Start the moment it
## opens, which would make that every press.
static func focus_ring(height: float) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(WHITE, 0.0)
	box.set_corner_radius_all(roundi(height / 2.0))
	box.corner_detail = CORNER_DETAIL
	box.set_border_width_all(FOCUS_RING_WIDTH)
	box.border_color = Color(WHITE, FOCUS_RING_ALPHA)
	return box


## The site's hero card ([code].hero-card[/code]): the dark rounded frame it
## puts every photograph inside.
##
## The frame is the point. The logo is artwork on its own black background, and
## dropped straight onto the title screen that black reads as a hole in the
## room behind it. Inside a card with a lit edge it reads as a plate hung on the
## wall — which is what the site does with the same picture, for the same reason.
static func card() -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = PANEL
	box.set_corner_radius_all(CARD_RADIUS)
	box.corner_detail = CORNER_DETAIL
	box.set_border_width_all(1)
	box.border_color = LINE
	box.set_content_margin_all(float(CARD_INSET))
	box.shadow_color = Color(0.0, 0.0, 0.0, CARD_SHADOW_ALPHA)
	box.shadow_size = CARD_SHADOW_SIZE
	box.shadow_offset = Vector2(0.0, float(CARD_SHADOW_DROP))
	return box


## The same pill in [param fill], with [method card]'s hairline around it: what a
## button wears when it is [i]not[/i] the one obvious thing to press.
##
## [b]Still two shapes.[/b] The site draws everything out of a red pill and a
## dark card, and that vocabulary has nothing to say the moment a screen offers
## two buttons at once — which is what a menu is. So this is the card's fill and
## the card's edge in the pill's shape, rather than a third colour invented for
## the occasion. The alternative is a second red pill, which is defensible and is
## what the site does, and it flattens the choice: two accents on one screen give
## the eye nowhere to land.
##
## The hairline is not decoration. A dark shape over a lit garage with no lit
## edge is a hole cut in the room rather than a button sitting on it — the same
## failure [method card] exists for, and the same fix.
static func quiet_pill(fill: Color, height: float) -> StyleBoxFlat:
	var box: StyleBoxFlat = pill(fill, height)
	box.set_border_width_all(1)
	box.border_color = LINE
	return box


## A round plate in [param fill], [param side] design pixels across: what a
## picture is printed on when the picture is the whole control.
##
## [b]It is a quiet pill, and that is not a shortcut.[/b] [method pill] sets every
## corner to half the height, so asking for one at a square size gives a circle
## by the same arithmetic that gives the Start button its round ends — one shape
## in this file, two aspect ratios — and the hairline a badge needs is the one
## [method quiet_pill] already puts there, for the same reason. A separate
## "circle" builder would be a second definition of the same corner, free to
## drift; a separate hairline would be a second definition of the same edge.
static func badge(fill: Color, side: float) -> StyleBoxFlat:
	return quiet_pill(fill, side)


## The same plate for the badge the player has [i]already[/i] picked: [method
## badge] with [method focus_ring]'s hairline around it, in full [constant WHITE].
##
## [b]A second channel, because the first one is colour.[/b] The equipped badge
## is a red plate, and red against dark is a colour difference and nothing else —
## which is the channel that fails in sunlight, at a glance, and for roughly one
## man in twelve, and is exactly the failure the badges themselves stopped relying
## on. A ring survives all three: greyscale the screen and the equipped badge is
## still the only one with a bright edge drawn round it.
##
## [constant FOCUS_RING_WIDTH] and the ring's own geometry rather than a new
## number, for [method badge]'s reason — a second definition of the same edge is
## free to drift from the first. Full [constant WHITE] rather than
## [constant FOCUS_RING_ALPHA] because this one is not marking where the keyboard
## is, it is marking what you are holding, and a keyboard focused on some other
## badge still has to be able to say so over the top of it.
static func picked_badge(fill: Color, side: float) -> StyleBoxFlat:
	var box: StyleBoxFlat = badge(fill, side)
	box.set_border_width_all(FOCUS_RING_WIDTH)
	box.border_color = WHITE
	return box


## [param albedo] as it should be [i]drawn on a badge[/i]: the tool's own colour,
## lightened only as far as it takes to clear [constant BADGE_CONTRAST] against
## the plate it is being drawn on — [constant PANEL] unless [param against] says
## otherwise.
##
## [b]The plate is a parameter because there are two of them.[/b] Four badges sit
## on [constant PANEL] and the one in the player's hands sits on [constant RED],
## which is the brighter of the two by a factor of twenty-six — so a tint that
## clears the floor on the dark plate can be well under it on the red one, and the
## belt used to dodge that by drawing the equipped tool as a flat white
## silhouette. A multi-tone sprite cannot go all-white without throwing away the
## readability it exists for, so the lift is asked the same question against
## whichever plate is actually behind it instead.
##
## [b]The distinction this function exists to make.[/b] A tool's albedo is what
## it is made of — the near-black plastic of a bottle, which is correct in a lit
## garage where light falls on it. A badge is flat, unlit and small, so the same
## number that reads as "black plastic" in the player's hands reads as nothing at
## all on a plate. This lifts the second without touching the first: the mesh
## still uses [member DetailingTool.albedo], and the two cannot drift apart
## because the tint is derived from it rather than written down beside it.
##
## A no-op for a colour that already clears the floor — three of the five tools —
## because lightening a silver wand that is already 11:1 would be inventing a
## colour the tool does not have, in the name of a problem it does not have.
static func badge_tint(albedo: Color, against: Color = PANEL) -> Color:
	var tint: Color = albedo
	for step: int in TINT_STEPS:
		if contrast_ratio(tint, against) >= BADGE_CONTRAST:
			return tint
		tint = albedo.lightened(float(step + 1) / float(TINT_STEPS))
	# The last step above is `lightened(1.0)`, which is white: 15:1 on the panel
	# and 4.8:1 on the red one, so this line is reached only by a plate no colour
	# in this palette could be seen on, and returning white is the closest to
	# satisfying it there is.
	return tint


## How far apart [param first] and [param second] are to a pair of eyes, on the
## [url=https://www.w3.org/TR/WCAG21/#dfn-contrast-ratio]WCAG 2.1[/url] scale:
## 1.0 for the same colour, 21.0 for black against white.
##
## Symmetric, because the definition is — the lighter of the two goes on top of
## the fraction whichever order it arrived in. Alpha is ignored: a ratio is
## between two things that are actually on screen, and a translucent colour is
## not one of them until it has been composited, which is the caller's job and
## not this function's.
static func contrast_ratio(first: Color, second: Color) -> float:
	var one: float = _relative_luminance(first)
	var other: float = _relative_luminance(second)
	return (maxf(one, other) + LUMA_FLOOR) / (minf(one, other) + LUMA_FLOOR)


## [param colour]'s relative luminance: its three channels taken back to linear
## light and weighted the way an eye weights them, which is why green counts for
## seven times what blue does.
static func _relative_luminance(colour: Color) -> float:
	return (
		LUMA_RED * _to_linear(colour.r)
		+ LUMA_GREEN * _to_linear(colour.g)
		+ LUMA_BLUE * _to_linear(colour.b)
	)


## One sRGB [param channel] as linear light. A straight line below the knee and a
## power curve above it — the piecewise definition, not the [code]^2.2[/code]
## approximation, because the whole point of the numbers this feeds is that they
## can be checked against a contrast checker somebody else wrote.
static func _to_linear(channel: float) -> float:
	if channel <= SRGB_KNEE:
		return channel / SRGB_SLOPE
	return pow((channel + SRGB_OFFSET) / SRGB_SCALE, SRGB_GAMMA)
