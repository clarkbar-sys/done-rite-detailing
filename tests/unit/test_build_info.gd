## Unit tests for [BuildInfo]'s build-stamp handling.
##
## The three cases that matter are the three states a shipped binary can be in:
## stamped (CI exported it), unstamped (a developer ran it) and mis-stamped
## (something wrote garbage to the file). The third is the one worth testing —
## a crash on startup because the provenance file is malformed would be a
## spectacularly bad trade.
##
## Every case goes through a throwaway file under [code]user://[/code], never
## [constant BuildInfo.STAMP_PATH]. A stamp left behind in the project
## directory is gitignored, so nothing would flag it, and the next `make build`
## would pack it — shipping a binary that reports a commit it wasn't built
## from. See [method BuildInfo.read_stamp].
##
## Nothing here writes [BuildInfo]'s static fields, which is deliberate:
## [code]_static_init[/code] runs once per process and cannot be re-run, so any
## test that mutated them would leak into whichever test happened to run next.
extends GutTest

## Somewhere no test ever writes, so "the file is missing" is a fact and not a
## race with a sibling test's cleanup.
const MISSING_STAMP: String = "user://test_build_info_no_such_stamp.json"

## Written and deleted per test — see [method after_each].
const TEMP_STAMP: String = "user://test_build_info_stamp.json"


func after_each() -> void:
	if FileAccess.file_exists(TEMP_STAMP):
		DirAccess.remove_absolute(TEMP_STAMP)


# ---- read_stamp: the three states a binary can be in -------------------------


func test_absent_stamp_reads_as_unstamped() -> void:
	assert_false(FileAccess.file_exists(MISSING_STAMP), "the missing stamp must stay missing")
	assert_eq(BuildInfo.read_stamp(MISSING_STAMP), BuildInfo.unstamped())


func test_present_stamp_yields_its_fields() -> void:
	_write_stamp('{"commit": "a1b2c3d", "built_at": "2026-07-31T09:41:00Z"}')
	var stamp: Dictionary[String, String] = BuildInfo.read_stamp(TEMP_STAMP)
	assert_eq(stamp[BuildInfo.KEY_COMMIT], "a1b2c3d")
	assert_eq(stamp[BuildInfo.KEY_BUILT_AT], "2026-07-31T09:41:00Z")


func test_malformed_stamp_reads_as_unstamped() -> void:
	_write_stamp('{"commit": "a1b2c3d",')
	assert_eq(BuildInfo.read_stamp(TEMP_STAMP), BuildInfo.unstamped())


# ---- parse_stamp: the shapes JSON can be that aren't a stamp -----------------


func test_parse_stamp_reads_both_fields() -> void:
	var stamp: Dictionary[String, String] = BuildInfo.parse_stamp(
		'{"commit": "deadbee", "built_at": "2026-01-02T03:04:05Z"}'
	)
	assert_eq(stamp[BuildInfo.KEY_COMMIT], "deadbee")
	assert_eq(stamp[BuildInfo.KEY_BUILT_AT], "2026-01-02T03:04:05Z")


func test_parse_stamp_defaults_the_fields_the_stamp_omits() -> void:
	var stamp: Dictionary[String, String] = BuildInfo.parse_stamp('{"commit": "deadbee"}')
	assert_eq(stamp[BuildInfo.KEY_COMMIT], "deadbee")
	assert_eq(stamp[BuildInfo.KEY_BUILT_AT], "", "an omitted built_at is empty, not null")


func test_parse_stamp_stringifies_non_string_fields() -> void:
	# A stamp written by something other than scripts/stamp-build.sh could put a
	# number here; `describe()` has to format it either way, so it must not
	# blow up. JSON has no integer type, so the round trip is through a double
	# and the commit comes back "1234567.0" — asserted as observed rather than
	# as hoped, because that is what a build would actually print.
	var stamp: Dictionary[String, String] = BuildInfo.parse_stamp('{"commit": 1234567}')
	assert_eq(stamp[BuildInfo.KEY_COMMIT], "1234567.0")


func test_parse_stamp_rejects_json_that_is_not_an_object() -> void:
	# Valid JSON, wrong shape — the case `JSON.parse_string` alone would let
	# through, because it returns the array quite happily.
	assert_eq(BuildInfo.parse_stamp("[1, 2, 3]"), BuildInfo.unstamped())


func test_parse_stamp_rejects_empty_text() -> void:
	assert_eq(BuildInfo.parse_stamp(""), BuildInfo.unstamped())


# ---- the wiring, and the API around it ---------------------------------------


func test_static_state_matches_the_stamp_on_disk() -> void:
	# Asserts that `_static_init` wired the parse to the static fields, without
	# asserting *which* answer it got: `make build` leaves a real stamp in the
	# tree, so hardcoding "local" here would pass in CI and fail for anyone who
	# had exported a build. Same source of truth, both environments.
	var stamp: Dictionary[String, String] = BuildInfo.read_stamp(BuildInfo.STAMP_PATH)
	assert_eq(BuildInfo.commit, stamp[BuildInfo.KEY_COMMIT])
	assert_eq(BuildInfo.built_at, stamp[BuildInfo.KEY_BUILT_AT])


func test_unstamped_reports_the_unknown_commit() -> void:
	var stamp: Dictionary[String, String] = BuildInfo.unstamped()
	assert_eq(stamp[BuildInfo.KEY_COMMIT], BuildInfo.UNKNOWN_COMMIT)
	assert_eq(stamp[BuildInfo.KEY_BUILT_AT], "")


func test_describe_formats_the_version_and_commit() -> void:
	assert_eq(BuildInfo.describe(), "v%s (%s)" % [BuildInfo.version, BuildInfo.commit])


func test_version_comes_from_project_settings() -> void:
	# release-please owns application/config/version; this is the assertion that
	# notices if the plumbing from project.godot to BuildInfo ever breaks.
	assert_eq(BuildInfo.version, str(ProjectSettings.get_setting("application/config/version")))


func _write_stamp(text: String) -> void:
	var file: FileAccess = FileAccess.open(TEMP_STAMP, FileAccess.WRITE)
	assert_not_null(file, "could not write the temp stamp at %s" % TEMP_STAMP)
	if file == null:
		return
	file.store_string(text)
	file.close()
