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

munitor_header "run_kubesec"
munitor_check_tool kubesec version

SCAN_OVERLAY="${KUBESEC_SCAN_OVERLAY:-production}"
INPUT_FILE="/tmp/kustomize-output/${SCAN_OVERLAY}.yaml"

if [[ ! -f "${INPUT_FILE}" ]]; then
  echo "ERROR: Kustomize output not found: ${INPUT_FILE}"
  echo "Ensure kustomize-validate ran successfully and produced output for overlay '${SCAN_OVERLAY}'."
  exit 1
fi

echo "Scanning ${INPUT_FILE}..."

# Soft-fail: kubesec exit code is informational, always exit 0
kubesec scan "${INPUT_FILE}" | tee /tmp/kubesec-report.json || true

echo ""
echo "=== kubesec scan complete ==="
echo "  Report: /tmp/kubesec-report.json"
