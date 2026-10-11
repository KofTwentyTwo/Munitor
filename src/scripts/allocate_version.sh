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

munitor_header "allocate_version"

# Atomically reserve the release version for this commit.
#
# GitVersion derives the next version from the tags it can see, so two main
# merges that build concurrently both compute the same version. The reservation
# is the git tag itself: GitHub creates refs/tags/v<version> only if it does not
# exist, which serializes concurrent pipelines without a lock service.
#   - created               -> this commit owns the version
#   - exists on this commit -> rerun of the same pipeline; reuse it
#   - exists on another     -> taken; try the next patch version
# An existing tag is never moved or deleted.

VERSION="${PROJECT_VERSION:?PROJECT_VERSION not set -- run export_version_vars first}"
BRANCH="${CIRCLE_BRANCH:-}"

if [[ "${BRANCH}" != "main" ]]; then
  echo "Branch '${BRANCH:-none}' is not main; version ${VERSION} needs no reservation."
  exit 0
fi

if [[ ! "${VERSION}" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "Version ${VERSION} is not a release version; no reservation needed."
  exit 0
fi

MAJOR="${BASH_REMATCH[1]}"
MINOR="${BASH_REMATCH[2]}"
PATCH="${BASH_REMATCH[3]}"

SHA="${CIRCLE_SHA1:?CIRCLE_SHA1 not set -- cannot reserve a version without the commit SHA}"
REPO="${MUNITOR_SOURCE_REPO:-${CIRCLE_PROJECT_USERNAME:-}/${CIRCLE_PROJECT_REPONAME:-}}"
MAX_ATTEMPTS="${MUNITOR_VERSION_ALLOC_ATTEMPTS:-25}"

if [[ "${REPO}" == "/" || "${REPO}" == */ || "${REPO}" == /* ]]; then
  echo "ERROR: Cannot determine the source repository (CIRCLE_PROJECT_USERNAME/CIRCLE_PROJECT_REPONAME)."
  exit 1
fi

if [[ -z "${MUNITOR_GH_API_CMD:-}" && -z "${GITHUB_TOKEN:-}" ]]; then
  echo "ERROR: GITHUB_TOKEN is not set; release versions on main must be reserved as git tags."
  echo "Add the GitHub context to the build-and-test job."
  exit 1
fi

# gh_api METHOD PATH [JSON_BODY]
# Prints the response body. Returns 0 on 2xx, 2 on 404, 3 on 409/422, 1 otherwise.
# MUNITOR_GH_API_CMD substitutes the transport (used by tests).
gh_api() {
  if [[ -n "${MUNITOR_GH_API_CMD:-}" ]]; then
    "${MUNITOR_GH_API_CMD}" "$@"
    return
  fi

  local method="$1" path="$2" body="${3:-}"
  local out code
  out=$(mktemp)
  local args=(-sS -o "${out}" -w '%{http_code}' -X "${method}"
    -H "Authorization: Bearer ${GITHUB_TOKEN}"
    -H "Accept: application/vnd.github+json"
    -H "X-GitHub-Api-Version: 2022-11-28")
  if [[ -n "${body}" ]]; then
    args+=(-H "Content-Type: application/json" -d "${body}")
  fi

  if ! code=$(curl "${args[@]}" "https://api.github.com/repos/${REPO}/${path}"); then
    cat "${out}"
    rm -f "${out}"
    return 1
  fi
  cat "${out}"
  rm -f "${out}"

  case "${code}" in
    2??) return 0 ;;
    404) return 2 ;;
    409|422) return 3 ;;
    *) echo "GitHub API ${method} ${path} returned HTTP ${code}" >&2; return 1 ;;
  esac
}

# tag_commit TAG -> prints the commit SHA the tag points at (dereferences annotated tags)
tag_commit() {
  local tag="$1" ref obj_type obj_sha rc=0
  ref=$(gh_api GET "git/ref/tags/${tag}") || rc=$?
  if [[ ${rc} -ne 0 ]]; then
    echo "ERROR: Could not read tag ${tag} (rc=${rc}): ${ref}" >&2
    return 1
  fi
  obj_type=$(echo "${ref}" | jq -r '.object.type')
  obj_sha=$(echo "${ref}" | jq -r '.object.sha')
  if [[ "${obj_type}" == "tag" ]]; then
    rc=0
    ref=$(gh_api GET "git/tags/${obj_sha}") || rc=$?
    if [[ ${rc} -ne 0 ]]; then
      echo "ERROR: Could not dereference annotated tag ${tag} (rc=${rc})" >&2
      return 1
    fi
    obj_sha=$(echo "${ref}" | jq -r '.object.sha')
  fi
  echo "${obj_sha}"
}

ALLOCATED=""
for ((attempt = 1; attempt <= MAX_ATTEMPTS; attempt++)); do
  CANDIDATE="${MAJOR}.${MINOR}.${PATCH}"
  TAG="v${CANDIDATE}"
  rc=0
  response=$(gh_api POST "git/refs" "{\"ref\":\"refs/tags/${TAG}\",\"sha\":\"${SHA}\"}") || rc=$?

  if [[ ${rc} -eq 0 ]]; then
    echo "Reserved ${TAG} for ${SHA}."
    ALLOCATED="${CANDIDATE}"
    break
  fi

  if [[ ${rc} -ne 3 ]]; then
    echo "ERROR: Failed to create tag ${TAG} (rc=${rc}): ${response}"
    exit 1
  fi

  OWNER=$(tag_commit "${TAG}")
  if [[ "${OWNER}" == "${SHA}" ]]; then
    echo "${TAG} already points at ${SHA} (pipeline rerun); reusing it."
    ALLOCATED="${CANDIDATE}"
    break
  fi

  echo "${TAG} is already taken by ${OWNER}; trying the next patch version."
  PATCH=$((PATCH + 1))
done

if [[ -z "${ALLOCATED}" ]]; then
  echo "ERROR: Could not reserve a release version after ${MAX_ATTEMPTS} attempts (last tried ${TAG})."
  exit 1
fi

if [[ "${ALLOCATED}" != "${VERSION}" ]]; then
  echo "GitVersion computed ${VERSION}, but it belongs to another commit; this build is ${ALLOCATED}."
fi

{
  echo "export PROJECT_VERSION='${ALLOCATED}'"
  echo "export GITVERSION_PATCH='${PATCH}'"
  echo "export MUNITOR_RELEASE_TAG='v${ALLOCATED}'"
} >> "${BASH_ENV}"

echo "Release version: ${ALLOCATED} (tag v${ALLOCATED} -> ${SHA})"
