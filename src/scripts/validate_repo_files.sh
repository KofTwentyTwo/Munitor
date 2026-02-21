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

munitor_header "validate_repo_files"

REQUIRED="${REQUIRED_FILES:-CODEOWNERS LICENSE README.md SECURITY.md}"

MISSING=()
WARNINGS=()

echo "Validating required repository files..."
echo "========================================"

# Check each required file
for file in ${REQUIRED}; do
  if [[ -f "${file}" ]]; then
    echo "[OK] ${file} exists"

    # Additional validation for specific files
    case "${file}" in
      CODEOWNERS|*/CODEOWNERS)
        # Check CODEOWNERS has at least one entry
        if ! grep -qE '^[^#]' "${file}" 2>/dev/null; then
          WARNINGS+=("${file} has no active entries (only comments)")
        fi
        ;;
      README.md|*/README.md)
        # Check README is not empty and has content beyond just a title
        lines=$(wc -l < "${file}" | tr -d ' ')
        if [[ "${lines}" -lt 5 ]]; then
          WARNINGS+=("${file} appears minimal (${lines} lines)")
        fi
        ;;
      SECURITY.md|*/SECURITY.md)
        # Check SECURITY.md has vulnerability reporting info
        if ! grep -qiE '(vulnerabilit|security|report|disclose)' "${file}" 2>/dev/null; then
          WARNINGS+=("${file} may be missing vulnerability reporting instructions")
        fi
        ;;
      LICENSE|*/LICENSE)
        # Check LICENSE is not empty
        if [[ ! -s "${file}" ]]; then
          WARNINGS+=("${file} is empty")
        fi
        ;;
    esac
  else
    echo "[MISSING] ${file}"
    MISSING+=("${file}")
  fi
done

# Check for .gitignore (common requirement)
if [[ -f ".gitignore" ]]; then
  echo "[OK] .gitignore exists"
else
  WARNINGS+=(".gitignore is missing (recommended)")
fi

# Check for .gitleaks.toml (security scanning config)
if [[ -f ".gitleaks.toml" ]]; then
  echo "[OK] .gitleaks.toml exists"
else
  WARNINGS+=(".gitleaks.toml is missing (recommended for secrets scanning)")
fi

echo ""
echo "========================================"

# Report warnings
if [[ ${#WARNINGS[@]} -gt 0 ]]; then
  echo ""
  echo "Warnings:"
  for warn in "${WARNINGS[@]}"; do
    echo "  - ${warn}"
  done
fi

# Fail if any required files are missing
if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo ""
  echo "ERROR: Missing required files:"
  for file in "${MISSING[@]}"; do
    echo "  - ${file}"
  done
  echo ""
  echo "Please add the missing files to comply with repository standards."
  exit 1
fi

echo ""
echo "All required repository files are present"
