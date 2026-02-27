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

echo "Installing Java ${VERSION} via Adoptium APT repository..."

# Add Adoptium GPG key and repository
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://packages.adoptium.net/artifactory/api/gpg/key/public \
  | sudo tee /etc/apt/keyrings/adoptium.asc > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] \
  https://packages.adoptium.net/artifactory/deb \
  $(. /etc/os-release && echo "${VERSION_CODENAME}") main" \
  | sudo tee /etc/apt/sources.list.d/adoptium.list > /dev/null

sudo apt-get update -qq
sudo apt-get install -y -qq "temurin-${VERSION}-jdk"

# Set JAVA_HOME for subsequent steps
JAVA_HOME_DIR="/usr/lib/jvm/temurin-${VERSION}-jdk-$(dpkg --print-architecture)"
echo "export JAVA_HOME='${JAVA_HOME_DIR}'" >> "${BASH_ENV}"
export JAVA_HOME="${JAVA_HOME_DIR}"
export PATH="${JAVA_HOME_DIR}/bin:${PATH}"

java -version
