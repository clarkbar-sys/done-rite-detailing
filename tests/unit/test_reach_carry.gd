## Unit tests for [ReachCarry] — the four tools that leave the hand and arrive on
## the paint.
##
## Under tests/unit/ for [code]test_wand_carry.gd[/code]'s reason: the claim is
## geometry and nothing else — two points and an angle in, a [Transform3D] out,
## no mesh and no camera. That the proxies really wear these poses is
## [code]tests/integration/test_view_model.gd[/code]'s, and that a real press puts
## a real can in front of real bodywork is
## [code]tests/integration/test_play_screen_reach.gd[/code]'s.
##
## [b]Two settings, tested as two carries.[/b] The class is one rule with a
## standoff and a lean, and the belt uses exactly two settings of it — flat on the
## paint for the sponge and the rag, held off and angled at it for the two
## bottles. Both are built below, because a formula that is right for one and
## wrong for the other is the failure worth catching and no single carry would
## show it.
##
## [b]The assertion that matters is the standoff, and it is measured to the
## working end.[/b] "The bottle is near the paint" is easy and is not enough: what
## the mist needs is the [i]nozzle[/i] a known distance off the panel, whatever
## the bottle's length, so that "a few inches away" keeps meaning the same thing
## after somebody resizes a proxy. That is what is measured here, and it is why
## the length is a constructor argument rather than something the caller offsets
## by afterwards.
extends GutTest

## A ten-thousandth of a metre, or of a component of a basis. These are exact
## constructions, so this is float noise rather than slack for a wrong answer.
const TOLERANCE: float = 0.0001

## A resting pose that is not the identity in any of its parts, so a carry that
## quietly handed back [constant Transform3D.IDENTITY] would fail rather than
## coincide.
const HELD: Transform3D = Transform3D(
	Basis(Vector3(0.0, 0.0, -1.0), Vector3(1.0, 0.0, 0.0), Vector3(0.0, -1.0, 0.0)),
	Vector3(0.03, -0.06, 0.01)
)

## Where the crosshair is, in the hand's own space: straight ahead, at about the
## range a car is washed from.
const MARK: Vector3 = Vector3(0.0, 0.0, -2.2)

## Which way the paint faces there — back at the player, which is what a flank
## square on to the eye gives and is the overwhelmingly common case.
##
## Deliberately level, with no [code]y[/code] in it, so that the "a leaning bottle
## leans upward" assertion below is reading the lean rather than reading the
## panel's own slope.
const OUTWARD: Vector3 = Vector3(0.0, 0.0, 1.0)

## The sponge's setting: half its own thickness plus a hair off the paint, lying
## flat on it, with no nozzle.
const SCRUB_STANDOFF: float = 0.055
const FLAT: float = 0.0
const NO_NOZZLE: float = 0.0

## The bottle's setting, from [ViewModel]'s own constants — a quarter of a metre
## of nozzle-to-paint and thirty degrees off square.
const SPRAY_STANDOFF: float = 0.25
const SPRAY_TILT: float = 150.0

## A bottle's length, from [method DetailingTool.catalogue]'s window cleaner.
## Written here rather than read off the catalogue for
## [code]test_wand_carry.gd[/code]'s reason: this suite is about a carry of a
## given length, not about which tool happens to have it.
const LENGTH: float = 0.26

var _scrub: ReachCarry = null
var _spray: ReachCarry = null


func before_each() -> void:
	_scrub = ReachCarry.new(HELD, SCRUB_STANDOFF, FLAT, NO_NOZZLE)
	_spray = ReachCarry.new(HELD, SPRAY_STANDOFF, SPRAY_TILT, LENGTH)


## Where [param carry]'s nozzle ends up, in the hand's space, fully brought up.
func _nozzle_at(carry: ReachCarry, outward: Vector3) -> Vector3:
	var posed: Transform3D = carry.pose(MARK, outward, 1.0)
	return posed * carry.nozzle()


## How far [param point] is off the paint, measured along the panel's own normal
## rather than as a straight distance to the mark — which is what a standoff is,
## and the only measure that stays honest when the tool is leaned to one side.
func _off_the_paint(point: Vector3, outward: Vector3) -> float:
	return (point - MARK).dot(outward.normalized())


# ---- the two tools that go onto the paint ------------------------------------


func test_a_scrubbing_tool_lands_flat_on_the_panel() -> void:
	# The whole of the sponge's setting: its own +Y is the surface normal, so the
	# broad face the catalogue gave it is against the paint rather than edge-on to
	# it. Swept across panels facing several ways, because a formula that lays a
	# sponge flat on a door and stands it up on a roof is exactly the mistake a
	# single head-on case would miss.
	for outward: Vector3 in [OUTWARD, Vector3(0.6, 0.2, 0.8), Vector3(0.0, 1.0, 0.0)]:
		var posed: Transform3D = _scrub.pose(MARK, outward, 1.0)
		assert_almost_eq(
			posed.basis.y, outward.normalized(), Vector3.ONE * TOLERANCE, "facing %v" % outward
		)


func test_a_scrubbing_tool_sits_its_standoff_off_the_paint_and_no_further() -> void:
	# The clearance that keeps half a sponge out of the door. Measured along the
	# panel's normal, which is what the number means; measured as a distance to the
	# mark it would also pass for a sponge slid sideways along the paint.
	for outward: Vector3 in [OUTWARD, Vector3(0.6, 0.2, 0.8), Vector3(0.0, 1.0, 0.0)]:
		var posed: Transform3D = _scrub.pose(MARK, outward, 1.0)
		assert_almost_eq(
			_off_the_paint(posed.origin, outward), SCRUB_STANDOFF, TOLERANCE, "facing %v" % outward
		)
		assert_almost_eq(
			posed.origin.distance_to(MARK),
			SCRUB_STANDOFF,
			TOLERANCE,
			"and square on to it rather than slid along it"
		)


func test_a_scrubbing_tool_keeps_its_own_width_level_in_the_frame() -> void:
	# The reason [method ReachCarry._lying_on] crosses against the frame's up
	# rather than a world axis. Without it the roll about the surface normal is
	# whatever a cross product happened to give, and a sponge slowly rotates on the
	# spot as the player walks around the car — which reads as the tool spinning
	# rather than as the eye moving.
	var posed: Transform3D = _scrub.pose(MARK, OUTWARD, 1.0)
	assert_almost_eq(posed.basis.x.y, 0.0, TOLERANCE, "the tool's own +X is level on screen")


# ---- the two that hover and spray --------------------------------------------


func test_a_spraying_can_holds_its_nozzle_the_standoff_off_the_paint() -> void:
	# The measurement the whole behaviour was asked for: the can a few inches from
	# the spot, with "a few inches" meaning the gap the mist crosses rather than the
	# gap to the middle of a bottle. A carry that placed the origin at the standoff
	# instead would put this nozzle 12 cm from the paint — near enough to look right
	# and wrong the moment the bottle changes size.
	assert_almost_eq(
		_off_the_paint(_nozzle_at(_spray, OUTWARD), OUTWARD),
		SPRAY_STANDOFF,
		TOLERANCE,
		"the nozzle, not the bottle"
	)


func test_the_standoff_is_the_nozzles_and_survives_a_bottle_of_any_length() -> void:
	# The property that makes the number above a design decision rather than a
	# coincidence. Three lengths, one answer: a longer can hangs further back, and
	# the end the product leaves from does not move.
	for length: float in [0.1, 0.26, 0.6]:
		var carry: ReachCarry = ReachCarry.new(HELD, SPRAY_STANDOFF, SPRAY_TILT, length)
		assert_almost_eq(
			_off_the_paint(_nozzle_at(carry, OUTWARD), OUTWARD),
			SPRAY_STANDOFF,
			TOLERANCE,
			"a %.2f m bottle" % length
		)


func test_the_nozzle_is_the_end_of_the_can_nearest_the_paint() -> void:
	# Which way round it is aimed. Both ends of a cylinder are on its axis, so
	# every angle above would pass just as happily for a can spraying over its own
	# shoulder.
	var posed: Transform3D = _spray.pose(MARK, OUTWARD, 1.0)
	assert_lt(
		(posed * _spray.nozzle()).distance_to(MARK),
		(posed * _spray.butt()).distance_to(MARK),
		"the product comes out of the end nearest the car"
	)


func test_a_can_is_leaned_off_square_rather_than_pointed_down_its_own_barrel() -> void:
	# A cylinder aimed straight at the panel is a cylinder aimed straight back at
	# the player, which is the disc [code]test_view_model.gd[/code] refuses for
	# every resting pose. The lean is asserted as the angle it actually is, so a
	# tilt quietly dropped to 180° fails here rather than in a screenshot.
	var axis: Vector3 = _spray.pose(MARK, OUTWARD, 1.0).basis.y
	assert_almost_eq(
		rad_to_deg(axis.angle_to(OUTWARD)), SPRAY_TILT, 0.001, "leaned off square by the tilt"
	)


func test_a_can_leans_upward_so_it_sprays_down_at_the_spot() -> void:
	# The sign of the lean, which is the half a cosine cannot see: crossed the other
	# way round the same thirty degrees puts the can below the spot angled up at it,
	# which is not how anybody holds a can. Asserted against a level panel normal so
	# this is reading the lean and not the panel.
	var posed: Transform3D = _spray.pose(MARK, OUTWARD, 1.0)
	assert_gt(posed.origin.y, MARK.y, "the body of the can sits above what it is spraying")
	assert_lt(posed.basis.y.y, 0.0, "and its nozzle points down at it")


# ---- coming up, and going back down ------------------------------------------


func test_a_tool_nobody_is_aiming_is_held_the_way_the_table_says() -> void:
	# The promise the near-plane and ground-clearance tests are still measuring: all
	# of this happens between a press and a release, and the resting pose is
	# untouched.
	for carry: ReachCarry in [_scrub, _spray]:
		var posed: Transform3D = carry.pose(MARK, OUTWARD, 0.0)
		assert_almost_eq(posed.origin, HELD.origin, Vector3.ONE * TOLERANCE)
		assert_almost_eq(posed.basis.y, HELD.basis.y, Vector3.ONE * TOLERANCE)


func test_coming_up_is_a_movement_rather_than_a_jump() -> void:
	# Half raised is half way there: neither pose, and nearer each of them than they
	# are to each other. This matters more here than it does for the wand, because
	# the distance travelled is the whole reach to the car — a sponge that appeared
	# on the paint between two frames would read as a rendering fault.
	for carry: ReachCarry in [_scrub, _spray]:
		var rest: Vector3 = HELD.origin
		var worked: Vector3 = carry.pose(MARK, OUTWARD, 1.0).origin
		var halfway: Vector3 = carry.pose(MARK, OUTWARD, 0.5).origin
		assert_lt(halfway.distance_to(rest), rest.distance_to(worked), "it has left the hand")
		assert_lt(halfway.distance_to(worked), rest.distance_to(worked), "and has not arrived")


func test_the_raise_is_read_as_a_fraction_of_the_way_up() -> void:
	# Anything outside 0..1 is a caller bug, and the answer to it is the nearer end
	# rather than a sponge driven past the paint into the door.
	assert_almost_eq(
		_scrub.pose(MARK, OUTWARD, 4.0).origin,
		_scrub.pose(MARK, OUTWARD, 1.0).origin,
		Vector3.ONE * TOLERANCE,
		"over the top is fully worked"
	)
	assert_almost_eq(
		_scrub.pose(MARK, OUTWARD, -4.0).origin,
		HELD.origin,
		Vector3.ONE * TOLERANCE,
		"and under it is at rest"
	)


# ---- surfaces there is no pose for -------------------------------------------


func test_a_mark_with_no_measured_normal_faces_the_tool_back_at_the_hand() -> void:
	# What [method Garage._nearest_on_the_car] produces when even its second ray
	# misses: a point on the car with nothing to measure a facing from. Rather than
	# refuse, the tool is turned back toward the hand — which is the same answer the
	# room invents for itself, and is never wrong by more than the angle the panel
	# is turned away at.
	var posed: Transform3D = _scrub.pose(MARK, Vector3.ZERO, 1.0)
	assert_almost_eq(
		posed.basis.y, -MARK.normalized(), Vector3.ONE * TOLERANCE, "facing back up the aim"
	)
	assert_true(posed.origin.is_finite(), "and emphatically not a NaN")


func test_a_mark_on_top_of_the_hand_leaves_the_tool_at_rest() -> void:
	# The one case there is no answer for at all: no point to work on and no normal
	# to work against, so nothing can be built without dividing by a zero-length
	# vector. A transform with no finite parts is a proxy that vanishes rather than
	# a tool held wrong.
	var posed: Transform3D = _scrub.pose(Vector3.ZERO, Vector3.ZERO, 1.0)
	assert_almost_eq(posed.origin, HELD.origin, Vector3.ONE * TOLERANCE)
	assert_almost_eq(posed.basis.y, HELD.basis.y, Vector3.ONE * TOLERANCE)


func test_a_panel_facing_straight_up_still_gets_a_pose() -> void:
	# The degenerate cross product [constant ReachCarry.FALLBACK] exists for: a roof
	# looked straight down at, where the surface normal and the frame's own up are
	# the same direction and the first reference gives a zero-length axis. Both
	# settings, because the can builds two bases and the sponge builds one.
	for carry: ReachCarry in [_scrub, _spray]:
		var posed: Transform3D = carry.pose(MARK, Vector3.UP, 1.0)
		assert_true(posed.basis.determinant() > 0.5, "a real basis rather than a collapsed one")
		assert_true(posed.origin.is_finite(), "and a finite place to put it")


# ---- what the viewmodel asks about it ----------------------------------------


func test_it_asks_to_be_kept_up_to_date() -> void:
	# Unlike the default carry, and for a stronger reason than the wand's: what this
	# is pointed at is a place on a panel, and both the place and the panel's facing
	# keep moving while the eye walks even on a frame where the swing has stopped.
	assert_true(_scrub.tracks_the_aim())
	assert_true(_spray.tracks_the_aim())


func test_only_the_tools_with_a_length_have_ends() -> void:
	# What [method ViewModel._build] reads to decide whether to hang markers off a
	# proxy, and what [method Garage._spray_the_can] reads to decide whether
	# anything comes out of it. A sponge with a nozzle would spray suds from its
	# own middle.
	assert_false(_scrub.has_ends(), "a sponge does not spray")
	assert_true(_spray.has_ends(), "a bottle does")
	assert_almost_eq(_spray.nozzle(), ReachCarry.AXIS * LENGTH * 0.5, Vector3.ONE * TOLERANCE)
	assert_almost_eq(_spray.nozzle().distance_to(_spray.butt()), LENGTH, TOLERANCE)
