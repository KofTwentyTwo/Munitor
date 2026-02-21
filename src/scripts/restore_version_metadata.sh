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

faber_header "restore_version_metadata"

if [[ -f .faber-version ]]; then
  echo "Restoring version vars from .faber-version"
  cat .faber-version
  # shellcheck disable=SC1091
  source .faber-version
  {
    echo "export PROJECT_VERSION='${PROJECT_VERSION}'"
    echo "export DOCKER_ENV_TAG='${DOCKER_ENV_TAG}'"
  } >> "${BASH_ENV}"
else
  echo "No .faber-version file found, skipping."
fi
