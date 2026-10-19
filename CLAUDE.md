# Munitor

CircleCI orb that generates CI/CD pipeline configurations from a `.munitor.yml` manifest. Supports 8 pipeline types: java-webapp, gradle-webapp, node-api, node-webapp, terraform, validate-cd-repo, sdk-distribution, argocd-apps.

## Key Commands

```bash
make test-scripts  # Script unit tests (bats tests for the .bats suites)
make pack          # Pack orb YAML from src/
make all           # lint + pack + test
make validate      # Validate packed orb with CircleCI CLI
```

## Project Structure

- `src/commands/` - CircleCI orb commands (YAML)
- `src/jobs/` - CircleCI orb jobs (YAML)
- `src/scripts/` - Shell scripts included by commands/jobs
- `src/scripts/templates/` - Pipeline config templates (`.yml.tpl`)
- `src/scripts/templates/partials/` - Include partials for templates
- `tests/` - BATS test files
- `tests/fixtures/` - Test fixture `.munitor.yml` files

## Issue Tracker

GitHub Issues (org: KofTwentyTwo). Commit format: `feat(#N): description` or `Closes #N` in body.

## CircleCI Orb

- Namespace: `kof22`
- Orb: `kof22/munitor`
- Latest stable: `kof22/munitor@0.3.11`
- Dev snapshot: `kof22/munitor@dev:snapshot`

`0.3.0` includes first-class pnpm support, repository-owned Dockerfiles for
`node-webapp`, and consolidated Kustomize GitOps write-back with optional
production-only behavior and bounded push-race retries. `0.3.1` moves the
generated `node-webapp` runtime to `distroless/nodejs<N>-debian13` (debian12
failed the Trivy gate on OpenSSL CVEs). `0.3.3` makes release versions on
`main` atomic (git-tag reservation via the GitHub refs API), refuses to
overwrite version image tags built from another commit, checks tag ownership
before the GitOps bump, and renders `cd_path` only when `cd.path` is set.

## Session Continuity

- Session state: `docs/SESSION-STATE.md`
- Active tasks: `docs/TODO.md`
- Plans: `docs/PLAN-*.md`

Read `AGENTS.md` and `CONTRIBUTING.md` before changing orb behavior. Feature
branches target `develop`; release branches promote to `main`, and stable orb
publication is driven by a `vX.Y.Z` tag.
