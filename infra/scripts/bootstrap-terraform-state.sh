#!/usr/bin/env bash
# One-time: create a versioned GCS bucket for Terraform state in the target project.
# Usage: ./bootstrap-terraform-state.sh PROJECT_ID [LOCATION]
set -euo pipefail

PROJECT_ID="${1:?PROJECT_ID required}"
LOCATION="${2:-europe-west2}"
BUCKET_NAME="${PROJECT_ID}-terraform-state"

if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud not found. Install Google Cloud SDK." >&2
  exit 1
fi

gcloud config set project "${PROJECT_ID}"

if gsutil ls -b "gs://${BUCKET_NAME}" >/dev/null 2>&1; then
  echo "Bucket gs://${BUCKET_NAME} already exists."
else
  gsutil mb -p "${PROJECT_ID}" -l "${LOCATION}" "gs://${BUCKET_NAME}"
fi

gsutil versioning set on "gs://${BUCKET_NAME}"

echo "OK: Terraform state bucket gs://${BUCKET_NAME} (versioning on)."
