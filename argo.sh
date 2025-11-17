#!/bin/bash
set -e

# =============================================================================
# Minimal Argo Tunnel Script for Zampto (wispbyte style)
# Version: 1.0.0
# Description: Simple, reliable keepalive + cloudflared tunnel
# =============================================================================

# Configuration
WORKDIR="/tmp/argo-zampto"
CONFIG_FILE="/home/container/config.json"
PORT="27039"

# Create workdir
mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "[INFO] Starting minimal Argo tunnel setup..."
echo "[INFO] WORKDIR: $WORKDIR"
echo "[INFO] PORT: $PORT"

# Load configuration from config.json
if [[ -f "$CONFIG_FILE" ]]; then
    echo "[INFO] Loading configuration from $CONFIG_FILE"
    CF_DOMAIN=$(grep -o '"CF_DOMAIN"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' || echo "")
    CF_TOKEN=$(grep -o '"CF_TOKEN"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' || echo "")
    ARGO_PORT=$(grep -o '"ARGO_PORT"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' || echo "27039")
    
    if [[ "$ARGO_PORT" != "27039" ]]; then
        PORT="$ARGO_PORT"
        echo "[INFO] Using port from config: $PORT"
    fi
    
    echo "[INFO] CF_DOMAIN: ${CF_DOMAIN:-'not set'}"
else
    echo "[WARN] Config file not found, using defaults"
fi

# Download cloudflared
if [[ ! -f "cloudflared" ]]; then
    echo "[INFO] Downloading cloudflared..."
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64|amd64) CLOUDFLARED_ARCH="amd64" ;;
        aarch64|arm64) CLOUDFLARED_ARCH="arm64" ;;
        armv7l|armhf) CLOUDFLARED_ARCH="arm" ;;
        *) echo "[ERROR] Unsupported architecture: $ARCH"; exit 1 ;;
    esac
    
    CLOUDFLARED_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CLOUDFLARED_ARCH}"
    if curl -fsSL "$CLOUDFLARED_URL" -o cloudflared; then
        chmod +x cloudflared
        echo "[INFO] Cloudflared downloaded successfully"
    else
        echo "[ERROR] Failed to download cloudflared"
        exit 1
    fi
fi

# Start keepalive HTTP server
echo "[INFO] Starting keepalive on port $PORT..."
echo '<!DOCTYPE html><html><head><title>Zampto Keepalive</title></head><body><h1>Zampto Keepalive Server</h1><p>Server is running: '$(date)'</p></body></html>' > index.html

python3 -m http.server "$PORT" --bind 127.0.0.1 >/dev/null 2>&1 &
KEEP_PID=$!
echo "[INFO] Keepalive PID: $KEEP_PID"

sleep 2
if ! kill -0 "$KEEP_PID" 2>/dev/null; then
    echo "[ERROR] HTTP server failed to start"
    exit 1
fi

# Start cloudflared tunnel
echo "[INFO] Starting cloudflared tunnel..."

if [[ -n "$CF_DOMAIN" && -n "$CF_TOKEN" ]]; then
    echo "[INFO] Starting fixed domain tunnel: $CF_DOMAIN"
    
    cat > tunnel.yml << EOF
tunnel: $CF_DOMAIN
credentials-file: credentials.json
ingress:
  - hostname: $CF_DOMAIN
    service: http://127.0.0.1:$PORT
  - service: http_status:404
EOF
    
    cat > credentials.json << EOF
{
  "AccountTag": "$(echo "$CF_TOKEN" | cut -d':' -f1)",
  "TunnelSecret": "$(echo "$CF_TOKEN" | cut -d':' -f2-)",
  "TunnelID": "$(echo "$CF_TOKEN" | cut -d':' -f3)"
}
EOF
    
    nohup ./cloudflared tunnel --config tunnel.yml run >/dev/null 2>&1 &
    CF_PID=$!
    echo "[INFO] Fixed domain tunnel started (PID: $CF_PID)"
    echo "[INFO] Tunnel URL: https://$CF_DOMAIN"
else
    echo "[INFO] Starting temporary tunnel (trycloudflare)"
    nohup ./cloudflared tunnel --url "http://127.0.0.1:$PORT" >/tmp/cloudflared.log 2>&1 &
    CF_PID=$!
    
    sleep 5
    TUNNEL_URL=$(grep -o 'https://.*\.trycloudflare\.com' /tmp/cloudflared.log | head -1)
    if [[ -n "$TUNNEL_URL" ]]; then
        echo "[INFO] Tunnel URL: $TUNNEL_URL"
    else
        echo "[WARN] Could not extract tunnel URL, check /tmp/cloudflared.log"
    fi
fi

sleep 2
if ! kill -0 "$CF_PID" 2>/dev/null; then
    echo "[ERROR] Cloudflared failed to start"
    kill "$KEEP_PID" 2>/dev/null
    exit 1
fi

echo "KEEP_PID=$KEEP_PID" > pids.txt
echo "CF_PID=$CF_PID" >> pids.txt

echo "[INFO] ======================================="
echo "[INFO] Setup completed successfully"
echo "[INFO] Keepalive server: PID $KEEP_PID (port $PORT)"
echo "[INFO] Cloudflared tunnel: PID $CF_PID"
echo "[INFO] ======================================="

cleanup() {
    echo "[INFO] Cleaning up..."
    if [[ -f "pids.txt" ]]; then
        while IFS= read -r line; do
            PID=$(echo "$line" | cut -d'=' -f2)
            kill "$PID" 2>/dev/null
        done < pids.txt
    fi
    exit 0
}

trap cleanup SIGTERM SIGINT
echo "[INFO] Services are running. Press Ctrl+C to stop."
wait