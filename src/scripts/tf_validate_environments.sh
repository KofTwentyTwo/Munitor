#!/usr/bin/env bash
set -euo pipefail

# Source shared helpers
FABER_HELPERS="${FABER_HELPERS:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/faber_helpers.sh}"
# shellcheck source=faber_helpers.sh
if [[ -f "${FABER_HELPERS}" ]]; then source "${FABER_HELPERS}"
elif ! type faber_header &>/dev/null; then
  faber_header() { echo "=== Faber: ${1:-unknown} ==="; }
  faber_check_tool() { command -v "$1" &>/dev/null || { echo "ERROR: $1 not found"; exit 1; }; }
  faber_download_with_retry() { curl -fsSL --retry 3 "$1" -o "$2"; }
fi

BASE_PATH="${TF_BASE_PATH:?TF_BASE_PATH not set}"
ENVIRONMENTS="${TF_ENVIRONMENTS:?TF_ENVIRONMENTS not set}"

faber_header "tf_validate_environments"
faber_check_tool terragrunt --version

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
