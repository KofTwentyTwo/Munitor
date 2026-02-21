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

munitor_header "npm_auth"

echo "Configuring private npm registry authentication..."

if [[ -z "${NPM_TOKEN:-}" ]]; then
  echo "ERROR: NPM_TOKEN environment variable is not set."
  echo "Add NPM_TOKEN to your CircleCI context or project environment variables."
  exit 1
fi

# Auth token for registry.npmjs.org
cat >> .npmrc <<EOF
//registry.npmjs.org/:_authToken=${NPM_TOKEN}
EOF

# Always include the org default scope
SCOPES=("${NPM_DEFAULT_SCOPE:-@koftwentytwo}")

# Parse additional scopes from MUNITOR_NPM_SCOPES (JSON array string)
if [[ -n "${NPM_SCOPES:-}" ]]; then
  while IFS= read -r scope; do
    # Skip if already in the list
    if [[ "${scope}" != "${SCOPES[0]}" && -n "${scope}" ]]; then
      SCOPES+=("${scope}")
    fi
  done < <(echo "${NPM_SCOPES}" | jq -r '.[]' 2>/dev/null || true)
fi

# Write .npmrc entry for each scope
for scope in "${SCOPES[@]}"; do
  echo "${scope}:registry=https://registry.npmjs.org/" >> .npmrc
  echo "Configured scope: ${scope}"
done

echo "Private npm registry configured for ${#SCOPES[@]} scope(s)."
