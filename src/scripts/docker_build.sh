#!/usr/bin/env bash
set -euo pipefail

# Source shared helpers
MUNITOR_HELPERS="${MUNITOR_HELPERS:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/munitor_helpers.sh}"
# shellcheck source=munitor_helpers.sh
if [[ -f "${MUNITOR_HELPERS}" ]]; then source "${MUNITOR_HELPERS}"
elif ! type munitor_header &>/dev/null; then
  munitor_header() { echo "=== Munitor: ${1:-unknown} ==="; }
  munitor_check_tool() { command -v "$1" &>/dev/null || { echo "ERROR: $1 not found"; exit 1; }; }
  munitor_download_with_retry() { curl -fsSL --retry 3 "$1" -o "$2"; }
fi

IMAGE="${IMAGE_NAME:?IMAGE_NAME not set}"
REGISTRY="${REGISTRY:-ghcr.io/KofTwentyTwo}"
DOCKERFILE="${DOCKERFILE:-Dockerfile}"
VERSION="${PROJECT_VERSION:?PROJECT_VERSION not set -- run export_version_vars first}"
ENV_TAG="${DOCKER_ENV_TAG:-}"

FULL_IMAGE="${REGISTRY}/${IMAGE}"

munitor_header "docker_build (${FULL_IMAGE}:${VERSION})"
munitor_check_tool docker --version

# Build with version tag; add env tag when set (e.g., develop, staging)
BUILD_CMD=(docker build -f "${DOCKERFILE}" -t "${FULL_IMAGE}:${VERSION}")
if [[ -n "${ENV_TAG}" ]]; then
  BUILD_CMD+=(-t "${FULL_IMAGE}:${ENV_TAG}")
fi
BUILD_CMD+=(--build-arg "VERSION=${VERSION}" --build-arg "GIT_COMMIT_SHA=${CIRCLE_SHA1:-}" .)

"${BUILD_CMD[@]}"

echo "Docker build complete: ${FULL_IMAGE}:${VERSION}"

# Export for downstream steps
{
  echo "export DOCKER_IMAGE='${FULL_IMAGE}'"
  echo "export DOCKER_TAG='${VERSION}'"
  echo "export DOCKER_ENV_TAG='${ENV_TAG}'"
} >> "${BASH_ENV}"
