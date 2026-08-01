## Unit tests for [ToolCarry] — how a tool sits in the hand, in the case where
## the answer is "the way it always does".
##
## Under tests/unit/ because a carry is a [RefCounted] that turns an aim into a
## [Transform3D] and has never seen a mesh: the whole of it is arithmetic about a
## pose. That the pose it hands back is really what the proxy ends up wearing is
## [code]tests/integration/test_view_model.gd[/code]'s job, and the geometry the
## power wash's own carry adds on top is [code]test_wand_carry.gd[/code]'s.
##
## [b]What is actually being pinned here[/b] is that the default carry is inert.
## Four of the five tools use it, and the whole promise of this refactor is that
## none of them moved — so "no input changes the answer" is the assertion, swept
## rather than sampled once.
extends GutTest

## A ten-thousandth of a metre, or of a component of a basis. These are lerps and
## rotations of exact inputs, so this is float noise rather than slack.
const TOLERANCE: float = 0.0001

## A pose that is not the identity in any of its parts, so a carry that quietly
## returned [constant Transform3D.IDENTITY] would fail rather than coincide.
const HELD: Transform3D = Transform3D(
	Basis(Vector3(0.0, 0.0, -1.0), Vector3(1.0, 0.0, 0.0), Vector3(0.0, -1.0, 0.0)),
	Vector3(0.03, -0.06, 0.01)
)

var _carry: ToolCarry = null


func before_each() -> void:
	_carry = ToolCarry.new(HELD)


## Somewhere for a hand to be pointed, in the hand's own space: [param range]
## metres down the aim, off at [param yaw] degrees.
func _somewhere(yaw: float, range_metres: float) -> Vector3:
	var yawed: float = deg_to_rad(yaw)
	return Vector3(-sin(yawed), 0.0, -cos(yawed)) * range_metres


func test_it_is_built_holding_the_pose_it_was_given() -> void:
	assert_almost_eq(_carry.rest_pose().origin, HELD.origin, Vector3.ONE * TOLERANCE)
	assert_almost_eq(_carry.rest_pose().basis.y, HELD.basis.y, Vector3.ONE * TOLERANCE)


func test_a_tool_at_rest_is_held_the_way_the_table_says() -> void:
	assert_almost_eq(_carry.pose(Vector3.ZERO, 0.0).origin, HELD.origin, Vector3.ONE * TOLERANCE)


func test_nothing_anybody_aims_at_moves_it() -> void:
	# The promise the four tools that are not the power wash are relying on: a
	# sponge is held the way a sponge is held, whatever the player is pointing at
	# and however far into aiming they are.
	for yaw: float in [-40.0, 0.0, 40.0]:
		for range_metres: float in [1.0, 2.5, 30.0]:
			for raise: float in [0.0, 0.5, 1.0]:
				var posed: Transform3D = _carry.pose(_somewhere(yaw, range_metres), raise)
				assert_almost_eq(
					posed.origin,
					HELD.origin,
					Vector3.ONE * TOLERANCE,
					"moved at yaw %.0f, %.1f m, raise %.1f" % [yaw, range_metres, raise]
				)
				assert_almost_eq(
					posed.basis.y,
					HELD.basis.y,
					Vector3.ONE * TOLERANCE,
					"turned at yaw %.0f, %.1f m, raise %.1f" % [yaw, range_metres, raise]
				)


func test_it_does_not_ask_to_be_kept_up_to_date() -> void:
	# What [method ViewModel._process] reads to decide whether a settled hand is
	# still worth paying for. A carry that returns one pose forever and said yes
	# here would cost a transform write every frame of every game for nothing.
	assert_false(_carry.tracks_the_aim(), "a fixed pose has nothing new to say")
