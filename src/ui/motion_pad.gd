## The movement half of the HUD: one circle in the bottom-right corner, opposite
## the tool belt's [b]T[/b], with a knob that follows your thumb.
##
## Push the knob left or right to walk around the car, up or down to raise and
## lower your eye, or anywhere in between to do both at once. Let go and it
## springs back to the middle and you stop. That is the whole scheme, and it is
## deliberately not a first-person control scheme: the game is played through a
## browser on a phone, where there is no mouse to capture and no second thumb
## going spare, so movement is a stick under one thumb rather than a look-stick
## plus a walk-stick.
##
## [b]It used to be four arrows, and the circle is the same idea with the corners
## taken off.[/b] Two arrows down the top-right, two along the bottom-right, each
## hold-to-move. They worked, and three things were wrong with them on a phone.
## A tap target is 164 design px, so four of them ate 350 px of a 720 px design
## down one edge. Walking and lifting at once needed two thumbs, and both of them
## are already spoken for — one is on the belt or the car. And an arrow is a
## switch: full speed or nothing, so lining up on the wing was a rhythm of taps
## rather than a movement. The circle is one target instead of four, says both
## axes from one thumb, and says every speed in between. Nothing downstream
## changed to gain that: [OrbitDrive] has always taken two numbers in
## [code]-1..1[/code], and the arrows were simply never able to send it anything
## but the ends of that range.
##
## [b]This pad is a state, not an event, and that is why it has no signal.[/b]
## The tool belt's roll-up emits [signal ToolBeltHud.tool_selected] because
## picking a tool happens at an instant. Holding a direction does not happen at an
## instant — it is a thing that is true across frames — so this exposes
## [method turn] and [method lift] and lets the screen read them each frame.
##
## [b]It reads touches itself rather than living on a [Button], and that is the
## part worth keeping.[/b] What a [Button] gives you for free is the mouse the
## engine emulates from a finger, and the engine only emulates the [i]first[/i]
## one — which is why the arrows could be held while the other hand aimed, but
## could not be grabbed [i]by[/i] the second finger while the first was on the
## car. A stick has to track a finger across the glass anyway, so it tracks it by
## index and any finger can drive it. [code]src/screens/play_screen.gd[/code] has
## the long version of the emulation story; the short version is that this class
## and that one make the same choice for the same reason, and the emulated mouse
## is dropped on sight at both ends.
##
## [b]Input is claimed in [method Node._input], before the GUI sees it.[/b] The
## screen underneath is a [Control] at the default [code]stop[/code] filter and
## turns every press on itself into an aim, so a press meant for the stick has to
## be taken off the table before it gets there — and the viewport checks
## [method Viewport.set_input_as_handled] between the [method Node._input] pass
## and the GUI pass, which makes this the one place that can. Only presses that
## land inside the circle are claimed. Everything else is left alone, which is
## what keeps a tap on the car an aim and a tap on the belt a tool change.
##
## [b]A held stick is a flag, and a flag that never clears is a camera that walks
## forever.[/b] The arrows had no such flag — [member BaseButton.button_pressed]
## was the engine's own answer, asked fresh — and giving that up is the real cost
## of this change, so it is paid for explicitly: a finger that leaves the glass
## while the browser tab is switched away never sends its release, so the pad also
## lets go on losing focus (see [method _notification]). That covers the case the
## arrows were immune to by construction.
##
## The root ignores the mouse, exactly like [ToolBeltHud] and for the same
## reason: this scene is full-rect and sits above the garage's
## [SubViewportContainer], so a root that stopped input would swallow every tap on
## the screen — including the ones meant for the belt in the far corner. It never
## takes part in GUI picking at all.
class_name MotionPad
extends Control

## Walk left around the car. The vector is [code](turn, lift)[/code], the same
## pair [method turn] and [method lift] return, so a direction is literally the
## input it asks for rather than a code that has to be looked up somewhere else.
## The four survive the arrows they used to name: they are still what a caller
## means by "left", and [method point_for] turns one into a place on the glass.
const LEFT: Vector2i = Vector2i(-1, 0)

## Walk right around the car.
const RIGHT: Vector2i = Vector2i(1, 0)

## Raise the eye.
const UP: Vector2i = Vector2i(0, 1)

## Lower the eye.
const DOWN: Vector2i = Vector2i(0, -1)

## The four the ring is marked with, in reading order for the pairs they make:
## the two that walk you round the car, then the two that move your eye.
const DIRECTIONS: Array[Vector2i] = [LEFT, RIGHT, UP, DOWN]

## Distance from the screen edge to the circle, in design pixels. The belt's
## [constant ToolBeltHud.MARGIN], because they are the same HUD and a control that
## sat a different distance from its own edge would read as misaligned.
const MARGIN: float = 12.0

## No finger is on the stick. Not a touch index the engine can ever hand out, so
## it cannot collide with a real one. The same sentinel
## [code]src/screens/play_screen.gd[/code] tracks its aiming finger with, and the
## same reason: the two are the same problem seen from two controls.
const NO_FINGER: int = -1

## The stand-in index for a mouse held down at a desk, so one variable can track
## who is driving whether that is a finger or a pointer. Also not a touch index
## the engine hands out, and distinct from [constant NO_FINGER] — a mouse that
## shared the "nobody" value would be released by the first stray touch.
const MOUSE_FINGER: int = -2

## How far past the ring a thumb may land and still be reaching for the stick, as
## a multiple of the radius.
##
## [b]The target is bigger than the picture[/b], the way a tap target always is.
## The ring is a drawing of where full deflection lives; the thing a finger has to
## hit is the control, and a player reaching for the edge of the stick and landing
## a few pixels outside it should get the stick rather than a mark on the car
## behind it. The slack also keeps the boundary off the one place a caller is most
## likely to aim at — [method point_for] hands out points exactly on the ring, and
## a grab area that ended exactly there would be a coin toss decided by float
## rounding.
const GRAB_SLACK: float = 1.15

## How big the knob is, as a fraction of the circle's radius. Small enough that
## the ring around it stays readable at full deflection, big enough to be a thing
## a thumb is on rather than a dot the thumb is near. The knob is not the tap
## target — the whole circle is — so this is a drawing number and nothing else.
const KNOB_FRACTION: float = 0.4

## How far out the four direction marks sit, as a fraction of the radius, and how
## big they are in the same units.
##
## The marks are the arrows this replaced, shrunk to hints. A bare circle on a
## picture of a garage does not say "this moves you" — the marks do, and they are
## drawn from the same [constant DIRECTIONS] the stick reports, so a mark cannot
## end up pointing somewhere the stick does not go.
const MARK_AT: float = 0.82
const MARK_SIZE: float = 0.13

## How thick a direction mark is drawn, in design pixels.
##
## [b]They are chevrons now, not filled triangles.[/b] The tool belt opposite
## draws five stroked silhouettes, and four solid arrowheads on this side were
## the heaviest marks on the screen — the eye landed on the furniture rather than
## on the tools. An outline says the same direction at a fraction of the weight,
## from the same three points [method mark_corners] already returned.
const MARK_WIDTH: float = 5.0

## How much of the middle the ring is filled with. Low, because this sits on top
## of the room the player is trying to look at: the stick has to be findable
## without being a hole in the picture.
const BASE_ALPHA: float = 0.28
const BASE_COLOR: Color = Color(Brand.INK, BASE_ALPHA)

## The ring itself, and how thick it is drawn in design pixels.
const RIM_ALPHA: float = 0.5
const RIM_COLOR: Color = Color(Brand.MUTED, RIM_ALPHA)
const RIM_WIDTH: float = 4.0

## The knob, and the direction marks. The brand's own greys rather than three
## hand-mixed ones, so the HUD is lit by one palette — [Brand] has the argument
## for why every colour in this game is written down in exactly one file.
const KNOB_ALPHA: float = 0.85
const KNOB_COLOR: Color = Color(Brand.WHITE, KNOB_ALPHA)
const MARK_ALPHA: float = 0.55
const MARK_COLOR: Color = Color(Brand.MUTED, MARK_ALPHA)

## The rim that appears around the knob while a thumb is on it, and how thick it
## is drawn in design pixels.
##
## [b]Red only while held, and that is the whole decision.[/b] On the site red is
## what a thing you are meant to press wears. The stick is not that — it is
## furniture you rest a thumb on, and a red disc sitting in the corner of every
## frame would be the loudest thing on a screen whose actual buttons are in the
## other corner. Held, it is a different sentence: this is the control you are
## driving right now, said in the one colour the rest of the HUD already uses for
## "this one is live".
const HELD_RIM_COLOR: Color = Brand.RED
const HELD_RIM_WIDTH: float = 5.0

## Which finger has the stick, or [constant NO_FINGER] for none.
var _finger: int = NO_FINGER

## Where that finger is, relative to the middle of the circle, in this pad's own
## coordinates. Meaningless while [member _finger] is [constant NO_FINGER], and
## zeroed on release rather than left behind, so a stray read cannot report the
## last direction anybody held.
var _offset: Vector2 = Vector2.ZERO

var _centre: Vector2 = Vector2.ZERO
var _radius: float = 0.0


func _ready() -> void:
	# The pad is anchored full-rect but laid out by hand (see [method _relayout]),
	# so it has to be told when the screen changed shape. `resized` fires on the
	# root because the scene is full-rect, which makes it the same event.
	resized.connect(_relayout)
	_relayout()


## Which way the player is asking to walk: [code]-1[/code] hard left,
## [code]+1[/code] hard right, [code]0[/code] for a thumb that is off the glass or
## resting in the middle of the circle — and every value in between, which is the
## thing four buttons could not say.
func turn() -> float:
	return input().x


## Which way the player is asking to move their eye: [code]+1[/code] up,
## [code]-1[/code] down, [code]0[/code] for neither.
func lift() -> float:
	return input().y


## Both at once, which is how the stick actually thinks about it —
## [code](turn, lift)[/code], never longer than 1.
##
## Computed from where the finger is rather than kept as a field updated on every
## drag event. There is one source of truth for what the stick is doing and it is
## the finger's position; a mirrored pair of numbers is one more thing that can be
## left holding a direction nobody is asking for.
func input() -> Vector2:
	if _finger == NO_FINGER:
		return Vector2.ZERO
	return ThumbStick.input_from(_offset, _radius)


## Whether a finger or a pointer currently has the stick. For the screen's tests,
## and for anything that wants to know the player is walking without caring which
## way.
func is_held() -> bool:
	return _finger != NO_FINGER


## The middle of the circle, in this pad's own coordinates.
func centre() -> Vector2:
	return _centre


## How far from [method centre] full deflection is, in design pixels. The ring
## that is drawn, and the distance a thumb has to travel to ask for everything.
func radius() -> float:
	return _radius


## How far from [method centre] a press still counts as reaching for the stick —
## [constant GRAB_SLACK] more than the ring, for the reason recorded there.
func grab_radius() -> float:
	return _radius * GRAB_SLACK


## Where the knob is drawn, in this pad's own coordinates. Public because it is
## the visible half of the state and therefore the half a test can watch: a stick
## whose knob stopped following the thumb is broken in a way no reading of
## [method turn] would show.
func knob() -> Vector2:
	if _finger == NO_FINGER:
		return _centre
	return _centre + ThumbStick.knob_from(_offset, _radius)


## How thick the red rim around the knob is drawn, or zero when there is not one.
##
## Public for the reason [method mark_corners] is: it is the value [method _draw]
## actually uses, so a test can pin "the stick goes red under a thumb and only
## under a thumb" against the drawing rather than against the flag that is
## supposed to drive it.
func knob_rim_width() -> float:
	return HELD_RIM_WIDTH if is_held() else 0.0


## Where on the glass a thumb has to land to ask, at full strength, to go
## [param direction] — in global coordinates, ready to be handed to a touch.
##
## The replacement for the old [code]button_for()[/code], and the reason it is a
## point rather than a control: there is no longer a node per direction, and a
## caller that wants to press "right" wants a place, not a widget. Diagonals work,
## because on a circle they mean something — [code]Vector2i(1, 1)[/code] is the
## corner that walks and lifts at once, which the four arrows could not express at
## all.
##
## [constant Vector2i.ZERO] is the middle of the circle: no direction, which is
## the honest place to put a finger that is asking for nothing.
func point_for(direction: Vector2i) -> Vector2:
	return get_global_transform_with_canvas() * (_centre + _reach(direction))


## The three corners of the mark for [param direction], in this pad's own
## coordinates, tip first.
##
## Public for the same reason the old arrow's geometry was: it is what the test
## asserts on, that the drawn tip really is the corner furthest along the
## direction it stands for. Asserting on the geometry the drawing code uses,
## rather than on the flag that is supposed to produce it, is the difference
## between pinning the behaviour and pinning the bookkeeping.
func mark_corners(direction: Vector2i) -> PackedVector2Array:
	var facing: Vector2 = _facing(direction)
	if facing == Vector2.ZERO:
		return PackedVector2Array()
	var across: Vector2 = Vector2(-facing.y, facing.x)
	var size_px: float = _radius * MARK_SIZE
	var base: Vector2 = _centre + facing * (_radius * MARK_AT - size_px)
	return PackedVector2Array(
		[
			_centre + facing * (_radius * MARK_AT + size_px),
			base + across * size_px,
			base - across * size_px,
		]
	)


## Every pointer that could be reaching for the stick, claimed or ignored.
##
## [method Node._input] rather than [method Control._gui_input], because the
## screen underneath claims every press the GUI hands it — the class docs have the
## whole of that. Rather than [method Node._unhandled_input] for the same reason:
## by then the press has already become somebody's aim.
##
## Touch first and the mouse after, with the emulated middle case dropped on
## sight: the finger it was invented from has already been handled here, and
## acting on both would move the stick twice for one thumb.
func _input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		_pointer(touch.index, touch.position, touch.pressed)
		return
	var dragged: InputEventScreenDrag = event as InputEventScreenDrag
	if dragged != null:
		_dragged(dragged.index, dragged.position)
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT:
		_pointer(MOUSE_FINGER, click.position, click.pressed)
		return
	var moved: InputEventMouseMotion = event as InputEventMouseMotion
	if moved != null:
		_dragged(MOUSE_FINGER, moved.position)


## The stick lets go when the game stops being the thing in front of the player.
##
## This is the cost of a held flag, paid. A finger on the glass when the browser
## tab is switched away never sends its release, and the pad would otherwise still
## be reporting that direction when the player came back — a camera walking on its
## own, with nothing touching the screen. Both notifications, because the
## application and the window can lose focus separately and either one means the
## thumb is no longer being watched.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_let_go()


## A pointer [param index] going down or coming up at [param at], in viewport
## coordinates.
##
## [b]The first finger inside the circle wins and keeps the stick until it
## lifts.[/b] A second one landing on it is ignored rather than taking over — two
## fingers cannot drive one stick, and the alternative is a camera that snaps
## between them. And a release only counts from the finger that took the stick, so
## lifting the aiming thumb off the car cannot stop the walk.
func _pointer(index: int, at: Vector2, pressed: bool) -> void:
	if not pressed:
		if index != _finger:
			return
		_let_go()
		_claim()
		return
	if _finger != NO_FINGER:
		return
	var offset: Vector2 = _local(at) - _centre
	if not ThumbStick.holds(offset, grab_radius()):
		return
	_finger = index
	_push(offset)


## The driving finger sliding to [param at]. Anything else moving is somebody
## else's thumb, or a mouse nobody is holding down.
##
## No bounds check: a thumb that slides off the edge of the circle keeps the
## stick, and [method ThumbStick.input_from] pins what it is asking for at full.
## Letting go at the rim would stop the camera for a movement the player did not
## mean as a stop.
func _dragged(index: int, at: Vector2) -> void:
	if index != _finger:
		return
	_push(_local(at) - _centre)


## Moves the stick to [param offset] and takes the event off the table, so the
## screen underneath does not also turn it into an aim.
func _push(offset: Vector2) -> void:
	_offset = offset
	queue_redraw()
	_claim()


## Springs the stick back to the middle. Separate from [method _push] and
## [method _claim] because [method _notification] needs exactly this and none of
## the rest: there is no event to consume when the whole window went away.
func _let_go() -> void:
	if _finger == NO_FINGER:
		return
	_finger = NO_FINGER
	_offset = Vector2.ZERO
	queue_redraw()


func _claim() -> void:
	get_viewport().set_input_as_handled()


## [param at] in viewport coordinates, moved into this pad's own.
##
## The two are the same rectangle today — the pad is anchored full-rect on a
## screen that is — so this is arithmetic that currently changes nothing. It is
## here for the reason [code]play_screen.gd[/code]'s own version of it is: the day
## the HUD is inset or letterboxed, every grab in the game would be off by the
## inset, and it would look like a bug in the circle rather than like two
## rectangles that stopped agreeing.
func _local(at: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * at


## [param direction] in screen space, as a unit vector — or zero for
## [constant Vector2i.ZERO], which is not a direction.
##
## Y flips on the way in: a direction is in input space, where up is
## [code]+1[/code], and this is screen space, where up is [code]-Y[/code].
func _facing(direction: Vector2i) -> Vector2:
	return Vector2(float(direction.x), -float(direction.y)).normalized()


## How far from the middle a finger asking for [param direction] at full strength
## has to be, as a vector in screen space. The rim, which is where
## [method ThumbStick.input_from] reaches [constant ThumbStick.FULL_INPUT].
func _reach(direction: Vector2i) -> Vector2:
	return _facing(direction) * _radius


## Puts the circle in the bottom-right corner.
##
## [b]The corner is the one the tool belt is not.[/b] The belt rolls up out of the
## bottom-left and wraps rightward as far as x = 350 design px; the nearest thing
## here answers to a finger at 850. A phone is held in two hands and the thumbs
## land in the bottom corners, which is why the two things a player does
## constantly — change tool, walk — are
## one in each. The four arrows were spread up the whole right-hand edge because
## four targets did not fit in a corner; one does, which puts the stick where the
## thumb already rests instead of where there was room.
##
## The radius is [method TouchTarget.min_design_size] — 164 design px today and
## not negotiable, see [TouchTarget] for the Start button that taught this project
## the number. So the ring is 328 px across, twice the minimum on both axes, the
## grab area around it is 377, and the full travel from middle to rim is exactly
## one minimum: about 13 mm of thumb on the narrowest screen the game targets,
## which is a stick you can push rather than a screen you have to swipe.
##
## [b]The corner is measured to the whole control, not to the ring[/b], and the
## whole control is the wider of two things: the grab area, and the knob at full
## deflection — which sticks out half its own width past the rim it is resting on.
## Measured in a browser on a phone-shaped screen, because the first version of
## this took the margin off the grab area and the knob spent every hard-right push
## sliced in half by the edge of the glass.
func _relayout() -> void:
	# Rounded up for the reason [method ToolBeltHud._relayout] records: [Vector2]
	# is float32 and the minimum is a float64, so asking for 163.84 gets a control
	# that measures 163.839996 and is honestly below the minimum.
	_radius = ceilf(TouchTarget.min_design_size())
	var corner: float = MARGIN + maxf(grab_radius(), _radius * (1.0 + KNOB_FRACTION))
	_centre = Vector2(size.x - corner, size.y - corner)
	# A screen that changed shape under a held thumb has moved the circle out from
	# under it, and the offset that was measured against the old middle is not a
	# direction anybody is asking for any more.
	_let_go()
	queue_redraw()


func _draw() -> void:
	if _radius <= 0.0:
		return
	draw_circle(_centre, _radius, BASE_COLOR)
	draw_circle(_centre, _radius, RIM_COLOR, false, RIM_WIDTH, true)
	for direction: Vector2i in DIRECTIONS:
		var corners: PackedVector2Array = mark_corners(direction)
		if corners.size() != 3:
			continue
		# Base, tip, base — the two arms of the chevron meet at the corner
		# [method mark_corners] puts furthest along the direction, which is what
		# makes the point the thing that points.
		var chevron: PackedVector2Array = PackedVector2Array([corners[1], corners[0], corners[2]])
		draw_polyline(chevron, MARK_COLOR, MARK_WIDTH, true)
	var at: Vector2 = knob()
	draw_circle(at, _radius * KNOB_FRACTION, KNOB_COLOR, true, -1.0, true)
	var rim: float = knob_rim_width()
	if rim > 0.0:
		draw_circle(at, _radius * KNOB_FRACTION, HELD_RIM_COLOR, false, rim, true)
