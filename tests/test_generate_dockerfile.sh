#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SCRIPT="${PROJECT_DIR}/src/scripts/generate_dockerfile.sh"
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

# Create a temp working directory for each test
setup() {
  WORK_DIR=$(mktemp -d)
}

teardown() {
  rm -rf "${WORK_DIR}"
}

run_generate() {
  (cd "${WORK_DIR}" && MUNITOR_CONFIG=".munitor.yml" bash "${SCRIPT}" 2>&1)
}

run_generate_rc() {
  (cd "${WORK_DIR}" && MUNITOR_CONFIG=".munitor.yml" bash "${SCRIPT}" 2>&1) || true
  (cd "${WORK_DIR}" && MUNITOR_CONFIG=".munitor.yml" bash "${SCRIPT}" >/dev/null 2>&1)
  echo $?
}

# =============================================================================
# Test: node-api generates correct Dockerfile
# =============================================================================
echo "=== node-api Dockerfile Generation ==="

echo -n "  TEST: generates Dockerfile with node:20-alpine (default)... "
setup
cat > "${WORK_DIR}/.munitor.yml" <<'EOF'
pipeline: node-api
image_name: my-app
EOF
run_generate > /dev/null
if grep -q 'FROM node:20-alpine AS deps' "${WORK_DIR}/Dockerfile"; then
  pass
else
  fail "expected node:20-alpine"
fi
teardown

echo -n "  TEST: generates Dockerfile with node:22-alpine (custom)... "
setup
cat > "${WORK_DIR}/.munitor.yml" <<'EOF'
pipeline: node-api
image_name: my-app
node_version: "22"
EOF
run_generate > /dev/null
if grep -q 'FROM node:22-alpine AS deps' "${WORK_DIR}/Dockerfile"; then
  pass
else
  fail "expected node:22-alpine"
fi
teardown

echo -n "  TEST: includes STANDALONE=true env... "
setup
cat > "${WORK_DIR}/.munitor.yml" <<'EOF'
pipeline: node-api
image_name: my-app
EOF
run_generate > /dev/null
if grep -q 'ENV STANDALONE=true' "${WORK_DIR}/Dockerfile"; then
  pass
else
  fail "expected STANDALONE=true"
fi
teardown

echo -n "  TEST: includes npm ci in deps stage... "
setup
cat > "${WORK_DIR}/.munitor.yml" <<'EOF'
pipeline: node-api
image_name: my-app
EOF
run_generate > /dev/null
if grep -q 'RUN npm ci' "${WORK_DIR}/Dockerfile"; then
  pass
else
  fail "expected npm ci"
fi
teardown

echo -n "  TEST: runs as nextjs user... "
setup
cat > "${WORK_DIR}/.munitor.yml" <<'EOF'
pipeline: node-api
image_name: my-app
EOF
run_generate > /dev/null
if grep -q 'USER nextjs' "${WORK_DIR}/Dockerfile"; then
  pass
else
  fail "expected USER nextjs"
fi
teardown

# =============================================================================
# Test: node-api Express framework generates correct Dockerfile
# =============================================================================
echo ""
echo "=== node-api Express Dockerfile Generation ==="

echo -n "  TEST: express generates Dockerfile without STANDALONE env... "
setup
cat > "${WORK_DIR}/.munitor.yml" <<'EOF'
pipeline: node-api
image_name: my-express-app
node:
  framework: express
EOF
run_generate > /dev/null
if ! grep -q 'ENV STANDALONE=true' "${WORK_DIR}/Dockerfile"; then
  pass
else
  fail "expected no STANDALONE env for express"
fi
teardown

echo -n "  TEST: express does not copy .next/standalone... "
setup
cat > "${WORK_DIR}/.munitor.yml" <<'EOF'
pipeline: node-api
image_name: my-express-app
node:
  framework: express
EOF
run_generate > /dev/null
if ! grep -q '.next/standalone' "${WORK_DIR}/Dockerfile"; then
  pass
else
  fail "expected no .next/standalone for express"
fi
teardown

echo -n "  TEST: express uses appuser not nextjs... "
setup
cat > "${WORK_DIR}/.munitor.yml" <<'EOF'
pipeline: node-api
image_name: my-express-app
node:
  framework: express
EOF
run_generate > /dev/null
if grep -q 'USER appuser' "${WORK_DIR}/Dockerfile" && ! grep -q 'USER nextjs' "${WORK_DIR}/Dockerfile"; then
  pass
else
  fail "expected USER appuser, not nextjs"
fi
teardown

echo -n "  TEST: express CMD uses node . ... "
setup
cat > "${WORK_DIR}/.munitor.yml" <<'EOF'
pipeline: node-api
image_name: my-express-app
node:
  framework: express
EOF
run_generate > /dev/null
if grep -q 'CMD \["node", "."\]' "${WORK_DIR}/Dockerfile"; then
  pass
else
  fail "expected CMD [\"node\", \".\"]"
fi
teardown

echo -n "  TEST: express includes HEALTHCHECK... "
setup
cat > "${WORK_DIR}/.munitor.yml" <<'EOF'
pipeline: node-api
image_name: my-express-app
node:
  framework: express
EOF
run_generate > /dev/null
if grep -q 'HEALTHCHECK' "${WORK_DIR}/Dockerfile"; then
  pass
else
  fail "expected HEALTHCHECK directive"
fi
teardown

echo -n "  TEST: express EXPOSE uses health port (default 3000)... "
setup
cat > "${WORK_DIR}/.munitor.yml" <<'EOF'
pipeline: node-api
image_name: my-express-app
node:
  framework: express
EOF
run_generate > /dev/null
if grep -q 'EXPOSE 3000' "${WORK_DIR}/Dockerfile"; then
  pass
else
  fail "expected EXPOSE 3000"
fi
teardown

echo -n "  TEST: express EXPOSE uses custom health port... "
setup
cat > "${WORK_DIR}/.munitor.yml" <<'EOF'
pipeline: node-api
image_name: my-express-app
node:
  framework: express
health:
  port: 4000
EOF
run_generate > /dev/null
if grep -q 'EXPOSE 4000' "${WORK_DIR}/Dockerfile"; then
  pass
else
  fail "expected EXPOSE 4000"
fi
teardown

echo -n "  TEST: express npm ci uses --omit=dev... "
setup
cat > "${WORK_DIR}/.munitor.yml" <<'EOF'
pipeline: node-api
image_name: my-express-app
node:
  framework: express
EOF
run_generate > /dev/null
if grep -q 'npm ci --omit=dev' "${WORK_DIR}/Dockerfile"; then
  pass
else
  fail "expected npm ci --omit=dev"
fi
teardown

echo -n "  TEST: unsupported node framework fails... "
setup
cat > "${WORK_DIR}/.munitor.yml" <<'EOF'
pipeline: node-api
image_name: my-app
node:
  framework: koa
EOF
OUTPUT=$(cd "${WORK_DIR}" && MUNITOR_CONFIG=".munitor.yml" bash "${SCRIPT}" 2>&1 || true)
RC=$(cd "${WORK_DIR}" && MUNITOR_CONFIG=".munitor.yml" bash "${SCRIPT}" >/dev/null 2>&1; echo $?) || true
if [[ "${RC}" -ne 0 ]] && echo "${OUTPUT}" | grep -q "Unsupported node framework"; then
  pass
else
  fail "expected non-zero exit for unsupported framework"
fi
teardown

# =============================================================================
# Test: java-webapp generates correct Dockerfile
# =============================================================================
echo ""
echo "=== java-webapp Dockerfile Generation ==="

# Helper to set up java-webapp test with a mock JAR
setup_java() {
  setup
  mkdir -p "${WORK_DIR}/target"
  touch "${WORK_DIR}/target/my-app-1.0.0.jar"
}

echo -n "  TEST: generates Dockerfile with Alpine JRE base... "
setup_java
cat > "${WORK_DIR}/.munitor.yml" <<'EOF'
pipeline: java-webapp
image_name: my-app
EOF
run_generate > /dev/null
if grep -q 'FROM eclipse-temurin:21-jre-alpine' "${WORK_DIR}/Dockerfile"; then
  pass
else
  fail "expected eclipse-temurin:21-jre-alpine"
fi
teardown

echo -n "  TEST: generates Dockerfile with temurin-17-jre-alpine (custom)... "
setup_java
cat > "${WORK_DIR}/.munitor.yml" <<'EOF'
pipeline: java-webapp
image_name: my-app
java_version: "17"
EOF
run_generate > /dev/null
if grep -q 'FROM eclipse-temurin:17-jre-alpine' "${WORK_DIR}/Dockerfile"; then
  pass
else
  fail "expected eclipse-temurin:17-jre-alpine"
fi
teardown

echo -n "  TEST: uses non-root user (appuser)... "
setup_java
cat > "${WORK_DIR}/.munitor.yml" <<'EOF'
pipeline: java-webapp
image_name: my-app
EOF
run_generate > /dev/null
if grep -q 'USER appuser' "${WORK_DIR}/Dockerfile"; then
  pass
else
  fail "expected USER appuser"
fi
teardown

echo -n "  TEST: EXPOSE uses health port (default 8080)... "
setup_java
cat > "${WORK_DIR}/.munitor.yml" <<'EOF'
pipeline: java-webapp
image_name: my-app
EOF
run_generate > /dev/null
if grep -q 'EXPOSE 8080' "${WORK_DIR}/Dockerfile"; then
  pass
else
  fail "expected EXPOSE 8080"
fi
teardown

echo -n "  TEST: EXPOSE uses custom health port... "
setup_java
cat > "${WORK_DIR}/.munitor.yml" <<'EOF'
pipeline: java-webapp
image_name: my-app
health:
  port: 8000
EOF
run_generate > /dev/null
if grep -q 'EXPOSE 8000' "${WORK_DIR}/Dockerfile"; then
  pass
else
  fail "expected EXPOSE 8000"
fi
teardown

echo -n "  TEST: HEALTHCHECK uses health path and port... "
setup_java
cat > "${WORK_DIR}/.munitor.yml" <<'EOF'
pipeline: java-webapp
image_name: my-app
health:
  path: /qqq-api/health
  port: 8000
EOF
run_generate > /dev/null
if grep -q 'http://localhost:8000/qqq-api/health' "${WORK_DIR}/Dockerfile"; then
  pass
else
  fail "expected HEALTHCHECK with custom path/port"
fi
teardown

echo -n "  TEST: includes JVM container tuning flags... "
setup_java
cat > "${WORK_DIR}/.munitor.yml" <<'EOF'
pipeline: java-webapp
image_name: my-app
EOF
run_generate > /dev/null
if grep -q 'UseContainerSupport' "${WORK_DIR}/Dockerfile" \
  && grep -q 'MaxRAMPercentage' "${WORK_DIR}/Dockerfile"; then
  pass
else
  fail "expected JVM container flags"
fi
teardown

echo -n "  TEST: copies detected JAR as app.jar... "
setup_java
cat > "${WORK_DIR}/.munitor.yml" <<'EOF'
pipeline: java-webapp
image_name: my-app
EOF
run_generate > /dev/null
if grep -q 'COPY target/my-app-1.0.0.jar app.jar' "${WORK_DIR}/Dockerfile"; then
  pass
else
  fail "expected COPY with detected JAR path"
fi
teardown

echo -n "  TEST: excludes original-* JARs from detection... "
setup_java
touch "${WORK_DIR}/target/original-my-app-1.0.0.jar"
cat > "${WORK_DIR}/.munitor.yml" <<'EOF'
pipeline: java-webapp
image_name: my-app
EOF
run_generate > /dev/null
if grep -q 'COPY target/my-app-1.0.0.jar app.jar' "${WORK_DIR}/Dockerfile"; then
  pass
else
  fail "expected original-* to be excluded"
fi
teardown

echo -n "  TEST: fails when no JAR found in target/... "
setup
cat > "${WORK_DIR}/.munitor.yml" <<'EOF'
pipeline: java-webapp
image_name: my-app
EOF
OUTPUT=$(cd "${WORK_DIR}" && MUNITOR_CONFIG=".munitor.yml" bash "${SCRIPT}" 2>&1 || true)
RC=$(cd "${WORK_DIR}" && MUNITOR_CONFIG=".munitor.yml" bash "${SCRIPT}" >/dev/null 2>&1; echo $?) || true
if [[ "${RC}" -ne 0 ]] && echo "${OUTPUT}" | grep -q "No application JAR found"; then
  pass
else
  fail "expected failure when no JAR in target/"
fi
teardown

echo -n "  TEST: no builder stage (no maven FROM)... "
setup_java
cat > "${WORK_DIR}/.munitor.yml" <<'EOF'
pipeline: java-webapp
image_name: my-app
EOF
run_generate > /dev/null
if ! grep -q 'FROM maven' "${WORK_DIR}/Dockerfile"; then
  pass
else
  fail "expected no maven builder stage"
fi
teardown

# =============================================================================
# Test: node-webapp auto-generates Dockerfile
# =============================================================================
echo ""
echo "=== node-webapp Dockerfile Generation ==="

echo -n "  TEST: generates Dockerfile for node-webapp... "
setup
cat > "${WORK_DIR}/.munitor.yml" <<'EOF'
pipeline: node-webapp
image_name: my-webapp
node_version: "22"
EOF
OUTPUT=$(run_generate)
if echo "${OUTPUT}" | grep -q "Generating Dockerfile for node-webapp"; then
  pass
else
  fail "expected 'Generating Dockerfile for node-webapp' message"
fi
teardown

echo -n "  TEST: uses distroless runner image... "
setup
cat > "${WORK_DIR}/.munitor.yml" <<'EOF'
pipeline: node-webapp
image_name: my-webapp
node_version: "22"
EOF
run_generate > /dev/null
if grep -q "gcr.io/distroless/nodejs22-debian12" "${WORK_DIR}/Dockerfile"; then
  pass
else
  fail "expected distroless runner image in Dockerfile"
fi
teardown

echo -n "  TEST: overwrites existing Dockerfile... "
setup
cat > "${WORK_DIR}/.munitor.yml" <<'EOF'
pipeline: node-webapp
image_name: my-webapp
node_version: "22"
EOF
echo "OLD CONTENT" > "${WORK_DIR}/Dockerfile"
run_generate > /dev/null
if ! grep -q "OLD CONTENT" "${WORK_DIR}/Dockerfile" && grep -q "distroless" "${WORK_DIR}/Dockerfile"; then
  pass
else
  fail "Dockerfile was not overwritten with generated content"
fi
teardown

# =============================================================================
# Test: unsupported pipeline type
# =============================================================================
echo ""
echo "=== Error Handling ==="

echo -n "  TEST: fails for unsupported pipeline type... "
setup
cat > "${WORK_DIR}/.munitor.yml" <<'EOF'
pipeline: python-api
image_name: my-app
EOF
OUTPUT=$(cd "${WORK_DIR}" && MUNITOR_CONFIG=".munitor.yml" bash "${SCRIPT}" 2>&1 || true)
RC=$(cd "${WORK_DIR}" && MUNITOR_CONFIG=".munitor.yml" bash "${SCRIPT}" >/dev/null 2>&1; echo $?) || true
if [[ "${RC}" -ne 0 ]] && echo "${OUTPUT}" | grep -q "Unsupported pipeline type"; then
  pass
else
  fail "expected non-zero exit and error message (rc=${RC})"
fi
teardown

echo -n "  TEST: fails when .munitor.yml is missing... "
setup
OUTPUT=$(cd "${WORK_DIR}" && MUNITOR_CONFIG=".munitor.yml" bash "${SCRIPT}" 2>&1 || true)
RC=$(cd "${WORK_DIR}" && MUNITOR_CONFIG=".munitor.yml" bash "${SCRIPT}" >/dev/null 2>&1; echo $?) || true
if [[ "${RC}" -ne 0 ]] && echo "${OUTPUT}" | grep -q "not found"; then
  pass
else
  fail "expected non-zero exit for missing config"
fi
teardown

# =============================================================================
# Test: generated file is non-empty
# =============================================================================
echo ""
echo "=== File Validation ==="

echo -n "  TEST: generated Dockerfile exists and is non-empty... "
setup
cat > "${WORK_DIR}/.munitor.yml" <<'EOF'
pipeline: node-api
image_name: my-app
node_version: "22"
EOF
run_generate > /dev/null
if [[ -s "${WORK_DIR}/Dockerfile" ]]; then
  pass
else
  fail "Dockerfile missing or empty"
fi
teardown

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="

if [[ ${FAIL} -gt 0 ]]; then
  exit 1
fi
