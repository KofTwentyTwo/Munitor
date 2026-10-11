#!/usr/bin/env bash
# Tests for allocate_version.sh: atomic release version reservation via git tags.
#
# The GitHub refs API is replaced by a fake backed by a directory. Creating a
# ref uses a hard link from a fully-written temp file, which is atomic and fails
# if the target exists -- the same create-if-absent semantics GitHub provides
# for POST /git/refs (422 "Reference already exists").
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SCRIPT="${PROJECT_DIR}/src/scripts/allocate_version.sh"
PASS=0
FAIL=0

WORK=$(mktemp -d)
trap 'rm -rf "${WORK}"' EXIT

pass() { echo "PASS"; PASS=$((PASS + 1)); }
fail() { echo "FAIL${1:+ ($1)}"; FAIL=$((FAIL + 1)); }

# Fake GitHub API: gh_api METHOD PATH [BODY]; state lives in ${FAKE_GH_DIR}/tags/<tag>
FAKE_API="${WORK}/fake_gh_api.sh"
cat > "${FAKE_API}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
method="$1" path="$2" body="${3:-}"
dir="${FAKE_GH_DIR:?}/tags"
mkdir -p "${dir}"
if [[ -n "${FAKE_GH_FAIL:-}" ]]; then
  echo '{"message":"Server Error"}'
  exit 1
fi
case "${method} ${path}" in
  "POST git/refs")
    tag=$(echo "${body}" | jq -r '.ref' | sed 's#^refs/tags/##')
    sha=$(echo "${body}" | jq -r '.sha')
    # Widen the race window so concurrent allocators genuinely interleave.
    sleep "0.0$((RANDOM % 9))"
    tmp=$(mktemp "${dir}/.tmp.XXXXXX")
    echo "${sha}" > "${tmp}"
    if ln "${tmp}" "${dir}/${tag}" 2>/dev/null; then
      rm -f "${tmp}"
      echo "{\"ref\":\"refs/tags/${tag}\",\"object\":{\"type\":\"commit\",\"sha\":\"${sha}\"}}"
      exit 0
    fi
    rm -f "${tmp}"
    echo '{"message":"Reference already exists"}'
    exit 3
    ;;
  "GET git/ref/tags/"*)
    tag="${path#git/ref/tags/}"
    if [[ -f "${dir}/${tag}" ]]; then
      sha=$(cat "${dir}/${tag}")
      if [[ -f "${dir}/${tag}.annotated" ]]; then
        echo "{\"object\":{\"type\":\"tag\",\"sha\":\"tagobj-${sha}\"}}"
      else
        echo "{\"object\":{\"type\":\"commit\",\"sha\":\"${sha}\"}}"
      fi
      exit 0
    fi
    echo '{"message":"Not Found"}'
    exit 2
    ;;
  "GET git/tags/tagobj-"*)
    echo "{\"object\":{\"type\":\"commit\",\"sha\":\"${path#git/tags/tagobj-}\"}}"
    exit 0
    ;;
esac
echo "unexpected call: ${method} ${path}" >&2
exit 1
EOF
chmod +x "${FAKE_API}"

# run_alloc STATE_DIR SHA VERSION [BRANCH] -> prints allocated PROJECT_VERSION (from BASH_ENV) or "-"
run_alloc() {
  local state="$1" sha="$2" version="$3" branch="${4:-main}"
  local env_file
  env_file=$(mktemp "${WORK}/env.XXXXXX")
  FAKE_GH_DIR="${state}" MUNITOR_GH_API_CMD="${FAKE_API}" BASH_ENV="${env_file}" \
    PROJECT_VERSION="${version}" CIRCLE_BRANCH="${branch}" CIRCLE_SHA1="${sha}" \
    CIRCLE_PROJECT_USERNAME="KofTwentyTwo" CIRCLE_PROJECT_REPONAME="Example" \
    bash "${SCRIPT}" > "${env_file}.log" 2>&1 || { echo "ERR"; return 0; }
  local v
  v=$(grep "^export PROJECT_VERSION=" "${env_file}" | tail -1 | sed "s/^export PROJECT_VERSION='\(.*\)'$/\1/")
  echo "${v:--}"
}

echo "=== allocate_version.sh Tests ==="

echo -n "  TEST: reserves the computed version when free... "
S="${WORK}/s1"
got=$(run_alloc "${S}" sha-a 0.1.24)
if [[ "${got}" == "0.1.24" && "$(cat "${S}/tags/v0.1.24")" == "sha-a" ]]; then pass; else fail "got ${got}"; fi

echo -n "  TEST: rerun on the same commit reuses its version... "
got=$(run_alloc "${S}" sha-a 0.1.24)
if [[ "${got}" == "0.1.24" && "$(cat "${S}/tags/v0.1.24")" == "sha-a" ]]; then pass; else fail "got ${got}"; fi

echo -n "  TEST: collision with another commit takes the next patch (the PR #65/#66 case)... "
got=$(run_alloc "${S}" sha-b 0.1.24)
if [[ "${got}" == "0.1.25" && "$(cat "${S}/tags/v0.1.24")" == "sha-a" && "$(cat "${S}/tags/v0.1.25")" == "sha-b" ]]; then
  pass
else
  fail "got ${got}"
fi

echo -n "  TEST: existing tags are never moved... "
if [[ "$(cat "${S}/tags/v0.1.24")" == "sha-a" ]]; then pass; else fail "v0.1.24 moved"; fi

echo -n "  TEST: annotated tag on the same commit is recognized as a rerun... "
S2="${WORK}/s2"; mkdir -p "${S2}/tags"; echo sha-x > "${S2}/tags/v1.0.0"; touch "${S2}/tags/v1.0.0.annotated"
got=$(run_alloc "${S2}" sha-x 1.0.0)
if [[ "${got}" == "1.0.0" ]]; then pass; else fail "got ${got}"; fi

echo -n "  TEST: skips several already-taken versions... "
S3="${WORK}/s3"; mkdir -p "${S3}/tags"
for p in 5 6 7; do echo "other-${p}" > "${S3}/tags/v2.3.${p}"; done
got=$(run_alloc "${S3}" sha-y 2.3.5)
if [[ "${got}" == "2.3.8" ]]; then pass; else fail "got ${got}"; fi

echo -n "  TEST: non-main branches are not reserved... "
S4="${WORK}/s4"
got=$(run_alloc "${S4}" sha-z 0.2.0-SNAPSHOT.abc develop)
if [[ "${got}" == "-" && ! -e "${S4}/tags/v0.2.0-SNAPSHOT.abc" ]]; then pass; else fail "got ${got}"; fi

echo -n "  TEST: pre-release versions on main are not reserved... "
got=$(run_alloc "${S4}" sha-z 0.2.0-RC.1 main)
if [[ "${got}" == "-" ]]; then pass; else fail "got ${got}"; fi

echo -n "  TEST: API failure fails the build instead of guessing... "
S5="${WORK}/s5"
got=$(FAKE_GH_FAIL=1 run_alloc "${S5}" sha-q 0.1.0)
if [[ "${got}" == "ERR" ]]; then pass; else fail "got ${got}"; fi

echo -n "  TEST: missing GITHUB_TOKEN fails on main... "
rc=0
env -u GITHUB_TOKEN BASH_ENV=/dev/null PROJECT_VERSION=0.1.0 CIRCLE_BRANCH=main CIRCLE_SHA1=abc \
  CIRCLE_PROJECT_USERNAME=o CIRCLE_PROJECT_REPONAME=r bash "${SCRIPT}" >/dev/null 2>&1 || rc=$?
if [[ ${rc} -ne 0 ]]; then pass; else fail "expected failure"; fi

# Concurrent simulation: N pipelines for N different merge commits all computed
# the same version from GitVersion and race to reserve it.
N=8
echo -n "  TEST: ${N} concurrent pipelines get ${N} distinct, contiguous versions... "
SC="${WORK}/concurrent"; mkdir -p "${SC}/tags"
pids=()
for i in $(seq 1 "${N}"); do
  ( run_alloc "${SC}" "merge-${i}" 0.1.24 > "${WORK}/result.${i}" ) &
  pids+=($!)
done
for pid in "${pids[@]}"; do wait "${pid}"; done

results=$(for i in $(seq 1 "${N}"); do cat "${WORK}/result.${i}"; done | sort -t. -k3,3n)
expected=$(for p in $(seq 24 $((24 + N - 1))); do echo "0.1.${p}"; done)
ok=true
[[ "${results}" == "${expected}" ]] || ok=false
# Every tag maps to exactly the commit that claims that version.
for i in $(seq 1 "${N}"); do
  v=$(cat "${WORK}/result.${i}")
  [[ -f "${SC}/tags/v${v}" && "$(cat "${SC}/tags/v${v}")" == "merge-${i}" ]] || ok=false
done
if ${ok}; then pass; else fail "results: $(echo "${results}" | tr '\n' ' ')"; fi

echo -n "  TEST: concurrent reruns of the same commits keep their versions... "
pids=()
for i in $(seq 1 "${N}"); do
  ( run_alloc "${SC}" "merge-${i}" 0.1.24 > "${WORK}/rerun.${i}" ) &
  pids+=($!)
done
for pid in "${pids[@]}"; do wait "${pid}"; done
ok=true
for i in $(seq 1 "${N}"); do
  [[ "$(cat "${WORK}/rerun.${i}")" == "$(cat "${WORK}/result.${i}")" ]] || ok=false
done
tag_count=$(find "${SC}/tags" -name 'v*' | wc -l | tr -d ' ')
[[ "${tag_count}" == "${N}" ]] || ok=false
if ${ok}; then pass; else fail "reruns changed versions or created extra tags (${tag_count})"; fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ ${FAIL} -eq 0 ]]
