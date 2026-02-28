#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
FIXTURES_DIR="${SCRIPT_DIR}/fixtures"
PASS=0
FAIL=0

GENERATE_SCRIPT="${PROJECT_DIR}/src/scripts/generate_config.sh"

# --------------------------------------------------------------------------
# Helper: render a fixture by calling the real generate_config.sh script
# and returning its output file contents.
# --------------------------------------------------------------------------
render_fixture() {
  local fixture="$1"

  # Run the real script; capture stderr for diagnostics, return generated YAML
  MUNITOR_CONFIG="${fixture}" bash "${GENERATE_SCRIPT}" >/dev/null 2>&1
  cat /tmp/generated-config.yml
}

run_test() {
  local name="$1"
  local fixture="$2"
  local expected_pattern="$3"

  echo -n "  TEST: ${name}... "

  local output
  output=$(render_fixture "${fixture}") || {
    echo "FAIL (script error)"
    echo "    Output: ${output}"
    FAIL=$((FAIL + 1))
    return
  }

  if echo "${output}" | grep -q "${expected_pattern}"; then
    echo "PASS"
    PASS=$((PASS + 1))
  else
    echo "FAIL (expected pattern '${expected_pattern}' not found)"
    echo "    Output (first 5 lines):"
    echo "${output}" | head -5 | sed 's/^/    /'
    FAIL=$((FAIL + 1))
  fi
}

run_negative_test() {
  local name="$1"
  local fixture="$2"
  local forbidden_pattern="$3"

  echo -n "  TEST: ${name}... "

  local output
  output=$(render_fixture "${fixture}") || {
    echo "FAIL (script error)"
    FAIL=$((FAIL + 1))
    return
  }

  if echo "${output}" | grep -q "${forbidden_pattern}"; then
    echo "FAIL (found forbidden pattern '${forbidden_pattern}')"
    FAIL=$((FAIL + 1))
  else
    echo "PASS"
    PASS=$((PASS + 1))
  fi
}

# --------------------------------------------------------------------------
# Helper: assert a pattern appears within a YAML block bounded by
# start_pattern (inclusive) and end_pattern (inclusive).
# Uses sed range addressing, so it captures ALL matching blocks across
# the entire file (e.g., all docker-build-push blocks across workflows).
# --------------------------------------------------------------------------
run_context_test() {
  local name="$1"
  local fixture="$2"
  local start_pattern="$3"
  local end_pattern="$4"
  local expected_pattern="$5"

  echo -n "  TEST: ${name}... "

  local output
  output=$(render_fixture "${fixture}") || {
    echo "FAIL (script error)"
    FAIL=$((FAIL + 1))
    return
  }

  # Use awk index() for string matching to avoid regex delimiter issues with slashes
  local block
  block=$(echo "${output}" | awk -v s="${start_pattern}" -v e="${end_pattern}" \
    'index($0,s){f=1} f{print} f&&index($0,e){f=0}')

  if [[ -z "${block}" ]]; then
    echo "FAIL (context block '${start_pattern}' not found)"
    FAIL=$((FAIL + 1))
    return
  fi

  if echo "${block}" | grep -q "${expected_pattern}"; then
    echo "PASS"
    PASS=$((PASS + 1))
  else
    echo "FAIL (expected '${expected_pattern}' within block)"
    FAIL=$((FAIL + 1))
  fi
}

# --------------------------------------------------------------------------
# Helper: assert a pattern does NOT appear within a YAML block bounded by
# start_pattern and end_pattern. Captures ALL matching blocks across the
# file, so the pattern must be absent from every occurrence.
# --------------------------------------------------------------------------
run_negative_context_test() {
  local name="$1"
  local fixture="$2"
  local start_pattern="$3"
  local end_pattern="$4"
  local forbidden_pattern="$5"

  echo -n "  TEST: ${name}... "

  local output
  output=$(render_fixture "${fixture}") || {
    echo "FAIL (script error)"
    FAIL=$((FAIL + 1))
    return
  }

  local block
  block=$(echo "${output}" | awk -v s="${start_pattern}" -v e="${end_pattern}" \
    'index($0,s){f=1} f{print} f&&index($0,e){f=0}')

  if [[ -z "${block}" ]]; then
    echo "PASS (context block not found, pattern cannot exist)"
    PASS=$((PASS + 1))
    return
  fi

  if echo "${block}" | grep -q "${forbidden_pattern}"; then
    echo "FAIL (found forbidden '${forbidden_pattern}' within block)"
    FAIL=$((FAIL + 1))
  else
    echo "PASS"
    PASS=$((PASS + 1))
  fi
}

echo "=== Template Rendering Tests ==="

# Test java-webapp renders with correct values
run_test "java-webapp: renders image_name" \
  "${FIXTURES_DIR}/java-webapp.munitor.yml" \
  "me-health-portal"

run_test "java-webapp: renders java_version" \
  "${FIXTURES_DIR}/java-webapp.munitor.yml" \
  "java_version: \"21\""

run_test "java-webapp: includes e2e when enabled" \
  "${FIXTURES_DIR}/java-webapp.munitor.yml" \
  "e2e-tests"

run_test "java-webapp: includes sonar when project_key set" \
  "${FIXTURES_DIR}/java-webapp.munitor.yml" \
  "sonar-scan"

run_test "java-webapp: includes sbom when enabled" \
  "${FIXTURES_DIR}/java-webapp.munitor.yml" \
  "sbom"

run_test "java-webapp: uses mvn sbom (not npm_sbom)" \
  "${FIXTURES_DIR}/java-webapp.munitor.yml" \
  "munitor/sbom"

run_negative_test "java-webapp: does not use npm_sbom" \
  "${FIXTURES_DIR}/java-webapp.munitor.yml" \
  "munitor/npm_sbom"

# Java-webapp sonar should still gate docker-build-push (regression guard)
run_context_test "java-webapp: sonar-scan blocks docker-build-push" \
  "${FIXTURES_DIR}/java-webapp.munitor.yml" \
  "name: docker-build-push" \
  "context:" \
  "sonar-scan"

# Test java-webapp-minimal: e2e/sbom/sonar should be excluded
run_test "java-webapp-minimal: renders java 17" \
  "${FIXTURES_DIR}/java-webapp-minimal.munitor.yml" \
  "java_version: \"17\""

run_test "java-webapp-minimal: has build-and-test" \
  "${FIXTURES_DIR}/java-webapp-minimal.munitor.yml" \
  "build-and-test"

run_negative_test "java-webapp-minimal: no e2e block" \
  "${FIXTURES_DIR}/java-webapp-minimal.munitor.yml" \
  "e2e-tests"

run_negative_test "java-webapp-minimal: no sbom block" \
  "${FIXTURES_DIR}/java-webapp-minimal.munitor.yml" \
  "sbom"

run_negative_test "java-webapp-minimal: no sonar block" \
  "${FIXTURES_DIR}/java-webapp-minimal.munitor.yml" \
  "sonar-scan"

# Test node-api renders with correct values
run_test "node-api: renders image_name" \
  "${FIXTURES_DIR}/node-api.munitor.yml" \
  "mes-assembly-server"

run_test "node-api: renders node_version" \
  "${FIXTURES_DIR}/node-api.munitor.yml" \
  "node_version: \"20\""

run_test "node-api: includes e2e when enabled" \
  "${FIXTURES_DIR}/node-api.munitor.yml" \
  "e2e-tests"

run_test "node-api: includes sonar when project_key set" \
  "${FIXTURES_DIR}/node-api.munitor.yml" \
  "sonar-scan"

run_test "node-api: uses npm_sonar_scan (not mvn sonar_scan)" \
  "${FIXTURES_DIR}/node-api.munitor.yml" \
  "munitor/npm_sonar_scan"

run_test "node-api: includes sbom when enabled" \
  "${FIXTURES_DIR}/node-api.munitor.yml" \
  "sbom"

run_test "node-api: uses npm_sbom (not mvn sbom)" \
  "${FIXTURES_DIR}/node-api.munitor.yml" \
  "munitor/npm_sbom"

run_negative_test "node-api: does not use mvn sbom job" \
  "${FIXTURES_DIR}/node-api.munitor.yml" \
  "munitor/sbom:"

# Verify the npm_sbom block includes the node_version parameter
run_context_test "node-api: npm_sbom passes node_version" \
  "${FIXTURES_DIR}/node-api.munitor.yml" \
  "munitor/npm_sbom" \
  "requires:" \
  "node_version:"

# Sonar non-blocking: sonar-scan should NOT be in docker-build-push requires
run_negative_context_test "node-api: sonar-scan not in docker-build-push requires" \
  "${FIXTURES_DIR}/node-api.munitor.yml" \
  "name: docker-build-push" \
  "context:" \
  "sonar-scan"

# Sonar job still exists in the workflow (just not blocking docker)
run_test "node-api: sonar-scan job still present in workflow" \
  "${FIXTURES_DIR}/node-api.munitor.yml" \
  "name: sonar-scan"

run_test "node-api: uses npm jobs" \
  "${FIXTURES_DIR}/node-api.munitor.yml" \
  "npm_build_and_test"

run_test "node-api: includes npm code quality" \
  "${FIXTURES_DIR}/node-api.munitor.yml" \
  "npm_code_quality"

run_test "node-api: includes npm security scan" \
  "${FIXTURES_DIR}/node-api.munitor.yml" \
  "npm_security_scan"

# Test node-api-minimal: e2e/sbom/sonar/extended features should be excluded
run_test "node-api-minimal: renders node 22" \
  "${FIXTURES_DIR}/node-api-minimal.munitor.yml" \
  "node_version: \"22\""

run_test "node-api-minimal: has build-and-test" \
  "${FIXTURES_DIR}/node-api-minimal.munitor.yml" \
  "build-and-test"

run_negative_test "node-api-minimal: no e2e block" \
  "${FIXTURES_DIR}/node-api-minimal.munitor.yml" \
  "e2e-tests"

run_negative_test "node-api-minimal: no sbom block" \
  "${FIXTURES_DIR}/node-api-minimal.munitor.yml" \
  "sbom"

run_negative_test "node-api-minimal: no sonar block" \
  "${FIXTURES_DIR}/node-api-minimal.munitor.yml" \
  "sonar-scan"

run_negative_test "node-api-minimal: no npm_auth block" \
  "${FIXTURES_DIR}/node-api-minimal.munitor.yml" \
  "npm_auth"

run_negative_test "node-api-minimal: no services block" \
  "${FIXTURES_DIR}/node-api-minimal.munitor.yml" \
  "services:"

run_negative_test "node-api-minimal: no test_setup block" \
  "${FIXTURES_DIR}/node-api-minimal.munitor.yml" \
  "test_setup"

run_negative_test "node-api-minimal: no test_commands block" \
  "${FIXTURES_DIR}/node-api-minimal.munitor.yml" \
  "test_commands"

run_negative_test "node-api-minimal: no coverage_command block" \
  "${FIXTURES_DIR}/node-api-minimal.munitor.yml" \
  "coverage_command"

# Test node-api-services: full-featured fixture with all extensions
run_test "node-api-services: includes npm_auth when private_registry true" \
  "${FIXTURES_DIR}/node-api-services.munitor.yml" \
  "npm_auth: true"

run_test "node-api-services: includes npm_scopes parameter" \
  "${FIXTURES_DIR}/node-api-services.munitor.yml" \
  "npm_scopes:"

run_test "node-api-services: includes services parameter" \
  "${FIXTURES_DIR}/node-api-services.munitor.yml" \
  "services:"

run_test "node-api-services: includes test_setup parameter" \
  "${FIXTURES_DIR}/node-api-services.munitor.yml" \
  "test_setup:"

run_test "node-api-services: includes test_commands parameter" \
  "${FIXTURES_DIR}/node-api-services.munitor.yml" \
  "test_commands:"

run_test "node-api-services: includes coverage_tool nyc" \
  "${FIXTURES_DIR}/node-api-services.munitor.yml" \
  "coverage_tool: nyc"

run_test "node-api-services: includes coverage_command" \
  "${FIXTURES_DIR}/node-api-services.munitor.yml" \
  "coverage_command:"

run_test "node-api-services: coverage min from test.coverage.min_instruction" \
  "${FIXTURES_DIR}/node-api-services.munitor.yml" \
  'min_coverage: "70"'

run_test "node-api-services: uses npm_sbom for sbom" \
  "${FIXTURES_DIR}/node-api-services.munitor.yml" \
  "munitor/npm_sbom"

run_negative_test "node-api-services: does not use mvn sbom job" \
  "${FIXTURES_DIR}/node-api-services.munitor.yml" \
  "munitor/sbom:"

# Test node-api-partial: custom test commands + NYC but no services/npm_auth/test_setup
run_test "node-api-partial: includes test_commands" \
  "${FIXTURES_DIR}/node-api-partial.munitor.yml" \
  "test_commands:"

run_test "node-api-partial: includes coverage_tool nyc" \
  "${FIXTURES_DIR}/node-api-partial.munitor.yml" \
  "coverage_tool: nyc"

run_test "node-api-partial: includes coverage_command" \
  "${FIXTURES_DIR}/node-api-partial.munitor.yml" \
  "coverage_command:"

run_test "node-api-partial: coverage min from test.coverage.min_instruction" \
  "${FIXTURES_DIR}/node-api-partial.munitor.yml" \
  'min_coverage: "75"'

run_negative_test "node-api-partial: no npm_auth" \
  "${FIXTURES_DIR}/node-api-partial.munitor.yml" \
  "npm_auth"

run_negative_test "node-api-partial: no services" \
  "${FIXTURES_DIR}/node-api-partial.munitor.yml" \
  "services:"

run_negative_test "node-api-partial: no test_setup" \
  "${FIXTURES_DIR}/node-api-partial.munitor.yml" \
  "test_setup"

# Test node-webapp renders with correct values
run_test "node-webapp: renders image_name" \
  "${FIXTURES_DIR}/node-webapp.munitor.yml" \
  "website-frontend"

run_test "node-webapp: renders node_version" \
  "${FIXTURES_DIR}/node-webapp.munitor.yml" \
  "node_version: \"22\""

run_test "node-webapp: includes e2e when enabled" \
  "${FIXTURES_DIR}/node-webapp.munitor.yml" \
  "e2e-tests"

run_test "node-webapp: includes sonar when project_key set" \
  "${FIXTURES_DIR}/node-webapp.munitor.yml" \
  "sonar-scan"

run_test "node-webapp: uses npm_sonar_scan (not mvn sonar_scan)" \
  "${FIXTURES_DIR}/node-webapp.munitor.yml" \
  "munitor/npm_sonar_scan"

run_test "node-webapp: includes sbom when enabled" \
  "${FIXTURES_DIR}/node-webapp.munitor.yml" \
  "sbom"

run_test "node-webapp: uses npm_sbom (not mvn sbom)" \
  "${FIXTURES_DIR}/node-webapp.munitor.yml" \
  "munitor/npm_sbom"

run_test "node-webapp: uses npm_build_and_test" \
  "${FIXTURES_DIR}/node-webapp.munitor.yml" \
  "npm_build_and_test"

run_test "node-webapp: includes npm code quality" \
  "${FIXTURES_DIR}/node-webapp.munitor.yml" \
  "npm_code_quality"

run_test "node-webapp: includes npm coverage" \
  "${FIXTURES_DIR}/node-webapp.munitor.yml" \
  "npm_coverage"

run_test "node-webapp: includes npm security scan" \
  "${FIXTURES_DIR}/node-webapp.munitor.yml" \
  "npm_security_scan"

# Sonar non-blocking: sonar-scan should NOT be in docker-build-push requires
run_negative_context_test "node-webapp: sonar-scan not in docker-build-push requires" \
  "${FIXTURES_DIR}/node-webapp.munitor.yml" \
  "name: docker-build-push" \
  "context:" \
  "sonar-scan"

# Health check defaults
run_context_test "node-webapp: docker-build-push health_port defaults to 3000" \
  "${FIXTURES_DIR}/node-webapp.munitor.yml" \
  "name: docker-build-push" \
  "context:" \
  'health_port: "3000"'

run_context_test "node-webapp: docker-build-push includes health_path" \
  "${FIXTURES_DIR}/node-webapp.munitor.yml" \
  "name: docker-build-push" \
  "context:" \
  "health_path: /api/health"

# Test node-webapp-minimal: e2e/sbom/sonar should be excluded
run_test "node-webapp-minimal: renders node 22" \
  "${FIXTURES_DIR}/node-webapp-minimal.munitor.yml" \
  "node_version: \"22\""

run_test "node-webapp-minimal: has build-and-test" \
  "${FIXTURES_DIR}/node-webapp-minimal.munitor.yml" \
  "build-and-test"

run_negative_test "node-webapp-minimal: no e2e block" \
  "${FIXTURES_DIR}/node-webapp-minimal.munitor.yml" \
  "e2e-tests"

run_negative_test "node-webapp-minimal: no sbom block" \
  "${FIXTURES_DIR}/node-webapp-minimal.munitor.yml" \
  "sbom"

run_negative_test "node-webapp-minimal: no sonar block" \
  "${FIXTURES_DIR}/node-webapp-minimal.munitor.yml" \
  "sonar-scan"

# Test sdk-distribution renders correctly
run_test "sdk-distribution: renders pipeline type" \
  "${FIXTURES_DIR}/sdk-distribution.munitor.yml" \
  "sdk-release"

run_test "sdk-distribution: includes github context" \
  "${FIXTURES_DIR}/sdk-distribution.munitor.yml" \
  "github"

# Test java-webapp: staging workflow present
run_test "java-webapp: includes staging workflow" \
  "${FIXTURES_DIR}/java-webapp.munitor.yml" \
  "staging:"

# Test java-webapp: CD update blocks when cd.repo is set
run_test "java-webapp: includes update-cd-repo when cd.repo set" \
  "${FIXTURES_DIR}/java-webapp.munitor.yml" \
  "update-cd-repo"

# Test java-webapp-no-cd: no update-cd-repo when cd.repo is missing
run_negative_test "java-webapp-no-cd: no update-cd-repo without cd.repo" \
  "${FIXTURES_DIR}/java-webapp-no-cd.munitor.yml" \
  "update-cd-repo"

# Test node-api: staging workflow present
run_test "node-api: includes staging workflow" \
  "${FIXTURES_DIR}/node-api.munitor.yml" \
  "staging:"

# Test node-api: CD update blocks when cd.repo is set
run_test "node-api: includes update-cd-repo when cd.repo set" \
  "${FIXTURES_DIR}/node-api.munitor.yml" \
  "update-cd-repo"

# Health check tests
run_context_test "node-api: docker-build-push includes health_path" \
  "${FIXTURES_DIR}/node-api.munitor.yml" \
  "name: docker-build-push" \
  "context:" \
  "health_path: /api/health"

run_context_test "node-api: docker-build-push health_port defaults to 3000" \
  "${FIXTURES_DIR}/node-api.munitor.yml" \
  "name: docker-build-push" \
  "context:" \
  'health_port: "3000"'

run_context_test "java-webapp: docker-build-push health_port defaults to 8080" \
  "${FIXTURES_DIR}/java-webapp.munitor.yml" \
  "name: docker-build-push" \
  "context:" \
  'health_port: "8080"'

run_context_test "node-api-services: custom health config overrides defaults" \
  "${FIXTURES_DIR}/node-api-services.munitor.yml" \
  "name: docker-build-push" \
  "context:" \
  "health_path: /health"

run_context_test "node-api-services: custom health_port overrides default" \
  "${FIXTURES_DIR}/node-api-services.munitor.yml" \
  "name: docker-build-push" \
  "context:" \
  'health_port: "4000"'

# Test java-webapp-portal: custom health, coverage, port settings
run_context_test "java-webapp-portal: health_port set to 8000" \
  "${FIXTURES_DIR}/java-webapp-portal.munitor.yml" \
  "name: docker-build-push" \
  "context:" \
  'health_port: "8000"'

run_context_test "java-webapp-portal: health_path set to /qqq-api/health" \
  "${FIXTURES_DIR}/java-webapp-portal.munitor.yml" \
  "name: docker-build-push" \
  "context:" \
  "health_path: /qqq-api/health"

run_test "java-webapp-portal: coverage set to 45" \
  "${FIXTURES_DIR}/java-webapp-portal.munitor.yml" \
  'min_instruction: "45"'

run_test "java-webapp-portal: includes e2e when enabled" \
  "${FIXTURES_DIR}/java-webapp-portal.munitor.yml" \
  "e2e-tests"

run_test "java-webapp-portal: includes sbom when enabled" \
  "${FIXTURES_DIR}/java-webapp-portal.munitor.yml" \
  "sbom"

# Test SAST fail_on_findings rendering
run_context_test "java-webapp-sast-warn: sast_scan has fail_on_findings false" \
  "${FIXTURES_DIR}/java-webapp-sast-warn.munitor.yml" \
  "name: sast-scan" \
  "filters:" \
  'fail_on_findings: "false"'

run_context_test "java-webapp: sast_scan has fail_on_findings true" \
  "${FIXTURES_DIR}/java-webapp.munitor.yml" \
  "name: sast-scan" \
  "filters:" \
  'fail_on_findings: "true"'

# Test terraform-sast: sast_scan has fail_on_findings true (boolean sast: true)
run_context_test "terraform-sast: sast_scan has fail_on_findings true" \
  "${FIXTURES_DIR}/terraform-sast.munitor.yml" \
  "name: sast-scan" \
  "filters:" \
  'fail_on_findings: "true"'

# --------------------------------------------------------------------------
# Release-candidate / Production workflow split tests
# --------------------------------------------------------------------------
echo ""
echo "=== Release-Candidate / Production Workflow Tests ==="

# java-webapp: has release-candidate and production workflows (not release)
run_test "java-webapp: has release-candidate workflow" \
  "${FIXTURES_DIR}/java-webapp.munitor.yml" \
  "release-candidate:"

run_test "java-webapp: has production workflow" \
  "${FIXTURES_DIR}/java-webapp.munitor.yml" \
  "production:"

run_negative_test "java-webapp: no legacy release workflow" \
  "${FIXTURES_DIR}/java-webapp.munitor.yml" \
  "^  release:"

# java-webapp: production workflow has NO quality gates
run_negative_context_test "java-webapp: production has no code-quality" \
  "${FIXTURES_DIR}/java-webapp.munitor.yml" \
  "production:" \
  "release-candidate:" \
  "code-quality"

run_negative_context_test "java-webapp: production has no coverage" \
  "${FIXTURES_DIR}/java-webapp.munitor.yml" \
  "production:" \
  "release-candidate:" \
  "mvn_coverage"

run_negative_context_test "java-webapp: production has no security-scan" \
  "${FIXTURES_DIR}/java-webapp.munitor.yml" \
  "production:" \
  "release-candidate:" \
  "security_scan"

# java-webapp: release-candidate has quality gates
run_context_test "java-webapp: release-candidate has code-quality" \
  "${FIXTURES_DIR}/java-webapp.munitor.yml" \
  "release-candidate:" \
  "production:" \
  "code-quality"

run_context_test "java-webapp: release-candidate has coverage" \
  "${FIXTURES_DIR}/java-webapp.munitor.yml" \
  "release-candidate:" \
  "production:" \
  "mvn_coverage"

run_context_test "java-webapp: release-candidate has security-scan" \
  "${FIXTURES_DIR}/java-webapp.munitor.yml" \
  "release-candidate:" \
  "production:" \
  "security_scan"

# java-webapp: both workflows have github-release
run_context_test "java-webapp: release-candidate has github-release" \
  "${FIXTURES_DIR}/java-webapp.munitor.yml" \
  "release-candidate:" \
  "production:" \
  "github-release"

run_context_test "java-webapp: production has github-release" \
  "${FIXTURES_DIR}/java-webapp.munitor.yml" \
  "production:" \
  "Results:" \
  "github-release"

# java-webapp: CD environments are correct
run_context_test "java-webapp: production CD uses prod env" \
  "${FIXTURES_DIR}/java-webapp.munitor.yml" \
  "production:" \
  "Results:" \
  "environment: prod"

run_context_test "java-webapp: release-candidate CD uses staging env" \
  "${FIXTURES_DIR}/java-webapp.munitor.yml" \
  "release-candidate:" \
  "production:" \
  "environment: staging"

# node-api: has release-candidate and production workflows
run_test "node-api: has release-candidate workflow" \
  "${FIXTURES_DIR}/node-api.munitor.yml" \
  "release-candidate:"

run_test "node-api: has production workflow" \
  "${FIXTURES_DIR}/node-api.munitor.yml" \
  "production:"

run_negative_test "node-api: no legacy release workflow" \
  "${FIXTURES_DIR}/node-api.munitor.yml" \
  "^  release:"

# node-api: production has no quality gates
run_negative_context_test "node-api: production has no code-quality" \
  "${FIXTURES_DIR}/node-api.munitor.yml" \
  "production:" \
  "release-candidate:" \
  "code-quality"

run_negative_context_test "node-api: production has no coverage" \
  "${FIXTURES_DIR}/node-api.munitor.yml" \
  "production:" \
  "release-candidate:" \
  "npm_coverage"

run_negative_context_test "node-api: production has no security-scan" \
  "${FIXTURES_DIR}/node-api.munitor.yml" \
  "production:" \
  "release-candidate:" \
  "npm_security_scan"

# node-api: release-candidate has quality gates
run_context_test "node-api: release-candidate has code-quality" \
  "${FIXTURES_DIR}/node-api.munitor.yml" \
  "release-candidate:" \
  "production:" \
  "code-quality"

# node-webapp: has release-candidate and production workflows
run_test "node-webapp: has release-candidate workflow" \
  "${FIXTURES_DIR}/node-webapp.munitor.yml" \
  "release-candidate:"

run_test "node-webapp: has production workflow" \
  "${FIXTURES_DIR}/node-webapp.munitor.yml" \
  "production:"

run_negative_test "node-webapp: no legacy release workflow" \
  "${FIXTURES_DIR}/node-webapp.munitor.yml" \
  "^  release:"

# node-webapp: production has no quality gates
run_negative_context_test "node-webapp: production has no code-quality" \
  "${FIXTURES_DIR}/node-webapp.munitor.yml" \
  "production:" \
  "release-candidate:" \
  "code-quality"

run_negative_context_test "node-webapp: production has no coverage" \
  "${FIXTURES_DIR}/node-webapp.munitor.yml" \
  "production:" \
  "release-candidate:" \
  "npm_coverage"

run_negative_context_test "node-webapp: production has no security-scan" \
  "${FIXTURES_DIR}/node-webapp.munitor.yml" \
  "production:" \
  "release-candidate:" \
  "npm_security_scan"

# node-webapp: release-candidate has quality gates
run_context_test "node-webapp: release-candidate has code-quality" \
  "${FIXTURES_DIR}/node-webapp.munitor.yml" \
  "release-candidate:" \
  "production:" \
  "code-quality"

# node-webapp: staging workflow present
run_test "node-webapp: includes staging workflow" \
  "${FIXTURES_DIR}/node-webapp.munitor.yml" \
  "staging:"

# node-webapp: CD update blocks when cd.repo is set
run_test "node-webapp: includes update-cd-repo when cd.repo set" \
  "${FIXTURES_DIR}/node-webapp.munitor.yml" \
  "update-cd-repo"

# terraform: has release-candidate and production workflows
run_test "terraform: has release-candidate workflow" \
  "${FIXTURES_DIR}/terraform.munitor.yml" \
  "release-candidate:"

run_test "terraform: has production workflow" \
  "${FIXTURES_DIR}/terraform.munitor.yml" \
  "production:"

run_negative_test "terraform: no legacy release workflow" \
  "${FIXTURES_DIR}/terraform.munitor.yml" \
  "^  release:"

# terraform: production has only validate-repo and tf-validate
run_negative_context_test "terraform: production has no tf-security-scan" \
  "${FIXTURES_DIR}/terraform.munitor.yml" \
  "production:" \
  "Results:" \
  "tf-security-scan"

run_negative_context_test "terraform: production has no secrets-scan" \
  "${FIXTURES_DIR}/terraform.munitor.yml" \
  "production:" \
  "Results:" \
  "secrets-scan"

# terraform: release-candidate has full validation
run_context_test "terraform: release-candidate has tf-security-scan" \
  "${FIXTURES_DIR}/terraform.munitor.yml" \
  "release-candidate:" \
  "production:" \
  "tf-security-scan"

run_context_test "terraform: release-candidate has secrets-scan" \
  "${FIXTURES_DIR}/terraform.munitor.yml" \
  "release-candidate:" \
  "production:" \
  "secrets-scan"

# --------------------------------------------------------------------------
# validate-cd-repo Template Tests
# --------------------------------------------------------------------------
echo ""
echo "=== validate-cd-repo Template Tests ==="

# Basic rendering
run_test "validate-cd-repo: renders orb version" \
  "${FIXTURES_DIR}/validate-cd-repo.munitor.yml" \
  "kof22/munitor@dev:snapshot"

# Workflow presence
run_test "validate-cd-repo: has pr-checks workflow" \
  "${FIXTURES_DIR}/validate-cd-repo.munitor.yml" \
  "pr-checks:"

run_test "validate-cd-repo: has develop workflow" \
  "${FIXTURES_DIR}/validate-cd-repo.munitor.yml" \
  "develop:"

run_test "validate-cd-repo: has release workflow" \
  "${FIXTURES_DIR}/validate-cd-repo.munitor.yml" \
  "release:"

# Job presence
run_test "validate-cd-repo: has yaml-lint job" \
  "${FIXTURES_DIR}/validate-cd-repo.munitor.yml" \
  "name: yaml-lint"

run_test "validate-cd-repo: has kustomize-validate job" \
  "${FIXTURES_DIR}/validate-cd-repo.munitor.yml" \
  "name: kustomize-validate"

run_test "validate-cd-repo: has kubesec-scan job" \
  "${FIXTURES_DIR}/validate-cd-repo.munitor.yml" \
  "name: kubesec-scan"

run_test "validate-cd-repo: has kube-linter job" \
  "${FIXTURES_DIR}/validate-cd-repo.munitor.yml" \
  "name: kube-linter"

run_test "validate-cd-repo: has secrets-scan job" \
  "${FIXTURES_DIR}/validate-cd-repo.munitor.yml" \
  "name: secrets-scan"

# Job dependencies
run_context_test "validate-cd-repo: kubesec-scan requires kustomize-validate" \
  "${FIXTURES_DIR}/validate-cd-repo.munitor.yml" \
  "name: kubesec-scan" \
  "filters:" \
  "kustomize-validate"

run_context_test "validate-cd-repo: kube-linter requires kustomize-validate" \
  "${FIXTURES_DIR}/validate-cd-repo.munitor.yml" \
  "name: kube-linter" \
  "filters:" \
  "kustomize-validate"

# Version rendering
run_test "validate-cd-repo: renders kustomize version" \
  "${FIXTURES_DIR}/validate-cd-repo.munitor.yml" \
  'kustomize_version: "5.5.0"'

run_test "validate-cd-repo: renders overlays" \
  "${FIXTURES_DIR}/validate-cd-repo.munitor.yml" \
  "overlays: \"dev staging production\""

run_test "validate-cd-repo: renders scan_overlay" \
  "${FIXTURES_DIR}/validate-cd-repo.munitor.yml" \
  'scan_overlay: "production"'

run_test "validate-cd-repo: renders kube_linter config" \
  "${FIXTURES_DIR}/validate-cd-repo.munitor.yml" \
  "config: \".kube-linter.yaml\""

# Branch filters
run_context_test "validate-cd-repo: pr-checks has feature branch filter" \
  "${FIXTURES_DIR}/validate-cd-repo.munitor.yml" \
  "pr-checks:" \
  "develop:" \
  "feature"

run_context_test "validate-cd-repo: develop has develop branch filter" \
  "${FIXTURES_DIR}/validate-cd-repo.munitor.yml" \
  "develop:" \
  "release:" \
  "only: develop"

run_context_test "validate-cd-repo: release has main branch filter" \
  "${FIXTURES_DIR}/validate-cd-repo.munitor.yml" \
  "release:" \
  "Results:" \
  "only: main"

# Negative tests: no app-pipeline artifacts
run_negative_test "validate-cd-repo: no docker job" \
  "${FIXTURES_DIR}/validate-cd-repo.munitor.yml" \
  "docker-build-push"

run_negative_test "validate-cd-repo: no build-and-test job" \
  "${FIXTURES_DIR}/validate-cd-repo.munitor.yml" \
  "build-and-test"

run_negative_test "validate-cd-repo: no update-cd-repo job" \
  "${FIXTURES_DIR}/validate-cd-repo.munitor.yml" \
  "update-cd-repo"

run_negative_test "validate-cd-repo: no github-release job" \
  "${FIXTURES_DIR}/validate-cd-repo.munitor.yml" \
  "github-release"

# Minimal fixture tests (defaults)
run_test "validate-cd-repo-minimal: renders correctly" \
  "${FIXTURES_DIR}/validate-cd-repo-minimal.munitor.yml" \
  "kof22/munitor@dev:snapshot"

run_test "validate-cd-repo-minimal: has all three workflows" \
  "${FIXTURES_DIR}/validate-cd-repo-minimal.munitor.yml" \
  "pr-checks:"

run_test "validate-cd-repo-minimal: default kustomize version" \
  "${FIXTURES_DIR}/validate-cd-repo-minimal.munitor.yml" \
  'kustomize_version: "5.5.0"'

run_test "validate-cd-repo-minimal: default scan_overlay" \
  "${FIXTURES_DIR}/validate-cd-repo-minimal.munitor.yml" \
  'scan_overlay: "production"'

run_test "validate-cd-repo-minimal: default base_path" \
  "${FIXTURES_DIR}/validate-cd-repo-minimal.munitor.yml" \
  'base_path: "base/"'

# --------------------------------------------------------------------------
# argocd-apps Template Tests
# --------------------------------------------------------------------------
echo ""
echo "=== argocd-apps Template Tests ==="

# Basic rendering
run_test "argocd-apps: renders orb version" \
  "${FIXTURES_DIR}/argocd-apps.munitor.yml" \
  "kof22/munitor@dev:snapshot"

# Workflow presence
run_test "argocd-apps: has pr-checks workflow" \
  "${FIXTURES_DIR}/argocd-apps.munitor.yml" \
  "pr-checks:"

run_test "argocd-apps: has develop workflow" \
  "${FIXTURES_DIR}/argocd-apps.munitor.yml" \
  "develop:"

run_test "argocd-apps: has release workflow" \
  "${FIXTURES_DIR}/argocd-apps.munitor.yml" \
  "release:"

# Job presence
run_test "argocd-apps: has yaml-lint job" \
  "${FIXTURES_DIR}/argocd-apps.munitor.yml" \
  "name: yaml-lint"

run_test "argocd-apps: has kustomize-validate job" \
  "${FIXTURES_DIR}/argocd-apps.munitor.yml" \
  "name: kustomize-validate"

run_test "argocd-apps: has kubesec-scan job" \
  "${FIXTURES_DIR}/argocd-apps.munitor.yml" \
  "name: kubesec-scan"

run_test "argocd-apps: has kube-linter job" \
  "${FIXTURES_DIR}/argocd-apps.munitor.yml" \
  "name: kube-linter"

run_test "argocd-apps: has secrets-scan job" \
  "${FIXTURES_DIR}/argocd-apps.munitor.yml" \
  "name: secrets-scan"

# overlay_dir rendering
run_test "argocd-apps: renders overlay_dir as envs" \
  "${FIXTURES_DIR}/argocd-apps.munitor.yml" \
  'overlay_dir: "envs"'

# base_path rendering (empty string)
run_test "argocd-apps: renders empty base_path" \
  "${FIXTURES_DIR}/argocd-apps.munitor.yml" \
  'base_path: ""'

# yamllint_paths rendering
run_test "argocd-apps: renders argocd-apps yamllint paths" \
  "${FIXTURES_DIR}/argocd-apps.munitor.yml" \
  "bootstrap/ projects/ credentials/ envs/ apps/ infra/"

# Version rendering
run_test "argocd-apps: renders kustomize version" \
  "${FIXTURES_DIR}/argocd-apps.munitor.yml" \
  'kustomize_version: "5.5.0"'

run_test "argocd-apps: renders overlays" \
  "${FIXTURES_DIR}/argocd-apps.munitor.yml" \
  "overlays: \"dev staging production\""

run_test "argocd-apps: renders scan_overlay" \
  "${FIXTURES_DIR}/argocd-apps.munitor.yml" \
  'scan_overlay: "production"'

run_test "argocd-apps: renders kube_linter config" \
  "${FIXTURES_DIR}/argocd-apps.munitor.yml" \
  "config: \".kube-linter.yaml\""

# Job dependencies
run_context_test "argocd-apps: kubesec-scan requires kustomize-validate" \
  "${FIXTURES_DIR}/argocd-apps.munitor.yml" \
  "name: kubesec-scan" \
  "filters:" \
  "kustomize-validate"

run_context_test "argocd-apps: kube-linter requires kustomize-validate" \
  "${FIXTURES_DIR}/argocd-apps.munitor.yml" \
  "name: kube-linter" \
  "filters:" \
  "kustomize-validate"

# Branch filters
run_context_test "argocd-apps: pr-checks has feature branch filter" \
  "${FIXTURES_DIR}/argocd-apps.munitor.yml" \
  "pr-checks:" \
  "develop:" \
  "feature"

run_context_test "argocd-apps: develop has develop branch filter" \
  "${FIXTURES_DIR}/argocd-apps.munitor.yml" \
  "develop:" \
  "release:" \
  "only: develop"

run_context_test "argocd-apps: release has main branch filter" \
  "${FIXTURES_DIR}/argocd-apps.munitor.yml" \
  "release:" \
  "Results:" \
  "only: main"

# Negative tests: no app-pipeline artifacts
run_negative_test "argocd-apps: no docker job" \
  "${FIXTURES_DIR}/argocd-apps.munitor.yml" \
  "docker-build-push"

run_negative_test "argocd-apps: no build-and-test job" \
  "${FIXTURES_DIR}/argocd-apps.munitor.yml" \
  "build-and-test"

run_negative_test "argocd-apps: no update-cd-repo job" \
  "${FIXTURES_DIR}/argocd-apps.munitor.yml" \
  "update-cd-repo"

run_negative_test "argocd-apps: no github-release job" \
  "${FIXTURES_DIR}/argocd-apps.munitor.yml" \
  "github-release"

# Minimal fixture tests (defaults)
run_test "argocd-apps-minimal: renders correctly" \
  "${FIXTURES_DIR}/argocd-apps-minimal.munitor.yml" \
  "kof22/munitor@dev:snapshot"

run_test "argocd-apps-minimal: has all three workflows" \
  "${FIXTURES_DIR}/argocd-apps-minimal.munitor.yml" \
  "pr-checks:"

run_test "argocd-apps-minimal: default kustomize version" \
  "${FIXTURES_DIR}/argocd-apps-minimal.munitor.yml" \
  'kustomize_version: "5.5.0"'

run_test "argocd-apps-minimal: default scan_overlay" \
  "${FIXTURES_DIR}/argocd-apps-minimal.munitor.yml" \
  'scan_overlay: "production"'

run_test "argocd-apps-minimal: default overlay_dir" \
  "${FIXTURES_DIR}/argocd-apps-minimal.munitor.yml" \
  'overlay_dir: "overlays"'

run_test "argocd-apps-minimal: default base_path" \
  "${FIXTURES_DIR}/argocd-apps-minimal.munitor.yml" \
  'base_path: "base/"'

# Regression: validate-cd-repo does NOT have overlay_dir param
run_negative_test "validate-cd-repo: no overlay_dir param (regression)" \
  "${FIXTURES_DIR}/validate-cd-repo.munitor.yml" \
  "overlay_dir:"

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="

if [[ ${FAIL} -gt 0 ]]; then
  exit 1
fi
