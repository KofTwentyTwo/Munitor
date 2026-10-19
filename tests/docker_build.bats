#!/usr/bin/env bats

@test "PR and release JVM builds refresh packages without disabling Node caching or Trivy" {
  run bash "${BATS_TEST_DIRNAME}/test_docker_build.sh"
  [ "$status" -eq 0 ]
}
