#!/usr/bin/env bash
# Bootstrap script: provisions S3 bucket + DynamoDB table for Terraform remote state.
# Run once before the first `terraform init`. Safe to run multiple times (idempotent).
#
# Usage:
#   ./scripts/bootstrap-state.sh [--region eu-central-1]
#
# After running, initialise each environment with:
#   terraform init -backend-config="bucket=<BUCKET_NAME>"
# The exact command is printed at the end of this script.

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
BUCKET_NAME="petclinic-terraform-state-${ACCOUNT_ID}"
TABLE_NAME="petclinic-terraform-locks"

echo "==> Bootstrap parameters"
echo "    Region:    ${REGION}"
echo "    Account:   ${ACCOUNT_ID}"
echo "    Bucket:    ${BUCKET_NAME}"
echo "    DynamoDB:  ${TABLE_NAME}"
echo ""

# ── S3 Bucket ─────────────────────────────────────────────────────────────────

if aws s3api head-bucket --bucket "${BUCKET_NAME}" --region "${REGION}" 2>/dev/null; then
  echo "==> S3 bucket already exists: ${BUCKET_NAME}"
else
  echo "==> Creating S3 bucket: ${BUCKET_NAME}"
  if [[ "${REGION}" == "us-east-1" ]]; then
    aws s3api create-bucket \
      --bucket "${BUCKET_NAME}" \
      --region "${REGION}"
  else
    aws s3api create-bucket \
      --bucket "${BUCKET_NAME}" \
      --region "${REGION}" \
      --create-bucket-configuration LocationConstraint="${REGION}"
  fi
fi

echo "==> Enabling S3 versioning..."
aws s3api put-bucket-versioning \
  --bucket "${BUCKET_NAME}" \
  --versioning-configuration Status=Enabled

echo "==> Enabling S3 server-side encryption (AES256)..."
aws s3api put-bucket-encryption \
  --bucket "${BUCKET_NAME}" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      },
      "BucketKeyEnabled": true
    }]
  }'

echo "==> Blocking all S3 public access..."
aws s3api put-public-access-block \
  --bucket "${BUCKET_NAME}" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# ── DynamoDB Table ─────────────────────────────────────────────────────────────

if aws dynamodb describe-table \
    --table-name "${TABLE_NAME}" \
    --region "${REGION}" \
    --output text --query 'Table.TableStatus' 2>/dev/null | grep -qE "ACTIVE|CREATING"; then
  echo "==> DynamoDB table already exists: ${TABLE_NAME}"
else
  echo "==> Creating DynamoDB table: ${TABLE_NAME}"
  aws dynamodb create-table \
    --table-name "${TABLE_NAME}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${REGION}"

  echo "==> Waiting for DynamoDB table to become active..."
  aws dynamodb wait table-exists \
    --table-name "${TABLE_NAME}" \
    --region "${REGION}"
fi

# ── Done ───────────────────────────────────────────────────────────────────────

echo ""
echo "==> Bootstrap complete."
echo ""
echo "Initialise Terraform environments with:"
echo ""
echo "    # Dev"
echo "    cd terraform/environments/dev"
echo "    terraform init -backend-config=\"bucket=${BUCKET_NAME}\""
echo ""
echo "    # Prod"
echo "    cd terraform/environments/prod"
echo "    terraform init -backend-config=\"bucket=${BUCKET_NAME}\""
echo ""
