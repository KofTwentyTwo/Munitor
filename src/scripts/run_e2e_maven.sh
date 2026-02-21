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

faber_header "run_e2e_maven"
faber_check_tool mvn --version

echo "Running Maven integration tests (failsafe)..."

# Run verify phase which triggers failsafe plugin for *IT.java tests.
# Unit tests are skipped since they already ran in build-and-test.
mvn verify \
  -DskipTests \
  --batch-mode \
  --fail-at-end \
  --no-transfer-progress

echo "Maven integration tests complete."
