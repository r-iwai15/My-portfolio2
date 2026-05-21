#!/usr/bin/env bash
# Terraform plan helper for hotel_folder stacks.
#
# Usage:
#   ./scripts/terraform-plan.sh type-b              # local .state/ backend
#   ./scripts/terraform-plan.sh type-a
#   AWS_PROFILE=prod ./scripts/terraform-plan.sh type-b aws   # S3 remote state
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STACK="${1:-}"
MODE="${2:-local}"

if [[ -z "$STACK" || ! "$STACK" =~ ^(type-a|type-b)$ ]]; then
  echo "Usage: $0 <type-a|type-b> [local|aws]" >&2
  exit 1
fi

TF_DIR="$ROOT/terraform/$STACK"
cd "$TF_DIR"
mkdir -p .state

PLAN_FILE="plan.tfplan"

if [[ "$MODE" == "--aws" || "$MODE" == "aws" ]]; then
  if grep -q 'backend "local"' versions.tf 2>/dev/null; then
    echo "S3 plan requires backend \"s3\" in versions.tf — see backends/README.md" >&2
    exit 1
  fi
  BACKEND_FILE="${TF_STATE_BACKEND_FILE:-backends/s3.hcl}"
  if [[ ! -f "$BACKEND_FILE" ]]; then
    echo "Missing $BACKEND_FILE — copy backends/s3.hcl.example and set bucket/key." >&2
    exit 1
  fi
  echo "▶ init (reconfigure → S3: $BACKEND_FILE)"
  terraform init -input=false -upgrade -reconfigure -backend-config="$BACKEND_FILE"
else
  echo "▶ init (local backend: .state/terraform.tfstate)"
  terraform init -input=false -upgrade
fi

echo "▶ plan → $PLAN_FILE"
terraform plan -input=false -out="$PLAN_FILE"
echo "✅ Plan saved: $TF_DIR/$PLAN_FILE"
echo "   Show: terraform -chdir=$TF_DIR show $PLAN_FILE"
