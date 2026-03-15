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

TRIVY_VERSION="${TRIVY_VERSION:-0.69.3}"
INSTALL_DIR="${HOME}/bin"
mkdir -p "${INSTALL_DIR}"
export PATH="${INSTALL_DIR}:${PATH}"

munitor_header "run_trivy_image"

# Resolve image tag: prefer IMAGE_TAG parameter, fall back to DOCKER_IMAGE:DOCKER_TAG
# set by docker_build.sh via BASH_ENV. The parameter path can contain literal
# ${DOCKER_TAG} because CircleCI environment blocks don't perform shell expansion.
IMAGE="${IMAGE_TAG:-}"
if [[ -z "${IMAGE}" || "${IMAGE}" == *'${'* ]]; then
  if [[ -n "${DOCKER_IMAGE:-}" && -n "${DOCKER_TAG:-}" ]]; then
    IMAGE="${DOCKER_IMAGE}:${DOCKER_TAG}"
    echo "Resolved image from BASH_ENV: ${IMAGE}"
  else
    echo "ERROR: No image tag available. Set IMAGE_TAG or ensure docker_build ran first."
    exit 1
  fi
fi

# Install Trivy if not present (direct binary download, no upstream installer script)
if ! command -v trivy &> /dev/null; then
  echo "Installing Trivy ${TRIVY_VERSION}..."
  ARCH=$(uname -m)
  case "${ARCH}" in
    x86_64)  ARCH="64bit" ;;
    aarch64|arm64) ARCH="ARM64" ;;
    *) echo "ERROR: Unsupported architecture: ${ARCH}"; exit 1 ;;
  esac
  TARBALL="trivy_${TRIVY_VERSION}_$(uname -s)-${ARCH}.tar.gz"
  munitor_download_with_retry "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/${TARBALL}" "/tmp/${TARBALL}"
  tar -xzf "/tmp/${TARBALL}" -C "${INSTALL_DIR}" trivy
  rm -f "/tmp/${TARBALL}"
  chmod +x "${INSTALL_DIR}/trivy"
fi

echo "Scanning container image: ${IMAGE}"

trivy image \
  --format json \
  --output /tmp/trivy-image-results.json \
  --severity HIGH,CRITICAL \
  --exit-code 1 \
  "${IMAGE}" || {
    EXIT_CODE=$?
    echo "Trivy found vulnerabilities in container image."
    trivy image --severity HIGH,CRITICAL "${IMAGE}"
    exit "${EXIT_CODE}"
  }

echo "Container image scan passed."
