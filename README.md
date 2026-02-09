# wireguard-proxy

Cliente WireGuard que expone proxies HTTP y SOCKS5 dentro del mismo contenedor. La configuración de WireGuard se monta como volumen y la autenticación de los proxies es opcional vía variables de entorno.

## Características
- Levanta WireGuard como cliente usando `wg-quick` y un fichero de config montado (`wg0.conf`).
- Proxy HTTP con Tinyproxy y proxy SOCKS5 con Microsocks.
- Puertos y autenticación configurables por variables de entorno.
- Señales manejadas por `tini` para apagado limpio.

## Imagen en Docker Hub
La imagen publicada en Docker Hub está disponible como:

https://hub.docker.com/r/jcarencibia9309/wg-client-proxy

```bash
docker pull jcarencibia9309/wg-client-proxy
```

## Requisitos
- Dispositivo `/dev/net/tun` dentro del contenedor.
- Capacidad `NET_ADMIN`.
- Un fichero de configuración válido de WireGuard (por ejemplo, `wg0.conf`).

## Variables de entorno
- `WG_CONFIG_PATH` (por defecto `/config/wg0.conf`): ruta al fichero de configuración de WireGuard.
- `HTTP_PROXY_PORT` (por defecto `3128`): puerto de Tinyproxy.
- `SOCKS5_PROXY_PORT` (por defecto `1080`): puerto de Microsocks.
- `PROXY_USER`, `PROXY_PASSWORD` (opcionales): credenciales para ambos proxies. Si no se definen, no hay autenticación.
- `TZ` (por defecto `UTC`): zona horaria del contenedor.

## Construcción de la imagen
```bash
# En la raíz del repo
docker build -t wireguard-proxy:latest .
```

## Ejecución (Docker CLI)
Sin autenticación (usando imagen pública):
```bash
docker run -d --name wg-proxy \
  --cap-add=NET_ADMIN \
  --device=/dev/net/tun \
  -p 3128:3128 -p 1080:1080 \
  -v %CD%/config/wg0.conf:/config/wg0.conf:ro \
  -e TZ=UTC \
  jcarencibia9309/wg-client-proxy:latest
```

Con autenticación (usando imagen pública):
```bash
docker run -d --name wg-proxy-auth \
  --cap-add=NET_ADMIN \
  --device=/dev/net/tun \
  -p 8080:3128 -p 1081:1080 \
  -v %CD%/config/wg0.conf:/config/wg0.conf:ro \
  -e PROXY_USER=miusuario -e PROXY_PASSWORD=secreto \
  -e HTTP_PROXY_PORT=3128 -e SOCKS5_PROXY_PORT=1080 \
  jcarencibia9309/wg-client-proxy:latest
```

## docker-compose.yml de ejemplo
```yaml
services:
  wg-proxy:
    image: jcarencibia9309/wg-client-proxy:latest
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    ports:
      - "3128:3128"   # HTTP proxy
      - "1080:1080"   # SOCKS5 proxy
    environment:
      TZ: "UTC"
      # PROXY_USER: "user"
      # PROXY_PASSWORD: "pass"
      # HTTP_PROXY_PORT: "3128"
      # SOCKS5_PROXY_PORT: "1080"
      # WG_CONFIG_PATH: "/config/wg0.conf"
    volumes:
      - ./config/wg0.conf:/config/wg0.conf:ro
    restart: unless-stopped
```

---

# Configuración de WireGuard
Monta tu `wg0.conf` dentro del contenedor en la ruta indicada por `WG_CONFIG_PATH` (por defecto `/config/wg0.conf`).

Ejemplo mínimo de `wg0.conf` (referencia):
```ini
[Interface]
PrivateKey = <clave-privada>
Address = 10.0.0.2/32
DNS = 1.1.1.1

[Peer]
PublicKey = <clave-publica-peer>
Endpoint = vpn.ejemplo.com:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
```

Ajusta las direcciones, claves y endpoint a tu infraestructura.

---

# Seguridad
- Si habilitas autenticación, las credenciales se aplican a ambos proxies (HTTP y SOCKS5).
- Para un "killswitch" (evitar fugas si cae el túnel), se pueden añadir reglas `iptables` opcionales. Abre un issue si deseas que se integre como variable de entorno.
- Para DNS a través del túnel, usa un `DNS` accesible por el peer o ajusta resolv.conf dentro del contenedor.
