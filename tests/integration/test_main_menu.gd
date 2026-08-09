## Integration test for the main menu: the lockup, the three pills, and which
## transition — and which mode — each of them asks for.
##
## Under tests/integration/ for [code]test_title_screen.gd[/code]'s reason —
## every fact here is established in `_ready()`, so nothing below can be
## asserted by loading the script alone.
##
## [b]What is deliberately not repeated from the title screen's suite.[/b] The
## build label and the attract bay are asserted here because they are promises
## this screen makes on its own account, but the shape of the brand pill, the
## touch-target arithmetic and the tap-versus-click behaviour are all
## [code]test_title_screen.gd[/code]'s, and the mechanism is shared —
## [method GameScreen.dress_loud] and one Button. What is tested here is what is
## different: that there are three of them, that they are dressed differently,
## that they lead to different places — and, for the two that lead to the same
## place, that they get there with a different clock.
extends GutTest

const MAIN_MENU: String = "res://src/screens/main_menu.tscn"

## Where every model the game loads lives, one directory each.
##
## Walked rather than listed, so a model that arrives without a credit fails a
## test instead of shipping quietly — see
## [method test_every_model_directory_is_either_credited_or_first_party].
const MODELS_DIR: String = "res://assets/models"

## The borrowed works, one row per directory under [constant MODELS_DIR]:
##
## [codeblock]
## [directory, title of the work, who made it, what the credit calls it,
##  the script that changes it — "" if the file is placed as it was downloaded]
## [/codeblock]
##
## The title and the author are two of the three things CC-BY 4.0 asks a credit
## to carry, the licence itself is the third, and the last column is the fourth
## thing the licence asks for and the one this list exists to keep honest: an
## indication of whether the material was modified. Every row's script is
## checked to exist, so "modified" is a fact about the repository rather than a
## claim in a table.
##
## The directory is the first column because it is what makes this list a
## coverage check rather than a wish: the tests below read
## [constant MODELS_DIR] and require every directory in it to appear here or in
## [constant FIRST_PARTY], which is what stops the twelfth model from being the
## one nobody credited.
const BORROWED: Array[Array] = [
	["cars", "Generic passenger car pack", "Comrade1280", "Cars", "build-car-pack.py"],
	["cleaning_spray", "Kitchen Spray", "Jesus Osco", "Bottles", "build-tire-cleaner.py"],
	["sponge", "Sponge", "Aullwen", "Sponge", "build-sponge.py"],
	["driveway", "Sunken Driveway Parking Spot", "jimbogies", "Driveway", ""],
]

## The model directories that owe nobody a credit, because the game drew what is
## in them.
##
## Named rather than inferred, and that is the point: a directory that is in
## neither this list nor [constant BORROWED] is a model somebody added without
## deciding where it came from, and that is the failure this pair is for.
const FIRST_PARTY: Array[String] = ["pressure_washer"]

## Where the bakes named in [constant BORROWED] live.
const BUILD_SCRIPTS: String = "res://scripts/"

## The file every model directory carries saying where its contents came from —
## for whoever clones the repo, where the menu's line is for whoever plays it.
const ATTRIBUTION: String = "ATTRIBUTION.txt"

var _screen: GameScreen = null
var _requested: Array[GameState] = []
var _rung: Array[Bell.Voice] = []
var _faded: Array[float] = []
var _window_size_before: Vector2i = Vector2i.ZERO
var _muted_before: bool = false
var _chosen_before: String = ""
var _mode_before: GameMode.Kind = GameMode.Kind.ARCADE


func before_each() -> void:
	_requested = []
	_rung = []
	_faded = []
	# This screen writes the player's car into [CarChoice] the moment it opens —
	# it adopts whatever the bay drew — and the pick is process-wide, so a suite
	# that walked away from one would decide which car every later suite's bay
	# parks. Snapshotted before the screen exists and put back in after_each, the
	# same care [member Sound.muted] gets above. Cleared as well as saved, so the
	# tests below start from a run nobody has chosen in.
	_chosen_before = CarChoice.chosen
	CarChoice.forget()
	# The menu's own toggle opens agreeing with whatever [Sound] was already at —
	# see src/ui/sound_toggle.gd — so a suite that left the game muted would open
	# this screen silenced too, for a reason that has nothing to do with this
	# one. Put back in after_each, like the window size below.
	_muted_before = Sound.muted
	Sound.set_muted(false)
	# And the mode, for CarChoice's reason word for word: pressing either of the
	# two mode pills writes a process-wide field that every later suite's play
	# screen would then read.
	_mode_before = GameMode.chosen
	GameMode.forget()
	# A headless window is 64x64 — smaller than either button, small enough that
	# a tap at a button's own coordinates lands outside the layout entirely.
	# `content_scale_size` is the design resolution from project.godot, so this
	# makes a coordinate in this file mean what it means on screen. Put back in
	# after_each: every suite shares this window.
	var root: Window = get_tree().root
	_window_size_before = root.size
	root.size = root.content_scale_size
	var packed: PackedScene = load(MAIN_MENU) as PackedScene
	assert_not_null(packed, "could not load %s" % MAIN_MENU)
	if packed == null:
		return
	# Instantiated into a typed local before handing it to add_child_autofree —
	# GUT's helper is untyped, and autofree is what keeps a failing assertion
	# below from being reported as a leak against whichever test runs next.
	var screen: GameScreen = packed.instantiate() as GameScreen
	_screen = screen
	add_child_autofree(_screen)
	_screen.transition_requested.connect(_record)
	_screen.bell_requested.connect(_record_bell)
	_screen.music_stop_requested.connect(_record_fade)
	# `_ready()` has already fired inside add_child; the frame is only here to
	# let layout settle before the sizes below are read.
	await wait_process_frames(1)


func after_each() -> void:
	get_tree().root.size = _window_size_before
	Sound.set_muted(_muted_before)
	CarChoice.choose(_chosen_before)
	GameMode.choose(_mode_before)


func _record(state: GameState) -> void:
	_requested.append(state)


func _record_bell(voice: Bell.Voice) -> void:
	_rung.append(voice)


func _record_fade(seconds: float) -> void:
	_faded.append(seconds)


func _arcade_button() -> Button:
	return _screen.get_node("%Arcade") as Button


func _simulation_button() -> Button:
	return _screen.get_node("%Simulation") as Button


func _how_to_play_button() -> Button:
	return _screen.get_node("%HowToPlay") as Button


## The two pills that lead into the bay, in the order they are drawn.
func _mode_buttons() -> Array[Button]:
	return [_arcade_button(), _simulation_button()]


## Every pill on the screen. The car arrows are buttons too and are deliberately
## not in here — they are an icon on a round plate, which is
## [code]src/ui/car_arrow.gd[/code]'s shape and
## [code]tests/integration/test_main_menu_cars.gd[/code]'s suite.
func _pills() -> Array[Button]:
	return [_arcade_button(), _simulation_button(), _how_to_play_button()]


## The box [param credits] actually draws its lines in.
##
## Bottom-aligned inside its own rect (see [code]main_menu.tscn[/code]), so the
## text sits on the bottom of the box and the unused height is above it — which
## is the half that matters here, because what is above it is the menu.
func _drawn_credit(credits: Label) -> Rect2:
	var font: Font = credits.get_theme_font("font")
	var size: int = credits.get_theme_font_size("font_size")
	var widest: float = 0.0
	for line: String in credits.text.split("\n"):
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	var box: Rect2 = credits.get_global_rect()
	var tall: float = credits.get_line_count() * credits.get_line_height()
	return Rect2(Vector2(box.position.x, box.end.y - tall), Vector2(widest, tall))


## The box [param pill]'s own words are drawn in — centred both ways in a button
## that is mostly padding, and the only part of it a credit can be said to be
## drawn across.
func _drawn_label(pill: Button) -> Rect2:
	var words: Vector2 = pill.get_theme_font("font").get_string_size(
		pill.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pill.get_theme_font_size("font_size")
	)
	var box: Rect2 = pill.get_global_rect()
	return Rect2(box.position + (box.size - words) * 0.5, words)


func _sound_toggle() -> SoundToggle:
	return _screen.get_node("%Sound") as SoundToggle


func test_the_screen_is_a_game_screen() -> void:
	# The host casts to [GameScreen] and refuses anything else, so a scene that
	# lost its script would boot to an empty window.
	assert_not_null(_screen, "the main menu must instantiate as a GameScreen")


func test_it_is_played_over_the_bay_working_itself() -> void:
	# The menu is the title card with one more pill, and that includes what is
	# behind it: a flat panel here would be a screen the attract mode disappears
	# behind, one press after it was the best argument the game made for itself.
	var garage: Garage = _screen.get_node("Garage") as Garage
	assert_not_null(garage, "the menu is played over the real room, not a picture of it")
	if garage == null:
		return
	assert_true(garage.attracting, "the bay must still be working behind the menu")
	assert_true(garage.first_person, "and somebody must still be standing in it")


func test_build_label_shows_the_build_identity() -> void:
	# The label stays top-right across the new screen. Same promise the title
	# card makes, made again where a player now spends time before starting.
	var build: Label = _screen.get_node("%Build") as Label
	assert_eq(build.text, BuildInfo.describe())


func test_it_shows_the_business_logo() -> void:
	var logo: TextureRect = _screen.get_node("%Logo") as TextureRect
	assert_not_null(logo, "the menu must show the lockup, like the card before it")
	if logo == null:
		return
	assert_not_null(logo.texture, "the logo's texture must have imported")
	assert_gt(logo.size.x, 0.0, "and must be laid out, not collapsed to nothing")


func test_the_logo_is_framed_rather_than_pasted_on() -> void:
	# The artwork carries its own black background, so without the card it reads
	# as a hole cut in the garage behind it. [Brand.card] has that argument.
	var card: PanelContainer = _screen.get_node("%LogoCard") as PanelContainer
	var box: StyleBoxFlat = card.get_theme_stylebox("panel") as StyleBoxFlat
	assert_not_null(box, "the logo must sit in a brand card")
	if box == null:
		return
	assert_eq(box.bg_color, Brand.PANEL, "the card must be the site's panel colour")


# ---- the credits the borrowed models arrive under ----------------------------


func test_every_borrowed_model_is_credited_where_a_player_can_read_it() -> void:
	# CC-BY 4.0 is the licence the cars, the tyre cleaner's bottle, the sponge and
	# the driveway all arrive under, and attribution is a condition of it, not a
	# courtesy. A file in the repository does not discharge that — the person
	# playing the game never sees one — so the credit has to be on a screen, and
	# this is the screen every player passes through.
	#
	# Every work, and all three parts of each by name, because the licence asks
	# for all three and a line that lost one of them would still look like a
	# credit: the title of the work, who made it, and what licence it is under.
	# What the game uses it for is on the line too and checked here with them —
	# not a licence condition, but the thing that makes a title on a menu mean
	# anything to the person reading it.
	#
	# Substrings rather than the whole string, so the wording around them stays
	# the .tscn's business — including how many of them share a line, which was
	# 2 + 2 + 1 while the power wash was a borrowed flamethrower and is 2 + 2 now
	# that the wand is drawn by this project (#162) and owes nobody anything, with
	# the modification note of #159 under both.
	#
	# Off [constant BORROWED] rather than a list written out here, so this suite
	# has one idea of what was borrowed and the coverage check below can hold it
	# against what is actually on disk.
	var credits: Label = _screen.get_node("%Credits") as Label
	assert_not_null(credits, "the menu must carry the credits for the borrowed models")
	if credits == null:
		return
	for work: Array in BORROWED:
		for required: String in [work[1], work[2], work[3]]:
			assert_string_contains(credits.text, required, "the credit must name %s" % required)
	assert_string_contains(credits.text, "CC BY 4.0", "the credit must name the licence")


func test_the_credit_says_which_of_the_models_were_changed() -> void:
	# The fourth thing CC-BY 4.0 asks for, and the one this menu went years
	# without: 3(a)(1)(B) wants an indication that the material was modified,
	# alongside the title, the author and the licence the test above checks. Three
	# of these four are modified — baked into the shapes the game wants by the
	# scripts named in [constant BORROWED] — and the driveway is the artist's file
	# placed as it was downloaded, so the note has to distinguish them rather than
	# say "some of this was changed".
	#
	# The note is the last line, and the semicolon in it is the contract: what is
	# changed is named before it and what is not is named after. That is a real
	# coupling to the wording in main_menu.tscn, and it is the cheapest one that
	# can tell the two halves apart — a test that only asked whether the word
	# "modified" appeared somewhere would pass a line that put the driveway on the
	# wrong side of it, which is the one way this sentence can be wrong and still
	# look right.
	var credits: Label = _screen.get_node("%Credits") as Label
	var lines: PackedStringArray = credits.text.split("\n")
	var note: String = lines[lines.size() - 1].to_lower()
	assert_string_contains(note, "modified", "the credit must say the models were modified")
	var changed: String = note.get_slice(";", 0)
	var untouched: String = note.get_slice(";", 1)
	assert_ne(changed, note, "the note must separate what was changed from what was not")
	for work: Array in BORROWED:
		var called: String = str(work[3]).to_lower()
		var bake: String = str(work[4])
		if bake.is_empty():
			assert_string_contains(untouched, called, "%s is unmodified and must say so" % called)
			continue
		assert_string_contains(changed, called, "%s is modified and must say so" % called)
		assert_true(
			FileAccess.file_exists(BUILD_SCRIPTS + bake),
			"%s is credited as modified by a script that is not there" % called
		)


func test_every_model_directory_is_either_credited_or_first_party() -> void:
	# What "all of them" is measured against, rather than asserted about a list
	# somebody remembered to update. The credit above names four works; this is
	# what makes four the right number — every directory under assets/models/ is
	# either a borrowed work with a line on the menu or a model this project drew,
	# and a new one is neither until somebody says which.
	#
	# Both directions, because the credit has been wrong in both. A model added
	# without a credit is the licence breach; a credit left behind by a model that
	# went away is the smaller thing #162 had to clean up by hand when the
	# borrowed flamethrower became a drawn pressure washer.
	var on_disk: PackedStringArray = DirAccess.get_directories_at(MODELS_DIR)
	assert_gt(on_disk.size(), 0, "no model directories found under %s" % MODELS_DIR)
	var accounted: Array[String] = FIRST_PARTY.duplicate()
	for work: Array in BORROWED:
		accounted.append(str(work[0]))
	for directory: String in on_disk:
		assert_true(
			accounted.has(directory),
			(
				(
					"assets/models/%s is credited nowhere: add it to BORROWED and to the menu's"
					+ " credit line, or to FIRST_PARTY if this project drew it"
				)
				% directory
			)
		)
	for directory: String in accounted:
		assert_true(
			on_disk.has(directory),
			"assets/models/%s is gone — take its credit off the menu with it" % directory
		)


func test_every_model_directory_says_where_it_came_from() -> void:
	# The copy of the credit that ships to whoever clones the repository, which
	# the menu's line does not replace and which does not replace the menu's line:
	# a player never opens a .txt, and a reader of the source never sees the
	# screen. Required of the first-party directories too — "nothing here is
	# borrowed" is an answer to "where did this come from", and a directory with
	# no file at all is silence.
	for directory: String in DirAccess.get_directories_at(MODELS_DIR):
		var beside: String = "%s/%s/%s" % [MODELS_DIR, directory, ATTRIBUTION]
		assert_true(
			FileAccess.file_exists(beside),
			"assets/models/%s must say where it came from" % directory
		)


func test_the_credit_is_actually_on_the_screen() -> void:
	# A label with the right words in it, laid out off the bottom of the picture,
	# is not attribution. The design height rather than the window's, for the
	# reason the rules screen uses it: `window/stretch/aspect` is "expand", so a
	# taller screen gets more room and never less — a line that fits at the design
	# resolution fits everywhere.
	var credits: Label = _screen.get_node("%Credits") as Label
	assert_gt(credits.size.x, 0.0, "the credit must be laid out, not collapsed")
	var box: Rect2 = credits.get_global_rect()
	assert_gte(box.position.x, 0.0, "the credit runs off the left of the screen")
	var design: Vector2i = get_tree().root.content_scale_size
	assert_lte(box.end.y, float(design.y), "the credit is off the bottom of the picture")
	assert_true(credits.is_visible_in_tree(), "the credit must be drawn")


func test_the_credit_does_not_cross_the_how_to_play_label() -> void:
	# The bug the driveway's third line found (#114) and the sponge's fourth work
	# would have found again: a credit is bottom-anchored and grows upwards, the
	# menu column is centred, and past a certain number of lines the top one is
	# drawn straight through "How to Play". It is legible neither as a credit nor
	# as a button, and nothing else on this screen can see it happen — the two
	# nodes are siblings that never touch, and both are laid out exactly as their
	# offsets ask.
	#
	# The pressure washer's fifth work (#154) is the one that finally spent the
	# 16 px two lines had in hand, and the menu bought the room back rather than
	# shrinking the type: 44 px off the lockup and 44 off the column's container —
	# src/screens/main_menu.tscn has that arithmetic — and this is the measurement
	# that says it was enough. That work has since gone (#162, the wand is drawn
	# by this project and is owed to nobody) and the room has not been given back,
	# so what this now measures is slack rather than a near miss. It is still the
	# measurement that would notice a sixth work arriving.
	#
	# Both boxes are measured off the text rather than off the control: a Label
	# is as tall as its offsets whatever it has in it, and a pill is mostly
	# padding. Measured in the viewport this suite is running in, so the claim
	# holds at whatever size the window happens to be rather than only at the
	# design one.
	var credits: Label = _screen.get_node("%Credits") as Label
	var pill: Button = _how_to_play_button()
	assert_false(
		_drawn_credit(credits).intersects(_drawn_label(pill)),
		"the credit is drawn across the How to Play label"
	)


func test_the_font_can_draw_the_credit() -> void:
	# The same bug `tests/integration/test_how_to_play.gd` pins, in the one place
	# on this screen where the copy is not plain ASCII: a glyph the face does not
	# have is a tofu box in a released build rather than an error anybody would
	# see. The credit carries curly quotes, an interpunct and an em dash, and
	# since #174 the face it is drawn in is Brand.BODY_FACE — a 226-glyph pixel
	# face rather than the built-in Open Sans this was written against, which is
	# the direction that makes the question sharper rather than moot.
	#
	# The line break between the two works is skipped, and only it: a control
	# character is layout rather than type, no font has a glyph for one, and
	# asking whether a face can draw a newline is a question with a wrong answer
	# either way. Everything from the space upwards is still asked.
	var credits: Label = _screen.get_node("%Credits") as Label
	var font: Font = credits.get_theme_font("font")
	for i: int in credits.text.length():
		var glyph: int = credits.text.unicode_at(i)
		if glyph < 0x20:
			continue
		assert_true(
			font.has_char(glyph),
			(
				"the credit wants U+%04X (%s), which %s cannot draw"
				% [glyph, char(glyph), font.get_font_name()]
			)
		)


func test_the_two_faces_are_used_for_the_two_jobs_they_are_for() -> void:
	# This screen is where the two-face system is easiest to get wrong, because
	# both faces are on it at once and they are eight design pixels apart in size.
	# The pills and the car's name are read at a glance and are chunky; the
	# credit is a hundred and forty characters of licence text a line at a time
	# and is not. Set the credit in the display face and it wraps to a wall over
	# the buttons — which is what `test_the_credit_does_not_cross_the_button`
	# would then catch, one failure later than this.
	for pill: Button in _pills():
		assert_eq(pill.get_theme_font("font"), Brand.DISPLAY_FACE, "%s must be chunky" % pill.name)
	assert_eq(
		(_screen.get_node("%CarName") as Label).get_theme_font("font"),
		Brand.DISPLAY_FACE,
		"the car's name is a caption for the room, read at a glance"
	)
	assert_eq(
		(_screen.get_node("%Credits") as Label).get_theme_font("font"),
		Brand.BODY_FACE,
		"the credit is small print and must be in the reading face"
	)


func test_the_credit_is_legible_over_a_lit_driveway() -> void:
	# It is laid over the bay working itself, which is tarmac, grass, sky and a
	# car of whatever colour was drawn — so muted grey on its own is legible
	# against about half of that. The outline is what makes it a promise rather
	# than a hope, and it is the same treatment the score wears over the same room.
	var credits: Label = _screen.get_node("%Credits") as Label
	assert_eq(credits.get_theme_color("font_color"), Brand.MUTED)
	assert_gt(credits.get_theme_constant("outline_size"), 0, "grey type needs a shadow here")


# ---- three buttons, and only one of them is the answer -----------------------


func test_it_offers_all_three_ways_on() -> void:
	assert_not_null(_arcade_button(), "the menu must offer the arcade run")
	assert_not_null(_simulation_button(), "and the simulation")
	assert_not_null(_how_to_play_button(), "and How to Play")


func test_the_arcade_is_the_one_red_thing_on_the_screen() -> void:
	# The whole reason the other two pills are dark. [constant Brand.RED] is the
	# site's one accent — worn by the thing you are meant to press and by
	# nothing else — and a menu with two of them leaves the eye nowhere to land.
	# Which of the three wears it is the arcade, because the answer to "how do I
	# play this" is still the timed run — src/screens/main_menu.gd has that.
	var loud: StyleBoxFlat = _arcade_button().get_theme_stylebox("normal") as StyleBoxFlat
	assert_not_null(loud, "Arcade must be a brand pill, not the theme's button")
	if loud == null:
		return
	assert_eq(loud.bg_color, Brand.RED, "Arcade is the answer, so Arcade is red")
	for button: Button in [_simulation_button(), _how_to_play_button()]:
		var quiet: StyleBoxFlat = button.get_theme_stylebox("normal") as StyleBoxFlat
		assert_not_null(quiet, "%s must be a brand pill, not the theme's button" % button.name)
		if quiet == null:
			continue
		assert_eq(quiet.bg_color, Brand.PANEL, "%s must not be a second accent" % button.name)


func test_the_quiet_pills_still_have_an_edge() -> void:
	# A dark shape over a lit garage with no lit edge is a hole cut in the room
	# rather than a button sitting on it — [method Brand.quiet_pill]'s argument,
	# and the one thing that separates it from a rectangle of panel colour.
	for button: Button in [_simulation_button(), _how_to_play_button()]:
		var quiet: StyleBoxFlat = button.get_theme_stylebox("normal") as StyleBoxFlat
		assert_eq(quiet.border_width_top, 1, "%s must carry the card's hairline" % button.name)
		assert_eq(quiet.border_color, Brand.LINE)


func test_every_pill_is_round_ended_at_the_size_it_is_drawn() -> void:
	for button: Button in _pills():
		var box: StyleBoxFlat = button.get_theme_stylebox("normal") as StyleBoxFlat
		assert_eq(
			box.corner_radius_top_left,
			roundi(button.size.y / 2.0),
			"%s must be a pill at the size it is actually drawn" % button.name
		)


func test_every_face_of_every_button_is_dressed() -> void:
	# Hover and pressed fall back to the theme's grey if they are not overridden,
	# which would strand a default button at the one moment it is being used.
	for button: Button in _pills():
		for state: String in ["normal", "hover", "pressed", "focus"]:
			assert_true(
				button.has_theme_stylebox_override(state),
				"%s's `%s` box must come from Brand" % [button.name, state]
			)


func test_every_button_is_big_enough_for_a_finger() -> void:
	# The bug this pins is the one the title card already shipped: a button below
	# this floor is ~18 CSS px on a phone, and most taps miss it. [TouchTarget]
	# has the arithmetic and the sources.
	var minimum: float = TouchTarget.min_design_size()
	for button: Button in _pills():
		assert_gte(button.size.x, minimum, "%s is too narrow to hit on a phone" % button.name)
		assert_gte(button.size.y, minimum, "%s is too short to hit on a phone" % button.name)


func test_the_arcade_holds_the_focus_when_the_menu_opens() -> void:
	# So the flow is drivable from a keyboard or a pad without a mouse, and on
	# the button that is already drawn as the answer — a focus ring round one of
	# the quiet pills would disagree with the colour.
	assert_eq(
		_screen.get_viewport().gui_get_focus_owner(),
		_arcade_button(),
		"the menu must open with Arcade under the keyboard"
	)


func test_the_two_modes_do_not_run_into_the_car_arrows() -> void:
	# The arithmetic src/screens/main_menu.tscn does out loud, measured rather
	# than trusted: the two mode pills are a row across the middle of a screen
	# whose edges belong to the arrows, and a row that grew — a longer word, a
	# bigger face — would be a pill drawn over a control a player is expected to
	# press several times in a row. Measured in the viewport this suite runs in,
	# which before_each has set to the design size.
	for arrow: Button in [
		_screen.get_node("%PreviousCar") as Button, _screen.get_node("%NextCar") as Button
	]:
		for pill: Button in _mode_buttons():
			assert_false(
				pill.get_global_rect().intersects(arrow.get_global_rect()),
				"%s is drawn over %s" % [pill.name, arrow.name]
			)


# ---- where each of them leads ------------------------------------------------


func test_it_asks_for_nothing_on_its_own() -> void:
	assert_eq(_requested.size(), 0, "the menu must wait for the player")
	assert_eq(_rung.size(), 0, "and must not make a noise on its own account")
	assert_eq(_faded.size(), 0, "and must not touch the music it was handed")


func test_both_modes_ask_for_the_play_state() -> void:
	# Through the button's own signal rather than by calling the handler, so a
	# connection dropped in `_ready()` fails here rather than in the browser.
	#
	# One state for both pills, and that is the design rather than an oversight:
	# a mode is a length the clock is built with, not a place the game can be in,
	# so there is one play screen and it reads the mode on the way up.
	for pill: Button in _mode_buttons():
		_requested = []
		pill.pressed.emit()
		assert_eq(_requested.size(), 1, "%s must request exactly one transition" % pill.name)
		if _requested.size() != 1:
			return
		assert_true(_requested[0] is PlayGameState, "%s must open the game" % pill.name)


func test_each_pill_chooses_its_own_mode() -> void:
	_arcade_button().pressed.emit()
	assert_eq(GameMode.chosen, GameMode.Kind.ARCADE, "Arcade must ask for the clock")
	_simulation_button().pressed.emit()
	assert_eq(GameMode.chosen, GameMode.Kind.SIMULATION, "Simulation must take it off")


func test_the_mode_is_chosen_before_the_screen_is_asked_to_leave() -> void:
	# `request_transition` frees this screen synchronously and the play screen
	# reads the mode in its own `_ready`, which has already run by the time the
	# line after a transition would execute. So the order is load-bearing rather
	# than tidy: a mode written afterwards is a mode the run never saw.
	var seen: Array[GameMode.Kind] = []
	_screen.transition_requested.connect(
		func(_state: GameState) -> void: seen.append(GameMode.chosen)
	)
	_simulation_button().pressed.emit()
	assert_eq(seen, [GameMode.Kind.SIMULATION] as Array[GameMode.Kind])


func test_how_to_play_asks_for_the_rules() -> void:
	_how_to_play_button().pressed.emit()
	assert_eq(_requested.size(), 1, "How to Play must request exactly one transition")
	if _requested.size() != 1:
		return
	assert_true(_requested[0] is HowToPlayGameState, "How to Play must open the rules")


func test_either_mode_rings_the_counter_bell() -> void:
	# The ding moved here from the title card's Start when Start stopped opening
	# the game: [constant Bell.Voice.START] means the job starts, and this is
	# where the job starts — in either mode, because in either mode a job is what
	# starts.
	for pill: Button in _mode_buttons():
		_rung = []
		pill.pressed.emit()
		assert_eq(_rung, [Bell.Voice.START] as Array[Bell.Voice], "%s must ding once" % pill.name)


func test_either_mode_asks_for_a_fade_rather_than_a_stop() -> void:
	for pill: Button in _mode_buttons():
		_faded = []
		pill.pressed.emit()
		assert_eq(_faded.size(), 1, "%s did not ask for the music to go" % pill.name)
		if _faded.size() != 1:
			return
		assert_almost_eq(
			_faded[0], Bandstand.FADE_SECONDS, 0.001, "%s cut the music dead" % pill.name
		)


func test_a_mode_asks_for_the_fade_before_it_asks_to_leave() -> void:
	# `request_transition` frees this screen synchronously, so a fade asked for
	# afterwards would be emitted from a node on its way out. It survives either
	# way, because the host is already connected, but the version that does not
	# rely on that is the one that should stay.
	var order: Array[String] = []
	_screen.music_stop_requested.connect(func(_seconds: float) -> void: order.append("fade"))
	_screen.transition_requested.connect(func(_state: GameState) -> void: order.append("leave"))
	_arcade_button().pressed.emit()
	assert_eq(order, ["fade", "leave"] as Array[String])


func test_the_rules_are_reached_without_disturbing_the_theme() -> void:
	# The theme is supposed to carry across the menu and fade as the game opens,
	# so the long way round to the game must sound like no decision at all.
	_how_to_play_button().pressed.emit()
	assert_eq(_faded.size(), 0, "reading the rules must not stop the music")
	assert_eq(_rung.size(), 0, "and must not ring the bell that means the job started")


# ---- the sound toggle: carried over from the title card ----------------------
#
# The toggle's own size, dressing and effect on [Sound] are
# tests/integration/test_sound_toggle.gd's job. What is worth pinning here is
# that the choice a player made on the title card is still on offer one screen
# later, and that pressing it here is not mistaken for either of the two real
# doors this screen has.


func test_the_menu_offers_the_sound_toggle_too() -> void:
	assert_not_null(_sound_toggle(), "the menu must carry the same toggle the title card does")


func test_pressing_it_opens_neither_door() -> void:
	_sound_toggle().pressed.emit()
	assert_eq(_requested.size(), 0, "muting is not a game and it is not How to Play")
	assert_eq(_rung.size(), 0, "and it must not ring the bell that means the job started")
	assert_eq(_faded.size(), 0, "and it must not touch the theme it is about to silence")


func test_a_tap_on_it_actually_reaches_it() -> void:
	# Through a real touch and not `pressed.emit()` — see
	# tests/integration/test_title_screen.gd's twin of this test for why
	# `pressed.emit()` alone cannot catch a `CenterContainer` left at the
	# engine's default `mouse_filter` swallowing the tap before it arrives.
	Sound.set_muted(false)
	_tap(_sound_toggle().get_global_rect().get_center())
	await wait_process_frames(1)
	assert_true(Sound.muted, "a tap on the corner must reach the sound toggle")


# ---- touch: the phone-shaped half of "do these buttons work" -----------------


## Taps the screen at [param at], the way a finger does.
##
## Through `Input` rather than `Viewport.push_input()` for
## [code]test_title_screen.gd[/code]'s reason: nothing in `Button` reads a touch
## event, so what actually makes a tap work is the engine turning it into a click
## first, and that emulation lives in `Input`.
func _tap(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var touch: InputEventScreenTouch = InputEventScreenTouch.new()
		touch.position = at
		touch.pressed = pressed
		Input.parse_input_event(touch)
	Input.flush_buffered_events()


func test_a_tap_on_the_arcade_opens_the_game() -> void:
	_tap(_arcade_button().get_global_rect().get_center())
	await wait_process_frames(1)
	assert_eq(_requested.size(), 1, "a tap on Arcade must ask for the game")
	if _requested.size() != 1:
		return
	assert_true(_requested[0] is PlayGameState)
	assert_eq(GameMode.chosen, GameMode.Kind.ARCADE)


## [b]There is no tap test for Simulation, and the reason is the harness rather
## than the pill.[/b] GUT's own runner draws its output panel over the right of
## the viewport — measured at x = 643 and rightwards in this project, against a
## 1280 px design — and it is a live [Control] at
## [constant Control.MOUSE_FILTER_STOP], so a touch delivered at the right-hand
## pill's centre (x = 852) is eaten by the runner before the menu is asked. What
## it would be asserting is where GUT put a text box.
##
## Nothing is lost that the tap above does not already cover: the two pills are
## siblings in the same row, inside the same [CenterContainer] whose
## [member Control.mouse_filter] is the thing these tests exist to catch, and
## [method test_each_pill_chooses_its_own_mode] drives Simulation through its own
## signal. The pills' geometry — that neither is drawn under an arrow — is
## measured in [method test_the_two_modes_do_not_run_into_the_car_arrows].


func test_a_tap_on_how_to_play_opens_the_rules() -> void:
	# The pills are stacked and adjacent, so this is also the assertion that
	# a tap lands on the one under the finger rather than on the row
	# above it.
	_tap(_how_to_play_button().get_global_rect().get_center())
	await wait_process_frames(1)
	assert_eq(_requested.size(), 1, "a tap on How to Play must ask for the rules")
	if _requested.size() != 1:
		return
	assert_true(_requested[0] is HowToPlayGameState)
