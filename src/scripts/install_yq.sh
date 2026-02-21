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

faber_header "install_yq"

if command -v yq &> /dev/null; then
  echo "yq already installed: $(yq --version)"
  exit 0
fi

VERSION="${YQ_VERSION:-v4.44.1}"
BINARY="yq_linux_amd64"
URL="https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY}"

echo "Installing yq ${VERSION}..."
faber_download_with_retry "${URL}" /tmp/yq
chmod +x /tmp/yq
sudo mv /tmp/yq /usr/local/bin/yq

echo "yq installed: $(yq --version)"
