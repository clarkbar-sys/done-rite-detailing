# Done Rite Detailing

> A game built with the [Godot](https://godotengine.org) engine.

[![CI (Godot)](https://github.com/clarkbar-sys/done-rite-detailing/actions/workflows/ci-godot.yml/badge.svg)](https://github.com/clarkbar-sys/done-rite-detailing/actions/workflows/ci-godot.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)

## Overview

Done Rite Detailing is an in-development game: a Godot 4 project that
type-checks, boots headlessly, and exports a playable build — in your browser,
or as a Linux binary — from CI. It opens on a title screen with the game
already being played behind the card — a filthy car being washed, cleaned and
buffed by nobody, in the bay you are about to stand in — and Start drops you
straight into that same room, standing beside the car with a tool in your
hand. A thumb stick in the bottom-right corner walks you around it and raises
and lowers your eye — push it and you move, at whatever speed you push it, in
any direction at once; let go and it springs back and you stop. The arrow keys
and WASD do the same job at a desk. A **T** in the opposite corner rolls out
the five tools you carry.
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
themselves, which is how you tell a projection bug from a raycast one.

And all five tools do something now, because the job is three passes rather than
one. Water takes mud off any panel; a cleaner then goes onto the bare paint it
left — the sponge on bodywork, the window cleaner on glass, the tyre cleaner on
the wheels, and the wrong bottle for a surface does nothing at all; the drying
rag buffs that product out into a shine, which is the only way a panel gets
finished. What keeps those three in order is not a rule anybody wrote down: a
texel divides its surface between mud, product, shine and bare paint, and each
tool moves units from one of those to another. So a sponge on a muddy wing has
no bare paint to draw from and a rag on a dry one has no product, and neither
needs refusing. Nor can you leave the water till last — the jet takes the
product off with the mud, so spraying a window you have just cleaned rinses it
back to bare glass. It leaves a buffed panel alone, though: wax is not something
lying on the paint, and a stray jet costing you three passes of work would be a
punishment for imprecision rather than a rule anybody can learn. [`src/core/grime_map.gd`](./src/core/grime_map.gd) has the
argument at length.

And you can hear it now. Start rings a counter bell, and every patch that comes
clean under the jet rings a smaller one — so a sweep that finishes three of them
is three dings rather than a texture quietly changing colour. Both are struck
bells built out of arithmetic at startup rather than recordings in the repo:
the pitch, the length and the decay are numbers in
[`src/core/bell.gd`](./src/core/bell.gd), so retuning the ding is a diff instead
of a re-recording. The bell on Start is also the press a mobile browser unlocks
audio on, which is why the game is deliberately silent until you touch it.

And the tools can be heard as well as seen. Hold the trigger and the power wash
runs — a band of water noise with a pump buzzing underneath it — and letting go
stops it; either bottle hisses like the aerosol it is, the drying rag squeaks
once per pass of your hand, and the sponge squelches as it is pressed. Four
sounds for five tools, because the two bottles are the same spray with different
liquid in them. They are generated the same way the bells are and for the same
reasons, with one extra: a loop recorded as a file has to be cut at a zero
crossing by hand and clicks for ever after if it was cut a sample out, where
here the seam is a property of how the sound is built and a test measures it.
The pitch of the squeak, how often the sponge squishes and how wide the jet's
band of noise is are all numbers in
[`src/core/tool_noise.gd`](./src/core/tool_noise.gd);
[`src/world/tool_racket.gd`](./src/world/tool_racket.gd) is what plays them, and
it fades every voice over a twentieth of a second so that pulling the trigger,
letting go and swapping tools mid-press are none of them a click. The demo
behind the title card stays silent through all of it — it is washing a car with
the tools muted, for the same reason it rings no bell.

And the title screen has a theme now — eight bars of loud synth brass at 132 BPM
over a gated snare, which is roughly what a network sports broadcast sounded
like in about 1992. Touch the screen and it starts; press Start and it fades out
over three seconds while the bell rings over the top of it and the game loads
underneath. It is original, it is not a transcription of anything, and like the
bells it is not a file: Godot cannot import a tracker module or a MIDI, so
[`src/core/timbre.gd`](./src/core/timbre.gd) builds six synthetic instruments out
of wavetables and seeded noise, and [`src/core/fanfare.gd`](./src/core/fanfare.gd)
is the score — a tracker pattern written as an array of `step, note, length`.
Retuning the theme, changing the tempo or rewriting a bar is a diff, the whole
thing costs about 390 ms of arithmetic during a load that was happening anyway,
and it adds nothing at all to the download.

And you can now see it from across the room, because the dirt is drawn as an
arcade game rather than as a photograph. Coverage is cut into bands instead of
fading smoothly — a smooth ramp is the honest description of mud thinning out
and it is unreadable in motion, where quantised the jet carves visible terraces
and you can tell a third-clean panel from a half-clean one at a glance. The
leading edge of each band carries a lit line, so washing reads as taking
territory. A patch that finishes throws a coloured square in the colour of the
pass that finished it — water, then the panel's own cleaner, then gold — fed
from the same list that rings the bell, so the light and the ding cannot come
apart. And a buffed panel catches a highlight travelling across the whole car,
which is the reward the wax itself could not be: the coat stays deliberately
faint so it deepens the paint instead of greying it, and the fix for "the paint
went slightly darker" is not a heavier coat but the one thing polish does that
dirt cannot. None of it touches the mask, and none of it can disagree with one —
the bands reach zero exactly where the mask does.
[`src/world/grime.gdshader`](./src/world/grime.gdshader) has each argument where
the uniform it settles is declared.

And the title screen now plays it, which is what an arcade cabinet does with a
machine nobody is standing at. Behind the logo the car is under mud and
somebody is working it: the power wash takes a panel back to bare paint, the
right bottle for that surface goes onto it, the drying rag buffs that out to a
shine, and the eye walks round the car to whatever is being worked on next — a
panel every twelve seconds, biggest first, and when the last one is finished
the mud goes back on and it starts again. What makes it worth having is that
it is not a recording. [`AttractRoutine`](./src/core/attract_routine.gd)
decides what a person would do next and
[`AttractWalk`](./src/core/attract_walk.gd) decides how hard they would push
the stick, and both answers go into the room through the same three doors a
player has — the walk, a press on the glass, and the tool belt. There is no
demo branch in the trigger, the aim, the standoff or the grime, so the attract
mode cannot show a wash the game would not have given you, and the day one of
those breaks the title screen breaks with it. The one thing it does that you
cannot is put the mud back at the end of a lap.

The room is still
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

Those 40 MB are the first thing the game asks of anybody, so they are spent
looking at the business rather than at the engine. The page you wait on is the
start menu's own lockup — the logo in its dark card, the name under it, and a
red bar filling where the Start button will be — instead of Godot's grey
default, and it is printed on the same black the boot splash and the title card
are. The bar is real: it counts the bytes of `index.wasm` and `index.pck` as
they arrive, and falls back to a swept band if the engine ever reports a total
it cannot work out. [`web/shell.html`](./web/shell.html) is that page, and it is
Godot's own template with the brand put on it — its header says what was
changed and what to diff against when the engine is bumped.

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
assets/brand/          the logo the game shares with the business it is named after
src/core/              cross-cutting code (shared helpers, game states, process-global facts)
src/main/              the entry scene — owns the state machine and swaps screens
src/screens/           one scene per game state, all of them a `GameScreen`
src/ui/                what the screens draw and play — HUD pieces, the bell, the title theme
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
