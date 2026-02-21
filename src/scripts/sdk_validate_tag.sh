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

faber_header "sdk_validate_tag"

TAG="${CIRCLE_TAG:?This job requires a tag trigger}"

if [[ ! "${TAG}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: Tag '${TAG}' is not valid semver (expected v<major>.<minor>.<patch>)"
  exit 1
fi

echo "Release tag: ${TAG}"
