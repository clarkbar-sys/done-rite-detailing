## Unit tests for [Sound] — the one flag every screen's toggle flips.
##
## Under tests/unit/ because nothing here needs a [SceneTree]: [Sound] is a
## static [RefCounted] and [AudioServer] is a low-level singleton that exists
## before any scene does, so what is asked here is whether the flag and the
## bus it drives agree with each other.
extends GutTest

## The state [Sound] was in before this suite touched it, so a run that fails
## mid-test still hands the next suite an unmuted game rather than whatever
## this one last left the static flag at.
var _muted_before: bool = false


func before_each() -> void:
	_muted_before = Sound.muted
	Sound.set_muted(false)


func after_each() -> void:
	Sound.set_muted(_muted_before)


func test_starts_unmuted() -> void:
	assert_false(Sound.muted, "the game must not start silenced")


func test_set_muted_flips_the_flag() -> void:
	Sound.set_muted(true)
	assert_true(Sound.muted)
	Sound.set_muted(false)
	assert_false(Sound.muted)


func test_set_muted_reaches_the_bus_it_names() -> void:
	# The flag alone is bookkeeping — this is the line that actually silences
	# anything.
	var bus: int = AudioServer.get_bus_index(Sound.BUS_NAME)
	Sound.set_muted(true)
	assert_true(AudioServer.is_bus_mute(bus), "muting the flag must mute the bus")
	Sound.set_muted(false)
	assert_false(AudioServer.is_bus_mute(bus), "unmuting the flag must restore the bus")


func test_toggle_flips_from_whatever_it_was() -> void:
	Sound.set_muted(false)
	Sound.toggle()
	assert_true(Sound.muted)
	Sound.toggle()
	assert_false(Sound.muted)


func test_the_bus_it_drives_is_the_whole_mix() -> void:
	# "Master" is what an AudioStreamPlayer mixes through when nothing else is
	# named, and project.godot defines no other bus — so muting this one bus is
	# muting the theme, the bell and every tool at once, not one voice of them.
	assert_eq(Sound.BUS_NAME, "Master")


func test_set_muted_writes_through_to_settings() -> void:
	# The real path and not a throwaway one — this is the wiring test, the same
	# way BuildInfo's own suite reads the real STAMP_PATH to check
	# `_static_init` rather than hardcoding an answer. `after_each` above
	# restores whatever this suite started with by the same route.
	Sound.set_muted(true)
	assert_true(Settings.read_settings(Settings.SETTINGS_PATH)[Settings.KEY_MUTED])
	Sound.set_muted(false)
	assert_false(Settings.read_settings(Settings.SETTINGS_PATH)[Settings.KEY_MUTED])
