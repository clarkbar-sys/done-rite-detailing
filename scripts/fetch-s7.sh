#!/usr/bin/env bash
# Fetch the pinned s7 Scheme source from CCRMA into a build directory.
#
# s7 is deliberately NOT vendored in this repo — it's downloaded at build time
# and verified against the sha256 below. Upstream ships a single *rolling*
# tarball (no versioned releases), so this pin is the single source of truth for
# which snapshot everything (Makefile, Dockerfile, CI, release) builds.
#
#   s7 11.9 (13-Jul-2026) — https://ccrma.stanford.edu/software/snd/snd/s7.html
#   License: 0BSD
#
# Usage:
#   scripts/fetch-s7.sh [DEST]     # populate DEST (default: .s7) with s7 sources
#   scripts/fetch-s7.sh --update   # re-download and print the current sha256 + version
set -euo pipefail

S7_URL="https://ccrma.stanford.edu/software/s7/s7.tar.gz"
S7_SHA256="a77fd58e8386e8e1f283d06b812669da2fe8f7c90cfd4e81f986635330db0ee7"

# Files we build with: the interpreter (s7.c/s7.h) plus the support scripts the
# deluxe interactive REPL loads. mus-config.h is a required empty stub s7.c
# #includes.
FILES=(s7.c s7.h cload.scm libc.scm repl.scm)

download() { echo ">> Downloading $S7_URL" >&2; curl -fsSL -o "$1" "$S7_URL"; }

# --update: report the current upstream sha256/version so the pin can be bumped.
if [ "${1:-}" = "--update" ]; then
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  download "$tmp/s7.tar.gz"
  sha="$(sha256sum "$tmp/s7.tar.gz" | cut -d' ' -f1)"
  tar -xzf "$tmp/s7.tar.gz" -C "$tmp"
  ver="$(grep -m1 -E '#define S7_VERSION' "$tmp/s7/s7.h" | sed -E 's/.*"([^"]+)".*/\1/')"
  date="$(grep -m1 -E '#define S7_DATE'    "$tmp/s7/s7.h" | sed -E 's/.*"([^"]+)".*/\1/')"
  cat >&2 <<EOF

>> Current upstream s7: ${ver:-?} (${date:-?})
   sha256: ${sha}

If this differs from S7_SHA256 in this script, update the pin (and the version
comment above), then commit.
EOF
  exit 0
fi

DEST="${1:-.s7}"
mkdir -p "$DEST"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

download "$tmp/s7.tar.gz"
echo ">> Verifying sha256" >&2
echo "$S7_SHA256  $tmp/s7.tar.gz" | sha256sum -c - >&2

tar -xzf "$tmp/s7.tar.gz" -C "$tmp"
for f in "${FILES[@]}"; do cp "$tmp/s7/$f" "$DEST/$f"; done
: > "$DEST/mus-config.h"   # s7.c #includes this; upstream expects an empty stub
echo ">> s7 source ready in $DEST" >&2
