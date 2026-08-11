#!/usr/bin/env bash
# Record the tutorial takes to disk with Godot's Movie Maker mode.
#
# One Godot run per take, each one filming `--take=<name>` (src/core/
# tutorial_take.gd, the demo routine #221 added) into `build/footage/<take>/`
# as a lossless PNG frame sequence plus the run's WAV. `make footage` is the
# door; this is what it runs, and it takes take names for a partial re-record:
#
#   scripts/capture-footage.sh            # the whole catalogue
#   scripts/capture-footage.sh sponge     # just the sponge clip
#
# The Makefile's `footage` recipe carries the measured reasoning for the flags
# below — why xvfb, why the Compatibility renderer, why PNG rather than the
# MJPEG AVI Movie Maker will also write, and what the audio is worth. What is
# here is the mechanics.
#
# Nothing in this file is on `make test`'s path and nothing here gates a PR: a
# full catalogue is ~30 minutes of software rasterizing and ~2 GB of frames.
#
# Env: GODOT (default .godot-sdk/bin/godot), FOOTAGE_DIR (default
# build/footage), FPS (default 60 — Movie Maker's own default, see the
# Makefile).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

GODOT="${GODOT:-$ROOT_DIR/.godot-sdk/bin/godot}"
OUT_ROOT="${FOOTAGE_DIR:-$ROOT_DIR/build/footage}"
FPS="${FPS:-60}"

[ -x "$GODOT" ] || {
  echo "!! $GODOT not found — run \`make import\` first" >&2
  exit 1
}
command -v xvfb-run >/dev/null || {
  echo "!! xvfb-run not found. Movie Maker cannot run under --headless (it" >&2
  echo "   segfaults in the dummy renderer — see the Makefile), so recording" >&2
  echo "   on a machine with no display needs a virtual one:" >&2
  echo "     sudo apt-get install -y xvfb" >&2
  exit 1
}

# The window size and the catalogue both come from the game rather than from a
# copy kept here — see scripts/shot-list.gd for why. Everything after this
# block is driven by what it printed, and it is read with awk rather than a
# grep pattern because the fields are tab-separated and the engine's own boot
# banner shares the stream.
SHOT_LIST="$("$GODOT" --headless --path "$ROOT_DIR" --script res://scripts/shot-list.gd)"

read -r FRAME_W FRAME_H < <(awk -F'\t' '$1 == "frame" { print $2, $3 }' <<<"$SHOT_LIST") || {
  echo "!! scripts/shot-list.gd printed no frame size — is the project imported?" >&2
  exit 1
}

declare -A TAKE_MS=()
CATALOGUE=()
while IFS=$'\t' read -r take_id take_ms; do
  CATALOGUE+=("$take_id")
  TAKE_MS["$take_id"]="$take_ms"
done < <(awk -F'\t' '$1 == "take" { print $2 "\t" $3 }' <<<"$SHOT_LIST")

[ ${#CATALOGUE[@]} -gt 0 ] || {
  echo "!! scripts/shot-list.gd named no takes — nothing to record" >&2
  exit 1
}

# A name nobody has filmed is refused here rather than by the game. src/main/
# main.gd does complain and exit 1 on one, but only after a window has opened
# and Movie Maker has started writing, which leaves a directory of two frames
# behind to explain.
WANTED=("$@")
if [ ${#WANTED[@]} -eq 0 ]; then
  WANTED=("${CATALOGUE[@]}")
else
  for take_id in "${WANTED[@]}"; do
    [ -n "${TAKE_MS[$take_id]:-}" ] || {
      echo "!! no tutorial take called '$take_id' — try one of: ${CATALOGUE[*]}" >&2
      exit 1
    }
  done
fi

# THE ONLY LEVER THAT SETS THE RECORDED RESOLUTION, MEASURED THE HARD WAY.
# Movie Maker records at the project's *viewport* size, not at the window's:
# `--resolution 720x1280` really does open a 720x1280 window (verified by
# printing DisplayServer.window_get_size() from a run that had it) and the
# frames still came out 1280x720, which is project.godot's
# display/window/size/viewport_*. TutorialTakeScreen._frame_the_window()'s own
# DisplayServer.window_set_size() call is beaten the same way. What does work is
# res://override.cfg — Godot loads it over project.godot at startup, and with
# the two lines below the header says "recording movie in 720x1280" and the PNGs
# are 720x1280. Verified both ways on the same commit.
#
# It has to live in the project root (Godot reads override.cfg from res://; a
# copy next to the engine binary was ignored, tested), so it is written on the
# way in and removed on the way out — including on Ctrl-C, which is what the
# trap is for. An override.cfg that outlived a run would silently reshape
# `make run` and `make editor` for whoever came next, so an existing one is a
# hard stop rather than something to overwrite: it is either somebody else's
# capture in flight or the wreckage of one that was killed with -9.
OVERRIDE="$ROOT_DIR/override.cfg"
[ ! -e "$OVERRIDE" ] || {
  echo "!! $OVERRIDE already exists — another capture may be running." >&2
  echo "   Delete it if it is left over from an interrupted one." >&2
  exit 1
}
trap 'rm -f "$OVERRIDE"' EXIT
cat >"$OVERRIDE" <<EOF
[display]

window/size/viewport_width=$FRAME_W
window/size/viewport_height=$FRAME_H
EOF

# What the assembly stage in #224 lines the narration up against, in the shape
# scripts/narrate.sh already writes its own timings in. Rows for takes this run
# is not re-recording are carried over rather than dropped, so recording one
# clip on its own does not blank the sheet for the other four.
mkdir -p "$OUT_ROOT"
TIMINGS="$OUT_ROOT/timings.tsv"
declare -A ROWS=()
if [ -f "$TIMINGS" ]; then
  while IFS=$'\t' read -r take_id rest; do
    if [ "$take_id" = "take" ]; then continue; fi
    ROWS["$take_id"]="$rest"
  done <"$TIMINGS"
fi

for take_id in "${WANTED[@]}"; do
  ms="${TAKE_MS[$take_id]}"
  want=$((ms * FPS / 1000))
  dir="$OUT_ROOT/$take_id"

  # Emptied and not merged into. A re-record that left the previous run's
  # frames in place would leave a longer clip's tail hanging off the end of a
  # shorter one, and the frame numbering gives no hint that two runs are mixed.
  rm -rf "$dir"
  mkdir -p "$dir"

  echo ">> Filming '$take_id' — ${FRAME_W}x${FRAME_H}, ${want} frames at ${FPS} fps" >&2
  xvfb-run -a -s "-screen 0 ${FRAME_W}x${FRAME_H}x24" \
    "$GODOT" --path "$ROOT_DIR" \
    --rendering-driver opengl3 --rendering-method gl_compatibility \
    --disable-vsync \
    --fixed-fps "$FPS" --write-movie "$dir/frame.png" \
    -- "--take=$take_id" >&2

  # Every check below is on a failure that would otherwise exit 0. The screen
  # quits the process itself when the take runs out (TutorialTakeScreen._cut),
  # so "the clip is the right length" is the only evidence that the take
  # actually played rather than that the engine happened to stop.
  frames=$(find "$dir" -maxdepth 1 -name 'frame*.png' | wc -l)
  [ "$frames" -ge "$want" ] || {
    echo "!! '$take_id' stopped early: $frames frames, expected at least $want." >&2
    exit 1
  }
  # The take clock starts when the mud lands, a frame or two into the run, and
  # Movie Maker has been recording since frame zero — so a few frames of slack
  # at the head is right and a whole second of it is not.
  [ "$frames" -le $((want + FPS)) ] || {
    echo "!! '$take_id' ran long: $frames frames, expected about $want." >&2
    exit 1
  }
  [ -s "$dir/frame.wav" ] || {
    echo "!! '$take_id' wrote no audio track ($dir/frame.wav)." >&2
    exit 1
  }

  # The resolution gate, and it is why the override.cfg block above has the
  # note it has: a capture that quietly reverts to the project's 1280x720 is a
  # landscape clip of a shot TutorialFraming composed for a phone, and it looks
  # like footage right up until somebody plays it.
  read -r got_w got_h < <(python3 - "$dir/frame00000000.png" <<'PY'
import struct
import sys

with open(sys.argv[1], "rb") as png:
    header = png.read(24)
print(*struct.unpack(">II", header[16:24]))
PY
  )
  [ "$got_w" = "$FRAME_W" ] && [ "$got_h" = "$FRAME_H" ] || {
    echo "!! '$take_id' recorded at ${got_w}x${got_h}, wanted ${FRAME_W}x${FRAME_H}." >&2
    exit 1
  }

  ROWS["$take_id"]="$(printf '%d\t%d.%03d\t%d\t%d' \
    "$frames" $((ms / 1000)) $((ms % 1000)) "$FRAME_W" "$FRAME_H")"
  echo ">> $dir — $frames frames + frame.wav ($(du -sh "$dir" | cut -f1))" >&2
done

{
  printf 'take\tframes\tseconds\twidth\theight\n'
  for take_id in "${CATALOGUE[@]}"; do
    [ -n "${ROWS[$take_id]:-}" ] || continue
    printf '%s\t%s\n' "$take_id" "${ROWS[$take_id]}"
  done
} >"$TIMINGS"

echo ">> Recorded ${#WANTED[@]} take(s) into $OUT_ROOT" >&2
cat "$TIMINGS" >&2
