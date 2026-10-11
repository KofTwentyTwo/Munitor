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

munitor_header "guard_image_tags"

# Version tags are immutable. Before anything is pushed, verify that every
# version tag this job will publish is either absent from the registry or was
# built from this same commit (a rerun). A tag built from a different commit
# means two pipelines claimed the same version; overwriting it would silently
# change what an already-deployed tag points at, so fail instead.
# Mutable environment tags (develop, staging) are not checked.

munitor_check_tool docker --version
munitor_check_tool jq --version

IMAGE="${IMAGE_NAME:?IMAGE_NAME not set}"
REGISTRY="${REGISTRY:-ghcr.io/KofTwentyTwo}"
VERSION="${PROJECT_VERSION:?PROJECT_VERSION not set -- run export_version_vars first}"
SHA="${CIRCLE_SHA1:?CIRCLE_SHA1 not set}"
SUPP_JSON="${SUPPLEMENTAL_IMAGES_JSON:-[]}"
REVISION_LABEL="org.opencontainers.image.revision"

if [[ -z "${MUNITOR_SKIP_REGISTRY_LOGIN:-}" ]]; then
  TOKEN="${!GHCR_TOKEN_VAR:-}"
  USER="${!GHCR_USER_VAR:-}"
  if [[ -z "${TOKEN}" || -z "${USER}" ]]; then
    echo "ERROR: GHCR credentials not set (\$${GHCR_TOKEN_VAR:-GHCR_TOKEN}, \$${GHCR_USER_VAR:-GHCR_USERNAME})"
    exit 1
  fi
  echo "${TOKEN}" | docker login "${REGISTRY%%/*}" -u "${USER}" --password-stdin
fi

REFS=("${REGISTRY}/${IMAGE}:${VERSION}")
if [[ "${SUPP_JSON}" != "[]" && "${SUPP_JSON}" != "null" && -n "${SUPP_JSON}" ]]; then
  while IFS= read -r name; do
    name="${name%$'\r'}"
    REFS+=("${REGISTRY}/${IMAGE}-${name}:${VERSION}")
  done < <(echo "${SUPP_JSON}" | jq -r '.[].name')
fi

CONFLICTS=0
for ref in "${REFS[@]}"; do
  err=$(mktemp)
  rc=0
  config=$(docker buildx imagetools inspect "${ref}" --format '{{json .Image}}' 2>"${err}") || rc=$?
  if [[ ${rc} -ne 0 ]]; then
    if grep -qiE 'not found|manifest unknown|MANIFEST_UNKNOWN|no such manifest' "${err}"; then
      echo "OK: ${ref} does not exist yet."
      rm -f "${err}"
      continue
    fi
    echo "ERROR: Could not inspect ${ref}; refusing to push without proving the tag is free:"
    cat "${err}"
    rm -f "${err}"
    exit 1
  fi
  rm -f "${err}"

  # Single-platform images return one config; multi-platform images return a map of configs.
  revision=$(echo "${config}" | jq -r --arg l "${REVISION_LABEL}" \
    '[.. | objects | select(has("Labels")) | .Labels // {} | .[$l] // empty] | first // ""')

  if [[ "${revision}" == "${SHA}" ]]; then
    echo "OK: ${ref} already exists for this commit (rerun); it will be republished from ${SHA}."
  else
    echo "ERROR: ${ref} already exists for a different commit (${revision:-unknown, no ${REVISION_LABEL} label})."
    CONFLICTS=$((CONFLICTS + 1))
  fi
done

if [[ ${CONFLICTS} -gt 0 ]]; then
  echo "Refusing to overwrite ${CONFLICTS} immutable version tag(s). Version ${VERSION} was claimed by another build;"
  echo "rerun from a fresh pipeline so allocate_version reserves a new version."
  exit 1
fi

echo "All ${#REFS[@]} version tag(s) are free for ${SHA}."
