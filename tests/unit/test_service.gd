## Unit tests for [Service] — the business's menu and its phone number.
##
## Under tests/unit/ because a [Service] is a [RefCounted] holding strings: there
## is nothing here that needs a scene, a window or a frame.
##
## [b]These are transcription tests, the same kind [code]tests/unit/test_brand.gd[/code]
## makes against the site's palette, and they work the same way: the page's own
## wording is written out a second time below, so an assertion is this file
## against the site rather than [Service] against itself. A test that read the
## constant it is checking would pass forever and protect nothing — and what
## these exist to catch is exactly the drift nothing else can, since a service
## renamed on the site fails no type check and no export.
extends GutTest

## The four service headings and the [code]tel:[/code], copied from the page.
## Source: https://bespoke-cascaron-816d86.netlify.app
const SITE: Dictionary = {
	"services":
	[
		"Hand Wash & Dry",
		"Interior Deep Clean",
		"Wheel & Tire Shine",
		"Protect & Maintain",
	],
	"tel": "tel:+13307804778",
	"spoken": "330-780-4778",
}


func test_the_menu_is_the_sites_menu() -> void:
	# In order, because the order is the site's grid and a menu that agreed about
	# the four names and disagreed about which is first is a different page.
	var expected: PackedStringArray = PackedStringArray(SITE["services"])
	assert_eq(Service.menu(), expected, "the game must list the services the site lists")


func test_every_named_service_is_on_the_menu() -> void:
	# By constant rather than by count: four entries where two are the same
	# service would satisfy the size check above and leave one unnameable.
	for name_shown: String in [
		Service.HAND_WASH_AND_DRY,
		Service.INTERIOR_DEEP_CLEAN,
		Service.WHEEL_AND_TIRE_SHINE,
		Service.PROTECT_AND_MAINTAIN,
	]:
		assert_true(
			Service.menu().has(name_shown), "%s is a constant but not on the menu" % name_shown
		)


func test_each_call_builds_a_fresh_menu() -> void:
	# A method and not a `const Array` precisely so one caller cannot rewrite
	# every other caller's copy. Mutating what came back must not be visible.
	var mine: PackedStringArray = Service.menu()
	mine.append("Undercoating")
	assert_eq(Service.menu().size(), SITE["services"].size(), "the menu must not be shared state")


func test_the_dial_url_is_the_one_the_site_dials() -> void:
	# The site's Call buttons point at this exact string. A `tel:` that lost its
	# country code would work on the phone of whoever tested it and nowhere else.
	assert_eq(Service.tel_url(), SITE["tel"], "the game must dial the number the site dials")


func test_the_number_is_written_both_ways_and_they_agree() -> void:
	# Two constants for one number, because a dialler and a reader want different
	# shapes of it — so the thing worth pinning is that they are the same digits.
	var spoken_digits: String = Service.PHONE_SPOKEN.replace("-", "")
	assert_eq(Service.PHONE_SPOKEN, SITE["spoken"], "the printed number must be the site's")
	assert_true(
		Service.PHONE_E164.ends_with(spoken_digits),
		"the dialled number must be the printed one with a country code on it"
	)
