# PLAN: SDLC Release Branch Workflow

## Goal

Split the single `release:` workflow (shared by main + release/* branches) into two distinct workflows: `release-candidate:` (release/* only, full quality pipeline) and `production:` (main only, fast-path promotion). Aligns templates with SDLC Section 6.3 and Versioning Policy Sections 2/7.

## Approach

Modify all three application templates (java-webapp, node-api, terraform) to separate QA-gated release candidate builds from streamlined production promotions. Also fix supporting scripts to support pre-release GitHub Releases, Faber-managed GitVersion config, and remove the banned `latest` Docker env tag.

## Versioning Policy Compliance

| Policy Requirement | Implementation |
|---|---|
| Section 2: develop=SNAPSHOT, release/*=RC.N, main=X.Y.Z | `export_version_vars.sh` (already done) |
| Section 2: GitVersion calculates versions automatically | `calculate_version.sh` writes standard GitVersion.yml |
| Section 3: Git tag = `v{X.Y.Z}`, Docker tag = `{X.Y.Z}` | `github_release.sh` prefixes `v`; version vars produce clean semver |
| Section 3: Tags immutable, only on main (+ pre-release on release/*) | `github_release.sh` dynamic `--target` and `--prerelease` |
| Section 7: No `latest` as deployment target | Remove from `export_version_vars.sh` main case |

## Files Affected

### Scripts
- `src/scripts/calculate_version.sh` -- Write Faber-managed GitVersion.yml before running GitVersion
- `src/scripts/github_release.sh` -- Support `--prerelease` flag for RC versions, dynamic `--target`
- `src/scripts/extract_faber_vars.sh` -- Add `FABER_CD_ENV_RELEASE` (default: "staging")
- `src/scripts/export_version_vars.sh` -- Remove `latest` Docker env tag from main case

### Templates
- `src/scripts/templates/java-webapp.yml.tpl` -- Split `release:` into `release-candidate:` + `production:`
- `src/scripts/templates/node-api.yml.tpl` -- Same split
- `src/scripts/templates/terraform.yml.tpl` -- Same split (lighter -- no Docker/CD)

### Tests
- `tests/test_extract_faber_vars.sh` -- Assert `FABER_CD_ENV_RELEASE` default
- `tests/test_version_mapping.sh` -- Main env tag "" (not "latest")
- `tests/test_generate_config.sh` -- Replace release tests with release-candidate + production tests
- `tests/test_scripts.sh` -- Add tests for calculate_version.sh and github_release.sh changes

### Docs
- `README.md` -- Update Workflow Matrix, add `cd.env.release` to reference table
- `CONTRIBUTING.md` -- Update template example to show split workflow pattern

## Steps

### 0. calculate_version.sh -- Faber owns GitVersion config

Before the `docker run` command, always write the standard SDLC-compliant `GitVersion.yml`. If the repo already has one, warn and overwrite.

Config:
- `tag-prefix: v` -- finds existing `v1.2.0` tags
- `commit-message-incrementing: Enabled` -- supports `+semver: major`
- develop `increment: Minor` -- feature merge to develop = minor bump
- release `increment: None` -- version from branch name
- hotfix `increment: Patch` + `source-branches: [main]`
- main `prevent-increment-of-merged-branch-version: true`

### 1. extract_faber_vars.sh -- add FABER_CD_ENV_RELEASE

After `FABER_CD_ENV_PROD` line:
```bash
FABER_CD_ENV_RELEASE=$(yq '.cd.env.release // "staging"' "${config_file}")
```
Add to export list and `get_envsubst_vars()`.

### 2. export_version_vars.sh -- remove `latest`

Change main case from `DOCKER_ENV_TAG="latest"` to remove that line. The variable defaults to `""` at the top of the script, so main builds get only the version tag.

### 3. github_release.sh -- pre-release support

Detect RC/pre-release versions and set `--prerelease` flag + dynamic `--target`:
- release/* branch: `1.2.0-RC.2` -> tag `v1.2.0-RC.2`, pre-release, targets release branch
- main branch: `1.2.0` -> tag `v1.2.0`, full release, targets main

### 4. java-webapp.yml.tpl -- split release workflow

Replace `release:` (lines 84-247) with:

**`release-candidate:`** (release/* only):
- Full quality pipeline: build-and-test, secrets-scan, sast-scan, code-quality, coverage, security-scan
- Conditional: e2e-tests, sonar-scan
- docker-build-push gated on all quality gates
- Conditional: sbom
- CD update targeting `${FABER_CD_ENV_RELEASE}` (not prod)
- github-release (pre-release)

**`production:`** (main only):
- build-and-test (required for JAR/artifact)
- docker-build-push (requires only build-and-test)
- CD update targeting `${FABER_CD_ENV_PROD}`
- github-release (full release)

Written inline (not via INCLUDE_DEPLOY) because the regex `/release\/.*/` would break the sed delimiter in `expand_includes`.

### 5. node-api.yml.tpl -- same split

Identical structure using node-specific jobs. Preserves all node conditional blocks.

### 6. terraform.yml.tpl -- minimal split

**`release-candidate:`** (release/*): full validation (validate-repo, tf-validate, tf-security-scan, secrets-scan, conditional sast-scan)
**`production:`** (main): minimal validation (validate-repo, tf-validate only)

### 7. Tests

Update all test files to validate the new workflow structure.

### 8. Documentation

Update README.md and CONTRIBUTING.md to reflect the split workflow.

### 9. Validate

Run `make all` to confirm everything passes.

## Not Changed

- `sdk-distribution.yml.tpl` -- tag-based release, no branch workflows
- `update_cd_repo.sh` -- digest fix already in MH-674
- `docker_build.sh` / `docker_push_ghcr.sh` -- already handle empty env tags
- INCLUDE_DEPLOY partials -- still used for develop/staging
