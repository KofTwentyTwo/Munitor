## Prompt: Adopting Munitor Supplemental Images for Pre-Rollout Containers

You are helping a development team configure their `.munitor.yml` file to use the **supplemental images** feature in the Munitor CircleCI orb. This feature builds, Trivy-scans, and pushes additional Docker images (sidecar/init containers) alongside the main application image during CI/CD.

### When to use supplemental images

Use this for any container that runs **before or alongside** the main application deployment:
- **Liquibase migrations** — runs DB changelogs before the app starts
- **Database backup** — snapshots the DB before a migration
- **Data seeding** — loads reference data into a fresh environment
- **Schema validation** — validates DB schema compatibility
- Any other init container or Job that needs its own image

### How it works

1. Munitor builds the main app image as usual
2. For each entry in `supplemental_images`, it either:
   - **Auto-generates a Dockerfile** from `base` + `copy` directives, OR
   - **Uses a provided Dockerfile** from the repo
3. Each supplemental image is built, scanned with Trivy (HIGH/CRITICAL), and pushed to the same registry
4. Image naming: `{image_name}-{supplemental_name}` (e.g., `me-health-portal-migrations`)
5. All images share the same version tag
6. The CD repo update commits all image tags (main + supplemental) atomically in a single commit

### Configuration reference

Add a `supplemental_images` array to your `.munitor.yml`:

```yaml
supplemental_images:
  - name: <string>           # REQUIRED. Suffix appended to image_name (e.g., "migrations")
    base: <string>           # Option A: base Docker image (e.g., "liquibase/liquibase:4.31")
    copy:                    # Files to COPY into the auto-generated Dockerfile
      - src: <path>          #   Source path relative to repo root
        dest: <path>         #   Destination path in the container
    dockerfile: <string>     # Option B: path to a Dockerfile in the repo (mutually exclusive with base)
    cd:                      # CD repo tag update config
      image_key: <string>    #   For Helm: dot-path in values.yaml (e.g., "migrations.image.tag")
      image_name: <string>   #   For Kustomize: image name in kustomization.yaml (defaults to {image_name}-{name})
```

Each entry must have either `base` or `dockerfile`, not both.

### Example: Liquibase migrations

```yaml
pipeline: java-webapp
image_name: me-health-portal
java_version: "21"

docker:
  registry: ghcr.io/dmdbrands

cd:
  repo: dmdbrands/me-health-portal-cd-pipeline

supplemental_images:
  - name: migrations
    base: liquibase/liquibase:4.31
    copy:
      - src: db/changelog/
        dest: /liquibase/changelog/
    cd:
      image_key: migrations.image.tag
```

This produces:
- Main image: `ghcr.io/dmdbrands/me-health-portal:1.2.3`
- Supplemental: `ghcr.io/dmdbrands/me-health-portal-migrations:1.2.3`
- CD repo `values.yaml` gets both `image.tag: "1.2.3"` and `migrations.image.tag: "1.2.3"` in one commit

### Example: Multiple supplemental images

```yaml
supplemental_images:
  - name: migrations
    base: liquibase/liquibase:4.31
    copy:
      - src: db/changelog/
        dest: /liquibase/changelog/
    cd:
      image_key: migrations.image.tag

  - name: db-backup
    dockerfile: docker/Dockerfile.db-backup
    cd:
      image_key: dbBackup.image.tag
```

### Example: Kustomize CD format

```yaml
supplemental_images:
  - name: migrations
    base: liquibase/liquibase:4.31
    copy:
      - src: db/changelog/
        dest: /liquibase/changelog/
    cd:
      image_name: me-health-portal-migrations   # optional, defaults to {image_name}-{name}
```

This updates `kustomization.yaml`:
```yaml
images:
  - name: me-health-portal
    newTag: "1.2.3"
  - name: me-health-portal-migrations
    newTag: "1.2.3"
```

### Key constraints

- The `name` field becomes part of the Docker image name, so use lowercase alphanumeric + hyphens only
- `base` + `copy` auto-generates a simple `FROM` + `COPY` Dockerfile — for anything more complex (RUN commands, ENV, etc.), use `dockerfile` instead
- All supplemental images are Trivy-scanned with `--severity HIGH,CRITICAL --exit-code 1` — the build fails if vulnerabilities are found
- The feature is available on all pipeline types: `java-webapp`, `node-api`, `node-webapp`
- If `supplemental_images` is not present in `.munitor.yml`, no supplemental processing occurs (fully backward compatible)

### Your task

Given the team's application context, help them:
1. Identify which pre-rollout tasks need their own container image
2. Determine whether each needs `base` + `copy` (simple) or a custom `dockerfile` (complex)
3. Configure the `supplemental_images` section in their `.munitor.yml`
4. Ensure the CD repo's `values.yaml` or `kustomization.yaml` has matching entries for the supplemental image tags
