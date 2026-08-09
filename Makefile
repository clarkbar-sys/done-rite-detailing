# Done Rite Detailing — a Godot 4 game.
#
# The Godot editor and export templates are downloaded on demand and pinned by
# sha256 (see scripts/fetch-godot.sh), so `make` here and CI over there run the
# byte-identical toolchain. Nothing is installed system-wide: everything lives
# under .godot-sdk/ and is thrown away by `make distclean`.
#
#   make check     type-check every script (the CI gate)
#   make smoke     boot the game headless and require a clean exit
#   make gut       run the GUT suites in tests/ headless
#   make tested    require every src/ script to be reached by a test
#   make test      check + smoke + gut + tested (what CI runs)
#   make lint      gdformat --check + gdlint every script (a separate CI gate)
#   make format    gdformat every script in place
#   make build     export the Linux release binary -> build/linux/
#   make build-web export the web bundle            -> build/web/
#   make export-linux / export-web  the same two exports without re-running
#                  `check` first — for CI, where `check` is already its own job
#   make editor    open the project in the Godot editor
#
# There is deliberately no `make coverage`. GDScript has no line-coverage
# instrumentation this project is willing to gate on; `make tested` is what
# stands in its place. STANDARDS.md "Coverage" has the measurements behind
# that decision — read it before adding a percentage to this file.

# Recipes pipe Godot's output through `tee`, and make's default /bin/sh reports
# the exit status of the *last* command in a pipeline. Without pipefail a hard
# crash (segfault, missing binary) is reported as success — verified: `make
# smoke` printed "Smoke test passed" for a run that exited 139.
SHELL      := /bin/bash
.SHELLFLAGS := -o pipefail -c

SDK        := .godot-sdk
GODOT      := $(SDK)/bin/godot
GUT        := addons/gut
GUT_PLUGIN := $(GUT)/plugin.cfg
BUILD_DIR  := build/linux
TARGET     := $(BUILD_DIR)/done-rite-detailing.x86_64
PRESET     := Linux
LOG_DIR    := build/logs

# The web bundle is a directory, not a file: Godot emits index.html plus the
# .js/.wasm/.pck/worklet/icon siblings beside it, all named after the .html.
# `index.html` so a bare directory URL serves the game — see export_presets.cfg.
WEB_DIR    := build/web
WEB_TARGET := $(WEB_DIR)/index.html
WEB_PRESET := Web

# Godot resolves export templates under $XDG_DATA_HOME/godot; pointing it at the
# SDK keeps the pinned templates out of the developer's real ~/.local/share.
export XDG_DATA_HOME := $(abspath $(SDK)/data)

# Headless boot length for `make smoke`. Enough frames for _ready() across the
# whole scene tree plus a few idle frames.
SMOKE_FRAMES ?= 60

# Every .gd in the working tree is type-checked. Deliberately `find` and not
# `git ls-files`: a script you haven't staged yet is exactly the one most likely
# to be broken, and listing tracked files only would skip it silently.
# addons/ is third-party and exempt (see gdscript/warnings/exclude_addons).
SOURCES := $(shell find . -name '*.gd' \
             -not -path './.godot/*' -not -path './.godot-sdk/*' \
             -not -path './addons/*' -not -path './build/*' 2>/dev/null | sed 's|^\./||')

.PHONY: all sdk editor-sdk gut-sdk import check smoke gut tested lint format test build build-web export-linux export-web stamp run editor clean distclean

all: check build

# ---- toolchain -------------------------------------------------------------

# Editor + export templates (~1.2 GB on first run, then cached in .godot-sdk/).
# Phony on purpose: the templates directory is created (empty) by the editor on
# every launch, so a directory target would look up to date and skip the fetch.
# fetch-godot.sh does its own idempotency check and is a no-op once populated.
sdk:
	@scripts/fetch-godot.sh $(SDK)

# Editor only (~76 MB) — all that `import`, `check` and `smoke` need.
editor-sdk: $(GODOT)

$(GODOT):
	@scripts/fetch-godot.sh --editor-only $(SDK)

# The GUT test addon (~3 MB), pinned by commit + tree sha256 in
# scripts/fetch-gut.sh. Same treatment as the Godot SDK and the lint venv:
# fetched on demand, gitignored, never vendored. A real file target, so the
# clone happens once; re-triggered when the pin script changes, and that
# script's own version check decides whether to actually reinstall.
gut-sdk: $(GUT_PLUGIN)

$(GUT_PLUGIN): scripts/fetch-gut.sh
	@scripts/fetch-gut.sh $(GUT)

# ---- develop ---------------------------------------------------------------

# An empty marker that hides build/ from Godot's filesystem scan. It exists for
# a bug that only appeared once something started exporting images into the
# project directory — i.e. once the web preset landed.
#
# THE BUG, MEASURED. Godot's filesystem scan walks the whole project directory,
# and build/ is inside it. The web export writes index.png, index.icon.png and
# index.apple-touch-icon.png; the next scan imported all three, wrote .import
# sidecars *into build/web/*, and — because both presets use
# export_filter="all_resources" — the export after that packed them. Verified
# by reading the pack: res://build/web/index.png and friends plus their .ctex,
# and index.pck grew from 9,776 to 30,988 bytes. It compounds, because every
# build re-exports the icons the previous one left behind, and it is not
# web-only: the Linux binary packs them too. Same family as GUT quietly
# shipping inside every build (see export_presets.cfg) and found the same way,
# by looking in the pack instead of trusting the filter.
#
# An empty `.gdignore` makes the scanner skip a directory outright, so the
# files never become resources at all. That is why it is the fix and
# `exclude_filter` is not: a filter would keep them out of the pack but the
# sidecars would still be written into build/web/ and published to Pages with
# the rest of the bundle. Verified after adding it: no sidecars, no
# .godot/imported entries, zero res://build/ strings in a fresh export.
#
# A real file target, and `import` depends on it, so it is in place before the
# first scan — including via `make editor`, which is how the GUI gets opened.
# Created here rather than committed because `make clean` is `rm -rf build`,
# and a tracked file inside a directory `clean` deletes would leave every
# `make clean` with a dirty tree.
GDIGNORE := build/.gdignore

$(GDIGNORE):
	@mkdir -p $(dir $@)
	@touch $@

# Populate .godot/ (import icon.svg -> .ctex, build the UID cache, register
# global classes). Required once before anything can load the project.
#
# GUT is a prerequisite, not an afterthought, and the ordering is load-bearing
# in both directions:
#   - the import pass is what registers `GutTest` and friends as global class
#     names, and every script in tests/ extends GutTest — so `make check` can't
#     even parse them until GUT is on disk *and* imported;
#   - if it isn't, gut_cmdln.gd prints "Some GUT class_names have not been
#     imported" and calls quit(0). Verified: with .godot/ removed, the runner
#     exits 0 having run nothing at all. Make guarantees both prerequisites
#     complete before this recipe runs, including under `-j`.
import: $(GODOT) $(GUT_PLUGIN) $(GDIGNORE)
	$(GODOT) --headless --path . --import

# The quality gate. `--check-only` parses and type-checks a script and exits
# non-zero on any error, and project.godot promotes the typing warnings to
# errors — so untyped or unsafe GDScript fails here instead of at runtime.
# How many scripts are checked at once. One short-lived Godot process per
# script, each one parsing a file and writing nothing, so they do not interact
# and the only shared resource is the CPU. Measured on a 4-core box — the same
# shape as CI's runner — over the 167 scripts in the tree: 55s serial, 14s at
# -P4. Overridable because the number is the machine's, not the project's.
CHECK_JOBS ?= $(shell nproc 2>/dev/null || echo 4)

# Each worker keeps its own stderr in its own temp file rather than the single
# shared check.log the serial loop used: with several checks in flight at once
# one log is a race, and the failure it loses is the one you needed. A worker
# that fails prints its own diagnostics and exits 1, which xargs turns into a
# 123 for the whole pipeline *after* running the rest — so a broken script
# still reports every other broken script alongside it, exactly as before.
check: import
	@mkdir -p $(LOG_DIR)
	@printf '%s\n' $(SOURCES) | xargs -P $(CHECK_JOBS) -n 1 bash -c '\
	  f="$$0"; err=$$(mktemp); \
	  if $(GODOT) --headless --path . --check-only --script "res://$$f" \
	       >/dev/null 2>"$$err"; then \
	    echo "  check $$f ... ok"; rm -f "$$err"; \
	  else \
	    echo "  check $$f ... FAIL"; cat "$$err"; rm -f "$$err"; exit 1; \
	  fi' \
	  || { echo "Type check failed."; exit 1; }
	@echo "All scripts type-check."

# Proof of life: boot the real project headless. Catches what `check` cannot —
# broken scenes, missing autoloads, node paths that don't resolve.
#
# Godot exits 0 even when a script errors at runtime, so the exit code alone
# proves nothing; the run has to be clean as well. Warnings (push_warning) are
# deliberately allowed through — only errors fail the build.
smoke: import
	@mkdir -p $(LOG_DIR)
	@echo "  booting headless for $(SMOKE_FRAMES) frames ..."
	@$(GODOT) --headless --path . --quit-after $(SMOKE_FRAMES) 2>&1 | tee $(LOG_DIR)/smoke.log
	@if grep -qE '(^|[[:space:]])(SCRIPT |USER )?ERROR:' $(LOG_DIR)/smoke.log; then \
	  echo "Smoke test FAILED — the headless run logged errors (above)."; exit 1; \
	fi
	@echo "Smoke test passed."

# The real tests: every tests/**/test_*.gd, run by GUT's headless CLI.
# tests/unit/ is pure logic, tests/integration/ is anything that needs a scene
# tree; -ginclude_subdirs is what makes both run from the one -gdir.
#
# THE EXIT CODE, MEASURED RATHER THAN ASSUMED (GUT 9.7.1, this Godot):
#
#  - A failing assert really does exit 1. Verified by adding a deliberately
#    failing test: 15 passing => 0, 15 passing + 1 failing => 1, and `make test`
#    with it in place exited 2 (make's own code for a failed recipe).
#
#  - `-gexit` turns out to be belt-and-braces here: GutRunner._handle_quit
#    quits if the flag is set OR the run is headless, and 9.6.0 added that
#    headless clause precisely because people forgot the flag. Measured both
#    ways, failing suite, headless: 1 with the flag and 1 without. It stays
#    because the flag is the documented contract and the headless shortcut is
#    a recent, removable convenience — not because it changes today's answer.
#
#  - THE TRAP: a run that collects nothing exits 0. Verified three ways —
#    `-gdir` at a directory containing no test scripts, `-gdir` at a directory
#    that doesn't exist, and GUT's own class names not yet imported. The first
#    two print "[GUT ERROR]: Nothing was run.", the third "Some GUT class_names
#    have not been imported"; all three exit 0 with no run summary at all.
#    So the exit code is not the gate on its own, exactly as with `make smoke`
#    above: the summary must show at least one script was collected.
#
#  - THE OTHER TRAP: a test that asserts nothing exits 0 too. GUT calls it
#    "risky" and prints "[Risky]: <name> did not assert" plus a
#    "Risky/Pending" line in the summary — and still returns 0. Verified with
#    a test whose whole body is `pass`: "Risky/Pending 1", "---- 1
#    pending/risky tests. ----", exit 0. That matters more here than in a repo
#    with a coverage floor, because `make tested` only checks that a test
#    *exists* for each logic script; without this line the pair would be
#    satisfied by an empty file. `pending()` tests land in the same total and
#    fail here too, on purpose — a pending test on main is a TODO wearing a
#    test's clothes.
#
# `-gdisable_colors` so the log greps cleanly and CI's plain-text view is
# readable; without it the ANSI escapes sit between the ^ and the word.
#
# `--fixed-fps 60` IS THE RUNTIME OF THIS SUITE, AND IT IS ALSO A CORRECTNESS
# FIX. A headless run has no vsync, so the main loop free-wheels: process frames
# come as fast as the CPU can make them while *physics* ticks stay pinned to the
# wall clock at 60 a second. Every `await wait_physics_frames(n)` in tests/ is
# therefore n/60 real seconds of the runner sitting idle, and the integration
# suites are built out of them — `_settle()` alone is 90 ticks, a second and a
# half, and there are 99 calls to it. Measured on CI's runner: the suite took
# 737s wall for 18s of CPU in one job and 730s of that was tests/integration/,
# where tests/unit/ was 8s.
#
# `--fixed-fps` disables that real-time synchronisation and hands every frame a
# fixed 1/60 delta instead, so the loop runs flat out and a frame's worth of
# waiting costs a frame's worth of work. Measured over the whole suite, same
# box, same 1229 tests: 737s -> 348s, and `real` now equals `user` — the idle is
# gone rather than moved. 60 because project.godot leaves
# physics_ticks_per_second at its default 60, so one physics tick per frame and
# every delta in the run is exactly the 1/60 the game itself sees.
#
# THE CORRECTNESS HALF. Pinning the delta also makes the run deterministic
# instead of a function of how loaded the runner was, and the first thing that
# bought was a real bug: ScoreHud's digits stopped 0.01 short of their target
# and truncated to a permanently-wrong score at 1/60 deltas, which is what the
# shipped game runs at. It passed for as long as it did because free-wheeling
# frames are tiny and the last step happened to land square. See the note on
# `ScoreHud._process`. A suite that only passes at thousands of frames a second
# is not testing the game anyone plays.
gut: import
	@mkdir -p $(LOG_DIR)
	@$(GODOT) --headless --fixed-fps 60 --path . -s res://$(GUT)/gut_cmdln.gd \
	  -gdir=res://tests -ginclude_subdirs -gdisable_colors -gexit \
	  2>&1 | tee $(LOG_DIR)/gut.log
	@if ! grep -qE '^Scripts +[1-9]' $(LOG_DIR)/gut.log; then \
	  echo "GUT collected no test scripts — a suite that runs nothing is not a pass."; \
	  exit 1; \
	fi
	@if grep -qE '^Risky/Pending +[1-9]' $(LOG_DIR)/gut.log; then \
	  echo "GUT reported risky/pending tests (above) — a test that asserts nothing is not a test."; \
	  exit 1; \
	fi
	@echo "GUT suites passed."

# What this repo gates on instead of a line-coverage floor: every script under
# src/ has to be reached by a test, and src/core/ has to stay unit-testable.
# scripts/check-test-map.sh states the three rules and what they can't see;
# STANDARDS.md "Coverage" has the evidence for why there is no percentage here.
#
# No Godot and no addon — it is grep over the working tree — so it runs in a
# second and is the first thing CI's `test` job does, before any download.
tested:
	@scripts/check-test-map.sh .

# The one command CI and humans run before pushing. Deliberately check, smoke
# and gut but not lint: those three are "does the game still work", gated by
# CI's `check` and `test` jobs; lint is "does the style pass", gated by CI's own
# `lint` job. CONTRIBUTING.md already treats "test" and "lint" as separate
# steps, and splitting them here means the slow ones (they need the Godot
# editor) and the fast one (lint needs no download, see below) don't force each
# other to wait. Run `make test lint` to get both locally.
#
# smoke before gut: a project that can't boot at all turns every GUT failure
# into a red herring, so let the coarse gate report first. `tested` is last
# because it is the only one that can be satisfied by writing a file rather
# than by fixing the game — hearing about it after the real failures is right.
test: check smoke gut tested

# ---- format / lint ----------------------------------------------------------

# gdtoolkit (gdformat + gdlint), pinned in requirements-dev.txt. Same
# philosophy as the Godot SDK above: fetched into a gitignored, throwaway venv
# on demand, never installed system-wide. Stamped so `make lint`/`make format`
# skip the reinstall once the venv already matches the pin.
LINT_VENV := .venv-lint
GDFORMAT  := $(LINT_VENV)/bin/gdformat
GDLINT    := $(LINT_VENV)/bin/gdlint

$(LINT_VENV)/.installed: requirements-dev.txt
	python3 -m venv $(LINT_VENV)
	$(LINT_VENV)/bin/pip install --quiet --upgrade pip
	$(LINT_VENV)/bin/pip install --quiet -r requirements-dev.txt
	@touch $@

$(GDFORMAT) $(GDLINT): $(LINT_VENV)/.installed

# Check-only and CI-safe: never rewrites a file, non-zero on any violation.
# `.gdlintrc` documents the rule set (and the one thing gdtoolkit can't check).
lint: $(GDFORMAT) $(GDLINT)
	@fail=0; \
	echo "  gdformat --check ..."; \
	$(GDFORMAT) --check $(SOURCES) || fail=1; \
	echo "  gdlint ..."; \
	$(GDLINT) $(SOURCES) || fail=1; \
	[ $$fail -eq 0 ] || { echo "Lint failed."; exit 1; }; \
	echo "gdformat + gdlint clean."

# Rewrites every script in place. Run this, not `lint`, when you actually want
# the fix; CI only ever runs `lint`.
format: $(GDFORMAT)
	$(GDFORMAT) $(SOURCES)

# ---- build -----------------------------------------------------------------

stamp:
	scripts/stamp-build.sh .

# `build` is the local default and keeps the gate in front of the export: you
# asked for a binary, so you get told about a type error before you get one.
#
# `export-linux` IS THAT EXPORT WITHOUT THE GATE, AND IT EXISTS FOR CI. Over
# there `check` is already a job of its own that `build` and `build-web` both
# `need:`, so `make build` in those jobs re-ran a check that had already passed
# on the same commit — three type checks per run, two of them for nothing.
# Measured on the runner: the Linux job spent 65s of its 76s on it and the
# export itself was 3.4s. It still depends on `import`, which `check` was
# quietly providing and the exporter genuinely needs.
#
# The gate is not being dropped, only stated once: nothing reaches `export-*`
# in CI without `check` and `test` having gone green first, and the local
# targets below are unchanged.
build: check export-linux

export-linux: import stamp sdk
	@mkdir -p $(BUILD_DIR)
	$(GODOT) --headless --path . --export-release "$(PRESET)" $(abspath $(TARGET))
	@echo ">> $(TARGET) ($$(du -h $(TARGET) | cut -f1))"

# The web bundle — what GitHub Pages serves and what a release ships zipped.
#
# Same shape as `build` above, and deliberately the same `--headless
# --export-release` invocation: exporting for the web needs no display and no
# special flags. What it does need is the `web_nothreads_*` templates, which is
# why this depends on `sdk` and why scripts/fetch-godot.sh keeps them.
#
# `mkdir -p` is doing more than tidying up here. Godot's web exporter bails with
# "Target folder does not exist or is inaccessible" rather than creating the
# directory (export_plugin.cpp checks DirAccess::exists(base_dir) before writing
# anything) — verified, so on a clean checkout the export fails without it.
#
# `rm -rf` first, and the file check after, are both about a partial bundle
# rather than about the exit code. Measured, and unlike `make smoke`/`make gut`:
# a failed web export really does exit 1 — deleting web_nothreads_release.zip
# gave "Could not open template for export" and status 1, twice, piped and
# direct. But that same failed run had *already written index.pck* before it
# noticed, so the previous export's index.html/.js/.wasm were left sitting
# beside a pack from a different build. Exporting into a directory that is
# emptied first makes "what is in build/web/" mean one export and no other, and
# the check then says that export was complete. index.pck is in the list on its
# own account: a bundle whose pack is missing still has a perfectly good
# index.html that boots to a blank canvas.
# Split from the export for the reason `build` is — see the note there.
build-web: check export-web

export-web: import stamp sdk
	@rm -rf $(WEB_DIR)
	@mkdir -p $(WEB_DIR)
	$(GODOT) --headless --path . --export-release "$(WEB_PRESET)" $(abspath $(WEB_TARGET))
	@for f in index.html index.js index.wasm index.pck; do \
	  [ -s "$(WEB_DIR)/$$f" ] || { echo "Web export FAILED — $(WEB_DIR)/$$f is missing or empty."; exit 1; }; \
	done
	@echo ">> $(WEB_DIR)/ ($$(du -sh $(WEB_DIR) | cut -f1))"
	@ls -1sh $(WEB_DIR)

# ---- interactive -----------------------------------------------------------

run: import
	$(GODOT) --path .

editor: import
	$(GODOT) --editor --path .

# ---- housekeeping ----------------------------------------------------------

clean:
	rm -rf build build_stamp.json .godot

# Also drops the downloaded toolchains (forces a re-fetch/reinstall next time).
distclean: clean
	rm -rf $(SDK) $(LINT_VENV) $(GUT)
