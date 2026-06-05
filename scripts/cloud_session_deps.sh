#!/usr/bin/env bash
#
# Per-session dependency install for Claude Code cloud sessions.
#
# Invoked by the SessionStart hook in .claude/settings.json. SessionStart hooks
# run on EVERY session start (including resume) AND on your local machine, so we
# guard on CLAUDE_CODE_REMOTE (set to "true" only in cloud sessions) to avoid
# clobbering or slowing down local work.

set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

echo "Cloud session detected — installing project dependencies"

# API (Node 22 / TypeScript / Hono / Drizzle)
( cd apps/api && npm install ) &

# Flutter web app. The base image doesn't ship Flutter, so install it once
# (the container is ephemeral, so this runs per cloud session). Guarded with
# `|| true` throughout — an optional toolchain must never abort the hook.
(
  FLUTTER_HOME="${FLUTTER_HOME:-/opt/flutter}"
  if ! command -v flutter >/dev/null 2>&1 && [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
    echo "Installing Flutter (stable) to $FLUTTER_HOME"
    git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_HOME" \
      >/dev/null 2>&1 || true
  fi
  if [ -x "$FLUTTER_HOME/bin/flutter" ]; then
    # Symlink onto PATH so `flutter`/`dart` resolve in every later shell.
    ln -sf "$FLUTTER_HOME/bin/flutter" /usr/local/bin/flutter 2>/dev/null || true
    ln -sf "$FLUTTER_HOME/bin/dart" /usr/local/bin/dart 2>/dev/null || true
    export PATH="$FLUTTER_HOME/bin:$PATH"
    flutter --version >/dev/null 2>&1 || true   # warms the tool + Dart SDK
    ( cd apps/sona && flutter pub get ) || true
  fi
) &

# E2E (Playwright)
( cd e2e && npm install ) &

wait
echo "Dependency install complete"
