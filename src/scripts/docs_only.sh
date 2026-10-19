#!/usr/bin/env bash
# Source this helper. Any uncertainty keeps the full pipeline.
munitor_docs_only() (
  [[ -z "${CIRCLE_TAG:-}" ]] || return 1
  local base paths path seen=0
  case "${CIRCLE_BRANCH:-}" in
    feature/*|hotfix/*)
      git fetch --no-tags origin '+refs/heads/main:refs/remotes/origin/main' >/dev/null 2>&1 || return 1
      base=$(git merge-base HEAD refs/remotes/origin/main 2>/dev/null) || return 1
      ;;
    main)
      base=$(git rev-parse --verify 'HEAD^1' 2>/dev/null) || return 1
      ;;
    *) return 1 ;;
  esac
  [[ "$(git rev-parse --is-shallow-repository 2>/dev/null)" == false ]] || return 1
  paths=$(mktemp 2>/dev/null) || return 1
  trap 'rm -f -- "$paths"' EXIT
  git diff --no-ext-diff --no-renames --name-only -z "$base" HEAD >"$paths" 2>/dev/null || return 1
  while IFS= read -r -d '' path; do
    case "$path" in
      README.md|CHANGELOG.md|CONTRIBUTING.md|docs/*.md) ;;
      *) return 1 ;;
    esac
    seen=1
  done <"$paths"
  [[ "$seen" -eq 1 ]]
)
