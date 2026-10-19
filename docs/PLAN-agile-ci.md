# Agile CI adoption

Implemented locally: an opt-in `java-webapp` docs-only workflow, aggregate consumer
gate, and native no-op gate for Munitor's own checks. Publication, real check-context
verification, required-check migration and consumer opt-in remain pending.

## Contract

- `ci.docs_only: true` permits only root README/CHANGELOG/CONTRIBUTING.md and
  `docs/**/*.md` (including Markdown directly in docs). Secret scanning stays on.
- Feature/hotfix classification uses the complete branch diff from the merge base
  with main, not the latest commit. Main uses its first parent. Tags, release/other
  branches, shallow history, empty or uncertain comparisons use full CI.
- Docs checks emit the aggregate gate without image build/deploy. Full workflows
  retain their existing gates. No custom reporting framework or reporting job.

## Required order

1. Local make all, 20 BATS, 31 classifier cases, eight source/packed graph cases, and CircleCI config validation passed. Finish hosted CI and publish the gate-capable orb.
2. Adopt it in the consumer with docs-only disabled. Observe successful actual
   GitHub context `ci/circleci: ci-ready`; do not infer the name from YAML alone.
3. Replace the consumer required-check list with that verified aggregate context,
   preserving review, signature, conversation, bypass and all other branch rules.
4. Enable `ci.docs_only: true`; prove docs-only and mixed/code changes select the
   expected paths and retain the required gate.
5. Separately verify Munitor's native no-op context (expected
   `ci/circleci: lint-pack/ci-ready`) before migrating its required checks.

All five adoption steps are pending; an implemented template is not rollout proof.
To avoid duplicate full builds, the pin and opt-in may share one adoption PR:
the manifest/config changes force full CI. Verify its gate and migrate required
checks before merging or opening a docs-only PR.

## Measure using existing CircleCI views

[Project Insights](https://app.circleci.com/insights/github/KofTwentyTwo/Website-Backend/workflows),
[PR checks](https://app.circleci.com/insights/github/KofTwentyTwo/Website-Backend/workflows/pr-checks),
and [Tests](https://app.circleci.com/insights/github/KofTwentyTwo/Website-Backend/workflows/pr-checks/tests)
already provide the dashboard. The historical API baseline was retrieved
October 19 but its returned data ends October 17 (PR P50 13m58s, P95 34m37s).
It is not a measurement of this implementation. After Insights catches up, compare
equivalent windows/branches and report the docs-checks median separately; do not
blend docs runs into a claimed full-build improvement or sum parallel job medians.

Backend native auto-cancel is on; main is its exempt default branch. Munitor stays
off because develop is its default and main/release work is not similarly exempt.
