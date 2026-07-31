#!/usr/bin/env bash
# Write res://build_stamp.json so an exported binary can say which commit it is.
#
# Run immediately before `--export-release`; the file is picked up by the
# BuildInfo autoload (src/core/build_info.gd) and packed into the game. It is
# git-ignored: local/editor runs have no stamp and report the commit as "local".
#
# Usage: scripts/stamp-build.sh [PROJECT_DIR]
set -euo pipefail

DIR="${1:-.}"
OUT="$DIR/build_stamp.json"

# In CI, GITHUB_SHA is authoritative — a PR build checks out a synthetic merge
# commit, so `git rev-parse HEAD` there names something that exists nowhere else.
commit="${GITHUB_SHA:-$(git -C "$DIR" rev-parse HEAD 2>/dev/null || echo unknown)}"
built_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

cat > "$OUT" <<EOF
{
  "commit": "${commit:0:7}",
  "built_at": "$built_at"
}
EOF

echo ">> Stamped $OUT (${commit:0:7} @ $built_at)" >&2
