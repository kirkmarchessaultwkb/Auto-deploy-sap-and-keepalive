# Configuration Examples for CPU Optimization

This document provides specific configuration examples for sing-box, Xray, and Cloudflared to achieve the CPU optimization target of 40-50%.

---

## 1. Optimized Xray Configuration (xray.json)

### Minimal High-Performance Configuration

```json
{
  "log": {
    "loglevel": "warning",
    "access": ""
  },
  "inbounds": [
    {
      "port": 8080,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "YOUR-UUID-HERE",
            "level": 1,
            "alterId": 0
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/ws",
          "connectionReuse": true,
          "maxEarlyData": 2048,
          "earlyDataHeaderName": "Sec-WebSocket-Protocol"
        }
      },
      "sockopt": {
        "tcpFastOpen": true,
        "tcpKeepAliveInterval": 60
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct",
      "settings": {
        "domainStrategy": "AsIs",
        "redirect": "",
        "fragment": {
          "packets": "tlshello",
          "length": "100-200",
          "interval": "10-20"
        }
      },
      "streamSettings": {
        "sockopt": {
          "tcpFastOpen": true,
          "tcpKeepAliveInterval": 60,
          "tcpRcvBuf": 32768,
          "tcpSndBuf": 32768
        }
      }
    },
    {
      "protocol": "blackhole",
      "tag": "blocked"
    }
  ],
  "dns": {
    "servers": [
      "8.8.8.8:53",
      {
        "address": "1.1.1.1",
        "port": 53
      }
    ],
    "queryStrategy": "UseIp",
    "cacheStrategy": "CacheAll"
  },
  "routing": {
    "domainStrategy": "PPre",
    "domainMatcher": "mph",
    "rules": [
      {
        "type": "field",
        "domain": [
          "geosite:private"
        ],
        "outbound": "blocked"
      },
      {
        "type": "field",
        "ip": [
          "geoip:private"
        ],
        "outbound": "direct"
      }
    ]
  }
}
```

### Configuration Explanation

| Setting | Reason |
|---------|--------|
| `"loglevel": "warning"` | Reduce logging overhead; only show warnings/errors |
| `"access": ""` | Disable access logging completely |
| `"alterId": 0` | Modern VMess format; reduces compatibility issues |
| `"connectionReuse": true` | Reuse connections; reduce connection overhead |
| `"tcpFastOpen": true` | Speed up TCP connections |
| `"tcpKeepAliveInterval": 60` | Prevent dead connections; 60s is good for ARM |
| `"tcpRcvBuf": 32768` | Receive buffer for ARM (32KB) |
| `"tcpSndBuf": 32768` | Send buffer for ARM (32KB) |
| `"domainStrategy": "AsIs"` | Don't force DNS; faster resolution |
| `"queryStrategy": "UseIp"` | More efficient DNS queries |

---

## 2. Optimized Cloudflared Configuration

### Configuration File: `/etc/cloudflared/config.yml`

```yaml
# ============================================================================
# Optimized Cloudflared Configuration for Low Resource Usage
# ============================================================================

# Tunnel configuration
tunnel: YOUR-TUNNEL-ID
credentials-file: /etc/cloudflared/cert.pem

# ============================================================================
# Main Ingress Configuration
# ============================================================================
ingress:
  # Primary route to sing-box
  - hostname: your-domain.com
    service: http://localhost:8080
    http-timeout: 30s
    websocket-timeout: 30s
    origin-request:
      connectTimeout: 30s
      noTLSVerify: false
      http2Origin: false

  # API endpoint (if separate)
  - hostname: api.your-domain.com
    service: http://localhost:8888
    http-timeout: 30s

  # Fallback 404 response
  - service: http_status:404

# ============================================================================
# Connection & Performance Optimization
# ============================================================================

# DNS queries - use public resolvers (faster than local)
dns: "1.1.1.1"

# Protocol configuration
protocol: http2

# Connection pool optimization
max-idle-connections: 10

# Timeout settings for better resource usage
http-timeout: 30s
websocket-timeout: 30s
grace-period: 30s
keepalive-timeout: 30s
keepalive-interval: 30s

# ============================================================================
# Logging & Observability (Reduced for Performance)
# ============================================================================

# Log level: "debug", "info", "warn", "error"
# Use "warn" or "error" for production to reduce I/O
loglevel: warn

# Logging formatter
log-format: json

# ============================================================================
# Network Optimization
# ============================================================================

# Disable QUIC if not needed (QUIC has higher overhead on ARM)
no-quic: true

# HTTP version
http-host-header: ""

# Limit simultaneous connections
# Adjust based on your resource constraints
max-fetch-size: 4294967296

# ============================================================================
# Additional Performance Tweaks
# ============================================================================

# Reduce TLS handshake overhead
tls-timeout: 30s

# Heartbeat for connection keep-alive
heartbeat-interval: 30s

# Disable metrics if not needed
# metrics: 0.0.0.0:6060  # Comment out to disable

# Auto update
autoupdate-freq: 24h
```

### Command-Line Alternative

If using systemd service, start Cloudflared with:

```bash
ExecStart=/usr/local/bin/cloudflared tunnel \
  --config /etc/cloudflared/config.yml \
  --loglevel warn \
  --metrics 0.0.0.0:6060
```

### Environment Variables

If using environment-based configuration:

```bash
export CLOUDFLARED_TUNNEL="YOUR-TUNNEL-ID"
export CLOUDFLARED_CREDENTIALS_FILE="/etc/cloudflared/cert.pem"
export CLOUDFLARED_LOGLEVEL="warn"
export CLOUDFLARED_MAX_IDLE_CONNECTIONS="10"
export CLOUDFLARED_HTTP_TIMEOUT="30s"
export CLOUDFLARED_NO_QUIC="true"

cloudflared tunnel run
```

---

## 3. Optimized Sing-box Configuration

### Base Configuration Template

```json
{
  "log": {
    "level": "warn",
    "timestamp": true,
    "disable": false
  },
  "inbounds": [
    {
      "type": "vmess",
      "listen": "0.0.0.0",
      "listen_port": 8080,
      "users": [
        {
          "uuid": "YOUR-UUID-HERE",
          "alt_id": 0,
          "email": "user@example.com"
        }
      ],
      "transport": {
        "type": "ws",
        "path": "/ws",
        "headers": {
          "Host": "your-domain.com"
        }
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    }
  ],
  "route": {
    "auto_detect_interface": true,
    "rules": [
      {
        "rule_set": [
          "geosite-private"
        ],
        "outbound": "block"
      }
    ]
  },
  "experimental": {
    "cache": {
      "enabled": true,
      "cache_file": "/dev/shm/sing-box.cache",
      "stores": [
        "memory",
        "file"
      ]
    }
  }
}
```

---

## 4. Docker Environment Variables for sing-box

### Recommended Environment Variables

```bash
# Core configuration
UUID=YOUR-UUID-HERE
ARGO_DOMAIN=your-domain.com
ARGO_AUTH=YOUR-ARGO-AUTH-TOKEN
SUB_PATH=sub
ARGO_PORT=8001

# Optimization-related variables
LOG_LEVEL=warning
HEALTH_CHECK_INTERVAL=30
REPORT_DELAY=60000

# Monitoring
NEZHA_SERVER=nezha.your-domain.com:8008
NEZHA_KEY=YOUR-NEZHA-SECRET
NEZHA_PORT=8008

# Notifications
CHAT_ID=YOUR-TELEGRAM-CHAT-ID
BOT_TOKEN=YOUR-TELEGRAM-BOT-TOKEN

# Direct connection (if not using Argo)
CFIP=cf.877774.xyz
CFPORT=443

# Custom Docker image (optional)
DOCKER_IMAGE=ghcr.io/eooce/nodejs:main
```

### Docker Run Command with Optimization

```bash
docker run -d \
  --name sing-box \
  --restart unless-stopped \
  -e UUID="YOUR-UUID" \
  -e LOG_LEVEL="warning" \
  -e HEALTH_CHECK_INTERVAL="30" \
  -e REPORT_DELAY="60000" \
  -e NEZHA_SERVER="nezha.your-domain.com:8008" \
  -e NEZHA_KEY="YOUR-KEY" \
  -p 8080:8080 \
  -p 8001:8001 \
  --cpus="1" \
  --memory="256m" \
  --memory-swap="256m" \
  --pids-limit="100" \
  ghcr.io/eooce/nodejs:main
```

### Docker Compose with Optimization

```yaml
version: '3.8'

services:
  sing-box:
    image: ghcr.io/eooce/nodejs:main
    container_name: sing-box
    restart: unless-stopped
    environment:
      UUID: YOUR-UUID-HERE
      LOG_LEVEL: warning
      HEALTH_CHECK_INTERVAL: "30"
      REPORT_DELAY: "60000"
      NEZHA_SERVER: nezha.your-domain.com:8008
      NEZHA_KEY: YOUR-NEZHA-SECRET
      ARGO_DOMAIN: your-domain.com
      ARGO_AUTH: YOUR-ARGO-AUTH
      SUB_PATH: sub
    ports:
      - "8080:8080"
      - "8001:8001"
    resources:
      limits:
        cpus: '1'
        memory: 256M
      reservations:
        cpus: '0.5'
        memory: 128M
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        labels: "service=sing-box"
    networks:
      - sing-box-network

networks:
  sing-box-network:
    driver: bridge
```

---

## 5. Nezha Client Optimization

### Client Configuration Format

#### TOML Format (nezha.toml)

```toml
[client]
server = "nezha.your-domain.com:8008"
secret = "YOUR-NEZHA-CLIENT-SECRET"

# ============================================================================
# Optimization Settings
# ============================================================================

# Report interval in milliseconds (optimized from 5000 to 60000)
report_delay = 60000

# System sampling interval in milliseconds
sample_rate = 3000

# Enable CPU info reporting
report_cpu = true

# Enable memory info reporting  
report_mem = true

# Enable disk info reporting (can be disabled on low resource devices)
report_disk = true

# Enable network info reporting
report_net = true

# Disable GPU monitoring (not relevant for servers)
report_gpu = false

# Process monitoring (disable if not needed)
report_proc = false

# Temperature monitoring (disable if not available)
report_temp = false

# Customize hostname/name for display
hostname = "sing-box-arm"

# Max retries for failed connections
max_retries = 3

# Retry interval in milliseconds
retry_interval = 5000

# TLS verification
insecure = false

# Skip certificate verification (not recommended)
# insecure_tls = true
```

#### Environment Variables for Nezha

```bash
# v1 format
NZ_SERVER="nezha.your-domain.com:8008"
NZ_CLIENT_SECRET="YOUR-CLIENT-SECRET"

# Reporting intervals in milliseconds
NZ_REPORT_DELAY="60000"
NZ_SAMPLE_RATE="3000"

# What to report
NZ_REPORT_CPU="true"
NZ_REPORT_MEM="true"
NZ_REPORT_DISK="true"
NZ_REPORT_NET="true"
NZ_REPORT_PROC="false"
NZ_REPORT_GPU="false"

# Display name
NZ_NAME="sing-box-arm"
```

---

## 6. System-Level Optimization (sysctl)

### Optimized sysctl Configuration

Create or edit `/etc/sysctl.d/99-sing-box-optimize.conf`:

```bash
# ============================================================================
# Network Optimization
# ============================================================================

# TCP connection reuse for faster reconnections
net.ipv4.tcp_tw_reuse = 1

# Reduce TIME_WAIT timeout
net.ipv4.tcp_fin_timeout = 15

# TCP connection queue
net.ipv4.tcp_max_syn_backlog = 2048

# Increase file descriptor limit
fs.file-max = 1000000

# Network buffer optimization
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728

# ============================================================================
# Memory Optimization
# ============================================================================

# Reduce cache pressure (lower = keep more cache)
vm.vfs_cache_pressure = 50

# Adjust memory overcommit
vm.overcommit_memory = 1

# Memory swappiness (lower = less swapping to disk)
vm.swappiness = 10

# ============================================================================
# Process Optimization
# ============================================================================

# Max number of open file descriptors
fs.nr_open = 2097152

# Increase inotify watches for file monitoring
fs.inotify.max_user_watches = 524288
```

### Apply Configuration

```bash
sysctl -p /etc/sysctl.d/99-sing-box-optimize.conf

# Verify settings
sysctl fs.file-max
sysctl net.ipv4.tcp_tw_reuse
sysctl vm.swappiness
```

---

## 7. Systemd Service Configuration

### Service File: `/etc/systemd/system/sing-box.service`

```ini
[Unit]
Description=sing-box Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/data

# CPU Optimization: Run with reduced priority
ExecStartPre=/bin/sh -c 'echo "Starting optimized sing-box..."'
ExecStart=/bin/sh -c 'nice -n 10 ionice -c3 /usr/local/bin/sing-box run -c /etc/sing-box/config.json'
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=10

# Resource limits for ARM devices
MemoryMax=256M
MemoryHigh=200M
CPUQuota=80%
TasksMax=100

# Security and isolation
NoNewPrivileges=true
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=sing-box

# Process management
KillMode=mixed
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
```

### Enable and Start Service

```bash
systemctl daemon-reload
systemctl enable sing-box.service
systemctl start sing-box.service

# Check status
systemctl status sing-box.service
journalctl -u sing-box -f --no-pager
```

---

## 8. Quick Start: All-in-One Optimization Script

```bash
#!/bin/bash

# Apply all optimizations at once

# 1. System sysctl optimization
echo "Applying sysctl optimizations..."
sysctl -w vm.vfs_cache_pressure=50
sysctl -w net.ipv4.tcp_tw_reuse=1
sysctl -w vm.swappiness=10

# 2. Prepare directories
mkdir -p /etc/sing-box /var/log/sing-box /etc/cloudflared

# 3. Use optimized startup script
echo "Installing optimized startup script..."
cp optimized-start.sh /app/start.sh
chmod +x /app/start.sh

# 4. Use optimized keepalive
echo "Installing optimized keepalive..."
cp keep-optimized.sh /usr/local/bin/keep-sap.sh
chmod +x /usr/local/bin/keep-sap.sh

# 5. Check and display current resource usage
echo "Current resource usage:"
top -bn1 | head -3
ps aux | grep -E "sing-box|cloudflared|nezha" | grep -v grep

echo "✅ All optimizations applied!"
```

---

## Performance Verification

After applying these configurations:

```bash
# Monitor CPU in real-time
watch -n 1 'ps aux | grep "[s]ing-box" | awk "{print \$3, \$4, \$11}"'

# Check memory usage
ps aux | grep -E "[s]ing-box|[c]loudflared" | awk '{print $11, "- CPU: " $3 "%, MEM: " $4 "%"}'

# Monitor network connections
ss -tan | grep ESTABLISHED | wc -l

# Check process priority
ps -eo pid,cmd,nice,cls | grep sing-box
```

---

## Rollback Instructions

If you need to revert optimizations:

```bash
# Restore default sysctl
sysctl vm.vfs_cache_pressure=100
sysctl net.ipv4.tcp_tw_reuse=0
sysctl vm.swappiness=60

# Use original startup script
cp keep.sh /app/start.sh

# Restart services
systemctl restart sing-box.service
```

---

## Notes

- All configurations maintain full compatibility with ARM architecture
- VMess-WS protocol unaffected by these optimizations
- Subscription generation remains identical
- Argo tunnel configuration unchanged
- All environment variables work as before
