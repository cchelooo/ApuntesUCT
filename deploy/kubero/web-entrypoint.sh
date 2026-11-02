#!/bin/sh
set -eu

: "${GATEWAY_UPSTREAM:?Configura GATEWAY_UPSTREAM}"
envsubst '${GATEWAY_UPSTREAM}' < /etc/nginx/templates/default.conf.template > /tmp/apuntesuct-server.conf
exec nginx -g 'daemon off;'
