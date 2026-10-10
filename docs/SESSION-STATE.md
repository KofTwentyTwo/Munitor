# Munitor session state

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
