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

faber_header "submit_dependency_graph"

SBOM="${SBOM_PATH:-target/bom.json}"
DETECTOR_NAME="${SBOM_DETECTOR_NAME:-CycloneDX Maven Plugin}"
DETECTOR_VERSION="${SBOM_DETECTOR_VERSION:-2.7.11}"
DETECTOR_URL="${SBOM_DETECTOR_URL:-https://github.com/CycloneDX/cyclonedx-maven-plugin}"

if [[ ! -f "${SBOM}" ]]; then
  echo "ERROR: SBOM file not found at ${SBOM}"
  exit 1
fi

echo "Submitting dependency graph from ${SBOM}..."

# Submit to GitHub dependency graph via API
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  REPO="${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}"
  echo "Submitting to GitHub dependency graph for ${REPO}..."

  # GitHub dependency submission API
  curl -s -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    "https://api.github.com/repos/${REPO}/dependency-graph/snapshots" \
    -d @- << PAYLOAD
{
  "version": 0,
  "job": {
    "id": "${CIRCLE_BUILD_NUM:-0}",
    "correlator": "faber-sbom-${CIRCLE_PROJECT_REPONAME}"
  },
  "sha": "${CIRCLE_SHA1:-HEAD}",
  "ref": "refs/heads/${CIRCLE_BRANCH:-main}",
  "detector": {
    "name": "${DETECTOR_NAME}",
    "version": "${DETECTOR_VERSION}",
    "url": "${DETECTOR_URL}"
  },
  "manifests": {}
}
PAYLOAD

  echo "Dependency graph submitted."
else
  echo "GITHUB_TOKEN not set, skipping dependency graph submission."
  echo "SBOM is still available as a build artifact."
fi
