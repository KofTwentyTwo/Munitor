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

MIN="${MIN_INSTRUCTION:-70}"

faber_header "mvn_jacoco (min: ${MIN}%)"
faber_check_tool mvn --version

# Validate MIN_INSTRUCTION is numeric
if ! [[ "${MIN}" =~ ^[0-9]+$ ]]; then
  echo "ERROR: MIN_INSTRUCTION must be a whole number, got '${MIN}'."
  exit 1
fi

echo "Generating JaCoCo report..."

mvn jacoco:report --batch-mode --fail-at-end

CSV_FILE="target/site/jacoco/jacoco.csv"

if [[ ! -f "${CSV_FILE}" ]]; then
  echo "ERROR: JaCoCo CSV report not found at ${CSV_FILE}."
  echo "Ensure jacoco-maven-plugin is configured in pom.xml."
  exit 1
fi

# Parse CSV: sum INSTRUCTION_MISSED (col 4) and INSTRUCTION_COVERED (col 5)
# CSV header: GROUP,PACKAGE,CLASS,INSTRUCTION_MISSED,INSTRUCTION_COVERED,...
read -r MISSED COVERED <<< "$(awk -F',' 'NR>1 { m+=$4; c+=$5 } END { print m, c }' "${CSV_FILE}")"

TOTAL=$((MISSED + COVERED))

if [[ "${TOTAL}" -eq 0 ]]; then
  echo "WARNING: No instruction data found in JaCoCo report (0 instructions total)."
  echo "JaCoCo coverage: N/A (no code to measure)"
  exit 0
fi

# Calculate percentage (integer arithmetic, truncated)
PCT=$((COVERED * 100 / TOTAL))

echo "JaCoCo coverage: ${PCT}% (${COVERED}/${TOTAL} instructions covered, minimum: ${MIN}%)"

if [[ "${PCT}" -lt "${MIN}" ]]; then
  echo "FAILED: Coverage ${PCT}% is below minimum threshold of ${MIN}%."
  exit 1
fi

echo "JaCoCo coverage passed (>= ${MIN}%)."
