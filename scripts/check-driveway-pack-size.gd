## Reads assets/models/driveway/'s three compiled entries out of a real
## exported .pck and prints their sizes — the mesh's `.scn` and both textures'
## `.ctex` — rather than trusting the `.godot/imported/` cache
## [code]make import[/code] leaves behind. The two agree today (nothing between
## import and export touches these three files), and the numbers in
## [code]src/world/ground.tscn[/code] were measured off the cache because it is
## the fast half of the loop — but what #207 actually asked to be <= 1 MiB is
## the pck a player downloads, so this is what checks that copy.
##
## Run against a bundle [code]make build-web[/code] has already produced:
## [codeblock]
## .godot-sdk/bin/godot --headless --path . \
##   --script res://scripts/check-driveway-pack-size.gd -- build/web/index.pck
## [/codeblock]
##
## [b]A [SceneTree] and not a [GutTest][/b] — for [code]scripts/perf-probe.gd[/code]'s
## reasons too: this does not open the project's own resources, only a `.pck`
## named on the command line, and it has no business under [code]tests/[/code] or
## being reached by [code]scripts/check-test-map.sh[/code]'s R1. It is still
## type-checked and linted like every other `.gd` in the tree.
##
## [b]`--path .` is still required[/b], even though the pck being read is the
## whole point — [code]res://scripts/check-driveway-pack-size.gd[/code] is
## itself loaded off the project's own `res://`, and that root has to exist
## before [method ProjectSettings.load_resource_pack] has anywhere to overlay
## the exported copy onto. `replace_files` defaults to true, so once the pck
## loads, every path this script reads under `res://.godot/imported/` is the
## exported bundle's byte-for-byte copy and not whatever `make import` left on
## disk locally — the two happen to be identical today, but this script is
## written to be correct if they ever were not.
extends SceneTree

## Where the compiled driveway resources land inside any pck this project
## exports — the same three paths src/world/ground.tscn's own comment names.
const IMPORTED_DIR: String = "res://.godot/imported/"

## The driveway's own entries in that directory, which holds every other
## imported asset's compiled resources too.
const PREFIX: String = "sunken_driveway_parking_spot"

## What actually ships. [constant IMPORTED_DIR] also carries a `.md5` beside
## every entry — [code]make import[/code]'s own change-detection stamp, real on
## disk but never packed (confirmed against `make build-web`'s own log, which
## lists exactly three `Storing File:` lines for the driveway, one `.scn` and
## two `.ctex`) — so those are filtered out rather than counted as if a player
## downloads them too.
const SUFFIXES: PackedStringArray = [".scn", ".ctex"]

## #207's own budget for the three entries combined, in bytes.
const BUDGET_BYTES: int = 1024 * 1024


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		printerr("usage: check-driveway-pack-size.gd -- <path-to-.pck>")
		quit(1)
		return
	var pck: String = args[0]
	if not ProjectSettings.load_resource_pack(pck):
		printerr("could not load resource pack %s" % pck)
		quit(1)
		return
	_report(pck)


## Walks [constant IMPORTED_DIR] after the pck has been mounted over it, prints
## one line per matching entry and the total, and exits non-zero over budget or
## if nothing matched at all — the same "a coverage check, not a wish" shape
## [code]tests/integration/test_main_menu.gd[/code] holds the credits to.
func _report(pck: String) -> void:
	var dir: DirAccess = DirAccess.open(IMPORTED_DIR)
	if dir == null:
		printerr("%s did not mount from %s" % [IMPORTED_DIR, pck])
		quit(1)
		return
	var total: int = 0
	var found: int = 0
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var matches_suffix: bool = false
		for suffix: String in SUFFIXES:
			matches_suffix = matches_suffix or entry.ends_with(suffix)
		if entry.begins_with(PREFIX) and matches_suffix and not dir.current_is_dir():
			var size: int = FileAccess.get_file_as_bytes(IMPORTED_DIR + entry).size()
			print("%-90s %8d bytes" % [entry, size])
			total += size
			found += 1
		entry = dir.get_next()
	dir.list_dir_end()
	if found == 0:
		printerr(
			"no %s* entries under %s — wrong pck, or the driveway moved" % [PREFIX, IMPORTED_DIR]
		)
		quit(1)
		return
	print(
		"driveway total: %d bytes (%.3f MiB) across %d entries" % [total, total / 1048576.0, found]
	)
	if total > BUDGET_BYTES:
		printerr(
			(
				"OVER BUDGET: %d bytes over the %d byte (1 MiB) limit"
				% [total - BUDGET_BYTES, BUDGET_BYTES]
			)
		)
		quit(1)
		return
	print("within budget by %d bytes" % (BUDGET_BYTES - total))
	quit(0)
