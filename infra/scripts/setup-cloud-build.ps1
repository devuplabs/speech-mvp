# Bootstrap Cloud Build + GitHub (2nd gen) for Sona Terraform uk/dev.
# Usage: .\setup-cloud-build.ps1 [-ProjectId ...] [-SkipBootstrap]
param(
  [string] $ProjectId = "project-a625d19b-de99-48e9-9a9",
  [string] $ProjectNumber = "1055416779632",
  [string] $Region = "europe-west2",
  [string] $ConnectionName = "sona-github",
  [string] $RepositoryName = "devuplabs-speech-mvp",
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

# Create triggers via REST (gcloud create fails without serviceAccount on newer projects)
$cbSaResource = "projects/$ProjectId/serviceAccounts/${ProjectNumber}@cloudbuild.gserviceaccount.com"
$token = gcloud auth print-access-token 2>$null
$headers = @{
  Authorization         = "Bearer $token"
  "x-goog-user-project" = $ProjectNumber
}
$triggerApi = "https://cloudbuild.googleapis.com/v1/projects/$ProjectId/locations/$Region/triggers"

$subs = @{
  _TERRAFORM_DIR           = "infra/terraform/environments/uk/dev"
  _STATE_BUCKET            = "${ProjectId}-terraform-state"
  _STATE_PREFIX            = "sona/uk/dev"
  _TARGET_PROJECT_ID       = $ProjectId
  _REGION                  = $Region
  _JURISDICTION            = "uk"
  _ENVIRONMENT             = "dev"
  _GCS_BUCKET_FORCE_DESTROY = "true"
  _DB_TIER                 = "db-f1-micro"
  _INFERENCE_ENABLED       = "true"
  _MODEL_GCS_PREFIX        = "gemma-3-27b-it"
  _VLLM_CONTAINER_IMAGE    = "europe-west2-docker.pkg.dev/$ProjectId/sona-sona/vllm-openai:latest"
  _INFERENCE_ZONE          = "europe-west2-b"
}

$planBody = @{
  name = "sona-terraform-dev-plan"
  description = "Terraform plan for uk/dev (PRs to main)"
  filename = "infra/ci/cloudbuild.terraform.plan.yaml"
  includeBuildLogs = "INCLUDE_BUILD_LOGS_WITH_STATUS"
  serviceAccount = $cbSaResource
  repositoryEventConfig = @{
    repository = $repoResource
    pullRequest = @{ branch = "^main$"; commentControl = "COMMENTS_ENABLED" }
  }
  substitutions = $subs
} | ConvertTo-Json -Depth 20

$applyBody = @{
  name = "sona-terraform-dev-apply"
  description = "Terraform apply for uk/dev (push to main, approval required)"
  filename = "infra/ci/cloudbuild.terraform.apply.yaml"
  includeBuildLogs = "INCLUDE_BUILD_LOGS_WITH_STATUS"
  serviceAccount = $cbSaResource
  approvalConfig = @{ approvalRequired = $true }
  repositoryEventConfig = @{
    repository = $repoResource
    push = @{ branch = "^main$" }
  }
  substitutions = $subs
} | ConvertTo-Json -Depth 20

foreach ($pair in @(
    @{ Name = "sona-terraform-dev-plan"; Body = $planBody },
    @{ Name = "sona-terraform-dev-apply"; Body = $applyBody }
  )) {
  $existing = gcloud builds triggers describe $pair.Name --region=$Region --project=$ProjectId 2>$null
  if ($LASTEXITCODE -eq 0) {
    Write-Host "Trigger $($pair.Name) already exists - skipping." -ForegroundColor Gray
    continue
  }
  Invoke-RestMethod -Uri $triggerApi -Method POST -Headers $headers -ContentType "application/json" -Body $pair.Body | Out-Null
  Write-Host "Created trigger $($pair.Name)" -ForegroundColor Green
}

Write-Host ""
Write-Host "OK: Cloud Build triggers configured." -ForegroundColor Green
Write-Host "  Plan:   sona-terraform-dev-plan  (PR -> main, /gcbrun)"
Write-Host "  Apply:  sona-terraform-dev-apply (push main, approval required)"
Write-Host ""
Write-Host "Grant approvers: roles/cloudbuild.builds.approver on project $ProjectId"
Write-Host "Console: https://console.cloud.google.com/cloud-build/triggers?project=$ProjectId"
