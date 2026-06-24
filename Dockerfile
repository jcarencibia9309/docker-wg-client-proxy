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
      ca-certificates \
      curl

# Instala gost (forwarder UDP local → SOCKS5/HTTP upstream)
ARG GOST_VERSION=2.11.5
RUN ARCH=$(uname -m) \
    && case "$ARCH" in \
         x86_64)  GOST_ARCH=amd64 ;; \
         aarch64) GOST_ARCH=arm64 ;; \
         armv7l)  GOST_ARCH=armv7 ;; \
         *) echo "Arquitectura no soportada: $ARCH" && exit 1 ;; \
       esac \
    && curl -fsSL -o /tmp/gost.gz "https://github.com/ginuerzh/gost/releases/download/v${GOST_VERSION}/gost-linux-${GOST_ARCH}-${GOST_VERSION}.gz" \
    && gunzip /tmp/gost.gz \
    && mv /tmp/gost /usr/local/bin/gost \
    && chmod +x /usr/local/bin/gost

# Compila proxyguard (UDP-over-HTTP CONNECT para proxy upstream de tipo HTTP)
RUN apk add --no-cache go git \
    && git clone --depth=1 https://codeberg.org/eduVPN/proxyguard.git /tmp/proxyguard \
    && cd /tmp/proxyguard && go build -o /usr/local/bin/proxyguard ./cmd/proxyguard-client \
    && rm -rf /tmp/proxyguard /root/go \
    && apk del go git

# Directorio para configuración externa del túnel
ENV WG_CONFIG_PATH=/config/wg0.conf \
    HTTP_PROXY_PORT=3128 \
    SOCKS5_PROXY_PORT=1080 \
    PROXY_USER= \
    PROXY_PASSWORD= \
    TZ=UTC \
    UPSTREAM_PROXY_TYPE= \
    UPSTREAM_PROXY_HOST= \
    UPSTREAM_PROXY_PORT= \
    UPSTREAM_PROXY_USER= \
    UPSTREAM_PROXY_PASSWORD=

# Crea estructuras mínimas
RUN mkdir -p /config /run/tinyproxy /var/run \
    && adduser -D -H -s /sbin/nologin proxyusr || true

# Copia el entrypoint
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 3128/tcp 1080/tcp

# Tini para manejar señales correctamente
ENTRYPOINT ["/sbin/tini", "-g", "--", "/usr/local/bin/entrypoint.sh"]
