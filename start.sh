#!/bin/bash

# =============================================================================
# Zampto Startup Script
# Description: Main startup script for zampto environment
# Loads configuration and starts services (Nezha + Argo tunnel)
# =============================================================================

# =============================================================================
# Configuration
# =============================================================================

CONFIG_FILE="/home/container/config.json"

# Log functions with timestamps
log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

log_warn() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [WARN] $1" >&2
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1" >&2
}

log_success() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [SUCCESS] $1"
}

# =============================================================================
# JSON Parsing Functions (without jq dependency)
# =============================================================================

# 通用的 JSON 提取函数
extract_json_value() {
    local file=$1
    local key=$2
    local default_value=${3:-""}
    
    if [[ ! -f "$file" ]]; then
        echo "$default_value"
        return 1
    fi
    
    # 使用 grep + sed 提取 JSON 值
    local value=$(grep "\"$key\"" "$file" | sed 's/.*"\([^"]*\)".*/\1/' | head -1)
    
    # 如果没有找到值，返回默认值
    if [[ -z "$value" ]]; then
        echo "$default_value"
        return 1
    else
        echo "$value"
        return 0
    fi
}

# =============================================================================
# Configuration Loading
# =============================================================================

load_config() {
    log_info "Loading configuration from: $CONFIG_FILE"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        return 1
    fi
    
    # 提取配置值（不依赖 jq）
    CF_DOMAIN=$(extract_json_value "$CONFIG_FILE" "CF_DOMAIN")
    CF_TOKEN=$(extract_json_value "$CONFIG_FILE" "CF_TOKEN")
    UUID=$(extract_json_value "$CONFIG_FILE" "UUID")
    NEZHA_SERVER=$(extract_json_value "$CONFIG_FILE" "NEZHA_SERVER")
    NEZHA_PORT=$(extract_json_value "$CONFIG_FILE" "NEZHA_PORT" "5555")
    NEZHA_KEY=$(extract_json_value "$CONFIG_FILE" "NEZHA_KEY")
    
    # 显示配置信息（隐藏敏感信息）
    log_info "Configuration loaded successfully:"
    log_info "  CF_DOMAIN: ${CF_DOMAIN:-'not set'}"
    if [[ -n "$CF_TOKEN" ]]; then
        log_info "  CF_TOKEN: 'set'"
    else
        log_info "  CF_TOKEN: 'not set'"
    fi
    if [[ -n "$UUID" ]]; then
        log_info "  UUID: 'set'"
    else
        log_info "  UUID: 'not set'"
    fi
    log_info "  NEZHA_SERVER: ${NEZHA_SERVER:-'not set'}"
    log_info "  NEZHA_PORT: $NEZHA_PORT"
    if [[ -n "$NEZHA_KEY" ]]; then
        log_info "  NEZHA_KEY: 'set'"
    else
        log_info "  NEZHA_KEY: 'not set'"
    fi
    
    return 0
}

# =============================================================================
# Nezha Agent Management
# =============================================================================

start_nezha_agent() {
    log_info "Starting Nezha agent..."
    
    if [[ -z "$NEZHA_KEY" ]]; then
        log_info "Nezha disabled (NEZHA_KEY is empty)."
        return 0
    fi
    
    if [[ -z "$NEZHA_SERVER" ]]; then
        log_warn "NEZHA_SERVER is not set, skipping Nezha agent startup"
        return 1
    fi
    
    log_info "NEZHA_KEY is set, downloading nezha-agent..."
    
    # 检测架构
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            NEZHA_ARCH="amd64"
            ;;
        aarch64|arm64)
            NEZHA_ARCH="arm64"
            ;;
        armv7l|armhf)
            NEZHA_ARCH="armv7"
            ;;
        *)
            log_error "Unsupported architecture: $ARCH"
            return 1
            ;;
    esac
    
    NEZHA_URL="https://github.com/naiba/nezha/releases/latest/download/nezha-agent-linux_${NEZHA_ARCH}.tar.gz"
    NEZHA_DIR="/tmp/nezha"
    NEZHA_BIN="$NEZHA_DIR/nezha-agent"
    
    # 创建目录
    mkdir -p "$NEZHA_DIR"
    
    # 下载 nezha-agent
    log_info "Downloading nezha-agent from: $NEZHA_URL"
    if command -v wget >/dev/null 2>&1; then
        wget -q -O "$NEZHA_DIR/nezha-agent.tar.gz" "$NEZHA_URL"
    elif command -v curl >/dev/null 2>&1; then
        curl -s -L -o "$NEZHA_DIR/nezha-agent.tar.gz" "$NEZHA_URL"
    else
        log_error "Neither wget nor curl is available for downloading nezha-agent"
        return 1
    fi
    
    # 解压
    if ! tar -xzf "$NEZHA_DIR/nezha-agent.tar.gz" -C "$NEZHA_DIR"; then
        log_error "Failed to extract nezha-agent"
        return 1
    fi
    
    # 设置执行权限
    chmod +x "$NEZHA_BIN"
    
    # 启动 nezha-agent
    log_info "Starting nezha-agent with server: $NEZHA_SERVER"
    
    # 解析服务器地址和端口
    SERVER_HOST=$(echo "$NEZHA_SERVER" | cut -d':' -f1)
    SERVER_PORT=$(echo "$NEZHA_SERVER" | cut -d':' -f2)
    if [[ -z "$SERVER_PORT" ]]; then
        SERVER_PORT="$NEZHA_PORT"
    fi
    
    # 后台启动 nezha-agent
    nohup "$NEZHA_BIN" -s "$SERVER_HOST:$SERVER_PORT" -p "$NEZHA_KEY" >/dev/null 2>&1 &
    NEZHA_PID=$!
    
    # 检查是否启动成功
    sleep 2
    if kill -0 "$NEZHA_PID" 2>/dev/null; then
        log_success "Nezha agent started successfully (PID: $NEZHA_PID)"
        echo "$NEZHA_PID" > /tmp/nezha.pid
        return 0
    else
        log_error "Failed to start Nezha agent"
        return 1
    fi
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    log_info "=== Zampto Startup Script ==="
    
    # 加载配置
    if ! load_config; then
        log_error "Failed to load configuration, exiting..."
        exit 1
    fi
    
    # 启动 Nezha Agent
    start_nezha_agent
    
    # 调用 argo-diagnostic.sh
    log_info "Starting Argo tunnel via argo-diagnostic.sh..."
    
    if [[ -f "/home/container/argo-diagnostic.sh" ]]; then
        bash /home/container/argo-diagnostic.sh
        
        if [ $? -eq 0 ]; then
            log_success "✅ Argo tunnel setup completed successfully"
        else
            log_error "❌ Argo tunnel setup failed"
        fi
    else
        log_error "argo-diagnostic.sh not found at /home/container/argo-diagnostic.sh"
    fi
    
    log_info "=== Startup Script Completed ==="
}

# 执行主函数
main "$@"