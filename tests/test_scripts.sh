#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SRC_SCRIPTS="${PROJECT_DIR}/src/scripts"
PASS=0
FAIL=0

# Test helper functions
pass() {
  echo "PASS"
  PASS=$((PASS + 1))
}

fail() {
  local msg="${1:-}"
  echo "FAIL${msg:+ ($msg)}"
  FAIL=$((FAIL + 1))
}

# =============================================================================
# Test: npm_test.sh - Custom test commands
# =============================================================================
echo "=== npm_test.sh Tests ==="

echo -n "  TEST: runs custom test commands via bash -c (not eval)... "
# Verify the script uses bash -c, not eval
if grep -q 'bash -c "\${CMD}"' "${SRC_SCRIPTS}/npm_test.sh"; then
  pass
else
  fail "script should use 'bash -c' not 'eval'"
fi

echo -n "  TEST: creates reports/junit directory... "
if grep -q 'mkdir -p reports/junit' "${SRC_SCRIPTS}/npm_test.sh"; then
  pass
else
  fail "should create reports/junit"
fi

echo -n "  TEST: handles empty TEST_COMMANDS_JSON... "
if grep -q '\[\]' "${SRC_SCRIPTS}/npm_test.sh" && grep -q 'null' "${SRC_SCRIPTS}/npm_test.sh"; then
  pass
else
  fail "should handle empty/null JSON"
fi

# =============================================================================
# Test: docker_push_ghcr.sh - Secret validation
# =============================================================================
echo ""
echo "=== docker_push_ghcr.sh Tests ==="

echo -n "  TEST: validates DOCKER_IMAGE is set... "
if grep -q 'DOCKER_IMAGE:?' "${SRC_SCRIPTS}/docker_push_ghcr.sh"; then
  pass
else
  fail "should validate DOCKER_IMAGE"
fi

echo -n "  TEST: validates DOCKER_TAG is set... "
if grep -q 'DOCKER_TAG:?' "${SRC_SCRIPTS}/docker_push_ghcr.sh"; then
  pass
else
  fail "should validate DOCKER_TAG"
fi

echo -n "  TEST: validates GHCR credentials... "
if grep -q 'if \[\[ -z "\${TOKEN}"' "${SRC_SCRIPTS}/docker_push_ghcr.sh"; then
  pass
else
  fail "should validate TOKEN"
fi

echo -n "  TEST: uses --password-stdin for docker login... "
if grep -q '\-\-password-stdin' "${SRC_SCRIPTS}/docker_push_ghcr.sh"; then
  pass
else
  fail "should use --password-stdin"
fi

# =============================================================================
# Test: github_release.sh - Secret validation
# =============================================================================
echo ""
echo "=== github_release.sh Tests ==="

echo -n "  TEST: validates GITHUB_TOKEN is set... "
if grep -q 'GITHUB_TOKEN' "${SRC_SCRIPTS}/github_release.sh" && grep -q 'ERROR.*GITHUB_TOKEN' "${SRC_SCRIPTS}/github_release.sh"; then
  pass
else
  fail "should validate GITHUB_TOKEN"
fi

echo -n "  TEST: validates PROJECT_VERSION is set... "
if grep -q 'PROJECT_VERSION' "${SRC_SCRIPTS}/github_release.sh"; then
  pass
else
  fail "should validate PROJECT_VERSION"
fi

echo -n "  TEST: creates GitHub Release with --generate-notes... "
if grep -q 'gh release create' "${SRC_SCRIPTS}/github_release.sh" && grep -q '\-\-generate-notes' "${SRC_SCRIPTS}/github_release.sh"; then
  pass
else
  fail "should create GitHub Release with --generate-notes"
fi

echo -n "  TEST: uses dynamic --target (not hardcoded main)... "
if grep -q '\-\-target "\${TARGET}"' "${SRC_SCRIPTS}/github_release.sh"; then
  pass
else
  fail "should use dynamic --target"
fi

echo -n "  TEST: supports --prerelease flag for RC versions... "
if grep -q '\-\-prerelease' "${SRC_SCRIPTS}/github_release.sh" && grep -q 'PRERELEASE_FLAG' "${SRC_SCRIPTS}/github_release.sh"; then
  pass
else
  fail "should support --prerelease flag"
fi

echo -n "  TEST: detects RC/alpha/beta/SNAPSHOT versions... "
if grep -q 'RC|alpha|beta|SNAPSHOT' "${SRC_SCRIPTS}/github_release.sh"; then
  pass
else
  fail "should detect pre-release version patterns"
fi

echo -n "  TEST: uses CIRCLE_BRANCH for pre-release target... "
if grep -q 'CIRCLE_BRANCH' "${SRC_SCRIPTS}/github_release.sh"; then
  pass
else
  fail "should use CIRCLE_BRANCH for pre-release target"
fi

echo -n "  TEST: skips if release already exists... "
if grep -q 'already exists, skipping' "${SRC_SCRIPTS}/github_release.sh"; then
  pass
else
  fail "should skip existing releases"
fi

# =============================================================================
# Test: calculate_version.sh - Munitor-managed GitVersion config
# =============================================================================
echo ""
echo "=== calculate_version.sh Tests ==="

echo -n "  TEST: writes GitVersion.yml before running GitVersion... "
if grep -q 'cat > GitVersion.yml' "${SRC_SCRIPTS}/calculate_version.sh"; then
  pass
else
  fail "should write GitVersion.yml"
fi

echo -n "  TEST: includes tag-prefix: v in GitVersion config... "
if grep -q 'tag-prefix: v' "${SRC_SCRIPTS}/calculate_version.sh"; then
  pass
else
  fail "should include tag-prefix: v"
fi

echo -n "  TEST: warns if repo already has GitVersion.yml... "
if grep -q 'WARNING.*GitVersion.yml' "${SRC_SCRIPTS}/calculate_version.sh"; then
  pass
else
  fail "should warn about existing GitVersion.yml"
fi

echo -n "  TEST: enables commit-message-incrementing... "
if grep -q 'commit-message-incrementing: Enabled' "${SRC_SCRIPTS}/calculate_version.sh"; then
  pass
else
  fail "should enable commit-message-incrementing"
fi

# =============================================================================
# Test: npm_auth.sh - Secret validation
# =============================================================================
echo ""
echo "=== npm_auth.sh Tests ==="

echo -n "  TEST: validates NPM_TOKEN is set... "
if grep -q 'if \[\[ -z "\${NPM_TOKEN:-}"' "${SRC_SCRIPTS}/npm_auth.sh"; then
  pass
else
  fail "should validate NPM_TOKEN"
fi

echo -n "  TEST: configures .npmrc securely... "
if grep -q '_authToken=\${NPM_TOKEN}' "${SRC_SCRIPTS}/npm_auth.sh"; then
  pass
else
  fail "should use NPM_TOKEN in .npmrc"
fi

echo -n "  TEST: always includes @koftwentytwo scope... "
if grep -q '@koftwentytwo' "${SRC_SCRIPTS}/npm_auth.sh"; then
  pass
else
  fail "should always include @koftwentytwo scope"
fi

echo -n "  TEST: supports additional scopes via NPM_SCOPES... "
if grep -q 'NPM_SCOPES' "${SRC_SCRIPTS}/npm_auth.sh"; then
  pass
else
  fail "should read NPM_SCOPES env var"
fi

# =============================================================================
# Test: health_check.sh - Generic PG env vars
# =============================================================================
echo ""
echo "=== health_check.sh Tests ==="

echo -n "  TEST: passes Liquibase env vars for java-webapp compat... "
if grep -q 'LIQUIBASE_USERNAME' "${SRC_SCRIPTS}/health_check.sh"; then
  pass
else
  fail "should pass Liquibase env vars"
fi

echo -n "  TEST: passes generic PG env vars for non-Liquibase apps... "
if grep -q 'PG_HOST' "${SRC_SCRIPTS}/health_check.sh"; then
  pass
else
  fail "should pass PG_HOST env var"
fi

echo -n "  TEST: passes PG_SSL=false for sidecar... "
if grep -q 'PG_SSL=false' "${SRC_SCRIPTS}/health_check.sh"; then
  pass
else
  fail "should pass PG_SSL=false"
fi

# =============================================================================
# Test: mvn_sonar.sh - Secret validation
# =============================================================================
echo ""
echo "=== mvn_sonar.sh Tests ==="

echo -n "  TEST: validates SONAR_PROJECT_KEY is set... "
if grep -q 'SONAR_PROJECT_KEY:?' "${SRC_SCRIPTS}/mvn_sonar.sh"; then
  pass
else
  fail "should validate SONAR_PROJECT_KEY"
fi

echo -n "  TEST: validates TOKEN is set... "
if grep -q 'if \[\[ -z "\${TOKEN}"' "${SRC_SCRIPTS}/mvn_sonar.sh"; then
  pass
else
  fail "should validate TOKEN"
fi

# =============================================================================
# Test: start_services.sh - Security
# =============================================================================
echo ""
echo "=== start_services.sh Tests ==="

echo -n "  TEST: uses bash -c for healthcheck (not eval)... "
if grep -q 'bash -c "\${HEALTHCHECK}"' "${SRC_SCRIPTS}/start_services.sh"; then
  pass
else
  fail "should use 'bash -c' not 'eval'"
fi

echo -n "  TEST: has health timeout... "
if grep -q 'HEALTH_TIMEOUT' "${SRC_SCRIPTS}/start_services.sh"; then
  pass
else
  fail "should have health timeout"
fi

# =============================================================================
# Test: npm_coverage_check.sh - Security
# =============================================================================
echo ""
echo "=== npm_coverage_check.sh Tests ==="

echo -n "  TEST: uses bash -c for coverage command (not eval)... "
if grep -q 'bash -c "\${COVERAGE_COMMAND}"' "${SRC_SCRIPTS}/npm_coverage_check.sh"; then
  pass
else
  fail "should use 'bash -c' not 'eval'"
fi

# =============================================================================
# Test: update_cd_repo.sh - CD_ENVIRONMENT support
# =============================================================================
echo ""
echo "=== update_cd_repo.sh Tests ==="

echo -n "  TEST: reads CD_ENVIRONMENT from env... "
if grep -q 'CD_ENVIRONMENT' "${SRC_SCRIPTS}/update_cd_repo.sh"; then
  pass
else
  fail "should reference CD_ENVIRONMENT"
fi

echo -n "  TEST: resolves environment-specific values path... "
if grep -q 'environments/' "${SRC_SCRIPTS}/update_cd_repo.sh"; then
  pass
else
  fail "should resolve environments/<env>/values.yaml"
fi

echo -n "  TEST: deletes digest field when setting newTag (kustomize)... "
if grep -q 'del((.images\[\] | select(.name == \\"${IMAGE_NAME}\\")).digest)' "${SRC_SCRIPTS}/update_cd_repo.sh"; then
  pass
else
  fail "should delete digest field to prevent kustomize from ignoring newTag"
fi

# =============================================================================
# Test: docker_build.sh - DOCKER_ENV_TAG support
# =============================================================================
echo ""
echo "=== docker_build.sh Tests ==="

echo -n "  TEST: reads DOCKER_ENV_TAG from env... "
if grep -q 'DOCKER_ENV_TAG' "${SRC_SCRIPTS}/docker_build.sh"; then
  pass
else
  fail "should reference DOCKER_ENV_TAG"
fi

echo -n "  TEST: exports DOCKER_ENV_TAG to BASH_ENV... "
if grep -q "DOCKER_ENV_TAG" "${SRC_SCRIPTS}/docker_build.sh" && grep -q 'BASH_ENV' "${SRC_SCRIPTS}/docker_build.sh"; then
  pass
else
  fail "should export DOCKER_ENV_TAG"
fi

# =============================================================================
# Test: docker_push_ghcr.sh - DOCKER_ENV_TAG support
# =============================================================================
echo ""
echo "=== docker_push_ghcr.sh DOCKER_ENV_TAG Tests ==="

echo -n "  TEST: reads DOCKER_ENV_TAG from env... "
if grep -q 'DOCKER_ENV_TAG' "${SRC_SCRIPTS}/docker_push_ghcr.sh"; then
  pass
else
  fail "should reference DOCKER_ENV_TAG"
fi

echo -n "  TEST: conditionally pushes env tag... "
if grep -q 'ENV_TAG' "${SRC_SCRIPTS}/docker_push_ghcr.sh" && grep -q 'docker push.*ENV_TAG' "${SRC_SCRIPTS}/docker_push_ghcr.sh"; then
  pass
else
  fail "should conditionally push env tag"
fi

# =============================================================================
# Test: export_version_vars.sh - DOCKER_ENV_TAG export
# =============================================================================
echo ""
echo "=== export_version_vars.sh DOCKER_ENV_TAG Tests ==="

echo -n "  TEST: exports DOCKER_ENV_TAG to BASH_ENV... "
if grep -q 'DOCKER_ENV_TAG' "${SRC_SCRIPTS}/export_version_vars.sh" && grep -q 'BASH_ENV' "${SRC_SCRIPTS}/export_version_vars.sh"; then
  pass
else
  fail "should export DOCKER_ENV_TAG to BASH_ENV"
fi

echo -n "  TEST: handles staging branch... "
if grep -q 'staging)' "${SRC_SCRIPTS}/export_version_vars.sh"; then
  pass
else
  fail "should handle staging branch"
fi

# =============================================================================
# Test: generate_dockerfile.sh - Dockerfile generation
# =============================================================================
echo ""
echo "=== generate_dockerfile.sh Tests ==="

echo -n "  TEST: reads .munitor.yml config... "
if grep -q '\.munitor\.yml' "${SRC_SCRIPTS}/generate_dockerfile.sh"; then
  pass
else
  fail "should read .munitor.yml"
fi

echo -n "  TEST: handles node-api pipeline... "
if grep -q 'node-api)' "${SRC_SCRIPTS}/generate_dockerfile.sh"; then
  pass
else
  fail "should handle node-api"
fi

echo -n "  TEST: handles java-webapp pipeline... "
if grep -q 'java-webapp)' "${SRC_SCRIPTS}/generate_dockerfile.sh"; then
  pass
else
  fail "should handle java-webapp"
fi

echo -n "  TEST: handles node-webapp pipeline... "
if grep -q 'node-webapp)' "${SRC_SCRIPTS}/generate_dockerfile.sh"; then
  pass
else
  fail "should handle node-webapp"
fi

echo -n "  TEST: fails on unsupported pipeline... "
if grep -q 'Unsupported pipeline type' "${SRC_SCRIPTS}/generate_dockerfile.sh"; then
  pass
else
  fail "should fail on unsupported type"
fi

echo -n "  TEST: uses multi-stage build for node-api... "
if grep -q 'AS deps' "${SRC_SCRIPTS}/generate_dockerfile.sh" && grep -q 'AS builder' "${SRC_SCRIPTS}/generate_dockerfile.sh"; then
  pass
else
  fail "should use multi-stage build"
fi

echo -n "  TEST: uses Alpine JRE for java-webapp... "
if grep -q 'eclipse-temurin.*jre-alpine' "${SRC_SCRIPTS}/generate_dockerfile.sh" && grep -q 'USER appuser' "${SRC_SCRIPTS}/generate_dockerfile.sh"; then
  pass
else
  fail "should use Alpine JRE with non-root user"
fi

# =============================================================================
# Test: install_kustomize.sh - Pinned binary install
# =============================================================================
echo ""
echo "=== install_kustomize.sh Tests ==="

echo -n "  TEST: uses munitor_download_with_retry... "
if grep -q 'munitor_download_with_retry' "${SRC_SCRIPTS}/install_kustomize.sh"; then
  pass
else
  fail "should use munitor_download_with_retry"
fi

echo -n "  TEST: pins version via KUSTOMIZE_VERSION... "
if grep -q 'KUSTOMIZE_VERSION' "${SRC_SCRIPTS}/install_kustomize.sh"; then
  pass
else
  fail "should use KUSTOMIZE_VERSION env var"
fi

echo -n "  TEST: uses URL-encoded path segment... "
if grep -q 'kustomize%2Fv' "${SRC_SCRIPTS}/install_kustomize.sh"; then
  pass
else
  fail "should use kustomize%2Fv in URL"
fi

echo -n "  TEST: has cleanup trap... "
if grep -q 'trap cleanup EXIT' "${SRC_SCRIPTS}/install_kustomize.sh"; then
  pass
else
  fail "should have cleanup trap"
fi

# =============================================================================
# Test: kustomize_validate.sh - Build base + overlays
# =============================================================================
echo ""
echo "=== kustomize_validate.sh Tests ==="

echo -n "  TEST: auto-detects overlays when KUSTOMIZE_OVERLAYS is empty... "
if grep -q 'overlays/\*/kustomization.yaml' "${SRC_SCRIPTS}/kustomize_validate.sh"; then
  pass
else
  fail "should auto-detect overlays"
fi

echo -n "  TEST: supports load restrictor flag... "
if grep -q 'LoadRestrictionsNone' "${SRC_SCRIPTS}/kustomize_validate.sh"; then
  pass
else
  fail "should support LoadRestrictionsNone"
fi

echo -n "  TEST: outputs to /tmp/kustomize-output... "
if grep -q '/tmp/kustomize-output' "${SRC_SCRIPTS}/kustomize_validate.sh"; then
  pass
else
  fail "should output to /tmp/kustomize-output"
fi

# =============================================================================
# Test: install_kubesec.sh - Pinned binary install
# =============================================================================
echo ""
echo "=== install_kubesec.sh Tests ==="

echo -n "  TEST: uses munitor_download_with_retry... "
if grep -q 'munitor_download_with_retry' "${SRC_SCRIPTS}/install_kubesec.sh"; then
  pass
else
  fail "should use munitor_download_with_retry"
fi

echo -n "  TEST: has cleanup trap... "
if grep -q 'trap cleanup EXIT' "${SRC_SCRIPTS}/install_kubesec.sh"; then
  pass
else
  fail "should have cleanup trap"
fi

# =============================================================================
# Test: run_kubesec.sh - Soft-fail scan
# =============================================================================
echo ""
echo "=== run_kubesec.sh Tests ==="

echo -n "  TEST: reads scan overlay from env... "
if grep -q 'KUBESEC_SCAN_OVERLAY' "${SRC_SCRIPTS}/run_kubesec.sh"; then
  pass
else
  fail "should read KUBESEC_SCAN_OVERLAY"
fi

echo -n "  TEST: soft-fails (|| true)... "
if grep -q '|| true' "${SRC_SCRIPTS}/run_kubesec.sh"; then
  pass
else
  fail "should soft-fail"
fi

# =============================================================================
# Test: install_kube_linter.sh - Pinned binary install
# =============================================================================
echo ""
echo "=== install_kube_linter.sh Tests ==="

echo -n "  TEST: uses munitor_download_with_retry... "
if grep -q 'munitor_download_with_retry' "${SRC_SCRIPTS}/install_kube_linter.sh"; then
  pass
else
  fail "should use munitor_download_with_retry"
fi

echo -n "  TEST: has cleanup trap... "
if grep -q 'trap cleanup EXIT' "${SRC_SCRIPTS}/install_kube_linter.sh"; then
  pass
else
  fail "should have cleanup trap"
fi

# =============================================================================
# Test: run_kube_linter.sh - Soft-fail lint
# =============================================================================
echo ""
echo "=== run_kube_linter.sh Tests ==="

echo -n "  TEST: reads scan overlay from env... "
if grep -q 'KUBE_LINTER_SCAN_OVERLAY' "${SRC_SCRIPTS}/run_kube_linter.sh"; then
  pass
else
  fail "should read KUBE_LINTER_SCAN_OVERLAY"
fi

echo -n "  TEST: supports optional config file... "
if grep -q 'KUBE_LINTER_CONFIG' "${SRC_SCRIPTS}/run_kube_linter.sh"; then
  pass
else
  fail "should read KUBE_LINTER_CONFIG"
fi

echo -n "  TEST: soft-fails (|| true)... "
if grep -q '|| true' "${SRC_SCRIPTS}/run_kube_linter.sh"; then
  pass
else
  fail "should soft-fail"
fi

# =============================================================================
# Test: yaml_lint_cd.sh - YAML linting
# =============================================================================
echo ""
echo "=== yaml_lint_cd.sh Tests ==="

echo -n "  TEST: installs yamllint via apt... "
if grep -q 'apt-get install.*yamllint' "${SRC_SCRIPTS}/yaml_lint_cd.sh"; then
  pass
else
  fail "should install yamllint via apt"
fi

echo -n "  TEST: uses relaxed config with line-length disabled... "
if grep -q 'line-length: disable' "${SRC_SCRIPTS}/yaml_lint_cd.sh"; then
  pass
else
  fail "should disable line-length rule"
fi

echo -n "  TEST: skips missing directories... "
if grep -q '! -d' "${SRC_SCRIPTS}/yaml_lint_cd.sh"; then
  pass
else
  fail "should skip missing directories"
fi

# =============================================================================
# Test: Scripts have proper error handling
# =============================================================================
echo ""
echo "=== Error Handling Tests ==="

echo -n "  TEST: all scripts use set -euo pipefail... "
# munitor_helpers.sh is a sourced library, not a standalone script -- exclude it
SCRIPTS_WITHOUT_STRICT=$(find "${SRC_SCRIPTS}" -name "*.sh" ! -name "munitor_helpers.sh" -exec grep -L 'set -euo pipefail' {} \;)
if [[ -z "${SCRIPTS_WITHOUT_STRICT}" ]]; then
  pass
else
  fail "missing in: ${SCRIPTS_WITHOUT_STRICT}"
fi

# =============================================================================
# Test: Cleanup traps
# =============================================================================
echo ""
echo "=== Cleanup Trap Tests ==="

echo -n "  TEST: install_gitleaks.sh has cleanup trap... "
if grep -q 'trap cleanup EXIT' "${SRC_SCRIPTS}/install_gitleaks.sh"; then
  pass
else
  fail "should have cleanup trap"
fi

echo -n "  TEST: install_gh.sh has cleanup trap... "
if grep -q 'trap cleanup EXIT' "${SRC_SCRIPTS}/install_gh.sh"; then
  pass
else
  fail "should have cleanup trap"
fi

echo -n "  TEST: update_cd_repo.sh has cleanup trap... "
if grep -q 'trap cleanup EXIT' "${SRC_SCRIPTS}/update_cd_repo.sh"; then
  pass
else
  fail "should have cleanup trap"
fi

echo -n "  TEST: sdk_post_validate.sh has cleanup trap... "
if grep -q 'trap cleanup EXIT' "${SRC_SCRIPTS}/sdk_post_validate.sh"; then
  pass
else
  fail "should have cleanup trap"
fi

echo -n "  TEST: generate_config.sh has cleanup trap... "
if grep -q 'trap cleanup EXIT' "${SRC_SCRIPTS}/generate_config.sh"; then
  pass
else
  fail "should have cleanup trap"
fi

# =============================================================================
# Test: All scripts source munitor_helpers and call munitor_header
# =============================================================================
echo ""
echo "=== Munitor Helpers Integration Tests ==="

# Scripts that are excluded from the munitor_header requirement:
# - munitor_helpers.sh: the library itself
# - extract_munitor_vars.sh: low-level helper, sourced by other scripts
# - packed_*: auto-generated, embed helpers differently
EXCLUDED_PATTERN="munitor_helpers.sh|extract_munitor_vars.sh|packed_"

echo -n "  TEST: all scripts source munitor_helpers... "
MISSING_SOURCE=""
while IFS= read -r script; do
  name=$(basename "${script}")
  if echo "${name}" | grep -qE "${EXCLUDED_PATTERN}"; then continue; fi
  if ! grep -q 'MUNITOR_HELPERS' "${script}"; then
    MISSING_SOURCE="${MISSING_SOURCE} ${name}"
  fi
done < <(find "${SRC_SCRIPTS}" -maxdepth 1 -name "*.sh" -type f)
if [[ -z "${MISSING_SOURCE}" ]]; then
  pass
else
  fail "missing sourcing:${MISSING_SOURCE}"
fi

echo -n "  TEST: all scripts call munitor_header... "
MISSING_HEADER=""
while IFS= read -r script; do
  name=$(basename "${script}")
  if echo "${name}" | grep -qE "${EXCLUDED_PATTERN}"; then continue; fi
  if ! grep -q 'munitor_header' "${script}"; then
    MISSING_HEADER="${MISSING_HEADER} ${name}"
  fi
done < <(find "${SRC_SCRIPTS}" -maxdepth 1 -name "*.sh" -type f)
if [[ -z "${MISSING_HEADER}" ]]; then
  pass
else
  fail "missing munitor_header:${MISSING_HEADER}"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="

if [[ ${FAIL} -gt 0 ]]; then
  exit 1
fi
