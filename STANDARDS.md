# Coding Standards

House standards for this repo. The goal is *tight and enforced*: every rule here
is backed by a config file and gated in CI, so "following the standard" mostly
means "let the tools run."

| Language | Format | Lint / analyze | Types | Tests + floor | Enforced by |
| -------- | ------ | -------------- | ----- | ------------- | ----------- |
| GDScript | `gdformat --check` | `gdlint` (`.gdlintrc`) | **typed GDScript, warnings-as-errors** | **GUT unit + integration, headless, gated**; headless smoke; **no line-coverage floor — [see below](#coverage)**, a test-map gate instead | `.github/workflows/ci-godot.yml` |

Run `make test` locally before pushing — CI runs the same commands, split
across the `check` and `test` jobs.

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
- **Anything a finger has to hit** clears `TouchTarget.min_design_size()` on
  both axes — 164 design px today, and a test asserts it rather than a review
  noticing it. The design is scaled to about a third on a phone, so a control
  that looks generous at 1280×720 can be 18 px tall in a hand, and a target
  nobody can hit reads as a game that ignores them, not as a small button.
- **One state, one screen.** What the game is doing is a `GameState` subclass in
  `src/core/` (Node-free, so a transition is a unit test); what the player sees
  is a `GameScreen` scene in `src/screens/`. A screen asks `GameStateMachine`
  for the state it wants next and nothing else — `src/main/main.gd` is the only
  script that loads or frees a screen, so screens never name each other.
- **Prefer a seam over a stub.** If a function can only be tested by planting a
  file somewhere real, split the parsing out of the I/O and test that.
  `BuildInfo.parse_stamp` is the worked example.

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

### Tests

[GUT](https://github.com/bitwes/Gut) 9.7.1, pinned and fetched by
[`scripts/fetch-gut.sh`](./scripts/fetch-gut.sh) into a gitignored
`addons/gut/` — same "reproducible, not vendored, not ambient" treatment as
Godot itself. GUT publishes no immutable release asset, so the pin is a commit
SHA plus a sha256 over the extracted addon tree rather than a tarball digest;
that script explains why at length.

```bash
make gut     # the suites, headless
make tested  # every src/ script is reached by a test (see Coverage below)
make test    # check + smoke + gut + tested — run this before you push
```

Layout, and the rule for choosing:

| Directory | For | Rule of thumb |
| --------- | --- | ------------- |
| `tests/unit/` | pure logic | if it needs a `SceneTree`, it doesn't go here |
| `tests/integration/` | anything with a scene tree | instantiating a scene, `_ready()`, signals, frames |

Test scripts are **not** exempt from the house standard. They're picked up by
`make check` and `make lint` like any other script, so they're typed, tabbed
and `##`-documented too. GUT's own code *is* exempt — it's third-party
(`exclude_addons=true`, and `addons/` is out of `.gdlintrc`'s scope).

Tests live outside the shipped pack: `tests/*` and `addons/gut/*` are both in
the export's `exclude_filter`. Verified by exporting a `.pck` with and without
those entries — 1.46 MB with the framework and the tests in it, 9.7 KB without.

**Trust the output, not the exit code.** GUT 9.7.1 exits `1` on a failing
assert (verified: deliberate failure ⇒ `make test` non-zero), but it also exits
`0` when it runs *nothing at all* — a missing `tests/` directory, a bad
`-gdir`, or its own class names not yet imported. All three verified. It exits
`0` for a test that asserts nothing, too: GUT calls that "risky", prints
`[Risky]: <name> did not assert`, and returns success. Verified with a test
whose entire body is `pass`. So `make gut` gates on the run summary as well —
at least one script collected, zero risky/pending tests — exactly like
`make smoke` gates on its log; the Makefile records the specifics.

#### Why GUT and not GdUnit4

Both are alive and both would work; this is a preference, not a verdict.
[GdUnit4](https://github.com/MikeSchulze/gdUnit4) 6.2.0 has the richer feature
set — fluent assertions, a scene runner, JUnit/HTML reports, an official CI
action — and lists Godot 4.7 support, but only as far as `4.7.1-rc1`, whereas
this project pins `4.7.1-stable`. GUT 9.7.1 ships changes made *for* 4.7 (its
doubles were reworked for 4.7's stricter return typing) and its compatibility
claim is about the release we actually run.

The rest is fit. GdUnit4 is half a C# framework — a `.csproj`, a NuGet package,
a .NET half of the test API — and we have no C# and no .NET in this toolchain;
that's surface to keep working for no benefit. GUT is GDScript only, its
runner is one script invoked with flags (no wrapper `runtest.sh`, no extra
action to pin), and its whole CLI is small enough to read, which is how the
exit-code traps above got found rather than guessed at. Neither offers
coverage, so that didn't decide it.

WAT was not considered further: last release v6.0.1, no 4.x line.

#### Coverage

**Decision: no line-coverage floor for GDScript.** The 80% the rest of the
house standard enforces (`gcovr` for C, `pytest-cov` for Python) has no honest
equivalent here. What is gated instead is `make tested`, below.

This is a measurement, not an opinion. Every candidate was run, not read:

| Candidate | Version | Verdict |
| --------- | ------- | ------- |
| GUT | 9.7.1 | no coverage of any kind — `grep -ril coverage addons/gut/` matches nothing |
| GdUnit4 | 6.2.0 (`d6e65c6`) | none either; the word only appears in prose and issue-number comments. Not a reason to reopen the framework choice |
| `dsnopek/godot-gdscript-coverage` | — | **does not exist.** `git ls-remote https://github.com/dsnopek/godot-gdscript-coverage.git` cannot resolve it while sibling repos under the same owner resolve fine. The URL in issue #12 is wrong; there is no such add-on to evaluate |
| `jamie-pate/godot-code-coverage` | `main` @ `3c92852` (2025-12-17) | the only real candidate. Fails, in two independent ways — below |
| `IgorBayerl/nano-coverage-godot` | v0.4.0 (`fce7a0a`, 2026-06-13) | alpha, self-described "developer preview", C++ GDExtension with no published binaries and no release automation, tags stop at v0.1.1 so there is nothing to pin. Integrates with GdUnit4 only ("GUT" is on the roadmap). Its own v0.4.0 changelog: for several releases the GdUnit4 hook was registered under a settings key *no GdUnit4 version reads*, so "any CLI/CI test run silently produced no coverage." A coverage tool that has already shipped a silent zero is the exact failure this section exists to avoid |
| `koalafr/godot-coverage-hack` | v1.0.0 (2022) | matches `Foo.gd` to `test_Foo.gd` by filename and, in its own words, "ignores file content". That is not coverage; it is the ritual number issue #12 warns about, with a Cobertura extension |

##### Why the real candidate fails

`godot-code-coverage` rewrites each script's source at test time, injecting a
counter before every statement, then calls `Script.reload()`. Run against this
project on Godot 4.7.1:

1. **It does not compile.** `addons/coverage/coverage.gd:462` overrides
   `get_coverage_collector()` in an inner class and returns `self`; the base
   declares `-> ScriptCoverageCollector`. Godot 4.7.1 rejects the override —
   `Cannot return value of type "NullCoverage" because the function return
   type is "ScriptCoverageCollector"`. A hard parse error, so
   `exclude_addons=true` does not help. And the run still went green: GUT
   printed `---- All tests passed! ----` and exited 0 with the post-run hook
   erroring and coverage never collected.
2. **The instrumented code it emits is untyped.** After forking that one line,
   every first-party script failed to reload: `Variable "__cl__" has no static
   type`, `The method "append()" is not present on the inferred type
   "Variant"`. Reported coverage: **0.0%**. Relaxing the warning levels at
   runtime from the pre-run hook does not help — the parser reads them at
   startup. The only way to a number is to demote the warnings-as-errors in
   `project.godot`, which is the single strongest gate this repo has.

##### And the number it produces is not defensible

With the fork applied *and* the typing gates switched off, it reports 93.75%
(30/32 lines) for this project. That number is wrong in both directions, and
the reasons are structural rather than fixable:

- **`match` bodies are invisible.** The instrumenter only counts the `match`
  line itself. A function whose whole body is a five-arm `match`, tested with
  exactly one input, reports **100.0%** — measured, not inferred. `match` is
  the dominant branch construct in GDScript, so the metric is at its weakest
  exactly where a game's logic is densest. `elif`/`else` lines are skipped too
  (deliberately, in its source).
- **Lines inside `"""` strings are counted as executable** and get counter
  calls spliced into them — the tool's own source says it ignores multiline
  strings. So a docstring-style constant both inflates the denominator with
  lines that can never be covered and corrupts the constant's value under test.
- The denominator is whatever instrumented successfully. A file that fails to
  instrument leaves the denominator entirely, which moves the percentage *up*.

A metric that reads 100% for a five-way branch with one case tested is worse
than no metric: it converts a real signal into a ritual. So it is not adopted,
and no percentage is published anywhere in this repo.

##### What is gated instead

[`scripts/check-test-map.sh`](./scripts/check-test-map.sh), wired as
`make tested`, run as the first step of CI's `test` job (no Godot needed — it
is grep over the checkout, so it fails in seconds rather than after a 76 MB
download):

| Rule | What it requires |
| ---- | ---------------- |
| R1 | every `.gd` under `src/` is named by at least one test — by its path, its `class_name`, or the `.tscn` that carries it |
| R2 | every `.gd` under `src/core/` has its own `tests/unit/test_<name>.gd` |
| R3 | every `.gd` under `src/core/` extends a Node-free base (`RefCounted`, `Resource`, `Object`) — directly, or through a first-party class that does — so R2 can always be satisfied honestly instead of by moving the file |

R3 is the load-bearing one. It is what makes "keep game logic in plain
testable classes" a rule rather than advice, and it is an allow-list, so a base
class nobody has listed fails the check instead of slipping through. The
allow-list holds **engine** classes only: a first-party base is resolved rather
than listed — `TitleScreenGameState extends GameState` is judged by what
`GameState` itself extends, all the way up. Listing first-party names instead
would be the hole it exists to close, because re-basing one of them onto a
`Node` would go on passing for every subclass. Together
with `make gut`'s risky-test gate — which fails a test that asserts nothing —
the pair cannot be satisfied by an empty file. All four failure modes verified
by breaking them one at a time; each exits 1.

**What this does not do, said plainly.** It checks that a test *exists* and
runs, not that it is *thorough*. Logic that lives in a scene-tier script
(`src/main/*.gd`) only has to be named by an integration test, not exercised
by one. Keeping logic out of `Node` subclasses, and making each test deep
enough to be worth its line count, is **advisory** — a review responsibility,
not a mechanical one. A coverage percentage would not have made it mechanical
either; it would only have made it look mechanical.

**When to revisit.** When the engine grows first-party coverage, or when a
tool exists that instruments without rewriting source into untyped GDScript
and counts `match` arms. Both are checkable claims. Nothing about this
decision changes because the project got bigger.

---

## Distribution

The cheapest thing anyone can do with the game is click a link, so that is the
channel that gets kept working. Three decisions hold it up; all three were
measured rather than argued, and each one names the thing that should make us
reopen it.

| Channel | What it is | Refreshed |
| ------- | ---------- | --------- |
| **GitHub Pages** | the web bundle from `main` | every push to `main` (`ci-godot.yml`'s `pages` job) |
| **Release assets** | `…-linux-x86_64` and `…-web.zip` | every tagged release (`release.yml`) |
| **CI artifacts** | both, per run | every push and PR |

```bash
make build      # the Linux binary  -> build/linux/
make build-web  # the web bundle    -> build/web/
```

Pages has to be switched on **by hand, once**: *Settings → Pages → Build and
deployment → Source → **GitHub Actions***. Until someone does, the `pages` job
fails at `actions/configure-pages` on every push to `main`.

### Renderer: Forward+ on desktop, `gl_compatibility` on the web

The engine owns this split; there is no configuration to maintain. Godot 4.7.1
registers `rendering/renderer/rendering_method.web` itself as a **one-value
enum** whose only value is `gl_compatibility` — `main/main.cpp`, with the
comment "This is a bit of a hack until we have WebGPU support" — and a
feature-tagged override beats the plain key. So `project.godot` keeps saying
`forward_plus` and the web build renders in Compatibility anyway. Verified in
the browser, not inferred: the exported bundle logs

```
OpenGL API OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) - Compatibility
```

There was never a third option — Vulkan is not available to a browser, so
"ship Forward+ to the web" is not a thing that can be chosen. The genuine
question was whether **desktop** should drop to `gl_compatibility` too, for one
renderer everywhere. It doesn't, because the split costs zero lines and
`forward_plus` is strictly more capable where it runs.

**The cost, stated plainly.** A Forward+-only feature — SDFGI, volumetric fog,
SSIL/SSAO, the Vulkan-only parts of the sky and light pipeline — is simply
absent from the build most people will click on, and no gate here can see that:
CI exports the bundle, it does not look at pixels. So the rule is: **anything
visual is checked in the web build before it is called done** — and **on a
phone-shaped screen, with a tap**, because that is the shape most people will
open the link in. That is advisory, exactly like "keep logic out of `Node`
subclasses" under [Coverage](#coverage), and for the same reason — it is a
review responsibility, not a mechanical one.

Both halves of it were learned the expensive way. On an emulated Pixel 7
(411×838 CSS px), `window/stretch/aspect="keep"` turned the game into a 411×231
strip with three quarters of the screen dead black, and a Start button that
looked comfortable at 1280×720 measured 70×18 CSS px — so taps missed it and the
game looked like it had stopped responding. A browser's device emulation
reproduces both in about a minute, which is how those numbers were arrived at.
What came out of it is written where it can't be forgotten: `project.godot`
carries the stretch measurement, and `TouchTarget` in `src/core/` turns "big
enough for a finger" into a number the tests gate.

**When to revisit.** The first time a Forward+-only feature is actually wanted.
Decide then, with something real to look at: either drop desktop to
`gl_compatibility` (one line, and the divergence is gone) or accept the
divergence knowingly. Settling it now, at day 0, is the point — there is
nothing to lose today, which will not be true later.

### Threads: the `nothreads` template, not COOP/COEP

`export_presets.cfg` sets `variant/thread_support=false`, and
`scripts/fetch-godot.sh` therefore unpacks `web_nothreads_release.zip` /
`web_nothreads_debug.zip` rather than the threaded pair. Godot 4.7.1 ships all
eight web templates (threads/nothreads × dlink/plain × debug/release), so this
is a live choice, not a workaround for something missing.

A threaded Godot web build needs `SharedArrayBuffer`, which browsers only give
to a cross-origin-isolated page, which needs the **server** to send
`Cross-Origin-Opener-Policy: same-origin` and
`Cross-Origin-Embedder-Policy: require-corp`. GitHub Pages sends neither and
has no way to configure headers.

Measured, both ways, against a local `python3 -m http.server` — which sends no
COOP/COEP either, so it reproduces Pages exactly:

| Bundle | Result in a real browser |
| ------ | ------------------------ |
| `thread_support=false` | boots. `crossOriginIsolated: false`, no `SharedArrayBuffer`, and it does not care — `Build configuration: Emscripten 4.0.20, single-threaded, no GDExtension support.` then the game's own startup line |
| `thread_support=true` | refuses. "The following features required to run Godot projects on the Web are missing: Cross-Origin Isolation … SharedArrayBuffer …" and a 300×150 canvas that never initialises |

The template explains the asymmetry: `godot.js`'s `getMissingFeatures()` wraps
both checks in `if (supportsThreads)`, and the emitted `index.html` bakes in
`const GODOT_THREADS_ENABLED = false`.

The two alternatives, and why neither won:

- **A host that can set headers** (itch.io, Cloudflare Pages). Works, and buys
  real threads. Rejected for now because it is another account, another
  deploy credential and another thing to keep in sync with `main`, to buy
  performance a title screen cannot spend. Revisit when the game is heavy
  enough that single-threaded is measurably the problem — and measure it,
  don't assume it.
- **Godot's own service-worker shim** (`progressive_web_app/enabled` +
  `progressive_web_app/ensure_cross_origin_isolation_headers`), where
  `godot.service.worker.js` intercepts fetches and adds the two headers itself.
  Real, and it is in the 4.7.1 template. Rejected because it only isolates the
  page *after* the worker installs and the page reloads, and because a service
  worker caches the previous build — directly against "the link is always
  current `main`". With the PWA off, the exporter skips
  `godot.service.worker.js` and `godot.offline.html` entirely, so the published
  bundle has no cache layer at all. Verified: neither file is in `build/web/`.

Cost of the decision: no `SharedArrayBuffer`, so no threaded audio or physics
in the browser, and WebAssembly SIMD is the only parallelism available.
Accepted.

### The loading screen: one vendored file, re-diffed on every Godot bump

**Decided.** `html/custom_html_shell` points the web export at
[`web/shell.html`](./web/shell.html) — Godot's `misc/dist/html/full-size.html`
with the start menu's lockup on it and a red progress bar where the Start pill
goes. The logo reaches it through `application/boot_splash/image`, which the
exporter writes out as `index.png` and substitutes into `$GODOT_SPLASH`, so
`assets/brand/` stays the one home of the artwork.

**This is the project's only vendored upstream source file**, and it is
vendored because there is no alternative: the exporter reads one HTML file and
substitutes its placeholders, so there is nothing to hook and nothing to patch.
Everything else third-party is fetched and pinned instead (see
`scripts/fetch-godot.sh`), which is why this earns a rule of its own:

- **Bumping Godot means diffing the shell.** `scripts/fetch-godot.sh --update`
  tells you to re-run `make check build` after changing the pins; add
  `diff`ing the new release's `misc/dist/html/full-size.html` against
  `web/shell.html` to that list. The `<script>` block in ours is byte-identical
  to upstream's on purpose, so an engine-side change to the loader shows up as
  a clean conflict rather than as a page that silently stops booting.
- **The gate is a unit test, not a build.** A missing `$GODOT_*` placeholder
  cannot fail a type check, a smoke run or an export — it fails in a browser,
  which nothing in CI opens. `tests/unit/test_web_shell.gd` reads the file and
  asserts the placeholders and the scripted element ids are still there.
- **Emptying the setting is a silent downgrade,** not an error: the export
  falls back to the stock grey shell and says nothing.

Cost of the decision: one file that can drift from upstream, and a step on
every engine bump. Accepted, because the alternative is the first thing every
player sees being the engine's branding rather than the business's.

### Windows and macOS: not now

**Not built.** The trigger to revisit is somebody asking — a real report of
"I couldn't try it", not a guess that someone might.

The reasoning is that they are two different problems wearing one label:

- **Windows** is genuinely cheap. It cross-compiles from Linux CI with the
  templates already in the archive `scripts/fetch-godot.sh` downloads; the
  whole change is a preset, two `KEEP_TEMPLATES` entries and a job. It is not
  free, though — Windows binaries without a code-signing certificate get
  SmartScreen's "Windows protected your PC" wall, which is a worse first
  experience than the web build it would be competing with.
- **macOS** is not cheap. An unsigned, un-notarised `.app` from the internet is
  refused outright by Gatekeeper on current macOS, and the workaround is a
  right-click dance most people will not do. Notarisation needs a paid Apple
  Developer account, a Developer ID certificate, and `notarytool` credentials
  in CI secrets. Shipping an unsigned macOS build is hostile to exactly the
  person who was curious enough to download it.

The web build makes both of them less urgent rather than more: it is the
platform-neutral answer to "can I try it", it needs no certificate on any
platform, and it is refreshed on every push. So the honest answer is that
desktop builds are a **packaging** problem to solve when someone wants to keep
a copy, and until then the effort belongs on the game. When that day comes,
Windows first and alone; macOS only with a signing identity in hand, because a
macOS build without one is worse than no macOS build.

---

## Cross-cutting

- **Commits:** [Conventional Commits](https://www.conventionalcommits.org/)
  (`feat:`, `fix:`, `chore:` …) — required for release-please. See
  [CONTRIBUTING.md](./CONTRIBUTING.md).
- **Toolchain:** pinned by sha256 in
  [`scripts/fetch-godot.sh`](./scripts/fetch-godot.sh). A Godot bump is a
  reviewable commit that changes those pins — never an ambient "whatever is
  installed".
- **Builds are traceable:** every exported build carries the commit it was
  built from (`build_stamp.json` → the `BuildInfo` class) — the Linux binary
  prints it to stdout, the web build prints the same line to the browser
  console and shows it on screen.
- **Distribution:** the game is playable from a link, refreshed on every push
  to `main` — see [Distribution](#distribution) for the renderer, threading and
  desktop-platform decisions behind that.
- **Editors:** [`.editorconfig`](./.editorconfig) is the source of truth for
  charset, line endings, final newline, and indentation.
- **CI gates before merge:** type check, headless smoke, the test map, the GUT
  suites, a Linux export that boots, and a web export whose pack contains
  neither `tests/` nor GUT must all be green. Enable branch protection on
  `main` and add the `ci-godot` jobs as required checks.
