# Initialize or verify git repo at repo root (run from anywhere).
# Requires Git for Windows: https://git-scm.com/download/win
$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Error "git not found. Install Git, then re-run this script."
}

Set-Location $repoRoot

if (-not (Test-Path ".git")) {
  git init -b main
} else {
  Write-Host ".git already exists at $repoRoot"
}

git add -A
git status
Write-Host ""
Write-Host "When ready, create the first commit:"
Write-Host "  git commit -m `"Initial commit: Sona MVP docs and GCP infra`""
