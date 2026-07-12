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

munitor_header "node_sonar"

PROJECT_KEY="${SONAR_PROJECT_KEY:?SONAR_PROJECT_KEY not set}"
ORG="${SONAR_ORG:-KofTwentyTwo}"
TOKEN="${!SONAR_TOKEN_VAR:-}"

if [[ -z "${TOKEN}" ]]; then
  echo "ERROR: SonarCloud token not found in \$${SONAR_TOKEN_VAR}"
  exit 1
fi

# Install sonar-scanner CLI (includes bundled JRE)
SONAR_SCANNER_VERSION="${SONAR_SCANNER_VERSION:-6.2.1.4610}"

if ! command -v sonar-scanner &>/dev/null; then
  echo "Installing sonar-scanner ${SONAR_SCANNER_VERSION}..."
  SCANNER_DIR="${HOME}/.sonar/scanner"
  mkdir -p "${SCANNER_DIR}"
  DOWNLOAD_URL="https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}-linux-x64.zip"
  munitor_download_with_retry "${DOWNLOAD_URL}" /tmp/sonar-scanner.zip
  unzip -qo /tmp/sonar-scanner.zip -d "${SCANNER_DIR}"
  rm -f /tmp/sonar-scanner.zip
  export PATH="${SCANNER_DIR}/sonar-scanner-${SONAR_SCANNER_VERSION}-linux-x64/bin:${PATH}"
fi

munitor_check_tool sonar-scanner --version

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

# Build scanner args
SCANNER_ARGS=(
  "-Dsonar.projectKey=${PROJECT_KEY}"
  "-Dsonar.organization=${ORG}"
  "-Dsonar.host.url=https://sonarcloud.io"
  "-Dsonar.token=${TOKEN}"
  "-Dsonar.sources=src"
)

# Add lcov coverage report if it exists
if [[ -f "coverage/lcov.info" ]]; then
  echo "  Found coverage/lcov.info -- including in analysis."
  SCANNER_ARGS+=("-Dsonar.javascript.lcov.reportPaths=coverage/lcov.info")
fi

# Add TypeScript config if present
if [[ -f "tsconfig.json" ]]; then
  echo "  Found tsconfig.json -- TypeScript project detected."
fi

sonar-scanner "${SCANNER_ARGS[@]}"

echo "SonarCloud analysis complete."
