#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SCRIPT="${PROJECT_DIR}/src/scripts/validate_branch.sh"
PASS=0
FAIL=0

test_branch() {
  local name="$1"
  local ref="$2"
  local should_pass="$3"

  echo -n "  TEST: ${name}... "

  local output
  local exit_code=0
  output=$(CIRCLE_BRANCH="${ref}" CIRCLE_TAG="" bash "${SCRIPT}" 2>&1) || exit_code=$?

  if [[ "${should_pass}" == "true" && ${exit_code} -eq 0 ]]; then
    echo "PASS"
    PASS=$((PASS + 1))
  elif [[ "${should_pass}" == "false" && ${exit_code} -ne 0 ]]; then
    echo "PASS (correctly rejected)"
    PASS=$((PASS + 1))
  else
    echo "FAIL (expected ${should_pass}, got exit ${exit_code})"
    FAIL=$((FAIL + 1))
  fi
}

test_tag() {
  local name="$1"
  local ref="$2"
  local should_pass="$3"

  echo -n "  TEST: ${name}... "

  local output
  local exit_code=0
  output=$(CIRCLE_BRANCH="" CIRCLE_TAG="${ref}" bash "${SCRIPT}" 2>&1) || exit_code=$?

  if [[ "${should_pass}" == "true" && ${exit_code} -eq 0 ]]; then
    echo "PASS"
    PASS=$((PASS + 1))
  elif [[ "${should_pass}" == "false" && ${exit_code} -ne 0 ]]; then
    echo "PASS (correctly rejected)"
    PASS=$((PASS + 1))
  else
    echo "FAIL (expected ${should_pass}, got exit ${exit_code})"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Branch Validation Tests ==="

# Valid branches
test_branch "main" "main" "true"
test_branch "develop" "develop" "true"
test_branch "staging" "staging" "true"
test_branch "feature/my-feature" "feature/my-feature" "true"
test_branch "feature/MH-123-add-login" "feature/MH-123-add-login" "true"
test_branch "release/1.2.0" "release/1.2.0" "true"
test_branch "hotfix/fix-crash" "hotfix/fix-crash" "true"
test_branch "dependabot/maven/org.postgresql-42.7.10" "dependabot/maven/org.postgresql-42.7.10" "true"
test_branch "dependabot/npm_and_yarn/express-4.18.3" "dependabot/npm_and_yarn/express-4.18.3" "true"
test_branch "dependabot/github_actions/actions/checkout-4" "dependabot/github_actions/actions/checkout-4" "true"

# Valid tags
test_tag "v1.0.0 tag" "v1.0.0" "true"
test_tag "v2.3.1 tag" "v2.3.1" "true"
test_tag "v0.1.0-rc.1 tag" "v0.1.0-rc.1" "true"

# Invalid branches
test_branch "master" "master" "false"
test_branch "feat/something" "feat/something" "false"
test_branch "bugfix/something" "bugfix/something" "false"
test_branch "random-branch" "random-branch" "false"
test_branch "my-feature" "my-feature" "false"
test_branch "feature" "feature" "false"
test_branch "uat" "uat" "false"
test_branch "uat/something" "uat/something" "false"
test_branch "staging-env" "staging-env" "false"

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="

if [[ ${FAIL} -gt 0 ]]; then
  exit 1
fi
