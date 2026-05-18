#!/usr/bin/env bash
# Initialize or verify git repo at repo root.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

command -v git >/dev/null 2>&1 || { echo "Install git first." >&2; exit 1; }

if [ ! -d .git ]; then
  git init -b main
else
  echo ".git already exists at $REPO_ROOT"
fi

git add -A
git status
echo ""
echo "When ready: git commit -m 'Initial commit: Sona MVP docs and GCP infra'"
