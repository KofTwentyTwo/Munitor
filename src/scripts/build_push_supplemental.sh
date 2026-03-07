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

munitor_header "build_push_supplemental"
munitor_check_tool jq --version
munitor_check_tool docker --version

IMAGES_JSON="${SUPPLEMENTAL_IMAGES_JSON:-[]}"

# Skip if no supplemental images defined
if [[ "${IMAGES_JSON}" == "[]" || "${IMAGES_JSON}" == "null" || -z "${IMAGES_JSON}" ]]; then
  echo "No supplemental images defined, skipping."
  exit 0
fi

IMAGE="${IMAGE_NAME:?IMAGE_NAME not set}"
REGISTRY="${REGISTRY:-ghcr.io/KofTwentyTwo}"
VERSION="${PROJECT_VERSION:?PROJECT_VERSION not set -- run export_version_vars first}"
ENV_TAG="${DOCKER_ENV_TAG:-}"

COUNT=$(echo "${IMAGES_JSON}" | jq 'length')
echo "Found ${COUNT} supplemental image(s) to build."

for i in $(seq 0 $((COUNT - 1))); do
  ENTRY=$(echo "${IMAGES_JSON}" | jq -c ".[$i]")

  NAME=$(echo "${ENTRY}" | jq -r '.name')
  BASE=$(echo "${ENTRY}" | jq -r '.base // empty')
  DOCKERFILE=$(echo "${ENTRY}" | jq -r '.dockerfile // empty')

  DERIVED_NAME="${IMAGE}-${NAME}"
  FULL_TAG="${REGISTRY}/${DERIVED_NAME}:${VERSION}"

  echo ""
  echo "--- Supplemental image: ${DERIVED_NAME} ---"

  if [[ -n "${DOCKERFILE}" ]]; then
    echo "Using provided Dockerfile: ${DOCKERFILE}"
  elif [[ -n "${BASE}" ]]; then
    # Auto-generate Dockerfile
    DOCKERFILE="Dockerfile.${NAME}"
    echo "Auto-generating ${DOCKERFILE} from base: ${BASE}"

    {
      echo "FROM ${BASE}"
      COPY_COUNT=$(echo "${ENTRY}" | jq '.copy // [] | length')
      for j in $(seq 0 $((COPY_COUNT - 1))); do
        SRC=$(echo "${ENTRY}" | jq -r ".copy[$j].src")
        DEST=$(echo "${ENTRY}" | jq -r ".copy[$j].dest")
        echo "COPY ${SRC} ${DEST}"
      done
    } > "${DOCKERFILE}"

    echo "Generated ${DOCKERFILE}:"
    cat "${DOCKERFILE}"
  else
    echo "ERROR: Supplemental image '${NAME}' must specify either 'dockerfile' or 'base'."
    exit 1
  fi

  # Build
  echo "Building ${FULL_TAG} ..."
  docker build -f "${DOCKERFILE}" -t "${FULL_TAG}" .

  if [[ -n "${ENV_TAG}" ]]; then
    ENV_FULL_TAG="${REGISTRY}/${DERIVED_NAME}:${ENV_TAG}"
    docker tag "${FULL_TAG}" "${ENV_FULL_TAG}"
  fi

  # Trivy scan
  echo "Scanning ${FULL_TAG} with Trivy ..."
  trivy image --severity HIGH,CRITICAL --exit-code 1 "${FULL_TAG}"

  # Push
  echo "Pushing ${FULL_TAG} ..."
  docker push "${FULL_TAG}"

  if [[ -n "${ENV_TAG}" ]]; then
    echo "Pushing ${ENV_FULL_TAG} ..."
    docker push "${ENV_FULL_TAG}"
  fi

  echo "--- Done: ${DERIVED_NAME} ---"
done

echo ""
echo "All supplemental images built, scanned, and pushed."
