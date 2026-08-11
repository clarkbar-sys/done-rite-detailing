## Unit tests for [code]site/index.html[/code] — the detailing business's page,
## which is what GitHub Pages now serves at the root with the game under
## [code]play/[/code].
##
## Under tests/unit/ for [code]test_web_shell.gd[/code]'s reason, and this file
## is that one's sibling in every sense: the thing under test is a file on disk,
## read and asserted, and it is a surface no type check, no smoke run and no
## export can fail on. A page that has lost its badge exports cleanly, publishes
## cleanly, and is a detailing site with no game on it.
##
## [b]What these tests are, and are not.[/b] A wiring gate, not a design review.
## They do not say the badge looks right — that is a screenshot and a judgement,
## and #220 was settled with two of them at 1280x800 and 390x844. What they
## catch is the class of edit that quietly breaks the arrangement the issue was
## about: a badge pointing at an absolute URL (which strands every PR preview on
## the published game), an embed creeping in where a link belongs, or the
## reduced-motion escape hatch being tidied away.
extends GutTest

## Where the page lives. The workflow copies this folder to the root of
## gh-pages; if it moves, `Assemble the published site` in ci-godot.yml moves.
const PAGE_PATH: String = "res://site/index.html"

## The badge's link target. [b]Relative on purpose.[/b] A PR preview is served
## from pr-preview/pr-<n>/, so an absolute
## https://clarkbar-sys.github.io/done-rite-detailing/play/ would send every
## preview's badge to the live game instead of the one being reviewed — the
## exact bug a preview exists to catch, in the link the preview is for.
const PLAY_HREF: String = "href=\"play/\""

## What must never appear. The game is ~40 MB and the homepage is a marketing
## page for a business whose front door is a phone number: the build is fetched
## when somebody presses the badge and at no other time. An iframe or a prefetch
## here is not a style question, it is the ordering rule from #75 being lost.
const NEVER: Array[String] = ["<iframe", "rel=\"prefetch\"", "rel=\"preload\""]

## The phone number, in the two forms the page offers it in. If a rework of this
## file drops one, the business has lost its front door and the game has become
## the point, which is backwards.
const CONTACTS: Array[String] = ["tel:+13307804778", "sms:+13307804778"]

var _page: String = ""


func before_all() -> void:
	var file: FileAccess = FileAccess.open(PAGE_PATH, FileAccess.READ)
	if file != null:
		_page = file.get_as_text()


## The page is there and is not empty — every other assertion reads as a vacuous
## pass on an empty string, so this one guards the rest.
func test_the_page_is_readable() -> void:
	assert_gt(_page.length(), 0, "%s is missing or empty" % PAGE_PATH)


## The badge exists and points at the game, relatively.
func test_the_badge_links_to_the_game() -> void:
	assert_string_contains(_page, "class=\"play-badge\"", "the play badge is gone")
	assert_string_contains(_page, PLAY_HREF, "the badge must link to the relative play/")


## A new tab, and a safe one. [code]target="_blank"[/code] is the decision from
## #220 — the business page stays open behind the game, so a quote is a tab away
## rather than a back button away — and [code]rel="noopener"[/code] is what
## stops the opened page reaching back through [code]window.opener[/code].
func test_the_badge_opens_a_new_tab_safely() -> void:
	assert_string_contains(_page, "target=\"_blank\"", "the badge should open a new tab")
	assert_string_contains(_page, "rel=\"noopener\"", "target=_blank without rel=noopener")


## The motion can be turned off. An animation that loops forever with no
## reduced-motion escape is an accessibility bug, and it is one only a browser
## would ever have shown us.
func test_the_animation_respects_reduced_motion() -> void:
	assert_string_contains(
		_page, "prefers-reduced-motion", "the badge bobs with no reduced-motion opt-out"
	)


## A link, not an embed — see [constant NEVER].
func test_the_game_is_never_loaded_by_the_page() -> void:
	for token: String in NEVER:
		assert_false(
			_page.contains(token), "%s on the homepage: the game must be a link, not a load" % token
		)


## The business is still reachable from its own front page.
func test_the_phone_number_survives() -> void:
	for contact: String in CONTACTS:
		assert_string_contains(_page, contact, "the page lost %s" % contact)


## The badge is big enough to hit with a thumb, on both of the sizes it is
## styled at — 52 px in the desktop rule and 48 px in the phone one. Same bar
## every other control in this project clears, from the same constant, so a
## future trim of the badge cannot quietly go under it.
func test_the_badge_is_a_real_touch_target() -> void:
	var floor_px: int = int(TouchTarget.MIN_REFERENCE_PX)
	var heights: PackedStringArray = _min_heights_after("play-badge")
	assert_gt(heights.size(), 0, "no min-height on .play-badge at all")
	for height: String in heights:
		assert_gte(
			int(height),
			floor_px,
			"a .play-badge min-height of %s px is under the %d px floor" % [height, floor_px]
		)


## Every [code]min-height:<n>px[/code] written in a rule naming [param selector].
##
## Deliberately a scan rather than a parse: this project has no CSS parser and
## does not want one, and what is being asserted is a number in a stylesheet,
## not a cascade. Reads each rule that mentions the selector up to its closing
## brace and pulls the min-heights out of it.
func _min_heights_after(selector: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var from: int = 0
	while true:
		var at: int = _page.find(selector, from)
		if at == -1:
			break
		var end: int = _page.find("}", at)
		if end == -1:
			end = _page.length()
		var rule: String = _page.substr(at, end - at)
		var mark: int = rule.find("min-height:")
		if mark != -1:
			var tail: String = rule.substr(mark + "min-height:".length())
			var digits: String = ""
			for index: int in range(tail.length()):
				if not tail[index].is_valid_int():
					break
				digits += tail[index]
			if digits != "":
				found.append(digits)
		from = at + selector.length()
	return found
