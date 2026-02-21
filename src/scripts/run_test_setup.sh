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

faber_header "run_test_setup"

SETUP_SCRIPT="${FABER_TEST_SETUP_SCRIPT:-}"

if [[ -z "${SETUP_SCRIPT}" ]]; then
  echo "No test setup script configured."
  exit 0
fi

if [[ ! -f "${SETUP_SCRIPT}" ]]; then
  echo "ERROR: Test setup script '${SETUP_SCRIPT}' not found."
  exit 1
fi

echo "Running test setup: ${SETUP_SCRIPT}"
chmod +x "${SETUP_SCRIPT}"
"${SETUP_SCRIPT}"
echo "Test setup complete."
