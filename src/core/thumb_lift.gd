## How far above the finger the aim lands, so the thumb making it is
## not the thing hiding it.
##
## Touch aiming shipped pointing exactly at the contact point, which is correct
## and unusable: on a phone the one part of the picture the player cannot see is
## the part directly under the thumb, and that is precisely where the mark was
## being drawn. The fix is not a different mark, it is a different question — the
## finger says *where*, and the aim is taken a thumb's width up the glass from
## it, so the player is pointing at something they can watch.
##
## [b]The lift is applied to the aim and not to the drawing.[/b] One point goes
## into [method Garage.aim_at] and everything downstream — the ray, the panel it
## names, the mark, the swing of the tool in the player's hands — comes off
## that one point. Moving only the drawing would be the cheaper edit and it
## would leave the wand pointed at the thumb while the mark sat somewhere else,
## which reads as a rendering bug rather than as an offset.
##
## [b]Straight up, and the sideways version is a trap.[/b] A thumb's body runs
## from the contact patch back toward whichever bottom corner of the phone the
## hand came from, so the ideal lift is up and away from that corner — up-left
## for a right thumb, up-right for a left one. Nothing in this game can observe
## which hand is aiming: either thumb aims on a phone held in two hands, and
## both hands reach both halves of the screen. Guessing from the touch's
## own x is worse than not guessing, because a right thumb stretched across to
## the left of the screen still comes from the bottom right and the guess would
## push the mark further under the hand than no lift at all. Straight up is never
## the best answer for either hand and never the wrong one for either, which is
## the right trade when the input is unknowable.
##
## [b]It is a physical distance, not a pixel count.[/b] A thumb is the same size
## on a phone and on a tablet, so the lift has to be too, and the number below is
## therefore in reference pixels — the same unit [TouchTarget] works in, for the
## same reason. [method design_lift] is what turns it into the design pixels this
## game's controls are laid out in.
##
## [b]A mouse gets no lift[/b], and that is the caller's decision rather than
## this class's — see [code]src/screens/play_screen.gd[/code]. A cursor is drawn
## by the compositor and occludes a few pixels of arrow; a hand occludes a
## thumb's worth of screen. Lifting a mouse aim would move the mark away
## from a pointer that was already showing the player exactly where they were
## aiming.
##
## Node-free and static throughout, so the whole thing is a unit test — same tier
## rule as [NearestPoint] and [ToolAim]: STANDARDS.md "Coverage" (R3).
class_name ThumbLift
extends RefCounted

## How far above the contact point the aim is taken, in reference pixels — the
## unit a phone reports its screen in, as [TouchTarget] spells out at length.
##
## Eighty of them is about 21 mm, which is a thumb's width. The contact patch is
## roughly 10 mm across and [constant TouchTarget.MIN_REFERENCE_PX] is sized for
## it, so half of that clears the middle of the thumb and the rest of the budget
## is fingertip, nail, and enough daylight that the ring is sitting on visible
## paint rather than grazing the hand.
##
## The failure modes are asymmetric, which is why the number leans generous.
## Too short and the mark is intermittently visible — worse than no lift, because
## the player learns to trust it and then cannot. Too long and the mark is
## plainly readable but reads as a separate thing rather than as the end of the
## player's own gesture; two thumb-widths is roughly where that starts, and this
## is one.
const REFERENCE_PX: float = 80.0

## Over how many multiples of the lift it eases off at the top of the glass, in
## [method raised].
##
## Two, because two is what makes the ease meet the straight translation smoothly
## — see that function. It is a constant rather than a tunable for the same
## reason: any other value puts a kink in the mapping.
const EASE_SPAN: float = 2.0

## The smallest screen scale worth believing. [method DisplayServer.screen_get_scale]
## answers 1.0 on every platform that has no notion of a device pixel ratio, and
## a browser zoomed out can report less than one — in which case the honest
## reading is "no hidpi", not "shrink the player's thumb".
const MIN_SCREEN_SCALE: float = 1.0


## [constant REFERENCE_PX], in the design pixels a [Control] is laid out in.
##
## Two engine numbers and one division, and both numbers are needed:
##
## [param stretch] is window pixels per design pixel — the scale the
## [code]canvas_items[/code] stretch mode is currently applying, which is
## [method Viewport.get_final_transform]'s scale. Design pixels are what a touch
## arrives in, so this is most of the conversion. Read rather than derived from
## the window's width, because [code]window/stretch/aspect[/code] is
## [code]expand[/code]: a portrait phone is scaled by its width and a landscape
## one by its height, and a conversion that assumed width would be wrong by the
## aspect ratio in exactly the orientation people play games in.
##
## [param screen_scale] is window pixels per reference pixel —
## [method DisplayServer.screen_get_scale]. This is the part that is easy to
## leave out and impossible to notice: on the web build, which is how this game
## is actually played, Godot sizes its canvas in device pixels, so a phone
## reporting a 411 px wide screen has a 1069 px wide window and a lift computed
## without this would be two and a half times too short. It answers 1.0 on a
## desktop, where window pixels already are reference pixels, so the same
## arithmetic is correct in both places rather than special-cased for one.
##
## A stretch of zero or less cannot happen in a running game and would divide by
## zero if it did, so it falls back to the raw reference number: wrong on a
## hidpi phone, harmless everywhere, and never a crash.
static func design_lift(stretch: float, screen_scale: float) -> float:
	if stretch <= 0.0:
		return REFERENCE_PX
	return REFERENCE_PX * maxf(screen_scale, MIN_SCREEN_SCALE) / stretch


## Where a touch at [param touch] is actually aiming, given a [param lift] in the
## same design pixels the touch is in.
##
## Only the vertical moves. See the class docs on why there is no sideways
## component.
static func aim_from(touch: Vector2, lift: float) -> Vector2:
	return Vector2(touch.x, raised(touch.y, lift))


## [param y] on the glass, moved [param lift] up it — except near the top, where
## the lift eases off instead of piling up against the edge.
##
## [b]Why the ease, rather than a clamp at zero.[/b] The obvious version is
## [code]maxf(y - lift, 0.0)[/code], and it has a bug the player feels
## immediately: every touch in the top strip aims at the same place, so a thumb
## dragged up there keeps moving while the mark sits still. Aiming that
## stops responding is a worse failure than aiming that responds slowly, and it
## happens in the one part of the screen a player probes at when they are trying
## to understand what the offset even is.
##
## So the mapping stays strictly increasing all the way to the top: above
## [constant EASE_SPAN] lifts it is a straight translation, and below that it is
## the parabola [code]y² / (2 · join)[/code] through the origin that meets the
## translation at [code]join = EASE_SPAN · lift[/code] with the same value
## [i]and[/i] the same slope. At the join both branches give [code]lift[/code] and
## both have slope 1, so there is no visible seam; at the very top edge the lift
## has faded to nothing and the mark meets the thumb, which is the only honest
## thing it can do when there is no screen left above it.
##
## Two is [constant EASE_SPAN] and not a free parameter: a parabola through the
## origin matching value and slope at its join is only smooth when the join sits
## at twice the offset. Any other span buys a kink.
##
## A lift of zero or less is the identity, so a caller that has decided not to
## lift can go through the same path as one that has.
static func raised(y: float, lift: float) -> float:
	if lift <= 0.0:
		return y
	var above: float = maxf(y, 0.0)
	var join: float = EASE_SPAN * lift
	if above >= join:
		return above - lift
	return above * above / (2.0 * join)
