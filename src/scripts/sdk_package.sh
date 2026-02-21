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

munitor_header "sdk_package"

STAGING="${SDK_STAGING_DIR:?SDK_STAGING_DIR not set}"
NAME="${SDK_ARTIFACT_NAME:?SDK_ARTIFACT_NAME not set}"
VERSION="${SDK_VERSION:?SDK_VERSION not set}"

ZIP_FILE="/tmp/${NAME}-${VERSION}.zip"

echo "Packaging SDK: ${ZIP_FILE}"

cd "$(dirname "${STAGING}")"
zip -r "${ZIP_FILE}" "$(basename "${STAGING}")"

SIZE=$(du -h "${ZIP_FILE}" | cut -f1)
echo "Package created: ${ZIP_FILE} (${SIZE})"

echo "export SDK_ZIP_FILE='${ZIP_FILE}'" >> "${BASH_ENV}"
