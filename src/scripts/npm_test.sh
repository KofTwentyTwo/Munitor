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

faber_header "npm_test"

# Prevent interactive prompts from apt/dpkg when test commands install system deps
export DEBIAN_FRONTEND=noninteractive

mkdir -p reports/junit

TEST_COMMANDS_JSON="${FABER_TEST_COMMANDS_JSON:-}"

if [[ -n "${TEST_COMMANDS_JSON}" && "${TEST_COMMANDS_JSON}" != "[]" && "${TEST_COMMANDS_JSON}" != "null" ]]; then
  faber_check_tool jq --version
  # Custom test commands from .faber.yml
  CMD_COUNT=$(echo "${TEST_COMMANDS_JSON}" | jq 'length')
  echo "Running ${CMD_COUNT} custom test command(s)..."

  for i in $(seq 0 $((CMD_COUNT - 1))); do
    CMD=$(echo "${TEST_COMMANDS_JSON}" | jq -r ".[$i]")
    echo "  Running: ${CMD}"
    bash -c "${CMD}"
  done

  echo "Custom test commands complete."
else
  # Default: Jest with coverage and JUnit reporter
  if ! npx jest --version &>/dev/null; then
    echo ""
    echo "ERROR: Jest is not installed and no custom test commands are configured."
    echo ""
    echo "  Faber defaults to 'npx jest' but this project doesn't have Jest."
    echo "  Add custom test commands to your .faber.yml:"
    echo ""
    echo "    test:"
    echo "      commands:"
    echo "        - \"npm test\""
    echo ""
    echo "  Or install Jest: npm install --save-dev jest"
    echo ""
    exit 1
  fi

  echo "Running Jest tests..."

  export JEST_JUNIT_OUTPUT_DIR="reports/junit"
  export JEST_JUNIT_OUTPUT_NAME="results.xml"

  npx jest \
    --ci \
    --forceExit \
    --coverage \
    --coverageReporters=json-summary \
    --coverageReporters=lcov \
    --reporters=default \
    --reporters=jest-junit

  echo "Jest tests complete."
fi
