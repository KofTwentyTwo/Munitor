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

munitor_header "node_install_deps"
munitor_check_tool node --version
munitor_check_tool npm --version

# Verify package-lock.json exists
if [[ ! -f "package-lock.json" ]]; then
  echo "ERROR: package-lock.json not found in $(pwd)"
  echo "  npm ci requires a lockfile. Run 'npm install' locally and commit the lockfile."
  exit 1
fi

# Check lockfile version compatibility
LOCKFILE_VERSION=$(node -e "console.log(require('./package-lock.json').lockfileVersion || 'unknown')" 2>/dev/null || echo "unknown")
NPM_MAJOR=$(npm --version 2>/dev/null | cut -d. -f1)
echo "  lockfileVersion: ${LOCKFILE_VERSION}"

if [[ "${LOCKFILE_VERSION}" == "3" && -n "${NPM_MAJOR}" && "${NPM_MAJOR}" -lt 11 ]]; then
  echo ""
  echo "WARNING: package-lock.json uses lockfileVersion 3 (npm 11+)"
  echo "  but CI is running npm ${NPM_MAJOR} ($(npm --version))."
  echo "  This will likely cause 'npm ci' to fail."
  echo ""
  echo "  Fix: regenerate your lockfile with the same Node version CI uses."
  echo "  Add an .nvmrc to your repo to keep local and CI versions in sync."
  echo ""
fi

echo ""
echo "Running npm ci..."
npm ci

PKG_COUNT=$(find node_modules -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
echo "npm ci complete. ${PKG_COUNT} packages installed."
