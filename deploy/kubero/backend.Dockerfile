# syntax=docker/dockerfile:1
FROM node:22-bookworm-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends openssl ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app/backend
COPY backend/package*.json ./
COPY backend/api-gateway/package.json api-gateway/package.json
COPY backend/auth-service/package.json auth-service/package.json
COPY backend/catalog-service/package.json catalog-service/package.json
COPY backend/material-service/package.json material-service/package.json
COPY backend/search-service/package.json search-service/package.json
RUN npm ci --no-audit --no-fund
COPY backend/ ./
# Generate each client's custom output, including Material's workspace-local client.
RUN npm run prisma:generate
ARG SERVICE
RUN case "$SERVICE" in api-gateway|auth-service|catalog-service|material-service|search-service) ;; *) exit 1 ;; esac \
    && npm run build --workspace="$SERVICE" \
    && mkdir -p "$SERVICE/prisma" "$SERVICE/node_modules"

FROM node:22-bookworm-slim AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends openssl ca-certificates \
    && rm -rf /var/lib/apt/lists/*
ENV NODE_ENV=production
ARG SERVICE
ENV SERVICE_NAME=$SERVICE
WORKDIR /app/backend
# Keep the locked Prisma CLIs for migrate deploy; no database access during build.
COPY --from=build --chown=node:node /app/backend/node_modules ./node_modules
COPY --from=build --chown=node:node /app/backend/package*.json ./
COPY --from=build --chown=node:node /app/backend/${SERVICE}/package.json ./${SERVICE}/package.json
COPY --from=build --chown=node:node /app/backend/${SERVICE}/dist ./${SERVICE}/dist
COPY --from=build --chown=node:node /app/backend/${SERVICE}/prisma ./${SERVICE}/prisma
COPY --from=build --chown=node:node /app/backend/${SERVICE}/node_modules ./${SERVICE}/node_modules
COPY --chmod=755 deploy/kubero/backend-entrypoint.sh /usr/local/bin/apuntesuct-start
USER node
WORKDIR /app/backend/${SERVICE}
ENTRYPOINT ["apuntesuct-start"]
