#!/usr/bin/env bash
# Verify deployment health configuration reaches source and shipped generators.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK=$(mktemp -d)
trap 'rm -rf -- "$WORK"' EXIT
export CIRCLE_BRANCH=develop CIRCLE_TAG=""
cp "${SCRIPT_DIR}/fixtures/java-webapp.munitor.yml" "${WORK}/defaults.yml"
cp "${WORK}/defaults.yml" "${WORK}/configured.yml"
cat >>"${WORK}/configured.yml" <<'YAML'
health:
  path: /health/ready
  port: 8181
  db: "true"
  migrations: migrations
  smoke_paths:
    - /api/templates
    - /api/version
YAML

# Packed helpers share /tmp/munitor; run these generators sequentially.
for generator in generate_config.sh packed_generate_config.sh; do
  for mode in configured defaults; do
    MUNITOR_CONFIG="${WORK}/${mode}.yml" MUNITOR_OUTPUT_FILE="${WORK}/generated.yml" \
      bash "${SCRIPT_DIR}/../src/scripts/${generator}" >"${WORK}/generator.log" 2>&1 || {
        cat "${WORK}/generator.log"
        exit 1
      }
    yq -o=json '.' "${WORK}/generated.yml" >"${WORK}/generated.json"
    python3 - "${WORK}/generated.json" "$mode" <<'PY'
import json
import sys

with open(sys.argv[1], encoding='utf-8') as source:
    workflows = json.load(source)['workflows']
expected = {'health_migrations': '', 'health_smoke_paths': ''}
if sys.argv[2] == 'configured':
    expected = {
        'health_path': '/health/ready',
        'health_port': '8181',
        'health_db': 'true',
        'health_migrations': 'migrations',
        'health_smoke_paths': '/api/templates,/api/version',
    }
for workflow in ('develop', 'staging', 'production', 'release-candidate'):
    jobs = [job['munitor/docker_build_push'] for job in workflows[workflow]['jobs']
            if isinstance(job, dict) and 'munitor/docker_build_push' in job]
    assert len(jobs) == 1, (workflow, 'expected one Docker build job', jobs)
    for parameter, value in expected.items():
        assert jobs[0].get(parameter) == value, (workflow, parameter, jobs[0].get(parameter), value)
PY
    printf 'PASS: %s %s deployment health parameters\n' "$generator" "$mode"
  done
done
