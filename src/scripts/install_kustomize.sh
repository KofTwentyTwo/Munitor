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

VERSION="${KUSTOMIZE_VERSION:-5.5.0}"

munitor_header "install_kustomize (v${VERSION})"

if command -v kustomize &>/dev/null; then
  echo "Kustomize already installed: $(kustomize version)"
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

# URL quirk: path segment uses kustomize%2Fv{VERSION}
URL="https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${VERSION}/kustomize_v${VERSION}_${OS}_${ARCH}.tar.gz"

TMPDIR=$(mktemp -d)
cleanup() { rm -rf "${TMPDIR}"; }
trap cleanup EXIT

echo "Downloading kustomize v${VERSION} from ${URL}..."
munitor_download_with_retry "${URL}" "${TMPDIR}/kustomize.tar.gz"

tar -xzf "${TMPDIR}/kustomize.tar.gz" -C "${TMPDIR}"
sudo mv "${TMPDIR}/kustomize" /usr/local/bin/kustomize
sudo chmod +x /usr/local/bin/kustomize

if ! command -v kustomize &>/dev/null; then
  echo "ERROR: kustomize not found after install."
  exit 1
fi

echo "=== Kustomize Installed ==="
echo "  kustomize: $(kustomize version)"
