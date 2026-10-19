#!/usr/bin/env bats

setup() {
  ROOT="${BATS_TEST_DIRNAME}/.."
  CONFIG="${BATS_TEST_TMPDIR}/rendered.yml"
}

check_workflows() {
  local expected="$1"
  yq -o=json '.' "$CONFIG" | EXPECTED_COVERAGE="$expected" node -e '
    const assert = require("node:assert/strict");
    const config = JSON.parse(require("node:fs").readFileSync(0,"utf8"));
    for (const [workflow, definition] of Object.entries(config.workflows)) {
      const jobs = definition.jobs.map(entry => {
        const [type, options] = Object.entries(entry)[0];
        assert.ok(!["munitor/mvn_code_quality", "munitor/mvn_coverage"].includes(type));
        return {type, ...options};
      });
      const names = jobs.map(job => job.name);
      assert.equal(new Set(names).size, names.length, workflow);
      const buildName = workflow === "production" ? "production-build-and-test" : "build-and-test";
      const build = jobs.find(job => job.name === buildName);
      assert.ok(build, workflow);
      assert.equal(jobs.filter(job => job.type === "munitor/mvn_build_and_test").length, 1);
      assert.ok(!names.includes(workflow === "production" ? "build-and-test" : "production-build-and-test"));
      const expectedFilter = {
        "pr-checks": ["/feature\\/.*/", "/hotfix\\/.*/"],
        develop: "develop", staging: "staging",
        "release-candidate": ["/release\\/.*/"], production: "main"
      }[workflow];
      assert.deepEqual(build.filters.branches.only, expectedFilter, workflow);
      if (workflow === "production") {
        assert.equal(build.quality_checks, undefined);
        assert.equal(build.min_instruction, undefined);
      } else {
        assert.equal(build.quality_checks, true, workflow);
        assert.equal(String(build.min_instruction), process.env.EXPECTED_COVERAGE, workflow);
        for (const gate of ["secrets-scan", "sast-scan", "security-scan"]) assert.ok(names.includes(gate), workflow);
      }
      for (const job of jobs) {
        assert.deepEqual(job.filters, build.filters, `${workflow}/${job.name} filters`);
        const dependencies = job.requires || [];
        assert.equal(new Set(dependencies).size, dependencies.length, job.name);
        for (const name of dependencies) assert.ok(names.includes(name), `${workflow}/${job.name}: ${name}`);
        if (["image-scan", "security-scan", "e2e-tests", "sonar-scan"].includes(job.name)) assert.ok(dependencies.includes(buildName));
        if (["docker-build-push", "sbom"].includes(job.name)) {
          assert.ok(dependencies.includes(buildName));
          if (workflow !== "production") for (const gate of ["secrets-scan", "sast-scan", "security-scan", "e2e-tests", "sonar-scan"].filter(name => names.includes(name))) assert.ok(dependencies.includes(gate), `${workflow}/${job.name}/${gate}`);
        }
        if (["update-cd-repo", "github-release"].includes(job.name)) assert.ok(dependencies.includes("docker-build-push"));
      }
      if (workflow === "pr-checks") assert.ok(names.includes("image-scan"));
    }
    for (const workflow of ["pr-checks", "develop", "staging", "release-candidate", "production"]) assert.ok(config.workflows[workflow]);
  '
}

@test "full Java workflow folds quality into build and preserves optional gates" {
  MUNITOR_CONFIG="${ROOT}/tests/fixtures/java-webapp.munitor.yml" MUNITOR_OUTPUT_FILE="$CONFIG" bash "${ROOT}/src/scripts/generate_config.sh"
  check_workflows 80
  [ "$(yq '.workflows.develop.jobs[] | .[] | select(.name == "sonar-scan") | .name' "$CONFIG")" = "sonar-scan" ]
}

@test "minimal Java workflow retains default coverage and production behavior" {
  MUNITOR_CONFIG="${ROOT}/tests/fixtures/java-webapp-minimal.munitor.yml" MUNITOR_OUTPUT_FILE="$CONFIG" bash "${ROOT}/src/scripts/generate_config.sh"
  check_workflows 70
}

@test "quality steps finish before workspace persistence and forward coverage threshold" {
  yq -o=json '.' "${ROOT}/src/jobs/mvn_build_and_test.yml" | node -e '
    const assert = require("node:assert/strict");
    const job = JSON.parse(require("node:fs").readFileSync(0,"utf8"));
    assert.equal(job.parameters.quality_checks.default, false);
    assert.equal(job.parameters.min_instruction.default, "70");
    const index = name => job.steps.findIndex(step => step === name || typeof step === "object" && name in step);
    assert.ok(index("mvn_test") < index("when"));
    assert.ok(index("when") < index("persist_to_workspace"));
    const block = job.steps[index("when")].when;
    assert.equal(block.condition, "<< parameters.quality_checks >>");
    const commands = block.steps.map(step => typeof step === "string" ? step : Object.keys(step)[0]);
    assert.deepEqual(commands.slice(0,4), ["mvn_checkstyle", "mvn_spotbugs", "mvn_pmd", "mvn_jacoco"]);
    assert.equal(block.steps[3].mvn_jacoco.min_instruction, "<< parameters.min_instruction >>");
  '
}
