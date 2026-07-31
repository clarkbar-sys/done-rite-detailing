# Done Rite Detailing

> A game built with the [Godot](https://godotengine.org) engine.

[![CI (Godot)](https://github.com/clarkbar-sys/done-rite-detailing/actions/workflows/ci-godot.yml/badge.svg)](https://github.com/clarkbar-sys/done-rite-detailing/actions/workflows/ci-godot.yml)
[![License](https://img.shields.io/badge/license-GPL--2.0-blue.svg)](./LICENSE)

## Overview

Done Rite Detailing is an in-development game. Today the project is at **day 0**:
a Godot 4 project that type-checks, boots headlessly, and exports a playable
Linux binary in CI. Gameplay comes next — see the
[day-0 initiative](https://github.com/clarkbar-sys/done-rite-detailing/issues/5)
for what's queued.

The Godot editor and export templates are **not vendored**. They're downloaded
on demand and **checksum-verified** against the pins in
[`scripts/fetch-godot.sh`](./scripts/fetch-godot.sh), so the repo stays lean
while your machine and CI build with the byte-identical toolchain. Nothing is
installed system-wide — it all lands in `.godot-sdk/`.

## Play it

Every CI run on `main` and on every pull request uploads a Linux build. Grab it
from the run's **Artifacts** section on the
[Actions tab](https://github.com/clarkbar-sys/done-rite-detailing/actions/workflows/ci-godot.yml),
or download a tagged build from
[Releases](https://github.com/clarkbar-sys/done-rite-detailing/releases):

```bash
chmod +x done-rite-detailing-*-linux-x86_64
./done-rite-detailing-*-linux-x86_64
```

Every binary knows which commit it came from — it prints `v<version> (<sha>)` on
startup, and shows the same string on screen.

## Development

Needs `bash`, `curl`, `unzip` and `make`. The first command downloads Godot
(~76 MB), and the first `make build` also pulls the export templates (~1.2 GB,
pruned to ~280 MB on disk). Both are cached in `.godot-sdk/` afterwards.

```bash
make check     # type-check every script — the CI gate
make smoke     # boot the game headless and require a clean run
make test      # both of the above; run this before you push
make build     # export the Linux release binary -> build/linux/
make editor    # open the project in the Godot editor
make run       # run the game
make clean     # remove build outputs (keeps the downloaded toolchain)
make distclean # also drop .godot-sdk/
```

To move to a newer Godot, run `scripts/fetch-godot.sh --update`. It prints the
latest upstream stable version and its checksums; update the three pins at the
top of that script, then re-run `make test build` before pushing.

### Layout

```
project.godot          engine + project settings (typed-GDScript gates live here)
export_presets.cfg     export targets; `make build` uses the "Linux" preset
src/core/              cross-cutting code (autoloads, shared helpers)
src/main/              the entry scene
scripts/               developer tooling (toolchain fetch, build stamping)
```

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
workflow then exports the game and attaches it to the release.

## Security

Found a vulnerability? See [SECURITY.md](./SECURITY.md) — please do **not** open a
public issue for security reports.

## License

Distributed under the terms of the [GNU GPL v2](./LICENSE).
