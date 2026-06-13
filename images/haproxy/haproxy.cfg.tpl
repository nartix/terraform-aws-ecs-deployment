global
  log stdout format raw local0
  stats socket /var/run/haproxy.sock mode 600 level admin expose-fd listeners

defaults
  mode http
  log global
  option httplog
  option forwardfor
  timeout connect 5s
  timeout client 60s
  timeout server 60s
  default-server init-addr none check inter 5s fall 3 rise 2

resolvers aws
  nameserver route53 ${ROUTE53_RESOLVER_IP}:53
  accepted_payload_size 8192
  resolve_retries 3
  timeout resolve 1s
  timeout retry 1s
  hold valid 10s
  hold nx 3s
  hold other 3s
  hold refused 3s

frontend public_http
  bind :${HAPROXY_FRONTEND_PORT}
  http-request return status 200 content-type text/plain string ok if { path /_edge_health }
  http-request set-header X-Forwarded-Proto https
  http-request set-header X-Real-IP %[req.hdr(CF-Connecting-IP)] if { req.hdr(CF-Connecting-IP) -m found }
  default_backend app_backend

backend app_backend
  balance roundrobin
  option httpchk GET /health
  server-template app ${HAPROXY_BACKEND_SLOTS} ${APP_DNS_NAME}:${APP_PORT} resolvers aws resolve-prefer ipv4 check init-addr none
