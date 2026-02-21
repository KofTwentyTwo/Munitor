#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

# Mock BASH_ENV to capture exports
BASH_ENV=$(mktemp)
export BASH_ENV

run_version_test() {
  local name="$1"
  local branch="$2"
  local major="$3"
  local minor="$4"
  local patch="$5"
  local prerelease_number="$6"
  local sha="$7"
  local expected="$8"

  echo -n "  TEST: ${name}... "

  # Clear BASH_ENV
  : > "${BASH_ENV}"

  # Set GitVersion vars
  export GITVERSION_MAJOR="${major}"
  export GITVERSION_MINOR="${minor}"
  export GITVERSION_PATCH="${patch}"
  export GITVERSION_BRANCH_NAME="${branch}"
  export GITVERSION_SHA="${sha}"
  export GITVERSION_PRERELEASE_NUMBER="${prerelease_number}"

  # Run the script
  local output
  output=$(bash "$(dirname "$0")/../src/scripts/export_version_vars.sh" 2>&1) || {
    echo "FAIL (script error)"
    echo "    Output: ${output}"
    FAIL=$((FAIL + 1))
    return
  }

  # Extract PROJECT_VERSION from BASH_ENV
  local actual
  actual=$(grep 'PROJECT_VERSION' "${BASH_ENV}" | sed "s/.*='//;s/'$//")

  if [[ "${actual}" == "${expected}" ]]; then
    echo "PASS"
    PASS=$((PASS + 1))
  else
    echo "FAIL"
    echo "    Expected: ${expected}"
    echo "    Actual:   ${actual}"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Version Mapping Tests ==="

# main branch: clean semver
run_version_test "main branch" \
  "main" "1" "2" "0" "0" "abc1234" \
  "1.2.0"

# develop branch: SNAPSHOT with SHA for unique tags
run_version_test "develop branch" \
  "develop" "1" "2" "0" "3" "def5678" \
  "1.2.0-SNAPSHOT.def5678"

# feature branch: name + sha + SNAPSHOT
run_version_test "feature branch" \
  "feature/my-feature" "1" "2" "0" "1" "abc1234" \
  "1.2.0-my-feature-abc1234-SNAPSHOT"

# feature branch with special chars
run_version_test "feature branch (special chars)" \
  "feature/MH-123_Add_Login" "2" "0" "0" "1" "fff9999" \
  "2.0.0-mh-123-add-login-fff9999-SNAPSHOT"

# release branch: RC.N
run_version_test "release branch" \
  "release/1.2.0" "1" "2" "0" "2" "bbb2222" \
  "1.2.0-RC.2"

# staging branch: version with staging qualifier
run_version_test "staging branch" \
  "staging" "1" "2" "0" "0" "def5678" \
  "1.2.0-staging.def5678"

# hotfix branch: clean patch
run_version_test "hotfix branch" \
  "hotfix/fix-login" "1" "2" "1" "1" "ccc3333" \
  "1.2.1"

# unknown branch: falls back to SNAPSHOT with SHA
run_version_test "unknown branch (fallback)" \
  "bugfix/something" "1" "0" "0" "0" "eee4444" \
  "1.0.0-SNAPSHOT.eee4444"

# --------------------------------------------------------------------------
# DOCKER_ENV_TAG tests
# --------------------------------------------------------------------------
echo ""
echo "=== Docker Env Tag Tests ==="

run_env_tag_test() {
  local name="$1"
  local branch="$2"
  local expected_tag="$3"

  echo -n "  TEST: ${name}... "

  : > "${BASH_ENV}"

  export GITVERSION_MAJOR="1"
  export GITVERSION_MINOR="0"
  export GITVERSION_PATCH="0"
  export GITVERSION_BRANCH_NAME="${branch}"
  export GITVERSION_SHA="abc1234"
  export GITVERSION_PRERELEASE_NUMBER="0"

  local output
  output=$(bash "$(dirname "$0")/../src/scripts/export_version_vars.sh" 2>&1) || {
    echo "FAIL (script error)"
    echo "    Output: ${output}"
    FAIL=$((FAIL + 1))
    return
  }

  local actual
  actual=$(grep 'DOCKER_ENV_TAG' "${BASH_ENV}" | sed "s/.*='//;s/'$//")

  if [[ "${actual}" == "${expected_tag}" ]]; then
    echo "PASS"
    PASS=$((PASS + 1))
  else
    echo "FAIL"
    echo "    Expected: '${expected_tag}'"
    echo "    Actual:   '${actual}'"
    FAIL=$((FAIL + 1))
  fi
}

run_env_tag_test "main env tag is empty" "main" ""
run_env_tag_test "develop env tag is develop" "develop" "develop"
run_env_tag_test "staging env tag is staging" "staging" "staging"
run_env_tag_test "feature env tag is empty" "feature/foo" ""
run_env_tag_test "release env tag is empty" "release/1.0.0" ""
run_env_tag_test "hotfix env tag is empty" "hotfix/bar" ""

rm -f "${BASH_ENV}"

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="

if [[ ${FAIL} -gt 0 ]]; then
  exit 1
fi
