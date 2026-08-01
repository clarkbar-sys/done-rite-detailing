# Done Rite Detailing

> A game built with the [Godot](https://godotengine.org) engine.

[![CI (Godot)](https://github.com/clarkbar-sys/done-rite-detailing/actions/workflows/ci-godot.yml/badge.svg)](https://github.com/clarkbar-sys/done-rite-detailing/actions/workflows/ci-godot.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)

## Overview

Done Rite Detailing is an in-development game: a Godot 4 project that
type-checks, boots headlessly, and exports a playable build — in your browser,
or as a Linux binary — from CI. It opens on a title screen played over the
detailing bay itself, with the camera circling the car; Start drops you
straight into that same room, standing beside the car with a tool in your
hand. Four arrows down the right-hand edge walk you around it and raise and
lower your eye — hold one to move, let go to stop, or use the arrow keys or
WASD — and a **T** in the opposite corner rolls out the five tools you carry.
Press anywhere on the car and the tool in your hand swings to point at it,
with a red crosshair on the paint where it lands; press past the car and the
crosshair snaps to the nearest bodywork instead. Holding is aiming, letting go
is not. On a touchscreen the aim is taken a thumb's width above your finger
rather than under it — the one part of a phone you cannot see is the part you
are touching — so the mark stays in view while you drag it around the paint. A
mouse aims at the pointer, because a cursor hides nothing.

And the trigger now spends something. The car starts under mud, and holding the
power wash on a panel takes it off where the water lands — a patch at a time,
each one announced as it comes clean. Every panel carries its own dirt mask,
addressed by a six-plane projection worked out from the point you hit rather
than from a UV map anybody unwrapped, so washing the driver's door leaves the
passenger's door filthy; the mud *pattern* over it is sampled triplanar, which
is the half of that job blending is safe for. Press **G** for the twelve masks
themselves, which is how you tell a projection bug from a raycast one. Only the
power wash does anything so far — the sponge, the cloth and the two sprays have
their channels allocated and nothing to write to them yet. The room is still
boxes and the car is still a green one under all that; see the
[day-0 initiative](https://github.com/clarkbar-sys/done-rite-detailing/issues/5)
for what's queued.

The Godot editor and export templates are **not vendored**. They're downloaded
on demand and **checksum-verified** against the pins in
[`scripts/fetch-godot.sh`](./scripts/fetch-godot.sh), so the repo stays lean
while your machine and CI build with the byte-identical toolchain. Nothing is
installed system-wide — it all lands in `.godot-sdk/`. The
[GUT](https://github.com/bitwes/Gut) test addon gets the same treatment via
[`scripts/fetch-gut.sh`](./scripts/fetch-gut.sh) and lands in `addons/gut/`.

## Play it

### 👉 [clarkbar-sys.github.io/done-rite-detailing](https://clarkbar-sys.github.io/done-rite-detailing/)

That's the current `main`, in your browser, republished by CI on every push. No
download, no `chmod`, nothing to install. It needs WebGL 2 and about 40 MB on
the first load; there is no service worker, so a refresh always gets the newest
build rather than a cached one.

Prefer a local copy? Every CI run on `main` and on every pull request uploads
both a Linux binary and the web bundle — grab them from the run's **Artifacts**
section on the
[Actions tab](https://github.com/clarkbar-sys/done-rite-detailing/actions/workflows/ci-godot.yml)
— and every tagged build is attached to
[Releases](https://github.com/clarkbar-sys/done-rite-detailing/releases):

```bash
chmod +x done-rite-detailing-*-linux-x86_64
./done-rite-detailing-*-linux-x86_64

# or the web bundle, which is a plain static site
unzip done-rite-detailing-*-web.zip && (cd web && python3 -m http.server)
```

Every build knows which commit it came from — it prints `v<version> (<sha>)` on
startup (to stdout on Linux, to the browser console on the web) and shows the
same string on screen.

There are no Windows or macOS builds, deliberately — the
[Coding Standards](./STANDARDS.md#windows-and-macos-not-now) say why, and what
would change that. The web build is the answer in the meantime.

## Development

Needs `bash`, `curl`, `unzip`, `git`, `make` and `python3` (the last only for
`make lint` / `make format`). The first command downloads Godot (~76 MB) and
the GUT test addon (~3 MB), and the first `make build` / `make build-web` also
pulls the export templates (~1.2 GB, pruned to ~300 MB on disk — the Linux pair
plus the two web `nothreads` ones). All are cached afterwards in
`.godot-sdk/` and `addons/gut/`; `make lint` likewise caches a small Python
venv in `.venv-lint/`.

```bash
make check     # type-check every script — a CI gate
make smoke     # boot the game headless and require a clean run
make gut       # run the tests/ suites headless with GUT — a CI gate
make tested    # require every src/ script to be reached by a test — a CI gate
make test      # all four of the above; run this before you push
make lint      # gdformat --check + gdlint — a separate, faster CI gate
make format    # gdformat, rewrites in place
make build     # export the Linux release binary -> build/linux/
make build-web # export the web bundle           -> build/web/
make editor    # open the project in the Godot editor
make run       # run the game
make clean     # remove build outputs (keeps the downloaded toolchains)
make distclean # also drop .godot-sdk/, .venv-lint/ and addons/gut/
```

To move to a newer Godot, run `scripts/fetch-godot.sh --update`. It prints the
latest upstream stable version and its checksums; update the three pins at the
top of that script, then re-run `make test build` before pushing.
`scripts/fetch-gut.sh --update` does the same for the test addon.

### Layout

```
project.godot          engine + project settings (typed-GDScript gates live here)
export_presets.cfg     export targets; "Linux" for `make build`, "Web" for `make build-web`
src/core/              cross-cutting code (shared helpers, game states, process-global facts)
src/main/              the entry scene — owns the state machine and swaps screens
src/screens/           one scene per game state, all of them a `GameScreen`
src/world/             the places the game happens in, instanced by the screens that show them
tests/unit/            tests for pure logic — no scene tree
tests/integration/     tests that need a scene tree
scripts/               developer tooling (toolchain fetch, build stamping, gates)
```

There is no coverage percentage, deliberately: GDScript has no line-coverage
instrumentation worth gating on, and `make tested` stands in its place. The
[Coding Standards](./STANDARDS.md#coverage) record what was measured and why.

`tests/` and `addons/gut/` are excluded from the exported game — in **both**
presets, which filter independently — see `export_presets.cfg`. CI checks the
web pack for them rather than trusting the filters.

The web build renders in Compatibility (WebGL 2) while the desktop build uses
Forward+; that is Godot's own per-platform override rather than a second
configuration, and the
[Coding Standards](./STANDARDS.md#renderer-forward-on-desktop-gl_compatibility-on-the-web)
record what it costs.

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) and the
[Coding Standards](./STANDARDS.md) — GDScript here is **statically typed**, and
that's enforced by the compiler rather than by review. Please also read our
[Code of Conduct](./CODE_OF_CONDUCT.md).

## Releases

Releases are automated with
[release-please](https://github.com/googleapis/release-please). Commit using
[Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`,
`chore:` …) and a **Release PR** is opened and kept up to date automatically —
it bumps the version (including `config/version` in `project.godot`) and updates
[CHANGELOG.md](./CHANGELOG.md). Merge that PR to tag the release; the same
workflow then exports the game — the Linux binary and the web bundle — and
attaches both to the release. The [link above](#play-it) is always current
`main`; a release asset is the version you can still get back to in a year.

## Security

Found a vulnerability? See [SECURITY.md](./SECURITY.md) — please do **not** open a
public issue for security reports.

## License

Distributed under the terms of the [MIT license](./LICENSE).
