## The movement half of the HUD: four hold-to-move arrows down the right-hand
## edge, opposite the tool belt's [b]T[/b].
##
## Up and down ride at the top of the screen and raise and lower the eye; left
## and right sit at the bottom and walk you around the car. Hold one to move,
## let go to stop. That is the whole scheme, and it is deliberately not a
## first-person control scheme: the game is played through a browser on a phone,
## where there is no mouse to capture and no second thumb going spare, so
## movement is buttons rather than a look-stick.
##
## [b]This pad is a state, not an event, and that is why it has no signal.[/b]
## The tool belt's roll-up emits [signal ToolBeltHud.tool_selected] because
## picking a tool happens at an instant. Holding a button does not happen at an
## instant — it is a thing that is true across frames — so this exposes
## [method turn] and [method lift] and lets the screen read them each frame.
##
## [b]The state is read off the buttons rather than mirrored into flags[/b], and
## that is the part worth keeping. The obvious shape is a bool per arrow kept up
## to date by [signal BaseButton.button_down] and [signal BaseButton.button_up],
## and its failure mode is a release that never arrives — a finger that leaves
## the glass while the browser tab is being switched away from — leaving a flag
## stuck on and the camera walking forever with nothing touching the screen.
## There is no flag to get stuck here: [member BaseButton.button_pressed] is the
## engine's own answer, asked at the moment it is wanted.
##
## [b]The root ignores the mouse[/b], exactly like [ToolBeltHud] and for the same
## reason: this scene is full-rect and sits above the garage's
## [SubViewportContainer], so a root that stopped input would swallow every tap
## on the screen — including the ones meant for the belt in the far corner. Only
## the four buttons are pickable.
class_name MotionPad
extends Control

## Walk left around the car. The vector is [code](turn, lift)[/code], the same
## pair [method turn] and [method lift] return, so a button's direction is
## literally the input it contributes rather than a code that has to be looked
## up somewhere else.
const LEFT: Vector2i = Vector2i(-1, 0)

## Walk right around the car.
const RIGHT: Vector2i = Vector2i(1, 0)

## Raise the eye.
const UP: Vector2i = Vector2i(0, 1)

## Lower the eye.
const DOWN: Vector2i = Vector2i(0, -1)

## Distance from the screen edge to the pad, in design pixels. The belt's
## [constant ToolBeltHud.MARGIN], because they are the same HUD and a control
## that sat a different distance from its own edge would read as misaligned.
const MARGIN: float = 12.0

## Space between two neighbouring targets, in design pixels. Same number and
## same reason as [constant ToolBeltHud.GAP] — two tap targets flush against each
## other turn a slightly-off tap into the opposite direction, and the opposite
## direction is a worse failure than nothing at all.
const GAP: float = 10.0

var _left: ArrowButton = null
var _right: ArrowButton = null
var _up: ArrowButton = null
var _down: ArrowButton = null


func _ready() -> void:
	_left = _build(LEFT)
	_right = _build(RIGHT)
	_up = _build(UP)
	_down = _build(DOWN)
	# The pad is anchored full-rect but laid out by hand (see [method _relayout]),
	# so it has to be told when the screen changed shape. `resized` fires on the
	# root because the scene is full-rect, which makes it the same event.
	resized.connect(_relayout)
	_relayout()


## Which way the player is asking to walk: [code]-1[/code] left, [code]+1[/code]
## right, and [code]0[/code] for nothing held — or for both held, which cancels
## rather than picking a winner.
func turn() -> float:
	return _axis(_right, _left)


## Which way the player is asking to move their eye: [code]+1[/code] up,
## [code]-1[/code] down, [code]0[/code] for neither or both.
func lift() -> float:
	return _axis(_up, _down)


## The button that contributes [param direction], or [code]null[/code] if that
## is not one of the four. For tests, and for anything that wants to point the
## player at a control rather than describe it.
func button_for(direction: Vector2i) -> Button:
	match direction:
		LEFT:
			return _left
		RIGHT:
			return _right
		UP:
			return _up
		DOWN:
			return _down
	return null


## One axis, as the difference of the two buttons that drive it. Held together
## they cancel, which is the honest answer to being asked for both at once and
## costs nothing to arrange.
func _axis(positive: ArrowButton, negative: ArrowButton) -> float:
	if positive == null or negative == null:
		return 0.0
	return float(positive.button_pressed) - float(negative.button_pressed)


## Makes one arrow and hangs it off this pad. Built here rather than written out
## as four nodes in the scene file because the direction is the only thing that
## differs between them, and it is the thing the button draws itself from — four
## copies in a [code].tscn[/code] would be four chances for a triangle to point
## somewhere its button does not move.
func _build(direction: Vector2i) -> ArrowButton:
	var button: ArrowButton = ArrowButton.new()
	button.point(direction)
	add_child(button)
	return button


## Puts the four arrows where the design says: up and down stacked in the
## top-right corner, left and right side by side in the bottom-right one.
##
## [b]The corner they are all in is the one the tool belt is not.[/b] The belt
## rolls up out of the bottom-left and wraps rightward as far as x = 350 design
## px; the nearest control here starts at 930. A phone is held in two hands and
## the thumbs land in the bottom corners, which is why the two things a player
## does constantly — change tool, walk — are one in each.
##
## Every one of these clears [method TouchTarget.min_design_size] on both axes,
## which is 164 design px today and is not negotiable — see [TouchTarget] for the
## Start button that taught this project the number. Four of them fit down one
## edge with room to spare: 350 px of stacked arrows at the top of a 720 px
## design, 176 at the bottom.
func _relayout() -> void:
	# Rounded up for the reason [method ToolBeltHud._relayout] records: [Vector2]
	# is float32 and the minimum is a float64, so asking for 163.84 gets a control
	# that measures 163.839996 and is honestly below the minimum.
	var slot: float = ceilf(TouchTarget.min_design_size())
	var square: Vector2 = Vector2(slot, slot)
	var step: float = slot + GAP
	var edge: float = size.x - MARGIN - slot
	var floor_row: float = size.y - MARGIN - slot
	_place(_up, square, Vector2(edge, MARGIN))
	_place(_down, square, Vector2(edge, MARGIN + step))
	_place(_left, square, Vector2(edge - step, floor_row))
	_place(_right, square, Vector2(edge, floor_row))


func _place(button: ArrowButton, square: Vector2, where: Vector2) -> void:
	if button == null:
		return
	button.custom_minimum_size = square
	button.size = square
	button.position = where


## One arrow: a triangle pointing the way its button moves you.
##
## [b]A drawn triangle and not a glyph.[/b] The belt's toggle is the letter
## [b]T[/b] precisely because a letter the font already has cannot go missing,
## and the same argument rules out [code]▲[/code] here — the arrow glyphs live in
## a Unicode block the default theme font is not guaranteed to carry, and a
## missing glyph on a movement button is a control that does not say what it
## does. Drawing it is four lines and cannot fail.
##
## A [Button] rather than a [Control] with [method Control._gui_input], for the
## same reason [ToolBeltHud.ToolIcon] is one: what makes a tap work on a phone is
## the engine turning it into a click and [BaseButton] handling that.
class ArrowButton:
	extends Button

	## How far in from the button's edge the triangle is drawn, as a fraction of
	## the smaller side. The tap target is the whole button; the picture inside it
	## is smaller on purpose, because the target is sized for a fingertip and a
	## 164 px triangle is a wall rather than an arrow.
	const INSET: float = 0.3

	## How far back from the middle the arrow's base sits, as a fraction of its
	## half-height. Less than 1 so the triangle reads as a stubby arrowhead rather
	## than as a thin spike.
	const BACK: float = 0.75

	## Half the arrow's base, same units. Under 1 so the head is taller than it is
	## wide and the direction is unmistakable at a glance.
	const SPREAD: float = 0.8

	## The arrow's colour. Deliberately not one of the tool colours — this says
	## "move", and nothing on the belt should look like it.
	const COLOR: Color = Color(0.88, 0.9, 0.94, 1.0)

	var _direction: Vector2i = Vector2i.ZERO

	## Tells this arrow which way it points. Separate from [method Object._init]
	## because [Button] has its own and a subclass that replaces it has to keep
	## calling it.
	func point(way: Vector2i) -> void:
		_direction = way
		queue_redraw()

	## The input this arrow contributes — and, through [method corners], the way
	## the triangle points. One source for both, so a button cannot be drawn
	## pointing one way and move the camera the other.
	func direction() -> Vector2i:
		return _direction

	## The three corners of the triangle, in this button's own space, tip first.
	##
	## Public because it is what the test asserts on: that the drawn tip really is
	## the corner furthest along the direction this button moves you. Asserting on
	## the geometry the drawing code uses, rather than on the flag that is supposed
	## to produce it, is the difference between pinning the behaviour and pinning
	## the bookkeeping — the same argument as
	## [method ToolBeltHud.ToolIcon.fill_color].
	func corners() -> PackedVector2Array:
		var side: float = minf(size.x, size.y)
		var box: Rect2 = Rect2(Vector2.ZERO, size).grow(-side * INSET)
		var reach: float = minf(box.size.x, box.size.y) * 0.5
		var middle: Vector2 = box.get_center()
		# Y is flipped on the way in: `_direction` is in input space, where up is
		# +1, and this is screen space, where up is -Y.
		var facing: Vector2 = Vector2(float(_direction.x), -float(_direction.y))
		var across: Vector2 = Vector2(-facing.y, facing.x)
		var base: Vector2 = middle - facing * reach * BACK
		return PackedVector2Array(
			[
				middle + facing * reach,
				base + across * reach * SPREAD,
				base - across * reach * SPREAD,
			]
		)

	func _draw() -> void:
		if _direction == Vector2i.ZERO:
			return
		draw_colored_polygon(corners(), COLOR)
