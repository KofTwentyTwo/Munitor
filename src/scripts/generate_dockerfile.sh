#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${FABER_CONFIG:-.faber.yml}"

# When run via CircleCI << include() >>, BASH_SOURCE is empty.
# Fall back to FABER_SCRIPT_DIR set by the command YAML.
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  SCRIPT_DIR="${FABER_SCRIPT_DIR:-/tmp/faber}"
fi

# Source shared helpers
FABER_HELPERS="${FABER_HELPERS:-${SCRIPT_DIR}/faber_helpers.sh}"
# shellcheck source=faber_helpers.sh
if [[ -f "${FABER_HELPERS}" ]]; then source "${FABER_HELPERS}"
elif ! type faber_header &>/dev/null; then
  faber_header() { echo "=== Faber: ${1:-unknown} ==="; }
  faber_check_tool() { command -v "$1" &>/dev/null || { echo "ERROR: $1 not found"; exit 1; }; }
  faber_download_with_retry() { curl -fsSL --retry 3 "$1" -o "$2"; }
fi

faber_header "generate_dockerfile"
faber_check_tool yq --version

if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "ERROR: ${CONFIG_FILE} not found in workspace." >&2
  exit 1
fi

# Source shared variable extraction
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/extract_faber_vars.sh"
extract_faber_vars "${CONFIG_FILE}"

case "${FABER_PIPELINE}" in
  node-api)
    echo "Generating Dockerfile for node-api (node ${FABER_NODE_VERSION}, framework ${FABER_NODE_FRAMEWORK})"

    case "${FABER_NODE_FRAMEWORK}" in
      nextjs)
        # Multi-stage Next.js standalone Dockerfile.
        # Assumes `output: 'standalone'` in next.config.js.
        cat > Dockerfile <<DOCKERFILE
FROM node:${FABER_NODE_VERSION}-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci

FROM node:${FABER_NODE_VERSION}-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV STANDALONE=true
RUN npm run build

FROM node:${FABER_NODE_VERSION}-alpine AS runner
WORKDIR /app
RUN apk update && apk upgrade --no-cache && rm -rf /var/cache/apk/*
# Remove npm/npx and their bundled deps (glob, tar) to reduce attack surface.
# The runner only needs the node binary to execute server.js.
RUN npm cache clean --force && rm -rf /usr/local/lib/node_modules /usr/local/bin/npm /usr/local/bin/npx
RUN addgroup --system --gid 1001 nodejs \\
 && adduser --system --uid 1001 nextjs
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
USER nextjs
EXPOSE 3000
ENV PORT=3000
CMD ["node", "server.js"]
DOCKERFILE
        ;;

      express)
        # Two-stage Express Dockerfile. Uses package.json "main" field via `node .`.
        cat > Dockerfile <<DOCKERFILE
FROM node:${FABER_NODE_VERSION}-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev

FROM node:${FABER_NODE_VERSION}-alpine AS runner
WORKDIR /app
RUN apk update && apk upgrade --no-cache && rm -rf /var/cache/apk/*
RUN npm cache clean --force && rm -rf /usr/local/lib/node_modules /usr/local/bin/npm /usr/local/bin/npx
RUN addgroup --system --gid 1001 nodejs \\
 && adduser --system --uid 1001 appuser -G nodejs
COPY --from=deps /app/node_modules ./node_modules
COPY . .
USER appuser
EXPOSE ${FABER_HEALTH_PORT}
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \\
    CMD wget --no-verbose --tries=1 --spider http://localhost:${FABER_HEALTH_PORT}${FABER_HEALTH_PATH} || exit 1
CMD ["node", "."]
DOCKERFILE
        ;;

      *)
        echo "ERROR: Unsupported node framework '${FABER_NODE_FRAMEWORK}'. Use 'nextjs' or 'express'." >&2
        exit 1
        ;;
    esac
    ;;

  java-webapp)
    echo "Generating Dockerfile for java-webapp (java ${FABER_JAVA_VERSION})"

    # Find the primary application JAR (exclude original-*, sources, javadoc)
    APP_JAR=$(find target -maxdepth 1 -name "*.jar" \
      ! -name "original-*" ! -name "*-sources.jar" ! -name "*-javadoc.jar" \
      2>/dev/null | head -1) || true

    if [[ -z "${APP_JAR}" ]]; then
      echo "ERROR: No application JAR found in target/" >&2
      exit 1
    fi

    echo "Using JAR: ${APP_JAR}"

    cat > Dockerfile <<DOCKERFILE
FROM eclipse-temurin:${FABER_JAVA_VERSION}-jre-alpine

RUN apk update && apk upgrade --no-cache

RUN addgroup -g 1001 -S appgroup && \\
    adduser -u 1001 -S appuser -G appgroup

WORKDIR /app

COPY ${APP_JAR} app.jar

RUN chown -R appuser:appgroup /app

USER appuser

ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+ExitOnOutOfMemoryError"

EXPOSE ${FABER_HEALTH_PORT}

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \\
    CMD wget --no-verbose --tries=1 --spider http://localhost:${FABER_HEALTH_PORT}${FABER_HEALTH_PATH} || exit 1

ENTRYPOINT ["sh", "-c", "java \$JAVA_OPTS -jar app.jar"]
DOCKERFILE
    ;;

  *)
    echo "ERROR: Unsupported pipeline type '${FABER_PIPELINE}' for Dockerfile generation." >&2
    exit 1
    ;;
esac

echo "Dockerfile generated successfully."
