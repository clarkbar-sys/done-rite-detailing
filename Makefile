# Done Rite Detailing — a Godot 4 game.
#
# The Godot editor and export templates are downloaded on demand and pinned by
# sha256 (see scripts/fetch-godot.sh), so `make` here and CI over there run the
# byte-identical toolchain. Nothing is installed system-wide: everything lives
# under .godot-sdk/ and is thrown away by `make distclean`.
#
#   make check     type-check every script (the CI gate)
#   make smoke     boot the game headless and require a clean exit
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

.PHONY: all sdk editor-sdk import check smoke test build stamp run editor clean distclean

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

# ---- develop ---------------------------------------------------------------

# Populate .godot/ (import icon.svg -> .ctex, build the UID cache, register
# global classes). Required once before anything can load the project.
import: $(GODOT)
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

# The one command CI and humans run. Unit tests (GUT) join it next; until then
# it is the type check plus the headless boot.
test: check smoke

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

# Also drops the downloaded toolchain (forces a re-fetch on the next build).
distclean: clean
	rm -rf $(SDK)
