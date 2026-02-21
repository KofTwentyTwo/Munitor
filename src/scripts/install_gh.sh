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

VERSION="${GH_VERSION:-2.62.0}"

faber_header "install_gh (v${VERSION})"

if command -v gh &> /dev/null; then
  echo "gh already installed: $(gh --version | head -1)"
  exit 0
fi

# Cleanup temp files on exit
cleanup() {
  rm -f /tmp/gh.tar.gz 2>/dev/null || true
  rm -rf /tmp/gh_extract 2>/dev/null || true
}
trap cleanup EXIT

echo "Installing gh v${VERSION}..."

ARCH=$(uname -m)
case "${ARCH}" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "ERROR: Unsupported architecture: ${ARCH}"; exit 1 ;;
esac

OS=$(uname -s | tr '[:upper:]' '[:lower:]')

URL="https://github.com/cli/cli/releases/download/v${VERSION}/gh_${VERSION}_${OS}_${ARCH}.tar.gz"

faber_download_with_retry "${URL}" /tmp/gh.tar.gz
mkdir -p /tmp/gh_extract
tar -xzf /tmp/gh.tar.gz -C /tmp/gh_extract
sudo mv "/tmp/gh_extract/gh_${VERSION}_${OS}_${ARCH}/bin/gh" /usr/local/bin/gh
sudo chmod +x /usr/local/bin/gh

echo "gh installed: $(gh --version | head -1)"
