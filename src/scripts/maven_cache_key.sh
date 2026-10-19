#!/usr/bin/env bash
set -euo pipefail

MUNITOR_HELPERS="${MUNITOR_HELPERS:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/munitor_helpers.sh}"
# shellcheck source=munitor_helpers.sh
if [[ -f "${MUNITOR_HELPERS}" ]]; then
  source "${MUNITOR_HELPERS}"
elif ! type munitor_header &>/dev/null; then
  munitor_header() { echo "=== Munitor: ${1:-unknown} ==="; }
fi
munitor_header "maven_cache_key"

# Hash the checked-out dependency definitions, not release-version rewrites.
# The same index travels with the workspace to downstream Maven jobs.
git ls-files -s -- pom.xml '**/pom.xml' '.mvn/*' > .munitor-maven-cache-key
if [[ ! -s .munitor-maven-cache-key ]]; then
  echo "ERROR: Maven cache requires tracked dependency definitions." >&2
  exit 1
fi
