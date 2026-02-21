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

faber_header "sdk_scrub"

STAGING="${SDK_STAGING_DIR:?SDK_STAGING_DIR not set -- run sdk_assemble first}"
CONFIG="${SDK_CONFIG:-.sdk-release.yml}"

echo "Scrubbing build artifacts from ${STAGING}..."

# Default scrub patterns (always applied)
DEFAULT_SCRUB=(
  ".DS_Store"
  "Thumbs.db"
  ".git"
  ".gitignore"
  "*.xcworkspace"
  "*.xcuserdata"
  "xcuserdata"
  "build"
  "DerivedData"
  ".idea"
  "*.iml"
  "__pycache__"
  "*.pyc"
  "node_modules"
)

# Apply default scrub patterns
for pattern in "${DEFAULT_SCRUB[@]}"; do
  find "${STAGING}" -name "${pattern}" -exec rm -rf {} + 2>/dev/null || true
done

# Apply custom scrub patterns from config
SCRUB_COUNT=$(yq '.scrub_patterns | length // 0' "${CONFIG}")
for i in $(seq 0 $((SCRUB_COUNT - 1))); do
  PATTERN=$(yq ".scrub_patterns[${i}]" "${CONFIG}")
  echo "  Scrubbing: ${PATTERN}"
  find "${STAGING}" -name "${PATTERN}" -exec rm -rf {} + 2>/dev/null || true
done

FILE_COUNT=$(find "${STAGING}" -type f | wc -l | tr -d ' ')
echo "Scrub complete. ${FILE_COUNT} files remain."
