#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
FIXTURES_DIR="${SCRIPT_DIR}/fixtures"
PASS=0
FAIL=0

# Source the helper under test
# shellcheck disable=SC1091
source "${PROJECT_DIR}/src/scripts/extract_munitor_vars.sh"

# --------------------------------------------------------------------------
# Test helpers
# --------------------------------------------------------------------------
assert_eq() {
  local name="$1" expected="$2" actual="$3"
  echo -n "  TEST: ${name}... "
  if [[ "${actual}" == "${expected}" ]]; then
    echo "PASS"
    PASS=$((PASS + 1))
  else
    echo "FAIL (expected '${expected}', got '${actual}')"
    FAIL=$((FAIL + 1))
  fi
}

# --------------------------------------------------------------------------
# java-webapp full fixture
# --------------------------------------------------------------------------
echo "=== extract_munitor_vars: java-webapp fixture ==="
extract_munitor_vars "${FIXTURES_DIR}/java-webapp.munitor.yml"

assert_eq "pipeline type" "java-webapp" "${MUNITOR_PIPELINE}"
assert_eq "image_name" "me-health-portal" "${MUNITOR_IMAGE_NAME}"
assert_eq "java_version" "21" "${MUNITOR_JAVA_VERSION}"
assert_eq "sonar project_key" "dmdbrands_me-health-portal" "${MUNITOR_SONAR_PROJECT_KEY}"
assert_eq "sonar flag" "true" "${MUNITOR_SONAR}"
assert_eq "docker registry" "ghcr.io/dmdbrands" "${MUNITOR_DOCKER_REGISTRY}"
assert_eq "cd repo" "dmdbrands/me-health-portal-cd-pipeline" "${MUNITOR_CD_REPO}"
assert_eq "cd flag" "true" "${MUNITOR_CD}"
assert_eq "coverage min" "80" "${MUNITOR_COVERAGE_MIN}"
assert_eq "e2e" "true" "${MUNITOR_E2E}"
assert_eq "sbom" "true" "${MUNITOR_SBOM}"
assert_eq "context registry" "ghcr" "${MUNITOR_CONTEXT_REGISTRY}"
assert_eq "context github" "github" "${MUNITOR_CONTEXT_GITHUB}"
assert_eq "context sonar" "sonarcloud" "${MUNITOR_CONTEXT_SONAR}"
assert_eq "context nvd" "nvd" "${MUNITOR_CONTEXT_NVD}"
assert_eq "github_release flag (has github context)" "true" "${MUNITOR_GITHUB_RELEASE}"
assert_eq "cd env release default" "staging" "${MUNITOR_CD_ENV_RELEASE}"
assert_eq "ci_email default" "munitor-ci@koftwentytwo.com" "${MUNITOR_CI_EMAIL}"
assert_eq "ci_name default" "Munitor CI" "${MUNITOR_CI_NAME}"
assert_eq "npm_default_scope" "@koftwentytwo" "${MUNITOR_NPM_DEFAULT_SCOPE}"
assert_eq "orb_slug" "kof22/munitor" "${MUNITOR_ORB_SLUG}"

# --------------------------------------------------------------------------
# node-api-minimal fixture (tests defaults)
# --------------------------------------------------------------------------
echo ""
echo "=== extract_munitor_vars: node-api-minimal fixture ==="
extract_munitor_vars "${FIXTURES_DIR}/node-api-minimal.munitor.yml"

assert_eq "pipeline type" "node-api" "${MUNITOR_PIPELINE}"
assert_eq "node_version" "22" "${MUNITOR_NODE_VERSION}"
assert_eq "sonar flag (no sonar)" "false" "${MUNITOR_SONAR}"
assert_eq "sonar key empty" "" "${MUNITOR_SONAR_PROJECT_KEY}"
assert_eq "e2e" "false" "${MUNITOR_E2E}"
assert_eq "sbom" "false" "${MUNITOR_SBOM}"
assert_eq "npm_auth default" "false" "${MUNITOR_NPM_AUTH}"
assert_eq "npm_scopes default" "[]" "${MUNITOR_NPM_SCOPES}"
assert_eq "services flag default" "false" "${MUNITOR_SERVICES}"
assert_eq "test_setup flag default" "false" "${MUNITOR_TEST_SETUP}"
assert_eq "custom_test flag default" "false" "${MUNITOR_CUSTOM_TEST}"
assert_eq "coverage_tool default" "jest" "${MUNITOR_COVERAGE_TOOL}"
assert_eq "coverage_cmd flag default" "false" "${MUNITOR_COVERAGE_CMD}"
assert_eq "github_release flag (has github context)" "true" "${MUNITOR_GITHUB_RELEASE}"
assert_eq "coverage min default" "70" "${MUNITOR_COVERAGE_MIN}"

# --------------------------------------------------------------------------
# node-api-services fixture (all node extensions enabled)
# --------------------------------------------------------------------------
echo ""
echo "=== extract_munitor_vars: node-api-services fixture ==="
extract_munitor_vars "${FIXTURES_DIR}/node-api-services.munitor.yml"

assert_eq "npm_auth" "true" "${MUNITOR_NPM_AUTH}"
assert_eq "npm_scopes" '["@greatergoods"]' "${MUNITOR_NPM_SCOPES}"
assert_eq "services flag" "true" "${MUNITOR_SERVICES}"
assert_eq "services JSON not empty" "true" "$([[ "${MUNITOR_SERVICES_JSON}" != "[]" ]] && echo true || echo false)"
assert_eq "test_setup flag" "true" "${MUNITOR_TEST_SETUP}"
assert_eq "test_setup script" "scripts/ci-setup.sh" "${MUNITOR_TEST_SETUP_SCRIPT}"
assert_eq "custom_test flag" "true" "${MUNITOR_CUSTOM_TEST}"
assert_eq "coverage_tool" "nyc" "${MUNITOR_COVERAGE_TOOL}"
assert_eq "coverage_cmd flag" "true" "${MUNITOR_COVERAGE_CMD}"
assert_eq "coverage_command" "npm run coverage" "${MUNITOR_COVERAGE_COMMAND}"
assert_eq "coverage min override" "70" "${MUNITOR_COVERAGE_MIN}"

# --------------------------------------------------------------------------
# terraform fixture
# --------------------------------------------------------------------------
echo ""
echo "=== extract_munitor_vars: terraform fixture ==="
extract_munitor_vars "${FIXTURES_DIR}/terraform.munitor.yml"

assert_eq "pipeline type" "terraform" "${MUNITOR_PIPELINE}"
assert_eq "tf_path" "terraform/" "${MUNITOR_TF_PATH}"
assert_eq "tf_live_path" "terraform/live" "${MUNITOR_TF_LIVE_PATH}"
assert_eq "tf_environments" "production staging dev" "${MUNITOR_TF_ENVIRONMENTS}"
assert_eq "checkov_skip" "CKV_AWS_144,CKV_AWS_145,CKV2_AWS_6" "${MUNITOR_CHECKOV_SKIP}"
assert_eq "sast" "false" "${MUNITOR_SAST}"
assert_eq "docker_registry default" "ghcr.io/KofTwentyTwo" "${MUNITOR_DOCKER_REGISTRY}"

# --------------------------------------------------------------------------
# SAST fail_on_findings (default, boolean true, boolean false, object form)
# --------------------------------------------------------------------------
echo ""
echo "=== extract_munitor_vars: SAST fail_on_findings ==="

# Default: no sast key -> SAST=false, FAIL_ON_FINDINGS=true
extract_munitor_vars "${FIXTURES_DIR}/node-api-minimal.munitor.yml"
assert_eq "sast default (no key)" "false" "${MUNITOR_SAST}"
assert_eq "sast fail_on_findings default" "true" "${MUNITOR_SAST_FAIL_ON_FINDINGS}"

# Boolean true: sast: true -> SAST=true, FAIL_ON_FINDINGS=true
extract_munitor_vars "${FIXTURES_DIR}/terraform-sast.munitor.yml"
assert_eq "sast boolean true" "true" "${MUNITOR_SAST}"
assert_eq "sast fail_on_findings (boolean true)" "true" "${MUNITOR_SAST_FAIL_ON_FINDINGS}"

# Boolean false: sast: false -> SAST=false, FAIL_ON_FINDINGS=true
extract_munitor_vars "${FIXTURES_DIR}/terraform.munitor.yml"
assert_eq "sast boolean false" "false" "${MUNITOR_SAST}"
assert_eq "sast fail_on_findings (boolean false)" "true" "${MUNITOR_SAST_FAIL_ON_FINDINGS}"

# Object form: sast: { fail_on_findings: false } -> SAST=true, FAIL_ON_FINDINGS=false
extract_munitor_vars "${FIXTURES_DIR}/java-webapp-sast-warn.munitor.yml"
assert_eq "sast object form" "true" "${MUNITOR_SAST}"
assert_eq "sast fail_on_findings (object false)" "false" "${MUNITOR_SAST_FAIL_ON_FINDINGS}"

# --------------------------------------------------------------------------
# node.framework defaults
# --------------------------------------------------------------------------
echo ""
echo "=== extract_munitor_vars: node.framework ==="

extract_munitor_vars "${FIXTURES_DIR}/node-api-minimal.munitor.yml"
assert_eq "node_framework default" "nextjs" "${MUNITOR_NODE_FRAMEWORK}"

# --------------------------------------------------------------------------
# validate-cd-repo full fixture
# --------------------------------------------------------------------------
echo ""
echo "=== extract_munitor_vars: validate-cd-repo fixture ==="
extract_munitor_vars "${FIXTURES_DIR}/validate-cd-repo.munitor.yml"

assert_eq "pipeline type" "validate-cd-repo" "${MUNITOR_PIPELINE}"
assert_eq "kustomize_version" "5.5.0" "${MUNITOR_KUSTOMIZE_VERSION}"
assert_eq "kustomize_base_path" "base/" "${MUNITOR_KUSTOMIZE_BASE_PATH}"
assert_eq "kustomize_load_restrictor" "true" "${MUNITOR_KUSTOMIZE_LOAD_RESTRICTOR}"
assert_eq "kustomize_scan_overlay" "production" "${MUNITOR_KUSTOMIZE_SCAN_OVERLAY}"
assert_eq "kustomize_overlays" "dev staging production" "${MUNITOR_KUSTOMIZE_OVERLAYS}"
assert_eq "kube_linter_config" ".kube-linter.yaml" "${MUNITOR_KUBE_LINTER_CONFIG}"
assert_eq "yamllint_paths" "base/ overlays/ argocd-apps/" "${MUNITOR_YAMLLINT_PATHS}"

# --------------------------------------------------------------------------
# validate-cd-repo minimal fixture (tests defaults)
# --------------------------------------------------------------------------
echo ""
echo "=== extract_munitor_vars: validate-cd-repo-minimal fixture ==="
extract_munitor_vars "${FIXTURES_DIR}/validate-cd-repo-minimal.munitor.yml"

assert_eq "pipeline type" "validate-cd-repo" "${MUNITOR_PIPELINE}"
assert_eq "kustomize_version default" "5.5.0" "${MUNITOR_KUSTOMIZE_VERSION}"
assert_eq "kustomize_base_path default" "base/" "${MUNITOR_KUSTOMIZE_BASE_PATH}"
assert_eq "kustomize_load_restrictor default" "true" "${MUNITOR_KUSTOMIZE_LOAD_RESTRICTOR}"
assert_eq "kustomize_scan_overlay default" "production" "${MUNITOR_KUSTOMIZE_SCAN_OVERLAY}"
assert_eq "kustomize_overlays default (empty)" "" "${MUNITOR_KUSTOMIZE_OVERLAYS}"
assert_eq "kube_linter_config default (empty)" "" "${MUNITOR_KUBE_LINTER_CONFIG}"
assert_eq "yamllint_paths default" "base/ overlays/ argocd-apps/" "${MUNITOR_YAMLLINT_PATHS}"

# --------------------------------------------------------------------------
# argocd-apps full fixture
# --------------------------------------------------------------------------
echo ""
echo "=== extract_munitor_vars: argocd-apps fixture ==="
extract_munitor_vars "${FIXTURES_DIR}/argocd-apps.munitor.yml"

assert_eq "pipeline type" "argocd-apps" "${MUNITOR_PIPELINE}"
assert_eq "kustomize_version" "5.5.0" "${MUNITOR_KUSTOMIZE_VERSION}"
assert_eq "kustomize_base_path (empty)" "" "${MUNITOR_KUSTOMIZE_BASE_PATH}"
assert_eq "kustomize_overlay_dir" "envs" "${MUNITOR_KUSTOMIZE_OVERLAY_DIR}"
assert_eq "kustomize_load_restrictor" "true" "${MUNITOR_KUSTOMIZE_LOAD_RESTRICTOR}"
assert_eq "kustomize_scan_overlay" "production" "${MUNITOR_KUSTOMIZE_SCAN_OVERLAY}"
assert_eq "kustomize_overlays" "dev staging production" "${MUNITOR_KUSTOMIZE_OVERLAYS}"
assert_eq "kube_linter_config" ".kube-linter.yaml" "${MUNITOR_KUBE_LINTER_CONFIG}"
assert_eq "yamllint_paths (argocd-apps default)" "bootstrap/ projects/ credentials/ envs/ apps/ infra/" "${MUNITOR_YAMLLINT_PATHS}"

# --------------------------------------------------------------------------
# argocd-apps minimal fixture (tests defaults)
# --------------------------------------------------------------------------
echo ""
echo "=== extract_munitor_vars: argocd-apps-minimal fixture ==="
extract_munitor_vars "${FIXTURES_DIR}/argocd-apps-minimal.munitor.yml"

assert_eq "pipeline type" "argocd-apps" "${MUNITOR_PIPELINE}"
assert_eq "kustomize_version default" "5.5.0" "${MUNITOR_KUSTOMIZE_VERSION}"
assert_eq "kustomize_base_path default" "base/" "${MUNITOR_KUSTOMIZE_BASE_PATH}"
assert_eq "kustomize_overlay_dir default" "overlays" "${MUNITOR_KUSTOMIZE_OVERLAY_DIR}"
assert_eq "kustomize_load_restrictor default" "true" "${MUNITOR_KUSTOMIZE_LOAD_RESTRICTOR}"
assert_eq "kustomize_scan_overlay default" "production" "${MUNITOR_KUSTOMIZE_SCAN_OVERLAY}"
assert_eq "kustomize_overlays default (empty)" "" "${MUNITOR_KUSTOMIZE_OVERLAYS}"
assert_eq "kube_linter_config default (empty)" "" "${MUNITOR_KUBE_LINTER_CONFIG}"
assert_eq "yamllint_paths (argocd-apps default)" "bootstrap/ projects/ credentials/ envs/ apps/ infra/" "${MUNITOR_YAMLLINT_PATHS}"

# --------------------------------------------------------------------------
# Regression: validate-cd-repo overlay_dir and yamllint_paths unchanged
# --------------------------------------------------------------------------
echo ""
echo "=== extract_munitor_vars: validate-cd-repo regression guard ==="
extract_munitor_vars "${FIXTURES_DIR}/validate-cd-repo.munitor.yml"

assert_eq "validate-cd-repo overlay_dir default" "overlays" "${MUNITOR_KUSTOMIZE_OVERLAY_DIR}"
assert_eq "validate-cd-repo yamllint_paths unchanged" "base/ overlays/ argocd-apps/" "${MUNITOR_YAMLLINT_PATHS}"

# --------------------------------------------------------------------------
# node-webapp full fixture
# --------------------------------------------------------------------------
echo ""
echo "=== extract_munitor_vars: node-webapp fixture ==="
extract_munitor_vars "${FIXTURES_DIR}/node-webapp.munitor.yml"

assert_eq "pipeline type" "node-webapp" "${MUNITOR_PIPELINE}"
assert_eq "image_name" "website-frontend" "${MUNITOR_IMAGE_NAME}"
assert_eq "node_version" "22" "${MUNITOR_NODE_VERSION}"
assert_eq "sonar project_key" "koftwentytwo_website-frontend" "${MUNITOR_SONAR_PROJECT_KEY}"
assert_eq "sonar flag" "true" "${MUNITOR_SONAR}"
assert_eq "docker registry" "ghcr.io/KofTwentyTwo" "${MUNITOR_DOCKER_REGISTRY}"
assert_eq "cd repo" "KofTwentyTwo/website-cd-pipeline" "${MUNITOR_CD_REPO}"
assert_eq "cd flag" "true" "${MUNITOR_CD}"
assert_eq "coverage min" "80" "${MUNITOR_COVERAGE_MIN}"
assert_eq "e2e" "true" "${MUNITOR_E2E}"
assert_eq "sbom" "true" "${MUNITOR_SBOM}"
assert_eq "health_port default 3000" "3000" "${MUNITOR_HEALTH_PORT}"
assert_eq "health_path" "/api/health" "${MUNITOR_HEALTH_PATH}"
assert_eq "package_manager default" "npm" "${MUNITOR_PACKAGE_MANAGER}"
assert_eq "sast object form" "true" "${MUNITOR_SAST}"
assert_eq "sast fail_on_findings (object false)" "false" "${MUNITOR_SAST_FAIL_ON_FINDINGS}"

# --------------------------------------------------------------------------
# node-webapp-minimal fixture (tests defaults)
# --------------------------------------------------------------------------
echo ""
echo "=== extract_munitor_vars: node-webapp-minimal fixture ==="
extract_munitor_vars "${FIXTURES_DIR}/node-webapp-minimal.munitor.yml"

assert_eq "pipeline type" "node-webapp" "${MUNITOR_PIPELINE}"
assert_eq "node_version" "22" "${MUNITOR_NODE_VERSION}"
assert_eq "image_name" "simple-webapp" "${MUNITOR_IMAGE_NAME}"
assert_eq "sonar flag (no sonar)" "false" "${MUNITOR_SONAR}"
assert_eq "e2e" "false" "${MUNITOR_E2E}"
assert_eq "sbom" "false" "${MUNITOR_SBOM}"
assert_eq "health_port default 3000" "3000" "${MUNITOR_HEALTH_PORT}"
assert_eq "coverage min default" "70" "${MUNITOR_COVERAGE_MIN}"
assert_eq "package_manager default" "npm" "${MUNITOR_PACKAGE_MANAGER}"

# --------------------------------------------------------------------------
# supplemental_images (enabled)
# --------------------------------------------------------------------------
echo ""
echo "=== extract_munitor_vars: supplemental_images (enabled) ==="
extract_munitor_vars "${FIXTURES_DIR}/java-webapp-supplemental.munitor.yml"

assert_eq "supplemental flag" "true" "${MUNITOR_SUPPLEMENTAL}"
assert_eq "supplemental JSON is non-empty" "true" "$([[ "${MUNITOR_SUPPLEMENTAL_IMAGES_JSON}" != "[]" ]] && echo true || echo false)"
assert_eq "supplemental JSON is single-line" "1" "$(echo "${MUNITOR_SUPPLEMENTAL_IMAGES_JSON}" | wc -l | tr -d ' ')"
assert_eq "supplemental JSON has migrations" "true" "$(echo "${MUNITOR_SUPPLEMENTAL_IMAGES_JSON}" | jq -r '.[0].name' 2>/dev/null | grep -q migrations && echo true || echo false)"
assert_eq "supplemental migrations base" "liquibase/liquibase:4.31" "$(echo "${MUNITOR_SUPPLEMENTAL_IMAGES_JSON}" | jq -r '.[0].base')"
assert_eq "supplemental migrations cd.image_key" "migrations.image.tag" "$(echo "${MUNITOR_SUPPLEMENTAL_IMAGES_JSON}" | jq -r '.[0].cd.image_key')"

# --------------------------------------------------------------------------
# supplemental_images (default: disabled)
# --------------------------------------------------------------------------
echo ""
echo "=== extract_munitor_vars: supplemental_images (default disabled) ==="
extract_munitor_vars "${FIXTURES_DIR}/java-webapp.munitor.yml"

assert_eq "supplemental flag default" "false" "${MUNITOR_SUPPLEMENTAL}"
assert_eq "supplemental JSON default empty" "[]" "${MUNITOR_SUPPLEMENTAL_IMAGES_JSON}"

# --------------------------------------------------------------------------
# gradle-webapp fixture
# --------------------------------------------------------------------------
echo ""
echo "=== extract_munitor_vars: gradle-webapp fixture ==="
extract_munitor_vars "${FIXTURES_DIR}/gradle-webapp.munitor.yml"

assert_eq "pipeline type" "gradle-webapp" "${MUNITOR_PIPELINE}"
assert_eq "image_name" "concilium" "${MUNITOR_IMAGE_NAME}"
assert_eq "java_version" "21" "${MUNITOR_JAVA_VERSION}"
assert_eq "server_module" "concilium-server" "${MUNITOR_SERVER_MODULE}"
assert_eq "docker registry" "ghcr.io/koftwentytwo" "${MUNITOR_DOCKER_REGISTRY}"
assert_eq "cd repo" "KofTwentyTwo/Concilium-CD" "${MUNITOR_CD_REPO}"
assert_eq "cd flag" "true" "${MUNITOR_CD}"
assert_eq "cd format" "kustomize" "${MUNITOR_CD_FORMAT}"
assert_eq "cd env develop" "dev" "${MUNITOR_CD_ENV_DEVELOP}"
assert_eq "coverage min" "50" "${MUNITOR_COVERAGE_MIN}"
assert_eq "sbom" "true" "${MUNITOR_SBOM}"
assert_eq "owasp" "false" "${MUNITOR_OWASP}"
assert_eq "sast" "true" "${MUNITOR_SAST}"
assert_eq "sast fail_on_findings" "true" "${MUNITOR_SAST_FAIL_ON_FINDINGS}"
assert_eq "health_path" "/api/health" "${MUNITOR_HEALTH_PATH}"
assert_eq "health_port" "8000" "${MUNITOR_HEALTH_PORT}"
assert_eq "context registry" "ghcr" "${MUNITOR_CONTEXT_REGISTRY}"
assert_eq "context github" "github" "${MUNITOR_CONTEXT_GITHUB}"
assert_eq "github_release flag" "true" "${MUNITOR_GITHUB_RELEASE}"

# --------------------------------------------------------------------------
# server_module defaults (empty when not set)
# --------------------------------------------------------------------------
echo ""
echo "=== extract_munitor_vars: server_module default ==="
extract_munitor_vars "${FIXTURES_DIR}/java-webapp.munitor.yml"
assert_eq "server_module default (empty)" "" "${MUNITOR_SERVER_MODULE}"

# --------------------------------------------------------------------------
# get_envsubst_vars includes MUNITOR_SERVER_MODULE
# --------------------------------------------------------------------------
echo -n "  TEST: get_envsubst_vars includes MUNITOR_SERVER_MODULE... "
VARS_CHECK=$(get_envsubst_vars)
if echo "${VARS_CHECK}" | grep -q 'MUNITOR_SERVER_MODULE'; then
  echo "PASS"
  PASS=$((PASS + 1))
else
  echo "FAIL"
  FAIL=$((FAIL + 1))
fi

# --------------------------------------------------------------------------
# Missing config file
# --------------------------------------------------------------------------
echo ""
echo "=== extract_munitor_vars: error handling ==="
echo -n "  TEST: missing config file returns error... "
if extract_munitor_vars "/nonexistent/file.yml" 2>/dev/null; then
  echo "FAIL (should have returned non-zero)"
  FAIL=$((FAIL + 1))
else
  echo "PASS"
  PASS=$((PASS + 1))
fi

# --------------------------------------------------------------------------
# get_envsubst_vars produces non-empty list
# --------------------------------------------------------------------------
echo -n "  TEST: get_envsubst_vars returns non-empty... "
VARS=$(get_envsubst_vars)
if [[ -n "${VARS}" ]]; then
  echo "PASS"
  PASS=$((PASS + 1))
else
  echo "FAIL (empty)"
  FAIL=$((FAIL + 1))
fi

echo -n "  TEST: get_envsubst_vars includes MUNITOR_PIPELINE... "
if echo "${VARS}" | grep -q 'MUNITOR_PIPELINE'; then
  echo "PASS"
  PASS=$((PASS + 1))
else
  echo "FAIL"
  FAIL=$((FAIL + 1))
fi

echo -n "  TEST: get_envsubst_vars includes MUNITOR_ORB_SLUG... "
if echo "${VARS}" | grep -q 'MUNITOR_ORB_SLUG'; then
  echo "PASS"
  PASS=$((PASS + 1))
else
  echo "FAIL"
  FAIL=$((FAIL + 1))
fi

echo -n "  TEST: get_envsubst_vars includes MUNITOR_PACKAGE_MANAGER... "
if echo "${VARS}" | grep -q 'MUNITOR_PACKAGE_MANAGER'; then
  echo "PASS"
  PASS=$((PASS + 1))
else
  echo "FAIL"
  FAIL=$((FAIL + 1))
fi

echo -n "  TEST: get_envsubst_vars includes MUNITOR_KUSTOMIZE_OVERLAY_DIR... "
if echo "${VARS}" | grep -q 'MUNITOR_KUSTOMIZE_OVERLAY_DIR'; then
  echo "PASS"
  PASS=$((PASS + 1))
else
  echo "FAIL"
  FAIL=$((FAIL + 1))
fi

echo -n "  TEST: get_envsubst_vars includes MUNITOR_SUPPLEMENTAL_IMAGES_JSON... "
if echo "${VARS}" | grep -q 'MUNITOR_SUPPLEMENTAL_IMAGES_JSON'; then
  echo "PASS"
  PASS=$((PASS + 1))
else
  echo "FAIL"
  FAIL=$((FAIL + 1))
fi

# --------------------------------------------------------------------------
echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="

if [[ ${FAIL} -gt 0 ]]; then
  exit 1
fi
