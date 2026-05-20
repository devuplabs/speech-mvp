#!/usr/bin/env bash
# Create sona-cloudbuild SA and bootstrap IAM for Terraform plan/apply via Cloud Build.
# Usage: ./bootstrap-cloud-build-iam.sh PROJECT_ID [PROJECT_NUMBER]
#
# Grants roles/owner for first apply only — narrow after success (see infra/BOOTSTRAP-MANUAL-STEPS.md).
set -euo pipefail

PROJECT_ID="${1:?PROJECT_ID required}"
PROJECT_NUMBER="${2:-}"

if [ -z "$PROJECT_NUMBER" ]; then
  if ! command -v gcloud >/dev/null 2>&1; then
    echo "gcloud required to resolve project number" >&2
    exit 1
  fi
  PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"
fi

CB_SA_ID="sona-cloudbuild"
CB_SA="${CB_SA_ID}@${PROJECT_ID}.iam.gserviceaccount.com"
STATE_BUCKET="${PROJECT_ID}-terraform-state"
P4SA="service-${PROJECT_NUMBER}@gcp-sa-cloudbuild.iam.gserviceaccount.com"

if ! gcloud iam service-accounts describe "${CB_SA}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  gcloud iam service-accounts create "${CB_SA_ID}" \
    --project="${PROJECT_ID}" \
    --display-name="Sona Cloud Build (Terraform)"
fi

gcloud iam service-accounts add-iam-policy-binding "${CB_SA}" --project="${PROJECT_ID}" \
  --member="serviceAccount:${P4SA}" \
  --role="roles/iam.serviceAccountUser" --quiet

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/logging.logWriter" \
  --condition=None --quiet

echo "Project:        ${PROJECT_ID}"
echo "Cloud Build SA: ${CB_SA}"
echo "State bucket:   gs://${STATE_BUCKET}"

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/owner" \
  --condition=None

gsutil iam ch "serviceAccount:${CB_SA}:roles/storage.objectAdmin" "gs://${STATE_BUCKET}" 2>/dev/null || {
  echo "Warning: could not set bucket IAM. Run bootstrap-terraform-state.sh first." >&2
}

echo "OK: Bootstrap IAM for Cloud Build on ${PROJECT_ID}"
echo "Next: setup-cloud-build and manual steps in infra/BOOTSTRAP-MANUAL-STEPS.md"
