#!/usr/bin/env bash
set -euo pipefail

# Source shared helpers
FABER_HELPERS="${FABER_HELPERS:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/faber_helpers.sh}"
# shellcheck source=faber_helpers.sh
if [[ -f "${FABER_HELPERS}" ]]; then source "${FABER_HELPERS}"
elif ! type faber_header &>/dev/null; then
  faber_header() { echo "=== Faber: ${1:-unknown} ==="; }
  faber_check_tool() { command -v "$1" &>/dev/null || { echo "ERROR: $1 not found"; exit 1; }; }
  faber_download_with_retry() { curl -fsSL --retry 3 "$1" -o "$2"; }
fi

faber_header "export_version_vars"

# Requires GITVERSION_* vars from calculate_version step
MAJOR="${GITVERSION_MAJOR:?GITVERSION_MAJOR not set -- run calculate_version first}"
MINOR="${GITVERSION_MINOR:?GITVERSION_MINOR not set}"
PATCH="${GITVERSION_PATCH:?GITVERSION_PATCH not set}"
BRANCH="${GITVERSION_BRANCH_NAME:-${CIRCLE_BRANCH:-unknown}}"
SHA="${GITVERSION_SHA:-$(git rev-parse --short HEAD)}"
PRERELEASE_NUMBER="${GITVERSION_PRERELEASE_NUMBER:-0}"

BASE_VERSION="${MAJOR}.${MINOR}.${PATCH}"

# Map GitVersion output to Maven-convention version based on branch type
DOCKER_ENV_TAG=""

case "${BRANCH}" in
  main)
    # Tagged release: clean semver (no env tag -- Versioning Policy Section 7)
    PROJECT_VERSION="${BASE_VERSION}"
    ;;
  develop)
    # Snapshot for continuous integration -- include SHA so each build produces a unique tag
    PROJECT_VERSION="${BASE_VERSION}-SNAPSHOT.${SHA}"
    DOCKER_ENV_TAG="develop"
    ;;
  staging)
    # Staging environment: version with staging qualifier
    PROJECT_VERSION="${BASE_VERSION}-staging.${SHA}"
    DOCKER_ENV_TAG="staging"
    ;;
  feature/*)
    # Feature branch: include sanitized branch name + short sha
    FEATURE_NAME="${BRANCH#feature/}"
    # Sanitize: replace non-alphanumeric with hyphen, lowercase
    FEATURE_NAME=$(echo "${FEATURE_NAME}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/-\+/-/g' | sed 's/^-//;s/-$//')
    PROJECT_VERSION="${BASE_VERSION}-${FEATURE_NAME}-${SHA}-SNAPSHOT"
    ;;
  release/*)
    # Release candidate
    PROJECT_VERSION="${BASE_VERSION}-RC.${PRERELEASE_NUMBER}"
    ;;
  hotfix/*)
    # Hotfix: clean patch version
    PROJECT_VERSION="${BASE_VERSION}"
    ;;
  *)
    echo "WARNING: Unrecognized branch type '${BRANCH}', using SNAPSHOT"
    PROJECT_VERSION="${BASE_VERSION}-SNAPSHOT.${SHA}"
    ;;
esac

echo "Branch: ${BRANCH}"
echo "Project version: ${PROJECT_VERSION}"
echo "Docker env tag: ${DOCKER_ENV_TAG:-none}"

echo "export PROJECT_VERSION='${PROJECT_VERSION}'" >> "${BASH_ENV}"
echo "export DOCKER_ENV_TAG='${DOCKER_ENV_TAG}'" >> "${BASH_ENV}"
