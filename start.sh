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

CF_DOMAIN=""
CF_TOKEN=""
UUID=""
NEZHA_SERVER=""
NEZHA_PORT="5555"
NEZHA_KEY=""
ARGO_PORT="27039"

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
        printf '%s\n' "$default_value"
        return 1
    fi

    local candidates=("$key")
    local uppercase_key="${key^^}"
    local lowercase_key="${key,,}"

    if [[ "$uppercase_key" != "$key" ]]; then
        candidates+=("$uppercase_key")
    fi
    if [[ "$lowercase_key" != "$key" && "$lowercase_key" != "$uppercase_key" ]]; then
        candidates+=("$lowercase_key")
    fi

    local python_output=""
    local python_status=1

    if command -v python3 >/dev/null 2>&1; then
        python_output=$(python3 - "$file" "${candidates[@]}" <<'PYCODE'
import json
import sys

filename = sys.argv[1]
keys = sys.argv[2:]

try:
    with open(filename, 'r', encoding='utf-8') as fh:
        data = json.load(fh)
except Exception:
    sys.exit(2)

for key in keys:
    if key in data:
        value = data[key]
        if value is None:
            value = ""
        if isinstance(value, (dict, list)):
            import json as json_module
            print(json_module.dumps(value, ensure_ascii=False))
        else:
            print(value)
        sys.exit(0)

sys.exit(1)
PYCODE
        )
        python_status=$?
    fi

    if [[ $python_status -eq 0 ]]; then
        printf '%s\n' "$python_output"
        return 0
    fi

    local value=""
    for candidate in "${candidates[@]}"; do
        value=$(awk -v key="$candidate" '
            match($0, "\"" key "\"[[:space:]]*:[[:space:]]*\"([^\"]*)\"", arr) {
                print arr[1]
                exit
            }
        ' "$file")
        if [[ -n "$value" ]]; then
            break
        fi

        value=$(awk -v key="$candidate" '
            match($0, "\"" key "\"[[:space:]]*:[[:space:]]*([^,}     
]+)", arr) {
                print arr[1]
                exit
            }
        ' "$file")
        if [[ -n "$value" ]]; then
            value=${value//\"/}
            break
        fi
    done

    if [[ -z "$value" ]]; then
        printf '%s\n' "$default_value"
        return 1
    fi

    printf '%s\n' "$value"
    return 0
}

format_sensitive_value() {
    local value="$1"
    local placeholder=${2:-"'not set'"}

    if [[ -z "$value" ]]; then
        printf "%s" "$placeholder"
        return
    fi

    local length=${#value}
    if (( length <= 10 )); then
        printf "%s (loaded)" "$value"
    else
        printf "%s... (loaded)" "${value:0:6}"
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

    CF_DOMAIN=$(extract_json_value "$CONFIG_FILE" "cf_domain")
    CF_TOKEN=$(extract_json_value "$CONFIG_FILE" "cf_token")
    UUID=$(extract_json_value "$CONFIG_FILE" "uuid")
    NEZHA_SERVER=$(extract_json_value "$CONFIG_FILE" "nezha_server")
    NEZHA_PORT=$(extract_json_value "$CONFIG_FILE" "nezha_port" "5555")
    NEZHA_KEY=$(extract_json_value "$CONFIG_FILE" "nezha_key")
    ARGO_PORT=$(extract_json_value "$CONFIG_FILE" "argo_port" "27039")

    NEZHA_PORT=${NEZHA_PORT:-5555}
    ARGO_PORT=${ARGO_PORT:-27039}

    export CF_DOMAIN CF_TOKEN UUID NEZHA_SERVER NEZHA_PORT NEZHA_KEY ARGO_PORT

    log_info "Configuration loaded successfully:"
    log_info "  CF_DOMAIN: ${CF_DOMAIN:-'not set'}"
    log_info "  CF_TOKEN: $(format_sensitive_value "$CF_TOKEN")"
    log_info "  UUID: ${UUID:-'not set'}"
    log_info "  NEZHA_SERVER: ${NEZHA_SERVER:-'not set'}"
    log_info "  NEZHA_PORT: ${NEZHA_PORT:-'not set'}"
    log_info "  NEZHA_KEY: $(format_sensitive_value "$NEZHA_KEY")"
    log_info "  ARGO_PORT: ${ARGO_PORT:-'not set'}"

    if [[ -z "$CF_DOMAIN" ]]; then
        log_warn "CF_DOMAIN is not set; Argo fixed domain will be unavailable."
    fi
    if [[ -z "$CF_TOKEN" ]]; then
        log_warn "CF_TOKEN is not set; falling back to temporary tunnels."
    fi
    if [[ -z "$UUID" ]]; then
        log_warn "UUID is not set; downstream services may require this value."
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
    else
        log_error "argo-diagnostic.sh not found"
    fi
    
    log_info "=== Startup Script Completed ==="
}

# 执行主函数
main "$@"