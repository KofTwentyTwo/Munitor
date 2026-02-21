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

munitor_header "run_e2e_playwright"

TEST_DIR="${E2E_TEST_DIR:-e2e}"

echo "Running Playwright E2E tests from ${TEST_DIR}..."

# Install Playwright browsers if needed
if [[ -f "package.json" ]]; then
  npm ci
  npx playwright install --with-deps chromium
fi

# Run tests with JUnit reporter for CircleCI
npx playwright test \
  --config="${TEST_DIR}/playwright.config.ts" \
  --reporter=junit \
  --output=e2e-results || {
    EXIT_CODE=$?
    echo "E2E tests failed. See artifacts for traces and screenshots."
    exit "${EXIT_CODE}"
  }

echo "E2E tests passed."
