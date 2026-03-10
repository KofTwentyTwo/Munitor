#!/usr/bin/env bash
set -euo pipefail

# Source shared helpers
MUNITOR_HELPERS="${MUNITOR_HELPERS:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/munitor_helpers.sh}"
# shellcheck source=munitor_helpers.sh
if [[ -f "${MUNITOR_HELPERS}" ]]; then source "${MUNITOR_HELPERS}"
elif ! type munitor_header &>/dev/null; then
  munitor_header() { echo "=== Munitor: ${1:-unknown} ==="; }
  munitor_check_tool() { command -v "$1" &>/dev/null || { echo "ERROR: $1 not found"; exit 1; }; }
  munitor_download_with_retry() { curl -fsSL --retry 3 "$1" -o "$2"; }
fi

HEALTH_PATH="${HEALTH_PATH:-/api/health}"
HEALTH_PORT="${HEALTH_PORT:-3000}"
HEALTH_DB="${HEALTH_DB:-false}"
HEALTH_MIGRATIONS="${HEALTH_MIGRATIONS:-}"
HEALTH_SMOKE_PATHS="${HEALTH_SMOKE_PATHS:-}"

# DOCKER_IMAGE and DOCKER_TAG are exported to BASH_ENV by docker_build.sh
IMAGE="${DOCKER_IMAGE:?DOCKER_IMAGE not set -- run docker_build first}"
TAG="${DOCKER_TAG:?DOCKER_TAG not set -- run docker_build first}"

CONTAINER_NAME="munitor-health-check-$$"
DB_CONTAINER_NAME="munitor-health-db-$$"
NETWORK_NAME="munitor-health-net-$$"

munitor_header "health_check (${IMAGE}:${TAG})"
echo "Endpoint: GET http://localhost:${HEALTH_PORT}${HEALTH_PATH}"

# Always clean up containers and network on exit
cleanup() {
  echo "Cleaning up containers..."
  docker rm -f "${CONTAINER_NAME}" &>/dev/null || true
  if [[ "${HEALTH_DB}" == "true" ]]; then
    docker rm -f "${DB_CONTAINER_NAME}" &>/dev/null || true
    docker network rm "${NETWORK_NAME}" &>/dev/null || true
  fi
}
trap cleanup EXIT

# --- PostgreSQL sidecar setup ---
if [[ "${HEALTH_DB}" == "true" ]]; then
  echo "Starting PostgreSQL sidecar for database-dependent health check..."

  docker network create "${NETWORK_NAME}"

  docker run -d \
    --name "${DB_CONTAINER_NAME}" \
    --network "${NETWORK_NAME}" \
    -e POSTGRES_USER=postgres \
    -e POSTGRES_PASSWORD=postgres \
    -e POSTGRES_DB=postgres \
    postgres:17-alpine

  echo "Waiting for PostgreSQL to be ready..."
  for i in $(seq 1 20); do
    if docker exec "${DB_CONTAINER_NAME}" pg_isready -U postgres &>/dev/null; then
      echo "PostgreSQL is ready."
      break
    fi
    if [[ "${i}" -eq 20 ]]; then
      echo "ERROR: PostgreSQL did not become ready in time."
      exit 1
    fi
    sleep 1
  done

  # Run migrations if a migrations image is specified
  if [[ -n "${HEALTH_MIGRATIONS}" ]]; then
    MIGRATIONS_IMAGE="${DOCKER_IMAGE}-${HEALTH_MIGRATIONS}:${TAG}"
    echo "Running migrations image: ${MIGRATIONS_IMAGE}"
    docker run --rm \
      --name "munitor-health-migrations-$$" \
      --network "${NETWORK_NAME}" \
      -e RDBMS_HOSTNAME="${DB_CONTAINER_NAME}" \
      -e RDBMS_PORT=5432 \
      -e RDBMS_DATABASE_NAME=postgres \
      -e RDBMS_USERNAME=postgres \
      -e RDBMS_PASSWORD=postgres \
      -e LB_CONTEXTS=dev \
      "${MIGRATIONS_IMAGE}"
    echo "Migrations completed."
  fi

  # Start app container on the same network with DB env vars
  docker run -d \
    --name "${CONTAINER_NAME}" \
    --network "${NETWORK_NAME}" \
    -p "${HEALTH_PORT}:${HEALTH_PORT}" \
    -e LIQUIBASE_USERNAME=postgres \
    -e LIQUIBASE_PASSWORD=postgres \
    -e LIQUIBASE_CREATE_DATABASE=true \
    -e LB_CONTEXTS=dev \
    -e RDBMS_HOSTNAME="${DB_CONTAINER_NAME}" \
    -e RDBMS_PORT=5432 \
    -e RDBMS_VENDOR=postgresql \
    -e RDBMS_DATABASE_NAME=postgres \
    -e RDBMS_USERNAME=postgres \
    -e RDBMS_PASSWORD=postgres \
    -e PG_HOST="${DB_CONTAINER_NAME}" \
    -e PG_PORT=5432 \
    -e PG_USER=postgres \
    -e PG_PASSWORD=postgres \
    -e PG_DATABASE=postgres \
    -e PG_SSL=false \
    "${IMAGE}:${TAG}"
else
  # Start the container without database
  docker run -d \
    --name "${CONTAINER_NAME}" \
    -p "${HEALTH_PORT}:${HEALTH_PORT}" \
    "${IMAGE}:${TAG}"
fi

# Retry loop: 20 attempts, 3s delay (60s max startup window)
MAX_ATTEMPTS=20
DELAY=3
HEALTHY=false

for attempt in $(seq 1 "${MAX_ATTEMPTS}"); do
  echo "Health check attempt ${attempt}/${MAX_ATTEMPTS}..."

  HTTP_CODE=$(curl -s -o /tmp/health_response.txt -w "%{http_code}" \
    "http://localhost:${HEALTH_PORT}${HEALTH_PATH}" 2>/dev/null || echo "000")

  if [[ "${HTTP_CODE}" == "200" ]]; then
    BODY=$(cat /tmp/health_response.txt)
    echo "Health check PASSED (HTTP ${HTTP_CODE}, body: ${BODY})"
    HEALTHY=true
    break
  else
    echo "HTTP ${HTTP_CODE} (not ready)"
  fi

  if [[ "${attempt}" -lt "${MAX_ATTEMPTS}" ]]; then
    sleep "${DELAY}"
  fi
done

if [[ "${HEALTHY}" != "true" ]]; then
  echo ""
  echo "ERROR: Health check FAILED after ${MAX_ATTEMPTS} attempts ($(( MAX_ATTEMPTS * DELAY ))s)"
  echo "Expected: GET ${HEALTH_PATH} -> HTTP 200"
  echo ""
  echo "--- Container logs (last 50 lines) ---"
  docker logs --tail 50 "${CONTAINER_NAME}" 2>&1 || true
  echo "--- End container logs ---"
  exit 1
fi

# --- API smoke tests ---
if [[ -n "${HEALTH_SMOKE_PATHS}" ]]; then
  echo ""
  echo "Running API smoke tests..."
  SMOKE_FAILED=false

  IFS=',' read -ra SMOKE_ENDPOINTS <<< "${HEALTH_SMOKE_PATHS}"
  for endpoint in "${SMOKE_ENDPOINTS[@]}"; do
    endpoint=$(echo "${endpoint}" | xargs)  # trim whitespace
    SMOKE_URL="http://localhost:${HEALTH_PORT}${endpoint}"
    echo "  Smoke test: GET ${endpoint}"

    SMOKE_CODE=$(curl -s -o /tmp/smoke_response.txt -w "%{http_code}" "${SMOKE_URL}" 2>/dev/null || echo "000")

    if [[ "${SMOKE_CODE}" == "200" ]]; then
      echo "    PASSED (HTTP ${SMOKE_CODE})"
    else
      BODY=$(cat /tmp/smoke_response.txt 2>/dev/null || echo "")
      echo "    FAILED (HTTP ${SMOKE_CODE})"
      echo "    Response: ${BODY:0:500}"
      SMOKE_FAILED=true
    fi
  done

  if [[ "${SMOKE_FAILED}" == "true" ]]; then
    echo ""
    echo "ERROR: API smoke tests FAILED"
    echo ""
    echo "--- Container logs (last 50 lines) ---"
    docker logs --tail 50 "${CONTAINER_NAME}" 2>&1 || true
    echo "--- End container logs ---"
    exit 1
  fi

  echo "All smoke tests PASSED."
fi
