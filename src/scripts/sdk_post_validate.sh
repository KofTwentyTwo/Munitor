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

faber_header "sdk_post_validate"

TAG="${CIRCLE_TAG:?CIRCLE_TAG not set}"
NAME="${SDK_ARTIFACT_NAME:?SDK_ARTIFACT_NAME not set}"
VERSION="${SDK_VERSION:?SDK_VERSION not set}"

DOWNLOAD_DIR="/tmp/post-validate"

# Cleanup on exit
cleanup() {
  rm -rf "${DOWNLOAD_DIR}" 2>/dev/null || true
}
trap cleanup EXIT

rm -rf "${DOWNLOAD_DIR}"
mkdir -p "${DOWNLOAD_DIR}"

echo "Post-release validation for ${TAG}..."

# Download release assets
echo "Downloading release assets..."
gh release download "${TAG}" --dir "${DOWNLOAD_DIR}"

# Verify zip exists
ZIP_FILE="${DOWNLOAD_DIR}/${NAME}-${VERSION}.zip"
if [[ ! -f "${ZIP_FILE}" ]]; then
  echo "ERROR: Release zip not found: ${ZIP_FILE}"
  echo "Available files:"
  ls -la "${DOWNLOAD_DIR}/"
  exit 1
fi

# Verify checksums
CHECKSUM_FILE="${DOWNLOAD_DIR}/CHECKSUMS.sha256"
if [[ -f "${CHECKSUM_FILE}" ]]; then
  echo "Verifying checksums..."
  cd "${DOWNLOAD_DIR}"
  # Verify only the zip checksum (individual file paths may differ)
  EXPECTED_HASH=$(grep "${NAME}-${VERSION}.zip" "${CHECKSUM_FILE}" | awk '{print $1}')
  ACTUAL_HASH=$(sha256sum "${ZIP_FILE}" | awk '{print $1}')
  if [[ "${EXPECTED_HASH}" != "${ACTUAL_HASH}" ]]; then
    echo "ERROR: Checksum mismatch for ${ZIP_FILE}"
    echo "  Expected: ${EXPECTED_HASH}"
    echo "  Actual:   ${ACTUAL_HASH}"
    exit 1
  fi
  echo "Checksum verified."
else
  echo "WARNING: No CHECKSUMS.sha256 found in release."
fi

# Unzip and verify structure
echo "Extracting and verifying structure..."
unzip -q "${ZIP_FILE}" -d "${DOWNLOAD_DIR}/extracted"

EXTRACTED_DIR="${DOWNLOAD_DIR}/extracted/${NAME}-${VERSION}"
if [[ ! -d "${EXTRACTED_DIR}" ]]; then
  echo "ERROR: Expected directory ${NAME}-${VERSION} not found after extraction."
  exit 1
fi

FILE_COUNT=$(find "${EXTRACTED_DIR}" -type f | wc -l | tr -d ' ')
echo "Release contains ${FILE_COUNT} files."

if [[ "${FILE_COUNT}" -eq 0 ]]; then
  echo "ERROR: Release zip is empty."
  exit 1
fi

echo "Post-release validation passed."
