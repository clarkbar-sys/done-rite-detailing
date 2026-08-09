## The clock, along the top of the screen: [code]M:SS[/code] counting down, and
## red for the last of it.
##
## [b]A readout and not a clock.[/b] [RunClock] owns every number in here and
## this owns what colour they are — the same split [ScoreHud] makes against
## [Scoring], and what lets a three-minute run be unit-tested without a
## [SceneTree] and the presentation be retuned without touching it. What crosses
## is one float.
##
## [b]A [Label] subclass with no scene of its own[/b], which is the shape
## [SoundToggle] and [CarArrow] already use for a control that is one node. A
## [code].tscn[/code] would be a file holding a single node's properties, and
## every one of those properties is a brand decision that belongs in a script
## next to the reason for it. Where it sits is still the screen's —
## [code]src/screens/play_screen.tscn[/code] anchors it.
##
## [b]It rewrites itself once a second and not once a frame.[/b] The screen hands
## it a float every frame, because that is how a countdown is polled, and fifty-
## nine of every sixty of those say the same thing. Comparing whole seconds first
## is the same early-out [method ScoreHud.done] takes against the same kind of
## caller, and for the same reason: building a string sixty times a second to
## print the number already on screen is the sort of cost nobody ever goes back
## and finds.
##
## [b]Red at [method RunClock.is_warning] rather than at a number written
## here.[/b] "Nearly out of time" is a rule about the run and not about a label,
## so it lives on the clock — see there — and the day the music or the bell wants
## to know, it asks the same question instead of inventing a second threshold.
##
## [b]It cannot be pressed.[/b] [constant Control.MOUSE_FILTER_IGNORE] is set
## explicitly and is load-bearing rather than tidy: [code]src/screens/play_screen.gd[/code]
## reads aims out of [method Control._gui_input], so a readout that stopped a
## press would be a rectangle of the windscreen the player cannot point a tool at.
## The same reason every control in [ScoreHud] is at that filter.
class_name TimeHud
extends Label

## Point size. [constant ScoreHud.TOTAL_FONT] itself, because the clock and the
## score are the two numbers a player checks mid-run and neither is more
## important than the other.
##
## Read from there rather than copied, which it was until #174 moved the score
## from 76 to 56 for the pixel face and left this on the old number — two
## constants that are meant to be equal and are written down twice can disagree,
## and this pair disagreed within one commit of being introduced. It also inherits
## that constant's other property for free: a multiple of
## [constant Brand.TYPE_GRID], which is what [code]0:59[/code] needs to have all
## four of its glyphs the same weight.
const FONT: int = ScoreHud.TOTAL_FONT

## How thick the outline under it is. [constant ScoreHud.OUTLINE], for that
## constant's reason: what is behind the top of this screen is sometimes sky and
## sometimes tarmac, and type with no edge on it disappears into one of them.
const OUTLINE: int = 8

## How dark that outline is — [code]src/screens/main_menu.gd[/code]'s
## [code]SHADOW_ALPHA[/code], the same 0.7 the score's pops wear over the same
## room.
const SHADOW_ALPHA: float = 0.7

## What the clock rests at. [constant Brand.MUTED] like the score's digits: it is
## true all the time rather than for a moment, so it should be readable at a
## glance and never be the thing the eye goes to first.
const RESTING: Color = Brand.MUTED

## What it goes to for the last [constant RunClock.WARNING_SECONDS].
##
## [constant Brand.RED] is the site's one accent and this screen is the one place
## in the game nothing else is wearing it — there is no button on the play screen.
## So the accent is free, and the last thirty seconds of a run is the right thing
## to spend it on.
const WARNING: Color = Brand.RED

## No time has been printed yet. Not a reading [method RunClock.whole_seconds]
## can produce, which is what makes the first call always draw.
const NOTHING_YET: int = -1

## What is currently printed, in whole seconds, or [constant NOTHING_YET] before
## anything has been. Kept so [method show_time] can be called every frame
## without building a string to say what the label already says.
var _shown: int = NOTHING_YET


func _ready() -> void:
	# Explicit rather than left to the Label default — see the class docs on why
	# this one is load-bearing on this screen.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", FONT)
	# The same face the score in the opposite corner wears, for the same reason it
	# is the same size: these are the two numbers of a run, and a clock in the
	# project's default reading face beside a score that is not would read as the
	# one thing on the HUD nobody dressed.
	add_theme_font_override("font", Brand.DISPLAY_FACE)
	add_theme_color_override("font_outline_color", Color(Brand.INK, SHADOW_ALPHA))
	add_theme_constant_override("outline_size", OUTLINE)
	# Drawn full before the first frame, so the clock does not appear a frame
	# after the room does — the same reason the menu sets its labels in `_ready`.
	show_time(RunClock.SECONDS)


## Prints [param seconds] left.
##
## Called every frame from [code]src/screens/play_screen.gd[/code], which is what
## the early-out is for.
func show_time(seconds: float) -> void:
	var whole: int = RunClock.whole_seconds(seconds)
	if whole == _shown:
		return
	_shown = whole
	text = RunClock.spell(seconds)
	add_theme_color_override(
		"font_color", WARNING if seconds <= RunClock.WARNING_SECONDS else RESTING
	)


## What the clock reads, in whole seconds. What a test asserts instead of parsing
## the label back out of [code]M:SS[/code].
func shown() -> int:
	return _shown
