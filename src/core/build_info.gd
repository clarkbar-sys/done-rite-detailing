## Build provenance for the running binary.
##
## Every artifact CI produces should be able to answer "which commit is this?"
## without guesswork. CI writes [code]res://build_stamp.json[/code] just before
## exporting; local and editor runs have no stamp and report
## [constant UNKNOWN_COMMIT].
##
## Deliberately a static [code]class_name[/code] rather than an autoload:
## [code]godot --check-only[/code] — what `make check` gates on — resolves global
## class names but *not* autoload names, so anything reached through an autoload
## silently drops out of the type check. Immutable process-global facts like
## these belong on a class anyway; they have no business being a node in the
## scene tree.
class_name BuildInfo
extends RefCounted

## Where the export-time stamp lives. Written by `scripts/stamp-build.sh` and
## packed into the exported game; absent in the editor and in `make run`.
const STAMP_PATH: String = "res://build_stamp.json"

## Commit field used when no stamp was baked in.
const UNKNOWN_COMMIT: String = "local"

## Keys in the stamp JSON, and in the dictionaries returned below. Named
## constants because `scripts/stamp-build.sh` writes the same two strings and a
## typo on either side is a silently unstamped build, not an error.
const KEY_COMMIT: String = "commit"
const KEY_BUILT_AT: String = "built_at"

## Semantic version, from `application/config/version` in project.godot.
## release-please owns that value; nothing else should write it.
static var version: String = ""

## Short git SHA this build was exported from, or [constant UNKNOWN_COMMIT].
static var commit: String = UNKNOWN_COMMIT

## ISO-8601 UTC build timestamp, or an empty string when unstamped.
static var built_at: String = ""


## Runs once, when the class is first referenced.
static func _static_init() -> void:
	version = str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	var stamp: Dictionary[String, String] = read_stamp(STAMP_PATH)
	commit = stamp[KEY_COMMIT]
	built_at = stamp[KEY_BUILT_AT]


## One-line human-readable build identifier, e.g. `v0.1.0 (a1b2c3d)`.
static func describe() -> String:
	return "v%s (%s)" % [version, commit]


## Reads the stamp at [param path] and returns its fields, or [method unstamped]
## if the file is missing, unreadable or malformed.
##
## Public, and takes a path, so the read is reachable from a test with a
## throwaway file under [code]user://[/code]. The alternative — planting a
## stamp at [constant STAMP_PATH] to exercise this — writes into the project
## directory, where a leftover would be packed into the next export and stamp a
## build with a lie. Nothing here touches the static fields above, so tests can
## run in any order.
static func read_stamp(path: String) -> Dictionary[String, String]:
	if not FileAccess.file_exists(path):
		return unstamped()
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("build stamp exists but could not be opened: %s" % path)
		return unstamped()
	var text: String = file.get_as_text()
	file.close()
	return parse_stamp(text, path)


## Parses the JSON text of a build stamp. Anything that isn't a JSON object —
## empty text, truncated JSON, a bare array or number — warns and yields
## [method unstamped] rather than raising: a build that can't say which commit
## it is should still run. [param source] only names the input in that warning.
##
## Split out from the file read so the parsing rules can be tested against a
## string, with no file and no process-global state involved.
static func parse_stamp(text: String, source: String = STAMP_PATH) -> Dictionary[String, String]:
	# `JSON.new().parse()` and not `JSON.parse_string()`: the latter reports a
	# parse failure by logging an engine error before returning null. `make
	# smoke` fails the build on any line matching `ERROR:`, so a malformed
	# stamp would break the smoke gate with a message about JSON internals
	# rather than about the stamp — for a case this code handles deliberately.
	# Verified: GUT flagged exactly that error here before this changed.
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		push_warning("build stamp is not valid JSON: %s" % source)
		return unstamped()
	var parsed: Variant = json.data
	if not parsed is Dictionary:
		push_warning("build stamp is not a JSON object: %s" % source)
		return unstamped()
	var stamp: Dictionary = parsed
	var result: Dictionary[String, String] = unstamped()
	result[KEY_COMMIT] = str(stamp.get(KEY_COMMIT, UNKNOWN_COMMIT))
	result[KEY_BUILT_AT] = str(stamp.get(KEY_BUILT_AT, ""))
	return result


## The stamp fields of an unstamped build — what a local or editor run reports.
static func unstamped() -> Dictionary[String, String]:
	return {KEY_COMMIT: UNKNOWN_COMMIT, KEY_BUILT_AT: ""}
