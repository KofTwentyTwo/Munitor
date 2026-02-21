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

VERSION="${GITLEAKS_VERSION:-8.18.4}"

faber_header "install_gitleaks (v${VERSION})"

if command -v gitleaks &> /dev/null; then
  echo "gitleaks already installed: $(gitleaks version)"
  exit 0
fi

# Cleanup temp files on exit
cleanup() {
  rm -f /tmp/gitleaks.tar.gz /tmp/gitleaks 2>/dev/null || true
}
trap cleanup EXIT

echo "Installing gitleaks v${VERSION}..."

ARCH=$(uname -m)
case "${ARCH}" in
  x86_64) ARCH="x64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "ERROR: Unsupported architecture: ${ARCH}"; exit 1 ;;
esac

OS=$(uname -s | tr '[:upper:]' '[:lower:]')

URL="https://github.com/gitleaks/gitleaks/releases/download/v${VERSION}/gitleaks_${VERSION}_${OS}_${ARCH}.tar.gz"

faber_download_with_retry "${URL}" /tmp/gitleaks.tar.gz
tar -xzf /tmp/gitleaks.tar.gz -C /tmp gitleaks
chmod +x /tmp/gitleaks
sudo mv /tmp/gitleaks /usr/local/bin/gitleaks

echo "gitleaks installed: $(gitleaks version)"
