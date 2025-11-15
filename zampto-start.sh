#!/bin/bash

# ============================================================
#  zampto sing-box 优化版 - 环境变量配置
#  CPU 优化：70% → 40-50%
# ============================================================

# ============ 必填参数 ============
# UUID 用于 Vmess 和哪吒 v1
# 如果为空，脚本会自动生成一个
export UUID=${UUID:-''}

# Argo 隧道域名（固定隧道）
# 格式：zampto.xunda.ggff.net
# 如果为空，使用临时隧道
export ARGO_DOMAIN=${ARGO_DOMAIN:-''}

# Argo 隧道 Token 或 JSON（固定隧道）
# 格式：可以是 token 字符串或 JSON 对象
# 如果为空，使用临时隧道
export ARGO_AUTH=${ARGO_AUTH:-''}

# ============ 可选参数（Argo 优选节点）============
# CF 优选域名或 IP
# 用于加速访问（如果不填，默认 www.shopify.com）
export CFIP=${CFIP:-'www.shopify.com'}

# CF 优选端口
# 默认 443
export CFPORT=${CFPORT:-'443'}

# ============ 可选参数（哪吒监控）============
# 哪吒服务器地址
# v1 版本格式：nezha.abc.com:8008（端口包含在域名中）
# v0 版本格式：nezha.abc.com（端口需要在下面的 NEZHA_PORT 填写）
# 如果为空，不启用哪吒
export NEZHA_SERVER=${NEZHA_SERVER:-''}

# 哪吒端口（仅 v0 版本需要）
# v1 版本不需要此参数
# v0 可选端口：443, 8443, 2096, 2087, 2083, 2053
# 如果为空，v0 默认使用 5555
export NEZHA_PORT=${NEZHA_PORT:-''}

# 哪吒密钥
# v1 版本：NZ_CLIENT_SECRET
# v0 版本：agent 密钥
# 如果为空，不启用哪吒
export NEZHA_KEY=${NEZHA_KEY:-''}

# ============ 可选参数（Telegram 通知）============
# Telegram chat ID
# 获取方法：https://t.me/laowang_serv00_bot
# 如果为空，不启用 Telegram 通知
export CHAT_ID=${CHAT_ID:-''}

# Telegram Bot Token
# 格式：123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11
# 如果为空，使用公共 bot（但需要填写 CHAT_ID）
export BOT_TOKEN=${BOT_TOKEN:-''}

# ============ 可选参数（其他）============
# 节点名称（订阅中显示的名字）
# 默认：zampto
export NAME=${NAME:-'zampto'}

# 订阅文件保存路径
# 默认：./.npm
export FILE_PATH=${FILE_PATH:-'./.npm'}

# Node.js 服务端口
# 默认：3000
export SERVER_PORT=${SERVER_PORT:-'3000'}

# 订阅自动上传地址
# 用于将订阅链接上传到汇聚订阅器
# 格式：https://merge.zabc.net
# 如果为空，不上传
export UPLOAD_URL=${UPLOAD_URL:-''}

# sing-box 监听地址（内部使用）
# 默认：::（监听所有 IPv4/IPv6 接口）
export LISTEN_IP=${LISTEN_IP:-'::'}

# sing-box 监听端口（内部使用）
# 默认：8080
export LISTEN_PORT=${LISTEN_PORT:-'8080'}

# ============ 保存后重启服务 ============
# 修改完上面的参数后，保存此文件
# 然后重启服务器即可

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
    
    if [ -z "$UUID" ]; then
        UUID="de305d54-75b4-431b-adb2-eb6b9e546014"
        log_warn "UUID not set, using default: $UUID"
    fi
    
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
      "type": "block",
      "tag": "block"
    },
    {
      "type": "urltest",
      "tag": "auto",
      "outbounds": ["cf-tunnel"],
      "url": "http://www.gstatic.com/generate_204",
      "interval": "1m",
      "tolerance": 50
    },
    {
      "type": "http",
      "tag": "cf-tunnel",
      "server": "127.0.0.1",
      "server_port": 8001,
      "username": "tunnel",
      "password": "tunnel"
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
      },
      {
        "inbound": ["vmess-in"],
        "outbound": "auto"
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
        local credentials_file="config/cloudflared/credentials.json"
        echo "$ARGO_AUTH" > "$credentials_file"
        chmod 600 "$credentials_file" 2>/dev/null || true
        
        local tunnel_id=""
        if command -v node >/dev/null 2>&1; then
            tunnel_id=$(node -e 'const fs=require("fs");const path=process.argv[1];try{const raw=fs.readFileSync(path,"utf8");const data=JSON.parse(raw);const id=data.TunnelID||data.tunnel_id||data.tunnelId||"";if(!id)process.exit(1);process.stdout.write(id);}catch(e){process.exit(1);}' "$credentials_file" 2>/dev/null || true)
        else
            log_warn "Node.js not available, unable to parse Cloudflared credentials"
        fi
        
        if [ -n "$tunnel_id" ]; then
            echo "$tunnel_id" > config/cloudflared/tunnel.id
            log_info "Detected Cloudflared tunnel ID: $tunnel_id"
        else
            log_warn "Failed to parse TunnelID from ARGO_AUTH credentials"
        fi
    else
        echo "$ARGO_AUTH" > config/cloudflared/token
        chmod 600 config/cloudflared/token 2>/dev/null || true
        log_info "Cloudflared token saved"
    fi
    
    log_info "Cloudflared credentials configured"
}

# ============================================================================
# 4.1. Start Cloudflared Tunnel
# ============================================================================

start_cloudflared_tunnel() {
    log_info "Starting Cloudflared tunnel..."
    
    if [ ! -f "cloudflared" ]; then
        log_warn "Cloudflared binary not found"
        return 1
    fi
    
    # Prepare log file
    mkdir -p logs
    CLOUDFLARED_LOG="logs/cloudflared.log"
    > "$CLOUDFLARED_LOG"
    
    # Start cloudflared tunnel with appropriate authentication
    if [ -n "$ARGO_AUTH" ] && [ -n "$ARGO_DOMAIN" ]; then
        log_info "Starting fixed Cloudflared tunnel..."
        log_info "Tunnel domain: $ARGO_DOMAIN"
        
        if echo "$ARGO_AUTH" | grep -q "^{"; then
            # JSON format - use credentials file
            local credentials_file="config/cloudflared/credentials.json"
            local tunnel_id=$(cat config/cloudflared/tunnel.id 2>/dev/null || echo "")
            
            if [ -n "$tunnel_id" ] && [ -f "$credentials_file" ]; then
                ./cloudflared tunnel --edge-ip-version auto --protocol http2 \
                    --credentials-file "$credentials_file" \
                    --url http://127.0.0.1:$LISTEN_PORT run "$tunnel_id" > "$CLOUDFLARED_LOG" 2>&1 &
            else
                # Fallback: try with ARGO_DOMAIN if tunnel_id not available
                ./cloudflared tunnel --edge-ip-version auto --protocol http2 \
                    --credentials-file "$credentials_file" \
                    --url http://127.0.0.1:$LISTEN_PORT run > "$CLOUDFLARED_LOG" 2>&1 &
            fi
        else
            # Token format
            ./cloudflared tunnel --edge-ip-version auto --protocol http2 \
                run --token "$ARGO_AUTH" > "$CLOUDFLARED_LOG" 2>&1 &
        fi
        
        CLOUDFLARED_PID=$!
        log_info "Cloudflared started with PID: $CLOUDFLARED_PID (fixed tunnel)"
        
        # Wait a moment for tunnel to establish
        sleep 5
        
        # Verify tunnel is running
        if ps -p $CLOUDFLARED_PID > /dev/null 2>&1; then
            log_info "✅ Cloudflared tunnel established: https://$ARGO_DOMAIN"
            echo "$ARGO_DOMAIN" > .argo_domain
            return 0
        else
            log_error "Cloudflared tunnel failed to start"
            cat "$CLOUDFLARED_LOG" | tail -20
            return 1
        fi
    else
        log_info "Starting temporary Cloudflared tunnel..."
        
        # Temporary tunnel (Quick Tunnel)
        ./cloudflared tunnel --edge-ip-version auto --protocol http2 \
            --url http://127.0.0.1:$LISTEN_PORT --no-autoupdate > "$CLOUDFLARED_LOG" 2>&1 &
        
        CLOUDFLARED_PID=$!
        log_info "Cloudflared started with PID: $CLOUDFLARED_PID (temporary tunnel)"
        
        # Wait for tunnel URL to appear in logs
        log_info "Waiting for tunnel URL..."
        for i in {1..30}; do
            if grep -q "trycloudflare.com" "$CLOUDFLARED_LOG" 2>/dev/null; then
                TEMP_DOMAIN=$(grep -oE 'https://[a-zA-Z0-9\-]+\.trycloudflare\.com' "$CLOUDFLARED_LOG" | head -1 | sed 's|https://||')
                if [ -n "$TEMP_DOMAIN" ]; then
                    log_info "✅ Temporary tunnel URL: https://$TEMP_DOMAIN"
                    ARGO_DOMAIN="$TEMP_DOMAIN"
                    echo "$TEMP_DOMAIN" > .argo_domain
                    return 0
                fi
            fi
            sleep 2
        done
        
        log_warn "Could not get tunnel URL from cloudflared logs"
        cat "$CLOUDFLARED_LOG" | tail -20
        return 1
    fi
}

# ============================================================================
# 4.2. Generate Subscription File
# ============================================================================

generate_subscription() {
    log_info "Generating subscription file..."
    
    # Get Argo domain
    local domain=""
    if [ -n "$ARGO_DOMAIN" ]; then
        domain="$ARGO_DOMAIN"
    elif [ -f ".argo_domain" ]; then
        domain=$(cat .argo_domain)
    else
        log_warn "No Argo domain available, subscription generation skipped"
        return 1
    fi
    
    # Remove https:// prefix if present
    domain="${domain#https://}"
    domain="${domain#http://}"
    
    log_info "Using domain: $domain"
    
    # Generate Vmess configuration
    local vmess_json="{
  \"v\": \"2\",
  \"ps\": \"${NAME}-vmess\",
  \"add\": \"${CFIP}\",
  \"port\": \"${CFPORT}\",
  \"id\": \"${UUID}\",
  \"aid\": \"0\",
  \"scy\": \"auto\",
  \"net\": \"ws\",
  \"type\": \"none\",
  \"host\": \"${domain}\",
  \"path\": \"/ws\",
  \"tls\": \"tls\",
  \"sni\": \"${domain}\",
  \"alpn\": \"\"
}"
    
    # Base64 encode (remove line breaks)
    local vmess_link="vmess://$(echo -n "$vmess_json" | base64 | tr -d '\n')"
    
    # Ensure directory exists
    mkdir -p "$FILE_PATH"
    
    # Save subscription
    echo "$vmess_link" > "$FILE_PATH/sub.txt"
    
    if [ -f "$FILE_PATH/sub.txt" ]; then
        log_info "✅ Subscription saved to $FILE_PATH/sub.txt"
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_info "📋 Vmess 订阅链接:"
        log_info "   $vmess_link"
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_info "🌐 Argo 隧道地址: https://$domain"
        log_info "🔑 UUID: $UUID"
        log_info "📡 优选 IP: $CFIP:$CFPORT"
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # Send Telegram notification if configured
        if [ -n "$BOT_TOKEN" ] && [ -n "$CHAT_ID" ]; then
            send_telegram_notification "✅ zampto 节点部署成功\n🌐 域名: https://$domain\n🔑 UUID: $UUID" "success"
        fi
        
        return 0
    else
        log_error "Failed to save subscription file"
        return 1
    fi
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
    
    # Start Nezha agent if configured
    if [ -f "nezha-agent" ] && [ -n "$NEZHA_SERVER" ] && [ -n "$NEZHA_KEY" ]; then
        log_info "Starting Nezha monitoring agent..."
        
        # Determine Nezha version based on NEZHA_SERVER format
        if echo "$NEZHA_SERVER" | grep -q ":"; then
            # v1 version (port in domain)
            ./nezha-agent -s "$NEZHA_SERVER" -p "$NEZHA_KEY" --disable-auto-update --disable-force-update > logs/nezha.log 2>&1 &
            NEZHA_PID=$!
            log_info "Nezha agent (v1) started with PID: $NEZHA_PID"
        else
            # v0 version
            NEZHA_PORT="${NEZHA_PORT:-5555}"
            ./nezha-agent -s "$NEZHA_SERVER:$NEZHA_PORT" -p "$NEZHA_KEY" --report-delay 60 > logs/nezha.log 2>&1 &
            NEZHA_PID=$!
            log_info "Nezha agent (v0) started with PID: $NEZHA_PID"
        fi
    fi
    
    # Start Cloudflared tunnel
    log_info "Starting Cloudflared tunnel..."
    start_cloudflared_tunnel
    
    # Wait a moment for tunnel to stabilize
    sleep 3
    
    # Generate subscription file
    log_info "Generating subscription..."
    generate_subscription
    
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
