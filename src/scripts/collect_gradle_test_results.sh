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

munitor_header "collect_gradle_test_results"

DEST="/tmp/test-results"
mkdir -p "${DEST}"

find . -path "*/build/test-results/test/*.xml" -exec cp {} "${DEST}/" \;

COUNT=$(find "${DEST}" -name "*.xml" 2>/dev/null | wc -l | tr -d ' ')
echo "Collected ${COUNT} test result file(s) to ${DEST}/"
