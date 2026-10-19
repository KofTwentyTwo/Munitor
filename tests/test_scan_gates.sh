#!/usr/bin/env bash
# The filesystem Trivy scan and the Semgrep scan must fail when they find
# something, and Semgrep must fail when it ran no rules. Local tool stubs; no
# network needed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_SCRIPTS="$(cd "${SCRIPT_DIR}/../src/scripts" && pwd)"
WORK=$(mktemp -d)
trap 'rm -rf "${WORK}"' EXIT
PASS=0
FAIL=0
pass() { echo "PASS"; PASS=$((PASS + 1)); }
fail() { echo "FAIL"; FAIL=$((FAIL + 1)); }

mkdir -p "${WORK}/home/bin" "${WORK}/bin" "${WORK}/repo"
cat > "${WORK}/home/bin/trivy" <<'EOF'
#!/usr/bin/env bash
printf 'trivy %s\n' "$*" >> "${CALL_LOG}"
# Real trivy exits 0 on findings unless --exit-code is given.
for a in "$@"; do [[ "$a" == --exit-code ]] && exit "${SCAN_EXIT:-0}"; done
exit 0
EOF
cat > "${WORK}/bin/semgrep" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${SEMGREP_FAKE_REPORT}" > "${SEMGREP_REPORT}"
exit "${SEMGREP_FAKE_EXIT:-0}"
EOF
chmod +x "${WORK}/home/bin/trivy" "${WORK}/bin/semgrep"
export PATH="${WORK}/bin:${PATH}" HOME="${WORK}/home" CALL_LOG="${WORK}/calls"
export SEMGREP_REPORT="${WORK}/semgrep.json"
cd "${WORK}/repo"

echo "=== Scan gate tests ==="
echo -n "  TEST: trivy fs fails the job on HIGH/CRITICAL findings... "
if ! SCAN_EXIT=1 bash "${SRC_SCRIPTS}/run_trivy.sh" > "${WORK}/trivy.log" 2>&1 &&
  grep -q '^trivy fs .*--severity HIGH,CRITICAL --exit-code 1 ' "${CALL_LOG}"; then
  pass
else
  fail
fi

echo -n "  TEST: trivy fs passes a clean scan... "
if SCAN_EXIT=0 bash "${SRC_SCRIPTS}/run_trivy.sh" > "${WORK}/trivy.log" 2>&1; then
  pass
else
  fail
fi

if command -v python3 &>/dev/null; then
  CLEAN='{"results":[],"errors":[],"paths":{"scanned":["a.java","b.java"]}}'
  FOUND='{"results":[{"check_id":"java.lang.security.x","path":"a.java","start":{"line":3}}],"errors":[],"paths":{"scanned":["a.java"]}}'
  NORULES='{"results":[],"errors":[{"type":"InvalidRuleSchemaError","message":"invalid configuration file found (1 configs were invalid)"}],"paths":{"scanned":[]}}'

  echo -n "  TEST: semgrep passes a clean scan... "
  if SEMGREP_FAKE_REPORT="${CLEAN}" bash "${SRC_SCRIPTS}/run_semgrep.sh" > "${WORK}/sg.log" 2>&1 &&
    grep -q '2 files scanned, 0 findings' "${WORK}/sg.log"; then
    pass
  else
    fail
  fi

  echo -n "  TEST: semgrep fails on findings and lists them... "
  if ! SEMGREP_FAKE_REPORT="${FOUND}" SEMGREP_FAKE_EXIT=1 bash "${SRC_SCRIPTS}/run_semgrep.sh" > "${WORK}/sg.log" 2>&1 &&
    grep -q 'java.lang.security.x  a.java:3' "${WORK}/sg.log"; then
    pass
  else
    fail
  fi

  echo -n "  TEST: semgrep warn-only mode passes with findings... "
  if SEMGREP_FAIL_ON_FINDINGS=false SEMGREP_FAKE_REPORT="${FOUND}" SEMGREP_FAKE_EXIT=1 \
    bash "${SRC_SCRIPTS}/run_semgrep.sh" > "${WORK}/sg.log" 2>&1; then
    pass
  else
    fail
  fi

  echo -n "  TEST: semgrep fails when no rules ran, even with exit 0 and warn-only... "
  if ! SEMGREP_FAIL_ON_FINDINGS=false SEMGREP_FAKE_REPORT="${NORULES}" SEMGREP_FAKE_EXIT=0 \
    bash "${SRC_SCRIPTS}/run_semgrep.sh" > "${WORK}/sg.log" 2>&1 &&
    grep -q 'did not run its rules' "${WORK}/sg.log"; then
    pass
  else
    fail
  fi
else
  echo "  SKIP: semgrep gate tests need python3"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "${FAIL}" -eq 0 ]]
