#!/usr/bin/env bats

setup() {
  export PROJECT_DIR="${BATS_TEST_DIRNAME}/.."
  export WORK="${BATS_TEST_TMPDIR}/work"
  node "${BATS_TEST_DIRNAME}/fixtures/npm-audit/build-fixture.cjs" "${WORK}"
  mkdir -p "${WORK}/bin"
  cat > "${WORK}/bin/npm" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == view ]]; then printf '"%s"\n' "${LATEST_VERSION:-3.0.3}"; exit 0; fi
if [[ "$*" == *--omit=dev* ]]; then cat production.json; exit 0; fi
cat full.json
exit "${MOCK_AUDIT_STATUS:-1}"
MOCK
  chmod +x "${WORK}/bin/npm"
  export PATH="${WORK}/bin:${PATH}"
  cd "${WORK}"
}

@test "accepts only the registered advisory and its propagated development findings" {
  run bash "${PROJECT_DIR}/src/scripts/node_audit.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Accepted EX-0008"* ]]
}

@test "fails closed for expired, invalid, unrelated, mixed, critical and runtime findings" {
  for scenario in expired invalid-date different mixed critical production runtime-path different-version unknown-chain cycle counts registry-error; do
    node "${BATS_TEST_DIRNAME}/fixtures/npm-audit/build-fixture.cjs" "$WORK" "$scenario"
    run bash "${PROJECT_DIR}/src/scripts/node_audit.sh"
    if [ "$status" -eq 0 ]; then echo "Unexpected acceptance: $scenario"; return 1; fi
  done
}

@test "a new upstream release requires reassessment" {
  export LATEST_VERSION=3.0.4
  run bash "${PROJECT_DIR}/src/scripts/node_audit.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"New braces release available"* ]]
}

@test "malformed reports and unexpected audit exit codes fail closed" {
  export MOCK_AUDIT_STATUS=2
  run bash "${PROJECT_DIR}/src/scripts/node_audit.sh"
  [ "$status" -ne 0 ]
  printf 'invalid json' > full.json
  run bash "${PROJECT_DIR}/src/scripts/node_audit.sh"
  [ "$status" -ne 0 ]
}

@test "repositories without exceptions retain their existing audit gate" {
  rm .npm-audit-exceptions.json
  run bash "${PROJECT_DIR}/src/scripts/node_audit.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"npm audit found high/critical"* ]]
}
