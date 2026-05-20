# Bootstrap Cloud Build + GitHub (2nd gen) for Sona Terraform uk/dev.
# Usage: .\setup-cloud-build.ps1 [-ProjectId ...] [-SkipBootstrap]
param(
  [string] $ProjectId = "project-a625d19b-de99-48e9-9a9",
  [string] $ProjectNumber = "1055416779632",
  [string] $Region = "europe-west2",
  [string] $ConnectionName = "sona-github",
  [string] $RepositoryName = "speech-mvp",
  [string] $RemoteUri = "https://github.com/devuplabs/speech-mvp.git",
  [switch] $SkipBootstrap
)

$ErrorActionPreference = "Stop"
$env:CLOUDSDK_CORE_DISABLE_PROMPTS = "1"

if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
  Write-Error "gcloud not found. Install Google Cloud SDK."
}

Write-Host "=== Sona Cloud Build setup ===" -ForegroundColor Cyan
Write-Host "Project: $ProjectId  Region: $Region"

$apis = @(
  "cloudbuild.googleapis.com",
  "secretmanager.googleapis.com",
  "compute.googleapis.com",
  "sqladmin.googleapis.com",
  "servicenetworking.googleapis.com",
  "vpcaccess.googleapis.com",
  "run.googleapis.com",
  "cloudkms.googleapis.com",
  "artifactregistry.googleapis.com",
  "container.googleapis.com",
  "cloudtasks.googleapis.com",
  "iam.googleapis.com",
  "cloudresourcemanager.googleapis.com",
  "developerknowledge.googleapis.com"
)
gcloud services enable $apis --project=$ProjectId --quiet | Out-Null

# Cloud Build P4SA needs Secret Manager for GitHub OAuth tokens
$p4sa = "service-${ProjectNumber}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
gcloud projects add-iam-policy-binding $ProjectId `
  --member="serviceAccount:$p4sa" `
  --role="roles/secretmanager.admin" `
  --condition=None --quiet 2>&1 | Out-Null

if (-not $SkipBootstrap) {
  & "$PSScriptRoot\bootstrap-terraform-state.ps1" -ProjectId $ProjectId -Location $Region
  & "$PSScriptRoot\bootstrap-cloud-build-iam.ps1" -ProjectId $ProjectId -ProjectNumber $ProjectNumber
}

# GitHub connection
$connJson = gcloud builds connections describe $ConnectionName --region=$Region --project=$ProjectId --format=json 2>$null
if ($LASTEXITCODE -ne 0) {
  Write-Host "Creating GitHub connection '$ConnectionName'..." -ForegroundColor Yellow
  gcloud builds connections create github $ConnectionName --region=$Region --project=$ProjectId
  $connJson = gcloud builds connections describe $ConnectionName --region=$Region --project=$ProjectId --format=json
}

$conn = $connJson | ConvertFrom-Json
$stage = $conn.installationState.stage
if ($stage -eq "PENDING_USER_OAUTH") {
  Write-Host ""
  Write-Host "ACTION REQUIRED: Complete GitHub OAuth for Cloud Build" -ForegroundColor Yellow
  Write-Host $conn.installationState.actionUri
  Write-Host ""
  Write-Host "Re-run this script after OAuth completes."
  exit 2
}

if ($stage -eq "COMPLETE") {
  $installId = $conn.githubConfig.appInstallationId
  Write-Host "GitHub connection COMPLETE (appInstallationId: $installId)." -ForegroundColor Green
  Write-Host "If triggers fail: grant the Google Cloud Build app access to $RemoteUri"
  if ($installId) {
    Write-Host "  https://github.com/settings/installations/$installId"
  }
  Write-Host "  See docs/cloud-build-github-troubleshooting.md"
}
elseif ($stage -eq "PENDING_INSTALL_APP") {
  Write-Host ""
  Write-Host "ACTION REQUIRED: Install Cloud Build GitHub App" -ForegroundColor Yellow
  if ($conn.installationState.actionUri) { Write-Host $conn.installationState.actionUri }
  exit 2
}
else {
  Write-Host "Connection stage: $stage" -ForegroundColor Yellow
  Write-Host ($conn.installationState | ConvertTo-Json -Depth 5)
  if ($conn.installationState.actionUri) {
    Write-Host "Open: $($conn.installationState.actionUri)"
  }
}

# Link repository
$repoResource = "projects/$ProjectId/locations/$Region/connections/$ConnectionName/repositories/$RepositoryName"
$repoExists = gcloud builds repositories describe $RepositoryName `
  --connection=$ConnectionName --region=$Region --project=$ProjectId 2>$null
if ($LASTEXITCODE -ne 0) {
  Write-Host "Linking repository $RemoteUri ..." -ForegroundColor Yellow
  gcloud builds repositories create $RepositoryName `
    --remote-uri=$RemoteUri `
    --connection=$ConnectionName `
    --region=$Region `
    --project=$ProjectId
}

# Create triggers from templates
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$triggersDir = Join-Path $repoRoot "infra\ci\triggers"
$planTpl = Join-Path $triggersDir "sona-terraform-dev-plan.yaml"
$applyTpl = Join-Path $triggersDir "sona-terraform-dev-apply.yaml"
$planCfg = Join-Path $env:TEMP "sona-terraform-dev-plan.yaml"
$applyCfg = Join-Path $env:TEMP "sona-terraform-dev-apply.yaml"

(Get-Content $planTpl -Raw).Replace("REPLACE_REPOSITORY_RESOURCE", $repoResource) | Set-Content $planCfg -NoNewline
(Get-Content $applyTpl -Raw).Replace("REPLACE_REPOSITORY_RESOURCE", $repoResource) | Set-Content $applyCfg -NoNewline

foreach ($pair in @(
    @{ Name = "sona-terraform-dev-plan"; File = $planCfg },
    @{ Name = "sona-terraform-dev-apply"; File = $applyCfg }
  )) {
  $existing = gcloud builds triggers describe $pair.Name --region=$Region --project=$ProjectId 2>$null
  if ($LASTEXITCODE -eq 0) {
    Write-Host "Trigger $($pair.Name) already exists - updating..." -ForegroundColor Gray
    gcloud builds triggers update github $pair.Name `
      --trigger-config=$pair.File `
      --region=$Region `
      --project=$ProjectId
  }
  else {
    gcloud builds triggers create github --trigger-config=$pair.File --region=$Region --project=$ProjectId
  }
}

Write-Host ""
Write-Host "OK: Cloud Build triggers configured." -ForegroundColor Green
Write-Host "  Plan:   sona-terraform-dev-plan  (PR -> main, /gcbrun)"
Write-Host "  Apply:  sona-terraform-dev-apply (push main, approval required)"
Write-Host ""
Write-Host "Grant approvers: roles/cloudbuild.builds.approver on project $ProjectId"
Write-Host "Console: https://console.cloud.google.com/cloud-build/triggers?project=$ProjectId"
