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

munitor_header "update_cd_repo"

REPO="${CD_REPO:?CD_REPO not set}"
VERSION="${PROJECT_VERSION:?PROJECT_VERSION not set}"
ENVIRONMENT="${CD_ENVIRONMENT:-}"
FORMAT="${CD_FORMAT:-helm}"
IMAGE_NAME="${CD_IMAGE_NAME:-}"
CONFIGURED_PATH="${CD_PATH:-}"
VALUES="${VALUES_FILE:-values.yaml}"
KEY="${IMAGE_KEY:-image.tag}"

CLONE_DIR="/tmp/cd-repo"

# Cleanup on exit
cleanup() {
  rm -rf "${CLONE_DIR}" 2>/dev/null || true
}
trap cleanup EXIT

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "ERROR: GITHUB_TOKEN is not set. Add it via CircleCI context."
  exit 1
fi

# Release versions are owned by exactly one commit (allocate_version reserves the
# v<version> tag atomically). Refuse to point the GitOps repo at a version that
# belongs to a different commit: the image tag would not contain this build.
if [[ "${CIRCLE_BRANCH:-}" == "main" && "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && -z "${MUNITOR_SKIP_TAG_OWNERSHIP_CHECK:-}" ]]; then
  SOURCE_REPO="${MUNITOR_SOURCE_REPO:-${CIRCLE_PROJECT_USERNAME:-}/${CIRCLE_PROJECT_REPONAME:-}}"
  SOURCE_SHA="${CIRCLE_SHA1:?CIRCLE_SHA1 not set}"
  github_get() {
    curl -fsS -H "Authorization: Bearer ${GITHUB_TOKEN}" -H "Accept: application/vnd.github+json"       "https://api.github.com/repos/${SOURCE_REPO}/$1"
  }
  if ! TAG_REF=$(github_get "git/ref/tags/v${VERSION}"); then
    echo "ERROR: Release tag v${VERSION} does not exist in ${SOURCE_REPO}; the version was never reserved."
    exit 1
  fi
  TAG_SHA=$(echo "${TAG_REF}" | jq -r '.object.sha')
  if [[ "$(echo "${TAG_REF}" | jq -r '.object.type')" == "tag" ]]; then
    TAG_SHA=$(github_get "git/tags/${TAG_SHA}" | jq -r '.object.sha')
  fi
  if [[ "${TAG_SHA}" != "${SOURCE_SHA}" ]]; then
    echo "ERROR: Version ${VERSION} belongs to commit ${TAG_SHA}, not ${SOURCE_SHA}."
    echo "Refusing to bump the GitOps repo: the image tag ${VERSION} was not built from this commit."
    exit 1
  fi
  echo "Verified v${VERSION} -> ${SOURCE_SHA}."
fi

echo "Updating CD repo: ${REPO} (format=${FORMAT}, version=${VERSION})"

# Clone the CD repo using explicit token auth
rm -rf "${CLONE_DIR}"
git clone "https://x-access-token:${GITHUB_TOKEN}@github.com/${REPO}.git" "${CLONE_DIR}"

cd "${CLONE_DIR}"

apply_updates() {
  if [[ "${FORMAT}" == "kustomize" ]]; then
    # --- Kustomize mode ---
    if [[ -z "${IMAGE_NAME}" ]]; then
      echo "ERROR: cd_image_name is required for Kustomize repos."
      exit 1
    fi

    # Explicit paths support consolidated GitOps repositories. Existing dedicated
    # repositories retain the overlays/<environment> convention by default.
    if [[ -n "${CONFIGURED_PATH}" ]]; then
      if [[ "${CONFIGURED_PATH}" == /* || "${CONFIGURED_PATH}" == *".."* || "${CONFIGURED_PATH}" != *kustomization.yaml ]]; then
        echo "ERROR: cd.path must be a relative path to a kustomization.yaml file without '..'."
        exit 1
      fi
      KUST_FILE="${CONFIGURED_PATH}"
    elif [[ -n "${ENVIRONMENT}" ]]; then
      KUST_FILE="overlays/${ENVIRONMENT}/kustomization.yaml"
    else
      KUST_FILE="kustomization.yaml"
    fi

    if [[ ! -f "${KUST_FILE}" ]]; then
      echo "ERROR: Kustomize file '${KUST_FILE}' not found in CD repo."
      if [[ -z "${CONFIGURED_PATH}" ]]; then
        echo "Available overlays:"
        ls overlays/ 2>/dev/null || echo "  (no overlays directory)"
      fi
      exit 1
    fi

    echo "Updating ${KUST_FILE}: ${IMAGE_NAME} -> ${VERSION}"
    if ! yq -e ".images[] | select(.name == \"${IMAGE_NAME}\")" "${KUST_FILE}" >/dev/null; then
      echo "ERROR: Image '${IMAGE_NAME}' is not declared in ${KUST_FILE}."
      exit 1
    fi
    yq -i "(.images[] | select(.name == \"${IMAGE_NAME}\")).newTag = \"${VERSION}\"" "${KUST_FILE}"
    yq -i "del((.images[] | select(.name == \"${IMAGE_NAME}\")).digest)" "${KUST_FILE}"
    git add "${KUST_FILE}"

  else
    # --- Helm mode (default) ---
    echo "Updating ${KEY} -> ${VERSION}"

    # Resolve environment-specific values path when CD_ENVIRONMENT is set
    if [[ -n "${ENVIRONMENT}" ]]; then
      ENV_VALUES="environments/${ENVIRONMENT}/${VALUES}"
      if [[ -f "${ENV_VALUES}" ]]; then
        VALUES="${ENV_VALUES}"
        echo "Using environment path: ${VALUES}"
      else
        echo "Environment path '${ENV_VALUES}' not found, falling back to root '${VALUES}'"
      fi
    fi

    if [[ ! -f "${VALUES}" ]]; then
      echo "ERROR: Values file '${VALUES}' not found in CD repo."
      exit 1
    fi

    yq -i ".${KEY} = \"${VERSION}\"" "${VALUES}"
    git add "${VALUES}"
  fi

  # Update supplemental image tags (if any)
  SUPP_JSON="${SUPPLEMENTAL_IMAGES_JSON:-[]}"
  if [[ "${SUPP_JSON}" != "[]" && "${SUPP_JSON}" != "null" ]]; then
    SUPP_COUNT=$(echo "${SUPP_JSON}" | jq 'length')
    echo "Updating ${SUPP_COUNT} supplemental image tag(s)..."

    for ((i = 0; i < SUPP_COUNT; i++)); do
      SUPP_NAME=$(echo "${SUPP_JSON}" | jq -r ".[$i].name")

      if [[ "${FORMAT}" == "kustomize" ]]; then
        SUPP_CD_IMAGE=$(echo "${SUPP_JSON}" | jq -r ".[$i].cd.image_name // \"\"")
        if [[ -z "${SUPP_CD_IMAGE}" ]]; then
          SUPP_CD_IMAGE="${IMAGE_NAME}-${SUPP_NAME}"
        fi
        echo "  Kustomize: ${SUPP_CD_IMAGE} -> ${VERSION}"
        # Upsert: add entry if it doesn't exist, then update
        EXISTING=$(yq ".images[] | select(.name == \"${SUPP_CD_IMAGE}\") | .name" "${KUST_FILE}")
        if [[ -z "${EXISTING}" ]]; then
          echo "    (creating new image entry)"
          yq -i ".images += [{\"name\": \"${SUPP_CD_IMAGE}\", \"newTag\": \"${VERSION}\"}]" "${KUST_FILE}"
        else
          yq -i "(.images[] | select(.name == \"${SUPP_CD_IMAGE}\")).newTag = \"${VERSION}\"" "${KUST_FILE}"
          yq -i "del((.images[] | select(.name == \"${SUPP_CD_IMAGE}\")).digest)" "${KUST_FILE}"
        fi
        git add "${KUST_FILE}"
      else
        SUPP_IMAGE_KEY=$(echo "${SUPP_JSON}" | jq -r ".[$i].cd.image_key // \"\"")
        if [[ -n "${SUPP_IMAGE_KEY}" ]]; then
          echo "  Helm: ${SUPP_IMAGE_KEY} -> ${VERSION}"
          yq -i ".${SUPP_IMAGE_KEY} = \"${VERSION}\"" "${VALUES}"
          git add "${VALUES}"
        fi
      fi
    done
  fi
}

# Commit through the GitHub GraphQL API (createCommitOnBranch) rather than pushing local commits.
# GitHub signs API-created commits, so they show as Verified and satisfy a
# "require signed commits" ruleset on the GitOps branch without a bypass actor.
# The commit author is the GITHUB_TOKEN identity; the source build is recorded
# in the commit body. expectedHeadOid makes concurrent updates fail cleanly and
# retry against the new head instead of overwriting each other.
BRANCH="$(git branch --show-current)"
HEADLINE="chore: update ${IMAGE_NAME:-image} to ${VERSION}"
MESSAGE_BODY="Source: ${CIRCLE_PROJECT_REPONAME:-unknown}@${CIRCLE_SHA1:-unknown}"

commit_via_api() {
  local head_oid additions payload response file
  head_oid="$(git rev-parse HEAD)"
  additions='[]'
  while IFS= read -r file; do
    base64 -w0 "${file}" > /tmp/cd-file.b64
    additions="$(jq --arg path "${file}" --rawfile contents /tmp/cd-file.b64       '. + [{path: $path, contents: $contents}]' <<< "${additions}")"
  done < <(git diff --cached --name-only)
  payload="$(jq -n --arg repo "${REPO}" --arg branch "${BRANCH}" --arg oid "${head_oid}"     --arg headline "${HEADLINE}" --arg body "${MESSAGE_BODY}" --argjson additions "${additions}"     '{query: "mutation($input: CreateCommitOnBranchInput!) { createCommitOnBranch(input: $input) { commit { oid url } } }",
      variables: {input: {branch: {repositoryNameWithOwner: $repo, branchName: $branch},
        expectedHeadOid: $oid, message: {headline: $headline, body: $body},
        fileChanges: {additions: $additions}}}}')"
  if ! response="$(curl -sS -X POST -H "Authorization: bearer ${GITHUB_TOKEN}"     -H "Content-Type: application/json" https://api.github.com/graphql --data @- <<< "${payload}")"; then
    echo "GraphQL request failed."
    return 1
  fi
  if [[ "$(jq -r '.data.createCommitOnBranch.commit.oid // empty' <<< "${response}")" == "" ]]; then
    echo "GraphQL commit rejected: $(jq -c '.errors // .' <<< "${response}")"
    return 1
  fi
  echo "Signed commit: $(jq -r '.data.createCommitOnBranch.commit.url' <<< "${response}")"
}

for attempt in 1 2 3; do
  apply_updates

  if git diff --cached --quiet; then
    echo "No changes to commit (version already up to date)."
    exit 0
  fi

  if commit_via_api; then
    echo "CD repo updated successfully."
    exit 0
  fi

  if [[ "${attempt}" == "3" ]]; then
    echo "ERROR: Could not commit the GitOps update after ${attempt} attempts."
    exit 1
  fi

  echo "Commit raced with another GitOps update; refreshing before retry ${attempt}/3."
  git fetch -q origin "${BRANCH}"
  git reset -q --hard "origin/${BRANCH}"
done
