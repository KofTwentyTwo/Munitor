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

faber_header "update_cd_repo"

REPO="${CD_REPO:?CD_REPO not set}"
VERSION="${PROJECT_VERSION:?PROJECT_VERSION not set}"
ENVIRONMENT="${CD_ENVIRONMENT:-}"
FORMAT="${CD_FORMAT:-helm}"
IMAGE_NAME="${CD_IMAGE_NAME:-}"
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

echo "Updating CD repo: ${REPO} (format=${FORMAT}, version=${VERSION})"

# Clone the CD repo using explicit token auth
rm -rf "${CLONE_DIR}"
git clone "https://x-access-token:${GITHUB_TOKEN}@github.com/${REPO}.git" "${CLONE_DIR}"

cd "${CLONE_DIR}"

if [[ "${FORMAT}" == "kustomize" ]]; then
  # --- Kustomize mode ---
  if [[ -z "${IMAGE_NAME}" ]]; then
    echo "ERROR: cd_image_name is required for Kustomize repos."
    exit 1
  fi

  # Find kustomization.yaml in overlays/<env>/
  if [[ -n "${ENVIRONMENT}" ]]; then
    KUST_FILE="overlays/${ENVIRONMENT}/kustomization.yaml"
  else
    KUST_FILE="kustomization.yaml"
  fi

  if [[ ! -f "${KUST_FILE}" ]]; then
    echo "ERROR: Kustomize file '${KUST_FILE}' not found in CD repo."
    echo "Available overlays:"
    ls overlays/ 2>/dev/null || echo "  (no overlays directory)"
    exit 1
  fi

  echo "Updating ${KUST_FILE}: ${IMAGE_NAME} -> ${VERSION}"
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

# Commit and push
git config user.email "${CI_GIT_EMAIL:-munitor-ci@koftwentytwo.com}"
git config user.name "${CI_GIT_NAME:-Munitor CI}"

if git diff --cached --quiet; then
  echo "No changes to commit (version already up to date)."
  exit 0
fi

git commit -m "chore: update image tag to ${VERSION}"
git push origin HEAD

echo "CD repo updated successfully."
