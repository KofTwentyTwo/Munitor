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

munitor_header "run_gitleaks"

echo "Running gitleaks secret scan..."

REPORT_FILE="/tmp/gitleaks-report.json"

gitleaks detect \
  --source . \
  --verbose \
  --report-format json \
  --report-path "${REPORT_FILE}" || {
    EXIT_CODE=$?
    echo "ERROR: gitleaks detected secrets in the repository."
    echo "Review the report at: ${REPORT_FILE}"
    if [[ -f "${REPORT_FILE}" ]]; then
      echo "---"
      cat "${REPORT_FILE}"
    fi
    exit "${EXIT_CODE}"
  }

echo "No secrets detected."
