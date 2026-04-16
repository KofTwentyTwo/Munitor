# PLAN: Gradle-Webapp Pipeline Type

## Goal

Add Gradle build support to Munitor so Gradle-based Java projects can use the same quality gates and deployment workflows as Maven projects.

## Design Decisions

1. **Approach A: Full parallel pipeline** - Completely independent pipeline type with its own commands, scripts, jobs, and template. No shared code with Maven.
2. **JAR discovery (C)**: Use `server_module` config field to construct path `{server_module}/build/libs/*.jar`, excluding `-plain.jar`, `-sources.jar`, `-javadoc.jar`.
3. **No version injection (C)**: Skip Gradle version setting entirely. Rely on `calculate_version` + `export_version_vars` for Docker image tagging.
4. **Cache key (B)**: `gradle-wrapper.properties` + `settings.gradle.kts` with `gradle-v1-` fallback.

## Config Shape

```yaml
pipeline: gradle-webapp
orb_version: "0.2"
image_name: concilium
java_version: "21"
server_module: "concilium-server"  # optional, for multi-module shadow JAR
docker:
  registry: ghcr.io/koftwentytwo
```

## Files Created (19)

- Scripts (6): `gradle_build.sh`, `gradle_test.sh`, `gradle_jacoco.sh`, `gradle_checkstyle.sh`, `gradle_spotbugs.sh`, `gradle_pmd.sh`, `collect_gradle_test_results.sh`
- Commands (8): `gradle_build.yml`, `gradle_test.yml`, `gradle_jacoco.yml`, `gradle_checkstyle.yml`, `gradle_spotbugs.yml`, `gradle_pmd.yml`, `restore_gradle_cache.yml`, `save_gradle_cache.yml`
- Jobs (3): `gradle_build_and_test.yml`, `gradle_code_quality.yml`, `gradle_coverage.yml`
- Templates (2): `gradle-webapp.yml.tpl`, `partials/gradle-webapp-deploy.yml.tpl`

## Files Modified (6+)

- `extract_munitor_vars.sh` - Added `MUNITOR_SERVER_MODULE`, fixed SC2155 warnings
- `generate_config.sh` - Added `gradle-webapp` to case + `server_module` to known keys
- `generate_dockerfile.sh` - Added `gradle-webapp` case with shadow JAR discovery
- `pack_generate_config.sh` - Added gradle templates to embed loops
- Test files (3) - Added gradle-webapp assertions

## Gotchas Discovered

1. **pack_generate_config.sh has hardcoded template lists** - New templates must be added to the for loops manually. Not auto-discovered.
2. **RC009 orb review** - CircleCI orb-tools review fails on inline commands > 64 chars. Must use `<< include() >>` syntax.
3. **Gradle JaCoCo CSV not default** - Gradle's JaCoCo plugin only generates HTML+XML by default. Projects must explicitly enable `csv.required.set(true)`.
4. **orb_version resolution** - `orb_version: "0.1"` in `.munitor.yml` resolves to latest stable `@0.1.x`, not `dev:snapshot`. New features only available via `dev:snapshot` until released.
