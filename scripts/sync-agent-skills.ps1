# Sync on-demand agent skills from addyosmani/agent-skills (local clone).
# Usage: .\scripts\sync-agent-skills.ps1
#        .\scripts\sync-agent-skills.ps1 -Source "E:\devup\agent-skills"

param(
    [string]$Source = $(if ($env:AGENT_SKILLS_PATH) { $env:AGENT_SKILLS_PATH } else { "E:\devup\agent-skills" })
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
$Dest = Join-Path $RepoRoot ".cursor\skills"
$SkillsSource = Join-Path $Source "skills"

if (-not (Test-Path $SkillsSource)) {
    Write-Error "Agent skills not found at: $SkillsSource`nClone: git clone https://github.com/addyosmani/agent-skills.git`nOr set AGENT_SKILLS_PATH."
}

$OnDemand = @(
    "frontend-ui-engineering",
    "browser-testing-with-devtools",
    "api-and-interface-design",
    "security-and-hardening",
    "documentation-and-adrs",
    "debugging-and-error-recovery",
    "ci-cd-and-automation",
    "spec-driven-development",
    "planning-and-task-breakdown",
    "test-driven-development",
    "code-simplification",
    "performance-optimization",
    "shipping-and-launch",
    "deprecation-and-migration",
    "incremental-implementation",
    "code-review-and-quality"
)

New-Item -ItemType Directory -Force -Path $Dest | Out-Null

foreach ($name in $OnDemand) {
    $srcDir = Join-Path $SkillsSource $name
    $dstDir = Join-Path $Dest $name
    if (-not (Test-Path $srcDir)) {
        Write-Warning "Skip missing skill: $name"
        continue
    }
    if (Test-Path $dstDir) { Remove-Item $dstDir -Recurse -Force }
    Copy-Item $srcDir $dstDir -Recurse -Force

    $skillMd = Join-Path $dstDir "SKILL.md"
    if (Test-Path $skillMd) {
        $content = Get-Content $skillMd -Raw
        if ($content -notmatch "disable-model-invocation") {
            $content = [regex]::Replace(
                $content,
                '^---\r?\n',
                "---`r`ndisable-model-invocation: false`r`n",
                1
            )
            Set-Content $skillMd $content -NoNewline -Encoding utf8
        }
    }
    Write-Host "Synced: $name"
}

# References (checklists)
$RefsSource = Join-Path $Source "references"
$RefsDest = Join-Path $RepoRoot ".cursor\references"
if (Test-Path $RefsSource) {
    if (Test-Path $RefsDest) { Remove-Item $RefsDest -Recurse -Force }
    Copy-Item $RefsSource $RefsDest -Recurse -Force
    Write-Host "Synced: references/"
}

# Re-apply Speech MVP CI/CD override (upstream sync must not remove deploy policy)
$ciCdSkill = Join-Path $Dest "ci-cd-and-automation\SKILL.md"
if (Test-Path $ciCdSkill) {
    $mvpBlock = @"

## Speech MVP override (always wins)

This repo does **not** deploy from the agent or laptop. Do not run ``gcloud builds submit``, ``gcloud run deploy``, or manual Cloud Run updates.

| Target | Path |
|--------|------|
| API + worker | PR → ``main`` → ``sona-api-dev-deploy`` (``infra/ci/cloudbuild.api.yaml``) |
| Flutter web | PR → ``main`` → ``sona-web-dev-deploy`` (``infra/ci/cloudbuild.web.yaml``) |
| Terraform | PR → ``main`` → ``sona-terraform-dev-apply`` (``infra/**``, approval) |

See ``.cursor/skills/mvp-git-workflow/SKILL.md`` and ``infra/ci/README.md``.
"@
    $content = Get-Content $ciCdSkill -Raw
    if ($content -notmatch "Speech MVP override") {
        $content = $content -replace "(# CI/CD and Automation\r?\n)", "`$1`r`n$mvpBlock`r`n"
        Set-Content $ciCdSkill $content -NoNewline -Encoding utf8
        Write-Host "Patched: ci-cd-and-automation (MVP deploy policy)"
    }
}

Write-Host "`nDone. On-demand skills are in .cursor/skills/"
