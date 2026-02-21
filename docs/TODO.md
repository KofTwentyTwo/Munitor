# TODO: SDLC Release Branch Workflow

## Implementation Checklist

- [x] **Step 0:** `calculate_version.sh` -- Write Faber-managed GitVersion.yml
- [x] **Step 1:** `extract_faber_vars.sh` -- Add `FABER_CD_ENV_RELEASE`
- [x] **Step 2:** `export_version_vars.sh` -- Remove `latest` Docker env tag from main
- [x] **Step 3:** `github_release.sh` -- Add `--prerelease` flag + dynamic `--target`
- [x] **Step 4:** `java-webapp.yml.tpl` -- Split `release:` into `release-candidate:` + `production:`
- [x] **Step 5:** `node-api.yml.tpl` -- Same split
- [x] **Step 6:** `terraform.yml.tpl` -- Same split (lighter)
- [x] **Step 7a:** `test_extract_faber_vars.sh` -- Assert `FABER_CD_ENV_RELEASE` default
- [x] **Step 7b:** `test_version_mapping.sh` -- Main env tag "" (not "latest")
- [x] **Step 7c:** `test_generate_config.sh` -- Replace release tests with release-candidate + production
- [x] **Step 7d:** `test_scripts.sh` -- Add tests for calculate_version.sh and github_release.sh
- [x] **Step 8:** `README.md` + `CONTRIBUTING.md` -- Update docs
- [x] **Step 9:** Run `make all` -- Validate everything passes (297 tests, 0 failures)
- [x] **Step 10:** Fix pre-existing lint issue (SC2054 in run_tfsec.sh)
