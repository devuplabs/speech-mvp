#!/usr/bin/env bash
# Assemble the per-slide PNGs into assets/marketing/deck/slides.pdf
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE"
img2pdf=/home/ubuntu/.local/bin/img2pdf
[[ -x "$img2pdf" ]] || img2pdf=$(command -v img2pdf)
"$img2pdf" --pagesize 1920x1080 \
  slides/01-cold-open.png \
  slides/02-meet-aria.png \
  slides/03-todays-inbox.png \
  slides/04-parent-journey.png \
  slides/05-sona-read-it.png \
  slides/06-triage-capture.png \
  slides/07-session-plan.png \
  slides/08-parent-summary.png \
  slides/09-audit.png \
  slides/10-the-math.png \
  slides/11-real-vs-vision.png \
  slides/12-ask.png \
  slides/13-credits.png \
  -o slides.pdf
echo "wrote $HERE/slides.pdf"
