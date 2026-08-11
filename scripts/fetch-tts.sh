#!/usr/bin/env bash
# Fetch the pinned Piper TTS engine and voice model into a local dir.
#
# Same philosophy as scripts/fetch-godot.sh and scripts/fetch-gut.sh: Piper is
# deliberately NOT vendored — it's a ~26 MB binary release plus a ~63 MB voice
# model, downloaded on demand and verified against the sha256 pins below, so
# scripts/narrate.sh (and CI, if it ever runs the narration pipeline) produce
# byte-identical audio from byte-identical inputs. This file is the single
# source of truth for "which Piper, which voice".
#
#   Piper 2023.11.14-2 — https://github.com/rhasspy/piper
#   License: MIT
#
#   Voice: en_US-lessac-medium — https://huggingface.co/rhasspy/piper-voices
#   License: public domain (LibriTTS-derived "lessac" recordings; see the
#   voice's MODEL_CARD once fetched)
#
# WHY THIS VOICE
# ---------------
# en_US-lessac-medium is one of the most widely used and best-reviewed en_US
# voices Piper ships: a single, clear speaker, "medium" quality (22 kHz — the
# resolution Piper's own docs recommend as the quality/size sweet spot; "low"
# is noticeably robotic, "high" roughly doubles the model for a difference
# that doesn't matter over a phone speaker or a YouTube compressor), and the
# voice several Piper example projects default to. No cloud call, no API key,
# no per-render bill or nondeterminism — it runs the same on a laptop and on a
# CI runner, which is the whole point of picking Piper over a hosted TTS.
#
# WHY A PINNED COMMIT, NOT "resolve/main"
# ----------------------------------------
# Hugging Face repos are git repos: "resolve/main" always serves whatever is
# on the branch tip *today*, which is exactly the moving target
# fetch-gut.sh's long comment warns about for GitHub's tarballs. Pinning
# VOICE_COMMIT to the commit "main" pointed at when this pin was made turns
# the URL into an immutable ref — the same bytes forever — and the sha256
# check below is the belt to that braces.
set -euo pipefail

PIPER_VERSION="2023.11.14-2"
PIPER_SHA256="a50cb45f355b7af1f6d758c1b360717877ba0a398cc8cbe6d2a7a3a26e225992"

VOICE_NAME="en_US-lessac-medium"
VOICE_COMMIT="ea046e8458f6acd997706d6e6066a022b42f6fb1"
VOICE_ONNX_SHA256="5efe09e69902187827af646e1a6e9d269dee769f9877d17b16b1b46eeaaf019f"
VOICE_CONFIG_SHA256="efe19c417bed055f2d69908248c6ba650fa135bc868b0e6abb3da181dab690a0"

PIPER_URL="https://github.com/rhasspy/piper/releases/download/$PIPER_VERSION/piper_linux_x86_64.tar.gz"
VOICE_BASE_URL="https://huggingface.co/rhasspy/piper-voices/resolve/$VOICE_COMMIT/en/en_US/lessac/medium"

# --update: report the newest upstream Piper release and the current voice
# commit + hashes, so the pins above can be bumped. Uses git tags rather than
# the GitHub API (no token needed), same as fetch-godot.sh / fetch-gut.sh.
if [ "${1:-}" = "--update" ]; then
  latest="$(git ls-remote --tags --refs https://github.com/rhasspy/piper |
    sed -n 's#.*refs/tags/\([0-9][0-9.]*-[0-9]*\)$#\1#p' | sort -V | tail -1)"
  [ -n "$latest" ] || { echo "!! could not determine the latest Piper tag" >&2; exit 1; }
  voice_commit="$(git ls-remote https://huggingface.co/rhasspy/piper-voices HEAD |
    cut -f1)"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  echo ">> Latest upstream Piper: $latest (pinned: $PIPER_VERSION)" >&2
  echo ">> Downloading piper_linux_x86_64.tar.gz" >&2
  curl -fsSL -o "$tmp/piper.tar.gz" \
    "https://github.com/rhasspy/piper/releases/download/$latest/piper_linux_x86_64.tar.gz"
  echo "   piper_linux_x86_64.tar.gz: $(sha256sum "$tmp/piper.tar.gz" | cut -d' ' -f1)" >&2
  echo ">> Latest piper-voices commit: $voice_commit (pinned: $VOICE_COMMIT)" >&2
  for f in "$VOICE_NAME.onnx" "$VOICE_NAME.onnx.json"; do
    echo ">> Downloading $f" >&2
    curl -fsSL -o "$tmp/$f" \
      "https://huggingface.co/rhasspy/piper-voices/resolve/$voice_commit/en/en_US/lessac/medium/$f"
    echo "   $f: $(sha256sum "$tmp/$f" | cut -d' ' -f1)" >&2
  done
  cat >&2 <<EOF

If these differ from the pins in this script, update PIPER_VERSION,
PIPER_SHA256, VOICE_COMMIT, VOICE_ONNX_SHA256 and VOICE_CONFIG_SHA256 (and
the version comments at the top), then commit. Re-run scripts/narrate.sh
before pushing — a voice bump changes every WAV's bytes and duration.
EOF
  exit 0
fi

DEST="${1:-.piper}"
BIN="$DEST/piper/piper"
VOICE_DIR="$DEST/voices"
VOICE_ONNX="$VOICE_DIR/$VOICE_NAME.onnx"
VOICE_CONFIG="$VOICE_DIR/$VOICE_NAME.onnx.json"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fetch_verify() { # url sha256 dest
  echo ">> Downloading $(basename "$1")" >&2
  curl -fsSL -o "$3" "$1"
  echo ">> Verifying sha256 of $(basename "$1")" >&2
  echo "$2  $3" | sha256sum -c - >&2
}

# Idempotent, so `make narration` can depend on this without re-downloading
# ~90 MB every run — same shape as fetch-godot.sh's editor/template checks.
if [ ! -x "$BIN" ]; then
  mkdir -p "$DEST"
  archive="$tmp/piper_linux_x86_64.tar.gz"
  fetch_verify "$PIPER_URL" "$PIPER_SHA256" "$archive"
  # The archive's one top-level entry is piper/ — binary, its .so's (RUNPATH
  # $ORIGIN, so they must stay siblings of the binary) and its bundled
  # espeak-ng-data phoneme tables. Extracted whole, not cherry-picked.
  tar -xzf "$archive" -C "$tmp"
  rm -rf "$DEST/piper"
  mv "$tmp/piper" "$DEST/piper"
  echo ">> Piper $PIPER_VERSION ready at $BIN" >&2
fi

if [ ! -f "$VOICE_ONNX" ] || [ ! -f "$VOICE_CONFIG" ]; then
  mkdir -p "$VOICE_DIR"
  fetch_verify "$VOICE_BASE_URL/$VOICE_NAME.onnx" "$VOICE_ONNX_SHA256" "$tmp/$VOICE_NAME.onnx"
  fetch_verify "$VOICE_BASE_URL/$VOICE_NAME.onnx.json" "$VOICE_CONFIG_SHA256" \
    "$tmp/$VOICE_NAME.onnx.json"
  mv "$tmp/$VOICE_NAME.onnx" "$VOICE_ONNX"
  mv "$tmp/$VOICE_NAME.onnx.json" "$VOICE_CONFIG"
  echo ">> Voice $VOICE_NAME ready at $VOICE_ONNX" >&2
fi
