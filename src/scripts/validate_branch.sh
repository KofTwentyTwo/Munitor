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

munitor_header "validate_branch"

# Determine what we're validating -- branch or tag
REF="${CIRCLE_TAG:-${CIRCLE_BRANCH:-}}"

if [[ -z "${REF}" ]]; then
  echo "ERROR: Neither CIRCLE_BRANCH nor CIRCLE_TAG is set."
  exit 1
fi

# GitFlow + environment branch allowed patterns
VALID_PATTERNS=(
  "^main$"
  "^develop$"
  "^staging$"
  "^feature/.+"
  "^release/.+"
  "^hotfix/.+"
  "^dependabot/.+"
  "^v[0-9]+\.[0-9]+\.[0-9]+.*"  # semver tags
)

for pattern in "${VALID_PATTERNS[@]}"; do
  if [[ "${REF}" =~ ${pattern} ]]; then
    echo "Branch/tag '${REF}' matches GitFlow pattern: ${pattern}"
    exit 0
  fi
done

echo "ERROR: Branch/tag '${REF}' does not conform to GitFlow naming conventions."
echo ""
echo "Allowed patterns:"
echo "  main              -- production branch"
echo "  develop           -- integration branch"
echo "  staging           -- staging environment branch"
echo "  feature/<name>    -- feature branches"
echo "  release/<version> -- release branches"
echo "  hotfix/<name>     -- hotfix branches"
echo "  dependabot/<type> -- dependabot dependency updates"
echo "  v<semver>         -- release tags (e.g., v1.2.3)"
echo ""
echo "Rename your branch to match one of the above patterns."
exit 1
