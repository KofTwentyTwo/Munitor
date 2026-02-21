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

faber_header "run_kube_linter"
faber_check_tool kube-linter version

SCAN_OVERLAY="${KUBE_LINTER_SCAN_OVERLAY:-production}"
CONFIG="${KUBE_LINTER_CONFIG:-}"
INPUT_FILE="/tmp/kustomize-output/${SCAN_OVERLAY}.yaml"

if [[ ! -f "${INPUT_FILE}" ]]; then
  echo "ERROR: Kustomize output not found: ${INPUT_FILE}"
  echo "Ensure kustomize-validate ran successfully and produced output for overlay '${SCAN_OVERLAY}'."
  exit 1
fi

# Build config flag
CONFIG_FLAG=""
if [[ -n "${CONFIG}" && -f "${CONFIG}" ]]; then
  CONFIG_FLAG="--config ${CONFIG}"
  echo "Using config: ${CONFIG}"
elif [[ -n "${CONFIG}" ]]; then
  echo "WARNING: Config file '${CONFIG}' not found, running without config."
fi

echo "Linting ${INPUT_FILE}..."

# Soft-fail: kube-linter findings are informational
# shellcheck disable=SC2086
kube-linter lint "${INPUT_FILE}" ${CONFIG_FLAG} --format json | tee /tmp/kube-linter-report.json || true

echo ""
echo "=== kube-linter scan complete ==="
echo "  Report: /tmp/kube-linter-report.json"
