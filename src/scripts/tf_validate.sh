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

ENV="${TF_ENV:-production}"
BASE_PATH="${TF_BASE_PATH:-terraform/live}"

munitor_header "tf_validate (${ENV})"
munitor_check_tool terragrunt --version

# Validate directory exists before cd
if [[ ! -d "${BASE_PATH}/${ENV}" ]]; then
  echo "ERROR: Directory '${BASE_PATH}/${ENV}' does not exist."
  echo "  Available directories in ${BASE_PATH}/:"
  ls -1 "${BASE_PATH}/" 2>/dev/null || echo "  (parent directory not found)"
  exit 1
fi

cd "${BASE_PATH}/${ENV}"

echo "Initializing Terragrunt for ${ENV}..."
terragrunt init -backend=false

echo "Validating Terraform configuration for ${ENV}..."
terragrunt validate

echo "Validation passed for ${ENV}"
