# Munitor

CircleCI orb that generates CI/CD pipeline configurations from a `.munitor.yml` manifest. Supports 8 pipeline types: java-webapp, gradle-webapp, node-api, node-webapp, terraform, validate-cd-repo, sdk-distribution, argocd-apps.

## Key Commands

```bash
make test          # Run all tests (BATS)
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
- Latest stable: `kof22/munitor@0.2.0`
- Dev snapshot: `kof22/munitor@dev:snapshot`

## Session Continuity

- Session state: `docs/SESSION-STATE.md`
- Active tasks: `docs/TODO.md`
- Plans: `docs/PLAN-*.md`
