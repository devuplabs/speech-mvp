# One-time: create a versioned GCS bucket for Terraform state in the target project.
# Usage: .\bootstrap-terraform-state.ps1 -ProjectId "your-project" [-Location "europe-west2"]
param(
  [Parameter(Mandatory = $true)]
  [string] $ProjectId,
  [string] $Location = "europe-west2"
)

$bucketName = "$ProjectId-terraform-state"

if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
  Write-Error "gcloud not found. Install Google Cloud SDK."
}

gcloud config set project $ProjectId | Out-Null

$oldEap = $ErrorActionPreference
$ErrorActionPreference = "SilentlyContinue"
gsutil ls -b "gs://$bucketName" | Out-Null
$exists = ($LASTEXITCODE -eq 0)
$ErrorActionPreference = $oldEap

if (-not $exists) {
  gsutil mb -p $ProjectId -l $Location "gs://$bucketName"
}

gsutil versioning set on "gs://$bucketName"

Write-Host "OK: Terraform state bucket gs://$bucketName (versioning on)."
