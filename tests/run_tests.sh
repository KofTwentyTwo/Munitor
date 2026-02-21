#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOTAL_PASS=0
TOTAL_FAIL=0
FAILED_TESTS=()

echo "========================================"
echo "  Faber Orb Test Suite"
echo "========================================"
echo ""

for test_file in "${SCRIPT_DIR}"/test_*.sh; do
  if [[ ! -f "${test_file}" ]]; then
    continue
  fi

  TEST_NAME=$(basename "${test_file}")
  echo "--- ${TEST_NAME} ---"

  if bash "${test_file}"; then
    TOTAL_PASS=$((TOTAL_PASS + 1))
  else
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
    FAILED_TESTS+=("${TEST_NAME}")
  fi

  echo ""
done

echo "========================================"
echo "  Suite Results: ${TOTAL_PASS} suites passed, ${TOTAL_FAIL} failed"
echo "========================================"

if [[ ${TOTAL_FAIL} -gt 0 ]]; then
  echo "Failed test suites:"
  for t in "${FAILED_TESTS[@]}"; do
    echo "  - ${t}"
  done
  exit 1
fi
