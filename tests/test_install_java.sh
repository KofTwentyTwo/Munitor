#!/usr/bin/env bash
set -euo pipefail
bats "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/install_java.bats"
