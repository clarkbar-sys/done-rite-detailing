## Unit tests for [code]web/shell.html[/code] — the loading screen the web
## bundle is served with.
##
## Under tests/unit/ because it needs no tree, no window and no frame: the
## thing under test is a file on disk, and every claim below is made by reading
## it. There is no [code]src/[/code] script to pair this with, which is exactly
## why it is here — the shell is the one player-visible surface in the project
## that no type check, no smoke run and no export can fail on. Godot's exporter
## substitutes placeholders it finds and silently ignores the ones it does not,
## so a shell missing [code]$GODOT_URL[/code] exports cleanly, publishes
## cleanly, and boots to a blank canvas in a browser nobody ran.
##
## [b]What these tests are, and are not.[/b] They are a wiring gate: the
## placeholders the engine fills in, and the ids its own script reaches for by
## name. They say nothing about whether the screen looks right — that is a
## screenshot and a judgement, and this file would be lying if it implied
## otherwise. What they catch is the class of edit that makes the page stop
## being a game: a tidy-up that drops a `$GODOT_*` token, or a rename that
## leaves [code]getElementById('status-progress')[/code] pointing at nothing.
extends GutTest

## Where the shell lives. The same path is in export_presets.cfg's
## [code]html/custom_html_shell[/code]; if this file moves, both move.
const SHELL_PATH: String = "res://web/shell.html"

## The tokens the exporter replaces, from
## platform/web/export/export_plugin.cpp (4.7.1). The first three are what make
## the page a game at all — the engine script's URL, the config object it is
## constructed with, and the threading flag its feature check reads. The rest
## are the loading screen itself: the splash image and its classes, the colour
## behind it, the project's name, and the slot the exporter puts the favicon
## links into.
const PLACEHOLDERS: Array[String] = [
	"$GODOT_URL",
	"$GODOT_CONFIG",
	"$GODOT_THREADS_ENABLED",
	"$GODOT_SPLASH",
	"$GODOT_SPLASH_CLASSES",
	"$GODOT_SPLASH_COLOR",
	"$GODOT_PROJECT_NAME",
	"$GODOT_HEAD_INCLUDE",
]

## The ids the shell's own script looks up by name. A stylesheet can be wrong
## and the game still runs; one of these going missing is a null dereference
## during startup, which is a blank page.
const SCRIPTED_IDS: Array[String] = ["status", "status-progress", "status-notice"]

var _shell: String = ""


func before_all() -> void:
	var file: FileAccess = FileAccess.open(SHELL_PATH, FileAccess.READ)
	if file != null:
		_shell = file.get_as_text()
		file.close()


## Read once in [method before_all] rather than per test, and asserted here
## rather than there: GUT counts assertions per test, and a failure in a hook
## reports against whichever test happened to run first.
func test_the_shell_exists_where_the_preset_points() -> void:
	var why: String = (
		"export_presets.cfg points html/custom_html_shell at %s; without it "
		+ "the export quietly falls back to the stock grey shell"
	)
	assert_true(FileAccess.file_exists(SHELL_PATH), why % SHELL_PATH)
	assert_false(_shell.is_empty(), "%s must not be empty" % SHELL_PATH)


func test_every_exporter_placeholder_survives() -> void:
	for token: String in PLACEHOLDERS:
		assert_true(
			_shell.contains(token),
			(
				"%s must keep %s — the exporter fills it in and warns about nothing"
				% [SHELL_PATH, token]
			)
		)


func test_the_ids_the_script_reaches_for_are_defined() -> void:
	for id: String in SCRIPTED_IDS:
		assert_true(
			_shell.contains('id="%s"' % id),
			'%s must define id="%s" — its own script looks it up by name' % [SHELL_PATH, id]
		)


## The CSS is a transcription of [Brand], because CSS in a file the engine
## never loads cannot read a GDScript constant. This is what holds the copy to
## the original, the same way [code]test_brand.gd[/code] holds [Brand] to the
## site's stylesheet.
func test_the_bar_and_the_card_wear_the_brand() -> void:
	_assert_drawn_in(Brand.RED, "the progress bar's fill")
	_assert_drawn_in(Brand.PANEL, "the card behind the logo, and the bar's track")
	_assert_drawn_in(Brand.MUTED, "the name under the logo")


## Asserts the shell's CSS mentions [param colour], which draws [param what].
##
## Matched as the six-digit hex the CSS is written in — [method Color.to_html]
## with no alpha, lowercase, which is the form both files agree on.
func _assert_drawn_in(colour: Color, what: String) -> void:
	var hex: String = colour.to_html(false)
	assert_true(
		_shell.contains("#%s" % hex),
		"%s must draw %s in #%s, as Brand does" % [SHELL_PATH, what, hex]
	)


## The loading screen is the first player-facing surface in the whole project,
## and until #174 it was the last one still printed in a web sans. It cannot
## reach into the [code].pck[/code] for the game's own type, so the [Makefile]
## copies [constant Brand.BODY_FACE] in beside [code]index.html[/code] and the
## shell names it by filename.
##
## Three things have to stay true together for that to work, and none of them
## is visible in the other two files: the shell has to declare the face, it has
## to name the file the Makefile actually copies, and the game has to still be
## set in the same one. Asserted off [constant Brand.BODY_FACE] rather than
## against a string typed here, so repointing the game's reading face fails
## here instead of leaving the loading screen quietly on the old one.
func test_the_loading_screen_is_set_in_the_games_own_reading_face() -> void:
	var file_name: String = Brand.BODY_FACE.resource_path.get_file()
	assert_true(
		_shell.contains("@font-face"),
		"%s must declare the game's face rather than fall back to a web sans" % SHELL_PATH
	)
	assert_true(
		_shell.contains("url('%s')" % file_name),
		"%s must name %s — the file `make build-web` copies in" % [SHELL_PATH, file_name]
	)
	assert_true(
		_shell.contains("font-family: 'Silkscreen', "),
		"%s must put the face in front of the fallback stack, not beside it" % SHELL_PATH
	)
	# Same rule as the logo below: one home for the asset. A base64 copy here
	# would be a second one, and the only thing that would notice it had drifted
	# is a person looking at a loading screen.
	assert_false(_shell.contains("data:font"), "%s must not inline the typeface" % SHELL_PATH)
	assert_false(
		_shell.contains("data:application/font"), "%s must not inline the typeface" % SHELL_PATH
	)


## The one style rule with a behaviour behind it rather than a look.
##
## The engine hands [code]onProgress[/code] a total of 0 when it cannot work
## one out, and the shell's script answers that by removing the
## [code]value[/code] attribute. A styled [code]<progress>[/code] in that state
## paints an empty track and stays there, so the shell carries a
## [code]:not([value])[/code] rule that sweeps a band across it instead.
##
## This is the rule most likely to be deleted by someone tidying up, because
## the state it covers does not appear on the bundle as it ships — the
## exporter bakes both file sizes into [code]GODOT_CONFIG.fileSizes[/code], so
## the bar is determinate today. The shell's own comment has the reading of
## index.js behind that sentence. A test rather than a comment alone because
## "correct in a case you cannot currently reach" is exactly what gets
## refactored away.
func test_the_bar_still_moves_when_the_total_is_unknown() -> void:
	assert_true(
		_shell.contains("#status-progress:not([value])"),
		"%s must style the valueless bar — see the rule's comment" % SHELL_PATH
	)
	assert_true(
		_shell.contains("@keyframes status-sweep"),
		"%s must keep the sweep the valueless bar animates" % SHELL_PATH
	)


## The shell names no asset, and must not start.
##
## The logo reaches the page through [code]application/boot_splash/image[/code]
## and the exporter's [code]$GODOT_SPLASH[/code], which is what keeps
## assets/brand/ the single home of the artwork. A hard-coded filename or an
## inlined data URI here would be a second copy, drifting quietly from the one
## the game itself draws.
func test_the_logo_is_not_copied_into_the_shell() -> void:
	assert_false(
		_shell.contains("done-rite-logo"),
		"%s must reach the logo through $GODOT_SPLASH, not by name" % SHELL_PATH
	)
	assert_false(
		_shell.contains("data:image"),
		"%s must not inline an image — assets/brand/ is where the artwork lives" % SHELL_PATH
	)
