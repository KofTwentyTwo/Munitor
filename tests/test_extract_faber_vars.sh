#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
FIXTURES_DIR="${SCRIPT_DIR}/fixtures"
PASS=0
FAIL=0

# Source the helper under test
# shellcheck disable=SC1091
source "${PROJECT_DIR}/src/scripts/extract_faber_vars.sh"

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
echo "=== extract_faber_vars: java-webapp fixture ==="
extract_faber_vars "${FIXTURES_DIR}/java-webapp.faber.yml"

assert_eq "pipeline type" "java-webapp" "${FABER_PIPELINE}"
assert_eq "image_name" "me-health-portal" "${FABER_IMAGE_NAME}"
assert_eq "java_version" "21" "${FABER_JAVA_VERSION}"
assert_eq "sonar project_key" "dmdbrands_me-health-portal" "${FABER_SONAR_PROJECT_KEY}"
assert_eq "sonar flag" "true" "${FABER_SONAR}"
assert_eq "docker registry" "ghcr.io/dmdbrands" "${FABER_DOCKER_REGISTRY}"
assert_eq "cd repo" "dmdbrands/me-health-portal-cd-pipeline" "${FABER_CD_REPO}"
assert_eq "cd flag" "true" "${FABER_CD}"
assert_eq "coverage min" "80" "${FABER_COVERAGE_MIN}"
assert_eq "e2e" "true" "${FABER_E2E}"
assert_eq "sbom" "true" "${FABER_SBOM}"
assert_eq "context registry" "ghcr" "${FABER_CONTEXT_REGISTRY}"
assert_eq "context github" "github" "${FABER_CONTEXT_GITHUB}"
assert_eq "context sonar" "sonarcloud" "${FABER_CONTEXT_SONAR}"
assert_eq "context nvd" "nvd" "${FABER_CONTEXT_NVD}"
assert_eq "github_release flag (has github context)" "true" "${FABER_GITHUB_RELEASE}"
assert_eq "cd env release default" "staging" "${FABER_CD_ENV_RELEASE}"
assert_eq "ci_email default" "munitor-ci@koftwentytwo.com" "${FABER_CI_EMAIL}"
assert_eq "ci_name default" "Munitor CI" "${FABER_CI_NAME}"
assert_eq "npm_default_scope" "@koftwentytwo" "${FABER_NPM_DEFAULT_SCOPE}"
assert_eq "orb_slug" "KofTwentyTwo/munitor" "${FABER_ORB_SLUG}"

# --------------------------------------------------------------------------
# node-api-minimal fixture (tests defaults)
# --------------------------------------------------------------------------
echo ""
echo "=== extract_faber_vars: node-api-minimal fixture ==="
extract_faber_vars "${FIXTURES_DIR}/node-api-minimal.faber.yml"

assert_eq "pipeline type" "node-api" "${FABER_PIPELINE}"
assert_eq "node_version" "22" "${FABER_NODE_VERSION}"
assert_eq "sonar flag (no sonar)" "false" "${FABER_SONAR}"
assert_eq "sonar key empty" "" "${FABER_SONAR_PROJECT_KEY}"
assert_eq "e2e" "false" "${FABER_E2E}"
assert_eq "sbom" "false" "${FABER_SBOM}"
assert_eq "npm_auth default" "false" "${FABER_NPM_AUTH}"
assert_eq "npm_scopes default" "[]" "${FABER_NPM_SCOPES}"
assert_eq "services flag default" "false" "${FABER_SERVICES}"
assert_eq "test_setup flag default" "false" "${FABER_TEST_SETUP}"
assert_eq "custom_test flag default" "false" "${FABER_CUSTOM_TEST}"
assert_eq "coverage_tool default" "jest" "${FABER_COVERAGE_TOOL}"
assert_eq "coverage_cmd flag default" "false" "${FABER_COVERAGE_CMD}"
assert_eq "github_release flag (has github context)" "true" "${FABER_GITHUB_RELEASE}"
assert_eq "coverage min default" "70" "${FABER_COVERAGE_MIN}"

# --------------------------------------------------------------------------
# node-api-services fixture (all node extensions enabled)
# --------------------------------------------------------------------------
echo ""
echo "=== extract_faber_vars: node-api-services fixture ==="
extract_faber_vars "${FIXTURES_DIR}/node-api-services.faber.yml"

assert_eq "npm_auth" "true" "${FABER_NPM_AUTH}"
assert_eq "npm_scopes" '["@greatergoods"]' "${FABER_NPM_SCOPES}"
assert_eq "services flag" "true" "${FABER_SERVICES}"
assert_eq "services JSON not empty" "true" "$([[ "${FABER_SERVICES_JSON}" != "[]" ]] && echo true || echo false)"
assert_eq "test_setup flag" "true" "${FABER_TEST_SETUP}"
assert_eq "test_setup script" "scripts/ci-setup.sh" "${FABER_TEST_SETUP_SCRIPT}"
assert_eq "custom_test flag" "true" "${FABER_CUSTOM_TEST}"
assert_eq "coverage_tool" "nyc" "${FABER_COVERAGE_TOOL}"
assert_eq "coverage_cmd flag" "true" "${FABER_COVERAGE_CMD}"
assert_eq "coverage_command" "npm run coverage" "${FABER_COVERAGE_COMMAND}"
assert_eq "coverage min override" "70" "${FABER_COVERAGE_MIN}"

# --------------------------------------------------------------------------
# terraform fixture
# --------------------------------------------------------------------------
echo ""
echo "=== extract_faber_vars: terraform fixture ==="
extract_faber_vars "${FIXTURES_DIR}/terraform.faber.yml"

assert_eq "pipeline type" "terraform" "${FABER_PIPELINE}"
assert_eq "tf_path" "terraform/" "${FABER_TF_PATH}"
assert_eq "tf_live_path" "terraform/live" "${FABER_TF_LIVE_PATH}"
assert_eq "tf_environments" "production staging dev" "${FABER_TF_ENVIRONMENTS}"
assert_eq "checkov_skip" "CKV_AWS_144,CKV_AWS_145,CKV2_AWS_6" "${FABER_CHECKOV_SKIP}"
assert_eq "sast" "false" "${FABER_SAST}"
assert_eq "docker_registry default" "ghcr.io/KofTwentyTwo" "${FABER_DOCKER_REGISTRY}"

# --------------------------------------------------------------------------
# SAST fail_on_findings (default, boolean true, boolean false, object form)
# --------------------------------------------------------------------------
echo ""
echo "=== extract_faber_vars: SAST fail_on_findings ==="

# Default: no sast key -> SAST=false, FAIL_ON_FINDINGS=true
extract_faber_vars "${FIXTURES_DIR}/node-api-minimal.faber.yml"
assert_eq "sast default (no key)" "false" "${FABER_SAST}"
assert_eq "sast fail_on_findings default" "true" "${FABER_SAST_FAIL_ON_FINDINGS}"

# Boolean true: sast: true -> SAST=true, FAIL_ON_FINDINGS=true
extract_faber_vars "${FIXTURES_DIR}/terraform-sast.faber.yml"
assert_eq "sast boolean true" "true" "${FABER_SAST}"
assert_eq "sast fail_on_findings (boolean true)" "true" "${FABER_SAST_FAIL_ON_FINDINGS}"

# Boolean false: sast: false -> SAST=false, FAIL_ON_FINDINGS=true
extract_faber_vars "${FIXTURES_DIR}/terraform.faber.yml"
assert_eq "sast boolean false" "false" "${FABER_SAST}"
assert_eq "sast fail_on_findings (boolean false)" "true" "${FABER_SAST_FAIL_ON_FINDINGS}"

# Object form: sast: { fail_on_findings: false } -> SAST=true, FAIL_ON_FINDINGS=false
extract_faber_vars "${FIXTURES_DIR}/java-webapp-sast-warn.faber.yml"
assert_eq "sast object form" "true" "${FABER_SAST}"
assert_eq "sast fail_on_findings (object false)" "false" "${FABER_SAST_FAIL_ON_FINDINGS}"

# --------------------------------------------------------------------------
# node.framework defaults
# --------------------------------------------------------------------------
echo ""
echo "=== extract_faber_vars: node.framework ==="

extract_faber_vars "${FIXTURES_DIR}/node-api-minimal.faber.yml"
assert_eq "node_framework default" "nextjs" "${FABER_NODE_FRAMEWORK}"

# --------------------------------------------------------------------------
# validate-cd-repo full fixture
# --------------------------------------------------------------------------
echo ""
echo "=== extract_faber_vars: validate-cd-repo fixture ==="
extract_faber_vars "${FIXTURES_DIR}/validate-cd-repo.faber.yml"

assert_eq "pipeline type" "validate-cd-repo" "${FABER_PIPELINE}"
assert_eq "kustomize_version" "5.5.0" "${FABER_KUSTOMIZE_VERSION}"
assert_eq "kustomize_base_path" "base/" "${FABER_KUSTOMIZE_BASE_PATH}"
assert_eq "kustomize_load_restrictor" "true" "${FABER_KUSTOMIZE_LOAD_RESTRICTOR}"
assert_eq "kustomize_scan_overlay" "production" "${FABER_KUSTOMIZE_SCAN_OVERLAY}"
assert_eq "kustomize_overlays" "dev staging production" "${FABER_KUSTOMIZE_OVERLAYS}"
assert_eq "kube_linter_config" ".kube-linter.yaml" "${FABER_KUBE_LINTER_CONFIG}"
assert_eq "yamllint_paths" "base/ overlays/ argocd-apps/" "${FABER_YAMLLINT_PATHS}"

# --------------------------------------------------------------------------
# validate-cd-repo minimal fixture (tests defaults)
# --------------------------------------------------------------------------
echo ""
echo "=== extract_faber_vars: validate-cd-repo-minimal fixture ==="
extract_faber_vars "${FIXTURES_DIR}/validate-cd-repo-minimal.faber.yml"

assert_eq "pipeline type" "validate-cd-repo" "${FABER_PIPELINE}"
assert_eq "kustomize_version default" "5.5.0" "${FABER_KUSTOMIZE_VERSION}"
assert_eq "kustomize_base_path default" "base/" "${FABER_KUSTOMIZE_BASE_PATH}"
assert_eq "kustomize_load_restrictor default" "true" "${FABER_KUSTOMIZE_LOAD_RESTRICTOR}"
assert_eq "kustomize_scan_overlay default" "production" "${FABER_KUSTOMIZE_SCAN_OVERLAY}"
assert_eq "kustomize_overlays default (empty)" "" "${FABER_KUSTOMIZE_OVERLAYS}"
assert_eq "kube_linter_config default (empty)" "" "${FABER_KUBE_LINTER_CONFIG}"
assert_eq "yamllint_paths default" "base/ overlays/ argocd-apps/" "${FABER_YAMLLINT_PATHS}"

# --------------------------------------------------------------------------
# Missing config file
# --------------------------------------------------------------------------
echo ""
echo "=== extract_faber_vars: error handling ==="
echo -n "  TEST: missing config file returns error... "
if extract_faber_vars "/nonexistent/file.yml" 2>/dev/null; then
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

echo -n "  TEST: get_envsubst_vars includes FABER_PIPELINE... "
if echo "${VARS}" | grep -q 'FABER_PIPELINE'; then
  echo "PASS"
  PASS=$((PASS + 1))
else
  echo "FAIL"
  FAIL=$((FAIL + 1))
fi

echo -n "  TEST: get_envsubst_vars includes FABER_ORB_SLUG... "
if echo "${VARS}" | grep -q 'FABER_ORB_SLUG'; then
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
