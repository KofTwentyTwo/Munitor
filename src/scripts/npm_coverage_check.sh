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

MIN="${MIN_COVERAGE:-70}"
COVERAGE_TOOL="${MUNITOR_COVERAGE_TOOL:-jest}"
COVERAGE_COMMAND="${MUNITOR_COVERAGE_COMMAND:-}"
SUMMARY_FILE="coverage/coverage-summary.json"

munitor_header "npm_coverage_check (min: ${MIN}%)"
munitor_check_tool node --version

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
