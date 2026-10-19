# Munitor session state

## JVM runtime package freshness (2026-10-19)

Website-Backend release6258 and PR scans6266/6277 reused a cached apk upgrade
layer containing vulnerable libexpat. The shared docker_build command now pulls
the base and bypasses layer caching for generated Java/Gradle runtimes, while
Node caching and all Trivy gates remain intact. Narrow behavioral tests cover
both pipeline types, alternate/missing manifests, tags, provenance, and both
PR/release job routes. All eight focused shell cases passed via the coordinating
agent; ShellCheck and git diff --check passed. Full make/BATS/orb validation and
real-image scanning remain pending. Stable release and consumer adoption remain
pending; no unchanged vulnerable image should be retried.

## PR container scanning (2026-10-13)

Uncommitted work on `feature/pr-image-scan` adds `docker_scan` after
`build-and-test` in the four application PR templates. It restores the existing
feature/hotfix version metadata, builds locally, and applies the release Trivy
HIGH/CRITICAL policy from the repository root. Supplemental images use
`push: false`; the command defaults to publishing for existing callers. Main
and supplemental JSON reports are artifacts. Release candidates already scan
through `docker_build_push`, so no duplicate job was added.

Verified: native CircleCI orb pack/validate, ShellCheck on all source scripts
and the changed tests, template structure/filters/parameter wiring, packed
template synchronization, and `git diff --check`. Requested make and BATS runs
were attempted but Git Bash cannot start in this sandbox (CreateFileMapping,
Win32 error 5); yamllint is not installed. New behavioral tests therefore need
a Linux/CI run, including real Docker/Trivy integration. No commit or publish.
The Second Brain vault is outside writable roots; continuity is recorded here.

## Release 0.3.3 (2026-10-11)

PR22 (00f349c) fixes release version collisions. Website-Backend #65/#66 (0.1.24)
and #80/#79 (0.1.32) built concurrently, computed the same GitVersion version,
overwrote the GHCR tag, and github-release tagged the moving main head, so prod
ran an image missing the later merge. Build jobs now reserve vX.Y.Z atomically
(POST git/refs; next patch on conflict; tags never move), docker_build_push guards
immutable version tags via the org.opencontainers.image.revision label,
update_cd_repo verifies tag ownership, and github_release targets CIRCLE_SHA1.
The generator renders cd_path only when cd.path is set (older-orb manifests on
website develop branches, Concilium, and makers4 failed with "Unexpected
argument(s): cd_path"). Consumer pin bumps are coordinated per repo because a
main merge deploys.

Local Windows runs: 4 test_generate_config health_path assertions fail on clean
develop too (Git-for-Windows rewrites /api/health); CI on Linux is authoritative.

## Release candidate 0.3.2 (2026-10-10)

Munitor PR19 merged to develop at c8bbf2e. Release branch `release/0.3.2`
promotes the bounded publishing CI fixes to main. Full make all and the feature
CircleCI lint/pack/review/snapshot publication passed. Stable publication still
requires the v0.3.2 tag on main and successful production orb publication.

EX-0008 is registered by standards PR27 (5c21fc7); Website-Frontend may select the
new stable orb after publication. Default audit policy, Trivy and GitOps contracts
are preserved. Website-Backend's Java installation now avoids interactive Ubuntu
service-restart dialogs. Website consumers and production remain pending.

## Current status

The `develop` branch contains the complete `0.3.0` feature set. PR #6 added
first-class pnpm support and the Obsidian pipeline, PR #8 added opt-in
repository Dockerfile preservation for `node-webapp`, and PR #10 added
consolidated Kustomize GitOps write-back with production-only controls and
bounded push-race retries. Investing in Chester and QRun marketing both proved
the release path through CircleCI, GHCR, `KofTwentyTwo/cluster-gitops`, and
ArgoCD.

## Release state

- Latest stable target: `kof22/munitor@0.3.0`
- Stable consumer pin: `kof22/munitor@0.3`
- Development aliases: `dev:<commit>` and `dev:snapshot`
- Default branch: `develop`; `main` is release-only
- Release tag: `v0.3.0`

## Verification

Run `make all` before release. The stable tag must publish successfully through
CircleCI before consumer repositories move from immutable development pins to
`0.3`.

## Publishing release CI fixes (2026-10-10)

Feature branch `feature/scoped-audit-exceptions` prepares development-only npm
exceptions with expiry, exact advisory/package/version checks, an independent
production audit and reassessment on a new upstream release. Website-Frontend's
proposed EX-0008 covers braces 3.0.3 through 2026-11-10. Regression tests exercise
acceptance and rejection paths. The default audit and Trivy remain unchanged.

Website-Backend CI job 1135 timed out in Ubuntu's interactive needrestart prompt
after Java installation. APT now receives noninteractive debconf and automatic
needrestart settings; a stubbed integration test verifies both APT invocations.
These fixes require normal feature-to-develop review and stable tag publication
from main before website consumers can select the new version. Nothing deployed.

Runtime freshness validation: coordinating agent completed make all (lint, pack, orb validation, scripts,277template assertions) and all7BATS tests in Ubuntu. Real consumer image scan remains required after release.
