#!/usr/bin/env bash
# Protect required CI contexts and publication gates when consolidating workflows.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
yq -o=json '.' "${SCRIPT_DIR}/../.circleci/config.yml" | node "${SCRIPT_DIR}/own_ci_regression.cjs"
