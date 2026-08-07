## How many pixels one face of a panel's grime atlas gets, worked out from the
## panel's own box rather than handed out flat.
##
## [b]The problem a single number cannot solve.[/b] [code]tile_pixels[/code] used
## to be one constant for every panel because every panel on the CSG blockout was
## roughly the same size — a door, a wing, a wheel. [MeshCar] breaks that: its
## seven parts run from a wheel a third of a metre across to a [code]Body[/code]
## that is the whole car, and the same [code]64[/code] stretched over both makes
## the wheel finer than it needs to be and the body coarser than the water jet —
## roughly doubling the effective texel size on the panel a player looks at most.
## Sizing each map off its own box fixes the body without touching the wheel.
##
## [b]The biggest axis decides it, not the volume or the diagonal.[/b] A panel's
## atlas is a single square tile stamped six times ([BoxProjection]'s class docs
## have the layout), so one number governs every face regardless of which two
## axes that face is measured along. The longest axis of the box is the one a
## face can actually be as large as — the flank of a [code]Body[/code] is
## measured along its length and its height, and the length is what a fixed
## texel-per-metre target has to keep pace with. Taking the diagonal or the
## volume would let a long, thin panel (the body) buy a lower number than a
## short, wide one of the same footprint by hiding its worst axis in an average.
##
## [b]Clamped at both ends, and the floor matters more than the ceiling.[/b] A
## texel density applied without a floor would make the wheels — well under a
## metre across — coarser than the [code]64[/code] every panel shipped at before,
## which is the "global bump that also inflates four wheel maps" this class
## exists to avoid doing in the other direction: [constant MIN_TILE_PIXELS] is
## exactly the old flat number, so a panel already fine enough never gets worse.
## The ceiling is memory: an uncapped body scaled to a seven-metre limousine
## would spend pixels a player will never resolve at arm's length, and
## [constant MAX_TILE_PIXELS] is where that stops paying off — see [method
## tile_pixels_for] for the numbers.
class_name PanelResolution
extends RefCounted

## Pixels of atlas per metre of a panel's longest axis. [b]32[/b] because it
## reproduces [code]grime.gd[/code]'s own arithmetic for the panel that number
## was originally tuned against: a roughly two-metre CSG door at
## [code]tile_pixels = 64[/code] is 64 / 2 = 32 px/m, "about 3 cm a texel" in that
## file's words. Carrying the same density forward means a [MeshCar] body four
## and change metres long lands on a texel about as fine as the blockout's door
## always was, rather than a new number chosen by feel.
const TEXELS_PER_METRE: float = 32.0

## The floor: never coarser than the blockout's own flat [code]64[/code],
## whatever [constant TEXELS_PER_METRE] would otherwise hand a small panel. A
## wheel a third of a metre across computes to about 21 px here — visibly
## blockier than the blockout's wheel had it not been floored, for no reason
## connected to the body panel this class was written for. This is also what
## keeps a degenerate box (a panel with a near-zero extent) from rounding to a
## handful of pixels: the clamp catches it the same way it catches a wheel.
const MIN_TILE_PIXELS: int = 64

## The ceiling: [constant TEXELS_PER_METRE] times this many metres is where
## returns stop being worth the pixels. At [b]128[/b] a panel's atlas is
## [code]3 * 128 = 384[/code] pixels across by [code]2 * 128 = 256[/code] down,
## RGBA8 — 384 KB, and that is one panel's whole budget regardless of how long
## the car gets: the longest style in the pack (the pickup, a shade over five
## metres) would otherwise ask for a body approaching 170 px a tile. See the
## class docs on [Grime] for what a whole car's seven panels add up to under
## this ceiling.
const MAX_TILE_PIXELS: int = 128


## The tile resolution for a panel whose box is [param panel_box], in the same
## units [constant TEXELS_PER_METRE] is quoted in.
##
## Pure arithmetic on a box and nothing else — no node, no scene, which is what
## lets [code]tests/unit/test_panel_resolution.gd[/code] hold the sizing rule
## down to the pixel without building a car to get one.
static func tile_pixels_for(panel_box: AABB) -> int:
	var longest: float = maxf(panel_box.size.x, maxf(panel_box.size.y, panel_box.size.z))
	var raw: int = roundi(longest * TEXELS_PER_METRE)
	return clampi(raw, MIN_TILE_PIXELS, MAX_TILE_PIXELS)
