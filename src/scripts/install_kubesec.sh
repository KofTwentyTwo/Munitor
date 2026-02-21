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

VERSION="${KUBESEC_VERSION:-2.14.0}"

munitor_header "install_kubesec (v${VERSION})"

if command -v kubesec &>/dev/null; then
  echo "kubesec already installed: $(kubesec version 2>&1 || true)"
  exit 0
fi

munitor_check_tool curl --version
munitor_check_tool tar --version

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "${ARCH}" in
  x86_64)  ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
esac

URL="https://github.com/controlplaneio/kubesec/releases/download/v${VERSION}/kubesec_${OS}_${ARCH}.tar.gz"

TMPDIR=$(mktemp -d)
cleanup() { rm -rf "${TMPDIR}"; }
trap cleanup EXIT

echo "Downloading kubesec v${VERSION} from ${URL}..."
munitor_download_with_retry "${URL}" "${TMPDIR}/kubesec.tar.gz"

tar -xzf "${TMPDIR}/kubesec.tar.gz" -C "${TMPDIR}"
sudo mv "${TMPDIR}/kubesec" /usr/local/bin/kubesec
sudo chmod +x /usr/local/bin/kubesec

if ! command -v kubesec &>/dev/null; then
  echo "ERROR: kubesec not found after install."
  exit 1
fi

echo "=== kubesec Installed ==="
echo "  kubesec: $(kubesec version 2>&1 || true)"
