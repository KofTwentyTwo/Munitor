# TODO: Supplemental Images

## Implementation Checklist

- [ ] **Step 1:** `extract_munitor_vars.sh` - Parse `supplemental_images` array, export `MUNITOR_SUPPLEMENTAL` + `MUNITOR_SUPPLEMENTAL_IMAGES_JSON`, add to exports and `get_envsubst_vars()`
- [ ] **Step 2:** `generate_config.sh` - Add `SUPPLEMENTAL` to conditional flags list, add `supplemental_images` to KNOWN_KEYS
- [ ] **Step 3:** `build_push_supplemental.sh` (NEW) - Loop: auto-generate Dockerfile, build, Trivy scan, push each supplemental image
- [ ] **Step 4:** `build_push_supplemental.yml` (NEW) - Orb command wrapping the script
- [ ] **Step 5:** `docker_build_push.yml` - Add `supplemental_images` param + `build_push_supplemental` step after `docker_push_ghcr`
- [ ] **Step 6:** `update_cd_repo.sh` - Read `SUPPLEMENTAL_IMAGES_JSON`, update supplemental image tags in same commit (both Helm + Kustomize)
- [ ] **Step 7:** `update_cd_repo.yml` - Add `supplemental_images` parameter + env var
- [ ] **Step 8a:** `java-webapp.yml.tpl` - Add `##IF_SUPPLEMENTAL##` blocks on docker_build_push + update_cd_repo (release-candidate + production)
- [ ] **Step 8b:** `node-api.yml.tpl` - Same
- [ ] **Step 8c:** `node-webapp.yml.tpl` - Same
- [ ] **Step 8d:** `java-webapp-deploy.yml.tpl` - Add `##IF_SUPPLEMENTAL##` blocks on docker_build_push + update_cd_repo
- [ ] **Step 8e:** `node-api-deploy.yml.tpl` - Same
- [ ] **Step 8f:** `node-webapp-deploy.yml.tpl` - Same
- [ ] **Step 9a:** `java-webapp-supplemental.munitor.yml` (NEW) - Test fixture
- [ ] **Step 9b:** `test_extract_munitor_vars.sh` - Test supplemental_images parsing (enabled + default disabled)
- [ ] **Step 9c:** `test_generate_config.sh` - Test ##IF_SUPPLEMENTAL## conditional rendering
- [ ] **Step 9d:** `test_scripts.sh` - Test build_push_supplemental.sh structure (helpers, error handling, jq usage)
- [ ] **Step 10:** Run `make all` - Validate everything passes
