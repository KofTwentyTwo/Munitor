#!/usr/bin/env bash
# Shared helper for extracting variables from .munitor.yml
# Source this file to get MUNITOR_* variables exported

set -euo pipefail

extract_munitor_vars() {
  local config_file="${1:-.munitor.yml}"

  if [[ ! -f "${config_file}" ]]; then
    echo "ERROR: Config file '${config_file}' not found." >&2
    return 1
  fi

  # --- Org defaults (overridable via .munitor.yml org section) ---
  local ORG_DOCKER_REGISTRY
  ORG_DOCKER_REGISTRY=$(yq '.org.docker_registry // "ghcr.io/KofTwentyTwo"' "${config_file}")
  local ORG_NPM_SCOPE
  ORG_NPM_SCOPE=$(yq '.org.npm_scope // "@koftwentytwo"' "${config_file}")
  local ORG_CI_EMAIL
  ORG_CI_EMAIL=$(yq '.org.ci_email // "munitor-ci@koftwentytwo.com"' "${config_file}")
  local ORG_CI_NAME
  ORG_CI_NAME=$(yq '.org.ci_name // "Munitor CI"' "${config_file}")
  local ORG_ORB_SLUG
  ORG_ORB_SLUG=$(yq '.org.orb_slug // "kof22/munitor"' "${config_file}")

  # Core pipeline settings
  MUNITOR_PIPELINE=$(yq '.pipeline' "${config_file}")
  MUNITOR_ORB_VERSION=$(yq '.orb_version // ""' "${config_file}")
  MUNITOR_IMAGE_NAME=$(yq '.image_name // ""' "${config_file}")
  MUNITOR_JAVA_VERSION=$(yq '.java_version // "21"' "${config_file}")
  MUNITOR_SERVER_MODULE=$(yq '.server_module // ""' "${config_file}")
  MUNITOR_NODE_VERSION=$(yq '.node_version // "20"' "${config_file}")
  MUNITOR_SONAR_PROJECT_KEY=$(yq '.sonar.project_key // ""' "${config_file}")
  MUNITOR_DOCKER_REGISTRY=$(yq '.docker.registry // ""' "${config_file}")
  if [[ -z "${MUNITOR_DOCKER_REGISTRY}" || "${MUNITOR_DOCKER_REGISTRY}" == "null" ]]; then
    MUNITOR_DOCKER_REGISTRY="${ORG_DOCKER_REGISTRY}"
  fi
  MUNITOR_CD_REPO=$(yq '.cd.repo // ""' "${config_file}")
  MUNITOR_CD_FORMAT=$(yq '.cd.format // "helm"' "${config_file}")
  MUNITOR_CD_ENV_DEVELOP=$(yq '.cd.env.develop // "develop"' "${config_file}")
  MUNITOR_CD_ENV_STAGING=$(yq '.cd.env.staging // "staging"' "${config_file}")
  MUNITOR_CD_ENV_PROD=$(yq '.cd.env.prod // "prod"' "${config_file}")
  MUNITOR_CD_ENV_RELEASE=$(yq '.cd.env.release // "staging"' "${config_file}")
  MUNITOR_COVERAGE_MIN=$(yq '.coverage.min_instruction // "70"' "${config_file}")
  MUNITOR_E2E=$(yq '.e2e // false' "${config_file}")
  MUNITOR_SBOM=$(yq '.sbom // false' "${config_file}")
  MUNITOR_OWASP=$(yq '.owasp' "${config_file}")
  if [[ "${MUNITOR_OWASP}" == "null" ]]; then
    MUNITOR_OWASP="true"
  fi

  # Contexts
  MUNITOR_CONTEXT_REGISTRY=$(yq '.contexts.registry // ""' "${config_file}")
  MUNITOR_CONTEXT_GITHUB=$(yq '.contexts.github // ""' "${config_file}")
  MUNITOR_CONTEXT_SONAR=$(yq '.contexts.sonar // ""' "${config_file}")
  MUNITOR_CONTEXT_NVD=$(yq '.contexts.nvd // ""' "${config_file}")

  # GitHub Release: auto-enabled when contexts.github is present
  if [[ -n "${MUNITOR_CONTEXT_GITHUB}" ]]; then
    MUNITOR_GITHUB_RELEASE="true"
  else
    MUNITOR_GITHUB_RELEASE="false"
  fi

  # Node-api extended features
  MUNITOR_NPM_AUTH=$(yq '.npm.private_registry // false' "${config_file}")
  MUNITOR_NPM_SCOPES=$(yq -o=json -I=0 '.npm.scopes // []' "${config_file}")
  MUNITOR_SERVICES_JSON=$(yq '.services // [] | tojson' "${config_file}")
  if [[ "${MUNITOR_SERVICES_JSON}" == "[]" ]]; then
    MUNITOR_SERVICES="false"
  else
    MUNITOR_SERVICES="true"
  fi
  MUNITOR_TEST_SETUP_SCRIPT=$(yq '.test.setup // ""' "${config_file}")
  if [[ -n "${MUNITOR_TEST_SETUP_SCRIPT}" ]]; then
    MUNITOR_TEST_SETUP="true"
  else
    MUNITOR_TEST_SETUP="false"
  fi
  MUNITOR_TEST_COMMANDS_JSON=$(yq '.test.commands // [] | tojson' "${config_file}")
  if [[ "${MUNITOR_TEST_COMMANDS_JSON}" == "[]" ]]; then
    MUNITOR_CUSTOM_TEST="false"
  else
    MUNITOR_CUSTOM_TEST="true"
  fi
  MUNITOR_COVERAGE_TOOL=$(yq '.test.coverage.tool // "jest"' "${config_file}")
  MUNITOR_COVERAGE_COMMAND=$(yq '.test.coverage.command // ""' "${config_file}")
  if [[ -n "${MUNITOR_COVERAGE_COMMAND}" ]]; then
    MUNITOR_COVERAGE_CMD="true"
  else
    MUNITOR_COVERAGE_CMD="false"
  fi
  # Allow test.coverage.min_instruction to override coverage.min_instruction
  MUNITOR_TEST_COVERAGE_MIN=$(yq '.test.coverage.min_instruction // ""' "${config_file}")
  if [[ -n "${MUNITOR_TEST_COVERAGE_MIN}" ]]; then
    MUNITOR_COVERAGE_MIN="${MUNITOR_TEST_COVERAGE_MIN}"
  fi

  # Terraform pipeline settings
  MUNITOR_TF_PATH=$(yq '.terraform.path // "terraform/"' "${config_file}")
  MUNITOR_TF_LIVE_PATH=$(yq '.terraform.live_path // "terraform/live"' "${config_file}")
  MUNITOR_TF_ENVIRONMENTS=$(yq '.terraform.environments // ["production"] | join(" ")' "${config_file}")
  MUNITOR_CHECKOV_SKIP=$(yq '.terraform.checkov_skip // ""' "${config_file}")
  # Kustomize / CD repo validation settings
  MUNITOR_KUSTOMIZE_VERSION=$(yq '.kustomize.version // "5.5.0"' "${config_file}")
  # Use 'has' check so explicit base_path: "" is preserved (yq // treats "" as falsy)
  if yq -e '.kustomize.base_path != null' "${config_file}" &>/dev/null; then
    MUNITOR_KUSTOMIZE_BASE_PATH=$(yq '.kustomize.base_path' "${config_file}")
  else
    MUNITOR_KUSTOMIZE_BASE_PATH="base/"
  fi
  MUNITOR_KUSTOMIZE_LOAD_RESTRICTOR=$(yq '.kustomize.load_restrictor // "true"' "${config_file}")
  MUNITOR_KUSTOMIZE_SCAN_OVERLAY=$(yq '.kustomize.scan_overlay // "production"' "${config_file}")
  MUNITOR_KUSTOMIZE_OVERLAYS=$(yq '.kustomize.overlays // [] | join(" ")' "${config_file}")
  MUNITOR_KUSTOMIZE_OVERLAY_DIR=$(yq '.kustomize.overlay_dir // "overlays"' "${config_file}")
  MUNITOR_KUBE_LINTER_CONFIG=$(yq '.kube_linter_config // ""' "${config_file}")
  MUNITOR_YAMLLINT_PATHS=$(yq '.yamllint_paths // ""' "${config_file}")
  if [[ -z "${MUNITOR_YAMLLINT_PATHS}" || "${MUNITOR_YAMLLINT_PATHS}" == "null" ]]; then
    case "${MUNITOR_PIPELINE}" in
      argocd-apps) MUNITOR_YAMLLINT_PATHS="bootstrap/ projects/ credentials/ envs/ apps/ infra/" ;;
      *) MUNITOR_YAMLLINT_PATHS="base/ overlays/ argocd-apps/" ;;
    esac
  fi

  # SAST: supports boolean (true/false) or object form (sast: { fail_on_findings: false })
  local sast_raw
  sast_raw=$(yq '.sast' "${config_file}")
  case "${sast_raw}" in
    true)
      MUNITOR_SAST="true"
      MUNITOR_SAST_FAIL_ON_FINDINGS="true"
      ;;
    false|null)
      MUNITOR_SAST="false"
      MUNITOR_SAST_FAIL_ON_FINDINGS="true"
      ;;
    *)
      # Object form: sast is present as a map, so SAST is enabled
      MUNITOR_SAST="true"
      local fof
      fof=$(yq '.sast.fail_on_findings' "${config_file}")
      if [[ "${fof}" == "false" ]]; then
        MUNITOR_SAST_FAIL_ON_FINDINGS="false"
      else
        MUNITOR_SAST_FAIL_ON_FINDINGS="true"
      fi
      ;;
  esac

  # Node framework (nextjs or express)
  MUNITOR_NODE_FRAMEWORK=$(yq '.node.framework // "nextjs"' "${config_file}")

  # Package manager (npm, yarn, pnpm)
  MUNITOR_PACKAGE_MANAGER=$(yq '.package_manager // "npm"' "${config_file}")

  # Org-level variables (derived from defaults block)
  MUNITOR_CI_EMAIL="${ORG_CI_EMAIL}"
  MUNITOR_CI_NAME="${ORG_CI_NAME}"
  MUNITOR_NPM_DEFAULT_SCOPE="${ORG_NPM_SCOPE}"
  MUNITOR_ORB_SLUG="${ORG_ORB_SLUG}"

  # Health check settings
  MUNITOR_HEALTH_PATH=$(yq '.health.path // "/api/health"' "${config_file}")
  MUNITOR_HEALTH_PORT=$(yq '.health.port // ""' "${config_file}")
  if [[ -z "${MUNITOR_HEALTH_PORT}" || "${MUNITOR_HEALTH_PORT}" == "null" ]]; then
    case "${MUNITOR_PIPELINE}" in
      node-api|node-webapp) MUNITOR_HEALTH_PORT="3000" ;;
      *) MUNITOR_HEALTH_PORT="8080" ;;
    esac
  fi
  MUNITOR_HEALTH_DB=$(yq '.health.db // false' "${config_file}")
  MUNITOR_HEALTH_MIGRATIONS=$(yq '.health.migrations // ""' "${config_file}")
  if [[ "${MUNITOR_HEALTH_MIGRATIONS}" == "null" ]]; then MUNITOR_HEALTH_MIGRATIONS=""; fi
  MUNITOR_HEALTH_SMOKE_PATHS=$(yq '.health.smoke_paths // [] | join(",")' "${config_file}")
  if [[ "${MUNITOR_HEALTH_SMOKE_PATHS}" == "null" ]]; then MUNITOR_HEALTH_SMOKE_PATHS=""; fi

  # Supplemental images (e.g., migrations, db-backup)
  MUNITOR_SUPPLEMENTAL_IMAGES_JSON=$(yq -o=json -I=0 '.supplemental_images // []' "${config_file}")
  if [[ "${MUNITOR_SUPPLEMENTAL_IMAGES_JSON}" == "[]" || "${MUNITOR_SUPPLEMENTAL_IMAGES_JSON}" == "null" ]]; then
    MUNITOR_SUPPLEMENTAL="false"
    MUNITOR_SUPPLEMENTAL_IMAGES_JSON="[]"
  else
    MUNITOR_SUPPLEMENTAL="true"
  fi

  # Derived flags
  if [[ -n "${MUNITOR_SONAR_PROJECT_KEY}" ]]; then
    MUNITOR_SONAR="true"
  else
    MUNITOR_SONAR="false"
  fi

  if [[ -n "${MUNITOR_CD_REPO}" ]]; then
    MUNITOR_CD="true"
  else
    MUNITOR_CD="false"
  fi

  if [[ -n "${MUNITOR_CONTEXT_NVD}" ]]; then
    MUNITOR_NVD="true"
  else
    MUNITOR_NVD="false"
  fi

  # Export all variables
  export MUNITOR_PIPELINE MUNITOR_ORB_VERSION MUNITOR_IMAGE_NAME MUNITOR_JAVA_VERSION MUNITOR_NODE_VERSION MUNITOR_SERVER_MODULE
  export MUNITOR_SONAR_PROJECT_KEY MUNITOR_DOCKER_REGISTRY MUNITOR_CD_REPO MUNITOR_CD_FORMAT
  export MUNITOR_CD_ENV_DEVELOP MUNITOR_CD_ENV_STAGING MUNITOR_CD_ENV_PROD MUNITOR_CD_ENV_RELEASE
  export MUNITOR_COVERAGE_MIN MUNITOR_E2E MUNITOR_SBOM MUNITOR_OWASP
  export MUNITOR_CONTEXT_REGISTRY MUNITOR_CONTEXT_GITHUB MUNITOR_CONTEXT_SONAR MUNITOR_CONTEXT_NVD
  export MUNITOR_GITHUB_RELEASE
  export MUNITOR_NPM_AUTH MUNITOR_NPM_SCOPES
  export MUNITOR_SERVICES MUNITOR_SERVICES_JSON
  export MUNITOR_TEST_SETUP MUNITOR_TEST_SETUP_SCRIPT
  export MUNITOR_CUSTOM_TEST MUNITOR_TEST_COMMANDS_JSON
  export MUNITOR_COVERAGE_TOOL MUNITOR_COVERAGE_CMD MUNITOR_COVERAGE_COMMAND
  export MUNITOR_TF_PATH MUNITOR_TF_LIVE_PATH MUNITOR_TF_ENVIRONMENTS MUNITOR_CHECKOV_SKIP MUNITOR_SAST MUNITOR_SAST_FAIL_ON_FINDINGS
  export MUNITOR_KUSTOMIZE_VERSION MUNITOR_KUSTOMIZE_BASE_PATH MUNITOR_KUSTOMIZE_LOAD_RESTRICTOR
  export MUNITOR_KUSTOMIZE_SCAN_OVERLAY MUNITOR_KUSTOMIZE_OVERLAYS MUNITOR_KUSTOMIZE_OVERLAY_DIR
  export MUNITOR_KUBE_LINTER_CONFIG MUNITOR_YAMLLINT_PATHS
  export MUNITOR_NODE_FRAMEWORK MUNITOR_PACKAGE_MANAGER
  export MUNITOR_CI_EMAIL MUNITOR_CI_NAME MUNITOR_NPM_DEFAULT_SCOPE MUNITOR_ORB_SLUG
  export MUNITOR_HEALTH_PATH MUNITOR_HEALTH_PORT MUNITOR_HEALTH_DB MUNITOR_HEALTH_MIGRATIONS MUNITOR_HEALTH_SMOKE_PATHS
  export MUNITOR_SUPPLEMENTAL MUNITOR_SUPPLEMENTAL_IMAGES_JSON
  export MUNITOR_SONAR MUNITOR_CD MUNITOR_NVD
}

# Build the envsubst variable list
get_envsubst_vars() {
  # shellcheck disable=SC2016
  echo '${MUNITOR_PIPELINE} ${MUNITOR_ORB_VERSION} ${MUNITOR_IMAGE_NAME} ${MUNITOR_JAVA_VERSION} ${MUNITOR_NODE_VERSION} ${MUNITOR_SONAR_PROJECT_KEY} ${MUNITOR_DOCKER_REGISTRY} ${MUNITOR_CD_REPO} ${MUNITOR_CD_FORMAT} ${MUNITOR_CD_ENV_DEVELOP} ${MUNITOR_CD_ENV_STAGING} ${MUNITOR_CD_ENV_PROD} ${MUNITOR_CD_ENV_RELEASE} ${MUNITOR_COVERAGE_MIN} ${MUNITOR_E2E} ${MUNITOR_SBOM} ${MUNITOR_OWASP} ${MUNITOR_CONTEXT_REGISTRY} ${MUNITOR_CONTEXT_GITHUB} ${MUNITOR_CONTEXT_SONAR} ${MUNITOR_CONTEXT_NVD} ${MUNITOR_NPM_AUTH} ${MUNITOR_NPM_SCOPES} ${MUNITOR_SERVICES_JSON} ${MUNITOR_TEST_SETUP_SCRIPT} ${MUNITOR_TEST_COMMANDS_JSON} ${MUNITOR_COVERAGE_TOOL} ${MUNITOR_COVERAGE_COMMAND} ${MUNITOR_GITHUB_RELEASE} ${MUNITOR_SAST} ${MUNITOR_SAST_FAIL_ON_FINDINGS} ${MUNITOR_HEALTH_PATH} ${MUNITOR_HEALTH_PORT} ${MUNITOR_HEALTH_DB} ${MUNITOR_HEALTH_MIGRATIONS} ${MUNITOR_HEALTH_SMOKE_PATHS} ${MUNITOR_TF_PATH} ${MUNITOR_TF_LIVE_PATH} ${MUNITOR_TF_ENVIRONMENTS} ${MUNITOR_CHECKOV_SKIP} ${MUNITOR_KUSTOMIZE_VERSION} ${MUNITOR_KUSTOMIZE_BASE_PATH} ${MUNITOR_KUSTOMIZE_LOAD_RESTRICTOR} ${MUNITOR_KUSTOMIZE_SCAN_OVERLAY} ${MUNITOR_KUSTOMIZE_OVERLAYS} ${MUNITOR_KUSTOMIZE_OVERLAY_DIR} ${MUNITOR_KUBE_LINTER_CONFIG} ${MUNITOR_YAMLLINT_PATHS} ${MUNITOR_CI_EMAIL} ${MUNITOR_CI_NAME} ${MUNITOR_NPM_DEFAULT_SCOPE} ${MUNITOR_ORB_SLUG} ${MUNITOR_PACKAGE_MANAGER} ${MUNITOR_SUPPLEMENTAL_IMAGES_JSON} ${MUNITOR_SERVER_MODULE}'
}
