#!/usr/bin/env bash
# Prove that every first-party script is actually reached by a test.
#
# This is the gate that stands in for the 80% line-coverage floor the rest of
# the house standard uses. GDScript has no coverage instrumentation worth
# gating on — STANDARDS.md "Coverage" records the measurements behind that
# sentence — so rather than publish a number that is easy to game, this checks
# the three structural facts the number would only have been a proxy for:
#
#   R1  every .gd under src/ is named by at least one test — by its own path,
#       by its class_name, or through the .tscn that carries it
#   R2  every .gd under src/core/ has its own tests/unit/test_<name>.gd
#   R3  every .gd under src/core/ extends a Node-free base, so R2 is always
#       possible to satisfy honestly instead of by moving the file
#
# WHAT THIS DOES NOT CHECK, SAID PLAINLY
# --------------------------------------
# Whether the tests are any *good*. A test file that asserts nothing would
# satisfy R2 — which is why `make gut` fails the run when GUT reports a risky
# (assert-free) test; the two gates only work as a pair. Beyond that, "is this
# test deep enough" is a review judgement and this script cannot make it.
# Neither can a coverage percentage, which is the whole point.
#
# The hole it leaves open, also said plainly: logic that lives in a scene-tier
# script (src/main/*.gd) only has to be *named* by an integration test, not
# covered by one. Keeping logic out of Node subclasses is a review rule, not a
# mechanical one. See STANDARDS.md.
#
# Usage: scripts/check-test-map.sh [PROJECT_DIR]
set -euo pipefail

DIR="${1:-.}"
cd "$DIR"

# Bases whose instances need no SceneTree, so a unit test can always construct
# one. An ALLOW-list and not a deny-list on purpose: a base nobody listed here
# fails R3, which is the safe direction. The fix is either "this is scene-tier
# and doesn't belong in src/core/" or "add the base here", and both are a
# reviewable commit rather than a silent hole. Deny-listing Node types instead
# would mean every Godot class we forgot to list quietly passed.
NODE_FREE_BASES=(RefCounted Resource Object)

fail=0
issues=()
bad() {
  issues+=("$*")
  fail=1
}

mapfile -t sources < <(find src -name '*.gd' 2>/dev/null | sort)
if [ ${#sources[@]} -eq 0 ]; then
  echo "!! no scripts found under src/ — run this from the project root" >&2
  exit 1
fi

# A test tree that doesn't exist would make every check below vacuously pass,
# which is the same "it ran nothing, so nothing failed" trap `make gut` guards
# against. Fail loudly instead.
if [ -z "$(find tests -name 'test_*.gd' 2>/dev/null | head -1)" ]; then
  echo "!! no tests/**/test_*.gd found — a source tree with no tests is not a pass" >&2
  exit 1
fi

# grep -F: paths and class names are literals, and `res://` is full of
# characters a regex would read as syntax.
named_in() { # needle dir
  grep -qrF --include='*.gd' -e "$1" "$2"
}

# The .tscn files that carry a given script, by resource path or by UID —
# Godot writes either form into a scene depending on when it was saved, so
# checking one and not the other would pass or fail by accident.
scenes_carrying() { # script_path
  local uid=""
  if [ -f "$1.uid" ]; then
    uid="$(cat "$1.uid")"
  fi
  while IFS= read -r scene; do
    if grep -qF -- "res://$1" "$scene" || { [ -n "$uid" ] && grep -qF -- "$uid" "$scene"; }; then
      echo "$scene"
    fi
  done < <(find src -name '*.tscn' 2>/dev/null | sort)
}

for src in "${sources[@]}"; do
  name="$(basename "$src" .gd)"
  # First line only: a `class_name`/`extends` further down is inside an inner
  # class and says nothing about the file's own base.
  class="$(sed -n 's/^class_name \([A-Za-z0-9_]*\).*/\1/p' "$src" | head -1)"
  base="$(sed -n 's/^extends \([A-Za-z0-9_]*\).*/\1/p' "$src" | head -1)"
  printf '  %s ... ' "$src"

  # ---- R1: something under tests/ names this script --------------------------
  via=""
  if named_in "res://$src" tests; then
    via="path"
  elif [ -n "$class" ] && named_in "$class" tests; then
    via="class_name $class"
  else
    while IFS= read -r scene; do
      [ -n "$scene" ] || continue
      if named_in "res://$scene" tests; then
        via="scene $scene"
        break
      fi
    done < <(scenes_carrying "$src")
  fi

  # ---- R2/R3: src/core/ is the logic tier and has no excuses -----------------
  unit_test="tests/unit/test_$name.gd"
  if [[ "$src" == src/core/* ]]; then
    if [ -f "$unit_test" ]; then
      [ -n "$via" ] || via="unit test"
    else
      bad "$src has no $unit_test (R2)"
    fi
    # An `extends`-less script is implicitly RefCounted, which is Node-free.
    # Spelled out with `if` rather than `[ … ] && flag=1`: under `set -e` a
    # bare AND-list whose test fails is a footgun waiting for whoever edits
    # this next, even though bash happens to let this one through.
    node_free=0
    if [ -z "$base" ]; then
      node_free=1
    fi
    for allowed in "${NODE_FREE_BASES[@]}"; do
      if [ "$base" = "$allowed" ]; then
        node_free=1
      fi
    done
    if [ "$node_free" -ne 1 ]; then
      bad "$src extends $base; src/core/ is the Node-free tier (R3): ${NODE_FREE_BASES[*]}"
    fi
  fi

  if [ -n "$via" ]; then
    echo "tested (via $via)"
  else
    echo "UNTESTED"
    bad "$src is not named by any test (R1) — add one under tests/"
  fi
done

if [ $fail -ne 0 ]; then
  echo >&2
  for issue in "${issues[@]}"; do
    echo "  !! $issue" >&2
  done
  echo "Test map check failed — see STANDARDS.md \"Coverage\" for R1/R2/R3." >&2
  exit 1
fi
echo "Every src/ script is reached by a test."
