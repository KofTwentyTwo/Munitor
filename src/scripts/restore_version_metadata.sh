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

munitor_header "restore_version_metadata"

if [[ -f .munitor-version ]]; then
  echo "Restoring version vars from .munitor-version"
  cat .munitor-version
  # shellcheck disable=SC1091
  source .munitor-version
  {
    echo "export PROJECT_VERSION='${PROJECT_VERSION}'"
    echo "export DOCKER_ENV_TAG='${DOCKER_ENV_TAG}'"
  } >> "${BASH_ENV}"
else
  echo "No .munitor-version file found, skipping."
fi
