# Contributing to Munitor

## Module Inventory

Munitor organizes CI/CD pipelines into **modules** (called "pipeline types" in `.munitor.yml`). Each module is a self-contained set of templates, jobs, commands, and scripts that handle a specific application stack.

### Current Modules

| Module | `.munitor.yml` name | Stack | Deploys Docker | Environments | Repos Using It |
|--------|-------------------|-------|---------------|--------------|----------------|
| **Node.js API** | `node-api` | Node.js, Next.js, TypeScript | Yes (auto-generated Dockerfile) | dev, staging, prod | me-health-website, me-health-dashboard-api, fulfillment APIs |
| **Node.js Webapp** | `node-webapp` | Node.js, TypeScript | Yes (user-provided Dockerfile) | dev, staging, prod | Website-Frontend |
| **Java Webapp** | `java-webapp` | Java, Maven | Yes (auto-generated Dockerfile) | dev, staging, prod | Website-Backend |
| **Terraform** | `terraform` | HCL, Terragrunt, OpenTofu | No | N/A | me-health-portal-infrastructure, terraform-sandbox, aft-* |
| **SDK Distribution** | `sdk-distribution` | Any (binary artifacts) | No | N/A | GGBluetoothSDK, ggHealthKitPackage |
| **CD Repo Validation** | `validate-cd-repo` | Kustomize, K8s manifests, ArgoCD | No | N/A | Website-CD, me-health-portal-cd |

### Planned Modules

| Module | Proposed name | Stack | Priority | Target Repos |
|--------|--------------|-------|----------|--------------|
| **Python App** | `python-app` | Python, pip/poetry, pytest | Medium | sdlc-monitor, me-health-portal-utils |
| **iOS App** | `ios-app` | Swift, Xcode, fastlane | Low | SageiOSApp, perfectPortions3-iOS, GGBluetoothSDK-RPM |
| **Android App** | `android-app` | Kotlin, Gradle | Low | SageAndroidApp, vico |
| **Static Site** | `static-site` | HTML/JS, no Docker | Low | ggSite, balanceWebsite |

## Module Architecture

Each module consists of these components:

```
src/scripts/templates/
  {module-name}.yml.tpl              # Main template (required)
  partials/{module-name}-deploy.yml.tpl  # Deploy partial (if multi-env)

src/scripts/
  {tool}_{action}.sh                 # Backing scripts for commands

src/commands/
  {tool}_{action}.yml                # Orb commands (reusable steps)

src/jobs/
  {module-prefix}_build_and_test.yml # Orb jobs (executor + steps)
  {module-prefix}_code_quality.yml
  {module-prefix}_coverage.yml
  ...

tests/fixtures/
  {module-name}.munitor.yml            # Full-featured test fixture
  {module-name}-minimal.munitor.yml    # Minimal test fixture
```

### How a module executes

```
1. Consumer repo has .munitor.yml with: pipeline: {module-name}

2. generate_config.sh:
   a. Reads .munitor.yml
   b. extract_munitor_vars.sh maps fields to MUNITOR_* shell variables
   c. Selects templates/{module-name}.yml.tpl
   d. Expands ##INCLUDE_DEPLOY## markers with deploy partials
   e. Runs envsubst for ${MUNITOR_*} variable substitution
   f. Processes ##IF_FLAG## / ##ENDIF_FLAG## conditional blocks
   g. Validates output YAML

3. CircleCI continuation runs the generated pipeline, which references
   munitor orb jobs/commands by name (e.g., munitor/npm_build_and_test)
```

## Adding a New Module

### Step 1: Create the pipeline template

**File:** `src/scripts/templates/{module-name}.yml.tpl`

This is the CircleCI config that gets generated. Use `${MUNITOR_*}` variables and conditional blocks:

```yaml
version: 2.1

orbs:
  munitor: kof22/munitor@${MUNITOR_ORB_VERSION}

workflows:
  pr-checks:
    jobs:
      - munitor/{module}_build_and_test:
          name: build-and-test
          context:
            - ${MUNITOR_CONTEXT_GITHUB}
          filters:
            branches:
              only:
                - /feature\/.*/
                - /hotfix\/.*/
      - munitor/secrets_scan:
          name: secrets-scan
          filters:
            branches:
              only:
                - /feature\/.*/
                - /hotfix\/.*/
      ##IF_SAST##
      - munitor/sast_scan:
          name: sast-scan
          filters:
            branches:
              only:
                - /feature\/.*/
                - /hotfix\/.*/
      ##ENDIF_SAST##
```

Available conditional flags: `E2E`, `SBOM`, `SONAR`, `NPM_AUTH`, `SERVICES`, `TEST_SETUP`, `CUSTOM_TEST`, `COVERAGE_CMD`, `GITHUB_RELEASE`, `SAST`, `CD`, `NVD`.

Templates use a split workflow pattern for release and production:
- **`release-candidate:`** (release/* branches) -- Full quality pipeline with all gates
- **`production:`** (main branch) -- Fast-path: build + deploy only (quality was enforced on the release branch)

To add a new flag, set it in `extract_munitor_vars.sh`, export it, and add it to the processing loop in `generate_config.sh` (line ~201). **Important:** any optional context (like `nvd`) that may be empty must be wrapped in a conditional to avoid generating empty YAML list items, which silently break CircleCI continuation.

### Step 2: Create deploy partials (if multi-environment)

**File:** `src/scripts/templates/partials/{module-name}-deploy.yml.tpl`

Uses placeholders that get replaced per environment:
- `__WORKFLOW_NAME__` -- workflow name (e.g., `develop`, `staging`)
- `__BRANCH_FILTER__` -- branch pattern (e.g., `develop`, `staging`)
- `__CD_ENVIRONMENT__` -- CD target env (e.g., `develop`, `staging`)

Reference from the main template:
```
##INCLUDE_DEPLOY {module-name}-deploy develop develop develop##
##INCLUDE_DEPLOY {module-name}-deploy staging staging staging##
```

### Step 3: Add variable extraction

**File:** `src/scripts/extract_munitor_vars.sh` (edit existing)

Add module-specific fields to `extract_munitor_vars()`:

```bash
# Python-app settings
MUNITOR_PYTHON_VERSION=$(yq '.python_version // "3.12"' "${config_file}")
```

Then add to the exports:
```bash
export MUNITOR_PYTHON_VERSION
```

And add to `get_envsubst_vars()`:
```bash
echo '... ${MUNITOR_PYTHON_VERSION}'
```

### Step 4: Register the module in generate_config.sh

**File:** `src/scripts/generate_config.sh` (edit existing)

**Required fields validation** (~line 69):
```bash
case "${pipeline}" in
  ...
  python-app)
    # Add any required fields for this module
    [[ -z "$(yq '.image_name // ""' "${config}")" ]] && missing+=("image_name")
    ;;
esac
```

**Known keys** (~line 91) -- add any new top-level `.munitor.yml` keys:
```bash
KNOWN_KEYS="... python_version"
```

### Step 5: Create orb jobs and commands

Jobs go in `src/jobs/`, commands in `src/commands/`, scripts in `src/scripts/`.

**Job pattern** (`src/jobs/{module}_build_and_test.yml`):
```yaml
description: >
  Build and test Python application.
parameters:
  python_version:
    type: string
    default: "3.12"
    description: Python version to install.
  resource_class:
    type: enum
    enum: [medium, large]
    default: medium
    description: Machine resource class.
executor:
  name: machine
  resource_class: << parameters.resource_class >>
steps:
  - checkout
  - install_python:
      version: << parameters.python_version >>
  - pip_install
  - python_test
```

**Command pattern** (`src/commands/pip_install.yml`):
```yaml
description: >
  Install Python dependencies via pip.
steps:
  - run:
      name: pip install
      command: <<include(scripts/pip_install.sh)>>
```

**Script pattern** (`src/scripts/pip_install.sh`):
```bash
#!/usr/bin/env bash
set -euo pipefail

# Source shared helpers
MUNITOR_HELPERS="${MUNITOR_HELPERS:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/munitor_helpers.sh}"
# shellcheck source=munitor_helpers.sh
if [[ -f "${MUNITOR_HELPERS}" ]]; then source "${MUNITOR_HELPERS}"
elif ! type munitor_header &>/dev/null; then
  munitor_header() { echo "=== Munitor: ${1:-unknown} ==="; }
  munitor_check_tool() { command -v "$1" &>/dev/null || { echo "ERROR: $1 not found"; exit 1; }; }
  munitor_download_with_retry() { curl -fsSL --retry 3 "$1" -o "$2"; }
fi

munitor_header "pip_install"
munitor_check_tool pip3 --version

pip3 install -r requirements.txt
```

### Step 6: Register in pack script

**File:** `scripts/pack_generate_config.sh` (edit existing)

Add template to the packing loop (~line 42):
```bash
for tpl in java-webapp node-api node-webapp terraform sdk-distribution validate-cd-repo python-app; do
```

If you added deploy partials, add those too (~line 50):
```bash
for partial in java-webapp-deploy node-api-deploy node-webapp-deploy python-app-deploy; do
```

Regenerate: `bash scripts/pack_generate_config.sh`

### Step 7: Add tests

**Test fixtures** (`tests/fixtures/`):

Create at least two:
- `{module-name}.munitor.yml` -- all features enabled
- `{module-name}-minimal.munitor.yml` -- bare minimum config

**Template rendering tests** (`tests/test_generate_config.sh`):
```bash
echo ""
echo "=== python-app Template Tests ==="

run_test "python-app: uses correct orb" \
  "${FIXTURES_DIR}/python-app.munitor.yml" \
  "kof22/munitor@"

run_test "python-app: renders python_version" \
  "${FIXTURES_DIR}/python-app.munitor.yml" \
  'python_version: "3.12"'

run_negative_test "python-app-minimal: no sast block" \
  "${FIXTURES_DIR}/python-app-minimal.munitor.yml" \
  "sast-scan"
```

**Variable extraction tests** (`tests/test_extract_munitor_vars.sh`):
```bash
echo ""
echo "=== python-app Variable Tests ==="
extract_munitor_vars "${FIXTURES_DIR}/python-app.munitor.yml"
assert_eq "MUNITOR_PIPELINE" "python-app" "${MUNITOR_PIPELINE}"
assert_eq "MUNITOR_PYTHON_VERSION" "3.12" "${MUNITOR_PYTHON_VERSION}"
```

### Step 8: Validate and publish

```bash
make all                            # lint + validate + all tests
bash scripts/pack_generate_config.sh # regenerate packed script
circleci orb pack src > orb.yml     # pack the orb
circleci orb validate orb.yml       # validate
git push origin develop             # triggers dev:snapshot publish
```

## Naming Conventions

| Component | Convention | Example |
|-----------|-----------|---------|
| Module name | `lowercase-with-hyphens` | `python-app` |
| Template file | `{module}.yml.tpl` | `python-app.yml.tpl` |
| Deploy partial | `{module}-deploy.yml.tpl` | `python-app-deploy.yml.tpl` |
| Orb command | `snake_case` | `pip_install` |
| Orb job | `snake_case` | `python_build_and_test` |
| Shell script | `snake_case.sh` | `pip_install.sh` |
| MUNITOR variable | `MUNITOR_UPPER_SNAKE` | `MUNITOR_PYTHON_VERSION` |
| Conditional flag | `UPPER_SNAKE` | `##IF_SAST##` |
| Test fixture | `{module}[-variant].munitor.yml` | `python-app-minimal.munitor.yml` |

## Shared Infrastructure

These components are shared across all modules -- you don't need to recreate them:

| Component | What It Does |
|-----------|-------------|
| `munitor_helpers.sh` | Standard header, tool checks, download retry |
| `validate_branch.sh` | GitFlow branch name enforcement |
| `secrets_scan` job | Gitleaks (all modules) |
| `sast_scan` job | Semgrep (all modules, opt-in) |
| `docker_build_push` job | Build + health check + Trivy scan + GHCR push |
| `health_check` command | Container health check smoke test (all Docker modules) |
| `update_cd_repo` job | GitOps CD repo update |
| `github_release` job | Annotated git tags + GitHub Releases (auto-enabled with `contexts.github`) |
| `sbom` job | Software Bill of Materials |
| `sonar_scan` job | SonarCloud analysis |

Reuse these in your template rather than creating new ones. Only create new jobs/commands when existing ones don't fit your stack.
