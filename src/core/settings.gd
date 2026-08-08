## Whether the game's settings survive a reload — the sound toggle today, and
## the one place any future setting would write through from.
##
## [b]Node-free, like [BuildInfo].[/b] Same reason: `godot --check-only` — what
## `make check` gates on — resolves global class names but not autoload names,
## so a call routed through an autoload would silently drop out of the type
## check. There's also no scene-tree lifecycle to hang this on: it's a file
## read once at boot and written on every change after.
##
## [b]Missing or corrupt data must not fail the boot[/b] — the same rule
## [method BuildInfo.read_stamp]/[method BuildInfo.parse_stamp] already follow
## for a missing or malformed build stamp. A player who has never played gets
## [method defaults]; a player whose save got mangled gets [method defaults]
## back rather than a crash.
##
## [b]One setting today.[/b] [constant KEY_MUTED] is the only thing anyone
## asks this to remember. A generic key-value store would be a layer of
## indirection nothing needs yet — see [method Sound.set_muted], the one
## caller, for how a second setting would plug in the same way.
class_name Settings
extends RefCounted

## Where the settings blob lives. A real file on desktop; on the Web export
## `user://` is backed by IndexedDB instead of a filesystem, so a write here
## needs [method sync_web] to actually survive a reload — see there.
const SETTINGS_PATH: String = "user://settings.json"

## Key in the JSON blob, and in the dictionary [method parse_settings] returns.
## Named so a typo on either side of a read/write is a compile error, not a
## silently dropped setting.
const KEY_MUTED: String = "muted"


## Reads the settings at [param path], or [method defaults] if the file is
## missing, unreadable or malformed.
static func read_settings(path: String) -> Dictionary[String, bool]:
	if not FileAccess.file_exists(path):
		return defaults()
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("settings file exists but could not be opened: %s" % path)
		return defaults()
	var text: String = file.get_as_text()
	file.close()
	return parse_settings(text, path)


## Parses the JSON text of a settings file. Anything that isn't a JSON object —
## empty text, truncated JSON, a bare array or number — warns and yields
## [method defaults] rather than raising: a corrupt settings file should still
## let the game boot. [param source] only names the input in that warning.
##
## Split out from the file read so the parsing rules can be tested against a
## string, with no file involved — the same seam [method BuildInfo.parse_stamp]
## is built on.
static func parse_settings(
	text: String, source: String = SETTINGS_PATH
) -> Dictionary[String, bool]:
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		push_warning("settings file is not valid JSON: %s" % source)
		return defaults()
	var parsed: Variant = json.data
	if not parsed is Dictionary:
		push_warning("settings file is not a JSON object: %s" % source)
		return defaults()
	var data: Dictionary = parsed
	var result: Dictionary[String, bool] = defaults()
	result[KEY_MUTED] = _as_bool(data.get(KEY_MUTED, false))
	return result


## Narrows a JSON-decoded [Variant] to [bool], defaulting anything else — a
## number or string in the saved file's [constant KEY_MUTED] slot — to
## [code]false[/code] rather than raising. [param value] is a [Variant]
## because that's what a [Dictionary] read out of parsed JSON always yields.
static func _as_bool(value: Variant) -> bool:
	if value is bool:
		return value
	return false


## The settings a player who has never saved, or whose save didn't survive,
## gets.
static func defaults() -> Dictionary[String, bool]:
	return {KEY_MUTED: false}


## Writes [param muted] to [param path] as the whole settings blob. Public and
## taking a path for the same reason [method BuildInfo.read_stamp] does: a
## test exercises it against a throwaway file under [code]user://[/code]
## rather than the one a real save lives at.
static func save_muted(muted: bool, path: String = SETTINGS_PATH) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("could not write settings file: %s" % path)
		return
	file.store_string(JSON.stringify({KEY_MUTED: muted}))
	file.close()
	sync_web()


## Flushes `user://` to IndexedDB on the Web export.
##
## `FileAccess` on Web writes into Emscripten's in-memory filesystem; IDBFS
## only makes that durable once something calls `FS.syncfs`, which the engine
## does not do on its own after an ordinary write. Skipping this would mean a
## setting that looks saved and is gone on the next reload. A no-op
## everywhere else `OS.has_feature("web")` is false, which is every
## environment the test suite runs in.
static func sync_web() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			"FS.syncfs(false, function(err) { if (err) { console.error(err); } });"
		)
