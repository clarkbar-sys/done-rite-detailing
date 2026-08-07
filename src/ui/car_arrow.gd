## One of the two arrows either side of the menu: the way through the ten cars
## in the pack.
##
## [b]Why it is a script at all, when a [Button] with a caption would do.[/b]
## Because the caption would be a tofu box. This project ships no font of its
## own, so every label is drawn in Godot's built-in Open Sans — and
## [code]tests/integration/test_main_menu.gd[/code] already gates the credit
## line's curly quotes against exactly that, because a glyph the font does not
## have is a blank rectangle in a released build rather than an error anybody
## would see. "◀" is a glyph Open Sans has no business having. So the arrow is
## drawn rather than typed, which is the same conclusion [SoundToggle] reached
## about a speaker and [GrimeDebug] about its own corner, and it is drawn with
## [method ToolBeltHud.stroke_glyph] — the same table-of-points-on-a-grid every
## other icon in this game is built from, so a sixth icon does not mean a second
## way of drawing one.
##
## [b]What it does not own is where it sits or what colour it is.[/b] The layout
## is [code]src/screens/main_menu.tscn[/code]'s, like every other control on that
## screen, and the pill comes from [method GameScreen.dress_quiet] — the card's
## colour in the pill's shape, cut round at this button's own size. Quiet and not
## [constant Brand.RED] on purpose: red is the one thing on a screen you are
## meant to press, Play is already wearing it, and an arrow is how you look
## rather than how you go.
##
## [b]And it does not know what a car is.[/b] It reports which way it points and
## nothing else — the menu turns that into a style and the room turns that into a
## model. That is the same seam the motion pad has with the walk, for the same
## reason: two numbers crossing is a control that can be replaced by a swipe, a
## dial or a row of ten without anything on the other side hearing about it.
class_name CarArrow
extends Button

## The arrow, in [constant ToolBeltHud.GLYPH_GRID] units and pointing forwards.
##
## A chevron and not a filled triangle, because [method ToolBeltHud.stroke_glyph]
## strokes polylines — which is what keeps every icon in this game at one weight,
## and what makes this one survive being drawn at a third of its design size on a
## phone. Open at both ends: the two segments meet at the point and nothing closes
## the back of it.
const CHEVRON: PackedVector2Array = [Vector2(9, 4), Vector2(17, 12), Vector2(9, 20)]

## What this arrow is called for a pointer that hovers over it and for a screen
## reader, which is the only place either arrow says anything in words.
const TOOLTIP_BACK: String = "Previous car"
const TOOLTIP_ON: String = "Next car"

## Which way along the list this one goes. Set per instance in
## [code]src/screens/main_menu.tscn[/code]; there are exactly two of them and
## they differ in this and in where they sit.
@export var backwards: bool = false


func _ready() -> void:
	tooltip_text = TOOLTIP_BACK if backwards else TOOLTIP_ON


## Which way this arrow steps through a list — what [method CarChoice.stepped]
## takes, and the whole of what this control has to say.
func step() -> int:
	return -1 if backwards else 1


## The picture for this arrow: a chevron, mirrored for the one that points back.
##
## Static and public for the reason [method SoundToggle.glyph] is: a test can ask
## what the two of them look like without a [SceneTree] to draw either into, and
## "the back arrow is not the forward one" is a claim worth being able to make
## cheaply.
static func glyph(points_back: bool) -> Array[PackedVector2Array]:
	var path: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in CHEVRON:
		path.append(Vector2(ToolBeltHud.GLYPH_GRID - point.x, point.y) if points_back else point)
	var paths: Array[PackedVector2Array] = []
	paths.append(path)
	return paths


func _draw() -> void:
	ToolBeltHud.stroke_glyph(self, glyph(backwards), size, Brand.WHITE)
