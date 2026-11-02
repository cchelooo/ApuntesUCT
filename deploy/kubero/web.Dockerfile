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
COPY deploy/kubero/nginx-main.conf /etc/nginx/nginx.conf
COPY deploy/kubero/nginx.conf.template /etc/nginx/templates/default.conf.template
COPY --chmod=755 deploy/kubero/web-entrypoint.sh /usr/local/bin/apuntesuct-web
COPY --from=build /app/web/dist /usr/share/nginx/html
USER nginx
EXPOSE 8080
ENTRYPOINT ["apuntesuct-web"]
