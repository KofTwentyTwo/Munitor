# Munitor Session State

## Last Updated
2026-03-27

## Current Status
Feature branch `feature/GH-5-pnpm-support` is at `7519d62`, pushed to origin. 17 commits ahead of `develop`. Dev snapshot published: `kof22/munitor@dev:snapshot`. All 219 tests pass. Ready for PR to develop when consumer repo validation confirms the fixes work.

## Branch
- `feature/GH-5-pnpm-support` at `7519d62` (pushed, 17 commits ahead of develop)
- `develop` at `af15015`
- `main` at `1e558c1` (2 commits ahead of develop)

## Tags / Releases
- `v0.1.0` at `9247dcc` - Initial stable release (7 pipeline types, 362+ tests)
- `v0.1.1` at `5f70823` - Supplemental images, health check, Trivy bump (505+ tests)
- `v0.1.2` at `d766747` - Overridable org defaults (PR #1)
- `v0.2.0` at `af15015` - Gradle-webapp pipeline type (PR #2), marked as Latest

All four have GitHub Releases.

## Key Facts
- GitHub org: KofTwentyTwo (repo: KofTwentyTwo/Munitor)
- CircleCI namespace: kof22 (orb: kof22/munitor)
- Latest stable orb: kof22/munitor@0.2.0
- Dev snapshot: kof22/munitor@dev:snapshot (pnpm support, 2026-03-27)
- Pipeline types (8): java-webapp, gradle-webapp, node-api, node-webapp, terraform, validate-cd-repo, sdk-distribution, argocd-apps
- CI workflows: lint-pack (all), snapshot (develop/feature), test-deploy (tags only)
- Default branch: develop (main is release-only)
- Test count: 219 assertions passing (across 7 test files)
- GitHub Issue: #5 (first-class pnpm support)

## pnpm Support (GH-5) Implementation Summary

### What was done (17 commits on feature/GH-5-pnpm-support)

**Phase 1 - Mechanical rename:**
- Renamed all `npm_*` jobs/commands/scripts to `node_*` (except `npm_auth` which stays)
- Updated all templates, tests, and CONTRIBUTING.md references

**Phase 2 - Package manager threading:**
- `package_manager` parameter threaded through: `install_node` -> `node_install_deps` -> `node_test` -> cache commands -> `node_build_and_test` job -> all templates
- Corepack activation in `install_node.sh` for pnpm/yarn (version detection from `packageManager` field or `engines`)
- `node_install_deps.sh` rewritten with npm/pnpm branching + Prisma auto-detection
- `node_test.sh` falls back to `pnpm test` for pnpm (instead of `npx jest`)
- Cache commands use PM-specific lockfile checksums and cache paths

**Phase 3 - Supplemental features:**
- `run_test_setup.sh` supports inline commands (not just file paths)
- `generate_dockerfile.sh` has pnpm Dockerfile variants for node-api (nextjs + express) and node-webapp
- Prisma auto-detection runs `prisma generate` after install for all PMs

**Phase 4 - Secondary job fixes (latest commit):**
- All secondary jobs (code-quality, coverage, e2e, security-scan, sonar, sbom) now run `install_node` with `node_version` + `package_manager` to bootstrap corepack/pnpm in their executors
- `node_coverage_check` supports configurable `coverage_summary_path` with glob patterns for monorepo weighted-average aggregation
- New `.munitor.yml` config: `test.coverage.summary_path` (default: `coverage/coverage-summary.json`)

### Design decisions
- Spec: `ClaudeCode/Munitor/docs/2026-03-27-pnpm-support-design.md`
- Plan: `ClaudeCode/Munitor/docs/2026-03-27-pnpm-support-plan.md`
- `npm_auth` NOT renamed (genuinely npm-registry-specific, .npmrc auth works for pnpm too)
- Monorepo Dockerfile generation out of scope (user provides custom Dockerfile)
- Yarn support limited to corepack plumbing (no yarn-specific testing)
- Coverage monorepo: glob + weighted average rather than auto-search

## Consumer Repos - Orb Version Status (updated 2026-03-27)
- `KofTwentyTwo/Concilium` - gradle-webapp, develop, **@0.2**, green (PR #41 merged)
- `KofTwentyTwo/Website-Backend` - java-webapp, develop, **@0.2** (PR #44 merged)
- `KofTwentyTwo/Website-Frontend` - node-webapp, develop, **@0.2** (PR #6 merged) - testing pnpm support via dev:snapshot
- `KofTwentyTwo/k8s-app-of-apps` - argocd-apps, develop, green (still on @0.1, compatible)
- `KofTwentyTwo/Website-CD` - validate-cd-repo, main, green (still on @0.1, compatible)
- `KofTwentyTwo/makers4` - java-webapp, main, **needs CircleCI follow**
- `KofTwentyTwo/terraform-proxmox-talos` - terraform, develop, **needs CircleCI follow**

## Next Steps
- Validate dev:snapshot on Website-Frontend (pnpm consumer) - confirm coverage job now works without corepack workaround
- Test `coverage_summary_path` glob if Website-Frontend is a monorepo
- Create PR #3 targeting develop once consumer validation passes
- Merge and release v0.3.0
- Bump consumer repos to @0.3
- Follow makers4 and terraform-proxmox-talos on CircleCI (manual UI step)
- Fix Website-Frontend ESLint error (DebugPanel.tsx:73 setState in effect, pre-existing)
- Adopt supplemental images on a consumer repo (e.g., me-health-portal with Liquibase)
