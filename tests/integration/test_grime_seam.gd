## Integration test for [method Grime.panels_within] — which panels one press is
## actually touching, rather than which one the ray happened to name.
##
## [b]What this is for.[/b] A tool is a ball of a radius in metres and a car's
## panels butt up against each other, so a press anywhere near a seam is
## physically on both sides of it. Spending the trigger on the single collider the
## raycast returned left the other side with a strip nothing could reach: the aim
## was never wrong, the brush was simply not allowed to leave the map it started
## in. [method Garage._spend_the_trigger] is what asks this, and
## [code]tests/unit/test_grime_map_reach.gd[/code] is the same widening one level
## down, across the faces of a single panel.
##
## [b]On [code]tests/fixtures/plain_car.tscn[/code][/b] for
## [code]tests/integration/test_grime.gd[/code]'s reason, and its class docs carry
## the argument: what is being pinned here is true of any car with two panels near
## each other, and pointing it at the blockout would buy a suite that goes red
## when somebody reshapes a wing.
##
## [b]The radii below are the fixture's, not the game's.[/b] Its panels stand a
## clear metre apart — deliberately, so tests that want them independent get that
## for free — where a real car's are touching. So "a brush that spans the gap" is
## 1.2 m here and 20 cm on the actual bodywork. The rule being asserted is the one
## that does not depend on either number: a press reaches every panel within its
## own radius of it, and no others.
##
## Under tests/integration/ because every box here is a panel's
## [method CSGShape3D.get_aabb] and CSG meshes are built deferred — a car asked
## before a frame has passed reports panels with no size at all.
extends GutTest

const CAR: String = "res://tests/fixtures/plain_car.tscn"

## Just inside the inward edge of one of the fixture's two body panels, level with
## the middle of it. The nearest thing the fixture has to a seam: the far panel
## starts a metre away across the gap.
##
## Inside the edge rather than exactly on it, so [method AABB.has_point] is not
## being asked about a boundary — [method _panel_under] uses it to work out which
## panel this is without naming one, and a point sitting on a face is the one input
## that question does not have a stable answer to.
const ON_THE_SEAM: Vector3 = Vector3(-0.6, 0.0, 0.0)

## A brush that does not span that gap — every real tool in the game, at this
## fixture's scale.
const SHORT_REACH: float = 0.4

## One that does, with room to spare on both sides so the assertion is not sitting
## on a boundary. Still short of the metre that separates the bodywork from the
## glass above it and the rubber below, which is what makes "both body panels and
## nothing else" a statement rather than a coincidence.
const LONG_REACH: float = 1.2

var _car: Car = null
var _grime: Grime = null


func before_each() -> void:
	var packed: PackedScene = load(CAR) as PackedScene
	assert_not_null(packed, "could not load %s" % CAR)
	if packed == null:
		return
	var car: Car = packed.instantiate() as Car
	_car = car
	add_child_autofree(_car)
	_grime = Grime.new()
	add_child_autofree(_grime)
	# The frame [Grime]'s class docs are about. Every box measured below belongs to
	# a panel that has been built.
	await wait_process_frames(1)
	_grime.lay_on(_car)


## The names of the panels a brush of [param reach] at [param at] can work, sorted
## so a comparison is about which panels and not about what order the car lists
## them in.
func _names_within(at: Vector3, reach: float) -> Array[String]:
	var names: Array[String] = []
	for panel: CSGShape3D in _grime.panels_within(at, reach):
		names.append(String(panel.name))
	names.sort()
	return names


## Every body panel of the fixture, by name, sorted the same way.
##
## By [enum Surface.Kind] rather than by writing the fixture's two slabs down, for
## the reason [code]tests/integration/test_grime.gd[/code] gives at length: there
## is no reason for this file to know what the fixture calls its furniture.
func _body_names() -> Array[String]:
	var names: Array[String] = []
	for panel: CSGShape3D in _car.panels():
		if _car.kind_of(panel) == Surface.Kind.BODY:
			names.append(String(panel.name))
	names.sort()
	return names


## The panel [param at] is actually inside, or [code]""[/code] if it is in thin
## air. What a raycast would have come back with, worked out from the boxes so
## that the assertions below can say "the panel the press landed on" without
## naming it.
func _panel_under(at: Vector3) -> String:
	for panel: CSGShape3D in _car.panels():
		if (panel.global_transform * panel.get_aabb()).has_point(at):
			return String(panel.name)
	return ""


# ---- what one press is touching -----------------------------------------------


func test_a_press_reaches_the_panel_it_landed_on() -> void:
	# The floor under everything else here. Whatever else widening the brush does,
	# it must not lose the panel the player was actually pointing at.
	var landed: String = _panel_under(ON_THE_SEAM)
	assert_ne(landed, "", "the test's own press is not on the car")
	assert_has(
		_names_within(ON_THE_SEAM, SHORT_REACH), landed, "the press missed the panel it was on"
	)


func test_a_press_that_spans_a_seam_works_both_sides_of_it() -> void:
	# The whole point. A brush wide enough to cross the gap is on both panels, and
	# before this it was on whichever one the ray returned.
	assert_eq(
		_names_within(ON_THE_SEAM, LONG_REACH),
		_body_names(),
		"a brush spanning the gap reached only one side of it"
	)


func test_a_press_that_does_not_span_it_stays_on_one_panel() -> void:
	# The other half, and the one that stops "reaches more panels" quietly meaning
	# "reaches all of them". A tool only works what it can actually touch.
	assert_eq(
		_names_within(ON_THE_SEAM, SHORT_REACH).size(),
		1,
		"a brush that cannot cross the gap crossed it anyway"
	)


func test_a_press_never_reaches_a_panel_it_is_nowhere_near() -> void:
	# The glass sits a clear metre above the bodywork and the rubber a metre below,
	# so neither is in reach of a press on the body at either radius. A brush that
	# collected them would be washing the windows from the door.
	#
	# Asserted as "everything it found is bodywork" rather than as two names, for
	# [method _body_names]'s reason.
	for reach: float in [SHORT_REACH, LONG_REACH]:
		for found: String in _names_within(ON_THE_SEAM, reach):
			assert_has(
				_body_names(), found, "%s is not bodywork and was reached at %f" % [found, reach]
			)


func test_a_press_off_the_car_reaches_nothing() -> void:
	# Not an error and not the nearest panel — a press twenty metres up is touching
	# no bodywork, and the honest answer to "what is this tool working" is nothing.
	assert_eq(_grime.panels_within(Vector3(0.0, 20.0, 0.0), LONG_REACH).size(), 0)


func test_a_wider_brush_never_reaches_less() -> void:
	# The property that makes the radius mean something. It is asserted rather than
	# assumed because the answer comes from a grown box, and a growth that had gone
	# in the wrong direction would still return plausible-looking panels.
	assert_true(
		(
			_names_within(ON_THE_SEAM, SHORT_REACH).size()
			<= _names_within(ON_THE_SEAM, LONG_REACH).size()
		),
		"a wider brush reached fewer panels"
	)
