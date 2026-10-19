#!/usr/bin/env bash
set -euo pipefail

MUNITOR_HELPERS="${MUNITOR_HELPERS:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/munitor_helpers.sh}"
# shellcheck source=munitor_helpers.sh
if [[ -f "${MUNITOR_HELPERS}" ]]; then
  source "${MUNITOR_HELPERS}"
elif ! type munitor_header &>/dev/null; then
  munitor_header() { echo "=== Munitor: ${1:-unknown} ==="; }
fi
munitor_header "maven_workspace"

archive="${PWD}/.munitor-maven-installed.tgz"
repository="${HOME}/.m2/repository"
case "${MAVEN_WORKSPACE_ACTION:-restore}" in
  save)
    # Maven marks local installs with an empty repository ID (artifact>=).
    # Carry build outputs and mutable SNAPSHOT dependencies separately from the cache.
    files=$(mktemp)
    trap 'rm -f "${files}"' EXIT
    cd "${repository}"
    while IFS= read -r -d '' tracking; do
      if [[ "${tracking}" == */*-SNAPSHOT/_remote.repositories ]] ||
        grep -qE '^[^#].*>=[[:space:]]*$' "${tracking}"; then
        directory=$(dirname "${tracking}")
        printf '%s\0' "${directory}" >> "${files}"
        while [[ "${directory}" != . ]]; do
          directory=$(dirname "${directory}")
          if [[ -f "${directory}/maven-metadata-local.xml" ]]; then
            printf '%s\0' "${directory}/maven-metadata-local.xml" >> "${files}"
          fi
        done
      fi
    done < <(find . -name _remote.repositories -type f -print0)
    tar -czf "${archive}" --null -T "${files}"
    ;;
  restore)
    if [[ -f "${archive}" ]]; then
      mkdir -p "${repository}"
      tar -xzf "${archive}" -C "${repository}"
    fi
    ;;
  *)
    echo "ERROR: Unknown Maven workspace action." >&2
    exit 1
    ;;
esac
