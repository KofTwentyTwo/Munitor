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

faber_header "install_opentofu"

if command -v tofu &>/dev/null; then
  echo "OpenTofu already installed: $(tofu --version)"
  exit 0
fi

faber_download_with_retry "https://get.opentofu.org/install-opentofu.sh" /tmp/install-opentofu.sh
chmod +x /tmp/install-opentofu.sh
sudo /tmp/install-opentofu.sh --install-method deb
rm /tmp/install-opentofu.sh

echo "Installed OpenTofu: $(tofu --version)"
