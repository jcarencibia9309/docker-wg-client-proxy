FROM alpine:3.19

# Instala herramientas necesarias: WireGuard, proxies y utilidades
RUN echo "https://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories \
    && echo "https://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories \
    && apk add --no-cache \
      wireguard-tools \
      iptables \
      iproute2 \
      bash \
      tini \
      tinyproxy \
      microsocks \
      tzdata \
      ca-certificates

# Directorio para configuración externa del túnel
ENV WG_CONFIG_PATH=/config/wg0.conf \
    HTTP_PROXY_PORT=3128 \
    SOCKS5_PROXY_PORT=1080 \
    PROXY_USER= \
    PROXY_PASSWORD= \
    TZ=UTC

# Crea estructuras mínimas
RUN mkdir -p /config /run/tinyproxy /var/run \
    && adduser -D -H -s /sbin/nologin proxyusr || true

# Copia el entrypoint
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 3128/tcp 1080/tcp

# Tini para manejar señales correctamente
ENTRYPOINT ["/sbin/tini", "-g", "--", "/usr/local/bin/entrypoint.sh"]
