#!/usr/bin/env bats

setup() {
  export JOB="${BATS_TEST_DIRNAME}/../src/jobs/security_scan.yml"
}

# Resolve only this job's compile-time OWASP condition, rejecting unknown ones.
resolved_steps() {
  yq -o=json '.' "$JOB" | jq --argjson enabled "$1" '
    def expand:
      .[] | if type == "object" and has("when") then
        if .when.condition != "<< parameters.owasp >>" then error("unknown condition")
        elif $enabled then .when.steps | expand else empty end
      else . end;
    [.steps | expand]'
}

@test "OWASP disabled skips Java Maven and NVD but retains Trivy and its artifact" {
  run resolved_steps false
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '
    map(if type == "string" then . else keys[0] end) ==
    ["attach_workspace", "restore_trivy_cache", "run_trivy", "save_trivy_cache", "store_artifacts"]' >/dev/null
  echo "$output" | jq -e '.[-1].store_artifacts.path == "/tmp/trivy-results.json"' >/dev/null
}

@test "OWASP enabled retains ordered Java Maven NVD scan and report workflow" {
  run resolved_steps true
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '
    map(if type == "string" then . else keys[0] end) ==
    ["attach_workspace", "install_java", "restore_maven_cache", "restore_cache",
     "mvn_owasp", "save_cache", "restore_trivy_cache", "run_trivy", "save_trivy_cache",
     "store_artifacts", "store_artifacts"]' >/dev/null
  echo "$output" | jq -e '
    .[1].install_java.version == "<< parameters.java_version >>" and
    .[3].restore_cache.keys == ["nvd-cache-v1-{{ .Branch }}", "nvd-cache-v1-"] and
    .[5].save_cache.paths == ["~/.dependency-check"] and
    .[9].store_artifacts.path == "target/dependency-check-report.html" and
    .[10].store_artifacts.path == "/tmp/trivy-results.json"' >/dev/null
}

@test "OWASP remains enabled by default" {
  [ "$(yq '.parameters.owasp.default' "$JOB")" = true ]
}
