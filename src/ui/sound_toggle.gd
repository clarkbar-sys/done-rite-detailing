## The on/off button for the game's one audio bus: a round plate in the
## screen's free top-left corner, on the title card, the menu and the bay
## alike.
##
## [b]One script, three screens.[/b] The title screen, the menu and the play
## screen each need exactly the same control — the same size, the same plate,
## the same picture, and the same [Sound] it flips — so this is written once
## and the same node dropped into all three [code].tscn[/code] files, rather
## than three copies a change to any one of them could fall out of step with.
##
## [b]The corner is free on every screen it sits on.[/b] [ToolBeltHud] owns the
## bottom-left, and [ScoreHud] shares the top-right with [GrimeDebug]'s own
## toggle. The title card and the menu use neither, and the play screen's
## top-left is the one corner none of its own HUD reaches — see
## [code]src/screens/play_screen.tscn[/code].
##
## [b]The picture is a speaker, not a word.[/b] [GrimeDebug]'s docs already make
## the case against a text glyph for anything meant to read as part of the
## brand: a button that said "Mute" would still say "Mute" after being pressed.
## What is drawn instead is the same picture every OS uses for the idea — a
## speaker with sound coming off it, or without — stroked with
## [method ToolBeltHud.stroke_glyph], the same table-of-points-on-a-grid every
## other icon in the HUD is built from, so a fifth icon does not mean a second
## way of drawing one.
##
## [b]The plate stays [constant Brand.PANEL] in both states, and that is a
## choice.[/b] [ToolBeltHud]'s own corner turns red while its roll-up is out,
## because red is what a thing you have already pressed wears on this site. A
## mute button that turned red while muted would borrow that same colour to
## mean something else — "off" rather than "chosen" — on a screen where Play
## or Start is already red for the first reason. So this corner says what it
## means with the picture alone, the way the toggle beside it already does for
## "closed" versus "the tools are out".
class_name SoundToggle
extends Button

## What the corner is called, for a pointer that hovers and for a screen
## reader. [method _refresh] keeps it in step with which press is on offer.
const TOOLTIP_ON: String = "Mute"
const TOOLTIP_OFF: String = "Unmute"

## Centre of the sound-wave arcs, in [constant ToolBeltHud.GLYPH_GRID] units —
## the tip of the speaker's cone below.
const WAVE_CENTER: Vector2 = Vector2(14.0, 12.0)

## The two radii the sound waves are drawn at when the game is not muted.
const WAVE_RADII: PackedFloat32Array = [3.5, 6.5]

## How wide the waves open, in radians either side of straight ahead.
const WAVE_HALF_ANGLE: float = 0.6

## How many segments each wave is tessellated into — enough that an arc reads
## as a curve rather than a chord at any size this badge is drawn.
const WAVE_SEGMENTS: int = 6


func _ready() -> void:
	var slot: float = ceilf(TouchTarget.min_design_size())
	custom_minimum_size = Vector2(slot, slot)
	size = Vector2(slot, slot)
	position = Vector2(ToolBeltHud.MARGIN, ToolBeltHud.MARGIN)
	pressed.connect(_on_pressed)
	_refresh()
	_dress()


## The picture for this corner: the speaker's outline, plus either the two
## waves or the mark that crosses them out.
##
## Static and public for the reason [method ToolBeltHud.BeltMark.sprite] is: a
## test can ask what the two states look like without a [SceneTree] to draw
## either of them into.
static func glyph(muted: bool) -> Array[PackedVector2Array]:
	var paths: Array[PackedVector2Array] = []
	(
		paths
		. append(
			PackedVector2Array(
				[
					Vector2(3, 9),
					Vector2(8, 9),
					Vector2(14, 4),
					Vector2(14, 20),
					Vector2(8, 15),
					Vector2(3, 15),
					Vector2(3, 9),
				]
			)
		)
	)
	if muted:
		paths.append(PackedVector2Array([Vector2(16, 8), Vector2(22, 14)]))
		paths.append(PackedVector2Array([Vector2(22, 8), Vector2(16, 14)]))
		return paths
	for radius: float in WAVE_RADII:
		paths.append(_wave(radius))
	return paths


## One arc of [param radius] glyph units, opening rightward out of
## [constant WAVE_CENTER].
static func _wave(radius: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for step: int in WAVE_SEGMENTS + 1:
		var amount: float = float(step) / float(WAVE_SEGMENTS)
		var angle: float = -WAVE_HALF_ANGLE + 2.0 * WAVE_HALF_ANGLE * amount
		points.append(WAVE_CENTER + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _draw() -> void:
	ToolBeltHud.stroke_glyph(self, glyph(Sound.muted), size, Brand.WHITE)


## Puts the brand on the corner: a round plate in all four of the states Godot
## will ask for, so hover and pressed do not fall back to the theme's grey —
## the one moment this button is actually being used.
func _dress() -> void:
	var side: float = size.y
	if side <= 0.0:
		return
	add_theme_stylebox_override("normal", Brand.badge(Brand.PANEL, side))
	add_theme_stylebox_override("hover", Brand.badge(Brand.PANEL.lightened(Brand.HOVER_LIFT), side))
	add_theme_stylebox_override("pressed", Brand.badge(Brand.RED_DARK, side))
	add_theme_stylebox_override("focus", Brand.focus_ring(side))


func _on_pressed() -> void:
	Sound.toggle()
	_refresh()


## Keeps the tooltip and the picture in step with [member Sound.muted].
func _refresh() -> void:
	tooltip_text = TOOLTIP_OFF if Sound.muted else TOOLTIP_ON
	queue_redraw()
