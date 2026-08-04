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
## goes.[/b] The three tints below are the shader's own flash family so the
## corner and the car agree about what a pass looks like — and the middle one is
## a product colour, which for bodywork is [constant Surface.BODY_PRODUCT], very
## nearly white. Against a white readout the foam flash is invisible: the pass
## that has its own tool, its own sound and its own square on the car would be
## the one pass the score does not appear to notice. Resting a shade down means
## all three read, and the one that reads as "brighter" rather than as "bluer" or
## "warmer" is the one whose product really is white suds.
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

## What a patch coming clean under the jet flashes: [code]grime.gdshader[/code]'s
## own [code]wash_flash_colour[/code], so the corner and the car throw the same
## water.
const WASH_TINT: Color = Color(0.55, 0.90, 1.0)

## What the rag's pass flashes: the shader's [code]buff_flash_colour[/code], and
## the only one of the three that is warm.
const BUFF_TINT: Color = Color(1.0, 0.86, 0.42)

## Point size of the total at the design width.
const TOTAL_FONT: int = 76

## Point size of the multiplier under it.
const RUN_FONT: int = 40

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

@onready var _total_label: Label = %Total
@onready var _run_label: Label = %Multiplier


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
	_paint()
	_relayout()


## Rolls the digits, fades the flash and lifts the pops.
##
## Returns on the frame there is nothing to do, which is most of them: a player
## walking round the car with the trigger up costs one comparison a frame rather
## than a string built and three controls moved. The same early-out
## [method PatchFlash.fade] takes, for the same reason.
func _process(delta: float) -> void:
	if _flying <= 0 and _flash <= 0.0 and is_equal_approx(_shown, float(_total)):
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
	_tint = tint_for(stage)
	_run_label.visible = multiplier > SHOW_RUN_ABOVE
	_run_label.text = "×%d" % multiplier
	_pop(award)
	_paint()


## The colour the score throws for a patch that finished [param stage].
##
## The middle one is asked of [Surface] rather than written here, so the corner
## cannot drift from the paint. It is the bodywork's product and not the panel's
## own, because [signal Grime.patch_finished] carries a panel's name and not its
## [enum Surface.Kind] — and widening that signal to colour one flash in the
## corner of the screen would be a change to the thing the whole game's scoring,
## sound and lighting hang off, to answer a question about glass that the player
## is not looking at while they are cleaning it.
static func tint_for(stage: GrimeMap.Stage) -> Color:
	match stage:
		GrimeMap.Stage.FOAMED:
			return Surface.product_colour(Surface.Kind.BODY)
		GrimeMap.Stage.BUFFED:
			return BUFF_TINT
	return WASH_TINT


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


## Puts the total in the corner, the multiplier under it, and both clear of
## whatever else is already in that corner.
func _relayout() -> void:
	if _total_label == null:
		return
	var width: float = _row_width()
	_total_label.size = Vector2(width, float(TOTAL_FONT) * 1.4)
	_total_label.position = Vector2(_left(), _top())
	_run_label.size = Vector2(width, float(RUN_FONT) * 1.4)
	_run_label.position = Vector2(_left(), _top() + _total_label.size.y)
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


## Where a pop starts from: the bottom of the column, so it rises past the
## multiplier and the total rather than out of them.
func _pop_top() -> float:
	return _top() + float(TOTAL_FONT) * 1.4 + float(RUN_FONT) * 1.4
