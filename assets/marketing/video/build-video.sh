#!/usr/bin/env bash
# Compose assets/marketing/video/out/sona-demo.mp4 from the per-slide PNGs.
#
# - 1920x1080, 30 fps
# - per-slide durations from video/captions.json (sum = 95 s)
# - caption strip drawn at the top of each frame
# - 250 ms crossfade between slides
# - soft generated ambient pad (CC0; built with ffmpeg sine + lowpass)
#
# Replace music: drop a track at music/<name>.mp3, set MUSIC=...
# Re-render slides first with `node ../deck/render.mjs`.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
OUT="$HERE/out/sona-demo.mp4"
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT
FONT_REG="/usr/share/fonts/truetype/macos/Inter-Medium.ttf"
FONT_BOLD="/usr/share/fonts/truetype/macos/Inter-Bold.ttf"
[[ -f "$FONT_BOLD" ]] || FONT_BOLD="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
[[ -f "$FONT_REG"  ]] || FONT_REG="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FPS=30
W=1920
H=1080
XFADE=0.8      # crossfade in seconds between slides

# Parse captions.json with python (always available)
mapfile -t LINES < <(python3 - <<'PY'
import json, pathlib
data = json.loads(pathlib.Path("captions.json").read_text())
for s in data["slides"]:
    print(f"{s['png']}\t{s['seconds']}\t{s['caption']}")
PY
)
N=${#LINES[@]}
echo "composing $N slides → $OUT"

# Pre-render each slide as a still-video with caption strip overlaid.
i=0
for line in "${LINES[@]}"; do
  PNG=$(awk -F'\t' '{print $1}' <<<"$line")
  DUR=$(awk -F'\t' '{print $2}' <<<"$line")
  CAP=$(awk -F'\t' '{print $3}' <<<"$line")
  IDX=$(printf "%02d" "$i")
  OUT_SEG="$TMPDIR/seg_$IDX.mp4"
  CAP_FILE="$TMPDIR/cap_$IDX.txt"
  BRAND_FILE="$TMPDIR/brand_$IDX.txt"
  printf '%s' "$CAP" > "$CAP_FILE"
  printf 'SONA · feedback demo' > "$BRAND_FILE"
  # Caption strip sits at the BOTTOM (height 88px) so it never collides with
  # the slide's own brand wordmark at top-left. Brand tag right, caption left.
  ffmpeg -hide_banner -loglevel error -y \
    -loop 1 -t "$DUR" -framerate "$FPS" -i "$ROOT/$PNG" \
    -filter_complex "[0:v]scale=${W}:${H},format=yuv420p,drawbox=x=0:y=ih-88:w=${W}:h=88:color=#142433@0.92:t=fill,drawtext=fontfile=${FONT_REG}:textfile=${CAP_FILE}:x=64:y=h-66:fontsize=28:fontcolor=#FAFAF7,drawtext=fontfile=${FONT_BOLD}:textfile=${BRAND_FILE}:x=w-text_w-64:y=h-62:fontsize=22:fontcolor=#F2A878[v]" \
    -map "[v]" -r "$FPS" -c:v libx264 -pix_fmt yuv420p -preset medium -crf 18 "$OUT_SEG"
  echo "  segment $IDX  ${DUR}s  → seg_$IDX.mp4"
  i=$((i+1))
done

# Stitch with crossfades using xfade.
# Build a filter graph that chains [v0]…[vN] with xfade between each.
INPUTS=()
for ((j=0; j<N; j++)); do
  IDX=$(printf "%02d" "$j")
  INPUTS+=( -i "$TMPDIR/seg_$IDX.mp4" )
done

# Compute cumulative offsets for xfade.
FILTER=""
PREV="0:v"
TOTAL=0
for ((j=0; j<N; j++)); do
  DUR=$(awk -F'\t' -v j="$j" 'NR==j+1{print $2}' < <(printf '%s\n' "${LINES[@]}"))
  if (( j == 0 )); then
    TOTAL=$DUR
    continue
  fi
  # offset where next slide begins (cum_prev - xfade)
  OFF=$(awk -v t="$TOTAL" -v x="$XFADE" 'BEGIN{printf "%.3f", t-x}')
  CUR="$j:v"
  OUT_L="x$j"
  FILTER+="[$PREV][$CUR]xfade=transition=fade:duration=$XFADE:offset=$OFF[$OUT_L];"
  PREV="$OUT_L"
  TOTAL=$(awk -v t="$TOTAL" -v d="$DUR" -v x="$XFADE" 'BEGIN{printf "%.3f", t + d - x}')
done

# Generate gentle ambient pad of length = TOTAL seconds.
# Two stacked low sines (220 Hz and 277 Hz ~ A3 + C#4), heavy low-pass, soft fade in/out.
AUDIO="$TMPDIR/pad.wav"
ffmpeg -hide_banner -loglevel error -y \
  -f lavfi -t "$TOTAL" -i "sine=frequency=220:sample_rate=48000" \
  -f lavfi -t "$TOTAL" -i "sine=frequency=277.18:sample_rate=48000" \
  -filter_complex "[0:a][1:a]amix=inputs=2:weights='0.6 0.4',
                   lowpass=f=900,
                   volume=0.10,
                   afade=t=in:st=0:d=1.5,
                   afade=t=out:st=$(awk -v t="$TOTAL" 'BEGIN{printf "%.3f", t-1.5}'):d=1.5" \
  -ar 48000 -ac 2 -c:a pcm_s16le "$AUDIO"

# Final mux.
ffmpeg -hide_banner -loglevel error -y \
  "${INPUTS[@]}" -i "$AUDIO" \
  -filter_complex "$FILTER" -map "[$PREV]" -map "$N:a" \
  -c:v libx264 -pix_fmt yuv420p -preset medium -crf 18 -r "$FPS" \
  -c:a aac -b:a 160k -shortest "$OUT"

echo "done. wrote $OUT ($(ffprobe -v 0 -show_entries format=duration -of csv=p=0 "$OUT") s)"
