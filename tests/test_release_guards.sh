#!/usr/bin/env bash
# Tests for the release guards: immutable image tags and conditional cd_path emission.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SRC_SCRIPTS="${PROJECT_DIR}/src/scripts"
PASS=0
FAIL=0

WORK=$(mktemp -d)
trap 'rm -rf "${WORK}"' EXIT

pass() { echo "PASS"; PASS=$((PASS + 1)); }
fail() { echo "FAIL${1:+ ($1)}"; FAIL=$((FAIL + 1)); }

# Fake docker: `docker buildx imagetools inspect REF --format ...` reads
# ${FAKE_REGISTRY}/<ref with / and : replaced by _> holding the revision label.
mkdir -p "${WORK}/bin"
cat > "${WORK}/bin/docker" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "--version" ]]; then echo "Docker version 99"; exit 0; fi
if [[ "$1 $2 $3" == "buildx imagetools inspect" ]]; then
  ref="$4"
  if [[ -n "${FAKE_REGISTRY_ERROR:-}" ]]; then echo "unauthorized: authentication required" >&2; exit 1; fi
  key=$(echo "${ref}" | tr '/:' '__')
  f="${FAKE_REGISTRY}/${key}"
  if [[ ! -f "${f}" ]]; then echo "ERROR: ${ref}: not found" >&2; exit 1; fi
  rev=$(cat "${f}")
  if [[ -z "${rev}" ]]; then echo '{"config":{"Labels":{}}}'; exit 0; fi
  echo "{\"architecture\":\"amd64\",\"config\":{\"Labels\":{\"org.opencontainers.image.revision\":\"${rev}\"}}}"
  exit 0
fi
echo "unexpected docker call: $*" >&2
exit 1
EOF
chmod +x "${WORK}/bin/docker"

put_image() { mkdir -p "${FAKE_REGISTRY}"; echo "$2" > "${FAKE_REGISTRY}/$(echo "$1" | tr '/:' '__')"; }

run_guard() {
  PATH="${WORK}/bin:${PATH}" MUNITOR_SKIP_REGISTRY_LOGIN=1 FAKE_REGISTRY="${FAKE_REGISTRY}" \
    IMAGE_NAME=website-backend REGISTRY=ghcr.io/koftwentytwo PROJECT_VERSION="$1" CIRCLE_SHA1="$2" \
    SUPPLEMENTAL_IMAGES_JSON="${3:-[]}" bash "${SRC_SCRIPTS}/guard_image_tags.sh" >"${WORK}/guard.log" 2>&1
}

echo "=== guard_image_tags.sh Tests ==="
SUPP='[{"name":"migrations","dockerfile":"docker/Dockerfile.migrations"}]'

FAKE_REGISTRY="${WORK}/reg1"
echo -n "  TEST: passes when the version tag does not exist... "
if run_guard 0.1.32 sha-new "${SUPP}"; then pass; else fail "$(cat "${WORK}/guard.log")"; fi

echo -n "  TEST: passes on rerun when the tag was built from the same commit... "
put_image ghcr.io/koftwentytwo/website-backend:0.1.32 sha-new
put_image ghcr.io/koftwentytwo/website-backend-migrations:0.1.32 sha-new
if run_guard 0.1.32 sha-new "${SUPP}"; then pass; else fail "$(cat "${WORK}/guard.log")"; fi

echo -n "  TEST: refuses to overwrite a version tag built from another commit (0.1.24 incident)... "
if run_guard 0.1.32 sha-other "${SUPP}"; then fail "guard allowed overwrite"; else pass; fi

echo -n "  TEST: refuses when only a supplemental image collides... "
FAKE_REGISTRY="${WORK}/reg2"
put_image ghcr.io/koftwentytwo/website-backend-migrations:0.2.0 sha-old
if run_guard 0.2.0 sha-new "${SUPP}"; then fail "guard allowed supplemental overwrite"; else pass; fi

echo -n "  TEST: refuses when an existing tag has no provenance label... "
FAKE_REGISTRY="${WORK}/reg3"
put_image ghcr.io/koftwentytwo/website-backend:0.3.0 ""
if run_guard 0.3.0 sha-new; then fail "unlabeled image overwritten"; else pass; fi

echo -n "  TEST: registry errors fail closed... "
if FAKE_REGISTRY_ERROR=1 run_guard 0.4.0 sha-new; then fail "error treated as free"; else pass; fi

echo -n "  TEST: docker_build labels images with the commit revision... "
if grep -q 'org.opencontainers.image.revision=${CIRCLE_SHA1}' "${SRC_SCRIPTS}/docker_build.sh" &&
   grep -q 'org.opencontainers.image.revision=${CIRCLE_SHA1}' "${SRC_SCRIPTS}/build_push_supplemental.sh"; then
  pass
else
  fail "revision label missing"
fi

echo -n "  TEST: docker_build_push guards tags before building and pushing... "
JOB="${PROJECT_DIR}/src/jobs/docker_build_push.yml"
g=$(grep -n 'guard_image_tags' "${JOB}" | head -1 | cut -d: -f1)
p=$(grep -n 'docker_push_ghcr' "${JOB}" | head -1 | cut -d: -f1)
if [[ -n "${g}" && -n "${p}" && ${g} -lt ${p} ]]; then pass; else fail "guard not before push"; fi

echo -n "  TEST: build jobs reserve the version before persisting it... "
ok=true
for j in mvn gradle node; do
  f="${PROJECT_DIR}/src/jobs/${j}_build_and_test.yml"
  a=$(grep -n 'allocate_version' "${f}" | head -1 | cut -d: -f1)
  e=$(grep -n 'export_version_vars' "${f}" | head -1 | cut -d: -f1)
  m=$(grep -n 'persist_version_metadata' "${f}" | head -1 | cut -d: -f1)
  [[ -n "${a}" && ${a} -gt ${e} && ${a} -lt ${m} ]] || ok=false
done
if ${ok}; then pass; else fail "allocate_version misplaced"; fi

echo -n "  TEST: github_release targets the built commit, not the branch head... "
if grep -q 'TARGET="${CIRCLE_SHA1:-main}"' "${SRC_SCRIPTS}/github_release.sh" &&
   grep -q 'Refusing to release' "${SRC_SCRIPTS}/github_release.sh"; then
  pass
else
  fail
fi

echo -n "  TEST: update_cd_repo verifies the release tag belongs to this commit... "
if grep -q 'Refusing to bump the GitOps repo' "${SRC_SCRIPTS}/update_cd_repo.sh"; then pass; else fail; fi

echo ""
echo "=== cd_path emission (orb version compatibility) ==="

render() {
  local fixture="$1" out="$2"
  MUNITOR_CONFIG="${fixture}" MUNITOR_OUTPUT_FILE="${out}" \
    bash "${SRC_SCRIPTS}/generate_config.sh" >/dev/null 2>&1 || true
}

echo -n "  TEST: manifest without cd.path emits no cd_path (older orbs reject it)... "
render "${SCRIPT_DIR}/fixtures/java-webapp.munitor.yml" "${WORK}/java.yml"
if [[ -s "${WORK}/java.yml" ]] && grep -q 'munitor/update_cd_repo' "${WORK}/java.yml" && ! grep -q 'cd_path' "${WORK}/java.yml"; then
  pass
else
  fail "cd_path present or render failed"
fi

echo -n "  TEST: manifest with cd.path still emits cd_path... "
render "${SCRIPT_DIR}/fixtures/node-webapp-consolidated.munitor.yml" "${WORK}/node.yml"
if grep -q 'cd_path: tenants/investinginchester/website/kustomization.yaml' "${WORK}/node.yml"; then pass; else fail; fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ ${FAIL} -eq 0 ]]
