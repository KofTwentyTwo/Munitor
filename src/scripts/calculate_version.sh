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

faber_header "calculate_version"

GITVERSION_TAG="${GITVERSION_TAG:-5.12.0}"

# Faber manages GitVersion config -- always write the standard SDLC-compliant config
if [[ -f "GitVersion.yml" ]]; then
  echo "WARNING: Repo contains GitVersion.yml -- Faber manages versioning config. Repo file will be ignored."
fi

cat > GitVersion.yml <<'GITVERSION'
mode: ContinuousDeployment
assembly-versioning-scheme: MajorMinorPatch
tag-prefix: v
commit-message-incrementing: Enabled
branches:
  main:
    regex: ^main$
    tag: ''
    increment: Patch
    is-release-branch: true
    prevent-increment-of-merged-branch-version: true
  develop:
    regex: ^develop$
    tag: alpha
    increment: Minor
  release:
    regex: ^release/.*$
    tag: beta
    increment: None
    is-release-branch: true
  feature:
    regex: ^feature/.*$
    tag: alpha
    increment: Minor
    source-branches: [develop]
  hotfix:
    regex: ^hotfix/.*$
    tag: ''
    increment: Patch
    source-branches: [main]
    is-release-branch: true
GITVERSION
echo "GitVersion config written (Faber standard SDLC)"

echo "Running GitVersion ${GITVERSION_TAG}..."

GITVERSION_OUTPUT=$(docker run --rm \
  -v "$(pwd):/repo" \
  "gittools/gitversion:${GITVERSION_TAG}" \
  /repo /output json /nofetch)

echo "GitVersion raw output:"
echo "${GITVERSION_OUTPUT}" | head -30

# Parse and export all GitVersion fields to BASH_ENV
GITVERSION_MAJOR=$(echo "${GITVERSION_OUTPUT}" | jq -r '.Major')
GITVERSION_MINOR=$(echo "${GITVERSION_OUTPUT}" | jq -r '.Minor')
GITVERSION_PATCH=$(echo "${GITVERSION_OUTPUT}" | jq -r '.Patch')
GITVERSION_SEMVER=$(echo "${GITVERSION_OUTPUT}" | jq -r '.SemVer')
GITVERSION_FULLSEMVER=$(echo "${GITVERSION_OUTPUT}" | jq -r '.FullSemVer')
GITVERSION_PRERELEASE_TAG=$(echo "${GITVERSION_OUTPUT}" | jq -r '.PreReleaseTag')
GITVERSION_PRERELEASE_NUMBER=$(echo "${GITVERSION_OUTPUT}" | jq -r '.PreReleaseNumber')
GITVERSION_BRANCH_NAME=$(echo "${GITVERSION_OUTPUT}" | jq -r '.BranchName')
GITVERSION_SHA=$(echo "${GITVERSION_OUTPUT}" | jq -r '.ShortSha')

{
  echo "export GITVERSION_MAJOR='${GITVERSION_MAJOR}'"
  echo "export GITVERSION_MINOR='${GITVERSION_MINOR}'"
  echo "export GITVERSION_PATCH='${GITVERSION_PATCH}'"
  echo "export GITVERSION_SEMVER='${GITVERSION_SEMVER}'"
  echo "export GITVERSION_FULLSEMVER='${GITVERSION_FULLSEMVER}'"
  echo "export GITVERSION_PRERELEASE_TAG='${GITVERSION_PRERELEASE_TAG}'"
  echo "export GITVERSION_PRERELEASE_NUMBER='${GITVERSION_PRERELEASE_NUMBER}'"
  echo "export GITVERSION_BRANCH_NAME='${GITVERSION_BRANCH_NAME}'"
  echo "export GITVERSION_SHA='${GITVERSION_SHA}'"
} >> "${BASH_ENV}"

echo "GitVersion: ${GITVERSION_MAJOR}.${GITVERSION_MINOR}.${GITVERSION_PATCH} (${GITVERSION_FULLSEMVER})"
