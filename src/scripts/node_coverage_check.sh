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
SUMMARY_PATH="${MUNITOR_COVERAGE_SUMMARY_PATH:-coverage/coverage-summary.json}"

munitor_header "node_coverage_check (min: ${MIN}%)"
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

# Resolve summary file(s) - supports glob patterns for monorepos
# shellcheck disable=SC2206
SUMMARY_FILES=( ${SUMMARY_PATH} )

if [[ ${#SUMMARY_FILES[@]} -eq 0 ]] || [[ ! -f "${SUMMARY_FILES[0]}" ]]; then
  echo "ERROR: Coverage summary not found at ${SUMMARY_PATH}."
  echo ""
  echo "  Ensure your test runner generates coverage-summary.json."
  echo "  For monorepos, set test.coverage.summary_path in .munitor.yml:"
  echo "    test:"
  echo "      coverage:"
  echo "        summary_path: \"packages/*/coverage/coverage-summary.json\""
  exit 1
fi

if [[ ${#SUMMARY_FILES[@]} -eq 1 ]]; then
  # Single file - use directly
  SUMMARY_FILE="${SUMMARY_FILES[0]}"
  echo "Using coverage summary: ${SUMMARY_FILE}"

  ACTUAL=$(node -e "
    const s = require('./${SUMMARY_FILE}');
    console.log(s.total.lines.pct);
  ")
else
  # Multiple files (monorepo) - compute weighted average
  echo "Found ${#SUMMARY_FILES[@]} coverage summaries (monorepo mode):"
  for f in "${SUMMARY_FILES[@]}"; do
    echo "  - ${f}"
  done

  ACTUAL=$(node -e "
    const files = process.argv.slice(1);
    let totalCovered = 0, totalTotal = 0;
    for (const f of files) {
      const s = require('./' + f);
      totalCovered += s.total.lines.covered;
      totalTotal += s.total.lines.total;
    }
    console.log(totalTotal > 0 ? ((totalCovered / totalTotal) * 100).toFixed(2) : '0');
  " "${SUMMARY_FILES[@]}")
fi

echo "Line coverage: ${ACTUAL}%"

# Compare as integers (floor)
ACTUAL_INT=${ACTUAL%.*}
if [[ "${ACTUAL_INT}" -lt "${MIN}" ]]; then
  echo "FAIL: Coverage ${ACTUAL}% is below minimum ${MIN}%."
  exit 1
fi

echo "Coverage check passed (${ACTUAL}% >= ${MIN}%)."
