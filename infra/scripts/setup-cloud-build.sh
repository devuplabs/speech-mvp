#!/usr/bin/env bash
# Bootstrap Cloud Build + GitHub (2nd gen) for Sona Terraform uk/dev.
# Creates sona-cloudbuild SA triggers via REST API (gcloud create often fails without serviceAccount).
set -euo pipefail

PROJECT_ID="${1:-project-a625d19b-de99-48e9-9a9}"
PROJECT_NUMBER="${2:-1055416779632}"
REGION="${3:-europe-west2}"
CONNECTION_NAME="${4:-sona-github}"
REPOSITORY_NAME="${5:-devuplabs-speech-mvp}"
REMOTE_URI="${6:-https://github.com/devuplabs/speech-mvp.git}"
UPDATE_TRIGGERS="${UPDATE_TRIGGERS:-false}"

export CLOUDSDK_CORE_DISABLE_PROMPTS=1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Sona Cloud Build setup ==="
echo "Project: ${PROJECT_ID}  Region: ${REGION}"

gcloud services enable \
  cloudbuild.googleapis.com secretmanager.googleapis.com compute.googleapis.com \
  sqladmin.googleapis.com servicenetworking.googleapis.com vpcaccess.googleapis.com \
  run.googleapis.com cloudkms.googleapis.com artifactregistry.googleapis.com \
  container.googleapis.com cloudtasks.googleapis.com iam.googleapis.com \
  cloudresourcemanager.googleapis.com developerknowledge.googleapis.com \
  --project="${PROJECT_ID}" --quiet

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-cloudbuild.iam.gserviceaccount.com" \
  --role="roles/secretmanager.admin" --condition=None --quiet

"${SCRIPT_DIR}/bootstrap-terraform-state.sh" "${PROJECT_ID}" "${REGION}"
"${SCRIPT_DIR}/bootstrap-cloud-build-iam.sh" "${PROJECT_ID}" "${PROJECT_NUMBER}"

if ! gcloud builds connections describe "${CONNECTION_NAME}" --region="${REGION}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  gcloud builds connections create github "${CONNECTION_NAME}" --region="${REGION}" --project="${PROJECT_ID}"
fi

STAGE="$(gcloud builds connections describe "${CONNECTION_NAME}" --region="${REGION}" --project="${PROJECT_ID}" --format='value(installationState.stage)')"
case "${STAGE}" in
  PENDING_USER_OAUTH)
    echo "ACTION REQUIRED: Complete GitHub OAuth:"
    gcloud builds connections describe "${CONNECTION_NAME}" --region="${REGION}" --project="${PROJECT_ID}" \
      --format='value(installationState.actionUri)'
    exit 2
    ;;
  COMPLETE)
    echo "GitHub connection COMPLETE."
    ;;
  *)
    echo "Connection stage: ${STAGE}"
    gcloud builds connections describe "${CONNECTION_NAME}" --region="${REGION}" --project="${PROJECT_ID}" \
      --format='yaml(installationState)'
    ;;
esac

if ! gcloud builds repositories describe "${REPOSITORY_NAME}" \
  --connection="${CONNECTION_NAME}" --region="${REGION}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  gcloud builds repositories create "${REPOSITORY_NAME}" \
    --remote-uri="${REMOTE_URI}" \
    --connection="${CONNECTION_NAME}" \
    --region="${REGION}" \
    --project="${PROJECT_ID}"
fi

CB_SA_EMAIL="sona-cloudbuild@${PROJECT_ID}.iam.gserviceaccount.com"
CB_SA_RESOURCE="projects/${PROJECT_ID}/serviceAccounts/${CB_SA_EMAIL}"
REPO_RESOURCE="projects/${PROJECT_ID}/locations/${REGION}/connections/${CONNECTION_NAME}/repositories/${REPOSITORY_NAME}"
TRIGGER_API="https://cloudbuild.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/triggers"
TOKEN="$(gcloud auth print-access-token)"

plan_body="$(cat <<EOF
{
  "name": "sona-terraform-dev-plan",
  "description": "Terraform plan for uk/dev (PRs to main)",
  "filename": "infra/ci/cloudbuild.terraform.plan.yaml",
  "includeBuildLogs": "INCLUDE_BUILD_LOGS_WITH_STATUS",
  "serviceAccount": "${CB_SA_RESOURCE}",
  "repositoryEventConfig": {
    "repository": "${REPO_RESOURCE}",
    "pullRequest": { "branch": "^main$", "commentControl": "COMMENTS_ENABLED" }
  },
  "substitutions": {
    "_TERRAFORM_DIR": "infra/terraform/environments/uk/dev",
    "_STATE_BUCKET": "${PROJECT_ID}-terraform-state",
    "_STATE_PREFIX": "sona/uk/dev",
    "_TARGET_PROJECT_ID": "${PROJECT_ID}",
    "_REGION": "${REGION}",
    "_JURISDICTION": "uk",
    "_ENVIRONMENT": "dev",
    "_GCS_BUCKET_FORCE_DESTROY": "true",
    "_DB_TIER": "db-f1-micro",
    "_INFERENCE_ENABLED": "false",
    "_MODEL_GCS_PREFIX": "gemma-3-27b-it",
    "_VLLM_CONTAINER_IMAGE": "europe-west2-docker.pkg.dev/${PROJECT_ID}/sona-sona/vllm-openai:latest",
    "_INFERENCE_ZONE": "europe-west2-b"
  }
}
EOF
)"

apply_body="$(cat <<EOF
{
  "name": "sona-terraform-dev-apply",
  "description": "Terraform apply uk/dev (push main, approval, MVP core only)",
  "filename": "infra/ci/cloudbuild.terraform.apply.yaml",
  "includeBuildLogs": "INCLUDE_BUILD_LOGS_WITH_STATUS",
  "serviceAccount": "${CB_SA_RESOURCE}",
  "approvalConfig": { "approvalRequired": true },
  "repositoryEventConfig": {
    "repository": "${REPO_RESOURCE}",
    "push": { "branch": "^main$" }
  },
  "substitutions": {
    "_TERRAFORM_DIR": "infra/terraform/environments/uk/dev",
    "_STATE_BUCKET": "${PROJECT_ID}-terraform-state",
    "_STATE_PREFIX": "sona/uk/dev",
    "_TARGET_PROJECT_ID": "${PROJECT_ID}",
    "_REGION": "${REGION}",
    "_JURISDICTION": "uk",
    "_ENVIRONMENT": "dev",
    "_GCS_BUCKET_FORCE_DESTROY": "true",
    "_DB_TIER": "db-f1-micro",
    "_INFERENCE_ENABLED": "false",
    "_MODEL_GCS_PREFIX": "gemma-3-27b-it",
    "_VLLM_CONTAINER_IMAGE": "europe-west2-docker.pkg.dev/${PROJECT_ID}/sona-sona/vllm-openai:latest",
    "_INFERENCE_ZONE": "europe-west2-b"
  }
}
EOF
)"

upsert_trigger() {
  local name="$1"
  local body="$2"
  if gcloud builds triggers describe "${name}" --region="${REGION}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
    if [ "${UPDATE_TRIGGERS}" = "true" ]; then
      local tid
      tid="$(gcloud builds triggers describe "${name}" --region="${REGION}" --project="${PROJECT_ID}" --format='value(id)')"
      curl -sS -X PATCH \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "x-goog-user-project: ${PROJECT_NUMBER}" \
        -H "Content-Type: application/json" \
        -d "${body}" \
        "${TRIGGER_API}/${tid}" >/dev/null
      echo "Updated trigger ${name}"
    else
      echo "Trigger ${name} already exists (set UPDATE_TRIGGERS=true to sync)."
    fi
  else
    curl -sS -X POST \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "x-goog-user-project: ${PROJECT_NUMBER}" \
      -H "Content-Type: application/json" \
      -d "${body}" \
      "${TRIGGER_API}" >/dev/null
    echo "Created trigger ${name}"
  fi
}

upsert_trigger "sona-terraform-dev-plan" "${plan_body}"
upsert_trigger "sona-terraform-dev-apply" "${apply_body}"

echo ""
echo "OK: Cloud Build triggers configured."
echo "Manual steps: infra/BOOTSTRAP-MANUAL-STEPS.md"
