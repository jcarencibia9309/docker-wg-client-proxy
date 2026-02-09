# WireGuard Proxy

A WireGuard client that exposes HTTP and SOCKS5 proxies within the same container. The WireGuard configuration is mounted as a volume, and proxy authentication is optional via environment variables.

## Features
- Runs WireGuard as a client using `wg-quick` and a mounted configuration file (`wg0.conf`).
- HTTP proxy with Tinyproxy and SOCKS5 proxy with Microsocks.
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
- `WG_CONFIG_PATH` (default `/config/wg0.conf`): path to the WireGuard configuration file.
- `HTTP_PROXY_PORT` (default `3128`): Tinyproxy port.
- `SOCKS5_PROXY_PORT` (default `1080`): Microsocks port.
- `PROXY_USER`, `PROXY_PASSWORD` (optional): credentials for both proxies. If not defined, authentication is disabled.
- `TZ` (default `UTC`): container timezone.

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
