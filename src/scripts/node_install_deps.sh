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

PACKAGE_MANAGER="${MUNITOR_PACKAGE_MANAGER:-npm}"

munitor_header "node_install_deps (${PACKAGE_MANAGER})"
munitor_check_tool node --version

case "${PACKAGE_MANAGER}" in
  npm)
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
    ;;

  pnpm)
    munitor_check_tool pnpm --version

    # Verify pnpm-lock.yaml exists
    if [[ ! -f "pnpm-lock.yaml" ]]; then
      echo "ERROR: pnpm-lock.yaml not found in $(pwd)"
      echo "  pnpm install --frozen-lockfile requires a lockfile. Run 'pnpm install' locally and commit the lockfile."
      exit 1
    fi

    echo ""
    echo "Running pnpm install --frozen-lockfile..."
    pnpm install --frozen-lockfile

    PKG_COUNT=$(find node_modules -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
    echo "pnpm install complete. ${PKG_COUNT} packages installed."
    ;;

  *)
    echo "ERROR: Unsupported package manager '${PACKAGE_MANAGER}'"
    echo "  Supported values: npm, pnpm"
    exit 1
    ;;
esac

# Prisma auto-detection: generate client if schema files are present
PRISMA_SCHEMAS=$(find . -path "*/prisma/schema.prisma" -not -path "*/node_modules/*" -not -path "*/dist/*" -not -path "*/build/*" 2>/dev/null || true)

if [[ -n "${PRISMA_SCHEMAS}" ]]; then
  echo ""
  echo "=== Prisma schema(s) detected ==="

  PRISMA_GENERATED=0
  while IFS= read -r SCHEMA_PATH; do
    # Resolve the package directory (parent of prisma/)
    PKG_DIR=$(dirname "$(dirname "${SCHEMA_PATH}")")

    # Check if prisma CLI is available from the package directory.
    # In monorepos, prisma may only be installed in a workspace package,
    # not at the root, so we must check from the package's own context.
    PRISMA_CMD=""
    case "${PACKAGE_MANAGER}" in
      npm)
        if (cd "${PKG_DIR}" && npx prisma --version) &>/dev/null; then
          PRISMA_CMD="npx prisma"
        fi
        ;;
      pnpm)
        if (cd "${PKG_DIR}" && pnpm exec prisma --version) &>/dev/null; then
          PRISMA_CMD="pnpm exec prisma"
        fi
        ;;
    esac

    if [[ -n "${PRISMA_CMD}" ]]; then
      echo "  Generating Prisma client for: ${SCHEMA_PATH}"
      (cd "${PKG_DIR}" && ${PRISMA_CMD} generate --schema=prisma/schema.prisma)
      PRISMA_GENERATED=$((PRISMA_GENERATED + 1))
    else
      echo "  WARNING: Found ${SCHEMA_PATH} but prisma CLI not available in ${PKG_DIR}."
      echo "    Add prisma as a dev dependency in that package."
    fi
  done <<< "${PRISMA_SCHEMAS}"

  if [[ "${PRISMA_GENERATED}" -gt 0 ]]; then
    echo "Prisma generate complete (${PRISMA_GENERATED} schema(s))."
  fi
fi
