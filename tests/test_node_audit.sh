#!/usr/bin/env bash
set -euo pipefail
bats "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/node_audit.bats"
