#!/usr/bin/env bash
# Shared helper library for Faber orb scripts.
# Source this at the top of each script for consistent diagnostics.
#
# Sourcing pattern (works even if helpers are missing):
#   FABER_HELPERS="${FABER_HELPERS:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/faber_helpers.sh}"
#   [[ -f "${FABER_HELPERS}" ]] && source "${FABER_HELPERS}"

# Guard against double-sourcing
[[ -n "${_FABER_HELPERS_LOADED:-}" ]] && return 0
_FABER_HELPERS_LOADED=1

# --------------------------------------------------------------------------
# faber_header <step_name>
#
# Print a standard banner with date, hostname, and working directory.
# --------------------------------------------------------------------------
faber_header() {
  local name="${1:-unknown}"
  echo "========================================"
  echo "  Faber: ${name}"
  echo "  Date:  $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo "  Host:  $(hostname 2>/dev/null || echo 'unknown')"
  echo "  Dir:   $(pwd)"
  echo "========================================"
}

# --------------------------------------------------------------------------
# faber_check_tool <command> [version_flag]
#
# Verify a tool is in PATH and print its version.  Exits 1 with a clear
# message if the tool is missing.
# --------------------------------------------------------------------------
faber_check_tool() {
  local cmd="$1"
  local version_flag="${2:---version}"

  if ! command -v "${cmd}" &>/dev/null; then
    echo "ERROR: Required tool '${cmd}' is not installed or not in PATH."
    echo "  PATH: ${PATH}"
    exit 1
  fi

  local ver
  ver=$("${cmd}" "${version_flag}" 2>&1 | head -1) || true
  echo "  ${cmd}: ${ver}"
}

# --------------------------------------------------------------------------
# faber_download_with_retry <url> <output> [retries] [delay]
#
# Download a URL with retry logic. Tries curl first, falls back to wget.
# --------------------------------------------------------------------------
faber_download_with_retry() {
  local url="$1"
  local output="$2"
  local retries="${3:-3}"
  local delay="${4:-5}"

  for attempt in $(seq 1 "${retries}"); do
    if command -v curl &>/dev/null; then
      if curl -fsSL --retry 2 "${url}" -o "${output}"; then
        return 0
      fi
    elif command -v wget &>/dev/null; then
      if wget -q "${url}" -O "${output}"; then
        return 0
      fi
    else
      echo "ERROR: Neither curl nor wget is available."
      exit 1
    fi

    if [[ "${attempt}" -lt "${retries}" ]]; then
      echo "  Download failed (attempt ${attempt}/${retries}), retrying in ${delay}s..."
      sleep "${delay}"
    fi
  done

  echo "ERROR: Failed to download ${url} after ${retries} attempts."
  return 1
}
