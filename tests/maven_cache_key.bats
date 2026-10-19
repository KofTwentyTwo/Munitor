#!/usr/bin/env bats

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../src/scripts/maven_cache_key.sh"
  cd "$BATS_TEST_TMPDIR"
  git init -q
  printf '<project><version>1-SNAPSHOT</version></project>\n' > pom.xml
  git add pom.xml
}

@test "release rewrites retain the restored cache identity" {
  bash "$SCRIPT"
  cp .munitor-maven-cache-key before
  printf '<project><version>1.2.3</version></project>\n' > pom.xml
  bash "$SCRIPT"
  cmp before .munitor-maven-cache-key
}

@test "nested checked-out dependency changes invalidate the cache" {
  mkdir module
  printf '<project><dependencies/></project>\n' > module/pom.xml
  git add module/pom.xml
  bash "$SCRIPT"
  cp .munitor-maven-cache-key before
  printf '<project><dependencies>changed</dependencies></project>\n' > module/pom.xml
  git add module/pom.xml
  bash "$SCRIPT"
  ! cmp -s before .munitor-maven-cache-key
}

@test "source changes do not invalidate dependency cache" {
  bash "$SCRIPT"
  cp .munitor-maven-cache-key before
  printf 'class Example {}\n' > Example.java
  git add Example.java
  bash "$SCRIPT"
  cmp before .munitor-maven-cache-key
}

@test "restore has no broad fallback and save uses the same key" {
  command_root="${BATS_TEST_DIRNAME}/../src/commands"
  restore=$(sed -n '/maven-v2-/p' "$command_root/restore_maven_cache.yml")
  save=$(sed -n '/maven-v2-/p' "$command_root/save_maven_cache.yml")
  [[ "$restore" == *'maven-v2-{{ checksum ".munitor-maven-cache-key" }}'* ]]
  [[ "$save" == *'maven-v2-{{ checksum ".munitor-maven-cache-key" }}'* ]]
  ! grep -q 'maven-v1\|maven-v2-$' "$command_root/restore_maven_cache.yml"
}
