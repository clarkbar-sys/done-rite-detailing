## The one link out of the game: the film of the job being done, and the two
## ways a build has of opening it.
##
## [b]Why a link and not the film itself.[/b] Playing it in the bay would mean
## the engine's Theora playback, and [code]module_theora_enabled[/code] is one
## of the ~40 modules [code]web/build_profile.json[/code] compiles out of the
## template this project builds for itself — see STANDARDS.md "The engine
## itself", which measures that profile at 3.3 MB off what a player downloads.
## Turning a module back on to play one clip would spend a slice of that, put
## the clip itself inside the pack on top, and hand the game a decoder it uses
## on exactly one screen of five. A link spends nothing: the film is hosted
## where film is already free to host, the bundle does not grow by a byte, and
## the player watches it at whatever resolution their connection can take
## rather than the one that fitted in the download.
##
## [b]Why that is a class rather than three lines on the screen that presses
## it.[/b] Two of the three lines are I/O — a call into the browser and a call
## into the desktop's shell — and neither can be run in a test without opening a
## window on whoever is running the suite. Split this way, the part that is
## pure is the part that can be wrong: the snippet the browser is handed. See
## [method new_tab_js] and [code]tests/unit/test_watch_video.gd[/code]. It is
## the same seam [method BuildInfo.parse_stamp] is drawn along, for the same
## reason.
class_name WatchVideo
extends RefCounted

## The film.
##
## [b]Placeholder.[/b] There is no film yet; #227 swaps in the real link and
## this is the one line it touches. Nothing else here reads the address —
## [method open] and [method new_tab_js] behave the same whatever it points at
## — which is why the screen and its tests could ship ahead of the shoot rather
## than waiting on it.
const URL: String = "https://www.youtube.com/watch?v=PLACEHOLDER"


## Opens [constant URL] in a new tab, by whichever of the two routes this build
## has.
##
## [b]Call this straight out of a [code]pressed[/code] handler and out of
## nothing else.[/b] A browser only lets a page open a window while it is still
## crediting a gesture the player made — transient activation, a few seconds
## wide and spent by the first thing that uses it — so an [code]await[/code], a
## [Timer] or a [method Object.call_deferred] on the way here is not a delay,
## it is the difference between a tab opening and a popup being blocked with no
## error anybody ever sees. That is also why neither branch below returns
## anything worth waiting on: both are one call, and being one call is the
## point.
##
## [b]The web branch and the desktop branch are not two ways of doing the same
## thing.[/b] [method OS.shell_open] on the web export hands the address to the
## engine's own web glue rather than to a browser that is already running the
## page, and what that does with a target is not something this screen should
## be guessing at; [code]window.open[/code] is what a page on the web has for
## this, and the gesture rule above is a browser rule with no desktop
## equivalent. So the feature is written twice, deliberately, and
## [method OS.has_feature] picks — the same switch
## [method Settings.sync_web] is written against.
static func open() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval(new_tab_js(URL))
		return
	# Desktop hands the address to whatever the system calls a browser. The
	# return says the shell was asked, not that anything opened, so the only
	# honest thing to do with it is say so in the log — a player who pressed a
	# button and got nothing is owed a line somewhere, and this is the only
	# place that knows.
	var asked: Error = OS.shell_open(URL)
	if asked != OK:
		push_warning("could not open %s: %s" % [URL, error_string(asked)])


## The one statement the browser is asked to run, for [param url].
##
## [code]_blank[/code] rather than a named target, because a named one is
## reused: a player who pressed the button twice would find the second press
## replacing the tab the first one opened, which from where they are sitting
## looks like a button that stopped working.
##
## [b]The address is quoted by [method JSON.stringify] rather than by hand.[/b]
## It goes into a JavaScript string literal, and a JSON string literal is one —
## so an address carrying a quote, a backslash or a newline comes out escaped
## instead of ending the string early and handing the browser a syntax error.
## That is not a hypothetical: [constant URL] is a placeholder somebody will
## paste over in one edit, from a page whose address bar is full of query
## parameters, and a broken snippet fails in a browser on a build CI cannot
## open — the same class of failure the build profile's own test exists for.
static func new_tab_js(url: String) -> String:
	return 'window.open(%s, "_blank");' % JSON.stringify(url)
