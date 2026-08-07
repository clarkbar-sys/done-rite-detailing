## Integration tests for [SoundToggle] on its own, rather than through one of
## the three screens that carry it.
##
## [b]Why on its own.[/b] The same script sits in
## [code]src/screens/title_screen.tscn[/code],
## [code]src/screens/main_menu.tscn[/code] and
## [code]src/screens/play_screen.tscn[/code], and the thing worth pinning is the
## behaviour all three inherit from that one source: its size, its dressing,
## and what a press actually does to [Sound]. A bug in any of those would
## otherwise have to be caught three times, once per screen, or slip through
## the two nobody thought to add a case for.
extends GutTest

var _toggle: SoundToggle = null
var _muted_before: bool = false


func before_each() -> void:
	_muted_before = Sound.muted
	Sound.set_muted(false)
	var toggle: SoundToggle = SoundToggle.new()
	_toggle = toggle
	add_child_autofree(_toggle)
	# `_ready()` has already run inside `add_child` — the frame is only here to
	# let a redraw settle before anything below reads the button back.
	await wait_process_frames(1)


func after_each() -> void:
	Sound.set_muted(_muted_before)


func test_it_is_big_enough_for_a_finger() -> void:
	# The same floor every other tap target on the belt and the pad clear —
	# [TouchTarget] has the arithmetic and the sources.
	var minimum: float = TouchTarget.min_design_size()
	assert_gte(_toggle.size.x, minimum, "the toggle is too narrow to hit on a phone")
	assert_gte(_toggle.size.y, minimum, "the toggle is too short to hit on a phone")


func test_every_face_is_dressed() -> void:
	# Hover and pressed fall back to the engine's own grey if they are not
	# overridden, which is the one moment this button is actually being used.
	for state: String in ["normal", "hover", "pressed", "focus"]:
		assert_true(
			_toggle.has_theme_stylebox_override(state),
			"%s must not fall back to the theme's own button" % state
		)


func test_the_plate_does_not_change_colour_with_the_sound() -> void:
	# Unlike the tool belt's own corner, this one does not turn red for its "on"
	# state — the class docs have the argument: red already means "the thing you
	# are meant to press" on every screen this button sits on.
	var before: StyleBoxFlat = _toggle.get_theme_stylebox("normal") as StyleBoxFlat
	assert_eq(before.bg_color, Brand.PANEL)
	_toggle.pressed.emit()
	var after: StyleBoxFlat = _toggle.get_theme_stylebox("normal") as StyleBoxFlat
	assert_eq(after.bg_color, Brand.PANEL, "the plate must not change with the sound")


func test_pressing_it_mutes_the_game() -> void:
	assert_false(Sound.muted, "must start unmuted for this test to mean anything")
	_toggle.pressed.emit()
	assert_true(Sound.muted)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(Sound.BUS_NAME)))


func test_pressing_it_twice_restores_the_sound() -> void:
	_toggle.pressed.emit()
	_toggle.pressed.emit()
	assert_false(Sound.muted)
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index(Sound.BUS_NAME)))


func test_the_tooltip_says_what_the_next_press_will_do() -> void:
	assert_eq(
		_toggle.tooltip_text, SoundToggle.TOOLTIP_ON, "sound is on, so the offer is to mute it"
	)
	_toggle.pressed.emit()
	assert_eq(
		_toggle.tooltip_text, SoundToggle.TOOLTIP_OFF, "sound is off, so the offer is to unmute it"
	)


func test_it_opens_already_matching_whatever_sound_was_left_at() -> void:
	# The flag can arrive already muted — a player who pressed it on the title
	# card and carried the choice into the menu — and a fresh toggle has to open
	# agreeing with that rather than defaulting back to "on".
	Sound.set_muted(true)
	var reopened: SoundToggle = SoundToggle.new()
	add_child_autofree(reopened)
	await wait_process_frames(1)
	assert_eq(
		reopened.tooltip_text, SoundToggle.TOOLTIP_OFF, "a muted game must open offering to unmute"
	)
