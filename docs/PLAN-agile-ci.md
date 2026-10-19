# Agile CI adoption

Released as 0.3.10: opt-in documentation-only Java CI and aggregate merge results.
PR48 implemented it; PR49 released main 19192d07, signed tag v0.3.10 published,
and PR50 back-merged to develop 81ac29ee. All hosted checks passed. Munitor's
actual `ci/circleci: lint-pack/ci-ready` now protects main/develop; unrelated
policy is unchanged. Backend PR333 passed full consumer validation before its
required checks changed. Docs PR335 passed the two-job path and cancellation proof.

## Contract

- `ci.docs_only: true` permits only root README/CHANGELOG/CONTRIBUTING.md and
  `docs/**/*.md` (including Markdown directly in docs). Secret scanning stays on.
- Feature/hotfix classification uses the complete branch diff from the merge base
  with main, not the latest commit. Main uses its first parent. Tags, release/other
  branches, shallow history, empty or uncertain comparisons use full CI.
- Docs checks emit the aggregate gate without image build/deploy. Full workflows
  retain their existing gates. No custom reporting framework or reporting job.

## Required order

1. Local make all, 20 BATS, 31 classifier cases, eight source/packed graph cases, and CircleCI config validation passed. Hosted CI and stable publication also passed.
2. Adopt it in the consumer with docs-only disabled. Observe successful actual
   GitHub context `ci/circleci: ci-ready`; do not infer the name from YAML alone.
3. Replace the consumer required-check list with that verified aggregate context,
   preserving review, signature, conversation, bypass and all other branch rules.
4. Enable `ci.docs_only: true`; prove docs-only and mixed/code changes select the
   expected paths and retain the required gate.
5. Separately verify Munitor's native no-op context (observed
   `ci/circleci: lint-pack/ci-ready`) before migrating its required checks.

Publication and both required-check migrations are complete, following successful actual-context verification.
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

## Observed consumer results

Backend PR333 (664efcad) ran the complete pipeline in 15m33, with all 777 test
identities preserved and every check successful, including the actual required
ci/circleci: ci-ready. Required lists on main/develop were migrated only after
that proof; all other rules were verified unchanged. The latest full run is a
sample, not a new median; the earlier successful parallel-suite run was 14m49.

Docs PR335 selected only secrets-scan and ci-ready. A follow-up documentation
commit caused native cancellation of the older workflow after 44 seconds, with
no explicit cancel API call. The final docs run passed in 5m23 (313s secrets scanning, 4s aggregate result), then merged as 8dda8339. Main also selected only those two jobs, with no application release.