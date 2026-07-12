# Munitor

Latin: *munitor* (fortifier, protector) -- KofTwentyTwo's unified CircleCI orb for building, testing, and deploying all repositories. Pipeline changes happen in one place instead of 80+ repos.

## How It Works

Munitor uses CircleCI's [dynamic configuration](https://circleci.com/docs/dynamic-config/) to generate your full CI/CD pipeline at runtime. Each repo has a minimal `.circleci/config.yml` that triggers Munitor, and a `.munitor.yml` that declares what your project needs. Munitor reads your config, selects the right template, and generates a complete CircleCI workflow.

```
repo/.munitor.yml  -->  Munitor setup job  -->  Generated pipeline  -->  Build/Test/Deploy
```

## Quick Start

### 1. Add `.circleci/config.yml`

This file is identical across all repos:

```yaml
version: 2.1
setup: true
orbs:
  munitor: kof22/munitor@1
workflows:
  setup:
    jobs:
      - munitor/generate_pipeline
```

### 2. Add `.munitor.yml`

Pick your pipeline type and create the config in your repo root. See [Pipeline Types](#pipeline-types) below.

### 3. Ensure branch naming follows GitFlow

Munitor validates branch names and will fail on non-conforming names.

| Pattern | Purpose |
|---------|---------|
| `main` | Production releases |
| `develop` | Integration |
| `staging` | Staging environment branch |
| `feature/<name>` | Feature work |
| `release/<version>` | Release prep |
| `hotfix/<name>` | Production fixes |

## Prerequisites

1. **CircleCI project**: Add your repo at https://app.circleci.com
2. **Enable dynamic config**: Project Settings > Advanced > "Enable dynamic config using setup workflows"
3. **Allow uncertified orbs**: Organization Settings > Security > "Allow uncertified orbs"
4. **CircleCI contexts** (Organization Settings > Contexts):

| Context | Secrets | Used By |
|---------|---------|---------|
| `ghcr` | `GHCR_TOKEN`, `GHCR_USER` | Docker push to GitHub Container Registry |
| `github` | `GITHUB_TOKEN` | Git operations, CD repo updates, SBOM, GitHub Releases |
| `sonarcloud` | `SONAR_TOKEN` | SonarCloud analysis |
| `nvd` | `NVD_API_KEY` | OWASP dependency check (Java only, optional) |

## Pipeline Types

### `node-api`

For Node.js/Next.js applications with Docker deployment.

**Minimal config:**

```yaml
pipeline: node-api
orb_version: dev:snapshot
image_name: my-app
docker:
  registry: ghcr.io/KofTwentyTwo
contexts:
  registry: ghcr
  github: github
```

**Full config with all options:**

```yaml
pipeline: node-api
orb_version: dev:snapshot
image_name: my-app
node_version: "22"                    # default: 20

sonar:
  project_key: KofTwentyTwo_my-app       # omit to skip SonarCloud

docker:
  registry: ghcr.io/KofTwentyTwo

cd:
  repo: KofTwentyTwo/my-app-cd           # omit to skip GitOps CD updates
  env:
    release: staging                   # default: staging (CD target for release/* branches)

coverage:
  min_instruction: 80                 # default: 70

e2e: true                             # default: false (Playwright)
sbom: true                            # default: false
sast: true                            # default: false (Semgrep)

health:
  path: /api/health                   # default: /api/health
  port: 3000                          # default: 3000 (node-api), 8080 (java-webapp)

npm:
  private_registry: true              # authenticate to private npm before install

services:                             # start containers before tests
  - image: postgres:17
    port: 5432
    healthcheck: "pg_isready -U test -d mydb"
    env:
      POSTGRES_USER: test
      POSTGRES_PASSWORD: test
      POSTGRES_DB: mydb

test:
  setup: scripts/ci-setup.sh          # script to run before tests
  commands:                            # replaces default Jest runner
    - npx playwright install --with-deps chromium
    - npx playwright test
  coverage:
    tool: nyc                          # default: jest
    command: npm run coverage          # custom coverage command
    min_instruction: 80                # overrides top-level coverage.min_instruction

contexts:
  registry: ghcr
  github: github
  sonar: sonarcloud
```

**Dockerfile:** Auto-generated multi-stage build. Default framework is `nextjs`, targeting Next.js [standalone output](https://nextjs.org/docs/app/api-reference/config/next-config-js/output) (requires `output: 'standalone'` in `next.config.js`). Set `node: { framework: express }` for Express apps (production deps only, uses `node .` entrypoint). If you need full control over the Dockerfile, use `node-webapp` instead.

### `node-webapp`

For Node.js applications that provide their own Dockerfile (unlike `node-api` which auto-generates one). Use this when your app needs a custom Docker build process.

**Minimal config:**

```yaml
pipeline: node-webapp
orb_version: dev:snapshot
image_name: my-webapp
docker:
  registry: ghcr.io/KofTwentyTwo
  use_repo_dockerfile: true
contexts:
  registry: ghcr
  github: github
```

**Full config with all options:**

```yaml
pipeline: node-webapp
orb_version: dev:snapshot
image_name: my-webapp
node_version: "22"                    # default: 20

sonar:
  project_key: KofTwentyTwo_my-webapp    # omit to skip SonarCloud

docker:
  registry: ghcr.io/KofTwentyTwo
  use_repo_dockerfile: true              # preserve the repository Dockerfile

cd:
  repo: KofTwentyTwo/cluster-gitops      # omit to skip GitOps CD updates
  format: kustomize
  production_only: true                  # only main writes this production target
  path: tenants/my-app/website/kustomization.yaml
  env:
    release: staging                   # default: staging (CD target for release/* branches)

coverage:
  min_instruction: 80                 # default: 70

e2e: true                             # default: false (Playwright)
sbom: true                            # default: false
sast: true                            # default: false (Semgrep)

health:
  path: /api/health                   # default: /api/health
  port: 3000                          # default: 3000

npm:
  private_registry: true              # authenticate to private npm before install

services:                             # start containers before tests
  - image: postgres:17
    port: 5432
    healthcheck: "pg_isready -U test -d mydb"
    env:
      POSTGRES_USER: test
      POSTGRES_PASSWORD: test
      POSTGRES_DB: mydb

test:
  setup: scripts/ci-setup.sh          # script to run before tests
  commands:                            # replaces default Jest runner
    - npx playwright install --with-deps chromium
    - npx playwright test
  coverage:
    tool: nyc                          # default: jest
    command: npm run coverage          # custom coverage command
    min_instruction: 80                # overrides top-level coverage.min_instruction

contexts:
  registry: ghcr
  github: github
  sonar: sonarcloud
```

**Dockerfile:** Set `docker.use_repo_dockerfile: true` and provide `Dockerfile` in the repo root when the application owns its runtime contract. Munitor preserves and builds it, runs a health check, scans with Trivy, and pushes to the registry. Without the option, Munitor retains the legacy generated Dockerfile behavior. Use `node-api` when an always-generated framework Dockerfile is preferred.

### `java-webapp`

For Java/Maven applications with Docker deployment.

**Minimal config:**

```yaml
pipeline: java-webapp
orb_version: dev:snapshot
image_name: my-service
docker:
  registry: ghcr.io/KofTwentyTwo
contexts:
  registry: ghcr
  github: github
  nvd: nvd                            # optional, for OWASP dependency check
```

**Full config with all options:**

```yaml
pipeline: java-webapp
orb_version: dev:snapshot
image_name: my-service
java_version: "21"                    # default: 21

sonar:
  project_key: KofTwentyTwo_my-service   # omit to skip SonarCloud

docker:
  registry: ghcr.io/KofTwentyTwo

cd:
  repo: KofTwentyTwo/my-service-cd       # omit to skip GitOps CD updates
  env:
    release: staging                   # default: staging (CD target for release/* branches)

coverage:
  min_instruction: 80                 # default: 70

e2e: true                             # default: false
sbom: true                            # default: false
sast:                                 # or just `sast: true` to fail on findings
  fail_on_findings: false             # warn-only mode during migration

health:
  path: /api/health                   # default: /api/health
  port: 8080                          # default: 8080

contexts:
  registry: ghcr
  github: github
  sonar: sonarcloud
  nvd: nvd                            # optional, for OWASP dependency check
```

**What runs:** Maven build/test, Checkstyle, SpotBugs, PMD, JaCoCo coverage, OWASP + Trivy security, Docker build/push (Dockerfile auto-generated), gitleaks. OWASP dependency check requires the `nvd` context; if omitted, the security scan runs without NVD database enrichment.

**Dockerfile:** Auto-generated production-ready image using Eclipse Temurin JRE Alpine. Includes non-root user (uid 1001), JVM container tuning flags, Docker HEALTHCHECK, and configurable port via `health.port`. The pre-built JAR from CI is copied directly (no redundant Maven build stage).

### `terraform`

For Terraform/Terragrunt infrastructure repos.

**Minimal config:**

```yaml
pipeline: terraform
orb_version: dev:snapshot
terraform:
  path: terraform/
```

**Full config:**

```yaml
pipeline: terraform
orb_version: dev:snapshot
terraform:
  path: terraform/                     # default: terraform/
  live_path: terraform/live            # default: terraform/live
  environments:                        # default: [production]
    - production
    - staging
  checkov_skip: "CKV_AWS_144,CKV_AWS_145"

sast: true                             # default: false (Semgrep)
```

**What runs:** `tofu fmt` check, `terragrunt init/validate` per environment, Checkov, tfsec, Trivy, gitleaks.

### `validate-cd-repo`

For CD/GitOps repositories containing Kubernetes manifests, Kustomize overlays, sealed secrets, and ArgoCD application definitions. No application code, no Docker builds, no CD updates.

**Minimal config:**

```yaml
pipeline: validate-cd-repo
orb_version: dev:snapshot
```

**Full config:**

```yaml
pipeline: validate-cd-repo
orb_version: dev:snapshot

kustomize:
  version: "5.5.0"                      # default: 5.5.0
  base_path: base/                       # default: base/
  overlays:                              # default: auto-detect from overlays/*/kustomization.yaml
    - dev
    - staging
    - production
  load_restrictor: true                  # default: true (--load-restrictor LoadRestrictionsNone)
  scan_overlay: production               # default: production

kube_linter_config: .kube-linter.yaml    # default: none (auto-detect if file exists)
```

**What runs:** YAML lint, kustomize build validation (base + all overlays), kubesec security scan, kube-linter best practices check, gitleaks secrets scan.

### `argocd-apps`

For ArgoCD app-of-apps repositories that use environment directories (`envs/`) instead of the standard `base/` + `overlays/` kustomize layout. Functionally identical to `validate-cd-repo` but with a different default directory structure.

**Minimal config:**

```yaml
pipeline: argocd-apps
orb_version: dev:snapshot
```

**Full config:**

```yaml
pipeline: argocd-apps
orb_version: dev:snapshot

kustomize:
  version: "5.5.0"                      # default: 5.5.0
  base_path: ""                          # empty string skips base build
  overlay_dir: envs                      # default: overlays
  overlays:                              # default: auto-detect from {overlay_dir}/*/kustomization.yaml
    - dev
    - staging
    - production
  load_restrictor: true                  # default: true (--load-restrictor LoadRestrictionsNone)
  scan_overlay: production               # default: production

kube_linter_config: .kube-linter.yaml    # default: none
yamllint_paths: "envs/ apps/"            # default: bootstrap/ projects/ credentials/ envs/ apps/ infra/
```

**What runs:** YAML lint, kustomize build validation (overlays only when `base_path` is empty), kubesec security scan, kube-linter best practices check, gitleaks secrets scan.

### `sdk-distribution`

For SDK packaging and GitHub Releases. Triggered by semver tags (`v1.2.3`).

```yaml
pipeline: sdk-distribution
orb_version: dev:snapshot
contexts:
  github: github
```

**What runs:** Tag validation, SDK assembly/scrub/validate/package, SHA-256 checksums, GitHub Release with artifacts.

## Workflow Matrix

Each workflow runs on specific branches and includes jobs based on your config:

| Workflow | Branches | Jobs |
|----------|----------|------|
| `pr-checks` | `feature/*`, `hotfix/*` | Build, test, lint, coverage, security scans |
| `develop` | `develop` | All pr-checks + Docker build/push + CD update (dev env) |
| `staging` | `staging` | All pr-checks + Docker build/push + CD update (staging env) |
| `release-candidate` | `release/*` | All pr-checks + Docker, CD (staging), SonarCloud, SBOM, GitHub Release (pre-release) |
| `production` | `main` | Build + Docker + CD (prod) + GitHub Release (no quality gates) |

For `validate-cd-repo` and `argocd-apps`, all three workflows (`pr-checks`, `develop`, `release`) run the same 5-job set: yaml-lint, kustomize-validate, kubesec-scan, kube-linter, secrets-scan.

### Job Dependency Graph (node-api pr-checks)

```
checkout
  --> build-and-test
        --> code-quality
        --> coverage
        --> security-scan
        --> e2e-tests (if enabled)
  --> secrets-scan (parallel)
  --> sast-scan (parallel)
```

For `release-candidate` workflows, `docker-build-push` runs after all quality checks pass, followed by `sbom`, `update-cd-repo` (targeting staging), and `github-release` (marked as pre-release). For `production` workflows, `docker-build-push` runs directly after `build-and-test` (no quality gates -- those were enforced on the release branch), followed by `update-cd-repo` (targeting prod) and `github-release` (full release). The `github-release` job auto-creates an annotated git tag and GitHub Release using the version calculated by GitVersion.

## Release Workflow

Munitor follows a three-environment GitFlow model: **dev**, **staging**, **prod**. Release candidates on staging serve as the QA/UAT gate -- there is no separate UAT environment.

### Environments

| Environment | Branch | Version Format | Purpose |
|-------------|--------|----------------|---------|
| **Dev** | `develop` | `X.Y.Z-SNAPSHOT.SHA` | Integration testing, continuous builds |
| **Staging** | `release/*` | `X.Y.Z-RC.N` | QA validation, UAT, release candidate testing |
| **Prod** | `main` | `X.Y.Z` | Production release |

### How to release

1. **Develop** -- Merge feature branches into `develop`. Each push builds a SNAPSHOT image and deploys to the dev environment.
2. **Create release branch** -- When ready to release, create `release/X.Y.Z` from `develop`. This triggers the `release-candidate` workflow:
   - Full quality pipeline (build, test, lint, coverage, security, SAST, SonarCloud)
   - Docker image tagged `X.Y.Z-RC.1` pushed to registry
   - CD repo updated targeting **staging** environment
   - GitHub pre-release created (`vX.Y.Z-RC.1`)
3. **QA on staging** -- Test the RC on staging. If fixes are needed, commit directly to the release branch. Each push increments the RC number (`RC.2`, `RC.3`, etc.) and re-deploys to staging.
4. **Promote to production** -- Merge the release branch into `main`. This triggers the `production` workflow:
   - Build + Docker image tagged `X.Y.Z` (no quality gates -- already passed on the release branch)
   - CD repo updated targeting **prod** environment
   - Full GitHub Release created (`vX.Y.Z`)
5. **Back-merge** -- Merge `main` back into `develop` to carry forward the version bump.

### Hotfixes

For emergency production fixes: create `hotfix/<name>` from `main`, fix, then merge directly to `main`. The production workflow runs the same fast-path (build + Docker + CD + release). Back-merge to `develop` after.

### Versioning

Munitor manages versioning automatically via GitVersion. You do not need a `GitVersion.yml` in your repo -- Munitor writes a standard SDLC-compliant config at CI time. Version bumps follow commit conventions:

- **Patch** (default): every merge to main
- **Minor**: feature branch merge to develop
- **Major**: commit message containing `+semver: major`

Tags follow the format `vX.Y.Z` (git tag) and `X.Y.Z` (Docker tag). Tags are immutable and only created on main (full releases) or release branches (pre-releases).

## `.munitor.yml` Reference

| Field | Type | Default | Pipelines | Description |
|-------|------|---------|-----------|-------------|
| `pipeline` | string | *required* | all | Pipeline type: `node-api`, `node-webapp`, `java-webapp`, `terraform`, `sdk-distribution`, `validate-cd-repo`, `argocd-apps` |
| `orb_version` | string | *required* | all | Orb version for the generated pipeline (e.g., `1`, `dev:snapshot`) |
| `image_name` | string | *required** | node-api, node-webapp, java-webapp | Docker image name (without registry prefix) |
| `node_version` | string | `20` | node-api, node-webapp | Node.js major version |
| `java_version` | string | `21` | java-webapp | Java major version |
| `sonar.project_key` | string | -- | node-api, node-webapp, java-webapp | SonarCloud project key. Omit to skip |
| `docker.registry` | string | *required** | node-api, node-webapp, java-webapp | Container registry URL |
| `docker.use_repo_dockerfile` | bool | `false` | node-webapp | Preserve and build the repository-root Dockerfile instead of generating one |
| `cd.repo` | string | -- | node-api, node-webapp, java-webapp | GitOps CD repo (`org/repo`). Omit to skip |
| `cd.path` | string | -- | node-api, node-webapp, java-webapp | Explicit repository-relative `kustomization.yaml` path for consolidated GitOps repositories |
| `cd.production_only` | bool | `false` | node-api, node-webapp, java-webapp | Disable CD write-back from develop, staging, and release workflows |
| `cd.env.release` | string | `staging` | node-api, node-webapp, java-webapp | CD target environment for release branches |
| `coverage.min_instruction` | int | `70` | node-api, node-webapp, java-webapp | Minimum coverage percentage |
| `e2e` | bool | `false` | node-api, node-webapp, java-webapp | Enable Playwright E2E tests |
| `sbom` | bool | `false` | node-api, node-webapp, java-webapp | Enable SBOM generation |
| `sast` | bool/object | `false` | all except sdk | Enable Semgrep SAST scanning. Use `true`/`false` or object form |
| `sast.fail_on_findings` | bool | `true` | all except sdk | Fail build on SAST findings. Set `false` for warn-only mode |
| `node.framework` | string | `nextjs` | node-api | Node framework: `nextjs` or `express` (not used by node-webapp) |
| `health.path` | string | `/api/health` | node-api, node-webapp, java-webapp | Health check endpoint path |
| `health.port` | int | `3000`/`8080` | node-api, node-webapp, java-webapp | Health check port (3000 for node-*, 8080 for java-*) |
| `npm.private_registry` | bool | `false` | node-api, node-webapp | Authenticate to private npm registry |
| `services` | list | `[]` | node-api, node-webapp | Service containers to start before tests |
| `test.setup` | string | -- | node-api, node-webapp | Script to run before tests |
| `test.commands` | list | `[]` | node-api, node-webapp | Custom test commands (replaces default Jest) |
| `test.coverage.tool` | string | `jest` | node-api, node-webapp | Coverage tool (`jest` or `nyc`) |
| `test.coverage.command` | string | -- | node-api, node-webapp | Custom coverage generation command |
| `terraform.path` | string | `terraform/` | terraform | Root Terraform directory |
| `terraform.live_path` | string | `terraform/live` | terraform | Terragrunt live directory |
| `terraform.environments` | list | `[production]` | terraform | Environments to validate |
| `terraform.checkov_skip` | string | -- | terraform | Comma-separated Checkov rules to skip |
| `kustomize.version` | string | `5.5.0` | validate-cd-repo, argocd-apps | Kustomize version to install |
| `kustomize.base_path` | string | `base/` | validate-cd-repo, argocd-apps | Path to kustomize base directory. Empty string skips base build |
| `kustomize.overlay_dir` | string | `overlays` | validate-cd-repo, argocd-apps | Directory containing overlay subdirectories (e.g. `overlays`, `envs`) |
| `kustomize.overlays` | list | auto-detect | validate-cd-repo, argocd-apps | Overlay names to validate |
| `kustomize.load_restrictor` | bool | `true` | validate-cd-repo, argocd-apps | Use --load-restrictor LoadRestrictionsNone |
| `kustomize.scan_overlay` | string | `production` | validate-cd-repo, argocd-apps | Overlay to scan with kubesec/kube-linter |
| `kube_linter_config` | string | -- | validate-cd-repo, argocd-apps | Path to kube-linter config file |
| `yamllint_paths` | string | *pipeline-dependent* | validate-cd-repo, argocd-apps | Space-separated directories for YAML linting |
| `contexts.registry` | string | -- | node-api, node-webapp, java-webapp | CircleCI context for Docker push (e.g., `ghcr`) |
| `contexts.github` | string | -- | all | CircleCI context for Git/GitHub operations. Enables GitHub Releases when set |
| `contexts.sonar` | string | -- | node-api, node-webapp, java-webapp | CircleCI context for SonarCloud. Required if `sonar.project_key` is set |
| `contexts.nvd` | string | -- | java-webapp | CircleCI context for OWASP NVD database. Optional; security scan runs without it |

*\* Required for pipelines that build Docker images.*

## Health Check Requirement

Every container built by Munitor must expose a health endpoint. After the Docker image is built, Munitor starts the container and validates the endpoint returns HTTP 200. This is a mandatory gate; builds fail if the health check does not pass within 30 seconds.

Default endpoint: `GET /api/health` on port 3000 (node-api, node-webapp) or 8080 (java-webapp). Override via `health.path` and `health.port` in `.munitor.yml`.

## Troubleshooting

**"Missing required fields: orb_version"** -- Add `orb_version` to your `.munitor.yml`. Use `dev:snapshot` for pre-release testing or `1` once a stable release is published.

**"munitor_header: command not found"** -- You're using an older orb version. Update to `dev:snapshot` or wait for the next stable release.

**Empty output + exit code 1 on `npm ci`** -- Usually a PATH issue. Munitor exports node/npm to `BASH_ENV`; if this breaks, all subsequent steps fail silently. Check that `install_node` succeeded in the build logs.

**"Unknown key 'xxx' in .munitor.yml"** -- Munitor warns on unrecognized top-level keys to catch typos. Check spelling against the reference table above.

**Interactive prompt hangs (debconf/dpkg)** -- If test commands install system packages via apt, add `DEBIAN_FRONTEND=noninteractive` as a prefix. Munitor sets this automatically in the test runner, but explicit is safer for custom commands.

**"No template found for pipeline type"** -- The `pipeline` field must be one of: `node-api`, `node-webapp`, `java-webapp`, `terraform`, `sdk-distribution`, `validate-cd-repo`, `argocd-apps`.

**Setup succeeds but no continuation workflow appears** -- The generated config may contain invalid YAML that CircleCI accepts but can't execute. Common cause: an empty context list item from an unset optional context (e.g., `contexts.nvd`). Check the generated config by running `make publish-snapshot` and retriggering.

**Branch name rejected** -- Munitor enforces GitFlow naming. Rename your branch to match an allowed pattern.

**Tests pass locally but fail in CI** -- Check Node/Java version alignment. Add an `.nvmrc` file to keep local and CI versions in sync. Munitor will warn if `.nvmrc` and `.munitor.yml` versions differ.

## Development (Munitor Contributors)

```bash
make lint             # yamllint + shellcheck
make validate         # pack + circleci validate
make test-scripts     # structural + unit tests
make test-templates   # template rendering tests
make all              # run everything
```

Pushes to `develop` auto-publish `kof22/munitor@dev:snapshot`. Production releases are tagged on `main` (`v1.2.3`).

### Architecture

```
src/
  @orb.yml              # Orb metadata
  commands/*.yml         # 56 reusable commands (each wraps a script)
  jobs/*.yml             # 22 jobs composing commands into workflows
  executors/*.yml        # Machine executor definitions
  scripts/
    *.sh                 # 55+ bash scripts (the actual logic)
    munitor_helpers.sh     # Shared library (header, tool checks, download retry)
    templates/*.yml.tpl  # Pipeline templates with conditional blocks
    templates/partials/  # Reusable deploy workflow fragments
```

Pipeline generation flow:
1. `generate_pipeline` job runs `generate_config.sh`
2. Reads `.munitor.yml`, extracts variables via `extract_munitor_vars.sh`
3. Selects template based on `pipeline` type
4. Expands `##INCLUDE_DEPLOY##` markers with partial templates
5. Runs `envsubst` for variable substitution
6. Processes `##IF_*##` / `##ENDIF_*##` conditional blocks
7. Validates output YAML and passes to CircleCI continuation
