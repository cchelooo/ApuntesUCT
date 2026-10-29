# syntax=docker/dockerfile:1
FROM node:22-bookworm-slim AS build
WORKDIR /app/web
COPY web/package*.json ./
RUN npm ci --no-audit --no-fund
COPY web/ ./
# The browser uses the same origin; Nginx resolves the internal Gateway at runtime.
ENV VITE_API_URL=/api/v1
RUN npm run build

FROM nginx:stable-alpine
ENV GATEWAY_UPSTREAM=http://gateway-kuberoapp:3000
ENV NGINX_ENVSUBST_FILTER=^GATEWAY_UPSTREAM$
COPY deploy/kubero/nginx.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /app/web/dist /usr/share/nginx/html
EXPOSE 8080
