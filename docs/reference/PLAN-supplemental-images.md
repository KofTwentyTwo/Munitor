# PLAN: Supplemental Images

## Goal

Add support for building, scanning, and pushing supplemental Docker images (e.g., Liquibase migrations, database backup containers) alongside the main application image. Each supplemental image shares the same version tag as the app, gets Trivy-scanned, and can update the CD repo.

## Config Shape

```yaml
# .munitor.yml
supplemental_images:
  - name: migrations
    # Option A: auto-generate Dockerfile from base + copy
    base: liquibase/liquibase:4.31
    copy:
      - src: db/changelog/
        dest: /liquibase/changelog/
    cd:
      image_key: migrations.image.tag         # Helm mode
      # image_name: ghcr.io/org/app-migrations  # Kustomize (auto-derived if omitted)

  - name: db-backup
    # Option B: use repo-provided Dockerfile
    dockerfile: docker/Dockerfile.backup
    cd:
      image_key: dbBackup.image.tag
```

Image name derivation: `{image_name}-{name}` (e.g., `me-health-portal-migrations`).
Version: always same as main app (`PROJECT_VERSION`).
Env tag: same as main app (`DOCKER_ENV_TAG`).

## Architecture

```
docker_build_push job steps:
  attach_workspace
  restore_version_metadata
  generate_dockerfile            # Main app Dockerfile
  docker_build                   # Build main app image
  health_check                   # Verify main app boots
  restore_trivy_cache
  run_trivy_image                # Scan main app image
  save_trivy_cache
  docker_push_ghcr               # Push main app (establishes registry auth)
  build_push_supplemental  [NEW] # For each supplemental: generate Dockerfile, build, scan, push
```

CD repo update: `update_cd_repo` receives supplemental_images JSON, updates all tags in a single commit.

## Files Affected

### New Files
| File | Purpose |
|------|---------|
| `src/scripts/build_push_supplemental.sh` | Loop: auto-generate Dockerfile, build, Trivy scan, push each supplemental image |
| `src/commands/build_push_supplemental.yml` | Orb command wrapping the script |
| `tests/fixtures/java-webapp-supplemental.munitor.yml` | Test fixture with supplemental_images config |

### Modified Files
| File | Change |
|------|--------|
| `src/scripts/extract_munitor_vars.sh` | Parse `supplemental_images` array, export `MUNITOR_SUPPLEMENTAL_IMAGES_JSON` + `MUNITOR_SUPPLEMENTAL` flag |
| `src/scripts/generate_config.sh` | Add `SUPPLEMENTAL` to conditional flags, `supplemental_images` to KNOWN_KEYS |
| `src/scripts/update_cd_repo.sh` | Read `SUPPLEMENTAL_IMAGES_JSON`, update all supplemental image tags in same commit |
| `src/commands/update_cd_repo.yml` | Add `supplemental_images` parameter |
| `src/jobs/docker_build_push.yml` | Add `supplemental_images` param + `build_push_supplemental` step |
| `src/scripts/templates/java-webapp.yml.tpl` | `##IF_SUPPLEMENTAL##` blocks on docker_build_push + update_cd_repo (release-candidate + production) |
| `src/scripts/templates/node-api.yml.tpl` | Same |
| `src/scripts/templates/node-webapp.yml.tpl` | Same |
| `src/scripts/templates/partials/java-webapp-deploy.yml.tpl` | `##IF_SUPPLEMENTAL##` blocks on docker_build_push + update_cd_repo |
| `src/scripts/templates/partials/node-api-deploy.yml.tpl` | Same |
| `src/scripts/templates/partials/node-webapp-deploy.yml.tpl` | Same |
| `tests/test_extract_munitor_vars.sh` | Test supplemental_images parsing |
| `tests/test_generate_config.sh` | Test ##IF_SUPPLEMENTAL## rendering |
| `tests/test_scripts.sh` | Test build_push_supplemental.sh structure |

## Design Decisions

**Loop in same job, not separate jobs.** Supplemental images are lightweight (FROM base + COPY). Sequential build in the same executor avoids spinning up more machines and reuses Docker auth + Trivy installation.

**JSON array config.** Variable number of supplemental images (0-N). JSON array parsed with `jq` handles this cleanly. Follows the same pattern as `MUNITOR_SERVICES_JSON`.

**Auto-generate Dockerfiles.** Most supplemental images are trivial. Auto-generation from `base` + `copy` eliminates boilerplate. Users can still provide custom Dockerfiles.

**Single CD commit.** All image tags (app + supplemental) are updated atomically so ArgoCD picks them up together.

**Docker-producing pipelines only.** supplemental_images only applies to java-webapp, node-api, node-webapp. Not terraform, argocd-apps, validate-cd-repo, sdk-distribution.

## Variable Flow

```
.munitor.yml                     extract_munitor_vars.sh              templates
--------------                   -----------------------              ---------
supplemental_images: [...]  -->  MUNITOR_SUPPLEMENTAL="true"     -->  ##IF_SUPPLEMENTAL##
                                 MUNITOR_SUPPLEMENTAL_IMAGES_JSON -->  docker_build_push(supplemental_images=...)
                                                                       update_cd_repo(supplemental_images=...)
```

## Script Details

### build_push_supplemental.sh

```
For each entry in SUPPLEMENTAL_IMAGES_JSON:
  1. Derive image name: {IMAGE_NAME}-{entry.name}
  2. If entry.dockerfile exists: use it
     Else: auto-generate Dockerfile.{name} from entry.base + entry.copy
  3. docker build -f {dockerfile} -t {REGISTRY}/{derived_name}:{VERSION} .
  4. If DOCKER_ENV_TAG set: also tag with env tag
  5. trivy image --severity HIGH,CRITICAL --exit-code 1 {full_tag}
  6. docker push {full_tag}
  7. If env tag: docker push {full_tag_env}
```

### update_cd_repo.sh changes

After updating main image tag, if SUPPLEMENTAL_IMAGES_JSON is non-empty:
- Helm: for each entry with cd.image_key, run `yq -i ".{key} = {VERSION}"`
- Kustomize: for each entry, derive image_name as `{CD_IMAGE_NAME}-{name}` (or use cd.image_name), run yq on kustomization.yaml
