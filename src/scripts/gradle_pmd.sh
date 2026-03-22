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

munitor_header "gradle_pmd"

if [[ ! -f "./gradlew" ]]; then
  echo "ERROR: ./gradlew not found. Ensure the Gradle wrapper is present."
  exit 1
fi
if [[ ! -x "./gradlew" ]]; then
  chmod +x ./gradlew
fi

# Detect if pmd plugin is applied
if ! ./gradlew tasks --all 2>/dev/null | grep -q "pmdMain"; then
  echo "PMD plugin not applied, skipping."
  exit 0
fi

echo "Running PMD..."

./gradlew pmdMain --no-daemon --console=plain

echo "PMD passed."
