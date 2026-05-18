#!/usr/bin/env bash
# Run Terraform for one environment directory: dev | stage | prod
# Requires backend.hcl (copy from backend.hcl.example) for remote state.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV="${1:?usage: terraform-env.sh <dev|stage|prod> [plan|apply|destroy]>}"
OP="${2:-plan}"
case "$ENV" in dev|stage|prod) ;; *)
  echo "Unknown env: $ENV" >&2
  exit 1
  ;;
esac
case "$OP" in plan|apply|destroy) ;; *)
  echo "Unknown op: $OP (use plan, apply, or destroy)" >&2
  exit 1
  ;;
esac
cd "$ROOT/terraform/environments/$ENV"

if [ -f backend.hcl ]; then
  terraform init -backend-config-file=backend.hcl -input=false
fi

exec terraform "$OP"
