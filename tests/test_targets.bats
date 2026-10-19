#!/usr/bin/env bats

@test "combined script and template targets run each suite once" {
  mkdir -p "$BATS_TEST_TMPDIR/tests"
  printf 'echo SCRIPT_EXECUTED\n' > "$BATS_TEST_TMPDIR/tests/test_example.sh"
  printf 'echo TEMPLATE_EXECUTED\n' > "$BATS_TEST_TMPDIR/tests/test_generate_config.sh"
  run make --no-print-directory -f "$BATS_TEST_DIRNAME/../Makefile" -C "$BATS_TEST_TMPDIR" test-scripts test-templates
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | grep -c '^SCRIPT_EXECUTED$')" -eq 1 ]
  [ "$(echo "$output" | grep -c '^TEMPLATE_EXECUTED$')" -eq 1 ]
}
