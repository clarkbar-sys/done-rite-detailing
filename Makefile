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
#   make test      check + smoke + gut (what CI runs)
#   make lint      gdformat --check + gdlint every script (a separate CI gate)
#   make format    gdformat every script in place
#   make build     export the Linux release binary -> build/linux/
#   make editor    open the project in the Godot editor

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

.PHONY: all sdk editor-sdk gut-sdk import check smoke gut lint format test build stamp run editor clean distclean

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
import: $(GODOT) $(GUT_PLUGIN)
	$(GODOT) --headless --path . --import

# The quality gate. `--check-only` parses and type-checks a script and exits
# non-zero on any error, and project.godot promotes the typing warnings to
# errors — so untyped or unsafe GDScript fails here instead of at runtime.
check: import
	@mkdir -p $(LOG_DIR); fail=0; \
	for f in $(SOURCES); do \
	  printf '  check %s ... ' "$$f"; \
	  if $(GODOT) --headless --path . --check-only --script "res://$$f" \
	       >/dev/null 2>$(LOG_DIR)/check.log; then \
	    echo ok; \
	  else \
	    echo FAIL; cat $(LOG_DIR)/check.log; fail=1; \
	  fi; \
	done; \
	[ $$fail -eq 0 ] || { echo "Type check failed."; exit 1; }; \
	echo "All scripts type-check."

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
# `-gdisable_colors` so the log greps cleanly and CI's plain-text view is
# readable; without it the ANSI escapes sit between the ^ and the word.
gut: import
	@mkdir -p $(LOG_DIR)
	@$(GODOT) --headless --path . -s res://$(GUT)/gut_cmdln.gd \
	  -gdir=res://tests -ginclude_subdirs -gdisable_colors -gexit \
	  2>&1 | tee $(LOG_DIR)/gut.log
	@if ! grep -qE '^Scripts +[1-9]' $(LOG_DIR)/gut.log; then \
	  echo "GUT collected no test scripts — a suite that runs nothing is not a pass."; \
	  exit 1; \
	fi
	@echo "GUT suites passed."

# The one command CI and humans run before pushing. Deliberately check, smoke
# and gut but not lint: those three are "does the game still work", gated by
# CI's `check` and `test` jobs; lint is "does the style pass", gated by CI's own
# `lint` job. CONTRIBUTING.md already treats "test" and "lint" as separate
# steps, and splitting them here means the slow ones (they need the Godot
# editor) and the fast one (lint needs no download, see below) don't force each
# other to wait. Run `make test lint` to get both locally.
#
# smoke before gut: a project that can't boot at all turns every GUT failure
# into a red herring, so let the coarse gate report first.
test: check smoke gut

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

build: check stamp sdk
	@mkdir -p $(BUILD_DIR)
	$(GODOT) --headless --path . --export-release "$(PRESET)" $(abspath $(TARGET))
	@echo ">> $(TARGET) ($$(du -h $(TARGET) | cut -f1))"

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
