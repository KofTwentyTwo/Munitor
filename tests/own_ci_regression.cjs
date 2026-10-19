// Public CI config only: no network, credentials or publication.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const config = JSON.parse(fs.readFileSync(0, 'utf8'));
const workflows = Object.values(config.workflows);
assert.equal(workflows.length, 1, 'all publishers must share the checked pack workspace');
const jobs = workflows.flatMap(workflow => workflow.jobs).map(job => {
  const [type, settings] = Object.entries(job)[0];
  return { type, ...settings, name: settings.name || type };
});
assert.equal(jobs.filter(job => job.type === 'orb-tools/pack').length, 1, 'pack once per pipeline');
const gates = ['orb-tools/lint', 'orb-tools/pack', 'orb-tools/review', 'test'];
for (const gate of gates) assert.equal(jobs.filter(job => job.name === gate).length, 1, `retain required context ${gate}`);
const publishers = jobs.filter(job => job.type === 'orb-tools/publish');
assert.equal(publishers.length, 3);
for (const job of publishers) {
  assert.deepEqual([...job.requires].sort(), [...gates].sort(), `${job.name} must wait for every gate`);
  assert.equal(job.orb_name, 'kof22/munitor');
  assert.deepEqual(job.context, ['orb-publishing']);
}
function matches(pattern, value) {
  return pattern.startsWith('/') && pattern.endsWith('/')
    ? new RegExp(`^(?:${pattern.slice(1, -1)})$`).test(value) : pattern === value;
}
function runs(job, kind, ref) {
  const filter = job.filters?.[kind];
  if (!filter) return kind === 'branches'; // CircleCI ignores tags unless opted in.
  const list = value => Array.isArray(value) ? value : [value];
  return (!filter.only || list(filter.only).some(pattern => matches(pattern, ref)))
    && (!filter.ignore || !list(filter.ignore).some(pattern => matches(pattern, ref)));
}
const cases = [
  ['branches', 'develop', ['publish-develop-snapshot']],
  ['branches', 'feature/ci-speed', ['publish-feature-sha']],
  ['branches', 'main', []], ['branches', 'hotfix/1.2.3', []],
  ['branches', 'release/1.2.3', []], ['branches', 'fix/ci-speed', []],
  ['tags', 'v1.2.3', ['orb-tools/publish']],
  ['tags', 'v1.2.3-RC.1', []], ['tags', 'v1.2', []], ['tags', 'other', []],
];
for (const [kind, ref, expected] of cases) {
  assert.deepEqual(publishers.filter(job => runs(job, kind, ref)).map(job => job.name).sort(), expected.sort(), `${kind}:${ref}`);
  for (const gate of gates) assert.ok(runs(jobs.find(job => job.name === gate), kind, ref), `${gate} must run for ${ref}`);
}
assert.equal(jobs.find(job => job.name === 'publish-develop-snapshot').dev_tags, 'dev:${CIRCLE_SHA1},dev:snapshot');
assert.equal(jobs.find(job => job.name === 'publish-feature-sha').dev_tags, 'dev:${CIRCLE_SHA1}');
assert.equal(jobs.find(job => job.name === 'orb-tools/publish').pub_type, 'production');
assert.equal(jobs.find(job => job.name === 'publish-feature-sha').pub_type, 'dev');
assert.equal(jobs.find(job => job.name === 'publish-develop-snapshot').pub_type, 'dev');
console.log('PASS: one pack, unchanged required contexts, all publish gates and 10 branch/tag cases');
