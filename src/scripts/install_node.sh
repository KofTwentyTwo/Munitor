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

VERSION="${NODE_VERSION:-20}"

faber_header "install_node (v${VERSION})"

# nvm is pre-installed on CircleCI ubuntu-2204 machine images
export NVM_DIR="${HOME}/.nvm"
# shellcheck source=/dev/null
[ -s "${NVM_DIR}/nvm.sh" ] && source "${NVM_DIR}/nvm.sh"

if ! command -v nvm &>/dev/null; then
  echo "ERROR: nvm is not available."
  echo "  Expected at: ${NVM_DIR}/nvm.sh"
  echo "  Ensure you are using a CircleCI machine image with nvm pre-installed."
  exit 1
fi

nvm install "${VERSION}"
nvm use "${VERSION}"
nvm alias default "${VERSION}"

# Verify installation succeeded
if ! command -v node &>/dev/null; then
  echo "ERROR: node not found after nvm install. Installation may have failed."
  exit 1
fi

echo "=== Node Environment ==="
echo "  Node: $(node --version)"
echo "  npm:  $(npm --version)"

# Warn if .nvmrc exists and doesn't match
if [[ -f ".nvmrc" ]]; then
  NVMRC_VERSION=$(cat .nvmrc | tr -d '[:space:]')
  if [[ "${NVMRC_VERSION}" != "${VERSION}" && "${NVMRC_VERSION}" != "v${VERSION}" ]]; then
    echo ""
    echo "WARNING: .nvmrc specifies '${NVMRC_VERSION}' but .faber.yml has node_version: '${VERSION}'"
    echo "  Update one or the other to keep local dev and CI in sync."
  fi
fi

# Export to BASH_ENV so downstream steps pick it up.
# CRITICAL: Do NOT source nvm.sh in BASH_ENV. CircleCI machine executors run
# each step with /bin/bash --login -eo pipefail. nvm.sh is not compatible with
# set -e and will kill every subsequent step before any script code executes
# (manifests as empty output + exit 1). Instead, export PATH directly to the
# installed node/npm binaries.
NODE_BIN_DIR="$(dirname "$(command -v node)")"
{
  echo "export NVM_DIR='${NVM_DIR}'"
  echo "export PATH=\"${NODE_BIN_DIR}:\${PATH}\""
} >> "${BASH_ENV}"

echo "  BASH_ENV: exported PATH with ${NODE_BIN_DIR}"
