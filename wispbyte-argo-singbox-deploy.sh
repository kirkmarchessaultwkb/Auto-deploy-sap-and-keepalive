#!/bin/bash
# =============================================================================
# Wispbyte Argo Sing-box Deploy (Simplified for Zampto)
# Version: 1.2.0 - Corrected Downloads & Proper URL Construction
# Architecture: sing-box (127.0.0.1:PORT) → cloudflared → CF tunnel (443)
# =============================================================================

set -euo pipefail

CONFIG_FILE="/home/container/config.json"
WORK_DIR="/home/container/argo-tuic"
BIN_DIR="$WORK_DIR/bin"
SINGBOX_BIN="$BIN_DIR/sing-box"
CLOUDFLARED_BIN="$BIN_DIR/cloudflared"
SINGBOX_CONFIG="$WORK_DIR/config.json"
SUBSCRIPTION_FILE="/home/container/.npm/sub.txt"

log_info() { echo "[$(date +'%H:%M:%S')] [INFO] $1" | tee -a "$WORK_DIR/deploy.log"; }
log_error() { echo "[$(date +'%H:%M:%S')] [ERROR] $1" >&2 | tee -a "$WORK_DIR/deploy.log"; }

# Load configuration (Priority 1: env vars, Priority 2: config.json)
load_config() {
    CF_DOMAIN="${CF_DOMAIN:-}"
    CF_TOKEN="${CF_TOKEN:-}"
    UUID="${UUID:-}"
    PORT="${PORT:-27039}"
    
    if [[ -z "$CF_DOMAIN" && -f "$CONFIG_FILE" ]]; then
        CF_DOMAIN=$(grep -o '"cf_domain":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4 || true)
    fi
    if [[ -z "$CF_TOKEN" && -f "$CONFIG_FILE" ]]; then
        CF_TOKEN=$(grep -o '"cf_token":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4 || true)
    fi
    if [[ -z "$UUID" && -f "$CONFIG_FILE" ]]; then
        UUID=$(grep -o '"uuid":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4 || true)
    fi
    if [[ "$PORT" == "27039" && -f "$CONFIG_FILE" ]]; then
        local cfg_port=$(grep -o '"port":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4 || true)
        [[ -n "$cfg_port" ]] && PORT="$cfg_port"
    fi
    
    [[ -z "$CF_DOMAIN" || -z "$UUID" ]] && {
        log_error "Missing config: CF_DOMAIN or UUID"
        return 1
    }
    
    log_info "Configuration: Domain=$CF_DOMAIN, UUID=$UUID, Port=$PORT"
}

# Detect architecture
detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        armv7l|armhf) echo "arm" ;;
        *) log_error "Unsupported arch: $(uname -m)"; return 1 ;;
    esac
}

# Download sing-box with version detection
download_singbox() {
    log_info "Downloading sing-box..."
    local arch=$(detect_arch) || return 1
    mkdir -p "$BIN_DIR"
    
    local version=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | grep '"tag_name"' | head -1 | sed 's/.*"v//;s/".*//' || echo "1.9.0")
    version=${version:-1.9.0}
    
    local url="https://github.com/SagerNet/sing-box/releases/download/v${version}/sing-box-${version}-linux-${arch}.tar.gz"
    log_info "Sing-box URL: $url"
    
    curl -fsSL -o /tmp/sing-box.tar.gz "$url" || return 1
    tar -xzf /tmp/sing-box.tar.gz -C "$BIN_DIR" --strip-components=1 2>/dev/null || true
    rm -f /tmp/sing-box.tar.gz
    
    [[ ! -f "$SINGBOX_BIN" ]] && {
        local found=$(find "$BIN_DIR" -name "sing-box" -type f 2>/dev/null | head -1)
        [[ -n "$found" ]] && mv "$found" "$SINGBOX_BIN"
    }
    
    chmod +x "$SINGBOX_BIN" || true
    "$SINGBOX_BIN" version >/dev/null 2>&1 && {
        log_info "[OK] Sing-box ready"
        return 0
    }
    log_error "Sing-box download failed"
    return 1
}

# Download cloudflared with version detection
download_cloudflared() {
    log_info "Downloading cloudflared..."
    local arch=$(detect_arch) || return 1
    mkdir -p "$BIN_DIR"
    
    local version=$(curl -s https://api.github.com/repos/cloudflare/cloudflared/releases/latest | grep '"tag_name"' | head -1 | sed 's/.*"//;s/".*//' || echo "latest")
    version=${version:-latest}
    
    local url="https://github.com/cloudflare/cloudflared/releases/download/${version}/cloudflared-linux-${arch}"
    log_info "Cloudflared URL: $url"
    
    curl -fsSL -o "$CLOUDFLARED_BIN" "$url" || {
        log_error "Cloudflared download failed"
        return 1
    }
    
    chmod +x "$CLOUDFLARED_BIN" || true
    "$CLOUDFLARED_BIN" --version >/dev/null 2>&1 && {
        log_info "[OK] Cloudflared ready"
        return 0
    }
    log_error "Cloudflared validation failed"
    return 1
}

# Generate sing-box configuration
generate_singbox_config() {
    log_info "Generating sing-box config..."
    cat > "$SINGBOX_CONFIG" <<EOF
{
  "log": {"level": "info"},
  "inbounds": [{
    "type": "vmess",
    "listen": "127.0.0.1",
    "listen_port": $PORT,
    "users": [{"uuid": "$UUID", "alterId": 0}],
    "transport": {"type": "ws", "path": "/ws"}
  }],
  "outbounds": [{"type": "direct"}]
}
EOF
    log_info "[OK] Config generated"
}

# Start sing-box service
start_singbox() {
    log_info "Starting sing-box on 127.0.0.1:$PORT..."
    [[ ! -f "$SINGBOX_BIN" ]] && {
        log_error "Binary not found: $SINGBOX_BIN"
        return 1
    }
    
    nohup "$SINGBOX_BIN" run -c "$SINGBOX_CONFIG" > "$WORK_DIR/singbox.log" 2>&1 &
    local pid=$!
    echo "$pid" > "$WORK_DIR/singbox.pid"
    sleep 2
    
    kill -0 "$pid" 2>/dev/null && {
        log_info "[OK] Sing-box started (PID: $pid)"
        return 0
    }
    log_error "Sing-box failed to start"
    return 1
}

# Start cloudflared tunnel
start_cloudflared() {
    log_info "Starting cloudflared tunnel..."
    [[ ! -f "$CLOUDFLARED_BIN" ]] && {
        log_error "Binary not found: $CLOUDFLARED_BIN"
        return 1
    }
    
    if [[ -n "$CF_DOMAIN" && -n "$CF_TOKEN" ]]; then
        log_info "Fixed domain: $CF_DOMAIN"
        nohup "$CLOUDFLARED_BIN" tunnel --no-autoupdate run --token "$CF_TOKEN" > "$WORK_DIR/cloudflared.log" 2>&1 &
    else
        log_info "Temporary tunnel (trycloudflare)"
        nohup "$CLOUDFLARED_BIN" tunnel --url "http://127.0.0.1:$PORT" > "$WORK_DIR/cloudflared.log" 2>&1 &
    fi
    
    local pid=$!
    echo "$pid" > "$WORK_DIR/cloudflared.pid"
    sleep 3
    
    kill -0 "$pid" 2>/dev/null && {
        log_info "[OK] Cloudflared started (PID: $pid)"
        return 0
    }
    log_error "Cloudflared failed to start"
    return 1
}

# Generate VMESS subscription
generate_subscription() {
    log_info "Generating VMESS subscription..."
    
    local domain="${CF_DOMAIN}"
    [[ -z "$domain" ]] && {
        sleep 2
        domain=$(grep -o 'https://.*\.trycloudflare\.com' "$WORK_DIR/cloudflared.log" 2>/dev/null | head -1 | sed 's|https://||' || true)
    }
    
    [[ -z "$domain" ]] && {
        log_error "No domain found for subscription"
        return 1
    }
    
    local node_json='{"v":"2","ps":"zampto-argo","add":"'"$domain"'","port":"443","id":"'"$UUID"'","aid":"0","net":"ws","type":"none","host":"'"$domain"'","path":"/ws","tls":"tls","sni":"'"$domain"'","fingerprint":"chrome"}'
    local node_b64=$(printf '%s' "$node_json" | base64 -w 0)
    
    mkdir -p "$(dirname "$SUBSCRIPTION_FILE")"
    printf '%s' "vmess://${node_b64}" | base64 -w 0 > "$SUBSCRIPTION_FILE"
    
    log_info "[OK] Subscription generated: https://$domain/sub"
}

# Main execution
main() {
    log_info "========================================"
    log_info "Wispbyte Argo Sing-box Deploy v1.2.0"
    log_info "========================================"
    
    mkdir -p "$WORK_DIR" "$BIN_DIR"
    
    load_config || exit 1
    download_singbox || exit 1
    download_cloudflared || exit 1
    generate_singbox_config
    start_singbox || exit 1
    start_cloudflared || exit 1
    generate_subscription
    
    log_info "========================================"
    log_info "[SUCCESS] Deployment completed"
    log_info "[SINGBOX] PID: $(cat "$WORK_DIR/singbox.pid" 2>/dev/null || echo 'unknown')"
    log_info "[CLOUDFLARED] PID: $(cat "$WORK_DIR/cloudflared.pid" 2>/dev/null || echo 'unknown')"
    log_info "[LOGS] $WORK_DIR"
    log_info "========================================"
}

trap "log_info 'Received signal, exiting...'; exit 0" SIGTERM SIGINT
main "$@"
