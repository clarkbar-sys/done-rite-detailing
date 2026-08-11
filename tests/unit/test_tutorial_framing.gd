## Unit tests for [TutorialFraming] — where the eye stands to film a panel.
##
## Under tests/unit/ because a shot is trigonometry: the class is handed two boxes
## and a lens and answers with a spot on the driveway, so "is this framing right"
## is a row in a table here rather than a screenshot somebody looked at. Whether the
## panel actually fills the frame it is put in front of is a thing only a pixel can
## answer, and CI has none — see STANDARDS.md on the renderer split.
extends GutTest

## A sedan-shaped car sitting on the floor: 4.5 m long in [code]x[/code], 1.9 m
## across, 1.5 m tall, with the bottom of its box on [code]y = 0[/code] the way
## [method Garage._park_the_car] leaves every car it parks.
const CAR: AABB = AABB(Vector3(-2.25, 0.0, -0.95), Vector3(4.5, 1.5, 1.9))

## A wheel: small, low, and well off the middle of the car — the panel that has a
## side to it, which the shell and the windows deliberately do not.
const WHEEL: AABB = AABB(Vector3(1.2, 0.0, 0.7), Vector3(0.7, 0.7, 0.3))

## The lens a 9:16 window actually gives this room: 75° across a desktop frame
## narrows to about 43° once [LensFit] has capped the vertical angle. The number
## every take is really framed through.
const PHONE_FOV: float = 43.0

## A millimetre, which is what a comparison between a distance the class computed
## and the same distance this file re-derived is worth. The fence it is checking is
## 1.2 m, so nothing here is being let through by it.
const SLOP: float = 0.001


## How far [param eye] is from the middle of [param box], measured on the floor —
## the only distance any of the fences below are about.
func _flat_from(eye: Vector3, box: AABB) -> float:
	var middle: Vector3 = box.get_center()
	return Vector2(eye.x - middle.x, eye.z - middle.z).length()


# ---- which way round the car the eye goes --------------------------------------


func test_a_panel_with_a_side_to_it_is_filmed_from_that_side() -> void:
	# The wheel is off to one corner, so the eye goes to that corner. Anything else
	# would film it through the car.
	var facing: Vector2 = TutorialFraming.facing_for(WHEEL, CAR)
	assert_gt(facing.x, 0.0, "the wheel is toward +x")
	assert_gt(facing.y, 0.0, "and toward +z")
	assert_almost_eq(facing.length(), 1.0, 0.0001, "a direction, not a distance")


func test_a_panel_at_the_middle_of_the_car_is_filmed_from_the_quarter() -> void:
	# The shell and the windows are both centred, and the angle of a point at the
	# middle of a circle flips from one side of the car to the other over a
	# centimetre. The fixed quarter is the stable answer and the flattering one.
	assert_almost_eq(
		TutorialFraming.facing_for(CAR, CAR).angle(),
		TutorialFraming.QUARTER.normalized().angle(),
		0.0001
	)


func test_the_reach_of_a_box_is_measured_along_the_direction_asked_about() -> void:
	# What "how much of this car is in the way" means for a direction that is not one
	# of the box's own axes.
	assert_almost_eq(TutorialFraming.reach_along(CAR, Vector2(1.0, 0.0)), 2.25, 0.0001)
	assert_almost_eq(TutorialFraming.reach_along(CAR, Vector2(0.0, -1.0)), 0.95, 0.0001)


# ---- how far back it stands ----------------------------------------------------


func test_the_eye_never_stands_in_the_bodywork() -> void:
	# The fence, and the reason there is one: a fixed shot has no [Standoff] ray to
	# keep it out of the paint, so the box has to. Checked on the panel that pulls
	# hardest at it — a wheel is small enough that the framing sum on its own would
	# put the lens inside the arch.
	for panel: AABB in [CAR, WHEEL]:
		var eye: Vector3 = TutorialFraming.eye_for(panel, CAR, PHONE_FOV)
		var facing: Vector2 = TutorialFraming.facing_for(panel, CAR)
		assert_gte(
			_flat_from(eye, CAR) + SLOP,
			TutorialFraming.reach_along(CAR, facing) + TutorialFraming.CLEARANCE,
			"the eye has to clear the car by more than a held tool is long"
		)


func test_the_eye_stays_on_the_driveway() -> void:
	# The far fence. The shell's own framing sum asks for a good deal more than this
	# through a phone lens, and past about here the eye is standing on the lawn.
	assert_almost_eq(
		_flat_from(TutorialFraming.eye_for(CAR, CAR, PHONE_FOV), CAR),
		TutorialFraming.FURTHEST,
		0.0001
	)


func test_a_narrower_lens_stands_further_back() -> void:
	# The whole of "it is a stand and not a zoom". The same panel through a tighter
	# lens is the same panel seen from further away, which is the thing that keeps the
	# framing honest when the window turns out to be a phone.
	var wide: float = _flat_from(TutorialFraming.eye_for(WHEEL, CAR, 90.0), CAR)
	var narrow: float = _flat_from(TutorialFraming.eye_for(WHEEL, CAR, 30.0), CAR)
	assert_gt(narrow, wide, "less lens has to mean more driveway")


func test_a_lens_with_no_width_is_not_measured_against() -> void:
	# It happens: a viewport that has not been laid out yet reports nothing, and
	# [method Lens._fit] leaves the camera alone rather than dividing by it. The honest
	# answer here is the near fence — a shot of the car — rather than an eye at
	# infinity.
	var facing: Vector2 = TutorialFraming.facing_for(WHEEL, CAR)
	assert_almost_eq(
		TutorialFraming.stand_off(WHEEL, CAR, facing, 0.0),
		TutorialFraming.reach_along(CAR, facing) + TutorialFraming.CLEARANCE,
		0.0001
	)


func test_a_wide_enough_lens_is_held_off_by_the_fence_rather_than_by_the_framing() -> void:
	# A fisheye would happily stand inside the car to fill its frame. The near fence is
	# what says no, and this is the case that proves it is the fence answering.
	var facing: Vector2 = TutorialFraming.facing_for(WHEEL, CAR)
	assert_almost_eq(
		TutorialFraming.stand_off(WHEEL, CAR, facing, 170.0),
		TutorialFraming.reach_along(CAR, facing) + TutorialFraming.CLEARANCE,
		0.0001
	)


# ---- how high it stands --------------------------------------------------------


func test_the_eye_is_raised_above_the_panel_it_films() -> void:
	# The camera looks at the panel from above it rather than level with it, for
	# [member Garage.attract_eye_rise_metres]'s reason: level with a sill is lying on
	# the tarmac.
	var glass: AABB = AABB(Vector3(-0.8, 0.9, -0.7), Vector3(1.6, 0.5, 1.4))
	assert_almost_eq(
		TutorialFraming.height_for(glass, CAR), glass.get_center().y + TutorialFraming.RISE, 0.0001
	)


func test_a_low_panel_is_still_filmed_standing_up() -> void:
	# A wheel is 35 cm off the ground and half a metre above that is a camera on its
	# side on the drive. The fence is what makes every take a shot from eye height.
	assert_almost_eq(
		TutorialFraming.height_for(WHEEL, CAR), CAR.position.y + TutorialFraming.LOWEST, 0.0001
	)


func test_the_height_is_measured_from_the_floor_the_car_is_parked_on() -> void:
	# So the fences mean the same thing on a sport car and on a minivan — and so a
	# fixture parked somewhere other than the origin is framed against its own floor
	# rather than against the number zero.
	var lifted: AABB = AABB(CAR.position + Vector3(0.0, 2.0, 0.0), CAR.size)
	assert_almost_eq(
		TutorialFraming.height_for(WHEEL, lifted),
		lifted.position.y + TutorialFraming.LOWEST,
		0.0001
	)


func test_the_eye_never_leans_in_over_the_roof() -> void:
	# The top fence. A panel high above the car — nothing in the pack, but the sum
	# does not know that — would otherwise put the camera up a ladder looking down at
	# the bonnet.
	var roof: AABB = AABB(Vector3(-1.0, 3.0, -0.5), Vector3(2.0, 0.2, 1.0))
	assert_almost_eq(
		TutorialFraming.height_for(roof, CAR), CAR.position.y + TutorialFraming.HIGHEST, 0.0001
	)


# ---- the shot as a whole -------------------------------------------------------


func test_the_same_panel_is_always_filmed_from_the_same_spot() -> void:
	# "The same commit always produces the same footage" is the whole point, and this
	# is the half of it that is arithmetic: no clock, no ray, no random draw, so two
	# calls a frame apart cannot disagree.
	assert_eq(
		TutorialFraming.eye_for(WHEEL, CAR, PHONE_FOV),
		TutorialFraming.eye_for(WHEEL, CAR, PHONE_FOV)
	)


func test_the_window_it_is_framed_for_is_the_shape_of_a_phone() -> void:
	# Taller than it is wide, because that is the screen this game is played on and
	# the reason [LensFit] exists at all.
	assert_gt(TutorialFraming.FRAME.y, TutorialFraming.FRAME.x)
