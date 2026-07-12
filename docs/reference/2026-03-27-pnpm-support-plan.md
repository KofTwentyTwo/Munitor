# First-Class Package Manager Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `package_manager` in `.munitor.yml` drive behavior across the full Node.js lifecycle (install, test, cache, Dockerfile, Prisma), rename `npm_*` orb components to `node_*`, and release as v0.3.0.

**Architecture:** Three phases: (1) mechanical rename of all `npm_*` files to `node_*` with no behavior change, (2) thread `package_manager` parameter through the orb's job/command/script chain and add pnpm-aware branching, (3) supplemental features (Prisma auto-detection, test.setup inline commands, Dockerfile pnpm support). Each phase ends with `make all` passing.

**Tech Stack:** Bash, CircleCI orb YAML, shellcheck, yamllint, bats-style test assertions

**Spec:** `ClaudeCode/Munitor/docs/2026-03-27-pnpm-support-design.md`

---

## File Map

### Renames (old -> new)

**Scripts:**
- `src/scripts/npm_install.sh` -> `src/scripts/node_install_deps.sh`
- `src/scripts/npm_test.sh` -> `src/scripts/node_test.sh`
- `src/scripts/npm_lint.sh` -> `src/scripts/node_lint.sh`
- `src/scripts/npm_audit.sh` -> `src/scripts/node_audit.sh`
- `src/scripts/npm_coverage_check.sh` -> `src/scripts/node_coverage_check.sh`
- `src/scripts/npm_sonar.sh` -> `src/scripts/node_sonar.sh`
- `src/scripts/npm_sbom.sh` -> `src/scripts/node_sbom.sh`

**Commands:**
- `src/commands/npm_install.yml` -> `src/commands/node_install_deps.yml`
- `src/commands/npm_test.yml` -> `src/commands/node_test.yml`
- `src/commands/npm_lint.yml` -> `src/commands/node_lint.yml`
- `src/commands/npm_audit.yml` -> `src/commands/node_audit.yml`
- `src/commands/npm_coverage_check.yml` -> `src/commands/node_coverage_check.yml`
- `src/commands/npm_sonar.yml` -> `src/commands/node_sonar.yml`
- `src/commands/npm_sbom.yml` -> `src/commands/node_sbom.yml`
- `src/commands/restore_npm_cache.yml` -> `src/commands/restore_node_cache.yml`
- `src/commands/save_npm_cache.yml` -> `src/commands/save_node_cache.yml`

**Jobs:**
- `src/jobs/npm_build_and_test.yml` -> `src/jobs/node_build_and_test.yml`
- `src/jobs/npm_code_quality.yml` -> `src/jobs/node_code_quality.yml`
- `src/jobs/npm_coverage.yml` -> `src/jobs/node_coverage.yml`
- `src/jobs/npm_security_scan.yml` -> `src/jobs/node_security_scan.yml`
- `src/jobs/npm_e2e_test.yml` -> `src/jobs/node_e2e_test.yml`
- `src/jobs/npm_sonar_scan.yml` -> `src/jobs/node_sonar_scan.yml`
- `src/jobs/npm_sbom.yml` -> `src/jobs/node_sbom.yml`

**NOT renamed (npm-specific):**
- `src/scripts/npm_auth.sh` - stays
- `src/commands/npm_auth.yml` - stays

### Modified (content changes, no rename)

- `src/scripts/install_node.sh` - add corepack activation
- `src/scripts/run_test_setup.sh` - add inline command support
- `src/scripts/generate_dockerfile.sh` - add pnpm Dockerfile variants
- `src/scripts/templates/node-webapp.yml.tpl` - rename refs + add package_manager param
- `src/scripts/templates/node-api.yml.tpl` - rename refs + add package_manager param
- `src/scripts/templates/partials/node-webapp-deploy.yml.tpl` - rename refs + add package_manager param
- `src/scripts/templates/partials/node-api-deploy.yml.tpl` - rename refs + add package_manager param
- `src/scripts/packed_generate_config.sh` - regenerated
- `src/scripts/packed_generate_dockerfile.sh` - regenerated
- `tests/test_generate_config.sh` - update assertions + add pnpm tests
- `tests/test_scripts.sh` - update script refs + add pnpm tests
- `tests/test_extract_munitor_vars.sh` - add pnpm fixture
- `CONTRIBUTING.md` - update job name reference

### New files

- `tests/fixtures/pnpm-webapp.munitor.yml` - test fixture for pnpm config

---

## Phase 1: Mechanical Rename

### Task 1: Create feature branch

**Files:** None

- [ ] **Step 1: Create branch from develop**

```bash
cd /Users/james.maes/Git.Local/Kof22/Munitor
git checkout develop
git pull origin develop
git checkout -b feature/GH-5-pnpm-support
```

- [ ] **Step 2: Verify clean state**

```bash
git status
```

Expected: clean working tree on `feature/GH-5-pnpm-support`

---

### Task 2: Rename script files

**Files:**
- Rename: `src/scripts/npm_install.sh` -> `src/scripts/node_install_deps.sh`
- Rename: `src/scripts/npm_test.sh` -> `src/scripts/node_test.sh`
- Rename: `src/scripts/npm_lint.sh` -> `src/scripts/node_lint.sh`
- Rename: `src/scripts/npm_audit.sh` -> `src/scripts/node_audit.sh`
- Rename: `src/scripts/npm_coverage_check.sh` -> `src/scripts/node_coverage_check.sh`
- Rename: `src/scripts/npm_sonar.sh` -> `src/scripts/node_sonar.sh`
- Rename: `src/scripts/npm_sbom.sh` -> `src/scripts/node_sbom.sh`

- [ ] **Step 1: Rename all script files**

```bash
cd /Users/james.maes/Git.Local/Kof22/Munitor
git mv src/scripts/npm_install.sh src/scripts/node_install_deps.sh
git mv src/scripts/npm_test.sh src/scripts/node_test.sh
git mv src/scripts/npm_lint.sh src/scripts/node_lint.sh
git mv src/scripts/npm_audit.sh src/scripts/node_audit.sh
git mv src/scripts/npm_coverage_check.sh src/scripts/node_coverage_check.sh
git mv src/scripts/npm_sonar.sh src/scripts/node_sonar.sh
git mv src/scripts/npm_sbom.sh src/scripts/node_sbom.sh
```

- [ ] **Step 2: Update munitor_header calls inside each renamed script**

In each renamed script, update the `munitor_header` call to match the new name. For example, in `node_install_deps.sh`:

```bash
# Change:
munitor_header "npm_install"
# To:
munitor_header "node_install_deps"
```

Apply the same pattern to all 7 renamed scripts:
- `node_install_deps.sh`: `munitor_header "node_install_deps"`
- `node_test.sh`: `munitor_header "node_test"`
- `node_lint.sh`: `munitor_header "node_lint"`
- `node_audit.sh`: `munitor_header "node_audit"`
- `node_coverage_check.sh`: `munitor_header "node_coverage_check"`
- `node_sonar.sh`: `munitor_header "node_sonar"`
- `node_sbom.sh`: `munitor_header "node_sbom"`

- [ ] **Step 3: Verify shellcheck passes on renamed scripts**

```bash
shellcheck --severity=warning src/scripts/node_install_deps.sh src/scripts/node_test.sh src/scripts/node_lint.sh src/scripts/node_audit.sh src/scripts/node_coverage_check.sh src/scripts/node_sonar.sh src/scripts/node_sbom.sh
```

Expected: no warnings

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: rename npm_* scripts to node_*"
```

---

### Task 3: Rename command files and update script references

**Files:**
- Rename: all 9 command files (see File Map above)
- Modify: each renamed command file's `<< include() >>` directive and `name:` field

- [ ] **Step 1: Rename all command files**

```bash
cd /Users/james.maes/Git.Local/Kof22/Munitor
git mv src/commands/npm_install.yml src/commands/node_install_deps.yml
git mv src/commands/npm_test.yml src/commands/node_test.yml
git mv src/commands/npm_lint.yml src/commands/node_lint.yml
git mv src/commands/npm_audit.yml src/commands/node_audit.yml
git mv src/commands/npm_coverage_check.yml src/commands/node_coverage_check.yml
git mv src/commands/npm_sonar.yml src/commands/node_sonar.yml
git mv src/commands/npm_sbom.yml src/commands/node_sbom.yml
git mv src/commands/restore_npm_cache.yml src/commands/restore_node_cache.yml
git mv src/commands/save_npm_cache.yml src/commands/save_node_cache.yml
```

- [ ] **Step 2: Update include paths in renamed command files**

Each command file uses `<< include(scripts/npm_*.sh) >>`. Update to reference the new script names:

`src/commands/node_install_deps.yml`:
```yaml
description: >
  Install project dependencies using the configured package manager.
steps:
  - run:
      name: Install dependencies
      command: << include(scripts/node_install_deps.sh) >>
```

`src/commands/node_test.yml`:
```yaml
description: >
  Run tests with CI flags, coverage, and JUnit reporter. Supports custom
  test commands via JSON array or falls back to package manager defaults.
parameters:
  test_commands:
    type: string
    default: ""
    description: JSON array of custom test commands to run instead of defaults.
steps:
  - run:
      name: Run tests
      environment:
        MUNITOR_TEST_COMMANDS_JSON: << parameters.test_commands >>
      command: << include(scripts/node_test.sh) >>
  - store_test_results:
      path: reports/junit
  - store_artifacts:
      path: reports/junit
      destination: test-results
  - store_artifacts:
      path: coverage
      destination: coverage
```

`src/commands/node_lint.yml`:
```yaml
description: >
  Run ESLint on the project source.
steps:
  - run:
      name: ESLint
      command: << include(scripts/node_lint.sh) >>
```

`src/commands/node_audit.yml`:
```yaml
description: >
  Run npm audit to check for known vulnerabilities in dependencies.
steps:
  - run:
      name: Security audit
      command: << include(scripts/node_audit.sh) >>
```

`src/commands/node_coverage_check.yml`:
```yaml
description: >
  Enforce minimum coverage threshold from coverage-summary.json.
  Supports Jest (default) and NYC coverage tools.
parameters:
  min_coverage:
    type: string
    default: "70"
    description: Minimum line coverage percentage.
  coverage_tool:
    type: string
    default: "jest"
    description: Coverage tool (jest or nyc).
  coverage_command:
    type: string
    default: ""
    description: Custom command to generate coverage report before threshold check.
steps:
  - run:
      name: Coverage threshold check
      environment:
        MIN_COVERAGE: << parameters.min_coverage >>
        MUNITOR_COVERAGE_TOOL: << parameters.coverage_tool >>
        MUNITOR_COVERAGE_COMMAND: << parameters.coverage_command >>
      command: << include(scripts/node_coverage_check.sh) >>
```

`src/commands/node_sonar.yml`:
```yaml
description: >
  Run SonarCloud analysis via sonar-scanner CLI for Node.js projects.
parameters:
  sonar_project_key:
    type: string
    description: SonarCloud project key.
  sonar_org:
    type: string
    default: KofTwentyTwo
    description: SonarCloud organization.
  sonar_token_env:
    type: env_var_name
    default: SONAR_TOKEN
    description: Environment variable containing the SonarCloud token.
steps:
  - run:
      name: SonarCloud analysis
      environment:
        SONAR_PROJECT_KEY: << parameters.sonar_project_key >>
        SONAR_ORG: << parameters.sonar_org >>
        SONAR_TOKEN_VAR: << parameters.sonar_token_env >>
      command: << include(scripts/node_sonar.sh) >>
```

`src/commands/node_sbom.yml`:
```yaml
description: >
  Generate a CycloneDX SBOM from a Node.js project.
steps:
  - run:
      name: Generate SBOM
      command: << include(scripts/node_sbom.sh) >>
```

`src/commands/restore_node_cache.yml` and `src/commands/save_node_cache.yml`: No include path changes needed (these use CircleCI native `restore_cache`/`save_cache`, not script includes). Update descriptions only:

`src/commands/restore_node_cache.yml`:
```yaml
description: >
  Restore the dependency cache based on lockfile checksum.
steps:
  - restore_cache:
      keys:
        - npm-v1-{{ checksum "package-lock.json" }}
        - npm-v1-
```

`src/commands/save_node_cache.yml`:
```yaml
description: >
  Save the dependency cache for future builds.
steps:
  - save_cache:
      key: npm-v1-{{ checksum "package-lock.json" }}
      paths:
        - ~/.npm
```

- [ ] **Step 3: Verify yamllint passes**

```bash
yamllint -c .yamllint src/commands/node_install_deps.yml src/commands/node_test.yml src/commands/node_lint.yml src/commands/node_audit.yml src/commands/node_coverage_check.yml src/commands/node_sonar.yml src/commands/node_sbom.yml src/commands/restore_node_cache.yml src/commands/save_node_cache.yml
```

Expected: no errors

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: rename npm_* commands to node_*"
```

---

### Task 4: Rename job files and update command references

**Files:**
- Rename: all 7 job files (see File Map above)
- Modify: each renamed job file's internal command references

- [ ] **Step 1: Rename all job files**

```bash
cd /Users/james.maes/Git.Local/Kof22/Munitor
git mv src/jobs/npm_build_and_test.yml src/jobs/node_build_and_test.yml
git mv src/jobs/npm_code_quality.yml src/jobs/node_code_quality.yml
git mv src/jobs/npm_coverage.yml src/jobs/node_coverage.yml
git mv src/jobs/npm_security_scan.yml src/jobs/node_security_scan.yml
git mv src/jobs/npm_e2e_test.yml src/jobs/node_e2e_test.yml
git mv src/jobs/npm_sonar_scan.yml src/jobs/node_sonar_scan.yml
git mv src/jobs/npm_sbom.yml src/jobs/node_sbom.yml
```

- [ ] **Step 2: Update command references in node_build_and_test.yml**

Replace command references inside `src/jobs/node_build_and_test.yml`:

```yaml
description: >
  Full Node.js build and test job. Installs Node.js, restores cache, runs
  dependency install, calculates version, tests with coverage, saves cache,
  and persists the workspace for downstream jobs.
parameters:
  node_version:
    type: string
    default: "20"
    description: Node.js major version to install.
  npm_auth:
    type: boolean
    default: false
    description: Configure private npm registry authentication before install.
  npm_scopes:
    type: string
    default: "[]"
    description: JSON array of additional npm scopes (e.g. '["@greatergoods"]').
  npm_default_scope:
    type: string
    default: "@koftwentytwo"
    description: Default npm scope for the organization.
  services:
    type: string
    default: ""
    description: JSON array of service container definitions to start before tests.
  test_setup:
    type: string
    default: ""
    description: Path to a setup script to run before tests.
  test_commands:
    type: string
    default: ""
    description: JSON array of custom test commands to run instead of defaults.
  resource_class:
    type: enum
    enum:
      - medium
      - large
      - xlarge
    default: large
    description: Machine resource class.
executor:
  name: machine
  resource_class: << parameters.resource_class >>
steps:
  - checkout
  - install_node:
      version: << parameters.node_version >>
  - when:
      condition: << parameters.npm_auth >>
      steps:
        - npm_auth:
            npm_scopes: << parameters.npm_scopes >>
            npm_default_scope: << parameters.npm_default_scope >>
  - restore_node_cache
  - node_install_deps
  - when:
      condition: << parameters.services >>
      steps:
        - start_services:
            services: << parameters.services >>
  - when:
      condition: << parameters.test_setup >>
      steps:
        - run_test_setup:
            test_setup: << parameters.test_setup >>
  - calculate_version
  - export_version_vars
  - run:
      name: Persist version metadata
      command: <<include(scripts/persist_version_metadata.sh)>>
  - node_test:
      test_commands: << parameters.test_commands >>
  - store_test_results:
      path: reports/junit
  - save_node_cache
  - persist_to_workspace:
      root: .
      paths:
        - "."
```

- [ ] **Step 3: Update command references in remaining job files**

`src/jobs/node_code_quality.yml`: Change `- npm_lint` to `- node_lint`

`src/jobs/node_coverage.yml`: Change `npm_coverage_check` to `node_coverage_check` (3 occurrences in the parameters pass-through)

`src/jobs/node_security_scan.yml`: Change `- npm_audit` to `- node_audit`

`src/jobs/node_sonar_scan.yml`: Change `- npm_sonar:` to `- node_sonar:`

`src/jobs/node_sbom.yml`: Change `- npm_sbom` to `- node_sbom`

- [ ] **Step 4: Verify yamllint passes on all renamed jobs**

```bash
yamllint -c .yamllint src/jobs/node_build_and_test.yml src/jobs/node_code_quality.yml src/jobs/node_coverage.yml src/jobs/node_security_scan.yml src/jobs/node_e2e_test.yml src/jobs/node_sonar_scan.yml src/jobs/node_sbom.yml
```

Expected: no errors

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: rename npm_* jobs to node_*"
```

---

### Task 5: Update templates to use new names

**Files:**
- Modify: `src/scripts/templates/node-webapp.yml.tpl`
- Modify: `src/scripts/templates/node-api.yml.tpl`
- Modify: `src/scripts/templates/partials/node-webapp-deploy.yml.tpl`
- Modify: `src/scripts/templates/partials/node-api-deploy.yml.tpl`

- [ ] **Step 1: Replace all `munitor/npm_` references with `munitor/node_` in templates**

In all 4 template files, perform these replacements:

| Old | New |
|---|---|
| `munitor/npm_build_and_test` | `munitor/node_build_and_test` |
| `munitor/npm_code_quality` | `munitor/node_code_quality` |
| `munitor/npm_coverage` | `munitor/node_coverage` |
| `munitor/npm_security_scan` | `munitor/node_security_scan` |
| `munitor/npm_e2e_test` | `munitor/node_e2e_test` |
| `munitor/npm_sonar_scan` | `munitor/node_sonar_scan` |
| `munitor/npm_sbom` | `munitor/node_sbom` |

Do NOT change `npm_auth`, `npm_scopes`, or `npm_default_scope` (these are npm-specific and stay).

- [ ] **Step 2: Verify no stale `munitor/npm_` references remain (excluding npm_auth)**

```bash
grep -r 'munitor/npm_' src/scripts/templates/ | grep -v npm_auth
```

Expected: no output

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "refactor: update templates to use node_* job names"
```

---

### Task 6: Update tests for rename

**Files:**
- Modify: `tests/test_generate_config.sh`
- Modify: `tests/test_scripts.sh`

- [ ] **Step 1: Update test_generate_config.sh**

Replace all `npm_build_and_test` with `node_build_and_test`, `npm_code_quality` with `node_code_quality`, `npm_coverage` with `node_coverage`, `npm_security_scan` with `node_security_scan`, `npm_e2e_test` with `node_e2e_test`, `npm_sonar_scan` with `node_sonar_scan`, `npm_sbom` with `node_sbom` in test assertions and descriptions.

Also update test descriptions like `"uses npm_sonar_scan"` to `"uses node_sonar_scan"`.

Do NOT change references to `npm_auth` or `npm_scopes` or `npm_default_scope`.

- [ ] **Step 2: Update test_scripts.sh**

Replace references to old script file names:
- `npm_coverage_check.sh` -> `node_coverage_check.sh`
- Any other `npm_*.sh` references -> corresponding `node_*.sh`

- [ ] **Step 3: Update CONTRIBUTING.md**

Replace the reference to `munitor/npm_build_and_test` with `munitor/node_build_and_test`.

- [ ] **Step 4: Regenerate packed scripts and validate**

```bash
make pack-scripts
make all
```

Expected: all lint, validation, and tests pass.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: update tests and docs for node_* rename"
```

---

## Phase 2: Package Manager Support

### Task 7: Add corepack activation to install_node.sh

**Files:**
- Modify: `src/scripts/install_node.sh`
- Modify: `src/commands/install_node.yml`

- [ ] **Step 1: Add package_manager parameter to install_node.yml**

```yaml
description: >
  Install the specified Node.js version using nvm (pre-installed on CircleCI ubuntu-2204).
  Activates corepack for non-npm package managers.
parameters:
  version:
    type: string
    default: "20"
    description: Node.js major version to install (e.g., 20, 22).
  package_manager:
    type: string
    default: "npm"
    description: Package manager to activate (npm, pnpm, yarn).
steps:
  - run:
      name: Install Node.js << parameters.version >>
      environment:
        NODE_VERSION: << parameters.version >>
        MUNITOR_PACKAGE_MANAGER: << parameters.package_manager >>
      command: << include(scripts/install_node.sh) >>
```

- [ ] **Step 2: Add corepack activation to install_node.sh**

After the existing `echo "=== Node Environment ==="` block and before the `.nvmrc` warning, add:

```bash
# Activate non-npm package managers via corepack
PACKAGE_MANAGER="${MUNITOR_PACKAGE_MANAGER:-npm}"
if [[ "${PACKAGE_MANAGER}" != "npm" ]]; then
  echo ""
  echo "=== Activating ${PACKAGE_MANAGER} via corepack ==="
  corepack enable

  # Detect version: packageManager field (corepack-native) > engines field > latest
  PM_VERSION=""
  if [[ -f "package.json" ]]; then
    # Check packageManager field first (e.g., "pnpm@9.15.9")
    PM_FIELD=$(node -e "try{const p=require('./package.json').packageManager||'';console.log(p)}catch{console.log('')}" 2>/dev/null)
    if [[ "${PM_FIELD}" == "${PACKAGE_MANAGER}@"* ]]; then
      PM_VERSION="${PM_FIELD#*@}"
    fi

    # Fall back to engines field (e.g., "engines": {"pnpm": ">=9"})
    if [[ -z "${PM_VERSION}" ]]; then
      PM_VERSION=$(node -e "try{console.log(require('./package.json').engines?.['${PACKAGE_MANAGER}']||'')}catch{console.log('')}" 2>/dev/null)
    fi
  fi

  if [[ -n "${PM_VERSION}" ]]; then
    echo "  Detected version: ${PM_VERSION}"
    corepack prepare "${PACKAGE_MANAGER}@${PM_VERSION}" --activate
  else
    echo "  No version constraint found, using corepack default"
  fi

  echo "  ${PACKAGE_MANAGER}: $(${PACKAGE_MANAGER} --version)"

  # Export PM binary to BASH_ENV for downstream steps
  PM_BIN_DIR="$(dirname "$(command -v "${PACKAGE_MANAGER}")")"
  if [[ "${PM_BIN_DIR}" != "${NODE_BIN_DIR}" ]]; then
    echo "export PATH=\"${PM_BIN_DIR}:\${PATH}\"" >> "${BASH_ENV}"
    echo "  BASH_ENV: exported PATH with ${PM_BIN_DIR}"
  fi
fi
```

- [ ] **Step 3: Verify shellcheck passes**

```bash
shellcheck --severity=warning src/scripts/install_node.sh
```

Expected: no warnings

- [ ] **Step 4: Commit**

```bash
git add src/scripts/install_node.sh src/commands/install_node.yml
git commit -m "feat: activate corepack for pnpm/yarn in install_node"
```

---

### Task 8: Make node_install_deps.sh package-manager-aware

**Files:**
- Modify: `src/scripts/node_install_deps.sh`
- Modify: `src/commands/node_install_deps.yml`

- [ ] **Step 1: Add package_manager parameter to node_install_deps.yml**

```yaml
description: >
  Install project dependencies using the configured package manager.
parameters:
  package_manager:
    type: string
    default: "npm"
    description: Package manager to use (npm, pnpm, yarn).
steps:
  - run:
      name: Install dependencies
      environment:
        MUNITOR_PACKAGE_MANAGER: << parameters.package_manager >>
      command: << include(scripts/node_install_deps.sh) >>
```

- [ ] **Step 2: Rewrite node_install_deps.sh with PM branching**

Replace the entire content of `src/scripts/node_install_deps.sh`:

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

PACKAGE_MANAGER="${MUNITOR_PACKAGE_MANAGER:-npm}"

munitor_header "node_install_deps (${PACKAGE_MANAGER})"
munitor_check_tool node --version

case "${PACKAGE_MANAGER}" in
  npm)
    munitor_check_tool npm --version

    if [[ ! -f "package-lock.json" ]]; then
      echo "ERROR: package-lock.json not found in $(pwd)"
      echo "  npm ci requires a lockfile. Run 'npm install' locally and commit the lockfile."
      exit 1
    fi

    LOCKFILE_VERSION=$(node -e "console.log(require('./package-lock.json').lockfileVersion || 'unknown')" 2>/dev/null || echo "unknown")
    NPM_MAJOR=$(npm --version 2>/dev/null | cut -d. -f1)
    echo "  lockfileVersion: ${LOCKFILE_VERSION}"

    if [[ "${LOCKFILE_VERSION}" == "3" && -n "${NPM_MAJOR}" && "${NPM_MAJOR}" -lt 11 ]]; then
      echo ""
      echo "WARNING: package-lock.json uses lockfileVersion 3 (npm 11+)"
      echo "  but CI is running npm ${NPM_MAJOR} ($(npm --version))."
      echo "  This will likely cause 'npm ci' to fail."
      echo ""
      echo "  Fix: regenerate your lockfile with the same Node version CI uses."
      echo "  Add an .nvmrc to your repo to keep local and CI versions in sync."
      echo ""
    fi

    echo ""
    echo "Running npm ci..."
    npm ci

    PKG_COUNT=$(find node_modules -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
    echo "npm ci complete. ${PKG_COUNT} packages installed."
    ;;

  pnpm)
    munitor_check_tool pnpm --version

    if [[ ! -f "pnpm-lock.yaml" ]]; then
      echo "ERROR: pnpm-lock.yaml not found in $(pwd)"
      echo "  pnpm install --frozen-lockfile requires a lockfile."
      echo "  Run 'pnpm install' locally and commit pnpm-lock.yaml."
      exit 1
    fi

    echo ""
    echo "Running pnpm install --frozen-lockfile..."
    pnpm install --frozen-lockfile

    echo "pnpm install complete."
    ;;

  *)
    echo "ERROR: Unsupported package manager '${PACKAGE_MANAGER}'."
    echo "  Supported values: npm, pnpm"
    exit 1
    ;;
esac

# Prisma auto-detection: generate client if schema files exist
PRISMA_SCHEMAS=$(find . -path "*/prisma/schema.prisma" \
  -not -path "*/node_modules/*" \
  -not -path "*/dist/*" \
  -not -path "*/build/*" \
  2>/dev/null || true)

if [[ -n "${PRISMA_SCHEMAS}" ]]; then
  echo ""
  echo "=== Prisma Auto-Detection ==="

  # Check if prisma CLI is available
  PRISMA_EXEC=""
  case "${PACKAGE_MANAGER}" in
    npm)  command -v npx &>/dev/null && npx prisma --version &>/dev/null 2>&1 && PRISMA_EXEC="npx prisma" ;;
    pnpm) pnpm exec prisma --version &>/dev/null 2>&1 && PRISMA_EXEC="pnpm exec prisma" ;;
  esac

  if [[ -z "${PRISMA_EXEC}" ]]; then
    echo "WARNING: Found Prisma schema(s) but prisma is not in dependencies. Skipping generate."
    echo "  Install prisma as a dev dependency to enable auto-generation."
  else
    while IFS= read -r schema; do
      echo "  Generating client for: ${schema}"
      ${PRISMA_EXEC} generate --schema="${schema}"
    done <<< "${PRISMA_SCHEMAS}"
    echo "Prisma client generation complete."
  fi
fi
```

- [ ] **Step 3: Verify shellcheck passes**

```bash
shellcheck --severity=warning src/scripts/node_install_deps.sh
```

Expected: no warnings

- [ ] **Step 4: Commit**

```bash
git add src/scripts/node_install_deps.sh src/commands/node_install_deps.yml
git commit -m "feat: make node_install_deps package-manager-aware with Prisma detection"
```

---

### Task 9: Make node_test.sh package-manager-aware

**Files:**
- Modify: `src/scripts/node_test.sh`
- Modify: `src/commands/node_test.yml`

- [ ] **Step 1: Add package_manager parameter to node_test.yml**

```yaml
description: >
  Run tests with CI flags, coverage, and JUnit reporter. Supports custom
  test commands via JSON array or falls back to package manager defaults.
parameters:
  test_commands:
    type: string
    default: ""
    description: JSON array of custom test commands to run instead of defaults.
  package_manager:
    type: string
    default: "npm"
    description: Package manager (npm, pnpm, yarn).
steps:
  - run:
      name: Run tests
      environment:
        MUNITOR_TEST_COMMANDS_JSON: << parameters.test_commands >>
        MUNITOR_PACKAGE_MANAGER: << parameters.package_manager >>
      command: << include(scripts/node_test.sh) >>
  - store_test_results:
      path: reports/junit
  - store_artifacts:
      path: reports/junit
      destination: test-results
  - store_artifacts:
      path: coverage
      destination: coverage
```

- [ ] **Step 2: Update the default fallback in node_test.sh**

Replace the `else` block (lines 36-69 of the original) that hardcodes `npx jest`:

```bash
else
  PACKAGE_MANAGER="${MUNITOR_PACKAGE_MANAGER:-npm}"

  case "${PACKAGE_MANAGER}" in
    pnpm)
      echo "Running pnpm test..."
      pnpm test
      echo "pnpm test complete."
      ;;
    *)
      # Default: Jest with coverage and JUnit reporter
      if ! npx jest --version &>/dev/null; then
        echo ""
        echo "ERROR: Jest is not installed and no custom test commands are configured."
        echo ""
        echo "  Munitor defaults to 'npx jest' but this project doesn't have Jest."
        echo "  Add custom test commands to your .munitor.yml:"
        echo ""
        echo "    test:"
        echo "      commands:"
        echo "        - \"npm test\""
        echo ""
        echo "  Or install Jest: npm install --save-dev jest"
        echo ""
        exit 1
      fi

      echo "Running Jest tests..."

      export JEST_JUNIT_OUTPUT_DIR="reports/junit"
      export JEST_JUNIT_OUTPUT_NAME="results.xml"

      npx jest \
        --ci \
        --forceExit \
        --coverage \
        --coverageReporters=json-summary \
        --coverageReporters=lcov \
        --reporters=default \
        --reporters=jest-junit

      echo "Jest tests complete."
      ;;
  esac
fi
```

- [ ] **Step 3: Verify shellcheck passes**

```bash
shellcheck --severity=warning src/scripts/node_test.sh
```

- [ ] **Step 4: Commit**

```bash
git add src/scripts/node_test.sh src/commands/node_test.yml
git commit -m "feat: make node_test package-manager-aware"
```

---

### Task 10: Make cache commands package-manager-aware

**Files:**
- Modify: `src/commands/restore_node_cache.yml`
- Modify: `src/commands/save_node_cache.yml`

- [ ] **Step 1: Rewrite restore_node_cache.yml with PM conditions**

```yaml
description: >
  Restore the dependency cache based on lockfile checksum.
parameters:
  package_manager:
    type: string
    default: "npm"
    description: Package manager (npm, pnpm, yarn).
steps:
  - when:
      condition:
        equal: ["npm", << parameters.package_manager >>]
      steps:
        - restore_cache:
            keys:
              - npm-v1-{{ checksum "package-lock.json" }}
              - npm-v1-
  - when:
      condition:
        equal: ["pnpm", << parameters.package_manager >>]
      steps:
        - restore_cache:
            keys:
              - pnpm-v1-{{ checksum "pnpm-lock.yaml" }}
              - pnpm-v1-
```

- [ ] **Step 2: Rewrite save_node_cache.yml with PM conditions**

```yaml
description: >
  Save the dependency cache for future builds.
parameters:
  package_manager:
    type: string
    default: "npm"
    description: Package manager (npm, pnpm, yarn).
steps:
  - when:
      condition:
        equal: ["npm", << parameters.package_manager >>]
      steps:
        - save_cache:
            key: npm-v1-{{ checksum "package-lock.json" }}
            paths:
              - ~/.npm
  - when:
      condition:
        equal: ["pnpm", << parameters.package_manager >>]
      steps:
        - save_cache:
            key: pnpm-v1-{{ checksum "pnpm-lock.yaml" }}
            paths:
              - ~/.local/share/pnpm/store
```

- [ ] **Step 3: Verify yamllint passes**

```bash
yamllint -c .yamllint src/commands/restore_node_cache.yml src/commands/save_node_cache.yml
```

- [ ] **Step 4: Commit**

```bash
git add src/commands/restore_node_cache.yml src/commands/save_node_cache.yml
git commit -m "feat: make cache commands package-manager-aware"
```

---

### Task 11: Thread package_manager through node_build_and_test job

**Files:**
- Modify: `src/jobs/node_build_and_test.yml`

- [ ] **Step 1: Add package_manager parameter and pass to commands**

Add the parameter to the job's `parameters:` block:

```yaml
  package_manager:
    type: string
    default: "npm"
    description: Package manager to use (npm, pnpm, yarn).
```

Update the steps to pass it through:

```yaml
steps:
  - checkout
  - install_node:
      version: << parameters.node_version >>
      package_manager: << parameters.package_manager >>
  - when:
      condition: << parameters.npm_auth >>
      steps:
        - npm_auth:
            npm_scopes: << parameters.npm_scopes >>
            npm_default_scope: << parameters.npm_default_scope >>
  - restore_node_cache:
      package_manager: << parameters.package_manager >>
  - node_install_deps:
      package_manager: << parameters.package_manager >>
  - when:
      condition: << parameters.services >>
      steps:
        - start_services:
            services: << parameters.services >>
  - when:
      condition: << parameters.test_setup >>
      steps:
        - run_test_setup:
            test_setup: << parameters.test_setup >>
  - calculate_version
  - export_version_vars
  - run:
      name: Persist version metadata
      command: <<include(scripts/persist_version_metadata.sh)>>
  - node_test:
      test_commands: << parameters.test_commands >>
      package_manager: << parameters.package_manager >>
  - store_test_results:
      path: reports/junit
  - save_node_cache:
      package_manager: << parameters.package_manager >>
  - persist_to_workspace:
      root: .
      paths:
        - "."
```

- [ ] **Step 2: Verify yamllint passes**

```bash
yamllint -c .yamllint src/jobs/node_build_and_test.yml
```

- [ ] **Step 3: Commit**

```bash
git add src/jobs/node_build_and_test.yml
git commit -m "feat: thread package_manager through node_build_and_test job"
```

---

### Task 12: Add package_manager to templates

**Files:**
- Modify: `src/scripts/templates/node-webapp.yml.tpl`
- Modify: `src/scripts/templates/node-api.yml.tpl`
- Modify: `src/scripts/templates/partials/node-webapp-deploy.yml.tpl`
- Modify: `src/scripts/templates/partials/node-api-deploy.yml.tpl`

- [ ] **Step 1: Add package_manager to every node_build_and_test invocation**

In all 4 template files, add `package_manager: "${MUNITOR_PACKAGE_MANAGER}"` to every `munitor/node_build_and_test:` block. Place it after the `node_version:` line:

```yaml
      - munitor/node_build_and_test:
          name: build-and-test
          node_version: "${MUNITOR_NODE_VERSION}"
          package_manager: "${MUNITOR_PACKAGE_MANAGER}"
```

There are multiple `node_build_and_test` invocations per template (pr-checks, release-candidate, production workflows). Add it to ALL of them.

- [ ] **Step 2: Verify no node_build_and_test invocation is missing package_manager**

```bash
grep -A2 'node_build_and_test:' src/scripts/templates/*.tpl src/scripts/templates/partials/*.tpl | grep -v package_manager | grep 'node_version'
```

Expected: no output (every invocation with node_version should also have package_manager)

- [ ] **Step 3: Commit**

```bash
git add src/scripts/templates/
git commit -m "feat: pass package_manager to node_build_and_test in all templates"
```

---

## Phase 3: Supplemental Features

### Task 13: Fix run_test_setup.sh to support inline commands

**Files:**
- Modify: `src/scripts/run_test_setup.sh`

- [ ] **Step 1: Update run_test_setup.sh**

Replace the file-only logic with file-or-inline:

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

munitor_header "run_test_setup"

SETUP_SCRIPT="${MUNITOR_TEST_SETUP_SCRIPT:-}"

if [[ -z "${SETUP_SCRIPT}" ]]; then
  echo "No test setup configured."
  exit 0
fi

if [[ -f "${SETUP_SCRIPT}" ]]; then
  echo "Running test setup script: ${SETUP_SCRIPT}"
  chmod +x "${SETUP_SCRIPT}"
  "${SETUP_SCRIPT}"
else
  echo "Running test setup command: ${SETUP_SCRIPT}"
  bash -c "${SETUP_SCRIPT}"
fi

echo "Test setup complete."
```

- [ ] **Step 2: Verify shellcheck passes**

```bash
shellcheck --severity=warning src/scripts/run_test_setup.sh
```

- [ ] **Step 3: Commit**

```bash
git add src/scripts/run_test_setup.sh
git commit -m "feat: support inline commands in test.setup"
```

---

### Task 14: Add pnpm support to Dockerfile generation

**Files:**
- Modify: `src/scripts/generate_dockerfile.sh`

- [ ] **Step 1: Add pnpm Dockerfile variants for node-api**

In `generate_dockerfile.sh`, the `node-api)` case has sub-cases for `nextjs` and `express`. Each needs a pnpm variant. Wrap each existing Dockerfile heredoc in a `case "${MUNITOR_PACKAGE_MANAGER}"` block.

For the **nextjs** sub-case (around line 42-76), replace the Dockerfile heredoc:

```bash
      nextjs)
        case "${MUNITOR_PACKAGE_MANAGER}" in
          pnpm)
            cat > Dockerfile <<DOCKERFILE
FROM node:${MUNITOR_NODE_VERSION}-alpine AS deps
WORKDIR /app
RUN corepack enable
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

FROM node:${MUNITOR_NODE_VERSION}-alpine AS builder
WORKDIR /app
RUN corepack enable
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV STANDALONE=true
ARG GIT_COMMIT_SHA
ENV GIT_COMMIT_SHA=\${GIT_COMMIT_SHA}
RUN pnpm run build

FROM node:${MUNITOR_NODE_VERSION}-alpine AS runner
WORKDIR /app
RUN apk update && apk upgrade --no-cache && rm -rf /var/cache/apk/*
RUN npm cache clean --force && rm -rf /usr/local/lib/node_modules /usr/local/bin/npm /usr/local/bin/npx
RUN addgroup --system --gid 1001 nodejs \\
 && adduser --system --uid 1001 nextjs
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
USER nextjs
EXPOSE 3000
ENV PORT=3000
CMD ["node", "server.js"]
DOCKERFILE
            ;;
          *)
            # existing npm Dockerfile -- keep current heredoc unchanged
            ;
            ;;
        esac
        ;;
```

Apply the same pattern to the **express** sub-case and the **node-webapp** case (around line 199-220).

For express pnpm variant:
```dockerfile
FROM node:${MUNITOR_NODE_VERSION}-alpine AS deps
WORKDIR /app
RUN corepack enable
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile --prod

FROM node:${MUNITOR_NODE_VERSION}-alpine AS runner
WORKDIR /app
RUN apk update && apk upgrade --no-cache && rm -rf /var/cache/apk/*
RUN npm cache clean --force && rm -rf /usr/local/lib/node_modules /usr/local/bin/npm /usr/local/bin/npx
RUN addgroup --system --gid 1001 nodejs \
 && adduser --system --uid 1001 appuser -G nodejs
COPY --from=deps /app/node_modules ./node_modules
COPY . .
USER appuser
EXPOSE ${MUNITOR_HEALTH_PORT}
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:${MUNITOR_HEALTH_PORT}${MUNITOR_HEALTH_PATH} || exit 1
CMD ["node", "."]
```

For node-webapp pnpm variant:
```dockerfile
FROM node:${MUNITOR_NODE_VERSION}-alpine AS builder
WORKDIR /app
RUN corepack enable
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile
COPY . .
ARG GIT_COMMIT_SHA
ENV GIT_COMMIT_SHA=\${GIT_COMMIT_SHA}
RUN pnpm run build

FROM gcr.io/distroless/nodejs${MUNITOR_NODE_VERSION}-debian12 AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public
EXPOSE ${MUNITOR_HEALTH_PORT}
CMD ["server.js"]
```

- [ ] **Step 2: Verify shellcheck passes**

```bash
shellcheck --severity=warning src/scripts/generate_dockerfile.sh
```

- [ ] **Step 3: Commit**

```bash
git add src/scripts/generate_dockerfile.sh
git commit -m "feat: add pnpm Dockerfile variants for node pipelines"
```

---

### Task 15: Add pnpm test fixture and tests

**Files:**
- Create: `tests/fixtures/pnpm-webapp.munitor.yml`
- Modify: `tests/test_generate_config.sh`
- Modify: `tests/test_scripts.sh`
- Modify: `tests/test_extract_munitor_vars.sh`

- [ ] **Step 1: Create pnpm test fixture**

```yaml
pipeline: node-webapp
package_manager: pnpm
node_version: "22"
image_name: ghcr.io/koftwentytwo/pnpm-app
docker:
  registry: ghcr.io/koftwentytwo
health:
  path: /api/health
  port: "3000"
```

Save to `tests/fixtures/pnpm-webapp.munitor.yml`.

- [ ] **Step 2: Add pnpm config generation test to test_generate_config.sh**

Add a new test section after the existing node-webapp tests:

```bash
# ============================================================
# pnpm node-webapp
# ============================================================
echo ""
echo "=== pnpm node-webapp tests ==="

run_test "pnpm-webapp: uses node_build_and_test" \
  "tests/fixtures/pnpm-webapp.munitor.yml" \
  "node_build_and_test"

run_test "pnpm-webapp: passes package_manager param" \
  "tests/fixtures/pnpm-webapp.munitor.yml" \
  'package_manager: "pnpm"'

run_negative_test "pnpm-webapp: does not reference npm_build_and_test" \
  "tests/fixtures/pnpm-webapp.munitor.yml" \
  "npm_build_and_test"
```

- [ ] **Step 3: Add pnpm extract_munitor_vars test**

Add to `tests/test_extract_munitor_vars.sh` after existing package_manager tests:

```bash
echo -n "  TEST: pnpm package_manager is extracted... "
source "${SRC_SCRIPTS}/extract_munitor_vars.sh"
extract_munitor_vars "tests/fixtures/pnpm-webapp.munitor.yml"
assert_eq "package_manager pnpm" "pnpm" "${MUNITOR_PACKAGE_MANAGER}"
```

- [ ] **Step 4: Add pnpm script structure tests to test_scripts.sh**

Add tests verifying the pnpm branching exists in the new scripts:

```bash
echo ""
echo "=== node_install_deps.sh pnpm support ==="

echo -n "  TEST: node_install_deps.sh handles pnpm case... "
if grep -q 'pnpm install --frozen-lockfile' "${SRC_SCRIPTS}/node_install_deps.sh"; then
  pass
else
  fail "missing pnpm install --frozen-lockfile"
fi

echo -n "  TEST: node_install_deps.sh has Prisma auto-detection... "
if grep -q 'prisma/schema.prisma' "${SRC_SCRIPTS}/node_install_deps.sh"; then
  pass
else
  fail "missing Prisma auto-detection"
fi

echo -n "  TEST: node_test.sh handles pnpm fallback... "
if grep -q 'pnpm test' "${SRC_SCRIPTS}/node_test.sh"; then
  pass
else
  fail "missing pnpm test fallback"
fi
```

- [ ] **Step 5: Run tests**

```bash
make test-scripts test-templates
```

Expected: all tests pass

- [ ] **Step 6: Commit**

```bash
git add tests/
git commit -m "test: add pnpm fixture and tests for package manager support"
```

---

### Task 16: Regenerate packed scripts and full validation

**Files:**
- Regenerate: `src/scripts/packed_generate_config.sh`
- Regenerate: `src/scripts/packed_generate_dockerfile.sh`

- [ ] **Step 1: Regenerate packed scripts**

```bash
make pack-scripts
```

- [ ] **Step 2: Run full validation**

```bash
make all
```

Expected: all lint, validation, and tests pass.

- [ ] **Step 3: Verify orb packs cleanly**

```bash
make pack validate
```

Expected: `Orb validation passed.`

- [ ] **Step 4: Commit packed scripts**

```bash
git add src/scripts/packed_generate_config.sh src/scripts/packed_generate_dockerfile.sh orb.yml
git commit -m "chore: regenerate packed scripts for node_* rename and pnpm support"
```

---

### Task 17: Final cleanup and PR preparation

**Files:** None new

- [ ] **Step 1: Verify no stale npm_ references remain (except npm_auth)**

```bash
grep -r 'npm_build_and_test\|npm_code_quality\|npm_coverage\b\|npm_security_scan\|npm_e2e_test\|npm_sonar_scan\|npm_sbom\b\|npm_install\b\|npm_test\b\|npm_lint\b\|npm_audit\b\|npm_coverage_check\|restore_npm_cache\|save_npm_cache' src/ tests/ --include='*.yml' --include='*.tpl' --include='*.sh' | grep -v 'packed_generate' | grep -v npm_auth
```

Expected: no output (packed scripts are regenerated so they pick up changes automatically)

- [ ] **Step 2: Run make all one final time**

```bash
make all
```

Expected: all pass

- [ ] **Step 3: Push and create PR**

```bash
git push -u origin feature/GH-5-pnpm-support
```

Create PR targeting `develop` with title: `feat: first-class pnpm support (#5)` and body referencing the issue and spec.
