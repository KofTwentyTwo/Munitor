const fs = require('node:fs');
const [directory, scenario = 'allowed'] = process.argv.slice(2);
const advisory = {
  name: 'braces', severity: 'high', url: 'https://github.com/advisories/GHSA-vfj7-8cjw-p6xm'
};
const root = { name: 'braces', severity: 'high', via: [advisory], nodes: ['node_modules/braces'] };
const full = { auditReportVersion: 2, vulnerabilities: {
  braces: root, parent: { name: 'parent', severity: 'high', via: ['braces'] }
}, metadata: { vulnerabilities: { info: 0, low: 0, moderate: 0, high: 2, critical: 0 } } };
const production = { auditReportVersion: 2, vulnerabilities: {},
  metadata: { vulnerabilities: { info: 0, low: 0, moderate: 0, high: 0, critical: 0 } } };
const exception = { id: 'EX-0008', advisory: 'GHSA-vfj7-8cjw-p6xm', package: 'braces',
  version: '3.0.3', scope: 'development', expires: '2099-01-01' };
const lock = { lockfileVersion: 3, packages: { 'node_modules/braces': { version: '3.0.3', dev: true } } };
if (scenario === 'expired') exception.expires = '2020-01-01';
if (scenario === 'invalid-date') exception.expires = '2099-02-30';
if (scenario === 'different') advisory.url = 'https://github.com/advisories/GHSA-aaaa-bbbb-cccc';
if (scenario === 'mixed') root.via.push({ ...advisory, url: 'https://github.com/advisories/GHSA-aaaa-bbbb-cccc' });
if (scenario === 'critical') { root.severity = advisory.severity = 'critical'; full.metadata.vulnerabilities.high--; full.metadata.vulnerabilities.critical++; }
if (scenario === 'production') { production.vulnerabilities.braces = root; production.metadata.vulnerabilities.high = 1; }
if (scenario === 'runtime-path') lock.packages['node_modules/braces'].dev = false;
if (scenario === 'different-version') lock.packages['node_modules/braces'].version = '3.0.2';
if (scenario === 'unknown-chain') full.vulnerabilities.parent.via = ['missing'];
if (scenario === 'cycle') root.via = ['parent'];
if (scenario === 'counts') full.metadata.vulnerabilities.high = 0;
if (scenario === 'registry-error') full.error = { code: 'ENETUNREACH' };
fs.mkdirSync(directory, { recursive: true });
for (const [name, data] of Object.entries({ 'full.json': full, 'production.json': production,
  '.npm-audit-exceptions.json': { schemaVersion: 1, exceptions: [exception] }, 'package-lock.json': lock })) {
  fs.writeFileSync(`${directory}/${name}`, JSON.stringify(data));
}
