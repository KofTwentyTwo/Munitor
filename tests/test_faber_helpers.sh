#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SRC_SCRIPTS="${PROJECT_DIR}/src/scripts"
PASS=0
FAIL=0

pass() {
  echo "PASS"
  PASS=$((PASS + 1))
}

fail() {
  local msg="${1:-}"
  echo "FAIL${msg:+ ($msg)}"
  FAIL=$((FAIL + 1))
}

# =============================================================================
# Test: faber_helpers.sh can be sourced under strict mode
# =============================================================================
echo "=== faber_helpers.sh Sourcing Tests ==="

echo -n "  TEST: sources without error under set -euo pipefail... "
if bash -c "set -euo pipefail; source '${SRC_SCRIPTS}/faber_helpers.sh'" 2>/dev/null; then
  pass
else
  fail "sourcing failed"
fi

echo -n "  TEST: double-sourcing is safe... "
if bash -c "set -euo pipefail; source '${SRC_SCRIPTS}/faber_helpers.sh'; source '${SRC_SCRIPTS}/faber_helpers.sh'" 2>/dev/null; then
  pass
else
  fail "double-source failed"
fi

# =============================================================================
# Test: faber_header output format
# =============================================================================
echo ""
echo "=== faber_header Tests ==="

HEADER_OUTPUT=$(bash -c "source '${SRC_SCRIPTS}/faber_helpers.sh'; faber_header 'test_step'" 2>&1)

echo -n "  TEST: header contains step name... "
if echo "${HEADER_OUTPUT}" | grep -q 'Munitor: test_step'; then
  pass
else
  fail "missing step name"
fi

echo -n "  TEST: header contains Date line... "
if echo "${HEADER_OUTPUT}" | grep -q 'Date:'; then
  pass
else
  fail "missing Date"
fi

echo -n "  TEST: header contains Host line... "
if echo "${HEADER_OUTPUT}" | grep -q 'Host:'; then
  pass
else
  fail "missing Host"
fi

echo -n "  TEST: header contains Dir line... "
if echo "${HEADER_OUTPUT}" | grep -q 'Dir:'; then
  pass
else
  fail "missing Dir"
fi

echo -n "  TEST: header has banner delimiters... "
DELIMITER_COUNT=$(echo "${HEADER_OUTPUT}" | grep -c '========================================' || true)
if [[ "${DELIMITER_COUNT}" -ge 2 ]]; then
  pass
else
  fail "expected 2 delimiters, got ${DELIMITER_COUNT}"
fi

# =============================================================================
# Test: faber_check_tool
# =============================================================================
echo ""
echo "=== faber_check_tool Tests ==="

echo -n "  TEST: passes for tool that exists (bash)... "
if CHECK_OUTPUT=$(bash -c "source '${SRC_SCRIPTS}/faber_helpers.sh'; faber_check_tool bash --version" 2>&1) && echo "${CHECK_OUTPUT}" | grep -q 'bash:'; then
  pass
else
  fail "should succeed for bash"
fi

echo -n "  TEST: fails for tool that does not exist... "
MISSING_OUTPUT=$(bash -c "source '${SRC_SCRIPTS}/faber_helpers.sh'; faber_check_tool __nonexistent_tool_xyz__" 2>&1 || true)
if echo "${MISSING_OUTPUT}" | grep -q 'ERROR.*__nonexistent_tool_xyz__'; then
  pass
else
  fail "should fail for missing tool"
fi

echo -n "  TEST: exit code is 1 for missing tool... "
EXIT_CODE=0
bash -c "source '${SRC_SCRIPTS}/faber_helpers.sh'; faber_check_tool __nonexistent_tool_xyz__" 2>/dev/null || EXIT_CODE=$?
if [[ "${EXIT_CODE}" -eq 1 ]]; then
  pass
else
  fail "expected exit 1, got ${EXIT_CODE}"
fi

# =============================================================================
# Test: faber_download_with_retry
# =============================================================================
echo ""
echo "=== faber_download_with_retry Tests ==="

echo -n "  TEST: function is defined after sourcing... "
if bash -c "source '${SRC_SCRIPTS}/faber_helpers.sh'; type faber_download_with_retry" &>/dev/null; then
  pass
else
  fail "function not defined"
fi

echo -n "  TEST: fails on invalid URL... "
EXIT_CODE=0
bash -c "source '${SRC_SCRIPTS}/faber_helpers.sh'; faber_download_with_retry 'https://invalid.example.test/nope' '/tmp/faber_test_dl' 1 0" 2>/dev/null || EXIT_CODE=$?
if [[ "${EXIT_CODE}" -ne 0 ]]; then
  pass
else
  fail "should fail on bad URL"
fi
rm -f /tmp/faber_test_dl 2>/dev/null || true

# =============================================================================
# Test: Script structure
# =============================================================================
echo ""
echo "=== Structure Tests ==="

echo -n "  TEST: has double-source guard... "
if grep -q '_FABER_HELPERS_LOADED' "${SRC_SCRIPTS}/faber_helpers.sh"; then
  pass
else
  fail "missing guard"
fi

echo -n "  TEST: has set guard (no set -euo pipefail to avoid caller issues)... "
if ! grep -q 'set -euo pipefail' "${SRC_SCRIPTS}/faber_helpers.sh"; then
  pass
else
  fail "helpers should not set -euo pipefail (callers handle that)"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="

if [[ ${FAIL} -gt 0 ]]; then
  exit 1
fi
