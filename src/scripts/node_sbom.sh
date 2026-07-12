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

munitor_header "node_sbom"
munitor_check_tool node --version
munitor_check_tool npx --version

CYCLONEDX_NPM_VERSION="${CYCLONEDX_NPM_VERSION:-1.19.3}"

echo "Generating CycloneDX SBOM via @cyclonedx/cyclonedx-npm..."

npx --yes "@cyclonedx/cyclonedx-npm@${CYCLONEDX_NPM_VERSION}" \
  --output-file bom.json \
  --output-format json

echo "SBOM generated at bom.json"
