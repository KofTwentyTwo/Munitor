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

faber_header "sdk_checksum"

ZIP_FILE="${SDK_ZIP_FILE:?SDK_ZIP_FILE not set}"
STAGING="${SDK_STAGING_DIR:?SDK_STAGING_DIR not set}"
CONFIG="${SDK_CONFIG:-.sdk-release.yml}"
CHECKSUM_FILE="/tmp/CHECKSUMS.sha256"

echo "Generating checksums..."

# Checksum the zip
sha256sum "${ZIP_FILE}" > "${CHECKSUM_FILE}"

# Checksum individual binaries from config
BINARY_COUNT=$(yq '.checksum_files | length // 0' "${CONFIG}")
for i in $(seq 0 $((BINARY_COUNT - 1))); do
  PATTERN=$(yq ".checksum_files[${i}]" "${CONFIG}")
  # shellcheck disable=SC2086
  find "${STAGING}" -name "${PATTERN}" -type f | while read -r file; do
    sha256sum "${file}" >> "${CHECKSUM_FILE}"
  done
done

echo "Checksums written to: ${CHECKSUM_FILE}"
cat "${CHECKSUM_FILE}"

echo "export SDK_CHECKSUM_FILE='${CHECKSUM_FILE}'" >> "${BASH_ENV}"
