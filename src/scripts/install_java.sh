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

munitor_header "install_java"

VERSION="${JAVA_VERSION:-21}"

echo "Installing Java ${VERSION} via SDKMAN..."

# Install SDKMAN if not present
if [[ ! -d "${HOME}/.sdkman" ]]; then
  curl -s "https://get.sdkman.io" | bash
fi

# Disable nounset for all SDKMAN operations -- its internals reference
# many unbound variables (SDKMAN_CANDIDATES_API, SDKMAN_OFFLINE_MODE, etc.)
# shellcheck source=/dev/null
set +u
source "${HOME}/.sdkman/bin/sdkman-init.sh"

# Find the latest available build for the requested major version
IDENTIFIER=$(sdk list java | grep -oP "[\d.]+\.hs-adpt" | grep "^${VERSION}\." | head -1 || true)

if [[ -z "${IDENTIFIER}" ]]; then
  # Try Temurin distribution
  IDENTIFIER=$(sdk list java | grep -oP "[\d.]+-tem" | grep "^${VERSION}\." | head -1 || true)
fi

if [[ -z "${IDENTIFIER}" ]]; then
  # Fallback: install by major version, let SDKMAN pick the default
  IDENTIFIER="${VERSION}-tem"
fi

echo "Installing Java: ${IDENTIFIER}"
if ! sdk install java "${IDENTIFIER}"; then
  echo "ERROR: Failed to install Java ${IDENTIFIER}"
  echo "Available Java versions:"
  sdk list java | head -20
  exit 1
fi
sdk use java "${IDENTIFIER}"

JAVA_HOME_DIR="$(sdk home java "${IDENTIFIER}")"
set -u

java -version
echo "export JAVA_HOME='${JAVA_HOME_DIR}'" >> "${BASH_ENV}"
