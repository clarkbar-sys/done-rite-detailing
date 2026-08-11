#!/usr/bin/env bash
# Turn video/narration.md into one WAV per take, using the pinned Piper voice.
#
# markdown in, `build/narration/<take>.wav` out — one WAV per `## <take>`
# section, plus a `build/narration/timings.tsv` (per-take duration) for the
# caption/assembly stage in the sibling sub-issue. Same voice, same input,
# same bytes out every time: nothing here is recorded, so rewording a line of
# tutorial copy is a diff and a re-run, not a trip back to a microphone.
#
# Usage:
#   scripts/narrate.sh [NARRATION_MD] [OUT_DIR]
#     NARRATION_MD  default: video/narration.md
#     OUT_DIR       default: build/narration
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

NARRATION_MD="${1:-$ROOT_DIR/video/narration.md}"
OUT_DIR="${2:-$ROOT_DIR/build/narration}"
TTS_DIR="${TTS_DIR:-$ROOT_DIR/.piper}"

[ -f "$NARRATION_MD" ] || { echo "!! $NARRATION_MD not found" >&2; exit 1; }

# Fetches on demand, same as scripts/fetch-godot.sh being a no-op prerequisite
# once .godot-sdk/ is populated — so this script works standalone as well as
# from `make narration`.
scripts/fetch-tts.sh "$TTS_DIR"

PIPER_BIN="$TTS_DIR/piper/piper"
VOICE_ONNX="$TTS_DIR/voices/en_US-lessac-medium.onnx"
VOICE_CONFIG="$TTS_DIR/voices/en_US-lessac-medium.onnx.json"

mkdir -p "$OUT_DIR"

# Parse video/narration.md into one text blob per take: a line matching
# "## <take_name>" opens a section, and every non-blank line up to the next
# "## " heading (or EOF) is that take's script, joined into one paragraph.
# Piper gets the whole paragraph on one stdin write — it splits sentences on
# punctuation and pauses briefly between them (--sentence_silence, its
# default), so a two-sentence take still comes out as a single clean WAV
# instead of something assembled from parts here.
current=""
text=""
takes=()

synth() { # name text
  local name="$1" body="$2"
  local wav="$OUT_DIR/$name.wav"
  echo ">> Synthesizing $name -> $wav" >&2
  printf '%s\n' "$body" |
    "$PIPER_BIN" --model "$VOICE_ONNX" --config "$VOICE_CONFIG" --output_file "$wav" >&2
  takes+=("$name")
}

flush() {
  if [ -n "$current" ]; then
    if [ -n "$text" ]; then
      synth "$current" "$text"
    else
      echo "!! section '$current' has no body text — skipping" >&2
    fi
  fi
}

while IFS= read -r line || [ -n "$line" ]; do
  if [[ "$line" =~ ^##[[:space:]]+([A-Za-z0-9_]+)[[:space:]]*$ ]]; then
    flush
    current="${BASH_REMATCH[1]}"
    text=""
  elif [ -n "$current" ]; then
    trimmed="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [ -z "$trimmed" ] && continue
    if [ -z "$text" ]; then text="$trimmed"; else text="$text $trimmed"; fi
  fi
done <"$NARRATION_MD"
flush

[ ${#takes[@]} -gt 0 ] || {
  echo "!! no '## <take>' sections found in $NARRATION_MD" >&2
  exit 1
}

# Per-take duration for the caption/assembly stage. Plain Python stdlib
# rather than ffprobe: ffprobe isn't part of the fetched toolchain, and every
# WAV Piper writes is PCM, whose duration is just frames/rate — exactly what
# the `wave` module's header reader gives back, no extra dependency to pin.
TIMINGS="$OUT_DIR/timings.tsv"
{
  printf 'take\tduration_seconds\n'
  for name in "${takes[@]}"; do
    dur="$(python3 -c "
import sys, wave
w = wave.open(sys.argv[1])
print(f'{w.getnframes() / w.getframerate():.3f}')
" "$OUT_DIR/$name.wav")"
    printf '%s\t%s\n' "$name" "$dur"
  done
} >"$TIMINGS"

echo ">> Wrote ${#takes[@]} take(s) to $OUT_DIR" >&2
cat "$TIMINGS" >&2
