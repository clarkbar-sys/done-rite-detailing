#!/usr/bin/env bash
# Build the project's own web export template — Godot with the modules this
# game never touches compiled out.
#
# WHY THIS EXISTS. The stock `web_nothreads_release` template is a 39.5 MB
# `index.wasm` that GitHub Pages gzips to 10.1 MB, and once the art passes had
# landed that was the majority of what a player downloads. The engine is the
# only thing left to cut, and the only way to cut an engine is to compile it.
# web/build_profile.json is the list of what comes out and why; this file is
# how it gets applied, and scripts/fetch-web-template.sh is how the result
# reaches an export.
#
# WHAT IT IS NOT. It is not `optimize=size`, which is already the web
# platform's default (platform/web/detect.py's get_flags(), with a comment
# about -Os beating -O3 by ~5 MB), and it is not `production=yes`, which is
# what the official templates already are. Both are passed below anyway so the
# invocation states its own configuration instead of inheriting half of it —
# but neither is where the saving comes from. The saving is the profile.
#
# WHICH GODOT. Not a version of its own: GODOT_VERSION is read out of
# scripts/fetch-godot.sh, which that file's header calls "the single source of
# truth for which Godot", and this script refuses to run if it cannot find it.
# A template built from a different engine than the editor that exports with it
# is the one failure this whole arrangement has to make impossible — Godot does
# not check, it just produces a bundle that crashes somewhere unhelpful.
# GODOT_COMMIT below pins the tag to a commit, because a tag can be moved and a
# commit cannot.
#
# Usage:
#   scripts/build-web-template.sh [DEST_ZIP]   # default: the SDK's template dir
#   scripts/build-web-template.sh --print-flags
#
# Cost, stated plainly: a cold build is ~50-70 minutes on four cores and wants
# ~12 GB of disk for the source tree, the emsdk and the objects. CI caches the
# result on this script's hash plus the profile's, so it pays that once per
# change to either; see .github/workflows/ci-godot.yml's `web-template` job.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Emscripten. Pinned for the same reason Godot is, and to the version the
# official 4.7.1 templates report in their own boot line ("Build configuration:
# Emscripten 4.0.20, single-threaded, no GDExtension support") — so the custom
# template differs from stock in the profile and in nothing else.
EMSDK_VERSION="4.0.20"

# The 4.7.1-stable tag's commit. `scripts/fetch-godot.sh --update` prints the
# new version; `git rev-parse <tag>` against godotengine/godot gives this.
GODOT_COMMIT="a13da4feb8d8aefc283c3763d33a2f170a18d541"

PROFILE="$REPO_ROOT/web/build_profile.json"

# `threads=no` + `arch=wasm32` is not a preference, it is the pair that makes
# the output the file the exporter goes looking for. Godot names a web template
# `web[_dlink][_nothreads]_{debug,release}.zip` from the preset's own switches,
# and export_presets.cfg's Web preset sets thread_support=false (the COOP/COEP
# decision — its own comments, and STANDARDS.md "Distribution", have the
# reasoning). Build it threaded and the export would not open it.
SCONS_FLAGS=(
  platform=web
  target=template_release
  production=yes
  threads=no
  arch=wasm32
  optimize=size
  "build_profile=$PROFILE"
)

TEMPLATE_NAME="web_nothreads_release.zip"
BUILT_NAME="godot.web.template_release.wasm32.nothreads.zip"

godot_version() {
  local v
  v="$(sed -n 's/^GODOT_VERSION="\(.*\)"$/\1/p' "$REPO_ROOT/scripts/fetch-godot.sh")"
  [ -n "$v" ] || {
    echo "!! could not read GODOT_VERSION from scripts/fetch-godot.sh" >&2
    exit 1
  }
  echo "$v"
}

if [ "${1:-}" = "--print-flags" ]; then
  echo "godot $(godot_version) ($GODOT_COMMIT), emsdk $EMSDK_VERSION"
  echo "scons ${SCONS_FLAGS[*]}"
  exit 0
fi

GODOT_VERSION="$(godot_version)"
DEST="${1:-$REPO_ROOT/.godot-sdk/data/godot/export_templates/${GODOT_VERSION/-/.}/$TEMPLATE_NAME}"
WORK="${WEB_TEMPLATE_WORK:-$REPO_ROOT/.godot-sdk/template-build}"

command -v scons >/dev/null || {
  echo "!! scons is not on PATH — pip install scons" >&2
  exit 1
}

mkdir -p "$WORK"

# --- the engine source ------------------------------------------------------
#
# Shallow, at the tag, then the commit is checked rather than trusted: a
# lightweight tag is a mutable pointer, and the whole point of pinning is that
# what gets compiled today is what got compiled last time.
if [ ! -d "$WORK/godot/.git" ]; then
  echo ">> Cloning godotengine/godot $GODOT_VERSION" >&2
  git clone --depth 1 --branch "$GODOT_VERSION" \
    https://github.com/godotengine/godot.git "$WORK/godot"
fi
have="$(git -C "$WORK/godot" rev-parse HEAD)"
[ "$have" = "$GODOT_COMMIT" ] || {
  echo "!! godot $GODOT_VERSION is at $have, expected $GODOT_COMMIT" >&2
  echo "   the tag moved, or GODOT_COMMIT in this script is stale" >&2
  exit 1
}

# --- the compiler -----------------------------------------------------------
if [ ! -d "$WORK/emsdk/.git" ]; then
  echo ">> Cloning emsdk" >&2
  git clone --depth 1 https://github.com/emscripten-core/emsdk.git "$WORK/emsdk"
fi
"$WORK/emsdk/emsdk" install "$EMSDK_VERSION" >&2
"$WORK/emsdk/emsdk" activate "$EMSDK_VERSION" >&2
# shellcheck disable=SC1091
source "$WORK/emsdk/emsdk_env.sh" >/dev/null 2>&1
# Not `emcc -v | head -1`: emcc keeps writing after head has taken its line,
# gets SIGPIPE, and under `set -o pipefail` that ends the script with a status
# nobody can trace back to a banner. Captured, then trimmed.
emcc_banner="$(emcc -v 2>&1)"
echo "${emcc_banner%%$'\n'*}" >&2

# --- the build --------------------------------------------------------------
echo ">> scons ${SCONS_FLAGS[*]}" >&2
(cd "$WORK/godot" && scons "${SCONS_FLAGS[@]}" -j"$(nproc)")

built="$WORK/godot/bin/$BUILT_NAME"
[ -f "$built" ] || {
  echo "!! scons finished but $built is not there" >&2
  exit 1
}

# --- what actually got compiled in -----------------------------------------
#
# A profile that turns off too much does not fail here. It links, it zips, it
# exports, and the game runs with a piece missing — which is a thing you find
# in a browser or not at all. The first build of web/build_profile.json did
# exactly that: dropping text_server_adv left NO text server, because
# text_server_fb is disabled by default upstream, and the bundle booted into a
# perfectly rendered 3D bay with every label drawn as nothing.
#
# modules_enabled.gen.h is SCons' own answer to "what is in this binary" — one
# #define per module that survived the profile — so this is the list being read
# back rather than assumed. Named modules only: the point is not to restate the
# profile from the other side, it is to name the handful whose absence is
# invisible until someone looks at a screen.
enabled_header="$WORK/godot/modules/modules_enabled.gen.h"
REQUIRED_MODULES=(
  bcdec        # decodes S3TC/BPTC where the browser exposes neither
  csg          # the entire 3D bay is CSG at runtime
  freetype     # the two faces are TTFs
  gdscript     # the game
  godot_physics_3d  # the 3D server "DEFAULT" resolves to; src/world/ raycasts
  noise        # FastNoiseLite, in src/world/
  svg          # the default theme rasterises its icons through it
  text_server_fb  # off by default upstream; without it, no glyphs anywhere
  webp         # a lossy .ctex is a WebP in a container
)
missing=()
for m in "${REQUIRED_MODULES[@]}"; do
  grep -q "^#define MODULE_${m^^}_ENABLED\$" "$enabled_header" || missing+=("$m")
done
if [ ${#missing[@]} -gt 0 ]; then
  echo "!! the build profile left out modules the game needs: ${missing[*]}" >&2
  echo "   see web/build_profile.json, and $enabled_header for what did survive" >&2
  exit 1
fi
echo ">> modules compiled in: $(grep -c '^#define MODULE_' "$enabled_header")" >&2

mkdir -p "$(dirname "$DEST")"
cp "$built" "$DEST"

# The numbers this exists for, printed where whoever ran it will see them.
# gzip, not raw, and at the default level — the same knob ci-godot.yml's bundle
# budget is measured with, so the two can be compared without a conversion.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
unzip -oq "$DEST" godot.wasm -d "$tmp"
echo ">> $DEST" >&2
echo "   sha256     $(sha256sum "$DEST" | cut -d' ' -f1)" >&2
echo "   godot.wasm $(stat -c%s "$tmp/godot.wasm") B raw, $(gzip -c "$tmp/godot.wasm" | wc -c) B gzip" >&2
