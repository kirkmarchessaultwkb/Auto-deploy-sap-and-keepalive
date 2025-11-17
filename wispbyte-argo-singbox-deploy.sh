#!/bin/bash
# =============================================================================
# Wispbyte Argo Sing-box Deploy (Simplified for Zampto)
# Version: 1.1.0 - Read from environment variables
# Architecture: sing-box (127.0.0.1:PORT) → cloudflared → CF tunnel (443)
# =============================================================================

set -o pipefail

# Working directories
WORK_DIR="/tmp/wispbyte-singbox"
BIN_DIR="$WORK_DIR/bin"
SINGBOX_BIN="$BIN_DIR/sing-box"
CLOUDFLARED_BIN="$BIN_DIR/cloudflared"
SINGBOX_CONFIG="$WORK_DIR/config.json"
SUBSCRIPTION_FILE="/home/container/.npm/sub.txt"
LOG_FILE="$WORK_DIR/deploy.log"

# Read configuration from environment variables (exported by start.sh)
# Set defaults if not provided
CF_DOMAIN="${CF_DOMAIN:-}"
CF_TOKEN="${CF_TOKEN:-}"
UUID="${UUID:-}"
PORT="${PORT:-27039}"

log() { echo "[$(date +'%H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

validate_config() {
    log "[INFO] Validating configuration..."
    log "[INFO] Domain: ${CF_DOMAIN:-'not set'}, UUID: ${UUID:-'not set'}, Port: $PORT"
    
    if [[ -z "$UUID" ]]; then
        log "[ERROR] UUID not set (required)"
        return 1
    fi
    
    log "[OK] Configuration valid"
    return 0
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        armv7l|armhf) echo "arm" ;;
        *) log "[ERROR] Unsupported arch: $(uname -m)"; exit 1 ;;
    esac
}

download_singbox() {
    log "[INFO] Downloading sing-box..."
    local arch=$(detect_arch)
    local url="https://github.com/SagerNet/sing-box/releases/latest/download/sing-box-linux-${arch}.tar.gz"
    
    mkdir -p "$BIN_DIR"
    curl -fsSL "$url" | tar -xz -C "$BIN_DIR" --strip-components=1 2>/dev/null
    
    [[ ! -f "$SINGBOX_BIN" ]] && {
        local found=$(find "$BIN_DIR" -name "*sing-box*" -type f | head -1)
        [[ -n "$found" ]] && mv "$found" "$SINGBOX_BIN"
    }
    
    chmod +x "$SINGBOX_BIN"
    "$SINGBOX_BIN" version >/dev/null 2>&1 && { log "[OK] Sing-box ready"; return 0; }
    log "[ERROR] Sing-box download failed"
    return 1
}

download_cloudflared() {
    log "[INFO] Downloading cloudflared..."
    local arch=$(detect_arch)
    local url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${arch}"
    
    mkdir -p "$BIN_DIR"
    curl -fsSL -o "$CLOUDFLARED_BIN" "$url" && chmod +x "$CLOUDFLARED_BIN"
    "$CLOUDFLARED_BIN" --version >/dev/null 2>&1 && { log "[OK] Cloudflared ready"; return 0; }
    log "[ERROR] Cloudflared download failed"
    return 1
}

generate_singbox_config() {
    log "[INFO] Generating sing-box config..."
    cat > "$SINGBOX_CONFIG" <<EOF
{
  "log": {"level": "info"},
  "inbounds": [{
    "type": "vmess",
    "tag": "vmess-in",
    "listen": "127.0.0.1",
    "listen_port": $PORT,
    "users": [{"uuid": "$UUID", "alterId": 0}],
    "transport": {"type": "ws", "path": "/ws"}
  }],
  "outbounds": [{"type": "direct", "tag": "direct"}]
}
EOF
    log "[OK] Config generated"
}

start_singbox() {
    log "[INFO] Starting sing-box on 127.0.0.1:$PORT..."
    [[ ! -f "$SINGBOX_BIN" ]] && { log "[ERROR] Binary not found"; return 1; }
    
    nohup "$SINGBOX_BIN" run -c "$SINGBOX_CONFIG" > "$WORK_DIR/singbox.log" 2>&1 &
    local pid=$!
    echo "$pid" > "$WORK_DIR/singbox.pid"
    
    sleep 2
    kill -0 "$pid" 2>/dev/null && { log "[OK] Sing-box started (PID: $pid)"; return 0; }
    log "[ERROR] Sing-box failed to start"
    return 1
}

start_cloudflared() {
    log "[INFO] Starting cloudflared tunnel..."
    [[ ! -f "$CLOUDFLARED_BIN" ]] && { log "[ERROR] Binary not found"; return 1; }
    
    if [[ -n "$CF_DOMAIN" && -n "$CF_TOKEN" ]]; then
        log "[INFO] Fixed domain: $CF_DOMAIN"
        nohup "$CLOUDFLARED_BIN" tunnel --no-autoupdate run --token "$CF_TOKEN" > "$WORK_DIR/cloudflared.log" 2>&1 &
    else
        log "[INFO] Temporary tunnel (trycloudflare)"
        nohup "$CLOUDFLARED_BIN" tunnel --url "http://127.0.0.1:$PORT" > "$WORK_DIR/cloudflared.log" 2>&1 &
    fi
    
    local pid=$!
    echo "$pid" > "$WORK_DIR/cloudflared.pid"
    
    sleep 3
    kill -0 "$pid" 2>/dev/null && { log "[OK] Cloudflared started (PID: $pid)"; return 0; }
    log "[ERROR] Cloudflared failed to start"
    return 1
}

generate_subscription() {
    log "[INFO] Generating VMESS subscription..."
    
    local domain="${CF_DOMAIN}"
    [[ -z "$domain" ]] && {
        log "[INFO] Extracting domain from cloudflared log..."
        sleep 2
        domain=$(grep -o 'https://.*\.trycloudflare\.com' "$WORK_DIR/cloudflared.log" | head -1 | sed 's|https://||')
    }
    
    [[ -z "$domain" ]] && { log "[ERROR] No domain found"; return 1; }
    
    local node_json='{"v":"2","ps":"zampto-argo","add":"'"$domain"'","port":"443","id":"'"$UUID"'","aid":"0","net":"ws","type":"none","host":"'"$domain"'","path":"/ws","tls":"tls","sni":"'"$domain"'","fingerprint":"chrome"}'
    local node_b64=$(printf '%s' "$node_json" | base64 -w 0)
    local vmess_url="vmess://${node_b64}"
    
    mkdir -p "$(dirname "$SUBSCRIPTION_FILE")"
    printf '%s' "$vmess_url" | base64 -w 0 > "$SUBSCRIPTION_FILE"
    
    log "[OK] Subscription generated"
    log "[URL] https://$domain/sub"
    log "[FILE] $SUBSCRIPTION_FILE"
}

main() {
    log "========================================"
    log "Wispbyte Argo Sing-box Deploy v1.1.0"
    log "========================================"
    
    mkdir -p "$WORK_DIR" "$BIN_DIR"
    
    validate_config || exit 1
    download_singbox || exit 1
    download_cloudflared || exit 1
    generate_singbox_config
    start_singbox || exit 1
    start_cloudflared || exit 1
    generate_subscription
    
    log "========================================"
    log "[SUCCESS] Deployment completed"
    log "[SINGBOX] PID: $(cat "$WORK_DIR/singbox.pid" 2>/dev/null || echo 'unknown')"
    log "[CLOUDFLARED] PID: $(cat "$WORK_DIR/cloudflared.pid" 2>/dev/null || echo 'unknown')"
    log "[LOGS] $WORK_DIR"
    log "========================================"
}

trap "log 'Received signal, exiting...'; exit 0" SIGTERM SIGINT
main "$@"
