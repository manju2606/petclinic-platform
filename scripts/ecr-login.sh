#!/usr/bin/env bash
# Authenticate Docker to the AWS ECR registry for this account and region.
# Run this before any docker pull/push to ECR. Token is valid for 12 hours.
#
# Usage:
#   ./scripts/ecr-login.sh [--region eu-central-1]

set -euo pipefail

REGION="eu-central-1"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --region)
      REGION="$2"
      shift 2
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      echo "Usage: $0 [--region REGION]" >&2
      exit 1
      ;;
  esac
done

echo "==> Checking AWS credentials..."
if ! aws sts get-caller-identity --output text --query Arn &>/dev/null; then
  echo "ERROR: No valid AWS credentials found. Configure AWS CLI before running this script." >&2
  exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "==> Logging in to ECR registry: ${REGISTRY}"
aws ecr get-login-password --region "${REGION}" \
  | docker login --username AWS --password-stdin "${REGISTRY}"

echo "==> ECR login successful. Token valid for 12 hours."
echo "    Registry: ${REGISTRY}"
