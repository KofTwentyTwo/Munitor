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

VERSION="${KUBE_LINTER_VERSION:-0.6.8}"

munitor_header "install_kube_linter (v${VERSION})"

if command -v kube-linter &>/dev/null; then
  echo "kube-linter already installed: $(kube-linter version 2>&1 || true)"
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

# kube-linter release assets use OS only, no arch suffix (e.g., kube-linter-linux.tar.gz)
URL="https://github.com/stackrox/kube-linter/releases/download/v${VERSION}/kube-linter-${OS}.tar.gz"

TMPDIR=$(mktemp -d)
cleanup() { rm -rf "${TMPDIR}"; }
trap cleanup EXIT

echo "Downloading kube-linter v${VERSION} from ${URL}..."
munitor_download_with_retry "${URL}" "${TMPDIR}/kube-linter.tar.gz"

tar -xzf "${TMPDIR}/kube-linter.tar.gz" -C "${TMPDIR}"
sudo mv "${TMPDIR}/kube-linter" /usr/local/bin/kube-linter
sudo chmod +x /usr/local/bin/kube-linter

if ! command -v kube-linter &>/dev/null; then
  echo "ERROR: kube-linter not found after install."
  exit 1
fi

echo "=== kube-linter Installed ==="
echo "  kube-linter: $(kube-linter version 2>&1 || true)"
