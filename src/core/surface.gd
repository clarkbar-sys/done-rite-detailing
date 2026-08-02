## What a panel of the car is made of, and which of the three cleaners is the one
## for it.
##
## The car is paint, glass and rubber, and a detailer does not reach for the same
## bottle for all three. That is the whole rule this class holds: a [Kind] per
## panel, and exactly one [DetailingTool] that treats it.
##
## [b]One direction, not a table.[/b] The obvious shape is a map from tool to the
## surfaces it works on, which is also the shape that lets two tools claim the
## same surface and lets one claim none. [method cleaner_for] goes the other way —
## a surface names its cleaner — so every kind has exactly one and no kind can be
## missed. A caller asking "may I use this here" compares the two ids, which is
## the same question with no second table to keep in step.
##
## [b]The power wash and the drying rag are deliberately absent.[/b] They are not
## surface-specific: water takes mud off anything and a cloth buffs anything, and
## the layered job in [GrimeMap] is what stops either of them being usable out of
## order. Only the middle step cares what it is standing on, so only the middle
## step is here.
##
## Node-free, so which bottle goes with which panel is a unit test rather than a
## thing somebody checks by playing — the R3 tier from STANDARDS.md "Coverage".
## Which panel is which [i]kind[/i] is not decided here: that is a group on the
## node, read by [method Car.kind_of], because the geometry is the car's business
## and a list of panel names written down in [code]src/core/[/code] would go stale
## the first time somebody added a window.
class_name Surface
extends RefCounted

## What a panel is made of.
##
## Three and not twelve: the split is by what you clean it [i]with[/i], not by
## what a parts catalogue would call it. A bonnet, a roof and a door are one kind
## because one sponge does all three.
enum Kind {
	## Paint. The default, and everything the other two do not claim.
	BODY,
	## Glass — the windscreen, the backlight and the side windows.
	GLASS,
	## Rubber and the rim inside it.
	WHEEL,
}

## The group that marks a panel as glass in [code]src/world/car.tscn[/code].
const GLASS_GROUP: String = "glass"

## The group that marks a panel as a wheel.
##
## There is no body group, on purpose: paint is what a panel is when nobody has
## said otherwise, so adding a panel to the car gets the right answer by default
## and only the two special cases have to be remembered.
const WHEEL_GROUP: String = "wheel"

## Suds. White, because that is what soap looks like and because it reads against
## all sixteen of [constant Car.PAINT_COLORS] — including Alpine White, which it
## survives because the foam is patterned and lit and the paint under it is flat.
const BODY_PRODUCT: Color = Color(0.94, 0.95, 0.97)

## Glass cleaner, blue, which is what it is in every bottle anybody has bought.
const GLASS_PRODUCT: Color = Color(0.33, 0.70, 0.92)

## Tyre and engine cleaner, green. Not black like the bottle it comes in
## ([method DetailingTool.catalogue] paints that near-black): the product has to
## be visible sitting on a near-black tyre, and a dark film on dark rubber is
## invisible at exactly the moment the player needs to see how much they have
## covered.
const WHEEL_PRODUCT: Color = Color(0.34, 0.72, 0.38)


## The one cleaner that treats [param kind].
##
## Body is the fallback rather than a case of its own, which is the same
## defaulting [constant WHEEL_GROUP] documents: an unrecognised kind gets the
## sponge, and the sponge is the tool for the surface the car is mostly made of.
static func cleaner_for(kind: Kind) -> DetailingTool.Id:
	match kind:
		Kind.GLASS:
			return DetailingTool.Id.WINDOW_CLEANER
		Kind.WHEEL:
			return DetailingTool.Id.TIRE_ENGINE_CLEANER
	return DetailingTool.Id.SPONGE


## What the product for [param kind] looks like sitting on the panel — the colour
## [code]grime.gdshader[/code] draws the green channel in.
##
## Three colours and one channel, which is worth saying plainly because the
## alternative looks necessary and is not: the mask has no room to record
## [i]which[/i] product is on a texel, but it does not need any. A panel's kind
## never changes, so the colour is a uniform set once when [method Grime.lay_on]
## builds the overlay, and the channel only has to carry how much.
static func product_colour(kind: Kind) -> Color:
	match kind:
		Kind.GLASS:
			return GLASS_PRODUCT
		Kind.WHEEL:
			return WHEEL_PRODUCT
	return BODY_PRODUCT
