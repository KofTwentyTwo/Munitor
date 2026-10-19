#!/usr/bin/env bats

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../src/scripts/maven_workspace.sh"
  export HOME="${BATS_TEST_TMPDIR}/home"
  cd "$BATS_TEST_TMPDIR"
}

@test "workspace overlays current installed artifacts and snapshot metadata without copying remote dependencies" {
  repo="$HOME/.m2/repository"
  mkdir -p "$repo/example/library/2-SNAPSHOT" "$repo/vendor/dependency/1"
  printf 'library-2-SNAPSHOT.jar>=\r\nlibrary-2-SNAPSHOT.pom>=\r\nlibrary-2-SNAPSHOT-tests.jar>=\r\n' > "$repo/example/library/2-SNAPSHOT/_remote.repositories"
  for extension in jar pom; do
    printf 'current build\n' > "$repo/example/library/2-SNAPSHOT/library-2-SNAPSHOT.$extension"
  done
  printf 'current test classes\n' > "$repo/example/library/2-SNAPSHOT/library-2-SNAPSHOT-tests.jar"
  printf 'snapshot metadata\n' > "$repo/example/library/maven-metadata-local.xml"
  printf 'plugin prefix metadata\n' > "$repo/example/maven-metadata-local.xml"
  printf 'dependency-1.jar>central=\n' > "$repo/vendor/dependency/1/_remote.repositories"
  printf 'remote dependency\n' > "$repo/vendor/dependency/1/dependency-1.jar"
  mkdir -p "$repo/vendor/mutable/2-SNAPSHOT"
  printf 'mutable-2-SNAPSHOT.jar>central=\n' > "$repo/vendor/mutable/2-SNAPSHOT/_remote.repositories"
  printf 'updated snapshot\n' > "$repo/vendor/mutable/2-SNAPSHOT/mutable-2-SNAPSHOT.jar"
  MAVEN_WORKSPACE_ACTION=save bash "$SCRIPT"
  run tar -tzf .munitor-maven-installed.tgz
  [ "$status" -eq 0 ]
  [[ "$output" != *vendor/dependency* ]]
  export HOME="${BATS_TEST_TMPDIR}/downstream"
  bash "$SCRIPT"
  restored="$HOME/.m2/repository/example/library"
  cmp "$repo/example/library/2-SNAPSHOT/library-2-SNAPSHOT.jar" "$restored/2-SNAPSHOT/library-2-SNAPSHOT.jar"
  cmp "$repo/example/library/maven-metadata-local.xml" "$restored/maven-metadata-local.xml"
  cmp "$repo/example/maven-metadata-local.xml" "$restored/../maven-metadata-local.xml"
  [ -f "$restored/2-SNAPSHOT/library-2-SNAPSHOT-tests.jar" ]
  [ ! -e "$HOME/.m2/repository/vendor/dependency" ]
  cmp "$repo/vendor/mutable/2-SNAPSHOT/mutable-2-SNAPSHOT.jar" "$HOME/.m2/repository/vendor/mutable/2-SNAPSHOT/mutable-2-SNAPSHOT.jar"
}

@test "initial build without a workspace archive needs no overlay" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}
