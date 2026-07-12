# Repository instructions

Read `CLAUDE.md`, `CONTRIBUTING.md`, `docs/SESSION-STATE.md`, and `docs/TODO.md`
before substantive work. Munitor is a CircleCI orb: source changes belong under
`src/`, generated packed scripts must remain synchronized, and consumer behavior
must be covered by BATS fixtures and assertions.

Use feature branches targeting `develop`; `main` is release-only. Run `make all`
before opening a pull request and `make validate` when the CircleCI CLI is
available. Publish development snapshots from feature or `develop`; publish
stable orb versions only from semantic version tags on `main`.

For deployment changes, preserve the established contract: repository-owned
Dockerfiles are opt-in, consolidated GitOps paths are repository-relative
`kustomization.yaml` files, and `production_only` prevents non-main write-back.
Never put credentials in manifests, fixtures, logs, or documentation.
