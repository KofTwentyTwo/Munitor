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

munitor_header "run_semgrep"

CONFIG="${SEMGREP_CONFIG:-auto}"
FAIL_ON_FINDINGS="${SEMGREP_FAIL_ON_FINDINGS:-true}"
REPORT="${SEMGREP_REPORT:-/tmp/semgrep-results.json}"

echo "Running Semgrep SAST scan (config: ${CONFIG}, fail_on_findings: ${FAIL_ON_FINDINGS})..."

EXIT_CODE=0
semgrep ci \
  --config "${CONFIG}" \
  --json \
  --output "${REPORT}" || EXIT_CODE=$?

# Summarise the report, and fail a scan that ran no rules or scanned no files:
# semgrep exits 0 when the downloaded rules fail to parse (an outdated semgrep),
# which used to pass this job without scanning anything.
python3 - "${REPORT}" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
scanned = len(report.get("paths", {}).get("scanned", []))
results = report.get("results", [])
errors = report.get("errors", [])
rule_errors = [e for e in errors if "rule" in str(e.get("type", "")).lower()
               or "config" in str(e.get("message", "")).lower()]
print(f"Semgrep: {scanned} files scanned, {len(results)} findings, {len(errors)} errors.")
for r in results[:50]:
    print(f"  {r.get('check_id')}  {r.get('path')}:{r.get('start', {}).get('line')}")
if scanned == 0 or rule_errors:
    for e in rule_errors[:5]:
        print(f"  error: {str(e.get('message', e))[:300]}")
    print("ERROR: Semgrep did not run its rules (no files scanned or invalid rule configuration).")
    sys.exit(2)
PY

if [[ "${EXIT_CODE}" -ne 0 ]]; then
  if [[ "${FAIL_ON_FINDINGS}" == "true" ]]; then
    echo "ERROR: Semgrep found issues."
    echo "Review the report at: ${REPORT}"
    exit "${EXIT_CODE}"
  fi
  echo "WARNING: Semgrep found issues (warn-only mode, not failing build)."
  echo "Review the report at: ${REPORT}"
fi

echo "Semgrep scan completed."
