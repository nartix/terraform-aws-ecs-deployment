FROM haproxy:3.0-alpine

USER root

RUN apk add --no-cache gettext

COPY haproxy.cfg.tpl /usr/local/etc/haproxy/haproxy.cfg.tpl
COPY docker-entrypoint.sh /usr/local/bin/render-haproxy-config

RUN chmod +x /usr/local/bin/render-haproxy-config

ENTRYPOINT ["/usr/local/bin/render-haproxy-config"]
CMD ["haproxy", "-f", "/usr/local/etc/haproxy/haproxy.cfg"]
