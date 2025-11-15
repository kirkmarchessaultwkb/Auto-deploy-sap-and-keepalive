#!/bin/bash

# ============================================================================
# Optimized Start Script for sing-box on zampto Node.js Platform
# Purpose: Reduce CPU usage from 70% to 40-50% on ARM servers
# Platform: zampto Node10 (ARM)
# ============================================================================

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" 2>&1
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" 2>&1
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" 2>&1
}

# ============================================================================
# Helper Functions
# ============================================================================

cleanup() {
    log_info "Received termination signal, cleaning up..."
    pkill -P $$ || true
    exit 0
}

trap cleanup SIGTERM SIGINT

# ============================================================================
# Environment Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

WORK_DIR="${WORK_DIR:-.}"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

mkdir -p logs cache subscriptions

log_info "Working directory: $WORK_DIR"

# ============================================================================
# 1. Download and Setup sing-box Binary
# ============================================================================

download_sing_box() {
    log_info "Checking sing-box binary..."
    
    if [ -f "sing-box" ] && [ -x "sing-box" ]; then
        log_info "sing-box binary already exists"
        return 0
    fi
    
    ARCH=$(uname -m)
    case $ARCH in
        x86_64|amd64)
            ARCH_TYPE="amd64"
            ;;
        aarch64|arm64)
            ARCH_TYPE="arm64"
            ;;
        armv7l|armhf)
            ARCH_TYPE="armv7"
            ;;
        *)
            log_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
    
    log_info "Detected architecture: $ARCH ($ARCH_TYPE)"
    
    log_info "Downloading sing-box for $ARCH_TYPE..."
    LATEST_RELEASE=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | grep "tag_name" | cut -d '"' -f 4)
    
    if [ -z "$LATEST_RELEASE" ]; then
        log_error "Failed to get latest sing-box version"
        exit 1
    fi
    
    DOWNLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/${LATEST_RELEASE}/sing-box-${LATEST_RELEASE#v}-linux-${ARCH_TYPE}.tar.gz"
    
    log_info "Downloading from: $DOWNLOAD_URL"
    curl -L -o /tmp/sing-box.tar.gz "$DOWNLOAD_URL" 2>/dev/null || {
        log_error "Failed to download sing-box"
        exit 1
    }
    
    tar -xzf /tmp/sing-box.tar.gz -C /tmp/ 2>/dev/null || {
        log_error "Failed to extract sing-box"
        exit 1
    }
    
    if [ -f "/tmp/sing-box" ]; then
        cp /tmp/sing-box .
    elif [ -f "/tmp/sing-box-${LATEST_RELEASE#v}-linux-${ARCH_TYPE}/sing-box" ]; then
        cp "/tmp/sing-box-${LATEST_RELEASE#v}-linux-${ARCH_TYPE}/sing-box" .
    else
        log_error "Could not find sing-box binary in archive"
        exit 1
    fi
    
    chmod +x sing-box
    rm -rf /tmp/sing-box.tar.gz /tmp/sing-box-* 2>/dev/null || true
    
    log_info "sing-box downloaded successfully"
}

# ============================================================================
# 2. Download and Setup Cloudflared Binary
# ============================================================================

download_cloudflared() {
    log_info "Checking cloudflared binary..."
    
    if [ -f "cloudflared" ] && [ -x "cloudflared" ]; then
        log_info "cloudflared binary already exists"
        return 0
    fi
    
    ARCH=$(uname -m)
    case $ARCH in
        x86_64|amd64)
            ARCH_TYPE="amd64"
            ;;
        aarch64|arm64)
            ARCH_TYPE="arm64"
            ;;
        armv7l|armhf)
            ARCH_TYPE="arm"
            ;;
        *)
            log_warn "Unsupported architecture for cloudflared: $ARCH"
            return 1
            ;;
    esac
    
    log_info "Downloading cloudflared for $ARCH_TYPE..."
    
    CLOUDFLARED_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH_TYPE}"
    curl -L -o cloudflared "$CLOUDFLARED_URL" 2>/dev/null || {
        log_warn "Failed to download cloudflared"
        return 1
    }
    
    chmod +x cloudflared
    log_info "cloudflared downloaded successfully"
}

# ============================================================================
# 3. Generate sing-box Configuration
# ============================================================================

generate_config() {
    log_info "Generating sing-box configuration..."
    
    UUID="${UUID:-de305d54-75b4-431b-adb2-eb6b9e546014}"
    LISTEN_IP="${LISTEN_IP:-127.0.0.1}"
    LISTEN_PORT="${LISTEN_PORT:-8080}"
    
    mkdir -p config
    
    cat > config/config.json << EOF
{
  "log": {
    "level": "error",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "google",
        "address": "8.8.8.8"
      },
      {
        "tag": "cloudflare",
        "address": "1.1.1.1"
      }
    ],
    "rules": [
      {
        "outbound": "any",
        "server": "google"
      }
    ],
    "strategy": "prefer_ipv4",
    "disable_cache": false,
    "independent_cache": false
  },
  "inbounds": [
    {
      "type": "vmess",
      "tag": "vmess-in",
      "listen": "$LISTEN_IP",
      "listen_port": $LISTEN_PORT,
      "users": [
        {
          "name": "user",
          "uuid": "$UUID",
          "alterId": 0
        }
      ],
      "transport": {
        "type": "ws",
        "path": "/ws",
        "early_data_header_name": "Sec-WebSocket-Protocol"
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "blackhole",
      "tag": "block"
    }
  ],
  "route": {
    "rules": [
      {
        "ip_cidr": [
          "10.0.0.0/8",
          "172.16.0.0/12",
          "192.168.0.0/16"
        ],
        "outbound": "block"
      }
    ],
    "final": "direct"
  }
}
EOF

    log_info "Configuration generated: config/config.json"
}

# ============================================================================
# 4. Setup Cloudflared Tunnel (if ARGO_AUTH is set)
# ============================================================================

setup_cloudflared() {
    if [ -z "$ARGO_AUTH" ] || [ -z "$ARGO_DOMAIN" ]; then
        log_warn "ARGO_AUTH or ARGO_DOMAIN not set, skipping Cloudflared setup"
        return 0
    fi
    
    log_info "Setting up Cloudflared tunnel..."
    
    download_cloudflared || {
        log_warn "Cloudflared not available, continuing without tunnel"
        return 1
    }
    
    mkdir -p config/cloudflared
    
    if echo "$ARGO_AUTH" | grep -q "^{"; then
        echo "$ARGO_AUTH" > config/cloudflared/cert.json
    else
        echo "$ARGO_AUTH" > config/cloudflared/token
    fi
    
    log_info "Cloudflared credentials configured"
}

# ============================================================================
# 5. Optimize Process Priority (Optimization #1)
# ============================================================================

start_with_optimization() {
    if command -v nice &> /dev/null && command -v ionice &> /dev/null; then
        log_info "Starting process with optimized priority..."
        exec nice -n 19 ionice -c 3 "$@"
    else
        log_warn "nice/ionice not available, starting without priority optimization"
        exec "$@"
    fi
}

# ============================================================================
# 6. Health Check Setup (Optimization #3: 30s interval)
# ============================================================================

setup_health_check() {
    log_info "Setting up health check service (30s interval)..."
    
    cat > health-check.sh << 'HEALTH_EOF'
#!/bin/bash

CHECK_INTERVAL=30
LOG_FILE="logs/health-check.log"

mkdir -p logs

while true; do
    sleep $CHECK_INTERVAL
    
    if ! pgrep -f "sing-box" > /dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: sing-box process not found" >> "$LOG_FILE"
    fi
    
    if ! timeout 2 bash -c "echo > /dev/tcp/127.0.0.1/8080" 2>/dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: Port 8080 not responding" >> "$LOG_FILE"
    fi
done
HEALTH_EOF

    chmod +x health-check.sh
    log_info "Health check script created"
}

# ============================================================================
# 7. Telegram Notification Helper (Optional)
# ============================================================================

send_telegram_notification() {
    if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
        return 0
    fi
    
    local message="$1"
    local message_type="${2:-info}"
    
    case $message_type in
        info)
            local icon="ℹ️"
            ;;
        success)
            local icon="✅"
            ;;
        error)
            local icon="❌"
            ;;
        warning)
            local icon="⚠️"
            ;;
        *)
            local icon="📢"
            ;;
    esac
    
    local full_message="$icon $message"
    
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" \
        -d "text=${full_message}" \
        -d "parse_mode=HTML" > /dev/null 2>&1 || true
}

# ============================================================================
# 8. Nezha Agent Setup (Optional)
# ============================================================================

setup_nezha() {
    if [ -z "$NEZHA_SERVER" ] || [ -z "$NEZHA_KEY" ]; then
        log_info "Nezha monitoring not configured"
        return 0
    fi
    
    log_info "Setting up Nezha monitoring agent..."
    
    ARCH=$(uname -m)
    case $ARCH in
        x86_64|amd64)
            ARCH_TYPE="amd64"
            ;;
        aarch64|arm64)
            ARCH_TYPE="arm64"
            ;;
        armv7l|armhf)
            ARCH_TYPE="armv7"
            ;;
        *)
            log_warn "Unsupported architecture for Nezha: $ARCH"
            return 1
            ;;
    esac
    
    if [ -f "nezha-agent" ] && [ -x "nezha-agent" ]; then
        log_info "Nezha agent already exists"
        return 0
    fi
    
    NEZHA_DOWNLOAD="https://github.com/nezhahq/agent/releases/latest/download/nezha-agent_linux_${ARCH_TYPE}.zip"
    
    log_info "Downloading Nezha agent from: $NEZHA_DOWNLOAD"
    curl -L -o /tmp/nezha-agent.zip "$NEZHA_DOWNLOAD" 2>/dev/null || {
        log_warn "Failed to download Nezha agent"
        return 1
    }
    
    unzip -q /tmp/nezha-agent.zip -d /tmp/ 2>/dev/null || {
        log_warn "Failed to extract Nezha agent"
        return 1
    }
    
    if [ -f "/tmp/nezha-agent" ]; then
        cp /tmp/nezha-agent ./
        chmod +x ./nezha-agent
    fi
    
    rm -f /tmp/nezha-agent* 2>/dev/null || true
    
    log_info "Nezha agent ready"
}

# ============================================================================
# 9. Main Service Startup
# ============================================================================

main() {
    log_info "=========================================="
    log_info "   Optimized sing-box for zampto Node.js"
    log_info "   Platform: Node10 (ARM)"
    log_info "   CPU Target: 40-50% (from 70%)"
    log_info "=========================================="
    
    download_sing_box
    setup_cloudflared
    setup_nezha
    
    generate_config
    setup_health_check
    
    log_info "UUID: ${UUID:-not configured}"
    log_info "Listen Port: ${LISTEN_PORT:-8080}"
    
    if [ -n "$ARGO_DOMAIN" ]; then
        log_info "Argo Domain: $ARGO_DOMAIN"
    fi
    
    if [ -n "$NEZHA_SERVER" ]; then
        log_info "Nezha Server: $NEZHA_SERVER"
    fi
    
    send_telegram_notification "sing-box service starting on zampto Node.js platform" "info"
    
    log_info "Starting sing-box service with CPU optimizations..."
    log_info "- Process Priority: nice -n 19, ionice -c 3"
    log_info "- Logging Level: error only"
    log_info "- Health Check: 30s interval"
    
    ./health-check.sh &
    HEALTH_CHECK_PID=$!
    
    log_info "Health check PID: $HEALTH_CHECK_PID"
    
    start_with_optimization ./sing-box run -c config/config.json
}

# ============================================================================
# Execute main function
# ============================================================================

main "$@"
