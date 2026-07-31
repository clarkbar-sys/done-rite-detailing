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

# What was actually checked out is the honest answer, so `git rev-parse HEAD`
# leads. GITHUB_SHA is only a last resort — it is NOT interchangeable:
#   - on `pull_request` it is the synthetic refs/pull/N/merge commit, which is
#     not the branch head a reviewer is looking at
#   - in release.yml we check out `ref: <tag>`, so GITHUB_SHA is whatever push
#     to main triggered the run, not the commit being released
# BUILD_COMMIT overrides both, which is how CI stamps a PR with its head sha.
commit="${BUILD_COMMIT:-$(git -C "$DIR" rev-parse HEAD 2>/dev/null || echo "${GITHUB_SHA:-unknown}")}"
built_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

cat > "$OUT" <<EOF
{
  "commit": "${commit:0:7}",
  "built_at": "$built_at"
}
EOF

echo ">> Stamped $OUT (${commit:0:7} @ $built_at)" >&2
