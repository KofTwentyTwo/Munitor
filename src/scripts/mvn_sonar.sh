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

munitor_header "mvn_sonar"
munitor_check_tool mvn --version

PROJECT_KEY="${SONAR_PROJECT_KEY:?SONAR_PROJECT_KEY not set}"
ORG="${SONAR_ORG:-KofTwentyTwo}"
TOKEN="${!SONAR_TOKEN_VAR:-}"

if [[ -z "${TOKEN}" ]]; then
  echo "ERROR: SonarCloud token not found in \$${SONAR_TOKEN_VAR}"
  exit 1
fi

# SonarCloud's SCM Publisher uses JGit which cannot lazy-fetch objects.
# Ensure ALL git objects are present regardless of clone type.
echo "Ensuring full git history for SonarCloud SCM analysis..."
echo "Git clone diagnostics:"
echo "  Shallow: $(git rev-parse --is-shallow-repository 2>/dev/null || echo unknown)"
echo "  Partial filter: $(git config remote.origin.partialclonefilter 2>/dev/null || echo none)"
echo "  Object count: $(git count-objects 2>/dev/null || echo unknown)"

# Handle shallow clones
if git rev-parse --is-shallow-repository 2>/dev/null | grep -q true; then
  echo "  Shallow clone detected -- unshallowing..."
  git fetch --unshallow origin 2>/dev/null || true
fi

# Handle partial/blobless clones (CircleCI machine executor default).
# JGit cannot lazy-fetch missing blobs, so we must fetch everything upfront.
if git config remote.origin.partialclonefilter &>/dev/null; then
  echo "  Partial clone detected (filter: $(git config remote.origin.partialclonefilter)) -- fetching all objects..."
  git config --unset remote.origin.partialclonefilter 2>/dev/null || true
  git config remote.origin.promisor false 2>/dev/null || true
  if git fetch --refetch origin 2>/dev/null; then
    echo "  Refetch complete."
  else
    echo "  --refetch not supported (git < 2.38), performing manual fetch..."
    git fetch origin '+refs/heads/*:refs/remotes/origin/*' 2>/dev/null || true
  fi
fi

echo "Running SonarCloud analysis (project: ${PROJECT_KEY})..."

mvn sonar:sonar \
  -Dsonar.projectKey="${PROJECT_KEY}" \
  -Dsonar.organization="${ORG}" \
  -Dsonar.host.url=https://sonarcloud.io \
  -Dsonar.token="${TOKEN}" \
  --batch-mode

echo "SonarCloud analysis complete."
