#!/bin/bash

# =============================================================================
# Zampto Startup Script v2.2
# Description: Load config, start Nezha, and call wispbyte deploy script
# Fixed: Proper error handling without set -e causing premature exit
# =============================================================================

# ===== 日志函数 =====
log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

log_warn() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [WARN] $1" >&2
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1" >&2
}

# ===== 初始化 =====
log_info "=== Zampto Startup Script v2.2 ==="
log_info "Loading config.json..."

CONFIG_FILE="/home/container/config.json"

# ===== 验证 config.json 存在 =====
if [[ ! -f "$CONFIG_FILE" ]]; then
    log_error "config.json not found at $CONFIG_FILE"
    exit 1
fi

# ===== 读取配置（使用 || echo "" 防止失败）=====
CF_DOMAIN=$(grep -o '"cf_domain":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4 || echo "")
CF_TOKEN=$(grep -o '"cf_token":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4 || echo "")
UUID=$(grep -o '"uuid":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4 || echo "")
PORT=$(grep -o '"port":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4 || echo "")
NEZHA_SERVER=$(grep -o '"nezha_server":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4 || echo "")
NEZHA_PORT=$(grep -o '"nezha_port":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4 || echo "")
NEZHA_KEY=$(grep -o '"nezha_key":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4 || echo "")

# ===== 设置默认值 =====
PORT=${PORT:-27039}
NEZHA_PORT=${NEZHA_PORT:-5555}

# ===== 验证关键字段 =====
if [[ -z "$CF_DOMAIN" ]] || [[ -z "$UUID" ]]; then
    log_error "Missing required config: CF_DOMAIN or UUID"
    exit 1
fi

# ===== 显示加载的配置 =====
log_info "Config loaded successfully:"
log_info "  - Domain: $CF_DOMAIN"
log_info "  - UUID: $UUID"
log_info "  - Port: $PORT"
log_info "  - Nezha: ${NEZHA_SERVER:-'not set'}"

# ===== 导出环境变量（重要！给后续脚本使用）=====
export CF_DOMAIN CF_TOKEN UUID PORT NEZHA_SERVER NEZHA_PORT NEZHA_KEY
log_info "Environment variables exported"

# ===== 启动哪吒（非阻塞式，失败不影响后续）=====
log_info "Starting Nezha agent..."

if [[ -n "$NEZHA_KEY" ]] && [[ -n "$NEZHA_SERVER" ]]; then
    ARCH=$(uname -m)
    case $ARCH in
        aarch64) NEZHA_ARCH="arm64" ;;
        x86_64) NEZHA_ARCH="amd64" ;;
        armv7l) NEZHA_ARCH="armv7" ;;
        *) NEZHA_ARCH="amd64" ;;
    esac
    
    mkdir -p /tmp/nezha || {
        log_warn "Failed to create /tmp/nezha directory (non-blocking)"
    }
    
    NEZHA_URL="https://github.com/naiba/nezha/releases/latest/download/nezha-agent-linux_${NEZHA_ARCH}.tar.gz"
    log_info "Downloading Nezha agent from: $NEZHA_URL"
    
    if curl -fsSL -o /tmp/nezha/nezha-agent.tar.gz "$NEZHA_URL" 2>/dev/null; then
        if tar -xzf /tmp/nezha/nezha-agent.tar.gz -C /tmp/nezha 2>/dev/null && \
           [[ -f /tmp/nezha/nezha-agent ]]; then
            chmod +x /tmp/nezha/nezha-agent
            nohup /tmp/nezha/nezha-agent -s "$NEZHA_SERVER:$NEZHA_PORT" -p "$NEZHA_KEY" >/dev/null 2>&1 &
            NEZHA_PID=$!
            sleep 1
            if kill -0 $NEZHA_PID 2>/dev/null; then
                log_info "Nezha agent started successfully (PID: $NEZHA_PID)"
            else
                log_warn "Nezha agent failed to start (non-blocking, continuing...)"
            fi
        else
            log_warn "Nezha agent extraction failed (non-blocking, continuing...)"
        fi
    else
        log_warn "Nezha agent download failed (non-blocking, continuing...)"
    fi
else
    log_info "Nezha disabled (NEZHA_KEY or NEZHA_SERVER not set)"
fi

# ===== 调用部署脚本 =====
log_info "Calling wispbyte-argo-singbox-deploy.sh..."

if [[ ! -f "/home/container/wispbyte-argo-singbox-deploy.sh" ]]; then
    log_error "wispbyte-argo-singbox-deploy.sh not found at /home/container/wispbyte-argo-singbox-deploy.sh"
    exit 1
fi

bash /home/container/wispbyte-argo-singbox-deploy.sh

log_info "=== Startup Completed ==="
