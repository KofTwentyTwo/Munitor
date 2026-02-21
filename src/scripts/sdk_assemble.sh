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

munitor_header "sdk_assemble"

CONFIG="${SDK_CONFIG:-.sdk-release.yml}"
VERSION="${CIRCLE_TAG:-${PROJECT_VERSION:-unknown}}"
# Strip leading 'v' from tag
VERSION="${VERSION#v}"

if [[ ! -f "${CONFIG}" ]]; then
  echo "ERROR: SDK config '${CONFIG}' not found."
  exit 1
fi

ARTIFACT_NAME=$(yq '.artifact_name' "${CONFIG}")
if [[ -z "${ARTIFACT_NAME}" || "${ARTIFACT_NAME}" == "null" ]]; then
  echo "ERROR: 'artifact_name' is required in ${CONFIG}"
  exit 1
fi

STAGING_DIR="/tmp/${ARTIFACT_NAME}-${VERSION}"
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

echo "Assembling SDK: ${ARTIFACT_NAME}-${VERSION}"

# Copy includes
INCLUDE_COUNT=$(yq '.includes | length' "${CONFIG}")
for i in $(seq 0 $((INCLUDE_COUNT - 1))); do
  PATTERN=$(yq ".includes[${i}]" "${CONFIG}")
  echo "  Including: ${PATTERN}"
  # Use rsync for pattern-based copying
  # shellcheck disable=SC2086
  for item in ${PATTERN}; do
    if [[ -e "${item}" ]]; then
      DEST_DIR="${STAGING_DIR}/$(dirname "${item}")"
      mkdir -p "${DEST_DIR}"
      cp -r "${item}" "${DEST_DIR}/"
    fi
  done
done

# Auto-discover Devices/ directory
if [[ -d "Devices" ]]; then
  echo "  Auto-discovered Devices/ directory"
  cp -r Devices "${STAGING_DIR}/"
fi

# Remove excludes
EXCLUDE_COUNT=$(yq '.excludes | length // 0' "${CONFIG}")
for i in $(seq 0 $((EXCLUDE_COUNT - 1))); do
  PATTERN=$(yq ".excludes[${i}]" "${CONFIG}")
  echo "  Excluding: ${PATTERN}"
  # shellcheck disable=SC2086
  find "${STAGING_DIR}" -path "*${PATTERN}" -exec rm -rf {} + 2>/dev/null || true
done

FILE_COUNT=$(find "${STAGING_DIR}" -type f | wc -l | tr -d ' ')
echo "SDK assembled: ${FILE_COUNT} files in ${STAGING_DIR}"

# Export for downstream steps
{
  echo "export SDK_STAGING_DIR='${STAGING_DIR}'"
  echo "export SDK_ARTIFACT_NAME='${ARTIFACT_NAME}'"
  echo "export SDK_VERSION='${VERSION}'"
} >> "${BASH_ENV}"
