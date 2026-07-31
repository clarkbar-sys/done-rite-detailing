#!/usr/bin/env bash
# Fetch the pinned Godot editor (and export templates) into a local SDK dir.
#
# Godot is deliberately NOT vendored — it's downloaded on demand and verified
# against the sha256 pins below, so the Makefile, CI and the release workflow all
# build with the byte-identical toolchain. This file is the single source of
# truth for "which Godot".
#
#   Godot 4.7.1-stable — https://godotengine.org
#   License: MIT
#
# Everything lands under DEST (default: .godot-sdk), including the export
# templates: the Makefile points XDG_DATA_HOME at DEST/data so Godot looks for
# templates there instead of the developer's real ~/.local/share.
#
# Usage:
#   scripts/fetch-godot.sh [DEST]          # editor + export templates
#   scripts/fetch-godot.sh --editor-only   # editor only (enough to type-check)
#   scripts/fetch-godot.sh --update        # print the latest upstream version + sha256s
set -euo pipefail

GODOT_VERSION="4.7.1-stable"
GODOT_SHA256="c7ff14fd28472c8d4f193043de30278dcf7e5241a1dcf7566b02e27addaa33ba"
TEMPLATES_SHA256="86409db6200b6f8fd3230989c2d2002851f3dd18acf11d7bdbafddf5a0dd0f72"

# Upstream ships every platform's templates in one ~1.2 GB archive. We keep only
# the ones our export presets actually use, which is what makes the SDK small
# enough to cache in CI. Adding a preset (web, windows, macos) means adding its
# template files here — otherwise the export fails with "template not found".
KEEP_TEMPLATES=(version.txt linux_release.x86_64 linux_debug.x86_64)

base_url() { echo "https://github.com/godotengine/godot/releases/download/$1"; }
editor_zip() { echo "Godot_v$1_linux.x86_64.zip"; }
templates_tpz() { echo "Godot_v$1_export_templates.tpz"; }

# --update: report the newest upstream stable release and its checksums so the
# pins above can be bumped. Uses git tags rather than the API (no token needed).
if [ "${1:-}" = "--update" ]; then
  latest="$(git ls-remote --tags --refs https://github.com/godotengine/godot \
    | sed -n 's#.*refs/tags/\([0-9][0-9.]*-stable\)$#\1#p' | sort -V | tail -1)"
  [ -n "$latest" ] || { echo "!! could not determine the latest Godot tag" >&2; exit 1; }
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  echo ">> Latest upstream Godot: $latest (pinned: $GODOT_VERSION)" >&2
  for f in "$(editor_zip "$latest")" "$(templates_tpz "$latest")"; do
    echo ">> Downloading $f" >&2
    curl -fsSL -o "$tmp/$f" "$(base_url "$latest")/$f"
    echo "   $f: $(sha256sum "$tmp/$f" | cut -d' ' -f1)" >&2
  done
  cat >&2 <<EOF

If this differs from the pins in this script, update GODOT_VERSION,
GODOT_SHA256 and TEMPLATES_SHA256 (and the version comment at the top),
then commit. Re-run \`make check build\` before pushing: a Godot bump can
change GDScript warnings and the export layout.
EOF
  exit 0
fi

EDITOR_ONLY=false
if [ "${1:-}" = "--editor-only" ]; then EDITOR_ONLY=true; shift; fi

DEST="${1:-.godot-sdk}"
BIN="$DEST/bin/godot"
TEMPLATE_DIR="$DEST/data/godot/export_templates/${GODOT_VERSION/-/.}"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

fetch_verify() { # url sha256 dest
  echo ">> Downloading $(basename "$1")" >&2
  curl -fsSL -o "$3" "$1"
  echo ">> Verifying sha256 of $(basename "$1")" >&2
  echo "$2  $3" | sha256sum -c - >&2
}

# Both steps are idempotent: an already-populated SDK is left alone, so `make`
# can depend on them without re-downloading ~1.2 GB every build.
if [ ! -x "$BIN" ]; then
  mkdir -p "$DEST/bin"
  zip="$tmp/$(editor_zip "$GODOT_VERSION")"
  fetch_verify "$(base_url "$GODOT_VERSION")/$(editor_zip "$GODOT_VERSION")" "$GODOT_SHA256" "$zip"
  unzip -oq "$zip" -d "$tmp/editor"
  mv "$tmp/editor/Godot_v${GODOT_VERSION}_linux.x86_64" "$BIN"
  chmod +x "$BIN"
  echo ">> Godot $GODOT_VERSION editor ready at $BIN" >&2
fi

if [ "$EDITOR_ONLY" = true ]; then exit 0; fi

if [ ! -f "$TEMPLATE_DIR/version.txt" ]; then
  mkdir -p "$TEMPLATE_DIR"
  tpz="$tmp/$(templates_tpz "$GODOT_VERSION")"
  fetch_verify "$(base_url "$GODOT_VERSION")/$(templates_tpz "$GODOT_VERSION")" \
    "$TEMPLATES_SHA256" "$tpz"
  # The .tpz is a zip whose entries all live under templates/. Extracting only
  # the KEEP_TEMPLATES entries avoids unpacking ~2 GB of platforms we don't ship.
  wanted=()
  for t in "${KEEP_TEMPLATES[@]}"; do wanted+=("templates/$t"); done
  unzip -oq "$tpz" -d "$tmp/tpl" "${wanted[@]}"
  for t in "${KEEP_TEMPLATES[@]}"; do
    [ -f "$tmp/tpl/templates/$t" ] || { echo "!! missing template: $t" >&2; exit 1; }
    mv "$tmp/tpl/templates/$t" "$TEMPLATE_DIR/$t"
  done
  echo ">> Export templates ready in $TEMPLATE_DIR" >&2
fi
