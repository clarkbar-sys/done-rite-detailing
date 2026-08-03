## Unit tests for [WandCarry] — the power wash lying along the line from the hand
## to whatever the player is aiming at.
##
## Under tests/unit/ because the claim being tested is geometry and nothing else:
## a pose in, a pose out, no mesh and no camera. That the wand really wears this
## pose, and that the two markers at its ends really land where it says, is
## [code]tests/integration/test_view_model.gd[/code]'s; that a real press on real
## glass produces a real line to the crosshair is
## [code]tests/integration/test_play_screen_wand.gd[/code]'s.
##
## [b]The assertion that matters is the nozzle, not the angle.[/b] "The wand is
## parallel to the aim" is easy and is not enough — a wand parallel to the aim
## from a hand that is not the eye is aimed past the mark by the offset between
## them. So what is measured below is the distance from the nozzle to the
## [i]segment[/i] between the hand and the mark, which is zero only when the wand,
## its nozzle and the mark are all on one line. That is the property the water
## needs, and it is the reason this class exists rather than a tweaked entry in
## [method ViewModel._held_pose].
extends GutTest

## A ten-thousandth of a metre. These are trig round trips on exact inputs, so
## this is float noise rather than slack for a wrong answer.
const TOLERANCE: float = 0.0001

## The power wash's own length, from [method DetailingTool.catalogue]. Written
## here rather than read off the catalogue on purpose: this suite is about a
## carry of a given length, not about which tool happens to have it.
const LENGTH: float = 0.72

## The surface normal every call below passes and none of them reads.
##
## A wand is aimed at a place and has no opinion about which way the paint there
## faces — that is the whole difference between it and [ReachCarry], and it is why
## [method WandCarry.pose] takes the argument and ignores it. Deliberately a
## direction with no relationship to anything else in this file: if it ever starts
## mattering, every assertion here is the thing that should notice.
const UNREAD: Vector3 = Vector3(0.0, 0.0, 1.0)

## A resting pose that is nowhere near the aimed one — across the frame and slid
## down its own axis, the way the table in [ViewModel] holds a wand.
const HELD: Transform3D = Transform3D(
	Basis(Vector3(0.0, 0.0, -1.0), Vector3(1.0, 0.0, 0.0), Vector3(0.0, -1.0, 0.0)),
	Vector3(0.0, -0.06, 0.0)
)

var _carry: WandCarry = null


func before_each() -> void:
	_carry = WandCarry.new(HELD, LENGTH)


## A point to aim at in the hand's own space: [param range_metres] away, off at
## [param yaw] and [param pitch] degrees. Built from the trig by hand so the
## tests are not checking the class against itself.
func _target(yaw: float, pitch: float, range_metres: float) -> Vector3:
	var yawed: float = deg_to_rad(yaw)
	var pitched: float = deg_to_rad(pitch)
	return (
		Vector3(-sin(yawed) * cos(pitched), sin(pitched), -cos(yawed) * cos(pitched)) * range_metres
	)


## Where the nozzle ends up, in the hand's space, for a wand aimed at
## [param target] and fully brought up.
func _nozzle_at(target: Vector3) -> Vector3:
	return _carry.pose(target, UNREAD, 1.0) * _carry.nozzle()


## How far [param point] is off the segment from the hand to [param target].
##
## The hand is the origin in this space, so the segment is the ray to the target
## clipped at both ends — and the measure is the perpendicular distance to it,
## which is the honest form of "these three points are on one line".
func _off_the_line(point: Vector3, target: Vector3) -> float:
	var along: Vector3 = target.normalized()
	var reach: float = point.dot(along)
	if reach <= 0.0 or reach >= target.length():
		# Past either end of the segment. Not on it at any distance, and reported as
		# the whole distance to the nearer end rather than as a perpendicular that
		# would flatter it.
		return minf(point.length(), point.distance_to(target))
	return point.distance_to(along * reach)


# ---- the line the water travels ----------------------------------------------


func test_the_wand_lies_along_the_line_to_what_it_is_aimed_at() -> void:
	# The alignment itself: the wand's own long axis is the direction to the mark.
	for yaw: float in [-32.0, -9.0, 0.0, 15.0, 32.0]:
		for pitch: float in [-24.0, 0.0, 24.0]:
			var target: Vector3 = _target(yaw, pitch, 2.4)
			var axis: Vector3 = _carry.pose(target, UNREAD, 1.0).basis.y
			assert_almost_eq(
				axis,
				target.normalized(),
				Vector3.ONE * TOLERANCE,
				"yaw %.0f pitch %.0f" % [yaw, pitch]
			)


func test_the_nozzle_sits_on_the_line_between_the_hand_and_the_mark() -> void:
	# The property the jet is going to be built on, and the one an angle alone does
	# not give you. Swept across the cone and across the range a car is washed at,
	# because a formula that is only right at one distance is exactly the failure
	# this replaces.
	for yaw: float in [-32.0, 0.0, 32.0]:
		for pitch: float in [-24.0, 0.0, 24.0]:
			for range_metres: float in [1.2, 2.2, 4.0, 30.0]:
				var target: Vector3 = _target(yaw, pitch, range_metres)
				assert_almost_eq(
					_off_the_line(_nozzle_at(target), target),
					0.0,
					TOLERANCE,
					"yaw %.0f pitch %.0f at %.1f m" % [yaw, pitch, range_metres]
				)


func test_the_nozzle_points_at_the_mark_from_wherever_it_ended_up() -> void:
	# The same fact stated the way a particle system will ask it: the direction out
	# of the nozzle and the direction from the nozzle to the mark are one direction.
	var target: Vector3 = _target(18.0, -11.0, 2.6)
	var nozzle: Vector3 = _nozzle_at(target)
	var out: Vector3 = _carry.pose(target, UNREAD, 1.0).basis.y
	assert_almost_eq(out.dot(nozzle.direction_to(target)), 1.0, TOLERANCE)


func test_the_nozzle_is_the_end_of_the_wand_nearest_the_mark() -> void:
	# Which way round it is aimed. Both ends of a cylinder are on its axis, so an
	# alignment that pointed the butt at the car would satisfy every angle above.
	var target: Vector3 = _target(0.0, 0.0, 2.4)
	var posed: Transform3D = _carry.pose(target, UNREAD, 1.0)
	assert_lt(
		(posed * _carry.nozzle()).distance_to(target),
		(posed * _carry.butt()).distance_to(target),
		"the water comes out of the end nearest the car"
	)


func test_the_two_ends_are_a_wand_apart_along_its_own_axis() -> void:
	assert_almost_eq(_carry.nozzle().distance_to(_carry.butt()), LENGTH, TOLERANCE)
	assert_almost_eq(_carry.nozzle(), WandCarry.AXIS * LENGTH * 0.5, Vector3.ONE * TOLERANCE)


func test_it_says_it_has_ends_worth_marking() -> void:
	# What [method ViewModel._build] reads to decide whether to hang a pair of
	# markers off the proxy. The wand is the tool they were invented for, and a
	# carry that had the geometry above and quietly answered no here would leave the
	# water with nowhere to come out of.
	assert_true(_carry.has_ends(), "the wand has a nozzle")


# ---- and it stays inside the shot --------------------------------------------


func test_an_aimed_wand_turns_about_the_hand_rather_than_reaching_past_it() -> void:
	# What keeps this inside the clearance budget the room measured: the wand turns
	# about the anchor with half of itself either side, so the furthest any part of
	# it gets from the hand is 0.36 m — under the 0.45 m every other tool is already
	# allowed. Sliding it along its axis to grip it like the resting pose does would
	# put the nozzle 0.66 m out and re-open a question the garage's docs closed.
	for yaw: float in [-32.0, 0.0, 32.0]:
		var target: Vector3 = _target(yaw, 0.0, 2.4)
		var posed: Transform3D = _carry.pose(target, UNREAD, 1.0)
		for end: Vector3 in [_carry.nozzle(), _carry.butt()]:
			assert_almost_eq((posed * end).length(), LENGTH * 0.5, TOLERANCE, "at yaw %.0f" % yaw)


# ---- coming up, and going back down ------------------------------------------


func test_a_wand_nobody_is_aiming_is_held_the_way_the_table_says() -> void:
	# The reason the "no cylinder points down the barrel" rule still holds for the
	# power wash: at rest it is back across the frame, and the alignment is
	# something that only happens while a finger is on the glass.
	var posed: Transform3D = _carry.pose(_target(0.0, 0.0, 2.4), UNREAD, 0.0)
	assert_almost_eq(posed.basis.y, HELD.basis.y, Vector3.ONE * TOLERANCE)
	assert_almost_eq(posed.origin, HELD.origin, Vector3.ONE * TOLERANCE)


func test_coming_up_is_a_movement_rather_than_a_jump() -> void:
	# Half raised is half way round: neither pose, and closer to each of them than
	# they are to each other. A carry that snapped at some threshold would pass
	# every other test in this file.
	var target: Vector3 = _target(0.0, 0.0, 2.4)
	var rest: Vector3 = HELD.basis.y
	var aimed: Vector3 = _carry.pose(target, UNREAD, 1.0).basis.y
	var halfway: Vector3 = _carry.pose(target, UNREAD, 0.5).basis.y
	assert_lt(halfway.angle_to(rest), rest.angle_to(aimed), "it has left the resting pose")
	assert_lt(halfway.angle_to(aimed), rest.angle_to(aimed), "and has not arrived yet")


func test_the_raise_is_read_as_a_fraction_of_the_way_up() -> void:
	# Anything outside 0..1 is a caller bug, and the answer to it is the nearer end
	# rather than a wand rotated past the aim into the car.
	var target: Vector3 = _target(0.0, 0.0, 2.4)
	assert_almost_eq(
		_carry.pose(target, UNREAD, 4.0).basis.y,
		_carry.pose(target, UNREAD, 1.0).basis.y,
		Vector3.ONE * TOLERANCE,
		"over the top is fully aimed"
	)
	assert_almost_eq(
		_carry.pose(target, UNREAD, -4.0).basis.y,
		HELD.basis.y,
		Vector3.ONE * TOLERANCE,
		"and under it is at rest"
	)


# ---- directions there is no wand for -----------------------------------------


func test_a_target_of_nothing_leaves_the_wand_at_rest() -> void:
	# `normalized()` of a zero vector is a zero vector, and the shortest arc to one
	# is a NaN quaternion — which is a transform with no finite parts and a proxy
	# that vanishes rather than a tool held wrong.
	var posed: Transform3D = _carry.pose(Vector3.ZERO, UNREAD, 1.0)
	assert_almost_eq(posed.basis.y, HELD.basis.y, Vector3.ONE * TOLERANCE)


func test_a_target_straight_back_down_the_wand_leaves_it_at_rest() -> void:
	# The other undefined arc: every rotation from +Y to -Y is equally short. The
	# pitch fence means the aim never asks for it, so this is about a caller with no
	# fence rather than about the game.
	var posed: Transform3D = _carry.pose(-WandCarry.AXIS * 2.0, UNREAD, 1.0)
	assert_almost_eq(posed.basis.y, HELD.basis.y, Vector3.ONE * TOLERANCE)
	assert_true(posed.basis.y.is_finite(), "and emphatically not a NaN")


func test_it_asks_to_be_kept_up_to_date() -> void:
	# Unlike the default carry: what this is aimed at moves while the eye walks,
	# even on a frame where the swing itself has stopped.
	assert_true(_carry.tracks_the_aim())
