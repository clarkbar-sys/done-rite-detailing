## Print the ten largest entries stored in an exported `.pck`, biggest first.
##
## [b]Why this exists.[/b] #209 is "make the bundle's size a visible number
## before the next art drop grows it again"; the CI budget that issue adds
## (`.github/workflows/ci-godot.yml`'s `build-web` job) says *whether* the
## total regressed, not *what* to blame. This answers the second question —
## the same one that found the duplicated 16 MB texture in #140/#152/#164/
## #168 with nobody looking, except by reading the pack instead of hoping
## someone notices a diff stat on an art PR.
##
## [b]Usage — run from a directory with NO [code]project.godot[/code][/b],
## deliberately, and pass the exported pack as the one argument:
## [codeblock]
## mkdir -p /tmp/pck-inspect && cd /tmp/pck-inspect
## <repo>/.godot-sdk/bin/godot --headless \
##   --script <repo>/scripts/pck-top-ten.gd -- <repo>/build/web/index.pck
## [/codeblock]
## [b]THE ORDER OF ARGUMENTS THERE IS NOT A STYLE CHOICE, VERIFIED.[/b] Godot
## boots a project from whatever directory it is pointed at (`--path`, or the
## current directory if `--path` is absent) before this script's
## [method SceneTree._initialize] ever runs, and [method ProjectSettings.
## load_resource_pack] then *overlays* the pack on top of that filesystem
## rather than replacing it. Run this from the repo checkout — which has a
## [code]project.godot[/code] — and [code]DirAccess[/code] walks the working
## tree's loose source files with the pack's entries mixed in, sizes and all;
## checked by running it there first, and the walk printed
## [code]res://.github/screenshots/menu.png[/code], which is not in any
## exported pack. A directory with nothing in it leaves the pack as the whole
## filesystem, which is the only thing worth measuring here.
##
## [b]What "size" means below.[/b] Each entry is [method FileAccess.
## get_length] on the mounted path — the byte count Godot stores it at inside
## the pack. Godot's exporter does not compress pack entries by default, so
## this is real bytes on disk in [code]index.pck[/code], not an estimate; the
## CI budget step (which gzips the whole file) is still the number that
## decides pass/fail, because gzip is what GitHub Pages actually serves and
## this is not. Summed across every entry it undercounts the pack's own file
## size slightly (409 entries totalled 35,577,851 B against a 35,615,884 B
## [code]index.pck[/code], measured on the same export) — the difference is
## the pack's own table of contents, which lists no path of its own to blame.
##
## [b]Why a manual tool and not a CI step, unlike the budget gate.[/b] The
## budget in [code]ci-godot.yml[/code] has one number to be right about: pass
## or fail. A top-ten list is read by a person deciding what to cut, and that
## judgement — is 1.6 MB of [code]sedan_2.jpg[/code] the same texture repeated
## eight times or eight cars that legitimately need one each — is exactly the
## kind of review call [code]scripts/check-test-map.sh[/code]'s own docs say a
## mechanical gate can't make. It lives in [code]scripts/[/code] rather than
## [code]src/[/code] for the same reason [code]perf-probe.gd[/code] does: it
## is not game code, [code]scripts/check-test-map.sh[/code]'s R1 only walks
## [code]src/[/code], and it has no business being reached by a
## [code]tests/[/code] script. It is still type-checked and linted, because
## [code]make check[/code] and [code]make lint[/code] walk every
## [code].gd[/code] in the tree regardless of which directory it lives in.
extends SceneTree

## How many entries to print. Ten because that is what #209 asked for — enough
## to see a pattern (eight identically-sized [code]*_2.jpg[/code] entries, one
## per car style, in the run this was written against) without paging through
## all 409.
const TOP_N: int = 10


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		printerr("usage: godot --headless --script scripts/pck-top-ten.gd -- <path-to.pck>")
		quit(1)
		return
	var pck_path: String = args[0]
	if not ProjectSettings.load_resource_pack(pck_path):
		printerr("pck-top-ten: could not load '%s' as a resource pack" % pck_path)
		quit(1)
		return

	var entries: Array = []
	var top: DirAccess = DirAccess.open("res://")
	if top == null:
		printerr("pck-top-ten: could not open res:// after loading the pack")
		quit(1)
		return
	_walk("res://", top, entries)

	if entries.is_empty():
		printerr("pck-top-ten: the pack loaded but nothing was found under res:// — see the")
		printerr("usage note above about running this from a directory with no project.godot")
		quit(1)
		return

	entries.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	var total: int = 0
	for entry: Array in entries:
		total += entry[1]

	print("pck-top-ten: %s — %d entries, %d bytes stored" % [pck_path, entries.size(), total])
	print("")
	for i: int in range(min(TOP_N, entries.size())):
		print("  %10d  %s" % [entries[i][1], entries[i][0]])
	quit(0)


## Every file under [param path], recursively, appended to [param entries] as
## [code][full_path, byte_length][/code] pairs. Directories are descended into
## and never themselves appended — a directory has no length worth ranking.
func _walk(path: String, dir: DirAccess, entries: Array) -> void:
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if name == "." or name == "..":
			name = dir.get_next()
			continue
		var full: String = path.path_join(name)
		if dir.current_is_dir():
			var sub: DirAccess = DirAccess.open(full)
			if sub != null:
				_walk(full, sub, entries)
		else:
			var fa: FileAccess = FileAccess.open(full, FileAccess.READ)
			if fa != null:
				entries.append([full, fa.get_length()])
		name = dir.get_next()
