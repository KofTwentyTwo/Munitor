#!/usr/bin/env bash
# Exercise the real generator and validate its complete dependency graph.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATOR="${SCRIPT_DIR}/../src/scripts/generate_config.sh"
WORK=$(mktemp -d)
trap 'rm -rf -- "$WORK"' EXIT
export CIRCLE_BRANCH=main CIRCLE_TAG=""
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME=Fixture GIT_AUTHOR_EMAIL=fixture@example.invalid
export GIT_COMMITTER_NAME=Fixture GIT_COMMITTER_EMAIL=fixture@example.invalid
PASS=0

render_check() {
  local config="$1" mode="$2" label="$3" generator="${4:-$GENERATOR}"
  MUNITOR_CONFIG="$config" MUNITOR_OUTPUT_FILE="${WORK}/generated.yml" \
    bash "$generator" >"${WORK}/generator.log" 2>&1 || { cat "${WORK}/generator.log"; return 1; }
  yq -o=json '.' "${WORK}/generated.yml" >"${WORK}/generated.json"
  python3 - "${WORK}/generated.json" "$mode" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding='utf-8'))
workflows = data['workflows']
assert workflows, 'no generated workflows'
if sys.argv[2] == 'docs':
    assert set(workflows) == {'docs-checks'}, workflows.keys()
else:
    assert {'pr-checks', 'production', 'release-candidate'} <= set(workflows), workflows.keys()
    assert 'docs-checks' not in workflows
for workflow, body in workflows.items():
    jobs = {}
    filters = {}
    for invocation in body['jobs']:
        if isinstance(invocation, str):
            command, options = invocation, {}
        else:
            assert len(invocation) == 1
            command, options = next(iter(invocation.items()))
            options = options or {}
        name = options.get('name', command)
        assert name not in jobs, (workflow, 'duplicate job', name)
        jobs[name] = (command, options.get('requires', []))
        filters[name] = options.get('filters', {})
    assert 'ci-ready' in jobs, (workflow, 'missing ci-ready')
    assert jobs['ci-ready'][0] == 'munitor/ci_ready'
    for name, job_filters in filters.items():
        assert job_filters == filters['ci-ready'], (workflow, name, 'filters differ from ci-ready', job_filters, filters['ci-ready'])
    for name, (_, dependencies) in jobs.items():
        assert isinstance(dependencies, list)
        assert set(dependencies) <= jobs.keys(), (workflow, name, 'dangling dependency', dependencies)
    def closure(name, ancestors):
        assert name not in ancestors, (workflow, 'dependency cycle', name)
        reached = set()
        for dependency in jobs[name][1]:
            reached.add(dependency)
            reached.update(closure(dependency, ancestors | {name}))
        return reached
    assert closure('ci-ready', set()) == set(jobs) - {'ci-ready'}, (workflow, 'ungated job')
    if sys.argv[2] == 'docs':
        assert set(jobs) == {'secrets-scan', 'ci-ready'}
        assert jobs['secrets-scan'][0] == 'munitor/secrets_scan'
    else:
        assert any(command == 'munitor/mvn_build_and_test' for command, _ in jobs.values()), workflow
print('validated', len(workflows), 'workflow graphs')
PY
  printf 'PASS: %s\n' "$label"
  PASS=$((PASS + 1))
}

render_check "${SCRIPT_DIR}/fixtures/java-webapp.munitor.yml" full 'full Java fixture gates every job'
render_check "${SCRIPT_DIR}/fixtures/java-webapp-minimal.munitor.yml" full 'minimal Java fixture has no dangling optional dependencies'
# Disable all optional publication/scanner additions as well as e2e/SBOM.
cat >"${WORK}/minimal.yml" <<'YAML'
pipeline: java-webapp
orb_version: dev:snapshot
image_name: fixture
java_version: "21"
docker:
  registry: ghcr.io/example
e2e: false
sbom: false
owasp: false
sast: false
YAML
render_check "${WORK}/minimal.yml" full 'optional jobs absent without dangling gates'

git init -q -b main "${WORK}/repo"
cd "${WORK}/repo"
cp "${WORK}/minimal.yml" .munitor.yml
printf '\nci:\n  docs_only: true\n' >> .munitor.yml
printf 'original\n' > README.md
mkdir src
printf 'original\n' > src/App.java
git add .
git -c commit.gpgsign=false commit -qm baseline
printf 'documentation\n' >> README.md
git add README.md
git -c commit.gpgsign=false commit -qm documentation
render_check "$PWD/.munitor.yml" docs 'opted-in main README-only change retains only secrets and ci-ready'
# The shipped script stages /tmp/munitor helpers; invoke sequentially, never in parallel.
render_check "$PWD/.munitor.yml" docs 'packed generator retains docs-only secrets and ci-ready' \
  "${SCRIPT_DIR}/../src/scripts/packed_generate_config.sh"

# Opt-out must retain the full workflow even with the same docs-only Git diff.
yq '.ci.docs_only = false' .munitor.yml >"${WORK}/optout.yml"
render_check "${WORK}/optout.yml" full 'docs change with opt-out still builds'
printf 'source change\n' >> src/App.java
git add src/App.java
git -c commit.gpgsign=false commit -qm source
render_check "$PWD/.munitor.yml" full 'source change still builds'
printf '\n# configuration change\n' >> .munitor.yml
git add .munitor.yml
git -c commit.gpgsign=false commit -qm configuration
render_check "$PWD/.munitor.yml" full 'configuration change still builds'
printf '%s ci-ready generator checks passed\n' "$PASS"
