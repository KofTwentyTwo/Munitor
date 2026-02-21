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

munitor_header "install_yq"

if command -v yq &> /dev/null; then
  echo "yq already installed: $(yq --version)"
  exit 0
fi

VERSION="${YQ_VERSION:-v4.44.1}"
BINARY="yq_linux_amd64"
URL="https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY}"

echo "Installing yq ${VERSION}..."
munitor_download_with_retry "${URL}" /tmp/yq
chmod +x /tmp/yq
sudo mv /tmp/yq /usr/local/bin/yq

echo "yq installed: $(yq --version)"
