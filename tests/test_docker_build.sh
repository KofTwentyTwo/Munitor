#!/usr/bin/env bash
# Assert the actual shared PR/release build command without a Docker daemon.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORK=$(mktemp -d)
trap 'rm -rf "${WORK}"' EXIT
mkdir -p "${WORK}/bin" "${WORK}/repo"
cat > "${WORK}/bin/docker" <<'MOCK'
#!/usr/bin/env bash
[[ "$1" == --version ]] && exit 0
printf '%s\n' "$@" > "${CALL_LOG}"
MOCK
cat > "${WORK}/bin/yq" <<'MOCK'
#!/usr/bin/env bash
[[ "$1" == --version ]] && exit 0
[[ "$1" == -r && "$2" == .pipeline ]] || exit 2
sed -n 's/^pipeline: //p' "$3"
MOCK
chmod +x "${WORK}/bin/docker" "${WORK}/bin/yq"
export PATH="${WORK}/bin:${PATH}"
export CALL_LOG="${WORK}/calls" BASH_ENV="${WORK}/env"
export IMAGE_NAME=app REGISTRY=ghcr.io/example PROJECT_VERSION=1.2.3
export CIRCLE_SHA1=abc123 DOCKER_ENV_TAG=develop
cd "${WORK}/repo"
for pipeline in java-webapp gradle-webapp node-api node-webapp; do
  printf 'pipeline: %s\n' "${pipeline}" > .munitor.yml
  bash "${PROJECT_DIR}/src/scripts/docker_build.sh" > "${WORK}/output"
  grep -qx -- '--pull' "${CALL_LOG}"
  if [[ "${pipeline}" == java-webapp || "${pipeline}" == gradle-webapp ]]; then
    grep -qx -- '--no-cache' "${CALL_LOG}"
  else
    ! grep -qx -- '--no-cache' "${CALL_LOG}"
  fi
  grep -qx 'org.opencontainers.image.revision=abc123' "${CALL_LOG}"
  grep -qx 'ghcr.io/example/app:1.2.3' "${CALL_LOG}"
  grep -qx 'ghcr.io/example/app:develop' "${CALL_LOG}"
  echo "PASS: ${pipeline} cache policy, provenance and tags"
done
mv .munitor.yml 'custom config.yml'
printf 'pipeline: java-webapp\n' > 'custom config.yml'
MUNITOR_CONFIG='custom config.yml' bash "${PROJECT_DIR}/src/scripts/docker_build.sh" > "${WORK}/output"
grep -qx -- '--no-cache' "${CALL_LOG}"
echo 'PASS: alternate manifest path'
bash "${PROJECT_DIR}/src/scripts/docker_build.sh" > "${WORK}/output"
grep -qx -- '--pull' "${CALL_LOG}"
! grep -qx -- '--no-cache' "${CALL_LOG}"
echo 'PASS: standalone build without manifest'
for job in docker_scan docker_build_push; do
  grep -q '^  - docker_build:' "${PROJECT_DIR}/src/jobs/${job}.yml"
  grep -q '^  - run_trivy_image:' "${PROJECT_DIR}/src/jobs/${job}.yml"
  echo "PASS: ${job} uses shared builder and retains Trivy"
done
