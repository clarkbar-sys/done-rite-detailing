## What Done Rite actually sells, and the number you book it on — the business
## half of the site, transcribed the way [Brand] transcribes its look.
##
## The game is named after a real business and already wears its palette. What
## it has never carried is the thing the business is [i]for[/i]: a visitor to
## [url=https://bespoke-cascaron-816d86.netlify.app]the site[/url] is offered
## four named services and a phone number, and a player who has just spent seven
## minutes learning by hand how long one car takes has been offered neither. This
## class is the four names and the number, in one place, so the game can say them
## without inventing its own wording for work somebody is being paid to do.
##
## [b]Transcribed, not invented.[/b] Every string below is lifted from the page
## verbatim — the four [code]<h3>[/code]s of its services grid and the
## [code]tel:[/code] its Call buttons point at — for exactly the reason [Brand]'s
## hexes are: a game that renamed "Wheel & Tire Shine" to "Tyres" would be
## advertising a service the business does not list. [code]tests/unit/test_service.gd[/code]
## holds this file to the page a second time rather than to itself.
##
## [b]The number is one string, in E.164, plus one for reading.[/b] A dialler
## wants [code]+13307804778[/code] and a person wants [code]330-780-4778[/code],
## and the two are not derivable from each other without knowing which country
## the business is in — so both are written down and [method tel_url] is the only
## place the scheme is spelled.
##
## [b]Node-free, like everything in [code]src/core/[/code].[/b] There is
## deliberately no [code]call_now()[/code] here wrapping [method OS.shell_open]:
## a URL is a value a unit test can assert, and opening one is a side effect on
## the machine running the test. The screens do the opening; this decides what
## gets opened.
class_name Service
extends RefCounted

## The exterior wash — the pass the power wash and the sponge are doing.
const HAND_WASH_AND_DRY: String = "Hand Wash & Dry"

## The one service with no tool on the belt. Kept here anyway, because
## [method menu] is the site's menu and a menu missing an item is not one — and
## because the gap is a decision worth being able to see rather than an omission
## nobody wrote down. The car has no inside to clean yet; the day it has,
## this is the string the tool takes.
const INTERIOR_DEEP_CLEAN: String = "Interior Deep Clean"

## The wheels — the tyre cleaner's pass, and the only tool on the belt that is
## the whole of a service on its own.
const WHEEL_AND_TIRE_SHINE: String = "Wheel & Tire Shine"

## The finish that outlasts the wash — the drying rag's buff.
const PROTECT_AND_MAINTAIN: String = "Protect & Maintain"

## The number, as somebody reads it aloud.
const PHONE_SPOKEN: String = "330-780-4778"

## The same number as a dialler wants it: E.164, country code and all. A
## [code]tel:[/code] built out of [constant PHONE_SPOKEN] works on a phone that
## happens to be in the same country and fails everywhere else.
const PHONE_E164: String = "+13307804778"


## The four services, in the order the site's own grid lists them.
##
## A method rather than a [code]const Array[/code] for the reason
## [method DetailingTool.catalogue] is one: a shared constant array is a mutable
## global that any caller can rewrite for every other caller. Four strings copied
## on demand is not a cost worth designing around.
static func menu() -> PackedStringArray:
	return PackedStringArray(
		[HAND_WASH_AND_DRY, INTERIOR_DEEP_CLEAN, WHEEL_AND_TIRE_SHINE, PROTECT_AND_MAINTAIN]
	)


## The business's phone number as a URL: what to hand [method OS.shell_open] to
## put the dialler on screen.
##
## [code]tel:[/code] and not a form, a booking page or a mailto, because that is
## the whole of what the site offers today — its Call buttons point at this exact
## string. One scheme, handled by the OS on every platform this game ships to: a
## dialler on a phone, whatever the desktop has registered otherwise, and the
## browser's own handler on the web build. No plugin and no web-only path.
static func tel_url() -> String:
	return "tel:%s" % PHONE_E164
