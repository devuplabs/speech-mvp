#!/usr/bin/env bash
# Grant the default Cloud Build service account permissions for Terraform plan/apply (bootstrap).
# Usage: ./bootstrap-cloud-build-iam.sh PROJECT_ID [PROJECT_NUMBER]
#
# After first successful apply, replace roles/editor with a custom least-privilege role.
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

CB_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"
STATE_BUCKET="${PROJECT_ID}-terraform-state"

echo "Project:        $PROJECT_ID"
echo "Cloud Build SA: $CB_SA"
echo "State bucket:   gs://$STATE_BUCKET"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/editor" \
  --condition=None

gsutil iam ch "serviceAccount:${CB_SA}:roles/storage.objectAdmin" "gs://${STATE_BUCKET}" 2>/dev/null || {
  echo "Warning: could not set bucket IAM (bucket missing?). Run bootstrap-terraform-state.sh first." >&2
}

echo "OK: Bootstrap IAM for Cloud Build on $PROJECT_ID"
echo "Next: connect GitHub and create plan + apply triggers (see infra/ci/cloud-build-terraform.md)"
