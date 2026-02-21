#!/usr/bin/env bash
set -euo pipefail

# Source shared helpers
FABER_HELPERS="${FABER_HELPERS:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/faber_helpers.sh}"
# shellcheck source=faber_helpers.sh
if [[ -f "${FABER_HELPERS}" ]]; then source "${FABER_HELPERS}"
elif ! type faber_header &>/dev/null; then
  faber_header() { echo "=== Munitor: ${1:-unknown} ==="; }
  faber_check_tool() { command -v "$1" &>/dev/null || { echo "ERROR: $1 not found"; exit 1; }; }
  faber_download_with_retry() { curl -fsSL --retry 3 "$1" -o "$2"; }
fi

faber_header "start_services"
faber_check_tool docker --version
faber_check_tool jq --version

SERVICES_JSON="${FABER_SERVICES_JSON:-}"
HEALTH_TIMEOUT="${FABER_HEALTH_TIMEOUT:-60}"
HEALTH_INTERVAL=2

if [[ -z "${SERVICES_JSON}" || "${SERVICES_JSON}" == "[]" ]]; then
  echo "No services to start."
  exit 0
fi

SERVICE_COUNT=$(echo "${SERVICES_JSON}" | jq 'length')
echo "Starting ${SERVICE_COUNT} service container(s)..."

for i in $(seq 0 $((SERVICE_COUNT - 1))); do
  SERVICE=$(echo "${SERVICES_JSON}" | jq -r ".[$i]")
  IMAGE=$(echo "${SERVICE}" | jq -r '.image')
  PORT=$(echo "${SERVICE}" | jq -r '.port')
  HEALTHCHECK=$(echo "${SERVICE}" | jq -r '.healthcheck // ""')
  CMD_OVERRIDE=$(echo "${SERVICE}" | jq -r '.command // ""')

  # Validate required JSON fields are not null/empty
  if [[ -z "${IMAGE}" || "${IMAGE}" == "null" ]]; then
    echo "  ERROR: Service [${i}] is missing required 'image' field."
    echo "  Service JSON: ${SERVICE}"
    exit 1
  fi
  if [[ -z "${PORT}" || "${PORT}" == "null" ]]; then
    echo "  ERROR: Service [${i}] (${IMAGE}) is missing required 'port' field."
    exit 1
  fi

  # Build docker run arguments
  DOCKER_ARGS="-d --name faber-svc-${i} -p ${PORT}:${PORT}"

  # Add environment variables if present
  ENV_KEYS=$(echo "${SERVICE}" | jq -r '.env // {} | keys[]' 2>/dev/null || true)
  for key in ${ENV_KEYS}; do
    val=$(echo "${SERVICE}" | jq -r ".env.${key}")
    DOCKER_ARGS+=" -e ${key}=${val}"
  done

  # Add command override if present
  if [[ -n "${CMD_OVERRIDE}" ]]; then
    DOCKER_ARGS+=" ${IMAGE} ${CMD_OVERRIDE}"
  else
    DOCKER_ARGS+=" ${IMAGE}"
  fi

  echo "  Starting ${IMAGE} on port ${PORT}..."
  # shellcheck disable=SC2086
  docker run ${DOCKER_ARGS}

  # Run health check if specified
  if [[ -n "${HEALTHCHECK}" ]]; then
    echo "  Waiting for health check: ${HEALTHCHECK}"
    ELAPSED=0
    LAST_OUTPUT=""
    while true; do
      # Try docker exec first -- capture output instead of swallowing it
      LAST_OUTPUT=$(docker exec "faber-svc-${i}" sh -c "${HEALTHCHECK}" 2>&1) && {
        echo "  Service ${IMAGE} is healthy."
        break
      }

      EXIT_CODE=$?
      # 126 = permission denied (command not executable in container)
      # 127 = command not found in container
      if [[ ${EXIT_CODE} -eq 126 || ${EXIT_CODE} -eq 127 ]]; then
        # Fall back to host-side execution
        LAST_OUTPUT=$(bash -c "${HEALTHCHECK}" 2>&1) && {
          echo "  Service ${IMAGE} is healthy (host-side check)."
          break
        }
      fi

      ELAPSED=$((ELAPSED + HEALTH_INTERVAL))
      if [[ ${ELAPSED} -ge ${HEALTH_TIMEOUT} ]]; then
        echo "  ERROR: Health check timed out after ${HEALTH_TIMEOUT}s for ${IMAGE}."
        echo "  Last health check output:"
        echo "    ${LAST_OUTPUT}"
        echo "  Container logs (last 20 lines):"
        docker logs "faber-svc-${i}" 2>&1 | tail -20
        exit 1
      fi

      sleep ${HEALTH_INTERVAL}
    done
  fi
done

echo "All service containers started."
