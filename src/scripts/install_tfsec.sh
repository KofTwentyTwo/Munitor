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

# tfsec is deprecated/archived -- use trivy config instead
TRIVY_VERSION="${TRIVY_VERSION:-0.58.2}"
INSTALL_DIR="${HOME}/bin"

faber_header "install_tfsec (trivy ${TRIVY_VERSION})"

if command -v trivy &>/dev/null; then
  echo "trivy already installed: $(trivy --version | head -1)"
  exit 0
fi

mkdir -p "${INSTALL_DIR}"

ARCH=$(uname -m)
case "${ARCH}" in
  x86_64)  ARCH="64bit" ;;
  aarch64) ARCH="ARM64" ;;
  arm64)   ARCH="ARM64" ;;
  *) echo "ERROR: Unsupported architecture: ${ARCH}"; exit 1 ;;
esac

OS=$(uname -s)

TARBALL="trivy_${TRIVY_VERSION}_${OS}-${ARCH}.tar.gz"
URL="https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/${TARBALL}"

echo "Downloading trivy ${TRIVY_VERSION} (${OS}-${ARCH})..."
faber_download_with_retry "${URL}" "/tmp/${TARBALL}"
tar -xzf "/tmp/${TARBALL}" -C "${INSTALL_DIR}" trivy
rm -f "/tmp/${TARBALL}"
chmod +x "${INSTALL_DIR}/trivy"

export PATH="${INSTALL_DIR}:${PATH}"
echo "Installed trivy: $(trivy --version | head -1)"
