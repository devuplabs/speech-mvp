# Grant the default Cloud Build service account permissions for Terraform plan/apply (bootstrap).
# Usage: .\bootstrap-cloud-build-iam.ps1 -ProjectId "project-a625d19b-de99-48e9-9a9" [-ProjectNumber "1055416779632"]
param(
  [Parameter(Mandatory = $true)]
  [string] $ProjectId,
  [string] $ProjectNumber = ""
)

if (-not $ProjectNumber) {
  if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
    Write-Error "gcloud required to resolve project number"
  }
  $ProjectNumber = gcloud projects describe $ProjectId --format="value(projectNumber)"
}

$legacyCbSa = "${ProjectNumber}@cloudbuild.gserviceaccount.com"
$cbSaId = "sona-cloudbuild"
$cbSa = "${cbSaId}@${ProjectId}.iam.gserviceaccount.com"
$stateBucket = "${ProjectId}-terraform-state"
$p4sa = "service-${ProjectNumber}@gcp-sa-cloudbuild.iam.gserviceaccount.com"

# Newer projects may not have the legacy Cloud Build SA; use a dedicated SA.
if (-not (gcloud iam service-accounts describe $cbSa --project=$ProjectId 2>$null)) {
  gcloud iam service-accounts create $cbSaId `
    --project=$ProjectId `
    --display-name="Sona Cloud Build (Terraform)"
}
gcloud iam service-accounts add-iam-policy-binding $cbSa --project=$ProjectId `
  --member="serviceAccount:$p4sa" `
  --role="roles/iam.serviceAccountUser" `
  --quiet 2>&1 | Out-Null
gcloud projects add-iam-policy-binding $ProjectId `
  --member="serviceAccount:$cbSa" `
  --role="roles/logging.logWriter" `
  --condition=None --quiet 2>&1 | Out-Null

Write-Host "Project:        $ProjectId"
Write-Host "Cloud Build SA: $cbSa"
Write-Host "State bucket:   gs://$stateBucket"

gcloud projects add-iam-policy-binding $ProjectId `
  --member="serviceAccount:$cbSa" `
  --role="roles/editor" `
  --condition=None

$oldEap = $ErrorActionPreference
$ErrorActionPreference = "SilentlyContinue"
gsutil iam ch "serviceAccount:${cbSa}:roles/storage.objectAdmin" "gs://$stateBucket"
if ($LASTEXITCODE -ne 0) {
  Write-Warning "Could not set bucket IAM. Run bootstrap-terraform-state.ps1 first."
}
$ErrorActionPreference = $oldEap

Write-Host "OK: Bootstrap IAM for Cloud Build on $ProjectId"
