#!/usr/bin/env bash
#
# Cloud environment setup for Claude Code on the web.
#
# Point your Claude Code cloud Environment's "Setup script" field at the
# contents of this file (paste it in, or curl it from the repo). It installs
# system-level tooling the cloud VM does not ship with. It runs ONCE when a new
# cloud session is created and the result is cached, so keep it under ~5 min.
#
# Project dependency installs (npm install, flutter pub get) live in the
# SessionStart hook in .claude/settings.json instead, since those run on every
# session start and benefit from the repo already being checked out.
#
# Requires "Trusted" network access so apt / git can reach their registries.

set -euo pipefail

log() { printf '\n=== %s ===\n' "$1"; }

log "apt: base tooling + PostgreSQL 16"
sudo apt-get update -y
sudo apt-get install -y gh postgresql postgresql-contrib

log "PostgreSQL: start service and provision dev DB/user"
sudo service postgresql start
# Idempotent: ignore "already exists" on repeat runs.
sudo -u postgres psql -c "CREATE USER sona_app WITH PASSWORD 'sona_dev_pass';" 2>/dev/null || true
sudo -u postgres psql -c "CREATE DATABASE sona OWNER sona_app;" 2>/dev/null || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE sona TO sona_app;" 2>/dev/null || true

log "Flutter 3.44.0 (only if not pre-installed)"
if ! command -v flutter >/dev/null 2>&1; then
  sudo git clone --depth 1 --branch 3.44.0 https://github.com/flutter/flutter.git /opt/flutter
  sudo git config --system --add safe.directory /opt/flutter
  export PATH="$PATH:/opt/flutter/bin"
  # Persist for the agent's interactive shells.
  echo 'export PATH="$PATH:/opt/flutter/bin"' >> "$HOME/.bashrc"
  flutter --version
  flutter precache --web
fi

log "Cloud setup complete"
