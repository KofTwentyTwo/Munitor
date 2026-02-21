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

faber_header "kustomize_validate"
faber_check_tool kustomize version

BASE_PATH="${KUSTOMIZE_BASE_PATH:-base/}"
OVERLAYS="${KUSTOMIZE_OVERLAYS:-}"
LOAD_RESTRICTOR="${KUSTOMIZE_LOAD_RESTRICTOR:-true}"

OUTPUT_DIR="/tmp/kustomize-output"
mkdir -p "${OUTPUT_DIR}"

# Build load restrictor flag
RESTRICTOR_FLAG=""
if [[ "${LOAD_RESTRICTOR}" == "true" ]]; then
  RESTRICTOR_FLAG="--load-restrictor LoadRestrictionsNone"
fi

FAILURES=0

# Build base
echo "=== Building base: ${BASE_PATH} ==="
# shellcheck disable=SC2086
if kustomize build ${RESTRICTOR_FLAG} "${BASE_PATH}" > "${OUTPUT_DIR}/base.yaml"; then
  echo "  base: OK"
else
  echo "  ERROR: base build failed"
  FAILURES=$((FAILURES + 1))
fi

# Auto-detect overlays if not specified
if [[ -z "${OVERLAYS}" ]]; then
  echo "=== Auto-detecting overlays ==="
  OVERLAYS=""
  for kfile in overlays/*/kustomization.yaml; do
    if [[ -f "${kfile}" ]]; then
      overlay_name=$(basename "$(dirname "${kfile}")")
      OVERLAYS="${OVERLAYS} ${overlay_name}"
    fi
  done
  OVERLAYS=$(echo "${OVERLAYS}" | xargs)
  if [[ -z "${OVERLAYS}" ]]; then
    echo "  No overlays found in overlays/*/"
  else
    echo "  Detected overlays: ${OVERLAYS}"
  fi
fi

# Build each overlay
for overlay in ${OVERLAYS}; do
  overlay_path="overlays/${overlay}/"
  echo "=== Building overlay: ${overlay} ==="
  if [[ ! -d "${overlay_path}" ]]; then
    echo "  ERROR: overlay directory '${overlay_path}' not found"
    FAILURES=$((FAILURES + 1))
    continue
  fi
  # shellcheck disable=SC2086
  if kustomize build ${RESTRICTOR_FLAG} "${overlay_path}" > "${OUTPUT_DIR}/${overlay}.yaml"; then
    echo "  ${overlay}: OK"
  else
    echo "  ERROR: overlay '${overlay}' build failed"
    FAILURES=$((FAILURES + 1))
  fi
done

echo ""
echo "=== Kustomize Output ==="
ls -la "${OUTPUT_DIR}/"

if [[ ${FAILURES} -gt 0 ]]; then
  echo ""
  echo "ERROR: ${FAILURES} kustomize build(s) failed."
  exit 1
fi

echo ""
echo "All kustomize builds succeeded."
