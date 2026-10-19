# TODO: Munitor

## Pending

- [ ] Validate and publish fast Java CI patch, canary actual cache size/timings, then adopt stable orb (docs/PLAN-lean-java-ci.md).

- [ ] Validate and release supplemental-image freshness fix, then adopt it in backend PR311 and verify all supplemental Trivy scans.

- [ ] Release JVM runtime cache fix and adopt the stable orb in Website-Backend; verify fresh image Trivy before release.

- [ ] Run PR image-scan script/template/BATS tests on Linux and verify a consumer PR with Docker/Trivy before publishing.
- [x] Add PR-only image scans for the four application templates, supplemental scan-only mode, JSON artifacts, and regression tests (uncommitted).

- [x] Review publishing CI fixes and merge PR19 to develop.
- [x] Publish v0.3.2 from main.
- [ ] Publish v0.3.3 (atomic release versions); bump Website-Backend/Frontend pins to 0.3.3.
- [ ] Bump Concilium (0.2) and makers4 (0.1) to 0.3.3 when next active.

- [ ] Follow makers4 and terraform-proxmox-talos on CircleCI when those repos are next active.
- [ ] Adopt supplemental images on an appropriate consumer.

## Completed

- [x] Prove consolidated production write-back with Investing in Chester and QRun marketing.
- [x] Release v0.3.0 and move the verified consumers to the stable 0.3 line.
- [x] Merge repository Dockerfile preservation and consolidated GitOps write-back.
- [x] Validate first-class pnpm support and merge PR #6.
- [x] Add opt-in repository Dockerfile preservation for node-webapp (GH-7)
- [x] Implement first-class pnpm support (GH-5, 17 commits, 219 tests)
- [x] Rename all `npm_*` orb components to `node_*` (backward-incompatible, pre-1.0)
- [x] Thread package_manager through full job/command/script chain
- [x] Add corepack activation for pnpm/yarn in install_node
- [x] Add pnpm Dockerfile variants for node-api and node-webapp
- [x] Add Prisma auto-detection after dependency install
- [x] Support inline commands in test.setup
- [x] Bootstrap pnpm in secondary jobs (code-quality, coverage, e2e, security-scan, sonar, sbom)
- [x] Add configurable coverage_summary_path with monorepo glob support
- [x] Publish dev:snapshot with pnpm support
- [x] Implement gradle-webapp pipeline type (20 new files, 7 modified, 605+ tests)
- [x] Fix pack_generate_config.sh to embed gradle templates
- [x] Fix RC009 orb review (extract inline commands to included script)
- [x] Fix SC2155 shellcheck warnings in extract_munitor_vars.sh
- [x] Add JaCoCo diagnostic output to gradle_jacoco.sh
- [x] Merge gradle-webapp PR #2 to develop
- [x] Release v0.2.0 and publish kof22/munitor@0.2.0
- [x] Create GitHub Release for v0.2.0
- [x] Bump Concilium from dev:snapshot to @0.2 (PR #41)
- [x] Bump Website-Backend from @0.1 to @0.2 (PR #44)
- [x] Bump Website-Frontend from @0.1 to @0.2 (PR #6)
- [x] Onboard Concilium as first gradle-webapp consumer
- [x] Create GitHub Releases for v0.1.0, v0.1.1, v0.1.2
- [x] Publish orb kof22/munitor@0.1.2 (overridable org defaults)
- [x] Implement supplemental Docker image support
- [x] All 8 pipeline types implemented and tested
- [x] Full rebrand from Faber to Munitor
