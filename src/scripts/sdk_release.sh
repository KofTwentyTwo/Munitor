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

faber_header "sdk_release"

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
