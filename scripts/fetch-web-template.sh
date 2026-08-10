#!/usr/bin/env bash
# Put the project's own web export template where the Web preset points.
#
# export_presets.cfg sets `custom_template/release` to
# res://.godot-sdk/web_nothreads_release.zip, and this is what makes that file
# exist. Godot does not fall back if it is missing — the export stops with
# "Custom release template not found", which is the behaviour this arrangement
# wants and the reason the preset names a path rather than the engine picking a
# template up by version.
#
# TWO WAYS TO GET ONE, and the difference between them is who paid for the
# compile, not what comes out:
#
#   published  — a release asset of this repository, fetched and checked
#                against WEB_TEMPLATE_SHA256 below. Same treatment as the
#                editor in scripts/fetch-godot.sh, for the same reason: a 40 MB
#                binary does not belong in git, and a binary nobody verified
#                does not belong in a build.
#   from source — scripts/build-web-template.sh, ~50-70 minutes on four cores.
#
# The pins start empty and the source path is what runs, so a fresh clone
# builds the thing it is about to ship rather than trusting an artifact that
# does not exist yet. .github/workflows/web-template.yml is the button that
# publishes one: it runs the same script this does, uploads the result, and
# prints the two lines to paste in below. After that every machine downloads.
#
# WHAT IS NOT A PATH HERE: falling back to the stock template. Both routes end
# at a template built from web/build_profile.json, and if neither can, this
# exits non-zero. A silent downgrade to stock would be a bundle 3 MB heavier
# than the budget in ci-godot.yml expects, discovered by that budget, in a job
# whose error would point at the art.
#
# Usage:
#   scripts/fetch-web-template.sh [DEST]
#   scripts/fetch-web-template.sh --print-id   # the build id, without building
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Set these together, from the workflow's summary, once a template is published.
# The tag is this repository's own release; the file inside it is always
# web_nothreads_release.zip.
WEB_TEMPLATE_RELEASE=""
WEB_TEMPLATE_SHA256=""

REPO_SLUG="clarkbar-sys/done-rite-detailing"
TEMPLATE_NAME="web_nothreads_release.zip"
DEST="${1:-$REPO_ROOT/.godot-sdk/$TEMPLATE_NAME}"

# The build id is what makes a stale template impossible to keep using.
#
# It is the hash of the two files that decide what the template contains — the
# profile and the script that applies it. `make export-web` is happy to reuse
# whatever zip is already on disk, and without this a developer who edits
# web/build_profile.json and re-exports gets the previous engine with no
# indication at all: same filename, same size to the eye, different contents.
# The id is written beside the template and compared on every run.
build_id() {
  sha256sum "$REPO_ROOT/web/build_profile.json" "$REPO_ROOT/scripts/build-web-template.sh" \
    "$REPO_ROOT/scripts/fetch-godot.sh" | sha256sum | cut -d' ' -f1
}

if [ "${1:-}" = "--print-id" ]; then
  build_id
  exit 0
fi

want="$(build_id)"
if [ -f "$DEST" ] && [ "$(cat "$DEST.build-id" 2>/dev/null)" = "$want" ]; then
  echo ">> Web template up to date at $DEST" >&2
  exit 0
fi

rm -f "$DEST" "$DEST.build-id"
mkdir -p "$(dirname "$DEST")"

if [ -n "$WEB_TEMPLATE_RELEASE" ] && [ -n "$WEB_TEMPLATE_SHA256" ]; then
  url="https://github.com/$REPO_SLUG/releases/download/$WEB_TEMPLATE_RELEASE/$TEMPLATE_NAME"
  echo ">> Downloading $TEMPLATE_NAME from $WEB_TEMPLATE_RELEASE" >&2
  curl -fsSL -o "$DEST" "$url"
  echo ">> Verifying sha256" >&2
  echo "$WEB_TEMPLATE_SHA256  $DEST" | sha256sum -c - >&2
else
  echo ">> No published template pinned — building one from source." >&2
  echo "   This takes ~50-70 minutes the first time; see the header of" >&2
  echo "   scripts/build-web-template.sh for what it does and why." >&2
  bash "$REPO_ROOT/scripts/build-web-template.sh" "$DEST"
fi

echo "$want" > "$DEST.build-id"
echo ">> Web template ready at $DEST" >&2
echo "   sha256 $(sha256sum "$DEST" | cut -d' ' -f1)" >&2
