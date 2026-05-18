# Run Terraform for one environment: dev | stage | prod
# Requires backend.hcl (copy from backend.hcl.example). Runs terraform init when backend.hcl exists.
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("dev", "stage", "prod")]
  [string] $Environment,
  [Parameter(Mandatory = $false)]
  [ValidateSet("plan", "apply", "destroy")]
  [string] $Operation = "plan"
)

$infraRoot = Split-Path -Parent $PSScriptRoot
$envDir = Join-Path $infraRoot "terraform\environments\$Environment"
Set-Location $envDir

if (Test-Path (Join-Path $envDir "backend.hcl")) {
  terraform init -backend-config-file=backend.hcl -input=false | Out-Host
}

& terraform $Operation
