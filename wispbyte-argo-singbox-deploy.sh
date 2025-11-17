#!/bin/bash
set -euo pipefail

# Wispbyte Argo Sing-box Deploy v1.3.0 - Download and Deployment Only
# Receives environment variables from start.sh (CF_DOMAIN, UUID, PORT, etc)

WORK_DIR="/home/container/argo-tuic"
BIN_DIR="$WORK_DIR/bin"
SINGBOX_BIN="$BIN_DIR/sing-box"
SINGBOX_CONFIG="$WORK_DIR/config.json"
CLOUDFLARED_BIN="$BIN_DIR/cloudflared"
SUBSCRIPTION_FILE="/home/container/.npm/sub.txt"

log() { echo "[$(date +'%H:%M:%S')] [INFO] $1"; }
log_error() { echo "[$(date +'%H:%M:%S')] [ERROR] $1" >&2; }

# Validate environment variables
[[ -z "${CF_DOMAIN:-}" || -z "${UUID:-}" ]] && { log_error "Missing CF_DOMAIN or UUID"; exit 1; }

PORT=${PORT:-27039}
mkdir -p "$WORK_DIR" "$BIN_DIR"
cd "$WORK_DIR"

log "========================================"
log "Wispbyte Argo Sing-box Deploy v1.3.0"
log "========================================"
log "Config: Domain=$CF_DOMAIN, Port=$PORT"

# Architecture detection
ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64) ARCH_SHORT="amd64" ;;
    aarch64|arm64) ARCH_SHORT="arm64" ;;
    armv7l) ARCH_SHORT="arm" ;;
    *) log_error "Unsupported arch: $ARCH"; exit 1 ;;
esac
log "Architecture: $ARCH ($ARCH_SHORT)"

# Download sing-box
log "Downloading sing-box..."
SINGBOX_VERSION=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest 2>/dev/null | grep '"tag_name"' | head -1 | sed 's/.*"v//;s/".*//' || echo "1.9.0")
SINGBOX_VERSION=${SINGBOX_VERSION:-1.9.0}
SINGBOX_URL="https://github.com/SagerNet/sing-box/releases/download/v${SINGBOX_VERSION}/sing-box-${SINGBOX_VERSION}-linux-${ARCH_SHORT}.tar.gz"
log "Sing-box URL: $SINGBOX_URL"

curl -fsSL -o /tmp/sing-box.tar.gz "$SINGBOX_URL" || { log_error "Sing-box download failed"; exit 1; }
tar -xzf /tmp/sing-box.tar.gz -C "$BIN_DIR" --strip-components=1 2>/dev/null || { log_error "Extraction failed"; exit 1; }
chmod +x "$SINGBOX_BIN" 2>/dev/null || true
rm -f /tmp/sing-box.tar.gz
log "Sing-box downloaded successfully"

# Create sing-box config
log "Creating sing-box config..."
cat > "$SINGBOX_CONFIG" <<EOF
{
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

# Start sing-box
log "Starting sing-box..."
nohup "$SINGBOX_BIN" run -c "$SINGBOX_CONFIG" > "$WORK_DIR/sing-box.log" 2>&1 &
SINGBOX_PID=$!
echo $SINGBOX_PID > "$WORK_DIR/sing-box.pid"
sleep 2

kill -0 $SINGBOX_PID 2>/dev/null && log "Sing-box started (PID: $SINGBOX_PID, Port: 127.0.0.1:$PORT)" || {
    log_error "Sing-box failed to start"
    tail -20 "$WORK_DIR/sing-box.log"
    exit 1
}

# Download cloudflared
log "Downloading cloudflared..."
CF_VERSION=$(curl -s https://api.github.com/repos/cloudflare/cloudflared/releases/latest 2>/dev/null | grep '"tag_name"' | head -1 | sed 's/.*"//;s/".*//' || echo "latest")
CF_VERSION=${CF_VERSION:-latest}

if [[ "$CF_VERSION" == "latest" ]]; then
    CF_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH_SHORT}"
else
    CF_URL="https://github.com/cloudflare/cloudflared/releases/download/${CF_VERSION}/cloudflared-linux-${ARCH_SHORT}"
fi

log "Cloudflared URL: $CF_URL"
curl -fsSL -o "$CLOUDFLARED_BIN" "$CF_URL" || { log_error "Cloudflared download failed"; exit 1; }
chmod +x "$CLOUDFLARED_BIN"
log "Cloudflared downloaded successfully"

# Start cloudflared tunnel
log "Starting cloudflared tunnel..."
if [[ -n "${CF_TOKEN:-}" ]]; then
    log "Using CF_TOKEN for fixed domain: $CF_DOMAIN"
    export TUNNEL_TOKEN="$CF_TOKEN"
    nohup "$CLOUDFLARED_BIN" tunnel run "$CF_DOMAIN" > "$WORK_DIR/cloudflared.log" 2>&1 &
else
    log "Using temporary tunnel"
    nohup "$CLOUDFLARED_BIN" tunnel --url "http://127.0.0.1:$PORT" > "$WORK_DIR/cloudflared.log" 2>&1 &
fi

CF_PID=$!
echo $CF_PID > "$WORK_DIR/cloudflared.pid"
sleep 3

kill -0 $CF_PID 2>/dev/null && log "Cloudflared started (PID: $CF_PID)" || {
    log_error "Cloudflared failed to start"
    tail -20 "$WORK_DIR/cloudflared.log"
    exit 1
}

# Generate subscription
log "Generating subscription..."
mkdir -p /home/container/.npm

NODE_JSON=$(cat <<'SUBSCRIPTION'
{
  "v": "2",
  "ps": "zampto-argo",
  "add": "CF_DOMAIN_PLACEHOLDER",
  "port": "443",
  "id": "UUID_PLACEHOLDER",
  "aid": "0",
  "net": "ws",
  "type": "none",
  "host": "CF_DOMAIN_PLACEHOLDER",
  "path": "/ws",
  "tls": "tls",
  "sni": "CF_DOMAIN_PLACEHOLDER",
  "fingerprint": "chrome"
}
SUBSCRIPTION
)

NODE_JSON=${NODE_JSON//CF_DOMAIN_PLACEHOLDER/$CF_DOMAIN}
NODE_JSON=${NODE_JSON//UUID_PLACEHOLDER/$UUID}

SUBSCRIPTION=$(printf '%s' "$NODE_JSON" | base64 -w 0)
echo "vmess://$SUBSCRIPTION" > "$SUBSCRIPTION_FILE"

log "Subscription generated: $SUBSCRIPTION_FILE"
log "Subscription URL: https://$CF_DOMAIN/sub"

# Completion
log "========================================"
log "All services started successfully!"
log "  - Sing-box: PID $SINGBOX_PID (127.0.0.1:$PORT)"
log "  - Cloudflared: PID $CF_PID"
log "  - Subscription: $SUBSCRIPTION_FILE"
log "========================================"
