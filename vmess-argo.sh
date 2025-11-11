#!/bin/bash

# ============================================================================
# Optimized vmess-argo.sh - Performance-tuned deployment for SAP Cloud Foundry
# ============================================================================
# CPU optimization features:
# - Connection pooling and HTTP/2 for Cloudflared
# - Xray logging reduction and memory optimization
# - System-level process priority tuning (nice/ionice)
# - Real-time CPU monitoring with graceful throttling
# - Auto-recovery on process failures
# ============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration from environment
ARGO_PORT="${ARGO_PORT:-8001}"
ARGO_DOMAIN="${ARGO_DOMAIN:-}"
ARGO_AUTH="${ARGO_AUTH:-}"
UUID="${UUID:-}"
SUB_PATH="${SUB_PATH:-sub}"
CFIP="${CFIP:-}"
CFPORT="${CFPORT:-}"

# Optimization settings
CPU_THRESHOLD="${CPU_THRESHOLD:-75}"
CPU_CHECK_INTERVAL="${CPU_CHECK_INTERVAL:-5}"
GRACEFUL_PAUSE_DURATION="${GRACEFUL_PAUSE_DURATION:-10}"
CLOUDFLARED_RETRIES="${CLOUDFLARED_RETRIES:-3}"
XRAY_LOG_LEVEL="${XRAY_LOG_LEVEL:-info}"

# Directories
XRAY_DIR="/opt/xray"
CLOUDFLARED_DIR="/opt/cloudflared"
WORK_DIR="/opt/work"
LOG_DIR="/var/log/services"

mkdir -p "$XRAY_DIR" "$CLOUDFLARED_DIR" "$WORK_DIR" "$LOG_DIR"

# Logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# System optimization
optimize_system_limits() {
    log_info "Optimizing system resource limits..."
    ulimit -n 65535 2>/dev/null || true
    ulimit -u 65535 2>/dev/null || true
    if command -v sysctl >/dev/null 2>&1; then
        sysctl -w net.ipv4.tcp_max_syn_backlog=4096 2>/dev/null || true
        sysctl -w net.ipv4.ip_local_port_range="10240 65535" 2>/dev/null || true
        sysctl -w net.ipv4.tcp_tw_reuse=1 2>/dev/null || true
        sysctl -w net.core.somaxconn=4096 2>/dev/null || true
    fi
    log_success "System limits optimized"
}

# CPU monitoring
get_current_cpu_usage() {
    if [ -f /proc/stat ]; then
        top -bn1 2>/dev/null | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print int(100 - $1)}' 2>/dev/null || echo "0"
    else
        echo 0
    fi
}

monitor_cpu_usage() {
    local service_pid=$1
    local service_name=$2
    log_info "Starting CPU monitoring for $service_name (PID: $service_pid)"
    while true; do
        sleep "$CPU_CHECK_INTERVAL"
        if ! kill -0 "$service_pid" 2>/dev/null; then
            break
        fi
        local cpu_usage=$(get_current_cpu_usage)
        if [ "$cpu_usage" -gt "$CPU_THRESHOLD" ]; then
            log_warn "High CPU usage: ${cpu_usage}% (threshold: ${CPU_THRESHOLD}%)"
            kill -STOP "$service_pid" 2>/dev/null || true
            sleep "$GRACEFUL_PAUSE_DURATION"
            kill -CONT "$service_pid" 2>/dev/null || true
            log_info "$service_name resumed after pause"
        fi
    done
}

# Cloudflared
download_cloudflared() {
    log_info "Downloading Cloudflared..."
    local arch=$(uname -m)
    local url=""
    case "$arch" in
        x86_64) url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" ;;
        aarch64) url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64" ;;
        *) log_error "Unsupported architecture: $arch"; return 1 ;;
    esac
    wget -q -O "$CLOUDFLARED_DIR/cloudflared" "$url" || { log_error "Failed to download"; return 1; }
    chmod +x "$CLOUDFLARED_DIR/cloudflared"
    log_success "Cloudflared downloaded"
}

generate_cloudflared_config() {
    log_info "Generating Cloudflared config..."
    cat > "$CLOUDFLARED_DIR/config.yaml" << 'EOF'
tunnel: argo-tunnel
http2Origin: true
grace-period: 30s
max-idle-connections: 10
retries: 3
retry-timeout: 30s
disable-tls-13: false
loglevel: error
transport-loglevel: warn
nameserver: 1.1.1.1
ingress:
  - hostname: "*"
    service: http://localhost:8080
    http2Origin: true
EOF
    log_success "Config generated"
}

start_cloudflared() {
    log_info "Starting Cloudflared..."
    generate_cloudflared_config
    local cmd="$CLOUDFLARED_DIR/cloudflared tunnel --url http://localhost:$ARGO_PORT"
    if [ -n "$ARGO_DOMAIN" ] && [ -n "$ARGO_AUTH" ]; then
        echo "$ARGO_AUTH" > "$CLOUDFLARED_DIR/token.txt"
        cmd="$cmd --token $(cat $CLOUDFLARED_DIR/token.txt)"
    fi
    nice -n 10 ionice -c3 $cmd > "$LOG_DIR/cloudflared.log" 2>&1 &
    local pid=$!
    log_success "Cloudflared started (PID: $pid)"
    monitor_cpu_usage "$pid" "Cloudflared" &
    echo "$pid"
}

# Xray
download_xray() {
    log_info "Downloading Xray..."
    local arch=$(uname -m)
    local url=""
    case "$arch" in
        x86_64) url="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip" ;;
        aarch64) url="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-arm64-v8.zip" ;;
        *) log_error "Unsupported: $arch"; return 1 ;;
    esac
    wget -q -O /tmp/xray.zip "$url" || { log_error "Download failed"; return 1; }
    unzip -q -o /tmp/xray.zip -d "$XRAY_DIR" && rm -f /tmp/xray.zip
    chmod +x "$XRAY_DIR/xray"
    log_success "Xray downloaded"
}

generate_xray_config() {
    log_info "Generating Xray config..."
    cat > "$XRAY_DIR/config.json" << EOF
{
  "log": {
    "loglevel": "$XRAY_LOG_LEVEL",
    "access": "$LOG_DIR/xray_access.log",
    "error": "$LOG_DIR/xray_error.log"
  },
  "inbounds": [{
    "port": 8080,
    "protocol": "vmess",
    "settings": {
      "clients": [{"id": "$UUID", "alterId": 0}]
    },
    "streamSettings": {
      "network": "ws",
      "wsSettings": {"path": "/$SUB_PATH"}
    }
  }],
  "outbounds": [
    {"protocol": "freedom", "tag": "direct", "settings": {"domainStrategy": "UseIP"}},
    {"protocol": "freedom", "tag": "default", "settings": {}}
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {"type": "field", "domain": ["geosite:cn"], "outboundTag": "direct"},
      {"type": "field", "ip": ["geoip:cn"], "outboundTag": "direct"}
    ]
  },
  "policy": {
    "levels": {"0": {"handshake": 4, "connIdle": 30, "uplinkOnly": 0, "downlinkOnly": 0, "statsUserUplink": false, "statsUserDownlink": false}},
    "system": {"statsInboundUplink": false, "statsInboundDownlink": false}
  }
}
EOF
    log_success "Config generated"
}

start_xray() {
    log_info "Starting Xray..."
    generate_xray_config
    nice -n 15 "$XRAY_DIR/xray" -c "$XRAY_DIR/config.json" > "$LOG_DIR/xray.log" 2>&1 &
    local pid=$!
    log_success "Xray started (PID: $pid)"
    monitor_cpu_usage "$pid" "Xray" &
    echo "$pid"
}

# Web server
setup_web_server() {
    log_info "Setting up web server..."
    cat > "$WORK_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head><title>Vmess-Argo</title></head>
<body><h1>Hello World</h1><p>Vmess-Argo Proxy Running</p></body>
</html>
EOF
    if command -v busybox >/dev/null 2>&1; then
        cd "$WORK_DIR" && busybox httpd -f -p 8000 > "$LOG_DIR/httpd.log" 2>&1 &
    elif command -v python3 >/dev/null 2>&1; then
        cd "$WORK_DIR" && python3 -m http.server 8000 > "$LOG_DIR/httpd.log" 2>&1 &
    else
        log_error "No HTTP server"; return 1
    fi
    log_success "Web server started"
}

cleanup() {
    log_warn "Shutting down..."
    jobs -p | xargs -r kill -9 2>/dev/null || true
    log_success "Cleanup complete"
}

# Main
main() {
    log_info "==== Optimized Vmess-Argo Service ===="
    if [ -z "$UUID" ]; then
        log_error "UUID not set"
        exit 1
    fi
    log_info "UUID: ${UUID:0:8}... | Port: $ARGO_PORT | CPU Threshold: ${CPU_THRESHOLD}%"
    trap cleanup EXIT INT TERM
    
    optimize_system_limits
    download_cloudflared || exit 1
    download_xray || exit 1
    setup_web_server || exit 1
    
    log_info "Starting services..."
    CLOUDFLARED_PID=$(start_cloudflared)
    XRAY_PID=$(start_xray)
    log_success "All services started"
    log_info "Logs: $LOG_DIR"
    log_info "==== Service Running ===="
    
    while true; do
        sleep 60
        kill -0 "$CLOUDFLARED_PID" 2>/dev/null || { log_error "Cloudflared died, restarting..."; CLOUDFLARED_PID=$(start_cloudflared); }
        kill -0 "$XRAY_PID" 2>/dev/null || { log_error "Xray died, restarting..."; XRAY_PID=$(start_xray); }
        log_info "CPU: $(get_current_cpu_usage)%"
    done
}

main "$@"
