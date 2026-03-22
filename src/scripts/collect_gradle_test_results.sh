#!/usr/bin/env bash
set -euo pipefail

# Collect Gradle multi-module JUnit XML test results into a single directory
# for CircleCI's store_test_results step.

DEST="/tmp/test-results"
mkdir -p "${DEST}"

find . -path "*/build/test-results/test/*.xml" -exec cp {} "${DEST}/" \;

COUNT=$(find "${DEST}" -name "*.xml" 2>/dev/null | wc -l | tr -d ' ')
echo "Collected ${COUNT} test result file(s) to ${DEST}/"
