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

## `.btn-dark{background:#17171b}`: the site's second button — the one beside the
## red one that is not the thing you are meant to press first.
##
## A literal in the stylesheet rather than a `:root` variable, which is why this
## is the one colour here whose name is a component and not a CSS custom
## property. Three shades off [constant PANEL] and deliberately kept apart from
## it: a dark button that was exactly a card would read as a card, and the whole
## job of the pair is that one of them can be pressed.
const BUTTON_DARK: Color = Color("#17171b")

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


## The site's other button ([code].btn-dark[/code]) at [param height] design
## pixels tall, in [param fill]: the same pill, edged rather than lit.
##
## [b]No glow, and that is the difference the pair is made of.[/b] The red pill
## carries [code]box-shadow:0 12px 30px rgba(226,27,35,.26)[/code] and this one
## carries no shadow at all — on the site, because a dark halo under a dark
## button on a near-black page is not visible, and here because the halo is how
## the eye is told which of two buttons is the one to press. Reusing
## [method pill] with a dark fill would produce exactly that: a second glowing
## pill, in a colour nobody notices is different, competing with Start.
##
## What replaces it is the card's own hairline — [code]border-color:var(--line)[/code]
## on the site, [constant LINE] here — which is what keeps the button off the
## background it is nearly the colour of. Over a lit garage rather than a black
## page that edge is doing more work than it does on the site, which is the
## argument for it being here rather than a border baked into a scene.
static func dark_pill(fill: Color, height: float) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(roundi(height / 2.0))
	box.corner_detail = CORNER_DETAIL
	box.set_border_width_all(1)
	box.border_color = LINE
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
