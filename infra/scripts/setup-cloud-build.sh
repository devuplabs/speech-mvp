#!/usr/bin/env bash
# Bootstrap Cloud Build + GitHub (2nd gen) for Sona Terraform uk/dev.
set -euo pipefail

PROJECT_ID="${1:-project-a625d19b-de99-48e9-9a9}"
PROJECT_NUMBER="${2:-1055416779632}"
REGION="${3:-europe-west2}"
CONNECTION_NAME="${4:-sona-github}"
REPOSITORY_NAME="${5:-speech-mvp}"
REMOTE_URI="${6:-https://github.com/devuplabs/speech-mvp.git}"

export CLOUDSDK_CORE_DISABLE_PROMPTS=1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "=== Sona Cloud Build setup ==="
gcloud config set project "${PROJECT_ID}"

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
if [ "${STAGE}" = "PENDING_USER_OAUTH" ]; then
  echo "ACTION REQUIRED: Complete GitHub OAuth:"
  gcloud builds connections describe "${CONNECTION_NAME}" --region="${REGION}" --project="${PROJECT_ID}" \
    --format='value(installationState.actionUri)'
  exit 2
fi

if ! gcloud builds repositories describe "${REPOSITORY_NAME}" \
  --connection="${CONNECTION_NAME}" --region="${REGION}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  gcloud builds repositories create "${REPOSITORY_NAME}" \
    --remote-uri="${REMOTE_URI}" \
    --connection="${CONNECTION_NAME}" \
    --region="${REGION}" \
    --project="${PROJECT_ID}"
fi

REPO_RESOURCE="projects/${PROJECT_ID}/locations/${REGION}/connections/${CONNECTION_NAME}/repositories/${REPOSITORY_NAME}"
TRIGGERS_DIR="${REPO_ROOT}/infra/ci/triggers"
PLAN_CFG="$(mktemp)"
APPLY_CFG="$(mktemp)"
sed "s|REPLACE_REPOSITORY_RESOURCE|${REPO_RESOURCE}|g" "${TRIGGERS_DIR}/sona-terraform-dev-plan.yaml" > "${PLAN_CFG}"
sed "s|REPLACE_REPOSITORY_RESOURCE|${REPO_RESOURCE}|g" "${TRIGGERS_DIR}/sona-terraform-dev-apply.yaml" > "${APPLY_CFG}"

for name file in "sona-terraform-dev-plan:${PLAN_CFG}" "sona-terraform-dev-apply:${APPLY_CFG}"; do
  trigger="${name%%:*}"
  cfg="${name##*:}"
  if gcloud builds triggers describe "${trigger}" --region="${REGION}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
    gcloud builds triggers update github "${trigger}" --trigger-config="${cfg}" --region="${REGION}" --project="${PROJECT_ID}"
  else
    gcloud builds triggers create github --trigger-config="${cfg}" --region="${REGION}" --project="${PROJECT_ID}"
  fi
done

echo "OK: Cloud Build triggers configured."
