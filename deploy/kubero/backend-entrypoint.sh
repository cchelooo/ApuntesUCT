#!/bin/sh
set -eu

case "$SERVICE_NAME" in
  auth-service|catalog-service|material-service)
    if [ "${MIGRATE_ON_START:-true}" = "true" ]; then
      npm run prisma:deploy
    fi
    ;;
esac

case "$SERVICE_NAME" in
  auth-service|catalog-service) exec node dist/src/main.js ;;
  api-gateway|material-service|search-service) exec node dist/main.js ;;
  *) echo "Servicio no soportado: $SERVICE_NAME" >&2; exit 1 ;;
esac
