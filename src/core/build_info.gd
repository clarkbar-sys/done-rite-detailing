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
	_load_stamp()


## One-line human-readable build identifier, e.g. `v0.1.0 (a1b2c3d)`.
static func describe() -> String:
	return "v%s (%s)" % [version, commit]


static func _load_stamp() -> void:
	if not FileAccess.file_exists(STAMP_PATH):
		return
	var file: FileAccess = FileAccess.open(STAMP_PATH, FileAccess.READ)
	if file == null:
		push_warning("build stamp exists but could not be opened: %s" % STAMP_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_warning("build stamp is not a JSON object: %s" % STAMP_PATH)
		return
	var stamp: Dictionary = parsed
	commit = str(stamp.get("commit", UNKNOWN_COMMIT))
	built_at = str(stamp.get("built_at", ""))
