#!/usr/bin/env bash
set -euo pipefail

# Source shared helpers
FABER_HELPERS="${FABER_HELPERS:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/faber_helpers.sh}"
# shellcheck source=faber_helpers.sh
if [[ -f "${FABER_HELPERS}" ]]; then source "${FABER_HELPERS}"
elif ! type faber_header &>/dev/null; then
  faber_header() { echo "=== Faber: ${1:-unknown} ==="; }
  faber_check_tool() { command -v "$1" &>/dev/null || { echo "ERROR: $1 not found"; exit 1; }; }
  faber_download_with_retry() { curl -fsSL --retry 3 "$1" -o "$2"; }
fi

IMAGE="${IMAGE_NAME:?IMAGE_NAME not set}"
REGISTRY="${REGISTRY:-ghcr.io/dmdbrands}"
DOCKERFILE="${DOCKERFILE:-Dockerfile}"
VERSION="${PROJECT_VERSION:?PROJECT_VERSION not set -- run export_version_vars first}"
ENV_TAG="${DOCKER_ENV_TAG:-}"

FULL_IMAGE="${REGISTRY}/${IMAGE}"

faber_header "docker_build (${FULL_IMAGE}:${VERSION})"
faber_check_tool docker --version

# Build with version tag; add env tag when set (e.g., develop, staging)
BUILD_CMD=(docker build -f "${DOCKERFILE}" -t "${FULL_IMAGE}:${VERSION}")
if [[ -n "${ENV_TAG}" ]]; then
  BUILD_CMD+=(-t "${FULL_IMAGE}:${ENV_TAG}")
fi
BUILD_CMD+=(--build-arg "VERSION=${VERSION}" .)

"${BUILD_CMD[@]}"

echo "Docker build complete: ${FULL_IMAGE}:${VERSION}"

# Export for downstream steps
{
  echo "export DOCKER_IMAGE='${FULL_IMAGE}'"
  echo "export DOCKER_TAG='${VERSION}'"
  echo "export DOCKER_ENV_TAG='${ENV_TAG}'"
} >> "${BASH_ENV}"
