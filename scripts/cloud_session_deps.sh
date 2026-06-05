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

# Flutter web app
if command -v flutter >/dev/null 2>&1; then
  ( cd apps/sona && flutter pub get ) &
fi

# E2E (Playwright)
( cd e2e && npm install ) &

wait
echo "Dependency install complete"
