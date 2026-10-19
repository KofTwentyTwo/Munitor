# Fast Java CI

Backend ticket work is paused while this performance change is delivered.

## Measured baseline

Website-Backend PR311, CircleCI jobs6314–6318 on2026-10-19:

- Build/test job:30m15s. Compilation49s; tests14m24s; Java installation4m27s.
- Maven cache48GiB: restore5m32s, save4m19s.
- Quality, coverage and security each restore the same48GiB again (5–6min).
- Coverage computation itself takes5.4s. Quality tools take57s combined.
- OWASP is disabled in this consumer, but security still installs Java and restores Maven.
- Test results are uploaded by both the test command and its enclosing job:777 results appear twice.

Evidence: coordinator cache/cicd-baseline.json, cicd-test-timings.json and cicd-github-friction.md.

## First implementation

1. Replace the old broad Maven fallback with an exact v2 key based on checked-out dependency definitions. Keep that key stable across release-version rewrites and invalidate for nested POM or Maven configuration changes. Never restore the48GiB v1 cache.
2. Skip Java/Maven/NVD setup when OWASP is disabled; preserve Trivy.
3. Upload Maven test results once.
4. Pack the orb once per pipeline; publish only after its existing checks pass, preserving branch/tag behavior and required check names.
5. Run template tests only in their dedicated Make target, rather than also discovering them in the generic script loop.
6. Run Checkstyle, SpotBugs, PMD and coverage on the existing build worker for generated PR/develop/staging/release workflows. Keep the standalone jobs available for custom consumers and preserve production behavior. Generated downstream jobs depend on the completed build gate.
7. Render each immutable test fixture once per test run; retain all277 assertions.

Maven caches are dependency reuse, not artifact handoff. A real three-module experiment failed SpotBugs with current target outputs and an older installed-module cache. Preserve locally installed version directories and ancestor metadata in a workspace archive, then overlay it after dependency-cache restore. The experiment passes for release versions, snapshots and classifier dependencies. Maven Resolver identifies local installs with empty repository IDs in `_remote.repositories`; this implementation depends on that Maven3 format. Do not replace this archive with the entire local repository.

Cold dependency downloads on changed POMs are deliberate: no cross-version fallback accumulation. Do not delete caches, artifacts, tags or change branch protections.

## Verification and rollout

- Focused behavioral/config regressions, then required make all and BATS suites once the combined patch is complete.
- Publish immutable feature orb; run a backend feature canary with both pins matching that SHA.
- Compare real cache size and build/check durations against the baseline. No claimed speedup before measurement; do not merge the consumer until tests and all existing security gates pass.
- Release the proven orb and adopt its stable version through normal PRs. Track the already-running backend release separately; do not resume paused ticket work.

## Follow-up decisions after measurement

If tests dominate after cache repair, inspect measured slow fixtures and isolate/parallelize only tests proven independent. Exact-source artifact promotion is a separate future change requiring verified source identity; do not skip merged-source validation on the strength of an earlier PR run. Avoid a new orchestration framework or speculative configuration options.
