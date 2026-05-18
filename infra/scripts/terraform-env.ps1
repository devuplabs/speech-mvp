# Run Terraform for one jurisdiction × environment stack.
# Usage: .\terraform-env.ps1 -Jurisdiction uk -Environment dev [-Operation plan]
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("uk", "us")]
  [string] $Jurisdiction,
  [Parameter(Mandatory = $true)]
  [ValidateSet("dev", "stage", "prod")]
  [string] $Environment,
  [Parameter(Mandatory = $false)]
  [ValidateSet("plan", "apply", "destroy")]
  [string] $Operation = "plan"
)

$infraRoot = Split-Path -Parent $PSScriptRoot
$envDir = Join-Path $infraRoot "terraform\environments\$Jurisdiction\$Environment"
Set-Location $envDir

if (Test-Path (Join-Path $envDir "backend.hcl")) {
  terraform init -backend-config-file=backend.hcl -input=false | Out-Host
}

& terraform $Operation
