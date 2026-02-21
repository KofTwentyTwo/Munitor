#!/usr/bin/env bash
set -euo pipefail

# Source shared helpers
FABER_HELPERS="${FABER_HELPERS:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/faber_helpers.sh}"
# shellcheck source=faber_helpers.sh
if [[ -f "${FABER_HELPERS}" ]]; then source "${FABER_HELPERS}"
elif ! type faber_header &>/dev/null; then
  faber_header() { echo "=== Munitor: ${1:-unknown} ==="; }
  faber_check_tool() { command -v "$1" &>/dev/null || { echo "ERROR: $1 not found"; exit 1; }; }
  faber_download_with_retry() { curl -fsSL --retry 3 "$1" -o "$2"; }
fi

TRIVY_VERSION="${TRIVY_VERSION:-0.58.2}"

faber_header "run_trivy (v${TRIVY_VERSION})"

# Install Trivy if not present (direct binary download, no upstream installer script)
if ! command -v trivy &> /dev/null; then
  echo "Installing Trivy ${TRIVY_VERSION}..."
  INSTALL_DIR="${HOME}/bin"
  mkdir -p "${INSTALL_DIR}"
  ARCH=$(uname -m)
  case "${ARCH}" in
    x86_64)  ARCH="64bit" ;;
    aarch64|arm64) ARCH="ARM64" ;;
    *) echo "ERROR: Unsupported architecture: ${ARCH}"; exit 1 ;;
  esac
  TARBALL="trivy_${TRIVY_VERSION}_$(uname -s)-${ARCH}.tar.gz"
  faber_download_with_retry "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/${TARBALL}" "/tmp/${TARBALL}"
  tar -xzf "/tmp/${TARBALL}" -C "${INSTALL_DIR}" trivy
  rm -f "/tmp/${TARBALL}"
  chmod +x "${INSTALL_DIR}/trivy"
  export PATH="${INSTALL_DIR}:${PATH}"
fi

echo "Running Trivy filesystem scan..."

trivy fs \
  --format json \
  --output /tmp/trivy-results.json \
  --severity HIGH,CRITICAL \
  . || {
    EXIT_CODE=$?
    echo "Trivy found vulnerabilities. See /tmp/trivy-results.json"
    exit "${EXIT_CODE}"
  }

echo "Trivy scan passed."
