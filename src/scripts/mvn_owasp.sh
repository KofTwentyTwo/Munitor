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

faber_header "mvn_owasp"
faber_check_tool mvn --version

MAX_RETRIES=3
RETRY_DELAY=30

echo "Running OWASP dependency check..."

NVD_KEY="${!NVD_API_KEY_VAR:-}"
NVD_ARGS=""
if [[ -n "${NVD_KEY}" ]]; then
  NVD_ARGS="-DnvdApiKey=${NVD_KEY}"
fi

run_owasp() {
  # shellcheck disable=SC2086
  mvn org.owasp:dependency-check-maven:check \
    ${NVD_ARGS} \
    -DdataDirectory="${HOME}/.dependency-check" \
    --batch-mode \
    --fail-at-end
}

for attempt in $(seq 1 ${MAX_RETRIES}); do
  echo "Attempt ${attempt}/${MAX_RETRIES}..."
  if run_owasp; then
    echo "OWASP dependency check complete."
    exit 0
  fi

  if [[ ${attempt} -lt ${MAX_RETRIES} ]]; then
    echo "OWASP check failed, cleaning H2 cache and retrying in ${RETRY_DELAY}s..."
    rm -f "${HOME}/.dependency-check/odc.mv.db" 2>/dev/null || true
    sleep ${RETRY_DELAY}
  fi
done

echo "ERROR: OWASP dependency check failed after ${MAX_RETRIES} attempts"
exit 1
