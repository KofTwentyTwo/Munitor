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

VERSION="${PROJECT_VERSION:?PROJECT_VERSION not set -- run export_version_vars first}"

munitor_header "mvn_set_version (${VERSION})"
munitor_check_tool mvn --version

mvn versions:set \
  -DnewVersion="${VERSION}" \
  -DgenerateBackupPoms=false \
  --batch-mode \
  --quiet

echo "Maven version set to ${VERSION}"
