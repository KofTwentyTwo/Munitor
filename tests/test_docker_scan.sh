#!/usr/bin/env bash
# Exercise image scanning with local tool stubs; no Docker daemon or network needed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_SCRIPTS="$(cd "${SCRIPT_DIR}/../src/scripts" && pwd)"
WORK=$(mktemp -d)
trap 'rm -rf "${WORK}"' EXIT
PASS=0
FAIL=0
pass() { echo "PASS"; PASS=$((PASS + 1)); }
fail() { echo "FAIL"; FAIL=$((FAIL + 1)); }

mkdir -p "${WORK}/bin" "${WORK}/home/bin" "${WORK}/repo"
cat > "${WORK}/bin/docker" <<'EOF'
#!/usr/bin/env bash
printf 'docker %s\n' "$*" >> "${CALL_LOG}"
EOF
cat > "${WORK}/home/bin/trivy" <<'EOF'
#!/usr/bin/env bash
[[ -f .trivyignore ]] || exit 99
printf 'trivy %s\n' "$*" >> "${CALL_LOG}"
# Redirect the production /tmp output path into the test workspace.
while [[ $# -gt 0 ]]; do
  if [[ "$1" == --output ]]; then
    printf '{"Results":[]}\n' > "${REPORT_DIR}/$(basename "$2")"
  fi
  shift
done
exit "${SCAN_EXIT:-0}"
EOF
chmod +x "${WORK}/bin/docker" "${WORK}/home/bin/trivy"
export PATH="${WORK}/bin:${PATH}" HOME="${WORK}/home"
export CALL_LOG="${WORK}/calls" REPORT_DIR="${WORK}"
export IMAGE_NAME=app REGISTRY=ghcr.io/example CIRCLE_SHA1=abcdef123456
export SUPPLEMENTAL_IMAGES_JSON='[{"name":"migrations","dockerfile":"Dockerfile.migrations"},{"name":"worker","base":"example/base:1"}]'
cd "${WORK}/repo"
touch .trivyignore

echo "=== PR image scan tests ==="
echo -n "  TEST: feature metadata survives workspace restore and supplies Docker scan tag... "
export BASH_ENV="${WORK}/build-env" CIRCLE_BRANCH=feature/image-scan
export GITVERSION_MAJOR=1 GITVERSION_MINOR=2 GITVERSION_PATCH=3
export GITVERSION_SHA=abcdef123456
bash "${SRC_SCRIPTS}/export_version_vars.sh" > "${WORK}/version.log"
bash "${SRC_SCRIPTS}/persist_version_metadata.sh" >> "${WORK}/version.log"
export BASH_ENV="${WORK}/scan-env"
bash "${SRC_SCRIPTS}/restore_version_metadata.sh" >> "${WORK}/version.log"
bash "${SRC_SCRIPTS}/docker_build.sh" >> "${WORK}/version.log"
# shellcheck disable=SC1090
source "${BASH_ENV}"
export IMAGE_TAG='ghcr.io/example/app:${DOCKER_TAG}'
if bash "${SRC_SCRIPTS}/run_trivy_image.sh" >> "${WORK}/version.log" &&
  grep -q 'trivy image .*--severity HIGH,CRITICAL --exit-code 1 ghcr.io/example/app:1.2.3-image-scan-abcdef123456-SNAPSHOT' "${CALL_LOG}"; then
  pass
else
  fail
fi

echo -n "  TEST: push=false builds and scans every supplemental without publishing... "
: > "${CALL_LOG}"
echo 'export DOCKER_ENV_TAG=develop' >> "${BASH_ENV}"
if PUSH_IMAGES=false bash "${SRC_SCRIPTS}/build_push_supplemental.sh" > "${WORK}/supplemental.log" &&
  [[ $(grep -c '^docker build ' "${CALL_LOG}") == 2 ]] &&
  [[ $(grep -c '^trivy image .*--severity HIGH,CRITICAL --exit-code 1 ' "${CALL_LOG}") == 2 ]] &&
  ! grep -Eq '^docker (push|login|tag|buildx) ' "${CALL_LOG}" &&
  [[ -s "${WORK}/migrations.json" && -s "${WORK}/worker.json" ]]; then
  pass
else
  fail
fi

echo -n "  TEST: default push still publishes version and environment tags... "
: > "${CALL_LOG}"
unset PUSH_IMAGES
if bash "${SRC_SCRIPTS}/build_push_supplemental.sh" > "${WORK}/supplemental.log" &&
  [[ $(grep -c '^docker push ' "${CALL_LOG}") == 4 ]]; then
  pass
else
  fail
fi

# Regression (0.3.5): CircleCI renders the boolean "push" parameter as "1"/"0" in
# the step environment, and release builds silently skipped the push.
for push in 1 true TRUE; do
  echo -n "  TEST: push=${push} (release builds) publishes every supplemental image... "
  : > "${CALL_LOG}"
  if PUSH_IMAGES="${push}" bash "${SRC_SCRIPTS}/build_push_supplemental.sh" > "${WORK}/supplemental.log" &&
    [[ $(grep -c '^docker push ' "${CALL_LOG}") == 4 ]] &&
    grep -q '^docker push ghcr.io/example/app-migrations:' "${CALL_LOG}" &&
    grep -q '^docker push ghcr.io/example/app-worker:' "${CALL_LOG}" &&
    grep -q 'push=true' "${WORK}/supplemental.log"; then
    pass
  else
    fail
  fi
done

for push in 0 false ""; do
  echo -n "  TEST: push='${push}' (PR scans) publishes nothing... "
  : > "${CALL_LOG}"
  if PUSH_IMAGES="${push}" bash "${SRC_SCRIPTS}/build_push_supplemental.sh" > "${WORK}/supplemental.log" &&
    ! grep -Eq '^docker (push|tag) ' "${CALL_LOG}"; then
    pass
  else
    fail
  fi
done

echo -n "  TEST: an unrecognised push value fails instead of guessing... "
: > "${CALL_LOG}"
if PUSH_IMAGES=maybe bash "${SRC_SCRIPTS}/build_push_supplemental.sh" > "${WORK}/supplemental.log" 2>&1; then
  fail
elif ! grep -Eq '^docker (build|tag|push) ' "${CALL_LOG}" && grep -q "must be true/false" "${WORK}/supplemental.log"; then
  pass
else
  fail
fi

for push in false true; do
  echo -n "  TEST: push=${push} fails on HIGH/CRITICAL findings before any push... "
  : > "${CALL_LOG}"
  rm -f "${WORK}/migrations.json"
  if SCAN_EXIT=1 PUSH_IMAGES="${push}" bash "${SRC_SCRIPTS}/build_push_supplemental.sh" > "${WORK}/supplemental.log" 2>&1; then
    fail
  elif ! grep -q '^docker push ' "${CALL_LOG}" && [[ -s "${WORK}/migrations.json" ]]; then
    pass
  else
    fail
  fi
done

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ ${FAIL} -eq 0 ]]
