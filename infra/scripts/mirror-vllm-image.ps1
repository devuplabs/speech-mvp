# Mirror vllm/vllm-openai to Artifact Registry (required before inference_enabled=true).
param(
  [string]$ProjectId = "project-a625d19b-de99-48e9-9a9",
  [string]$Region = "europe-west2",
  [string]$Repository = "sona-sona",
  [string]$ImageTag = "latest"
)

$ErrorActionPreference = "Stop"
$target = "${Region}-docker.pkg.dev/${ProjectId}/${Repository}/vllm-openai:${ImageTag}"

Write-Host "Configuring docker auth for $Region..."
gcloud auth configure-docker "${Region}-docker.pkg.dev" --quiet

Write-Host "Pulling vllm/vllm-openai:$ImageTag ..."
docker pull "vllm/vllm-openai:${ImageTag}"

Write-Host "Tagging -> $target"
docker tag "vllm/vllm-openai:${ImageTag}" $target

Write-Host "Pushing..."
docker push $target

Write-Host "Done: $target"
