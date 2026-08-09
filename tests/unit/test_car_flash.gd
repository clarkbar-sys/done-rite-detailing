## Unit tests for [method Car.flash_colour] — what a patch of paint throws when
## the water finishes it.
##
## Under tests/unit/ although [Car] is a [Node3D], because the thing under test is
## a static function on it and needs no car standing anywhere: it takes a colour
## and returns one. Everything about the [i]node[/i] is in
## [code]tests/integration/test_car.gd[/code].
##
## [b]What is worth pinning is the property, not the thirteen answers.[/b] The
## flash is drawn as emission ([code]grime.gdshader[/code]'s [code]flash_tint[/code]),
## so what a wash pop needs from every paint in the palette is a channel at full
## and its own hue kept — a colour that came back dark would be a car whose
## reward for washing nobody can see, and one that came back white would be a
## reward that is not about their car. Both failures look like taste and are not.
extends GutTest

## How close two colours have to be to count as the same one here. Everything
## below is a ratio of floats, so this is float slack rather than a tolerance on
## anything anybody chose.
const TOLERANCE: float = 0.0001


## How bright the brightest channel of [param colour] is.
func _peak(colour: Color) -> float:
	return maxf(colour.r, maxf(colour.g, colour.b))


## The whole point: every car pops as hard as every other car, whatever it is
## painted. A flash that carried the paint's own value would announce a finished
## patch on Deep Blue at a fifth of the brightness it announces one on Alpine
## White, which is the palette deciding who gets feedback.
func test_every_paint_in_the_palette_lights_to_a_full_channel() -> void:
	for colour: Color in Car.PAINT_COLORS:
		var flash: Color = Car.flash_colour(colour)
		assert_almost_eq(_peak(flash), 1.0, TOLERANCE, "%s does not light to full" % colour)


## And it is still their car. The hue is the entire message — the reward for
## washing is seeing what colour is under the mud — so the three channels have to
## keep their ratios to each other rather than being lifted toward white.
func test_lighting_a_paint_keeps_its_hue() -> void:
	for colour: Color in Car.PAINT_COLORS:
		var flash: Color = Car.flash_colour(colour)
		assert_almost_eq(flash.h, colour.h, TOLERANCE, "%s changed hue" % colour)
		assert_almost_eq(flash.s, colour.s, TOLERANCE, "%s changed saturation" % colour)


## A colour and the same colour after [method MeshCar.compensated] flash the same,
## which is what lets the caller read [member Car.paint] without caring whether the
## pack's greyscale map has been accounted for yet. It falls out of the scaling
## rather than being arranged, and this is the test that says so out loud.
func test_the_map_compensation_makes_no_difference_to_the_flash() -> void:
	for colour: Color in Car.PAINT_COLORS:
		var flash: Color = Car.flash_colour(colour)
		var driven: Color = Car.flash_colour(MeshCar.compensated(colour))
		assert_almost_eq(driven.r, flash.r, TOLERANCE, "%s: red moved" % colour)
		assert_almost_eq(driven.g, flash.g, TOLERANCE, "%s: green moved" % colour)
		assert_almost_eq(driven.b, flash.b, TOLERANCE, "%s: blue moved" % colour)


## A colour that is already at full is left where it is rather than scaled down —
## this only ever lifts.
func test_a_paint_already_at_full_is_left_alone() -> void:
	assert_eq(Car.flash_colour(Color(1.0, 0.5, 0.0)), Color(1.0, 0.5, 0.0))


## Black has no hue to keep and nothing to divide by. No car in
## [constant Car.PAINT_COLORS] is black — the palette's own docs have why — but a
## fixture painted by hand can be, and the answer has to be a flash rather than a
## division by zero or an invisible one.
func test_black_paint_flashes_white_rather_than_nothing() -> void:
	assert_eq(Car.flash_colour(Color.BLACK), Color.WHITE)
