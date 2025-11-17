#!/bin/bash
set -euo pipefail

# =============================================================================
# Zampto Startup Script
# Description: Load config, start Nezha, and call wispbyte deploy script
# Version: 1.2 - Corrected with proper config export
# =============================================================================

# ===== 日志函数 =====
log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1" >&2
}

# ===== 验证 config.json =====
CONFIG_FILE="/home/container/config.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
    log_error "config.json not found at /home/container/config.json"
    exit 1
fi

log_info "=== Zampto Startup Script ==="
log_info "Loading config.json..."

# ===== 读取配置 =====
CF_DOMAIN=$(grep -o '"cf_domain":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
CF_TOKEN=$(grep -o '"cf_token":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
UUID=$(grep -o '"uuid":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
PORT=$(grep -o '"port":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
NEZHA_SERVER=$(grep -o '"nezha_server":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
NEZHA_PORT=$(grep -o '"nezha_port":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
NEZHA_KEY=$(grep -o '"nezha_key":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)

# 设置默认值
PORT=${PORT:-27039}
NEZHA_PORT=${NEZHA_PORT:-5555}

# ===== 验证关键字段 =====
if [[ -z "$CF_DOMAIN" || -z "$UUID" ]]; then
    log_error "Missing required config: CF_DOMAIN or UUID"
    exit 1
fi

log_info "Config loaded:"
log_info "  - Domain: $CF_DOMAIN"
log_info "  - UUID: $UUID"
log_info "  - Port: $PORT"
log_info "  - Nezha: $NEZHA_SERVER:$NEZHA_PORT"

# ===== 导出环境变量（重要！）=====
export CF_DOMAIN CF_TOKEN UUID PORT NEZHA_SERVER NEZHA_PORT NEZHA_KEY

# ===== 启动哪吒（非阻塞） =====
log_info "Starting Nezha agent..."

if [[ -n "$NEZHA_KEY" && -n "$NEZHA_SERVER" ]]; then
    ARCH=$(uname -m)
    case $ARCH in
        aarch64) NEZHA_ARCH="arm64" ;;
        x86_64) NEZHA_ARCH="amd64" ;;
        armv7l) NEZHA_ARCH="armv7" ;;
        *) NEZHA_ARCH="amd64" ;;
    esac
    
    mkdir -p /tmp/nezha
    if curl -s -L -o /tmp/nezha/nezha-agent.tar.gz \
      "https://github.com/naiba/nezha/releases/latest/download/nezha-agent-linux_${NEZHA_ARCH}.tar.gz" && \
       tar -xzf /tmp/nezha/nezha-agent.tar.gz -C /tmp/nezha && \
       chmod +x /tmp/nezha/nezha-agent; then
        nohup /tmp/nezha/nezha-agent -s "$NEZHA_SERVER:$NEZHA_PORT" -p "$NEZHA_KEY" >/dev/null 2>&1 &
        log_info "Nezha agent started"
    else
        log_error "Nezha startup failed (non-blocking, continuing...)"
    fi
else
    log_info "Nezha disabled (NEZHA_KEY or NEZHA_SERVER not set)"
fi

# ===== 调用部署脚本 =====
log_info "Calling wispbyte-argo-singbox-deploy.sh..."

if [[ -f "/home/container/wispbyte-argo-singbox-deploy.sh" ]]; then
    bash /home/container/wispbyte-argo-singbox-deploy.sh
else
    log_error "wispbyte-argo-singbox-deploy.sh not found"
    exit 1
fi

log_info "=== Startup Completed ==="
