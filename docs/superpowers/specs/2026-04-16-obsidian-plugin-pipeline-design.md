# Design: obsidian-plugin Pipeline Type

New Munitor pipeline type for Obsidian plugins. Handles building, testing, quality gating, and releasing TypeScript/esbuild-based Obsidian plugins to GitHub Releases. No Docker, no CD deployment.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Pipeline naming | `obsidian-plugin` (specific) | Bakes in Obsidian conventions (hardcoded artifacts, no Docker) |
| Release model | Branch-based (release-candidate + production) | Aligns with SDLC Section 6.3 and org branching strategy |
| Quality gates | All node gates supported as conditionals | SAST, coverage, SBOM, security-scan enabled for obsidian-penny |
| Artifact handling | Hardcoded `main.js manifest.json styles.css` | Convention over configuration for Obsidian-specific type |
| Artifact upload mechanism | Extend existing `github_release` job | Adds `release_artifacts` parameter; minimal orb changes |
| Build output persistence | Use `test.commands` override to chain build + test | Works today with no orb changes; dedicated `build_command` can come later |

## Template Structure

File: `src/scripts/templates/obsidian-plugin.yml.tpl`

Four workflows matching the SDLC branch model:

### pr-checks (feature/\*, hotfix/\*)

Full quality pipeline. Jobs:
- `node_build_and_test` (npm install + build + test via `test.commands`)
- `secrets_scan`
- `sast_scan` (conditional: `##IF_SAST##`)
- `node_code_quality` (requires: build-and-test)
- `node_coverage` (requires: build-and-test)
- `node_security_scan` (requires: build-and-test)
- `node_e2e_test` (conditional: `##IF_E2E##`, requires: build-and-test)

### develop (develop branch)

Smoke check only. Jobs:
- `node_build_and_test`

No deploy partials, no Docker, no CD. This differs from node-api/node-webapp which use `##INCLUDE_DEPLOY##` for develop.

### release-candidate (release/\*)

Full quality pipeline gated before release. Jobs:
- All pr-checks jobs
- `node_sonar_scan` (conditional: `##IF_SONAR##`)
- `node_sbom` (conditional: `##IF_SBOM##`, gated on quality gates)
- `github_release` with `release_artifacts: "main.js manifest.json styles.css"` (gated on quality gates, pre-release via RC version detection)

The `github_release` job requires all quality gate jobs. No Docker gate since there is no Docker job.

### production (main)

Fast-path promotion (quality gates already passed on release/\*). Jobs:
- `node_build_and_test`
- `github_release` with `release_artifacts: "main.js manifest.json styles.css"` (requires: build-and-test, full release)

## Changes to `github_release` Job/Script

### `src/jobs/github_release.yml`

Add optional parameter:

```yaml
parameters:
  release_artifacts:
    type: string
    default: ""
    description: "Space-separated list of files to upload to the GitHub Release"
```

Pass to script as `MUNITOR_RELEASE_ARTIFACTS` environment variable.

### `src/scripts/github_release.sh`

After the `gh release create` block, add artifact upload:

```bash
if [[ -n "${MUNITOR_RELEASE_ARTIFACTS:-}" ]]; then
  echo "Uploading release artifacts: ${MUNITOR_RELEASE_ARTIFACTS}"
  # shellcheck disable=SC2086
  gh release upload "${TAG}" ${MUNITOR_RELEASE_ARTIFACTS}
fi
```

Uses `gh release upload` (separate from create) so it works whether the release was just created or already existed. Backward compatible -- existing pipelines pass no artifacts.

## `.munitor.yml` Schema

obsidian-penny configuration:

```yaml
pipeline: obsidian-plugin
orb_version: "0.3"
node_version: "20"
sast: true
sbom: true
test:
  commands: ["npm run build", "npm test"]
  coverage:
    tool: vitest
    command: npx vitest run --coverage
contexts:
  github: github
```

No new variables in `extract_munitor_vars.sh`. The template uses a subset of existing `MUNITOR_*` variables: `NODE_VERSION`, `PACKAGE_MANAGER`, `SAST`, `SAST_FAIL_ON_FINDINGS`, `SBOM`, `COVERAGE_MIN`, `COVERAGE_TOOL`, `COVERAGE_COMMAND`, `CONTEXT_GITHUB`, and the node feature flags.

### `generate_config.sh` validation

Add `obsidian-plugin` to the pipeline type case statement. Required: `contexts.github`. Not required: `image_name`, `docker.registry`, `cd.repo`.

### `packed_generate_config.sh`

Embed `obsidian-plugin.yml.tpl` in the packed script using the same heredoc pattern as other templates.

## Testing

### Test fixture

`tests/fixtures/obsidian-plugin.munitor.yml` -- mirrors the schema above.

### `tests/test_generate_config.sh`

Positive tests (patterns present):
- Valid YAML output
- All 4 workflows: `pr-checks`, `develop`, `release-candidate`, `production`
- `build-and-test` in all workflows
- `secrets-scan` and `sast-scan` in pr-checks and release-candidate
- `github-release` in release-candidate and production
- `release_artifacts: "main.js manifest.json styles.css"` on github-release jobs
- `security-scan` present
- `sbom` present
- Correct branch filters

Negative tests (patterns absent):
- No `docker-build-push`
- No `update-cd-repo`
- No `image_name` or `registry` references
- No `INCLUDE_DEPLOY` partials

### `tests/test_scripts.sh`

- `github_release.sh` with `MUNITOR_RELEASE_ARTIFACTS` set -- verify upload behavior
- `github_release.sh` with `MUNITOR_RELEASE_ARTIFACTS` empty -- verify no upload (backward compat)

## Consumer Repo Changes (obsidian-penny, post-release)

1. Create `.munitor.yml` (schema above)
2. Bump `.circleci/config.yml` orb version to new release
3. Remove `.github/workflows/release.yml` (redundant)
4. Verify workspace persistence delivers `main.js` to `github_release` job

## Not Changed

- `extract_munitor_vars.sh` -- no new variables needed
- `node_build_and_test` job -- works as-is with `test.commands` override
- Other pipeline templates -- no modifications
- `sdk-distribution.yml.tpl` -- remains tag-based, separate use case
