#!/usr/bin/env bash
# Build the Sona strategy memo PDF from Markdown.
#
# Pipeline:
#   1. Pandoc converts the Markdown source to a standalone HTML file with a
#      generated table of contents and inlined CSS.
#   2. Headless Chrome prints the HTML to a paginated PDF.
#
# Requires:  pandoc, google-chrome (or chrome).
# Outputs:
#   /opt/cursor/artifacts/sona-product-strategy-2026-05.pdf     # for download
#   docs/strategy/sona-product-strategy-2026-05.html            # intermediate
#
# Run from repo root.

set -euo pipefail

cd "$(dirname "$0")/../.."

SRC="docs/strategy/sona-product-strategy-2026-05.md"
CSS="docs/strategy/pdf-styles.css"
HTML="docs/strategy/sona-product-strategy-2026-05.html"
PDF_OUT="${PDF_OUT:-/opt/cursor/artifacts/sona-product-strategy-2026-05.pdf}"

mkdir -p "$(dirname "$PDF_OUT")"

# 1. Markdown -> standalone HTML with TOC.
pandoc "$SRC" \
  --from gfm+yaml_metadata_block+raw_html \
  --to html5 \
  --standalone \
  --toc \
  --toc-depth=2 \
  --metadata title-meta="Sona — Product Strategy & Differentiation Review (May 2026)" \
  --template=docs/strategy/pdf-template.html \
  --css="$CSS" \
  --self-contained \
  -o "$HTML"

# 2. HTML -> PDF via headless Chrome.
google-chrome \
  --headless=new \
  --disable-gpu \
  --no-pdf-header-footer \
  --no-sandbox \
  --print-to-pdf="$PDF_OUT" \
  --print-to-pdf-no-header \
  --virtual-time-budget=10000 \
  "file://$(pwd)/$HTML" 2>&1 | grep -v "^$" || true

echo "PDF written to: $PDF_OUT"
ls -lh "$PDF_OUT"
