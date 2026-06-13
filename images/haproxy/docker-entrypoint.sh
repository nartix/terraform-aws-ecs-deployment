#!/usr/bin/env sh
set -eu

: "${APP_DNS_NAME:=app.ecs.internal}"
: "${APP_PORT:=8080}"
: "${HAPROXY_FRONTEND_PORT:=8080}"
: "${HAPROXY_BACKEND_SLOTS:=20}"
: "${ROUTE53_RESOLVER_IP:=169.254.169.253}"
: "${HAPROXY_CONFIG_B64:=}"

if [ -n "$HAPROXY_CONFIG_B64" ]; then
  printf '%s' "$HAPROXY_CONFIG_B64" | base64 -d > /usr/local/etc/haproxy/haproxy.cfg
else
  envsubst '${APP_DNS_NAME} ${APP_PORT} ${HAPROXY_FRONTEND_PORT} ${HAPROXY_BACKEND_SLOTS} ${ROUTE53_RESOLVER_IP}' \
    < /usr/local/etc/haproxy/haproxy.cfg.tpl \
    > /usr/local/etc/haproxy/haproxy.cfg
fi

exec "$@"
