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

munitor_header "sdk_validate"

STAGING="${SDK_STAGING_DIR:?SDK_STAGING_DIR not set}"
CONFIG="${SDK_CONFIG:-.sdk-release.yml}"
ERRORS=0

echo "Validating SDK at ${STAGING}..."

# Check required files
REQUIRED_COUNT=$(yq '.required_files | length // 0' "${CONFIG}")
for i in $(seq 0 $((REQUIRED_COUNT - 1))); do
  REQUIRED=$(yq ".required_files[${i}]" "${CONFIG}")
  if [[ ! -e "${STAGING}/${REQUIRED}" ]]; then
    echo "  ERROR: Required file missing: ${REQUIRED}"
    ERRORS=$((ERRORS + 1))
  else
    echo "  OK: ${REQUIRED}"
  fi
done

# Check excluded content is absent
EXCLUDE_COUNT=$(yq '.excludes | length // 0' "${CONFIG}")
for i in $(seq 0 $((EXCLUDE_COUNT - 1))); do
  PATTERN=$(yq ".excludes[${i}]" "${CONFIG}")
  FOUND=$(find "${STAGING}" -path "*${PATTERN}" 2>/dev/null | head -1 || true)
  if [[ -n "${FOUND}" ]]; then
    echo "  ERROR: Excluded content found: ${FOUND}"
    ERRORS=$((ERRORS + 1))
  fi
done

# Check Devices/ directory has at least one .md file
if [[ -d "${STAGING}/Devices" ]]; then
  MD_COUNT=$(find "${STAGING}/Devices" -name "*.md" -type f | wc -l | tr -d ' ')
  if [[ "${MD_COUNT}" -eq 0 ]]; then
    echo "  ERROR: Devices/ directory has no .md files"
    ERRORS=$((ERRORS + 1))
  else
    echo "  OK: Devices/ has ${MD_COUNT} .md files"
  fi
fi

if [[ ${ERRORS} -gt 0 ]]; then
  echo "Validation FAILED with ${ERRORS} errors."
  exit 1
fi

echo "Validation passed."
