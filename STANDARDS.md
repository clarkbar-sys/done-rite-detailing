# Coding Standards

House standards for this repo. The goal is *tight and enforced*: every rule here
is backed by a config file and gated in CI, so "following the standard" mostly
means "let the tools run."

| Language | Format | Lint / analyze | Types | Tests + floor | Enforced by |
| -------- | ------ | -------------- | ----- | ------------- | ----------- |
| GDScript | `gdformat --check` | `gdlint` (`.gdlintrc`) | **typed GDScript, warnings-as-errors** | headless smoke; GUT + floor *pending* | `.github/workflows/ci-godot.yml` |

Run `make test` locally before pushing — CI runs the same commands.

---

## GDScript

**Statically typed, always.** Every variable, parameter and return value carries
a type. This isn't a style preference: untyped GDScript is interpreted with
dynamic dispatch, so typing it is both a correctness gate *and* the single
biggest performance lever the language has.

```gdscript
## Doc comments use `##` and describe the *why*.
class_name Client
extends Node

signal cleaned(vehicle: Vehicle)

const MAX_QUEUE: int = 8

var _queue: Array[Vehicle] = []


func enqueue(vehicle: Vehicle) -> bool:
	if _queue.size() >= MAX_QUEUE:
		return false
	_queue.append(vehicle)
	return true
```

Tabs for indentation (the engine's own style — see `.editorconfig`); snake_case
for functions and variables, PascalCase for classes and nodes, SCREAMING_CASE
for constants; a leading `_` marks private members and intentionally-unused
parameters.

### How it's enforced

The typing rules are **compiler-enforced**, not review-enforced. `project.godot`
sets these GDScript warnings to level 2 (= error), so an offending script fails
to compile:

| Warning | Why it's an error |
| ------- | ----------------- |
| `untyped_declaration` | the core rule — no untyped vars, params or returns |
| `unsafe_property_access`, `unsafe_method_access` | reaching into a `Variant` hides typos until runtime |
| `unsafe_cast`, `unsafe_call_argument` | narrow explicitly, at a place you chose |
| `unsafe_void_return`, `narrowing_conversion`, `int_as_enum_without_cast` | silent type coercion |
| `shadowed_variable`, `shadowed_variable_base_class` | shadowing reads as a bug |
| `unused_variable`, `unused_signal`, `standalone_expression` | dead code, or a call you forgot to make |

`inferred_declaration` (`:=`) and `unused_parameter` are level 1 — visible in the
editor, non-fatal. Addons are exempt (`exclude_addons=true`); third-party code
plays by its own rules.

```bash
make check   # runs `--check-only` over every .gd; non-zero on any error
```

### Beyond the compiler

- **Nodes:** reach for children with unique names (`%Title`) or `@export`ed
  `NodePath`s — never a brittle `../../Sibling` chain.
- **Signals over polling.** Declare them with typed parameters.
- **Prefer a `class_name` with static members over an autoload.** `--check-only`
  resolves global class names but *not* autoload names, so every call made
  through an autoload silently drops out of the type check — the gate above
  stops applying to exactly the globals everything depends on. `BuildInfo` is
  the worked example. Reach for an autoload only when you genuinely need a node
  in the tree (`_process`, signals, lifecycle), and know you're trading away the
  compile-time check when you do.
- **Scenes stay small and composable.** If a scene needs a paragraph to explain,
  split it.
- **Tests live outside the shipped pack** (`tests/` is in the export's
  `exclude_filter`).

### Format & lint

[gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) (`gdformat` +
`gdlint`), version-pinned in [`requirements-dev.txt`](./requirements-dev.txt)
the same way Godot itself is pinned in `scripts/fetch-godot.sh` — a floating
lint tool means CI can start failing with no commit to blame. Installed into a
gitignored venv at `.venv-lint/`, never system-wide.

```bash
make format   # gdformat, rewrites in place
make lint     # gdformat --check + gdlint, CI-safe (never rewrites)
```

`gdformat` and `.editorconfig` agree: both want tabs and a final newline for
`.gd` files, and `gdformat` trims trailing whitespace on top — verified by
running it over the tree and diffing (no-op) and over a deliberately
trailing-whitespace / no-final-newline / space-indented file (fixed all
three, tabs preserved).

`gdlint`'s rules live in [`.gdlintrc`](./.gdlintrc), mostly gdtoolkit's
defaults — they already match the naming/tabs conventions above without
edits. One gap: gdtoolkit 4.5.0 has no function-length / cyclomatic-style
check (max-statements, max-locals, etc. are commented-out placeholders in its
own source, not implemented) — `.gdlintrc` says so rather than faking it with
a rule that doesn't exist.

Confirmed against gdtoolkit 4.5.0 (latest on PyPI as of this writing):
typed signals, `static var`, `_static_init`, `@onready var x: Label = %Name`
and `##` doc comments all parse, format, and lint cleanly — the toolkit's
lagging parser is not a problem for the 4.7 syntax this repo actually uses.

To bump the pin: install the new `gdtoolkit==<version>` in a scratch venv,
`pip freeze` it back into `requirements-dev.txt`, then run `gdlint -d` and
diff the dump against `.gdlintrc` in case a new gdtoolkit release changed a
default. Re-run `make lint` before pushing.

### Parked

Unit tests with [GUT](https://github.com/bitwes/Gut) and a coverage floor to
match the 80% the rest of the house standard uses. Tracked as a sub-issue of
the day-0 initiative; this table gets its last missing cell then.

---

## Cross-cutting

- **Commits:** [Conventional Commits](https://www.conventionalcommits.org/)
  (`feat:`, `fix:`, `chore:` …) — required for release-please. See
  [CONTRIBUTING.md](./CONTRIBUTING.md).
- **Toolchain:** pinned by sha256 in
  [`scripts/fetch-godot.sh`](./scripts/fetch-godot.sh). A Godot bump is a
  reviewable commit that changes those pins — never an ambient "whatever is
  installed".
- **Builds are traceable:** every exported binary carries the commit it was
  built from (`build_stamp.json` → the `BuildInfo` autoload).
- **Editors:** [`.editorconfig`](./.editorconfig) is the source of truth for
  charset, line endings, final newline, and indentation.
- **CI gates before merge:** type check, headless smoke, and a successful export
  that boots must all be green. Enable branch protection on `main` and add the
  `ci-godot` jobs as required checks.
