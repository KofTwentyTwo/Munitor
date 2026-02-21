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

MIN="${MIN_COVERAGE:-70}"
COVERAGE_TOOL="${FABER_COVERAGE_TOOL:-jest}"
COVERAGE_COMMAND="${FABER_COVERAGE_COMMAND:-}"
SUMMARY_FILE="coverage/coverage-summary.json"

faber_header "npm_coverage_check (min: ${MIN}%)"
faber_check_tool node --version

# Validate MIN_COVERAGE is numeric
if ! [[ "${MIN}" =~ ^[0-9]+$ ]]; then
  echo "ERROR: MIN_COVERAGE must be a whole number, got '${MIN}'."
  exit 1
fi

echo "Checking coverage threshold (minimum: ${MIN}%, tool: ${COVERAGE_TOOL})..."

# Run custom coverage report command if specified
if [[ -n "${COVERAGE_COMMAND}" ]]; then
  echo "Running coverage report command: ${COVERAGE_COMMAND}"
  bash -c "${COVERAGE_COMMAND}"
fi

if [[ ! -f "${SUMMARY_FILE}" ]]; then
  echo "ERROR: Coverage summary not found at ${SUMMARY_FILE}."
  echo "Ensure your test runner generates coverage/coverage-summary.json."
  exit 1
fi

# Extract total line coverage percentage from summary (same format for jest and nyc)
ACTUAL=$(node -e "
  const s = require('./${SUMMARY_FILE}');
  console.log(s.total.lines.pct);
")

echo "Line coverage: ${ACTUAL}%"

# Compare as integers (floor)
ACTUAL_INT=${ACTUAL%.*}
if [[ "${ACTUAL_INT}" -lt "${MIN}" ]]; then
  echo "FAIL: Coverage ${ACTUAL}% is below minimum ${MIN}%."
  exit 1
fi

echo "Coverage check passed (${ACTUAL}% >= ${MIN}%)."
