# Spec: First-Class Package Manager Support (Issue #5)

## Goal

Make `package_manager` a first-class config in Munitor that drives behavior across the full Node.js lifecycle: dependency install, test execution, caching, Dockerfile generation, and post-install hooks (Prisma). Rename all `npm_*` orb jobs/commands to `node_*` to reflect multi-PM support. Release as v0.3.0.

## Context

`MUNITOR_PACKAGE_MANAGER` is parsed from `.munitor.yml` and available at config-generation time via envsubst, but no runtime script uses it. All scripts hardcode npm commands. Projects using `package_manager: pnpm` hit `pnpm: command not found` and must work around it with custom test commands.

## Scope

### In scope
- Rename `npm_*` jobs/commands/scripts to `node_*` (except `npm_auth`)
- Thread `package_manager` parameter through job -> command -> script chain
- Corepack activation for pnpm (and yarn) in `install_node.sh`
- Package-manager-aware dependency install, test fallback, cache, Dockerfile generation
- Prisma schema auto-detection and `prisma generate` after install
- Fix `test.setup` to support inline commands (not just file paths)
- Update all templates, packed scripts, and tests
- v0.3.0 release

### Out of scope
- Yarn support beyond basic corepack plumbing (no yarn-specific testing or validation)
- Monorepo-aware Dockerfile generation (user provides custom Dockerfile for complex monorepos)
- Changes to `npm_auth` (works for all PMs via `.npmrc`)

## Design

### 1. Rename Map

Keep `npm_auth` as-is (genuinely npm-registry-specific; `.npmrc` auth works for pnpm too). Everything else:

**Jobs:**
| Old | New |
|---|---|
| `npm_build_and_test` | `node_build_and_test` |
| `npm_code_quality` | `node_code_quality` |
| `npm_coverage` | `node_coverage` |
| `npm_security_scan` | `node_security_scan` |
| `npm_e2e_test` | `node_e2e_test` |
| `npm_sonar_scan` | `node_sonar_scan` |
| `npm_sbom` | `node_sbom` |

**Commands:**
| Old | New |
|---|---|
| `npm_install` | `node_install_deps` |
| `npm_test` | `node_test` |
| `npm_lint` | `node_lint` |
| `npm_audit` | `node_audit` |
| `npm_coverage_check` | `node_coverage_check` |
| `npm_sonar` | `node_sonar` |
| `npm_sbom` (cmd) | `node_sbom` (cmd) |
| `restore_npm_cache` | `restore_node_cache` |
| `save_npm_cache` | `save_node_cache` |

**Scripts:** Same pattern, `.sh` suffix (e.g., `npm_install.sh` -> `node_install_deps.sh`).

### 2. Parameter Threading

Add `package_manager` (type: string, default: `"npm"`) to:
- `node_build_and_test` job
- `install_node` command
- `node_install_deps` command
- `node_test` command
- `restore_node_cache` / `save_node_cache` commands

Templates pass it: `package_manager: "${MUNITOR_PACKAGE_MANAGER}"`.

At runtime, each command sets `MUNITOR_PACKAGE_MANAGER: << parameters.package_manager >>` in the step's `environment` block, making it available to the included script.

### 3. Corepack Activation (`install_node.sh`)

After nvm install/use, when `MUNITOR_PACKAGE_MANAGER != npm`:

1. Run `corepack enable`
2. Detect version from `package.json` with this priority:
   - `packageManager` field (e.g., `"pnpm@9.15.9"`) -- corepack-native declaration
   - `engines.<pm>` field (e.g., `"engines": {"pnpm": ">=9"}`)
   - Fallback: no version specified (corepack uses latest)
3. If version found: `corepack prepare <pm>@<version> --activate`
4. Print version to build output
5. Export PM binary path to `BASH_ENV` so downstream steps have it on PATH

### 4. Dependency Install (`node_install_deps.sh`, was `npm_install.sh`)

Branch on `MUNITOR_PACKAGE_MANAGER`:

**npm (default):** Current behavior unchanged. Check `package-lock.json`, run `npm ci`, lockfile version warning.

**pnpm:** Check `pnpm-lock.yaml` exists (error message should suggest `pnpm install` to create it, not `npm install`). Run `pnpm install --frozen-lockfile`. Note: `pnpm install` at the repo root handles workspaces natively; `pnpm -r` is NOT needed.

After install (all PMs): Prisma auto-detection (see section 7).

### 5. Test Execution (`node_test.sh`, was `npm_test.sh`)

**Custom commands path:** Unchanged. Already runs arbitrary commands via `bash -c`.

**Default fallback (no custom commands):**
- npm: `npx jest` (current behavior)
- pnpm: `pnpm test` (delegates to package.json scripts, where Jest or Vitest is typically configured)

### 6. Cache (`restore_node_cache.yml` / `save_node_cache.yml`)

Use CircleCI `when/equal` conditions on `package_manager` parameter:

**npm:** Checksum `package-lock.json`, cache `~/.npm`.
**pnpm:** Checksum `pnpm-lock.yaml`, cache pnpm store (get path via `pnpm store path` at save time, use `~/.local/share/pnpm/store` as restore default).

Cache key prefix changes per PM to avoid collisions: `npm-v1-` vs `pnpm-v1-`.

### 7. Prisma Auto-Detection

Added to `node_install_deps.sh` after the dependency install step:

1. `find . -path "*/prisma/schema.prisma" -not -path "*/node_modules/*" -not -path "*/dist/*" -not -path "*/build/*"`
2. For each found schema, run `<exec> prisma generate --schema=<path>`:
   - npm: `npx prisma generate --schema=<path>`
   - pnpm: `pnpm exec prisma generate --schema=<path>`
3. If no schemas found, skip silently (no output).
4. If schemas found but `prisma` is not in dependencies, log a warning and continue (don't fail the build).

This is not pnpm-specific; it helps any monorepo where Prisma's postinstall hook can't find the schema at the default location.

### 8. Dockerfile Generation (`generate_dockerfile.sh`)

Already has `MUNITOR_PACKAGE_MANAGER` via `extract_munitor_vars.sh`. Changes needed in node-api and node-webapp Dockerfile templates:

**npm (default):** No change. `COPY package*.json` / `npm ci` / `npm run build`.

**pnpm:** In builder stage:
```dockerfile
RUN corepack enable
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile
COPY . .
RUN pnpm run build
```

Runner stage: strip pnpm (same pattern as stripping npm). For distroless images (node-webapp), pnpm isn't present in the runner anyway since only standalone output is copied.

**Monorepo note:** Generated Dockerfiles assume single-package or standalone-output builds. Complex monorepo setups should provide a custom Dockerfile (existing escape hatch: place a `Dockerfile` in the repo and Munitor skips generation).

### 9. test.setup Fix (`run_test_setup.sh`)

Current behavior: if the value doesn't point to an existing file, exit with "script not found." This silently confuses users who pass command strings.

Fix: if the value is not a file path, treat it as an inline shell command and run it via `bash -c`. Log clearly which mode was used:
- File: `"Running test setup script: ./scripts/setup.sh"`
- Inline: `"Running test setup command: corepack enable && ..."`

This reduces the need for the inline workaround now that pnpm is auto-handled, but prevents future confusion.

### 10. Template Updates

All 4 templates (`node-webapp.yml.tpl`, `node-api.yml.tpl`) and 2 deploy partials (`node-webapp-deploy.yml.tpl`, `node-api-deploy.yml.tpl`):
- Replace all `munitor/npm_*` references with `munitor/node_*`
- Add `package_manager: "${MUNITOR_PACKAGE_MANAGER}"` to `node_build_and_test` invocations

`packed_generate_config.sh` and `packed_generate_dockerfile.sh`: Regenerated from source (these embed templates).

### 11. Test Updates

- `test_generate_config.sh`: Update all `npm_*` assertions to `node_*`. Add pnpm fixture and tests.
- `test_extract_munitor_vars.sh`: Already tests `MUNITOR_PACKAGE_MANAGER`. Add pnpm-specific fixture.
- `test_scripts.sh`: Update script path references. Add tests for pnpm branching in `node_install_deps.sh` and Prisma detection.
- New fixture: `.munitor.yml` with `package_manager: pnpm` for generate_config tests.

### 12. Version and Release

- Version: **0.3.0** (breaking rename, pre-1.0)
- Consumer repos must regenerate `.circleci/config.yml` after bumping orb version
- `generate_config.sh` output automatically uses new job names
