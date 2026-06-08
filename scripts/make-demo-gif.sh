#!/bin/bash
# Convert a screen recording into an optimized GIF for the README.
#
#   ./scripts/make-demo-gif.sh <recording.mov> [output.gif]
#
# Defaults: writes assets/demo.gif, scaled to 760px wide at 15 fps (matches the
# <img> the README expects). Tune with env vars:
#   WIDTH=760 FPS=15 TRIM_START=0 TRIM_DUR= ./scripts/make-demo-gif.sh clip.mov
#   TRIM_START=2.5 TRIM_DUR=12   → start 2.5s in, keep 12s (trims dead air).
#
# Uses ffmpeg's two-pass palette method (best quality/size, no extra deps).
set -euo pipefail
cd "$(dirname "$0")/.."                 # repo root

IN="${1:-}"
OUT="${2:-assets/demo.gif}"
[ -n "$IN" ] || { echo "usage: $0 <recording.mov> [output.gif]" >&2; exit 1; }
[ -f "$IN" ] || { echo "✗ input not found: $IN" >&2; exit 1; }

WIDTH="${WIDTH:-760}"
FPS="${FPS:-15}"
TRIM_START="${TRIM_START:-0}"
TRIM_DUR="${TRIM_DUR:-}"

# Optional trim flags (apply to BOTH passes so palette matches the output).
TRIM=(-ss "$TRIM_START")
[ -n "$TRIM_DUR" ] && TRIM+=(-t "$TRIM_DUR")

PALETTE="$(mktemp -t kright-palette).png"
FILTERS="fps=$FPS,scale=$WIDTH:-1:flags=lanczos"

echo "▸ Pass 1/2: building color palette…"
ffmpeg -y "${TRIM[@]}" -i "$IN" -vf "$FILTERS,palettegen=stats_mode=diff" "$PALETTE" >/dev/null 2>&1

echo "▸ Pass 2/2: encoding GIF (${WIDTH}px @ ${FPS}fps)…"
mkdir -p "$(dirname "$OUT")"
ffmpeg -y "${TRIM[@]}" -i "$IN" -i "$PALETTE" \
  -lavfi "$FILTERS[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle" \
  "$OUT" >/dev/null 2>&1
rm -f "$PALETTE"

SIZE_BYTES=$(stat -f%z "$OUT")
SIZE_H=$(echo "scale=1; $SIZE_BYTES/1048576" | bc)
echo "✓ Wrote $OUT  (${SIZE_H} MB)"
if [ "$SIZE_BYTES" -gt 5242880 ]; then
  echo "⚠ Over 5 MB. Trim it (TRIM_DUR=…), or drop quality: FPS=12 WIDTH=640 $0 \"$IN\""
fi
echo "  Preview:  open \"$OUT\""
echo "  Then uncomment the demo <img> line in README.md."
