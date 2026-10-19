#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=src/scripts/docs_only.sh
source "${SCRIPT_DIR}/../src/scripts/docs_only.sh"
WORK=$(mktemp -d)
trap 'rm -rf -- "$WORK"' EXIT
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME=Fixture GIT_AUTHOR_EMAIL=fixture@example.invalid
export GIT_COMMITTER_NAME=Fixture GIT_COMMITTER_EMAIL=fixture@example.invalid
export GIT_TERMINAL_PROMPT=0
export CIRCLE_BRANCH=feature/docs CIRCLE_TAG=""
PASS=0
git init -q --bare "${WORK}/origin.git"
git init -q -b main "${WORK}/seed"
cd "${WORK}/seed"
mkdir -p src docs/nested
printf 'base\n' > README.md
printf 'base\n' > src/app.java
printf 'base\n' > docs/old.md
git add .
git -c commit.gpgsign=false commit -qm base
git remote add origin "${WORK}/origin.git"
git push -q origin main
git --git-dir="${WORK}/origin.git" symbolic-ref HEAD refs/heads/main

fresh() {
  local repo="${WORK}/case-${PASS}"
  git clone -q "${WORK}/origin.git" "$repo"
  cd "$repo"
  git switch -qc feature/docs
  export CIRCLE_BRANCH=feature/docs CIRCLE_TAG=""
}

commit() {
  git add -A
  git -c commit.gpgsign=false commit -qm change
}

check() {
  local expected="$1" name="$2" status=0 output
  output=$(munitor_docs_only 2>&1) || status=$?
  if [[ "$status" -ne "$expected" || -n "$output" ]]; then
    printf 'FAIL: %s (status %s, expected %s; output must be empty)\n' "$name" "$status" "$expected"
    exit 1
  fi
  printf 'PASS: %s\n' "$name"
  PASS=$((PASS + 1))
}

fresh
printf 'docs\n' >> README.md
mkdir -p docs/nested
printf 'docs\n' > 'docs/nested/space name.md'
printf 'docs\n' > $'docs/nested/line\nbreak.md'
printf 'docs\n' > CHANGELOG.md
printf 'docs\n' > CONTRIBUTING.md
commit
check 0 'feature docs with nested, spaced and newline paths'
CIRCLE_BRANCH=hotfix/docs check 0 'hotfix docs'
for branch in develop staging release/1.0 unknown ''; do
  CIRCLE_BRANCH="$branch" check 1 "ineligible branch: $branch"
done
CIRCLE_TAG=v1.0 check 1 'tag cannot skip release'

fresh
check 1 'empty branch diff'
printf 'code\n' >> src/app.java
commit
printf 'docs\n' >> README.md
commit
check 1 'earlier code commit followed by latest docs commit'

fresh
printf 'code\n' >> src/app.java
printf 'docs\n' >> README.md
commit
check 1 'mixed source and docs'

fresh
git mv src/app.java docs/disguised.md
commit
check 1 'code renamed into allowed docs path'

fresh
git mv docs/old.md docs/new.md
commit
check 0 'docs-only rename'

fresh
git rm -q src/app.java
commit
check 1 'deleted code'

fresh
git rm -q docs/old.md
commit
check 0 'deleted documentation'

for path in pom.xml .circleci/config.yml docs/image.png docs/example.java readme.md nested/README.md; do
  fresh
  mkdir -p "$(dirname "$path")"
  printf 'not docs\n' > "$path"
  commit
  check 1 "non-allowlisted path: $path"
done

fresh
printf 'docs\n' >> README.md
commit
git remote remove origin
check 1 'missing origin fails closed'

fresh
printf 'docs\n' >> README.md
commit
git remote set-url origin "${WORK}/missing.git"
check 1 'fetch failure fails closed despite cached origin/main'

fresh
printf 'docs\n' >> README.md
commit
# Advance origin main after this checkout; an old tracking ref is not enough.
cd "${WORK}/seed"
printf 'main\n' >> README.md
commit
git push -q origin main
latest=$(git rev-parse HEAD)
cd "${WORK}/case-${PASS}"
check 0 'fetch updated main then compare merge-base'
[[ "$(git rev-parse origin/main)" == "$latest" ]]

fresh
git switch -q main
printf 'docs\n' >> README.md
commit
CIRCLE_BRANCH=main check 0 'main docs commit compares first parent'
printf 'code\n' >> src/app.java
commit
CIRCLE_BRANCH=main check 1 'main source commit'

fresh
printf 'docs\n' >> README.md
commit
git switch -q main
git -c commit.gpgsign=false merge --no-ff -qm 'docs merge' feature/docs
CIRCLE_BRANCH=main check 0 'main docs merge uses first parent'

fresh
printf 'code\n' >> src/app.java
commit
printf 'docs\n' >> README.md
commit
git switch -q main
git -c commit.gpgsign=false merge --no-ff -qm 'mixed merge' feature/docs
CIRCLE_BRANCH=main check 1 'main merge includes whole source change'

git init -q -b main "${WORK}/root-only"
cd "${WORK}/root-only"
printf 'docs\n' > README.md
commit
CIRCLE_BRANCH=main check 1 'root commit has no parent'
git remote add origin "${WORK}/origin.git"
CIRCLE_BRANCH=feature/docs check 1 'unrelated history has no merge base'

git clone -q --depth=1 "file://${WORK}/origin.git" "${WORK}/shallow"
cd "${WORK}/shallow"
printf 'docs\n' >> README.md
commit
CIRCLE_BRANCH=main check 1 'shallow history fails closed'
printf '%s docs-only checks passed\n' "$PASS"
