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

BASE_PATH="${TF_BASE_PATH:?TF_BASE_PATH not set}"
ENVIRONMENTS="${TF_ENVIRONMENTS:?TF_ENVIRONMENTS not set}"

munitor_header "tf_validate_environments"
munitor_check_tool terragrunt --version

for env in ${ENVIRONMENTS}; do
  echo "Validating environment: ${env}"
  if [[ ! -d "${BASE_PATH}/${env}" ]]; then
    echo "ERROR: Directory '${BASE_PATH}/${env}' does not exist."
    echo "  Available directories in ${BASE_PATH}/:"
    ls -1 "${BASE_PATH}/" 2>/dev/null || echo "  (parent directory not found)"
    exit 1
  fi
  cd "${BASE_PATH}/${env}"
  terragrunt init -backend=false
  terragrunt validate
  cd - > /dev/null
done

echo "All environments validated"
