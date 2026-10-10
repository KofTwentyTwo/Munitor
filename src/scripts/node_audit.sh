#!/usr/bin/env bash
set -euo pipefail

# Source shared helpers
MUNITOR_HELPERS="${MUNITOR_HELPERS:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/munitor_helpers.sh}"
# shellcheck source=munitor_helpers.sh
if [[ -f "${MUNITOR_HELPERS}" ]]; then source "${MUNITOR_HELPERS}"
elif ! type munitor_header &>/dev/null; then
  munitor_header() { echo "=== Munitor: ${1:-unknown} ==="; }
  munitor_check_tool() { command -v "$1" &>/dev/null || { echo "ERROR: $1 not found"; exit 1; }; }
  munitor_download_with_retry() { curl -fsSL --retry 3 "$1" -o "$2"; }
fi

munitor_header "node_audit"

echo "Running npm audit..."

if [[ -f .npm-audit-exceptions.json ]]; then
  # The optional, repository-reviewed exception file never changes runtime policy.
  REPORT_DIR=$(mktemp -d)
  trap 'rm -rf "${REPORT_DIR}"' EXIT
  export REPORT_DIR
  npm audit --json --audit-level=high > "${REPORT_DIR}/full.json" || AUDIT_STATUS=$?
  npm audit --json --omit=dev --audit-level=high > "${REPORT_DIR}/production.json" || PRODUCTION_STATUS=$?
  export AUDIT_STATUS="${AUDIT_STATUS:-0}" PRODUCTION_STATUS="${PRODUCTION_STATUS:-0}"
  node <<'AUDIT_JS'
const fs = require('node:fs');
const { execFileSync } = require('node:child_process');
function fail(message) { throw new Error(message); }
function readReport(name, status) {
  const report = JSON.parse(fs.readFileSync(`${process.env.REPORT_DIR}/${name}.json`, 'utf8'));
  if (report.error || report.auditReportVersion !== 2 || !report.vulnerabilities || !report.metadata?.vulnerabilities)
    fail(`${name}: npm audit returned an error or unsupported report`);
  if (![0, 1].includes(Number(status))) fail(`${name}: npm audit failed (${status})`);
  const counts = report.metadata.vulnerabilities;
  if (Object.values(report.vulnerabilities).some(v => !v || !['info', 'low', 'moderate', 'high', 'critical'].includes(v.severity)))
    fail(`${name}: invalid vulnerability severity`);
  for (const severity of ['info', 'low', 'moderate', 'high', 'critical']) {
    if (!Number.isInteger(counts[severity]) || counts[severity] < 0) fail(`${name}: invalid severity counts`);
    if (Object.values(report.vulnerabilities).filter(v => v.severity === severity).length !== counts[severity])
      fail(`${name}: inconsistent severity counts`);
  }
  return report;
}
try {
  const full = readReport('full', process.env.AUDIT_STATUS);
  const production = readReport('production', process.env.PRODUCTION_STATUS);
  if (production.metadata.vulnerabilities.high || production.metadata.vulnerabilities.critical)
    fail('Production dependencies contain high/critical vulnerabilities; exceptions do not apply');
  if (full.metadata.vulnerabilities.critical) fail('Critical vulnerabilities cannot be excepted');
  const config = JSON.parse(fs.readFileSync('.npm-audit-exceptions.json', 'utf8'));
  if (config.schemaVersion !== 1 || !Array.isArray(config.exceptions) || !config.exceptions.length)
    fail('Invalid exception configuration');
  const today = new Date().toISOString().slice(0, 10);
  const lock = JSON.parse(fs.readFileSync('package-lock.json', 'utf8'));
  if (!lock.packages) fail('Exceptions require a package-lock.json with package paths');
  const allowed = new Map();
  for (const entry of config.exceptions) {
    if (!/^EX-\d{4}$/.test(entry.id) || !/^GHSA-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}$/.test(entry.advisory)
        || entry.scope !== 'development' || !/^\d{4}-\d{2}-\d{2}$/.test(entry.expires)
        || !Number.isFinite(Date.parse(entry.expires))
        || new Date(entry.expires).toISOString().slice(0, 10) !== entry.expires || today >= entry.expires
        || typeof entry.package !== 'string' || !/^(@[a-z0-9._-]+\/)?[a-z0-9._-]+$/.test(entry.package)
        || !/^\d+\.\d+\.\d+$/.test(entry.version) || allowed.has(entry.advisory))
      fail('Invalid, duplicated or expired development exception');
    allowed.set(entry.advisory, entry);
  }
  function roots(name, seen = new Set()) {
    if (seen.has(name)) fail(`Cyclic vulnerability chain: ${name}`);
    const vulnerability = full.vulnerabilities[name];
    if (!vulnerability || !Array.isArray(vulnerability.via) || !vulnerability.via.length)
      fail(`Unresolved vulnerability chain: ${name}`);
    const next = new Set([...seen, name]);
    return vulnerability.via.flatMap(via => {
      if (typeof via === 'string') return roots(via, next);
      if (!via || typeof via.url !== 'string' || typeof via.severity !== 'string')
        fail(`Invalid advisory: ${name}`);
      return [{ advisory: via, vulnerability }];
    });
  }
  const used = new Set();
  for (const [name, vulnerability] of Object.entries(full.vulnerabilities)) {
    if (vulnerability.severity !== 'high') continue;
    for (const { advisory, vulnerability: root } of roots(name)) {
      if (!['high', 'critical'].includes(advisory.severity)) continue;
      const id = advisory.url.replace('https://github.com/advisories/', '');
      const exception = allowed.get(id);
      if (!exception || advisory.url !== `https://github.com/advisories/${id}`
          || advisory.severity !== 'high' || advisory.name !== exception.package
          || root.name !== exception.package || !Array.isArray(root.nodes) || !root.nodes.length)
        fail(`Unexcepted high vulnerability: ${name} (${advisory.url})`);
      for (const path of root.nodes) {
        if (!lock.packages[path] || lock.packages[path].dev !== true || lock.packages[path].version !== exception.version)
          fail(`Exception does not cover package path or version: ${path}`);
      }
      used.add(id);
    }
    if (!roots(name).some(r => ['high', 'critical'].includes(r.advisory.severity)))
      fail(`High vulnerability has no resolvable high advisory: ${name}`);
  }
  for (const id of used) {
    const entry = allowed.get(id);
    // Any newer release requires reassessment, even if npm proposes a parent downgrade.
    const latest = execFileSync('npm', ['view', entry.package, 'version', '--json'],
      { encoding: 'utf8', timeout: 30000 });
    if (JSON.parse(latest) !== entry.version) fail(`New ${entry.package} release available; reassess ${entry.id}`);
    console.log(`Accepted ${entry.id}: ${id}, development only, expires ${entry.expires}`);
  }
  console.log('Full audit checked; production audit has no high/critical findings.');
} catch (error) {
  console.error(`npm audit rejected: ${error.message}`);
  process.exit(1);
}
AUDIT_JS
  exit 0
fi

npm audit --audit-level=high || {
  EXIT_CODE=$?
  echo "npm audit found high/critical vulnerabilities."
  exit "${EXIT_CODE}"
}

echo "npm audit passed."
