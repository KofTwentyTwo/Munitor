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

munitor_header "docker_push_ghcr"
munitor_check_tool docker --version

IMAGE="${DOCKER_IMAGE:?DOCKER_IMAGE not set -- run docker_build first}"
TAG="${DOCKER_TAG:?DOCKER_TAG not set -- run docker_build first}"
ENV_TAG="${DOCKER_ENV_TAG:-}"
TOKEN="${!GHCR_TOKEN_VAR:-}"
USER="${!GHCR_USER_VAR:-}"

if [[ -z "${TOKEN}" || -z "${USER}" ]]; then
  echo "ERROR: GHCR credentials not set (\$${GHCR_TOKEN_VAR}, \$${GHCR_USER_VAR})"
  exit 1
fi

REGISTRY_HOST="${DOCKER_IMAGE%%/*}"
echo "Authenticating to ${REGISTRY_HOST}..."
echo "${TOKEN}" | docker login "${REGISTRY_HOST}" -u "${USER}" --password-stdin

echo "Pushing ${IMAGE}:${TAG}..."
docker push "${IMAGE}:${TAG}"

if [[ -n "${ENV_TAG}" ]]; then
  echo "Pushing ${IMAGE}:${ENV_TAG}..."
  docker push "${IMAGE}:${ENV_TAG}"
fi

echo "Push complete."
