# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Godot 4 game (car-detailing arcade game) written in **statically typed GDScript**, exported to Linux and the web from CI. The Godot editor, export templates, the GUT test addon and the lint venv are all fetched on demand and pinned by sha256 — nothing is vendored or installed system-wide. They land in `.godot-sdk/`, `addons/gut/` and `.venv-lint/` (all gitignored).

The one exception is the **web export template, which this project compiles itself**: `web/build_profile.json` lists the engine modules the game never uses, and `scripts/fetch-web-template.sh` either downloads a published build or compiles one (~50–70 min, once). It is worth 3.2 MB off what a player downloads; there is no fallback to the stock template, by design.

**Never modify `src-models/`** — its `AGENTS.md` forbids agents from touching that folder (Blender source assets).

## Working agreements

- **Work in a git worktree**, not directly on the main checkout.
- **After opening a pull request, do not watch or poll CI on GitHub** — the human handles CI from there.

## Commands

```bash
make test      # check + smoke + gut + tested — run before pushing (what CI runs)
make check     # type-check every .gd (--check-only; typing warnings are errors)
make smoke     # boot the game headless, fail on any logged ERROR
make gut       # run tests/ headless with GUT
make tested    # test-map gate: every src/ script reached by a test (grep, fast)
make lint      # gdformat --check + gdlint (separate CI gate; run `make test lint`)
make format    # gdformat, rewrites in place
make build     # Linux binary  -> build/linux/
make build-web # web bundle    -> build/web/
make web-template # the custom web export template the bundle needs
make run       # run the game
make editor    # open the Godot editor
```

Run a single test script (GUT's `-gselect` matches by filename):

```bash
.godot-sdk/bin/godot --headless --fixed-fps 60 --path . -s res://addons/gut/gut_cmdln.gd \
  -gdir=res://tests -ginclude_subdirs -gdisable_colors -gexit -gselect=test_scoring.gd
```

`--fixed-fps 60` is load-bearing: it makes frame deltas deterministic (the 1/60 the shipped game sees) and cuts suite wall-time ~2×. The Makefile's comments record measured traps — notably that GUT exits 0 when it collects nothing or when a test asserts nothing, so `make gut` gates on the run summary, not the exit code. Trust the Makefile's checks; don't bypass them.

## Hard rules (compiler/CI-enforced)

- **Everything is typed**: every var, parameter and return. `project.godot` promotes the typing warnings (`untyped_declaration`, `unsafe_*`, etc.) to errors, so untyped code fails `make check`. Tests are held to the same standard (typed, tabs, `##` doc comments); only `addons/` is exempt.
- Tabs for indentation; snake_case functions/vars, PascalCase classes, SCREAMING_CASE constants; leading `_` for private.
- **Conventional Commits** (`feat:`, `fix:`, `chore:` …) — release-please builds releases from them.
- The test map (`make tested`, `scripts/check-test-map.sh`) enforces:
  - R1: every `.gd` under `src/` is named by at least one test.
  - R2: every `.gd` under `src/core/` has its own `tests/unit/test_<name>.gd`.
  - R3: every `.gd` under `src/core/` extends a Node-free base (`RefCounted`/`Resource`/`Object`, possibly via a first-party class) — core logic must stay unit-testable.
- Anything a finger has to hit clears `TouchTarget.min_design_size()` on both axes; tests assert it.

## Architecture

**State machine, one state = one screen.** What the game *is doing* is a `GameState` subclass in `src/core/` (Node-free, so transitions are unit-testable). What the player *sees* is a `GameScreen` scene in `src/screens/`. A screen asks `GameStateMachine` for the state it wants next and nothing else; `src/main/main.gd` is the **only** script that loads or frees screens, so screens never name each other.

```
src/core/     cross-cutting, Node-free logic (states, scoring, grime math, synth audio)
src/main/     entry scene — owns the state machine, swaps screens
src/screens/  one scene per game state, all `GameScreen`s
src/ui/       HUD pieces, bells, title theme playback
src/world/    the 3D bay — garage, car, tools, shaders; instanced by screens
tests/unit/         pure logic, no scene tree
tests/integration/  anything needing a scene tree
```

**Prefer `class_name` + static members over autoloads.** `--check-only` resolves global class names but *not* autoload names, so calls through an autoload silently escape the type check. Use an autoload only when you genuinely need a node in the tree.

**Prefer a seam over a stub**: split parsing/logic out of I/O so it's unit-testable (`BuildInfo.parse_stamp` is the worked example).

**The simulation core** is `src/core/grime_map.gd`: each texel divides its surface between mud, product, shine and bare paint, and each tool moves units between those pools — tool ordering (wash → cleaner → buff) emerges from the arithmetic, not from rules. Panels are addressed by six-plane box projection, not UVs. `src/world/grime.gdshader` renders it (quantised bands); visuals never touch the mask.

**Audio is synthesized, not recorded**: bells (`src/core/bell.gd`), tool noises (`src/core/tool_noise.gd`), and the title theme (`src/core/timbre.gd` instruments + `src/core/fanfare.gd` score) are built from arithmetic at startup. Retuning a sound is a diff, not a re-recording.

**Attract mode** (`src/core/attract_routine.gd`, `attract_walk.gd`) drives the title-screen demo through the same input paths a player has — there is no demo branch in the game code.

## Web build constraints

- Exports single-threaded (`nothreads` templates) because GitHub Pages can't send COOP/COEP headers. No `SharedArrayBuffer`.
- Consequence: web audio defaults to *Sample* playback — `volume_db` changes after `play()` are ignored and fades don't work. Where a fade is needed, set `playback_type = PLAYBACK_TYPE_STREAM` per-player (see `Bandstand`).
- Desktop renders Forward+, web renders Compatibility (engine-owned split, no config). **Anything visual must be checked in the web build, on a phone-shaped screen, before it's called done** — CI can't see pixels.
- `web/shell.html` is the one vendored upstream file (Godot's HTML shell, branded). Bumping Godot means re-diffing it against upstream; `tests/unit/test_web_shell.gd` gates its placeholders.
- Saves on web go through IndexedDB — writes to `user://` need an `FS.syncfs` flush or they vanish on reload (see `HighScores` / the sound toggle).
- The web engine is **not the stock one**. `web/build_profile.json` compiles out ~40 modules; `tests/unit/test_web_build_profile.gd` scans `src/` for the classes they provide, so reaching for `RegEx`, a 2D physics body or anything glTF at runtime fails `make gut` rather than the published page. Adding an engine feature to `src/` may mean turning a line in that profile back on — and a module that is off shows up as a feature that silently does nothing, never as a compile or export error.

## Testing notes

- Integration suites may build an expensive fixture once in `before_all` **only if every test leaves it exactly as found** (or resets the one thing it writes in `before_each`). Use `add_child` + `free()` in `after_all` — `add_child_autofree` in `before_all` gets freed after test one, and `queue_free()` reads as a leak.
- A test that asserts nothing ("risky") fails `make gut`, as does `pending()`.
- Toolchain bumps: `scripts/fetch-godot.sh --update` / `scripts/fetch-gut.sh --update` print new pins; update the script, re-run `make test build`.

STANDARDS.md records the measured reasoning behind every gate (coverage decision, renderer/threading choices, GUT exit-code traps) — read the relevant section before relaxing one.
