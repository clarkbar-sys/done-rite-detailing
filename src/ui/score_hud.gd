## The score, in the top-right corner: six digits that roll rather than jump, a
## multiplier that appears when there is one, and a [code]+250[/code] that lifts
## off the total and fades every time a patch pays.
##
## [b]It is a readout and not a scorer.[/b] [Scoring] owns every number in here;
## this file owns how long they take to arrive and what colour they are on the
## way. That split is the same one [MotionPad] and [ToolBeltHud] already make
## against [CameraOrbit] and [ToolBelt], and it is what lets the values be
## unit-tested without a [SceneTree] and the presentation be retuned without
## touching them. What crosses is four integers and a [enum GrimeMap.Stage].
##
## [b]The digits roll because a score that snaps is a label.[/b] An award lands
## as one integer, and a readout that simply prints it has told the player the
## answer without ever showing them the sum. Rolling it over
## [constant ROLL_SECONDS] costs nothing, cannot get out of step — the target is
## the real total, so a roll that is interrupted by the next award simply
## retargets — and it is the entire difference between a counter and a score.
##
## Zero-padded to [constant DIGITS] for the same reason, and for a second one
## that is not taste: a right-aligned number that changes width makes every digit
## beside it move, so an unpadded total would shuffle sideways as it crossed each
## power of ten. Padding pins the field.
##
## [b]The flash is the ding, drawn.[/b] Every award tints the total to the colour
## of the pass that paid it and punches it briefly larger, then falls back over
## [constant PatchFlash.SECONDS] — the same constant the square on the car fades
## over, because they are one event shown in two places and a score still lit
## after its patch has gone dark reads as a second thing having happened.
##
## [b]It flashes per patch, not per ding, and those are not the same count.[/b]
## [Chime] drops any bell landing inside [constant Chime.MIN_GAP_MSEC] of the
## last, so a fast sweep of the jet pays five patches and rings three times. The
## rate limit exists because two of the same sound inside 70 ms are heard as one
## distorted sound — that is a fact about ears, and it does not transfer: two
## flashes 40 ms apart are two flashes, and a score that stayed still for the
## patches whose ding was swallowed would be a score that stopped agreeing with
## the money. So the audible tie the feature is for is "a ding always lands on a
## flash", which holds, rather than "every flash has a ding", which cannot.
##
## [b]Why it rests in [constant Brand.MUTED] rather than white, which took two
## goes.[/b] The three tints are the shader's own flash family so the corner and
## the car agree about what a pass looks like — and the middle one is a product
## colour, which for bodywork is [constant Surface.BODY_PRODUCT], very nearly
## white. Against a white readout the foam flash is invisible: the pass that has
## its own tool, its own sound and its own square on the car would be the one
## pass the score does not appear to notice. Resting a shade down means all three
## read, and the one that reads as "brighter" rather than as "bluer" or "warmer"
## is the one whose product really is white suds.
##
## That argument only got stronger when the wash stopped being a constant. It is
## now the car's own paint lit ([method Car.flash_colour], and
## [code]grime.gdshader[/code]'s [code]wash_flash_colour[/code] is the same sum),
## which on Alpine White is another near-white — so two of the three would be
## invisible against a white readout rather than one. Resting at
## [constant Brand.MUTED] is what keeps a pale car's wash a flash.
##
## The punch is the belt-and-braces half of that. Colour alone has to carry the
## whole message on a phone in daylight, through a thumb, over a lit garage; a
## number that jumps a few percent larger does not depend on the display, and it
## is what an arcade cabinet would have done with the same problem.
##
## [b]The corner it is in is shared with the grime board.[/b] [GrimeDebug] puts
## its [b]~[/b] toggle at exactly this corner, and only in a debug build — see
## [method OS.is_debug_build] there. So this drops below a tap target's height
## when that toggle is up and takes the corner back when it is not, which is the
## same dodge [code]src/screens/play_screen.tscn[/code] already documents for the
## panel readout, done live instead of by a number typed into a scene file.
##
## [b]Nothing in here can be pressed.[/b] Every control is at
## [constant Control.MOUSE_FILTER_IGNORE], and that is load-bearing rather than
## tidy: [PlayScreen] reads aims out of [method Control._gui_input], so a HUD
## that stopped a press would be a rectangle of the windscreen the player cannot
## point a tool at. It is also the reason the pops are [Label]s laid out by hand
## rather than a container — a container would still be a control in the way.
class_name ScoreHud
extends Control

## How many digits the total is padded to. Six is a million points, which at
## [constant Scoring.BUFF_POINTS] times [constant Scoring.MAX_MULTIPLIER] is a
## thousand perfect patches — far past anything the car currently holds, so the
## field never has to grow and shuffle the digits beside it.
const DIGITS: int = 6

## How long the digits take to catch up with an award, in seconds. Short enough
## that the number is current by the time the player looks at it, long enough
## that they see it move.
const ROLL_SECONDS: float = 0.25

## How much larger the total is punched on an award, as a fraction of its resting
## size. Small on purpose: this is the corner of the screen, not the middle of
## it, and a readout that doubles is a readout that is now in the way of the sky.
const PUNCH: float = 0.18

## How far a [code]+250[/code] lifts before it is gone, in design pixels.
const POP_RISE: float = 84.0

## How long one lives for, in seconds. Longer than the flash — the flash is the
## event and this is the receipt, and a receipt that vanished with the event
## would be unreadable during a sweep.
const POP_SECONDS: float = 0.75

## How many can be in the air at once before the oldest is taken back.
##
## The same round-robin, and the same reasoning, as [constant Chime.VOICES]: a
## wide jet finishes several patches in a tick, and a pool sized for that shows
## them as several rather than as one. Twice the bell's, because these outlive
## their own event by design — see [constant POP_SECONDS] — so more of them
## overlap than of the sound.
const POPS: int = 8

## What a patch coming clean under the jet flashes before anybody has said what
## the car is painted: [code]grime.gdshader[/code]'s own default for
## [code]wash_flash_colour[/code], which means the same thing there — a flash
## with no car behind it. [method set_paint_colour] is how the corner is told,
## and it is told on [signal Garage.grimed], which is before the first patch can
## possibly have been washed.
const UNPAINTED_TINT: Color = Color.WHITE

## What the rag's pass flashes: the shader's [code]buff_flash_colour[/code], and
## the only one of the three that is warm.
const BUFF_TINT: Color = Color(1.0, 0.86, 0.42)

## Point size of the total at the design width.
const TOTAL_FONT: int = 76

## Point size of the multiplier under it.
const RUN_FONT: int = 40

## Point size of the done percentage under that. Between the multiplier and a
## pop: it is the one number on this HUD that is true all the time rather than
## for a moment, so it should be readable at a glance and never be the thing the
## eye goes to first.
const DONE_FONT: int = 34

## What the done percentage rests at. [constant Brand.MUTED] like the total, and
## for the same reason — it never flashes, so it never needs a colour to fall back
## from.
const DONE_TINT: Color = Brand.MUTED

## Point size of a pop.
const POP_FONT: int = 36

## How thick the outline under every number is. The same treatment the panel
## readout gets and for the same reason: what is behind this corner is sometimes
## sky and sometimes tarmac, and type with no edge on it disappears into one of
## them.
const OUTLINE: int = 8

## A run of one is not a run worth printing — every patch has one, so a
## [code]×1[/code] that is always there is furniture. The multiplier appears at
## the first step above it.
const SHOW_RUN_ABOVE: int = 1

var _total: int = 0
var _shown: float = 0.0
var _roll: float = 0.0
var _flash: float = 0.0
var _tint: Color = Brand.MUTED
var _pops: Array[Label] = []
var _ages: PackedFloat32Array = PackedFloat32Array()
var _next_pop: int = 0
var _flying: int = 0
## The done percentage last printed, as a whole number. Kept so [method done] can
## be called every frame — which is what a number read off a running total has to
## be — without building a string sixty times a second to say the same thing.
var _done: int = 0
## What a wash throws, which is this car's paint lit — see [method
## set_paint_colour]. Held rather than asked for on each award because
## [signal Grime.patch_finished] carries a panel and a stage and no car, and the
## corner has no business reaching across the room to find one mid-sweep.
var _washed: Color = UNPAINTED_TINT

@onready var _total_label: Label = %Total
@onready var _run_label: Label = %Multiplier
@onready var _done_label: Label = %Done


func _ready() -> void:
	# Laid out by hand rather than by anchors, the way every other piece of this
	# HUD is — [method ToolBeltHud._relayout] has the argument. The corner this
	# sits in moves with the grime board's toggle, which is a decision rather than
	# a rectangle, so it has to be recomputed on every resize.
	resized.connect(_relayout)
	for index: int in POPS:
		var pop: Label = Label.new()
		pop.name = "Pop%d" % index
		pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pop.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pop.add_theme_font_size_override("font_size", POP_FONT)
		pop.add_theme_color_override("font_outline_color", Color(Brand.INK, 0.7))
		pop.add_theme_constant_override("outline_size", OUTLINE)
		pop.visible = false
		add_child(pop)
		_pops.append(pop)
	_ages.resize(POPS)
	_total_label.add_theme_font_size_override("font_size", TOTAL_FONT)
	_run_label.add_theme_font_size_override("font_size", RUN_FONT)
	_run_label.visible = false
	_done_label.add_theme_font_size_override("font_size", DONE_FONT)
	_done_label.add_theme_color_override("font_color", DONE_TINT)
	_print_done()
	_paint()
	_relayout()


## Rolls the digits, fades the flash and lifts the pops.
##
## Returns on the frame there is nothing to do, which is most of them: a player
## walking round the car with the trigger up costs one comparison a frame rather
## than a string built and three controls moved. The same early-out
## [method PatchFlash.fade] takes, for the same reason.
##
## [b]The arrival test is exact, and [method is_equal_approx] here was a bug.[/b]
## [method shown] truncates, and that tolerance scales with the number:
## [code]CMP_EPSILON * 1200[/code] is 0.012, so a roll that had reached 1199.99
## read as arrived, the digits stopped, and the readout sat on 1199 for the rest
## of the game. [method move_toward] clamps to its target exactly, so the exact
## comparison is the one that is always eventually true — it just costs the one
## further frame the approximate one was skipping. Measured at 1/60 deltas,
## which is both what the game runs at and what CI's [code]--fixed-fps[/code]
## run pins: a 30-frame trickle to 1200 landed on 1199 before this and 1200
## after. Not caught sooner because a headless test run used to free-wheel at
## thousands of tiny frames a second, where the last step happened to land on
## the target rather than a hundredth short of it.
##
## [b]And the tolerance is bigger than a point above 100,000.[/b] It scales, so
## at 200,000 it is 2.0 — the same bug with no float luck in it at all, where a
## single-point tick was swallowed outright rather than landing a hundredth
## short. That is the case
## [code]tests/integration/test_score_hud.gd[/code] pins deterministically,
## because the 1,200 one above only fails when a frame's delta puts the last step
## in the wrong place.
func _process(delta: float) -> void:
	if _flying <= 0 and _flash <= 0.0 and _shown == float(_total):
		return
	_roll_digits(delta)
	_fade_flash(delta)
	_lift_pops(delta)
	_paint()


## One patch paid [param award], bringing the score to [param reached], on a run
## multiplying by [param multiplier], for a patch that finished [param stage].
##
## Four numbers rather than a [Scoring] handed over, so this file cannot read
## anything it was not told and cannot be tempted to do the arithmetic again —
## the split the class docs open on. The first is [param reached] rather than
## `total` because [method total] is a method on this class, and GDScript treats
## a parameter shadowing one as an error here.
func score(reached: int, award: int, stage: GrimeMap.Stage, multiplier: int) -> void:
	_total = reached
	# The gap is measured now rather than per frame, so an award landing mid-roll
	# retargets and still arrives in [constant ROLL_SECONDS] instead of
	# decelerating forever into a total that keeps moving.
	_roll = maxf(float(_total) - _shown, 1.0) / ROLL_SECONDS
	_flash = 1.0
	_tint = tint_for(stage, _washed)
	_run_label.visible = multiplier > SHOW_RUN_ABOVE
	_run_label.text = "×%d" % multiplier
	_pop(award)
	_paint()


## The score has climbed to [param reached] by work rather than by an event, so
## the digits chase it and nothing else happens.
##
## [b]No flash and no pop, and that is the difference the whole split exists
## for.[/b] Work is continuous — this is called on any frame the trigger is doing
## something, which while a jet is running is every one of them — so a flash here
## would be a readout permanently lit and a pop would be sixty labels a second.
## What the player is being told by a number that will not sit still is exactly
## "this is still going", and it needs no punctuation. The punctuation is
## [method score], for the moments that have some.
##
## The roll is retargeted the same way an award retargets it, so a trickle is
## chased at the rate the gap deserves rather than at a fixed speed: the digits
## run a little behind a fast sweep, catch up within [constant ROLL_SECONDS] of
## it stopping, and never overshoot.
func tick(reached: int) -> void:
	if reached == _total:
		return
	_total = reached
	_roll = maxf(float(_total) - _shown, 1.0) / ROLL_SECONDS


## How much of the car is finished, as [code]0..1[/code] — [method Grime.shine],
## printed as a percentage.
##
## [b]Why this can exist at all is the whole of [code]#144[/code].[/b] Until the
## grime was seeded only where a player can reach, the shine could not pass about
## a half whatever anybody did to the car, because the underside of the shell and
## the air inside every panel's box were seeded with mud nobody could take off. A
## percentage nobody can finish is worse than no percentage, which is why there was
## none here before. [PanelReach] is what made the number honest and this is what
## prints it.
##
## [b]Polled and not signalled[/b], which is the same split the rest of this HUD
## makes: an award is an instant and arrives through [method score], and how clean
## the car is is true across frames, so [code]src/screens/play_screen.gd[/code]
## reads it once a frame exactly as it reads the wage and the walk. Nothing flashes
## and nothing pops — see [method tick], which is the same argument about the same
## kind of number.
##
## [b]Rounded down, and that matters at exactly one value.[/b] A car at 99.6%
## printing "100% done" while the last patch is still muddy is the readout calling
## a job finished that is not, which is the one lie a progress number must not
## tell. Flooring means the hundred arrives with the last unit of shine and not
## before.
func done(fraction: float) -> void:
	var percent: int = clampi(floori(fraction * 100.0), 0, 100)
	if percent == _done:
		return
	_done = percent
	_print_done()


## What the done readout says, as a whole percent. What a test asserts instead of
## reading a label back.
func done_shown() -> int:
	return _done


## The colour the score throws for a patch that finished [param stage] on a car
## whose wash flashes [param washed].
##
## The middle one is asked of [Surface] rather than written here, so the corner
## cannot drift from the paint. It is the bodywork's product and not the panel's
## own, because [signal Grime.patch_finished] carries a panel's name and not its
## [enum Surface.Kind] — and widening that signal to colour one flash in the
## corner of the screen would be a change to the thing the whole game's scoring,
## sound and lighting hang off, to answer a question about glass that the player
## is not looking at while they are cleaning it.
##
## [b]The first one is handed in rather than looked up, which is the same split
## one step further.[/b] A wash now throws the car's own paint rather than a
## constant ([method Car.flash_colour]), and this class does not know a car
## exists — it is a corner of the screen that is told numbers. So the colour
## arrives through [method set_paint_colour] and is passed back in here, which
## keeps this function what it was: the one place that maps a stage onto a
## colour, with nothing to reach for and nothing to remember.
##
## Still static, so a test can ask what a stage throws on a given paint without
## standing a HUD up in a tree.
static func tint_for(stage: GrimeMap.Stage, washed: Color) -> Color:
	match stage:
		GrimeMap.Stage.FOAMED:
			return Surface.product_colour(Surface.Kind.BODY)
		GrimeMap.Stage.BUFFED:
			return BUFF_TINT
	return washed


## The car in the bay is painted [param colour], so a wash flashes what
## [method Car.flash_colour] makes of it — the same sum the overlay on the car
## does, so the corner and the paint throw one colour rather than two that agree
## by hand.
##
## [b]Given the paint rather than the flash[/b], so the caller does not have to
## know there is a sum in the way. The one place that calls this
## ([code]src/screens/play_screen.gd[/code]) has a car and its material; what it
## should not have to hold is this class's idea of what a flash looks like.
func set_paint_colour(colour: Color) -> void:
	_washed = Car.flash_colour(colour)


## What a wash currently throws in the corner. What a test asserts instead of
## reading a colour back off a label mid-fade.
func wash_tint() -> Color:
	return _washed


## What the digits currently read, which during a roll is behind the real total.
## The honest answer to "what does the screen say", for a test that wants the one
## the player can see rather than the one [Scoring] knows.
func shown() -> int:
	return int(_shown)


## The total the digits are rolling towards.
func total() -> int:
	return _total


## How lit the flash is, [code]1..0[/code]. What a test asserts instead of a
## screenshot.
func flash() -> float:
	return _flash


## How many pops are in the air.
func flying() -> int:
	return _flying


## Whether the multiplier is being printed at all.
func run_shown() -> bool:
	return _run_label.visible


## Moves the digits [param delta] worth of the way to the total.
func _roll_digits(delta: float) -> void:
	_shown = move_toward(_shown, float(_total), _roll * delta)


## Dims the flash by [param delta] worth of [constant PatchFlash.SECONDS].
func _fade_flash(delta: float) -> void:
	if _flash <= 0.0:
		return
	_flash = maxf(_flash - delta / PatchFlash.SECONDS, 0.0)


## Lifts every pop in the air by [param delta], retiring the ones that ran out.
func _lift_pops(delta: float) -> void:
	if _flying <= 0:
		return
	for index: int in _pops.size():
		if not _pops[index].visible:
			continue
		_ages[index] += delta
		if _ages[index] >= POP_SECONDS:
			_pops[index].visible = false
			_flying -= 1
			continue
		_place_pop(index)


## Starts a [code]+[param award][/code] rising from the total.
##
## Round-robin over the pool, so a burst past [constant POPS] takes the oldest
## back rather than dropping the newest. The one being reclaimed is the one
## furthest through its own life and therefore the faintest, which is the version
## of "something went missing" nobody can see.
func _pop(award: int) -> void:
	var index: int = _next_pop
	_next_pop = (_next_pop + 1) % _pops.size()
	if not _pops[index].visible:
		_flying += 1
	_pops[index].text = "+%d" % award
	_pops[index].visible = true
	_ages[index] = 0.0
	_place_pop(index)


## Puts pop [param index] where its age says it has got to, and fades it as it
## goes. Squared, so it is fully legible for the first half of its life and then
## leaves quickly — a linear fade spends most of its time at a transparency
## nobody can read and it reads as a smear.
func _place_pop(index: int) -> void:
	var amount: float = clampf(_ages[index] / POP_SECONDS, 0.0, 1.0)
	var pop: Label = _pops[index]
	pop.size = Vector2(_row_width(), float(POP_FONT) * 1.5)
	pop.position = Vector2(_left(), _pop_top() - POP_RISE * amount)
	pop.modulate = Color(_tint, 1.0 - amount * amount)


## Repaints the digits and the multiplier from the current roll and flash.
##
## One function for both, and called from both [method _process] and
## [method score], because the alternative is a frame where the award has landed
## and the screen has not caught up — visible as a pop appearing over a total
## that has not moved.
func _paint() -> void:
	_total_label.text = str(int(_shown)).pad_zeros(DIGITS)
	# Toward the tint rather than set to it, so the colour arrives with the flash
	# and leaves with it. At rest this is exactly [constant Brand.MUTED].
	var lit: Color = Brand.MUTED.lerp(_tint, _flash)
	_total_label.add_theme_color_override("font_color", lit)
	_run_label.add_theme_color_override("font_color", _tint)
	var punched: int = roundi(float(TOTAL_FONT) * (1.0 + PUNCH * _flash))
	_total_label.add_theme_font_size_override("font_size", punched)


## Writes the done percentage out. One place, called from [method _ready] and
## from [method done], so the resting text and the running one cannot drift into
## two different shapes.
func _print_done() -> void:
	_done_label.text = "%d%% done" % _done


## Puts the total in the corner, the multiplier under it, the done percentage
## under that, and all three clear of whatever else is already in that corner.
##
## The rows are stacked by measuring rather than by anchors, and every one of them
## takes its height whether it is visible or not — the multiplier is hidden for
## most of a game, and a done readout that jumped up the screen the first time a
## run of two patches appeared would be worse than one sitting a row lower than it
## has to.
func _relayout() -> void:
	if _total_label == null:
		return
	var width: float = _row_width()
	_total_label.size = Vector2(width, float(TOTAL_FONT) * 1.4)
	_total_label.position = Vector2(_left(), _top())
	_run_label.size = Vector2(width, float(RUN_FONT) * 1.4)
	_run_label.position = Vector2(_left(), _top() + _total_label.size.y)
	_done_label.size = Vector2(width, float(DONE_FONT) * 1.4)
	_done_label.position = Vector2(_left(), _run_label.position.y + _run_label.size.y)
	for index: int in _pops.size():
		_place_pop(index)


## The left edge of every row: the whole width in from the margin, so all three
## labels are one right-aligned column.
func _left() -> float:
	return size.x - ToolBeltHud.MARGIN - _row_width()


## How wide that column is. A third of the screen — enough for six digits at
## [constant TOTAL_FONT] with room to spare, and narrow enough that it cannot
## reach the panel readout on the other side.
func _row_width() -> float:
	return size.x / 3.0


## The top of the total.
##
## [b]Below the grime board's toggle when there is one.[/b] That toggle is in
## this exact corner and is hidden in release builds, so asking whether it is
## there is asking [method OS.is_debug_build] — the same question [GrimeDebug]
## asks to decide whether to show it. Sized off
## [method TouchTarget.min_design_size] rather than off a number written here,
## for the reason [method GrimeDebug._relayout] gives: the two are the same
## target and should move together the day that minimum does.
func _top() -> float:
	if not OS.is_debug_build():
		return ToolBeltHud.MARGIN
	return ToolBeltHud.MARGIN + ceilf(TouchTarget.min_design_size()) + ToolBeltHud.GAP


## Where a pop starts from: the bottom of the column, so it rises past the done
## readout, the multiplier and the total rather than out of them.
func _pop_top() -> float:
	return _top() + (float(TOTAL_FONT) + float(RUN_FONT) + float(DONE_FONT)) * 1.4
