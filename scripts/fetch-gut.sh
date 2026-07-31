#!/usr/bin/env bash
# Fetch the pinned GUT unit-test addon into addons/gut.
#
# Same philosophy as scripts/fetch-godot.sh: GUT is deliberately NOT vendored.
# It's ~3 MB of third-party GDScript that would otherwise sit in every diff,
# every blame and every clone forever. It's fetched on demand, verified against
# the pins below, and gitignored. This file is the single source of truth for
# "which GUT".
#
#   GUT 9.7.1 — https://github.com/bitwes/Gut
#   License: MIT (see addons/gut/LICENSE.md once fetched)
#
# WHY A GIT CLONE AND A TREE DIGEST, NOT `curl <tarball> | sha256sum`
# ------------------------------------------------------------------
# fetch-godot.sh pins the sha256 of a release asset, which works because Godot
# uploads immutable, byte-stable build artifacts. GUT publishes no such asset:
# its releases only carry GitHub's *auto-generated* source tarball, and those
# are not byte-stable — GitHub regenerates them on demand and has changed the
# gzip settings before, silently changing the sha256 of every archive in every
# repo. Pinning that digest would produce a fetch that starts failing with no
# commit to blame, which is the exact failure mode the pins exist to prevent.
#
# So we pin two things instead, and check both:
#   GUT_COMMIT      the commit the tag pointed at when the pin was made. A tag
#                   is a movable label; the commit is not. Checked first, so a
#                   retagged upstream fails loudly instead of installing
#                   different code under the version we claim.
#   GUT_TREE_SHA256 sha256 over the extracted addons/gut tree — every file's
#                   content *and* path (see tree_digest below). This is the
#                   real content pin: it doesn't care how the bytes arrived, it
#                   only cares that what landed on disk is what was reviewed.
#
# Usage:
#   scripts/fetch-gut.sh [DEST]     # install into DEST (default: addons/gut)
#   scripts/fetch-gut.sh --update   # print the latest upstream tag + its pins
set -euo pipefail

GUT_VERSION="9.7.1"
GUT_COMMIT="aeb5d4f3f7f0a6c9b5e178876d6c99b791fda605"
GUT_TREE_SHA256="d2c73004a788353d6fde06c1be0697fc9e44d21deb39b466304e409deeda943e"

GUT_REPO="https://github.com/bitwes/Gut.git"

# Deterministic digest of a directory tree: every file hashed with its path,
# in a byte-order sort that does not depend on the caller's locale, then the
# whole listing hashed again. Covers added, removed, renamed and edited files.
# -print0/-z/-0 throughout so a filename with a space or newline can't split a
# record and quietly drop a file out of the digest.
tree_digest() { # dir
  (cd "$1" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum |
    sha256sum | cut -d' ' -f1)
}

# Shallow clone of one tag into $1, then assert it really is GUT_COMMIT.
# --depth 1 keeps this at a few MB; we never need GUT's history.
# `advice.detachedHead=false`: cloning a tag always detaches, and the ten-line
# lecture about it in the middle of a `make` run reads like a failure.
clone_tag() { # dest version
  git -c advice.detachedHead=false clone --quiet --depth 1 --branch "v$2" "$GUT_REPO" "$1"
}

# --update: report the newest upstream release and the pins that go with it.
# Uses git tags rather than the API (no token needed), same as fetch-godot.sh.
if [ "${1:-}" = "--update" ]; then
  latest="$(git ls-remote --tags --refs "$GUT_REPO" |
    sed -n 's#.*refs/tags/v\([0-9][0-9.]*\)$#\1#p' | sort -V | tail -1)"
  [ -n "$latest" ] || {
    echo "!! could not determine the latest GUT tag" >&2
    exit 1
  }
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  echo ">> Latest upstream GUT: $latest (pinned: $GUT_VERSION)" >&2
  clone_tag "$tmp/gut" "$latest"
  cat >&2 <<EOF

GUT_VERSION="$latest"
GUT_COMMIT="$(git -C "$tmp/gut" rev-parse HEAD)"
GUT_TREE_SHA256="$(tree_digest "$tmp/gut/addons/gut")"

If these differ from the pins in this script, update all three (and the
version comment at the top), then commit. Re-run \`make test\` before
pushing: a GUT bump can change assert semantics and the CLI's exit codes,
which is exactly what the test job gates on.
EOF
  exit 0
fi

DEST="${1:-addons/gut}"

# Idempotent, so `make` can depend on it without re-cloning every run. Keyed on
# the version in plugin.cfg, so bumping GUT_VERSION forces a reinstall; the
# digest below is re-checked on the fresh copy, not on the cached one.
if [ -f "$DEST/plugin.cfg" ] && grep -q "^version=\"$GUT_VERSION\"" "$DEST/plugin.cfg"; then
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo ">> Cloning GUT v$GUT_VERSION" >&2
clone_tag "$tmp/gut" "$GUT_VERSION"

got_commit="$(git -C "$tmp/gut" rev-parse HEAD)"
if [ "$got_commit" != "$GUT_COMMIT" ]; then
  echo "!! tag v$GUT_VERSION points at $got_commit, expected $GUT_COMMIT" >&2
  echo "!! upstream retagged, or the pin is wrong — do not proceed blind" >&2
  exit 1
fi

echo ">> Verifying sha256 of the addons/gut tree" >&2
got_tree="$(tree_digest "$tmp/gut/addons/gut")"
if [ "$got_tree" != "$GUT_TREE_SHA256" ]; then
  echo "!! addons/gut digest is $got_tree, expected $GUT_TREE_SHA256" >&2
  exit 1
fi

# Install only after both checks pass, and replace wholesale — a half-fetched
# or stale-mixed addons/gut is worse than none, because it fails at test time
# with an error about GUT's internals rather than about the fetch.
rm -rf "$DEST"
mkdir -p "$(dirname "$DEST")"
mv "$tmp/gut/addons/gut" "$DEST"
echo ">> GUT $GUT_VERSION ready at $DEST" >&2
