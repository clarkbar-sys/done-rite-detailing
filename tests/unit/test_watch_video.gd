## Unit tests for [WatchVideo] — the link out to the film, and the one line of
## JavaScript the web build hands the browser to open it.
##
## [b]What is deliberately not tested is the opening itself.[/b]
## [method OS.shell_open] would open a browser on whoever is running the suite,
## and [method JavaScriptBridge.eval] does nothing at all outside one — so a
## test of [method WatchVideo.open] would either be a nuisance or a lie. That is
## the reason the class is split the way it is: everything that can be wrong
## quietly is on this side of the seam.
##
## [b]And "quietly" is the whole point.[/b] A malformed address is not a compile
## error, not an export error and not a warning — it is a button that does
## nothing, on a published page, for whichever half of the players are on the
## web build. #227 will edit [constant WatchVideo.URL] and nothing else, so what
## these tests guard is exactly what that edit can break.
extends GutTest

## An address with every character that could end a JavaScript string early in
## it, and one that could not: a quote, a backslash, and a query parameter of
## the kind a real link is made of.
const AWKWARD_URL: String = 'https://example.test/watch?v=a"b\\c&t=1'


func test_the_link_is_an_https_youtube_address() -> void:
	# https because a browser opening a plain-http tab out of an https page is a
	# mixed-content warning on the way to the film, and YouTube because that is
	# the decision #175 settled: the film is hosted where film is free to host.
	assert_true(
		WatchVideo.URL.begins_with("https://"),
		"the film must be opened over https: %s" % WatchVideo.URL
	)
	assert_true(
		WatchVideo.URL.contains("youtube.com") or WatchVideo.URL.contains("youtu.be"),
		"the film lives on YouTube: %s" % WatchVideo.URL
	)


func test_the_link_is_a_single_unbroken_address() -> void:
	# A pasted link that arrived with a newline or a stray space on it is the
	# most likely way #227 goes wrong, and the symptom would be a tab that opens
	# on a search page rather than the film.
	assert_false(WatchVideo.URL.contains(" "), "a link with a space in it is not a link")
	assert_eq(WatchVideo.URL.strip_edges(), WatchVideo.URL, "the link carries whitespace around it")


func test_the_snippet_opens_the_link_in_a_tab_of_its_own() -> void:
	var snippet: String = WatchVideo.new_tab_js(WatchVideo.URL)
	assert_true(
		snippet.begins_with("window.open("),
		"the web build opens the film with window.open: %s" % snippet
	)
	assert_true(
		snippet.contains(WatchVideo.URL), "the snippet must carry the address: %s" % snippet
	)
	assert_true(
		snippet.contains('"_blank"'),
		(
			"a named target would be reused, so a second press would replace the first tab: %s"
			% snippet
		)
	)


func test_the_snippet_is_one_statement_with_nothing_to_wait_for() -> void:
	# The browser rule this whole design is shaped by: a page may open a window
	# only while it is still being credited with a gesture the player made, and
	# the first thing that waits spends it. So the snippet is one call, made on
	# the line the button was pressed — anything below would be a popup blocked
	# in silence on the published page and nowhere else.
	var snippet: String = WatchVideo.new_tab_js(WatchVideo.URL)
	assert_eq(snippet.count(";"), 1, "one statement, not a script: %s" % snippet)
	for waiting: String in ["await", "setTimeout", "requestAnimationFrame", "then("]:
		assert_false(
			snippet.contains(waiting), "%s would spend the gesture the tab is opened on" % waiting
		)


func test_an_address_cannot_break_out_of_the_string_it_is_quoted_in() -> void:
	# The failure this stands in front of: a link pasted in with a quote or a
	# backslash in it ends the JavaScript string early, and what reaches the
	# browser is a syntax error rather than a tab. It type-checks, it exports,
	# and it fails on a page CI never opens — so the quoting is done by
	# JSON.stringify rather than by hand, and this is what says so.
	var snippet: String = WatchVideo.new_tab_js(AWKWARD_URL)
	assert_false(
		snippet.contains('/watch?v=a"b'),
		"the quote in the address was written through raw: %s" % snippet
	)
	assert_true(snippet.contains('a\\"b'), "the quote must arrive escaped: %s" % snippet)
	assert_true(snippet.contains("b\\\\c"), "the backslash must arrive escaped: %s" % snippet)
	assert_eq(snippet.count(";"), 1, "and it is still one statement: %s" % snippet)


func test_the_link_as_it_stands_needs_no_escaping() -> void:
	# Reading the same rule from the other end. The placeholder — and any
	# ordinary YouTube link that replaces it — comes out of the quoting
	# untouched, so what a person sees in the browser's console is the address
	# they pasted. A day the snippet grows escapes, the link has something in it
	# worth looking at.
	assert_false(
		WatchVideo.new_tab_js(WatchVideo.URL).contains("\\"),
		"an ordinary link should quote to itself: %s" % WatchVideo.URL
	)
