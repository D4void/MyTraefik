# MyTraefik

A centralized Traefik v3 reverse proxy deployment using Docker Compose, designed to route traffic for multiple containerized applications (Nextcloud, Joplin, ZoneMinder, etc.) with automatic Let's Encrypt SSL certificates.

## 📋 Features

- **Centralized Reverse Proxy**: Single Traefik instance managing routing for all Docker applications
- **Fixed IP Networking**: Predictable container IP for NAT port forwarding from ISP router
- **Automatic HTTPS**: Let's Encrypt TLS-ALPN-01 challenge for automatic certificate management
- **Security Hardened**: TLS 1.2+ with strong cipher suites, HSTS preload, and security headers middleware
- **Hot-Reload Configuration**: Dynamic configuration changes without container restart
- **Multi-Application Support**: Routes traffic for Nextcloud, Joplin, ZoneMinder, and more

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         ISP Router                              │
│   NAT: 80/443/9000/22300 → TRAEFIK_IP (e.g., 192.168.2.2)       │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                     MyTraefikNet (Bridge)                       │
│                   Subnet: 192.168.2.0/24                        │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    Traefik Container                     │   │
│  │              Fixed IP: 192.168.2.2                       │   │
│  │  Ports: 80 (HTTP), 443 (HTTPS), 9000 (ZM), 22300 (Joplin)│   │
│  └──────────────────────────────────────────────────────────┘   │
│                             │                                   │
│    ┌─────────────┬──────────┴────────┬─────────────┐            │
│    ▼             ▼                   ▼             ▼            │
│ Nextcloud     Joplin           ZoneMinder      Other Apps       │
└─────────────────────────────────────────────────────────────────┘
```

### Network Design

- **MyTraefikNet**: Custom bridge network with fixed subnet, marked `attachable: true`
- **Fixed Container IP**: Allows ISP router NAT rules to forward to a predictable address
- **External Connectivity**: Other Docker Compose projects connect via `external: true` network

## Prerequisites

- Docker Engine 20.10+
- Docker Compose v2.x
- A domain name with DNS A records pointing to your public IP
- ISP router with NAT/port forwarding capability

## 🚀 Quick Start

### 1. Clone and Configure

```bash
git clone https://github.com/D4void/MyTraefik.git
cd MyTraefik

# Create and secure environment file
cp env.example .env
chmod 600 .env
```

### 2. Edit Environment Variables

Edit `.env` with your configuration:

```bash
# Traefik image version
TRAEFIK_TAG=v3.6

# Host IP where ports will be bound
HOST_IP=192.168.0.10

# Docker network configuration
SUBNET=192.168.2.0/24
GATEWAY=192.168.2.1
TRAEFIK_IP=192.168.2.2

# Volume paths
TRAEFIK_VOL=/opt/MyTraefik
TRAEFIK_LETSENCRYPT_VOL=/opt/Letsencrypt

# Let's Encrypt email (required)
EMAIL=myname@domain.fr
```

### 3. Initialize Volume Directories

```bash
./init-voldir.sh
```

This script creates the required directory structure and copies the configuration templates.

### 4. Configure Traefik

**Critical**: Edit the static configuration to set your email for Let's Encrypt:

```bash
nano ${TRAEFIK_VOL}/etc/traefik/traefik.toml
```

Update the `email` field in `[certificatesResolvers.mytlschallenge.acme]` section.

### 5. Deploy

```bash
docker compose up -d
```

## ⚙️ Configuration

### Static Configuration (`traefik.toml`)

Located at `${TRAEFIK_VOL}/etc/traefik/traefik.toml`. Changes require container restart.

| Section | Description |
|---------|-------------|
| `[api]` | Dashboard settings (disabled by default for security) |
| `[log]` | Logging configuration |
| `[providers.docker]` | Docker provider with `exposedByDefault = false` |
| `[providers.file]` | File provider for dynamic configuration |
| `[entryPoints]` | Port definitions (web:80, websecure:443, zmevent:9000, joplin:22300) |
| `[certificatesResolvers]` | Let's Encrypt ACME configuration |

### Dynamic Configuration (`traefik_dynamic.toml`)

Located at `${TRAEFIK_VOL}/etc/traefik/dynamic/traefik_dynamic.toml`. Hot-reloaded automatically.

**TLS Options**:
- Minimum TLS 1.2
- Strong cipher suites (ECDHE, ChaCha20-Poly1305, AES-GCM)
- SNI strict mode enabled

**Security Middleware** (`security@file`):
- HSTS with preload (10 years)
- XSS filter enabled
- Content-Type nosniff
- Frame deny / SAMEORIGIN
- Referrer policy: same-origin

## Exposed Ports

| Port  |         Purpose                 | Entrypoint |
|-------|---------------------------------|------------|
| 80    | HTTP (redirects to HTTPS)       | `web`      |
| 443   | HTTPS with TLS termination      | `websecure`|
| 9000  | ZoneMinder event server         | `zmevent`  |
| 9080  | Traefik dashboard (if enabled)  | API        |
| 22300 | Joplin sync server              | `joplin`   |

## Integrating Applications

Other Docker Compose projects can connect to Traefik using the following steps:

### 1. Attach to the Network

```yaml
networks:
  MyTraefikNet:
    external: true
```

### 2. Add Traefik Labels

```yaml
services:
  myapp:
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`app.domain.fr`)"
      - "traefik.http.routers.myapp.entrypoints=websecure"
      - "traefik.http.routers.myapp.tls.certresolver=mytlschallenge"
      - "traefik.http.routers.myapp.middlewares=security@file"
      - "traefik.http.services.myapp.loadbalancer.server.port=8080"
    networks:
      - MyTraefikNet
```

## File Structure

```
MyTraefik/
├── docker-compose.yml           # Main service definition
├── env.example                  # Environment variables template
├── init-voldir.sh               # Volume initialization script
├── LICENSE                      # MIT License
├── README.md                    # This file
└── traefik-config/
    ├── traefik.toml.example     # Static config template
    └── dynamic/
        └── traefik_dynamic.toml # TLS & middleware config
```

## 🐛 Troubleshooting

### Let's Encrypt Certificate Issues

- Ensure the email address is correctly set in `traefik.toml`
- Verify that DNS A records point to your public IP
- Check that ports 80/443 are forwarded through your router
- Use staging CA server for testing: uncomment `caServer` line with staging URL

### Network Conflicts

- Ensure that `SUBNET` does not overlap with existing Docker networks
- Check for conflicts with your LAN subnet
- Run `docker network ls` to list all existing networks

### Dashboard Access

To enable the dashboard (use with caution):

1. Set `dashboard = true` and `insecure = true` in `traefik.toml`
2. Restart the container: `docker compose restart`
3. Access it at `http://${HOST_IP}:9080`

### View Logs

```bash
# Container logs
docker compose logs -f traefik

# Traefik application logs
tail -f ${TRAEFIK_VOL}/log/traefik.log
```

## 🔒 Security Considerations

- **Dashboard**: Disabled by default (`api.insecure = false`). Enable only for debugging.
- **Docker Socket**: Mounted read-only (`:ro`) to limit container privileges
- **Environment File**: Must be `chmod 600` to protect sensitive variables
- **TLS Configuration**: Enforces TLS 1.2+ with modern cipher suites only

## 🔗 Related Projects

This Traefik instance is designed to work with:

- [MyNextCloud](https://github.com/D4void/MyNextCloud) - Nextcloud deployment with Collabora
- [MyJoplin](https://github.com/D4void/MyJoplin) - Joplin sync server
- [Zoneminder](https://github.com/D4void/zoneminder) - Video surveillance system
- [MyDockerApps](https://github.com/D4void/MyDockerApps) - Orchestrator for all services

## 🔗 Links

 - [Traefik](https://traefik.io/traefik)
 - [Traefik documentation](https://doc.traefik.io/traefik/)

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

*This README was initially generated with AI assistance.*
