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

Write-Host "`nDone. On-demand skills are in .cursor/skills/"
