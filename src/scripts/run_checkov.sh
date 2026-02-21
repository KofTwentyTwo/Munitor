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

munitor_header "run_checkov"
munitor_check_tool checkov --version

PATH_TO_SCAN="${CHECKOV_PATH:-terraform/}"
SKIP_CHECKS="${CHECKOV_SKIP:-}"
SOFT="${SOFT_FAIL:-true}"

ARGS=(
  --directory "${PATH_TO_SCAN}"
  --quiet
  --compact
)

if [[ -n "${SKIP_CHECKS}" ]]; then
  ARGS+=(--skip-check "${SKIP_CHECKS}")
fi

if [[ "${SOFT}" == "true" ]]; then
  ARGS+=(--soft-fail)
  echo "NOTE: soft_fail=true -- checkov findings will NOT fail the build."
fi

echo "Running checkov on ${PATH_TO_SCAN}..."
checkov "${ARGS[@]}"

echo "checkov scan completed"
