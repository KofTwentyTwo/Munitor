#!/usr/bin/env bats

setup() {
  export PROJECT_DIR="${BATS_TEST_DIRNAME}/.."
  export WORK="${BATS_TEST_TMPDIR}/work"
  mkdir -p "${WORK}/bin"
  export BASH_ENV="${WORK}/bash-env" JAVA_VERSION=21
  export APT_CALLS="${WORK}/apt-calls"
  cat > "${WORK}/bin/sudo" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == env ]]; then
  [[ "$2" == DEBIAN_FRONTEND=noninteractive && "$3" == NEEDRESTART_MODE=a && "$4" == apt-get ]] || exit 2
  printf '%s\n' "$*" >> "$APT_CALLS"
elif [[ "$1" == tee ]]; then
  cat > /dev/null
fi
MOCK
  printf '#!/usr/bin/env bash\necho key\n' > "${WORK}/bin/curl"
  printf '#!/usr/bin/env bash\necho amd64\n' > "${WORK}/bin/dpkg"
  printf '#!/usr/bin/env bash\necho java-version-21\n' > "${WORK}/bin/java"
  chmod +x "${WORK}/bin/"*
  export PATH="${WORK}/bin:${PATH}"
}

@test "APT update and Java installation cannot open an interactive restart prompt" {
  run bash "${PROJECT_DIR}/src/scripts/install_java.sh"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$APT_CALLS")" -eq 2 ]
  grep -q 'apt-get update -qq' "$APT_CALLS"
  grep -q 'apt-get install -y -qq temurin-21-jdk' "$APT_CALLS"
  grep -q "export JAVA_HOME='/usr/lib/jvm/temurin-21-jdk-amd64'" "$BASH_ENV"
}
