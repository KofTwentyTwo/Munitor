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
