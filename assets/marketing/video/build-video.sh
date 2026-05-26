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

# Pick the music track to use.
#   Default: assets/marketing/music/final-lasting-hope.mp3
#            ("Lasting Hope" by Kevin MacLeod, CC BY 4.0; see
#            assets/marketing/music/README.md).
#   Override: export MUSIC=/abs/path/to/your-track.mp3
#   Fallback: if MUSIC is unset and the default file is missing, generate
#            a CC0 ambient pad with ffmpeg.
MUSIC="${MUSIC:-$ROOT/music/final-lasting-hope.mp3}"
AUDIO="$TMPDIR/track.wav"

# Fade settings (per the music-revision brief):
#   FADE_IN  = 2 s
#   FADE_OUT = 3 s
FADE_IN=2.0
FADE_OUT=3.0
FADE_OUT_AT=$(awk -v t="$TOTAL" -v f="$FADE_OUT" 'BEGIN{printf "%.3f", t-f}')

# Build the timed-duck expression for the volume filter.
#
# We do not have a voice track to drive a true side-chain compressor, so we
# approximate the effect: at each "caption-appearance moment" we dip the
# music by -3 dB (linear amplitude 0.708) using a Gaussian envelope. The
# Gaussian is centred on the slide-transition time, sigma=0.4 s, so the dip
# is meaningful for ~±0.8 s around each new caption and otherwise has zero
# effect.
#
# A new caption appears at the END of each crossfade — i.e. at the
# cumulative end of slide j-1 (which equals the start of slide j). These
# offsets are exactly the same numbers we used to build the xfade graph
# above, so reuse them.
DUCK_DB=-3.0
DUCK_SIGMA=0.4
# 1 - 10^(DUCK_DB/20) = drop magnitude (0.292 for -3 dB)
DUCK_DROP=$(awk -v d="$DUCK_DB" 'BEGIN{printf "%.6f", 1 - exp(d * log(10)/20)}')

# Recompute cumulative slide-end times (the moments the next caption appears).
# Skip t=0 (covered by the fade-in) and skip the final boundary (covered by
# the fade-out).
duck_terms=""
total_running=0
slide_idx=0
for line in "${LINES[@]}"; do
  d=$(awk -F'\t' '{print $2}' <<<"$line")
  if (( slide_idx == 0 )); then
    total_running=$d
  else
    total_running=$(awk -v t="$total_running" -v dd="$d" -v x="$XFADE" 'BEGIN{printf "%.3f", t + dd - x}')
  fi
  # The caption for slide slide_idx fully replaces the prior caption at the
  # END of the crossfade, which is total_running for slide slide_idx-1's
  # end. The first slide's caption appears at t=0 (skip), and the last
  # boundary is the end of the video (skip — fade-out handles it).
  if (( slide_idx >= 1 )); then
    # Centre the duck at the moment the new caption is fully on-screen.
    t_centre=$(awk -v t="$total_running" -v d="$d" -v x="$XFADE" 'BEGIN{printf "%.3f", t - d + x}')
    # gauss-like dip: DROP * exp(-((t - centre)/sigma)^2)
    duck_terms="$duck_terms + ${DUCK_DROP}*exp(-pow((t-${t_centre})/${DUCK_SIGMA}\\,2))"
  fi
  slide_idx=$((slide_idx+1))
done
# Drop the leading " + "
duck_terms="${duck_terms# + }"
# Cap the multiplicative envelope at >= 0.5 (-6 dB) so stacked Gaussians can
# never silence the track entirely.
DUCK_EXPR="max(0.5\\,1 - (${duck_terms}))"

if [[ -f "$MUSIC" ]]; then
  echo "  music: $MUSIC"
  echo "  ducking: ${DUCK_DB} dB at each caption transition (sigma=${DUCK_SIGMA}s)"
  echo "  fades:   in=${FADE_IN}s · out=${FADE_OUT}s"
  # Two-pass loudnorm to flatten LRA + land at -22 LUFS, then loop/trim to
  # TOTAL, then apply timed volume dips, then fade in/out.
  ffmpeg -hide_banner -loglevel error -y \
    -stream_loop -1 -i "$MUSIC" \
    -filter_complex "[0:a]atrim=duration=$TOTAL,
                     loudnorm=I=-22:TP=-2:LRA=5,
                     volume=eval=frame:volume='${DUCK_EXPR}',
                     afade=t=in:st=0:d=${FADE_IN},
                     afade=t=out:st=${FADE_OUT_AT}:d=${FADE_OUT}" \
    -ar 48000 -ac 2 -c:a pcm_s16le "$AUDIO"
else
  echo "  music: $MUSIC missing — using generated CC0 ambient pad"
  ffmpeg -hide_banner -loglevel error -y \
    -f lavfi -t "$TOTAL" -i "sine=frequency=220:sample_rate=48000" \
    -f lavfi -t "$TOTAL" -i "sine=frequency=277.18:sample_rate=48000" \
    -filter_complex "[0:a][1:a]amix=inputs=2:weights='0.6 0.4',
                     lowpass=f=900,
                     volume=0.10,
                     volume=eval=frame:volume='${DUCK_EXPR}',
                     afade=t=in:st=0:d=${FADE_IN},
                     afade=t=out:st=${FADE_OUT_AT}:d=${FADE_OUT}" \
    -ar 48000 -ac 2 -c:a pcm_s16le "$AUDIO"
fi

# Final mux.
ffmpeg -hide_banner -loglevel error -y \
  "${INPUTS[@]}" -i "$AUDIO" \
  -filter_complex "$FILTER" -map "[$PREV]" -map "$N:a" \
  -c:v libx264 -pix_fmt yuv420p -preset medium -crf 18 -r "$FPS" \
  -c:a aac -b:a 160k -shortest "$OUT"

echo "done. wrote $OUT ($(ffprobe -v 0 -show_entries format=duration -of csv=p=0 "$OUT") s)"
