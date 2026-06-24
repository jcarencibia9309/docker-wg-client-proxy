# WireGuard Proxy

A WireGuard client that exposes HTTP and SOCKS5 proxies within the same container. The WireGuard configuration is mounted as a volume, and proxy authentication is optional via environment variables.

## Features
- Runs WireGuard as a client using `wg-quick` and a mounted configuration file (`wg0.conf`).
- HTTP proxy with Tinyproxy and SOCKS5 proxy with Microsocks.
- Optional upstream proxy support: route the WireGuard connection itself through an upstream SOCKS5 or HTTP CONNECT proxy.
- Configurable ports and authentication via environment variables.
- Clean shutdown handling via `tini` signals.

## Docker Hub Image
The published image on Docker Hub is available as:

https://hub.docker.com/r/jcarencibia9309/wg-client-proxy

```bash
docker pull jcarencibia9309/wg-client-proxy
```

## GitHub Repository
Source code and further details are available on GitHub:  
https://github.com/jcarencibia9309/docker-wg-client-proxy

## Requirements
- `/dev/net/tun` device inside the container.
- `NET_ADMIN` capability.
- A valid WireGuard configuration file (e.g., `wg0.conf`).

## Environment Variables

### Outbound proxy (exposed to clients)
- `WG_CONFIG_PATH` (default `/config/wg0.conf`): path to the WireGuard configuration file.
- `HTTP_PROXY_PORT` (default `3128`): Tinyproxy port.
- `SOCKS5_PROXY_PORT` (default `1080`): Microsocks port.
- `PROXY_USER`, `PROXY_PASSWORD` (optional): credentials for both proxies. If not defined, authentication is disabled.
- `TZ` (default `UTC`): container timezone.

### Upstream proxy (for the WireGuard connection itself)
These variables let WireGuard connect to its endpoint *through* an upstream proxy, useful when direct UDP is blocked.

- `UPSTREAM_PROXY_TYPE`: `socks5` or `http`. Leave empty (default) to connect directly.
- `UPSTREAM_PROXY_HOST`: hostname or IP of the upstream proxy.
- `UPSTREAM_PROXY_PORT`: port of the upstream proxy.
- `UPSTREAM_PROXY_USER`, `UPSTREAM_PROXY_PASSWORD` (optional): credentials for the upstream proxy.

> **Note — `socks5` mode**: uses [gost](https://github.com/ginuerzh/gost) to tunnel WireGuard's UDP packets through the upstream SOCKS5 proxy via `UDP ASSOCIATE`. The upstream SOCKS5 server **must support UDP ASSOCIATE** (e.g. sing-box, shadowsocks, dante with UDP). The local WireGuard `Endpoint` is dynamically rewritten to point to gost's local listener.
>
> **Note — `http` mode**: uses [proxyguard](https://codeberg.org/eduVPN/proxyguard) to tunnel WireGuard UDP over an HTTP CONNECT proxy (TCP). This requires a compatible server-side proxyguard instance listening on the WireGuard endpoint.

## Running (Docker CLI)
```bash
docker run -d \
  --name wg-proxy \
  --cap-add NET_ADMIN \
  --device /dev/net/tun:/dev/net/tun \
  --sysctl net.ipv4.conf.all.src_valid_mark=1 \
  --sysctl net.ipv6.conf.all.disable_ipv6=0 \
  --sysctl net.ipv6.conf.default.disable_ipv6=0 \
  --sysctl net.ipv6.conf.lo.disable_ipv6=0 \
  -p 3128:3128 \
  -p 1080:1080 \
  -e TZ="UTC" \
  -v ./config/wg0.conf:/config/wg0.conf:ro \
  --restart unless-stopped \
  jcarencibia9309/wg-client-proxy:latest
```

## Example docker-compose.yml

### Direct connection (no upstream proxy)
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

### Via upstream SOCKS5 proxy
```yaml
services:
  wg-proxy:
    image: jcarencibia9309/wg-client-proxy:latest
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    ports:
      - "3128:3128"
      - "1080:1080"
    environment:
      TZ: "UTC"
      UPSTREAM_PROXY_TYPE: "socks5"
      UPSTREAM_PROXY_HOST: "your-socks5-proxy.example.com"
      UPSTREAM_PROXY_PORT: "1080"
      # UPSTREAM_PROXY_USER: "user"
      # UPSTREAM_PROXY_PASSWORD: "pass"
    volumes:
      - ./config/wg0.conf:/config/wg0.conf:ro
    restart: unless-stopped
```

### Via upstream HTTP CONNECT proxy
```yaml
services:
  wg-proxy:
    image: jcarencibia9309/wg-client-proxy:latest
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    ports:
      - "3128:3128"
      - "1080:1080"
    environment:
      TZ: "UTC"
      UPSTREAM_PROXY_TYPE: "http"
      UPSTREAM_PROXY_HOST: "your-http-proxy.example.com"
      UPSTREAM_PROXY_PORT: "3128"
      # UPSTREAM_PROXY_USER: "user"
      # UPSTREAM_PROXY_PASSWORD: "pass"
    volumes:
      - ./config/wg0.conf:/config/wg0.conf:ro
    restart: unless-stopped
```

---

# WireGuard Configuration
Mount your `wg0.conf` inside the container at the path specified by `WG_CONFIG_PATH` (default `/config/wg0.conf`).

Minimal example `wg0.conf` (reference):
```ini
[Interface]
PrivateKey = <private-key>
Address = 10.0.0.2/32
DNS = 1.1.1.1

[Peer]
PublicKey = <peer-public-key>
Endpoint = vpn.example.com:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
```
