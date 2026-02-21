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

munitor_header "sdk_release"

ZIP_FILE="${SDK_ZIP_FILE:?SDK_ZIP_FILE not set}"
CHECKSUM_FILE="${SDK_CHECKSUM_FILE:?SDK_CHECKSUM_FILE not set}"
NAME="${SDK_ARTIFACT_NAME:?SDK_ARTIFACT_NAME not set}"
VERSION="${SDK_VERSION:?SDK_VERSION not set}"
TAG="${CIRCLE_TAG:?CIRCLE_TAG not set -- SDK release requires a tag}"

echo "Creating GitHub Release: ${TAG}"

# Generate release notes
NOTES="## ${NAME} v${VERSION}

### Contents
$(find "${SDK_STAGING_DIR}" -type f | sed "s|${SDK_STAGING_DIR}/|- |" | sort)

### Checksums (SHA256)
\`\`\`
$(cat "${CHECKSUM_FILE}")
\`\`\`
"

gh release create "${TAG}" \
  "${ZIP_FILE}" \
  "${CHECKSUM_FILE}" \
  --title "${NAME} v${VERSION}" \
  --notes "${NOTES}"

echo "GitHub Release created: ${TAG}"
