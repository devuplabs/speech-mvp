# Show NVIDIA L4 GPU quota in europe-west2-b for the uk/dev project.
param(
  [string]$ProjectId = "project-a625d19b-de99-48e9-9a9",
  [string]$Zone = "europe-west2-b"
)

$ErrorActionPreference = "Stop"

Write-Host "L4 GPU quota for project=$ProjectId zone=$Zone`n"
gcloud compute regions describe europe-west2 --project=$ProjectId --format="yaml(quotas)" 2>$null | Select-String -Pattern "L4|GPU" -Context 0,2

Write-Host "`nTo request an increase: GCP Console -> IAM & Admin -> Quotas"
Write-Host "Filter: NVIDIA L4 GPUs, region europe-west2, zone $Zone"
