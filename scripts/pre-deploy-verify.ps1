# Run before opening a PR that touches intake / API / Flutter web.
# Fast checks (no browser): Flutter unit tests (if SDK available), API typecheck,
# Playwright API specs. Full UI E2E: cd e2e; npm run test:full (~4 min).

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

$flutterAvailable = $null -ne (Get-Command flutter -ErrorAction SilentlyContinue)

if ($flutterAvailable) {
    Write-Host "==> Flutter unit + widget tests (intake validation, controller race, full 8-step flow)"
    Set-Location "$root\apps\sona"
    flutter test
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
    Write-Host "==> Skipping Flutter unit + widget tests (flutter not on PATH)"
}

Write-Host "==> API TypeScript typecheck"
Set-Location "$root\apps\api"
npm run typecheck
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "==> Playwright API intake specs (hosted dev API)"
Set-Location "$root\e2e"
npm run test:api
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "Pre-deploy verify passed (local + API E2E)."
Write-Host "Optional full UI + dashboard:  cd e2e; npm run test:full"
