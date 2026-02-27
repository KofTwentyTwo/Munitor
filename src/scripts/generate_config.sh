#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${MUNITOR_CONFIG:-.munitor.yml}"
OUTPUT_FILE="/tmp/generated-config.yml"

# When run via CircleCI << include() >>, BASH_SOURCE is empty.
# Fall back to MUNITOR_SCRIPT_DIR set by the command YAML.
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  SCRIPT_DIR="${MUNITOR_SCRIPT_DIR:-/tmp/munitor}"
fi
TEMPLATE_DIR="${SCRIPT_DIR}/templates"

# Source shared helpers
MUNITOR_HELPERS="${MUNITOR_HELPERS:-${SCRIPT_DIR}/munitor_helpers.sh}"
# shellcheck source=munitor_helpers.sh
if [[ -f "${MUNITOR_HELPERS}" ]]; then source "${MUNITOR_HELPERS}"
elif ! type munitor_header &>/dev/null; then
  munitor_header() { echo "=== Munitor: ${1:-unknown} ==="; }
  munitor_check_tool() { command -v "$1" &>/dev/null || { echo "ERROR: $1 not found"; exit 1; }; }
  munitor_download_with_retry() { curl -fsSL --retry 3 "$1" -o "$2"; }
fi

munitor_header "generate_config"
munitor_check_tool yq --version
munitor_check_tool envsubst --version

# Temp file cleanup trap
TEMP_FILES=()
cleanup() {
  for f in "${TEMP_FILES[@]}"; do
    rm -f "${f}" 2>/dev/null || true
  done
}
trap cleanup EXIT

# Source shared variable extraction
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/extract_munitor_vars.sh"

# --------------------------------------------------------------------------
# Read .munitor.yml
# --------------------------------------------------------------------------
if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "ERROR: Config file '${CONFIG_FILE}' not found."
  echo "Each repo must have a .munitor.yml in the root."
  exit 1
fi

PIPELINE_TYPE=$(yq '.pipeline' "${CONFIG_FILE}")

if [[ -z "${PIPELINE_TYPE}" || "${PIPELINE_TYPE}" == "null" ]]; then
  echo "ERROR: 'pipeline' field is required in ${CONFIG_FILE}."
  exit 1
fi

echo "Pipeline type: ${PIPELINE_TYPE}"

# --------------------------------------------------------------------------
# Validate required fields per pipeline type
# --------------------------------------------------------------------------
validate_required_fields() {
  local pipeline="$1"
  local config="$2"
  local missing=()

  # Global required fields (all pipeline types)
  [[ -z "$(yq '.orb_version // ""' "${config}")" ]] && missing+=("orb_version")

  case "${pipeline}" in
    java-webapp|node-api|node-webapp)
      [[ -z "$(yq '.image_name // ""' "${config}")" ]] && missing+=("image_name")
      [[ -z "$(yq '.docker.registry // ""' "${config}")" ]] && missing+=("docker.registry")
      ;;
    terraform)
      [[ -z "$(yq '.terraform.path // ""' "${config}")" ]] && missing+=("terraform.path")
      ;;
    validate-cd-repo)
      # No additional required fields beyond orb_version
      ;;
  esac

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: Missing required fields for pipeline '${pipeline}':"
    printf '  - %s\n' "${missing[@]}"
    return 1
  fi
}

validate_required_fields "${PIPELINE_TYPE}" "${CONFIG_FILE}"

# --------------------------------------------------------------------------
# Warn about unknown top-level keys (catches typos like java_verion)
# --------------------------------------------------------------------------
KNOWN_KEYS="pipeline orb_version image_name java_version node_version sonar docker cd coverage e2e sbom owasp contexts npm node services test terraform sast health kustomize kube_linter_config package_manager"
ACTUAL_KEYS=$(yq 'keys | .[]' "${CONFIG_FILE}" 2>/dev/null || true)
for key in ${ACTUAL_KEYS}; do
  if ! echo "${KNOWN_KEYS}" | grep -qw "${key}"; then
    echo "WARNING: Unknown key '${key}' in ${CONFIG_FILE} (possible typo?)"
  fi
done

# --------------------------------------------------------------------------
# Select template
# --------------------------------------------------------------------------
TEMPLATE_FILE="${TEMPLATE_DIR}/${PIPELINE_TYPE}.yml.tpl"

if [[ ! -f "${TEMPLATE_FILE}" ]]; then
  echo "ERROR: No template found for pipeline type '${PIPELINE_TYPE}'."
  echo "Available templates:"
  find "${TEMPLATE_DIR}" -maxdepth 1 -name '*.yml.tpl' -exec basename {} .yml.tpl \; 2>/dev/null | sed 's/^/  /'
  exit 1
fi

echo "Using template: ${TEMPLATE_FILE}"

# --------------------------------------------------------------------------
# Extract values from .munitor.yml and export for envsubst
# --------------------------------------------------------------------------
extract_munitor_vars "${CONFIG_FILE}"

# --------------------------------------------------------------------------
# Render template
# --------------------------------------------------------------------------

# Pre-pass: expand ##INCLUDE_DEPLOY <partial> <workflow> <branch> <cd_env>## markers
# Loads partial templates from templates/partials/ and substitutes placeholders
expand_includes() {
  local input="$1"
  local output="$2"
  local partials_dir="${TEMPLATE_DIR}/partials"
  local result
  result=$(mktemp)
  TEMP_FILES+=("${result}")

  cp "${input}" "${result}"

  while IFS= read -r line; do
    if [[ "${line}" =~ ^[[:space:]]*##INCLUDE_DEPLOY[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)##[[:space:]]*$ ]]; then
      local partial="${BASH_REMATCH[1]}"
      local workflow="${BASH_REMATCH[2]}"
      local branch="${BASH_REMATCH[3]}"
      local cd_env="${BASH_REMATCH[4]}"
      local partial_file="${partials_dir}/${partial}.yml.tpl"

      if [[ ! -f "${partial_file}" ]]; then
        echo "ERROR: Partial template '${partial_file}' not found." >&2
        return 1
      fi

      local expanded
      expanded=$(mktemp)
      TEMP_FILES+=("${expanded}")
      sed \
        -e "s/__WORKFLOW_NAME__/${workflow}/g" \
        -e "s/__BRANCH_FILTER__/${branch}/g" \
        -e "s/__CD_ENVIRONMENT__/${cd_env}/g" \
        "${partial_file}" > "${expanded}"

      # Replace the marker line with the expanded partial content
      local swap
      swap=$(mktemp)
      TEMP_FILES+=("${swap}")
      awk -v marker="${line}" -v file="${expanded}" '
        $0 == marker { while ((getline rep < file) > 0) print rep; next }
        { print }
      ' "${result}" > "${swap}"
      cp "${swap}" "${result}"
    fi
  done < "${input}"

  cp "${result}" "${output}"
}

STAGE0_FILE=$(mktemp)
TEMP_FILES+=("${STAGE0_FILE}")
expand_includes "${TEMPLATE_FILE}" "${STAGE0_FILE}"

# Get the list of envsubst variables to replace
ENVSUBST_VARS=$(get_envsubst_vars)

# First pass: envsubst for variable replacement
STAGE1_FILE=$(mktemp)
TEMP_FILES+=("${STAGE1_FILE}")
envsubst "${ENVSUBST_VARS}" < "${STAGE0_FILE}" > "${STAGE1_FILE}"

# Second pass: process conditional blocks
# Removes blocks wrapped in ##IF_<FLAG>## / ##ENDIF_<FLAG>## when flag is false
process_conditionals() {
  local input="$1"
  local output="$2"
  local tmpfile
  tmpfile=$(mktemp)
  TEMP_FILES+=("${tmpfile}")

  cp "${input}" "${tmpfile}"

  # Process each conditional flag
  for flag in E2E SBOM SONAR NPM_AUTH SERVICES TEST_SETUP CUSTOM_TEST COVERAGE_CMD GITHUB_RELEASE SAST CD OWASP NVD; do
    local var_name="MUNITOR_${flag}"
    local value="${!var_name:-false}"
    local flag_file
    flag_file=$(mktemp)
    TEMP_FILES+=("${flag_file}")

    if [[ "${value}" == "true" ]]; then
      # Keep the content, strip the markers
      sed "/^[[:space:]]*##IF_${flag}##[[:space:]]*$/d; /^[[:space:]]*##ENDIF_${flag}##[[:space:]]*$/d" "${tmpfile}" > "${flag_file}"
    else
      # Remove everything between markers (inclusive)
      awk "/^[[:space:]]*##IF_${flag}##[[:space:]]*$/{skip=1; next} /^[[:space:]]*##ENDIF_${flag}##[[:space:]]*$/{skip=0; next} !skip" "${tmpfile}" > "${flag_file}"
    fi

    cp "${flag_file}" "${tmpfile}"
  done

  cp "${tmpfile}" "${output}"
}

process_conditionals "${STAGE1_FILE}" "${OUTPUT_FILE}"

# Check for unprocessed conditional markers (indicates typo or unmatched pair)
STALE_MARKERS=$(grep -nE '##(IF|ENDIF)_[A-Z_]+##' "${OUTPUT_FILE}" || true)
if [[ -n "${STALE_MARKERS}" ]]; then
  echo "ERROR: Unprocessed conditional markers found in generated config:"
  echo "${STALE_MARKERS}"
  echo "This usually means a typo in a marker name or an unmatched IF/ENDIF pair."
  exit 1
fi

# Validate the generated YAML
if ! yq '.' "${OUTPUT_FILE}" > /dev/null 2>&1; then
  echo "ERROR: Generated config is not valid YAML"
  echo "Check template and conditional markers for mismatches"
  exit 1
fi

# Validate output file was actually created
if [[ ! -s "${OUTPUT_FILE}" ]]; then
  echo "ERROR: Generated config file is empty or missing at ${OUTPUT_FILE}."
  exit 1
fi

echo "Generated config written to: ${OUTPUT_FILE}"
echo "---"
head -20 "${OUTPUT_FILE}"
echo "..."
echo "($(wc -l < "${OUTPUT_FILE}") total lines)"
