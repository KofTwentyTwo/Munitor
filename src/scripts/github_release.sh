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

munitor_header "github_release"

# Validate required environment
if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "ERROR: GITHUB_TOKEN environment variable is not set."
  echo "Add a 'github' context with GITHUB_TOKEN to your CircleCI project."
  exit 1
fi

# PROJECT_VERSION is set by GitVersion in the build job and restored via .munitor-version
VERSION="${PROJECT_VERSION:?PROJECT_VERSION is not set. Ensure the build job ran and version metadata was persisted.}"
TAG="v${VERSION}"

echo "Version: ${VERSION}"
echo "Tag: ${TAG}"

munitor_check_tool gh --version

# Detect pre-release versions (RC, alpha, beta, SNAPSHOT)
if [[ "${VERSION}" =~ -(RC|alpha|beta|SNAPSHOT) ]]; then
  PRERELEASE_FLAG="--prerelease"
  TARGET="${CIRCLE_BRANCH:-main}"
else
  PRERELEASE_FLAG=""
  TARGET="main"
fi

echo "Target: ${TARGET}"
echo "Pre-release: ${PRERELEASE_FLAG:-no}"

# Create tag + GitHub Release via API (skip if already exists)
# Uses gh release create which handles both tag and release in one call,
# bypassing CircleCI's read-only SSH deploy key entirely.
if gh release view "${TAG}" >/dev/null 2>&1; then
  echo "Release ${TAG} already exists, skipping."
else
  echo "Creating GitHub Release ${TAG}..."
  gh release create "${TAG}" \
    --generate-notes \
    --target "${TARGET}" \
    --title "Release ${VERSION}" \
    ${PRERELEASE_FLAG}
  echo "GitHub Release ${TAG} created."
fi

echo "github_release completed"
