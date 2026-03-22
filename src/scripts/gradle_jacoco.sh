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

MIN="${MIN_INSTRUCTION:-70}"

munitor_header "gradle_jacoco (min: ${MIN}%)"

# Validate MIN_INSTRUCTION is numeric
if ! [[ "${MIN}" =~ ^[0-9]+$ ]]; then
  echo "ERROR: MIN_INSTRUCTION must be a whole number, got '${MIN}'."
  exit 1
fi

if [[ ! -f "./gradlew" ]]; then
  echo "ERROR: ./gradlew not found. Ensure the Gradle wrapper is present."
  exit 1
fi
if [[ ! -x "./gradlew" ]]; then
  chmod +x ./gradlew
fi

echo "Generating JaCoCo report..."

./gradlew jacocoTestReport --no-daemon --console=plain

# Show what JaCoCo produced for diagnostics
echo ""
echo "Searching for JaCoCo reports..."
find . -path "*/build/reports/jacoco" -type d 2>/dev/null | while read -r dir; do
  echo "  Found: ${dir}/"
  for f in "${dir}"/test/*; do
    [[ -e "${f}" ]] && echo "    $(basename "${f}")"
  done
done

# Find ALL CSV report files across all subprojects
CSV_FILES=$(find . -path "*/build/reports/jacoco/test/jacocoTestReport.csv" -type f)

if [[ -z "${CSV_FILES}" ]]; then
  echo ""
  echo "ERROR: No JaCoCo CSV reports found."
  echo ""
  echo "Gradle does not generate CSV reports by default. Add this to your"
  echo "build.gradle.kts (in each module or via allprojects/subprojects):"
  echo ""
  echo '  tasks.jacocoTestReport {'
  echo '    dependsOn(tasks.test)'
  echo '    reports {'
  echo '      csv.required.set(true)'
  echo '    }'
  echo '  }'
  exit 1
fi

echo ""
echo "Found CSV reports:"
echo "${CSV_FILES}" | sed 's/^/  /'

# Parse CSV: sum INSTRUCTION_MISSED (col 4) and INSTRUCTION_COVERED (col 5) across ALL files
# CSV header: GROUP,PACKAGE,CLASS,INSTRUCTION_MISSED,INSTRUCTION_COVERED,...
read -r MISSED COVERED <<< "$(awk -F',' 'NR>1 { m+=$4; c+=$5 } END { print m, c }' ${CSV_FILES})"

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
