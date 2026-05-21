#!/usr/bin/env bash
# Build all Spring Petclinic microservice images for linux/arm64 (Graviton) and push to ECR.
#
# Strategy:
#   1. Maven builds all JARs (./mvnw clean install -DskipTests)
#   2. docker buildx builds an ARM64 image per service using those JARs
#   3. Each image is pushed to ECR as: {account}.dkr.ecr.{region}.amazonaws.com/petclinic-{env}/{service}:{tag}
#
# Prerequisites:
#   - AWS credentials configured and ECR login done (run scripts/ecr-login.sh first)
#   - docker buildx with QEMU support (installed automatically if missing)
#   - Java 17+ and Maven wrapper in the app repo
#
# Usage:
#   ./scripts/build-push.sh --app-repo /path/to/spring-petclinic-microservices \
#                           --env dev \
#                           --tag abc1234 \
#                           [--region eu-central-1] \
#                           [--services "config-server,api-gateway"]

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────

REGION="eu-central-1"
APP_REPO=""
ENV=""
TAG=""
SERVICES_FILTER=""

ALL_SERVICES=(
  "config-server:8888"
  "discovery-server:8761"
  "api-gateway:8080"
  "customers-service:8081"
  "visits-service:8082"
  "vets-service:8083"
  "genai-service:8084"
  "admin-server:9090"
)

# ── Argument parsing ───────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-repo)
      APP_REPO="$2"
      shift 2
      ;;
    --env)
      ENV="$2"
      shift 2
      ;;
    --tag)
      TAG="$2"
      shift 2
      ;;
    --region)
      REGION="$2"
      shift 2
      ;;
    --services)
      SERVICES_FILTER="$2"
      shift 2
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      echo "Usage: $0 --app-repo PATH --env ENV --tag TAG [--region REGION] [--services csv]" >&2
      exit 1
      ;;
  esac
done

# ── Validation ─────────────────────────────────────────────────────────────────

if [[ -z "${APP_REPO}" || -z "${ENV}" || -z "${TAG}" ]]; then
  echo "ERROR: --app-repo, --env, and --tag are required." >&2
  echo "Usage: $0 --app-repo PATH --env ENV --tag TAG [--region REGION] [--services csv]" >&2
  exit 1
fi

if [[ ! -d "${APP_REPO}" ]]; then
  echo "ERROR: app-repo directory not found: ${APP_REPO}" >&2
  exit 1
fi

if [[ "${ENV}" != "dev" && "${ENV}" != "prod" ]]; then
  echo "ERROR: --env must be 'dev' or 'prod'" >&2
  exit 1
fi

echo "==> Checking AWS credentials..."
if ! aws sts get-caller-identity --output text --query Arn &>/dev/null; then
  echo "ERROR: No valid AWS credentials. Run 'aws configure' or set AWS_* environment variables." >&2
  exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "==> Build parameters"
echo "    App repo: ${APP_REPO}"
echo "    Env:      ${ENV}"
echo "    Tag:      ${TAG}"
echo "    Region:   ${REGION}"
echo "    Registry: ${REGISTRY}"
echo ""

# ── QEMU + buildx setup ────────────────────────────────────────────────────────
# QEMU enables cross-compilation of linux/arm64 images on x86_64 hosts.

echo "==> Setting up QEMU for ARM64 cross-compilation..."
if ! docker buildx inspect petclinic-arm64-builder &>/dev/null; then
  docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
  docker buildx create --name petclinic-arm64-builder --driver docker-container --use
else
  docker buildx use petclinic-arm64-builder
fi
docker buildx inspect --bootstrap

# ── Maven build ────────────────────────────────────────────────────────────────
# Build all service JARs in one Maven invocation. docker buildx copies the
# compiled JAR from target/ — do not use Maven's buildDocker profile.

echo ""
echo "==> Building JARs with Maven (this may take several minutes)..."
cd "${APP_REPO}"
./mvnw clean install -DskipTests --batch-mode --no-transfer-progress

echo ""
echo "==> Maven build complete."

# ── Docker image build and push ────────────────────────────────────────────────

build_and_push() {
  local service="$1"
  local port="$2"
  local maven_module="spring-petclinic-${service}"
  local image_uri="${REGISTRY}/petclinic-${ENV}/${service}:${TAG}"

  echo ""
  echo "==> Building and pushing: ${service} → ${image_uri}"

  docker buildx build \
    --platform linux/arm64 \
    --file "docker/Dockerfile" \
    --build-arg ARTIFACT_NAME="${maven_module}" \
    --build-arg EXPOSED_PORT="${port}" \
    --tag "${image_uri}" \
    --push \
    .

  echo "    Pushed: ${image_uri}"
}

# Filter services if --services was provided

declare -A SERVICE_FILTER_MAP
if [[ -n "${SERVICES_FILTER}" ]]; then
  IFS=',' read -ra FILTER_LIST <<< "${SERVICES_FILTER}"
  for svc in "${FILTER_LIST[@]}"; do
    SERVICE_FILTER_MAP["${svc// /}"]=1
  done
fi

PUSHED=0
SKIPPED=0

for entry in "${ALL_SERVICES[@]}"; do
  svc="${entry%%:*}"
  port="${entry##*:}"

  if [[ -n "${SERVICES_FILTER}" && -z "${SERVICE_FILTER_MAP[$svc]+x}" ]]; then
    SKIPPED=$(( SKIPPED + 1 ))
    continue
  fi

  build_and_push "${svc}" "${port}"
  PUSHED=$(( PUSHED + 1 ))
done

# ── Summary ────────────────────────────────────────────────────────────────────

echo ""
echo "==> Build and push complete."
echo "    Images pushed: ${PUSHED}"
[[ "${SKIPPED}" -gt 0 ]] && echo "    Services skipped: ${SKIPPED}"
echo ""
echo "Images are available at:"
for entry in "${ALL_SERVICES[@]}"; do
  svc="${entry%%:*}"
  if [[ -n "${SERVICES_FILTER}" && -z "${SERVICE_FILTER_MAP[$svc]+x}" ]]; then
    continue
  fi
  echo "    ${REGISTRY}/petclinic-${ENV}/${svc}:${TAG}"
done
