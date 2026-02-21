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

# tfsec is deprecated/archived -- use trivy config instead
faber_header "run_tfsec (trivy config)"

export PATH="${HOME}/bin:${PATH}"
faber_check_tool trivy --version

PATH_TO_SCAN="${TF_PATH:-terraform/}"
SOFT="${SOFT_FAIL:-true}"

ARGS=(
  config
  "${PATH_TO_SCAN}"
  --format json
  --output tfsec-results.json
  --severity "HIGH,CRITICAL"
)

if [[ "${SOFT}" == "true" ]]; then
  ARGS+=(--exit-code 0)
  echo "NOTE: soft_fail=true -- security findings will NOT fail the build."
else
  ARGS+=(--exit-code 1)
fi

echo "Running trivy config on ${PATH_TO_SCAN}..."
trivy "${ARGS[@]}"

# Print human-readable summary
echo ""
echo "--- Scan Summary ---"
trivy config "${PATH_TO_SCAN}" --severity HIGH,CRITICAL || true

echo "trivy config scan completed. Results saved to tfsec-results.json"
