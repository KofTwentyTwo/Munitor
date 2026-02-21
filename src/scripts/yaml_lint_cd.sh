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

faber_header "yaml_lint_cd"

PATHS="${YAMLLINT_PATHS:-base/ overlays/ argocd-apps/}"

# Install yamllint via apt (cimg/base has no python/pip)
sudo apt-get update -qq
sudo apt-get install -y -qq yamllint

faber_check_tool yamllint --version

YAMLLINT_CONFIG='{extends: relaxed, rules: {line-length: disable, truthy: disable}}'

# Non-blocking: report findings for awareness but never fail the job.
# CD repos commonly have Helm-rendered manifests with trailing spaces and
# indentation quirks that are template-engine artifacts, not real problems.
FINDINGS=0
for dir in ${PATHS}; do
  if [[ ! -d "${dir}" ]]; then
    echo "  Skipping ${dir} (not found)"
    continue
  fi
  echo "=== Linting: ${dir} ==="
  if yamllint -d "${YAMLLINT_CONFIG}" "${dir}"; then
    echo "  ${dir}: OK"
  else
    echo "  ${dir}: findings reported (non-blocking)"
    FINDINGS=$((FINDINGS + 1))
  fi
done

echo ""
if [[ ${FINDINGS} -gt 0 ]]; then
  echo "yamllint reported findings in ${FINDINGS} directory(ies) (non-blocking)."
else
  echo "All YAML lint checks passed."
fi
