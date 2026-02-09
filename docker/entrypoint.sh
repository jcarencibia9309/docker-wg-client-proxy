#!/usr/bin/env bash
set -Eeuo pipefail

WG_CONFIG_PATH=${WG_CONFIG_PATH:-/config/wg0.conf}
HTTP_PROXY_PORT=${HTTP_PROXY_PORT:-3128}
SOCKS5_PROXY_PORT=${SOCKS5_PROXY_PORT:-1080}
PROXY_USER=${PROXY_USER:-}
PROXY_PASSWORD=${PROXY_PASSWORD:-}
TZ=${TZ:-UTC}

cleanup() {
  echo "[entrypoint] Caught signal, shutting down..."
  # Intenta parar los servicios ordenadamente
  if pidof microsocks >/dev/null 2>&1; then killall microsocks || true; fi
  if pidof tinyproxy >/dev/null 2>&1; then killall tinyproxy || true; fi
  # Baja el túnel si está levantado
  if ip link show wg0 >/dev/null 2>&1; then
    echo "[entrypoint] Bringing down WireGuard (wg-quick down)"
    wg-quick down "$WG_CONFIG_PATH" || true
  fi
}
trap cleanup TERM INT EXIT

# Validaciones básicas
if [[ ! -e /dev/net/tun ]]; then
  echo "[entrypoint][ERROR] /dev/net/tun no existe. Debes ejecutar el contenedor con --cap-add=NET_ADMIN --device=/dev/net/tun"
  exit 1
fi

if [[ ! -f "$WG_CONFIG_PATH" ]]; then
  echo "[entrypoint][ERROR] No se encontró el fichero de configuración de WireGuard en $WG_CONFIG_PATH"
  exit 1
fi

# Zona horaria
if [[ -n "$TZ" && -f "/usr/share/zoneinfo/$TZ" ]]; then
  ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" > /etc/timezone || true
fi

# Asegura que IPv6 esté habilitado si el config incluye rutas IPv6 (::/0, etc.)
if [[ -f /proc/sys/net/ipv6/conf/all/disable_ipv6 ]]; then
  if [[ "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6)" != "0" ]]; then
    echo "[entrypoint] Enabling IPv6 in container namespace"
    sysctl -w net.ipv6.conf.all.disable_ipv6=0 || true
    sysctl -w net.ipv6.conf.default.disable_ipv6=0 || true
    # Algunas distros requieren también habilitar en lo y futuras ifaces
    sysctl -w net.ipv6.conf.lo.disable_ipv6=0 || true
  fi
fi

# Levanta WireGuard
echo "[entrypoint] Starting WireGuard using $WG_CONFIG_PATH"
wg-quick up "$WG_CONFIG_PATH"

# Tinyproxy config
TINYCONF=/etc/tinyproxy/tinyproxy.conf
mkdir -p /run/tinyproxy

# Genera configuración mínima controlada por ENV
cat > "$TINYCONF" <<EOF
User nobody
Group nogroup
Port $HTTP_PROXY_PORT
Listen 0.0.0.0
Timeout 600
DefaultErrorFile "/usr/share/tinyproxy/default.html"
StatFile "/usr/share/tinyproxy/stats.html"
LogLevel Info
PidFile "/run/tinyproxy/tinyproxy.pid"
MaxClients 100
MinSpareServers 5
MaxSpareServers 20
StartServers 10
Allow 0.0.0.0/0
EOF

# Autenticación opcional para HTTP proxy
if [[ -n "$PROXY_USER" && -n "$PROXY_PASSWORD" ]]; then
  echo "BasicAuth $PROXY_USER $PROXY_PASSWORD" >> "$TINYCONF"
  echo "[entrypoint] Tinyproxy: autenticación BASIC habilitada"
else
  echo "[entrypoint] Tinyproxy: autenticación deshabilitada"
fi

# Inicia Tinyproxy
echo "[entrypoint] Starting Tinyproxy on 0.0.0.0:$HTTP_PROXY_PORT"
tinyproxy -d &
TP_PID=$!

# Construye flags para microsocks (SOCKS5)
MS_FLAGS=( -i 0.0.0.0 -p "$SOCKS5_PROXY_PORT" )
if [[ -n "$PROXY_USER" && -n "$PROXY_PASSWORD" ]]; then
  MS_FLAGS+=( -u "$PROXY_USER" -P "$PROXY_PASSWORD" )
fi

echo "[entrypoint] Starting Microsocks on 0.0.0.0:$SOCKS5_PROXY_PORT"
microsocks "${MS_FLAGS[@]}" &
MS_PID=$!

# Salida informativa
echo "[entrypoint] Proxies en ejecución: HTTP=$HTTP_PROXY_PORT, SOCKS5=$SOCKS5_PROXY_PORT"
if [[ -n "$PROXY_USER" && -n "$PROXY_PASSWORD" ]]; then
  echo "[entrypoint] Credenciales: usuario='$PROXY_USER'"
fi

# Espera a los procesos hijos
wait -n $TP_PID $MS_PID
EXIT_CODE=$?

# Si uno de los procesos terminó, sal con ese código (tini gestionará señales)
exit $EXIT_CODE
