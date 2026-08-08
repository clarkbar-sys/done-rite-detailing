## Unit tests for [Settings]' JSON persistence.
##
## The three cases that matter mirror [BuildInfo]'s own build-stamp suite:
## present (a returning player), absent (nobody has ever saved), and corrupt
## (something wrote garbage to the file) — and the third is the one worth
## testing, since a crash on startup because a save got mangled would be a
## spectacularly bad trade for a sound toggle.
##
## Every case goes through a throwaway file under [code]user://[/code], never
## [constant Settings.SETTINGS_PATH] — the same reason [code]test_build_info.gd[/code]
## does: a file left behind there is exactly the one a real boot would read.
extends GutTest

## Somewhere no test ever writes, so "the file is missing" is a fact and not a
## race with a sibling test's cleanup.
const MISSING_SETTINGS: String = "user://test_settings_no_such_file.json"

## Written and deleted per test — see [method after_each].
const TEMP_SETTINGS: String = "user://test_settings_file.json"


func after_each() -> void:
	if FileAccess.file_exists(TEMP_SETTINGS):
		DirAccess.remove_absolute(TEMP_SETTINGS)


# ---- read_settings: the three states a save can be in -----------------------


func test_absent_settings_read_as_defaults() -> void:
	assert_false(FileAccess.file_exists(MISSING_SETTINGS), "the missing file must stay missing")
	assert_eq(Settings.read_settings(MISSING_SETTINGS), Settings.defaults())


func test_present_settings_yield_the_saved_value() -> void:
	_write_settings('{"muted": true}')
	var settings: Dictionary[String, bool] = Settings.read_settings(TEMP_SETTINGS)
	assert_true(settings[Settings.KEY_MUTED])


func test_malformed_settings_read_as_defaults() -> void:
	_write_settings('{"muted": true,')
	assert_eq(Settings.read_settings(TEMP_SETTINGS), Settings.defaults())


# ---- parse_settings: the shapes JSON can be that aren't a save --------------


func test_parse_settings_reads_the_muted_flag() -> void:
	var settings: Dictionary[String, bool] = Settings.parse_settings('{"muted": true}')
	assert_true(settings[Settings.KEY_MUTED])


func test_parse_settings_defaults_an_omitted_flag() -> void:
	var settings: Dictionary[String, bool] = Settings.parse_settings("{}")
	assert_false(settings[Settings.KEY_MUTED], "an omitted muted must default to false")


func test_parse_settings_rejects_json_that_is_not_an_object() -> void:
	# Valid JSON, wrong shape — the case a plain `JSON.parse_string()` call
	# would let through, because it returns the array quite happily.
	assert_eq(Settings.parse_settings("[1, 2, 3]"), Settings.defaults())


func test_parse_settings_rejects_empty_text() -> void:
	assert_eq(Settings.parse_settings(""), Settings.defaults())


func test_defaults_start_unmuted() -> void:
	assert_false(Settings.defaults()[Settings.KEY_MUTED], "a new player must not start silenced")


# ---- save_muted: the write half of the round trip ---------------------------


func test_save_then_read_round_trips() -> void:
	Settings.save_muted(true, TEMP_SETTINGS)
	assert_true(Settings.read_settings(TEMP_SETTINGS)[Settings.KEY_MUTED])
	Settings.save_muted(false, TEMP_SETTINGS)
	assert_false(Settings.read_settings(TEMP_SETTINGS)[Settings.KEY_MUTED])


func _write_settings(text: String) -> void:
	var file: FileAccess = FileAccess.open(TEMP_SETTINGS, FileAccess.WRITE)
	assert_not_null(file, "could not write the temp settings file at %s" % TEMP_SETTINGS)
	if file == null:
		return
	file.store_string(text)
	file.close()
