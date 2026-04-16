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

munitor_header "run_test_setup"

SETUP_SCRIPT="${MUNITOR_TEST_SETUP_SCRIPT:-}"

if [[ -z "${SETUP_SCRIPT}" ]]; then
  echo "No test setup configured."
  exit 0
fi

if [[ -f "${SETUP_SCRIPT}" ]]; then
  echo "Running test setup script: ${SETUP_SCRIPT}"
  chmod +x "${SETUP_SCRIPT}"
  "${SETUP_SCRIPT}"
else
  echo "Running test setup command: ${SETUP_SCRIPT}"
  bash -c "${SETUP_SCRIPT}"
fi

echo "Test setup complete."
