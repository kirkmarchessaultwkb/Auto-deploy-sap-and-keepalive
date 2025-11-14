#!/bin/bash
set -euo pipefail

# Enable job control
set +m

# ============================================================================
# Configuration and Global Variables
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${SCRIPT_DIR}/bin"
LOG_DIR="${SCRIPT_DIR}/logs"
NPM_DIR="${SCRIPT_DIR}/.npm"
ETC_DIR="${SCRIPT_DIR}/etc"
XRAY_BIN="${BIN_DIR}/xray"
XRAY_CONFIG="${ETC_DIR}/xray-config.json"
CLOUDFLARED_BIN="${BIN_DIR}/cloudflared"
PID_XRAY=""
PID_CLOUDFLARED=""
PID_NODE=""
CLOUDFLARE_URL=""
WATCHDOG_INTERVAL=30

# Environment variables with defaults
UUID="${UUID:-}"
CFIP="${CFIP:-}"
CFPORT="${CFPORT:-443}"
DISABLE_ARGO="${DISABLE_ARGO:-0}"
ARGO_DOMAIN="${ARGO_DOMAIN:-}"
ARGO_AUTH="${ARGO_AUTH:-}"
SERVER_PORT="${SERVER_PORT:-3000}"

# ============================================================================
# Utility Functions
# ============================================================================

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

log_error() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $*" >&2
}

generate_uuid() {
  if command -v uuidgen >/dev/null 2>&1; then
    uuidgen | tr '[:upper:]' '[:lower:]'
  else
    cat /proc/sys/kernel/random/uuid 2>/dev/null || \
    od -An -tx1 -N16 /dev/urandom | tr ' ' '-' | sed 's/^-//' | tr '[:upper:]' '[:lower:]'
  fi
}

detect_arch() {
  local arch=$(uname -m)
  case "$arch" in
    x86_64|amd64)
      echo "amd64"
      ;;
    aarch64|arm64)
      echo "arm64"
      ;;
    armv7|armhf)
      echo "armv7"
      ;;
    *)
      log_error "Unsupported architecture: $arch"
      return 1
      ;;
  esac
}

# ============================================================================
# Setup: Create directories and validate environment
# ============================================================================

setup_directories() {
  log "Setting up directories..."
  mkdir -p "$BIN_DIR" "$LOG_DIR" "$NPM_DIR" "$ETC_DIR"
}

validate_environment() {
  log "Validating environment..."
  
  # Generate UUID if not provided
  if [ -z "$UUID" ]; then
    log "Generating new UUID..."
    UUID=$(generate_uuid)
    export UUID
    log "Generated UUID: $UUID"
  fi
  
  log "Environment configuration:"
  log "  UUID: $UUID"
  log "  CFIP: ${CFIP:-not set}"
  log "  CFPORT: $CFPORT"
  log "  DISABLE_ARGO: $DISABLE_ARGO"
  log "  ARGO_DOMAIN: ${ARGO_DOMAIN:-not set}"
  log "  SERVER_PORT: $SERVER_PORT"
}

# ============================================================================
# Xray Setup and Management
# ============================================================================

download_xray() {
  log "Downloading Xray binary..."
  
  if [ -f "$XRAY_BIN" ]; then
    log "Xray binary already exists at: $XRAY_BIN"
    return 0
  fi
  
  local arch=$(detect_arch)
  
  # Try to get latest release info with retries
  local release_data=""
  local retry_count=0
  while [ -z "$release_data" ] && [ $retry_count -lt 3 ]; do
    release_data=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases/latest")
    if [ -z "$release_data" ] || echo "$release_data" | grep -q "404"; then
      retry_count=$((retry_count + 1))
      sleep 2
    else
      break
    fi
  done
  
  if [ -z "$release_data" ]; then
    log_error "Failed to fetch Xray release information"
    return 1
  fi
  
  # Determine the correct release file for the architecture
  local download_url=""
  case "$arch" in
    amd64)
      download_url=$(echo "$release_data" | grep -oP '"browser_download_url":"[^"]*linux-64\.zip"' | head -1 | cut -d'"' -f4)
      ;;
    arm64)
      download_url=$(echo "$release_data" | grep -oP '"browser_download_url":"[^"]*linux-arm64-v8\.zip"' | head -1 | cut -d'"' -f4)
      ;;
    armv7)
      download_url=$(echo "$release_data" | grep -oP '"browser_download_url":"[^"]*linux-arm32-v7\.zip"' | head -1 | cut -d'"' -f4)
      ;;
  esac
  
  if [ -z "$download_url" ]; then
    log_error "Could not find Xray download URL for architecture: $arch"
    return 1
  fi
  
  log "Downloading from: $download_url"
  
  local temp_dir=$(mktemp -d)
  trap "rm -rf $temp_dir" RETURN
  
  if ! curl -L -o "${temp_dir}/xray.zip" "$download_url"; then
    log_error "Failed to download Xray"
    return 1
  fi
  
  if ! command -v unzip >/dev/null 2>&1; then
    log_error "unzip command not found"
    return 1
  fi
  
  if ! unzip -q -o "${temp_dir}/xray.zip" -d "$temp_dir"; then
    log_error "Failed to extract Xray"
    return 1
  fi
  
  if ! cp "${temp_dir}/xray" "$XRAY_BIN"; then
    log_error "Failed to copy Xray binary"
    return 1
  fi
  
  chmod +x "$XRAY_BIN"
  
  # Strip the binary to reduce size
  if command -v strip >/dev/null 2>&1; then
    strip "$XRAY_BIN" || true
  fi
  
  log "Xray binary ready at: $XRAY_BIN"
}

generate_xray_config() {
  log "Generating Xray configuration..."
  
  cat > "$XRAY_CONFIG" <<'EOF'
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 10000,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "PLACEHOLDER_UUID",
            "level": 1,
            "alterId": 0
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/ws"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "blocked"
    }
  ],
  "routing": {
    "rules": [
      {
        "outboundTag": "blocked",
        "domain": ["geosite:category-ads"]
      }
    ]
  }
}
EOF
  
  # Replace UUID placeholder
  sed -i "s/PLACEHOLDER_UUID/${UUID}/g" "$XRAY_CONFIG"
  
  log "Xray configuration generated at: $XRAY_CONFIG"
}

# ============================================================================
# Cloudflared Setup and Management
# ============================================================================

download_cloudflared() {
  if [ "$DISABLE_ARGO" = "1" ]; then
    log "Argo tunneling disabled (DISABLE_ARGO=1)"
    return 0
  fi
  
  # If using fixed tunnel, we might not need to download cloudflared
  if [ -n "$ARGO_DOMAIN" ] && [ -n "$ARGO_AUTH" ]; then
    log "Using fixed Argo tunnel (domain-based)"
    return 0
  fi
  
  # Check if already downloaded
  if [ -f "$CLOUDFLARED_BIN" ]; then
    log "Cloudflared binary already exists at: $CLOUDFLARED_BIN"
    return 0
  fi
  
  log "Setting up ephemeral Argo tunnel, downloading Cloudflared..."
  
  local arch=$(detect_arch)
  local cf_arch=""
  
  case "$arch" in
    amd64)
      cf_arch="amd64"
      ;;
    arm64)
      cf_arch="arm64"
      ;;
    armv7)
      cf_arch="arm32"
      ;;
  esac
  
  local download_url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${cf_arch}"
  
  log "Downloading Cloudflared from: $download_url"
  
  if ! curl -L -o "$CLOUDFLARED_BIN" "$download_url"; then
    log_error "Failed to download Cloudflared"
    return 1
  fi
  
  chmod +x "$CLOUDFLARED_BIN"
  
  # Strip the binary
  if command -v strip >/dev/null 2>&1; then
    strip "$CLOUDFLARED_BIN" || true
  fi
  
  log "Cloudflared binary ready at: $CLOUDFLARED_BIN"
}

start_cloudflared() {
  if [ "$DISABLE_ARGO" = "1" ]; then
    log "Argo tunneling disabled, skipping Cloudflared startup"
    return 0
  fi
  
  if [ -n "$ARGO_DOMAIN" ] && [ -n "$ARGO_AUTH" ]; then
    log "Using fixed Argo tunnel, skipping Cloudflared startup"
    return 0
  fi
  
  log "Starting Cloudflared for ephemeral tunnel..."
  
  if [ ! -f "$CLOUDFLARED_BIN" ]; then
    log_error "Cloudflared binary not found at $CLOUDFLARED_BIN"
    return 1
  fi
  
  local cf_log="${LOG_DIR}/cloudflared.log"
  
  # Start cloudflared with niceness optimization
  nice -n 10 "$CLOUDFLARED_BIN" tunnel --url http://127.0.0.1:10000 --no-autoupdate >"$cf_log" 2>&1 &
  PID_CLOUDFLARED=$!
  
  log "Cloudflared started with PID: $PID_CLOUDFLARED"
  
  # Wait for Cloudflared to initialize and extract the URL
  sleep 5
  
  # Extract the URL from Cloudflared logs (try multiple patterns)
  CLOUDFLARE_URL=$(grep -oP 'https://[a-zA-Z0-9\-]+\.trycloudflare\.com' "$cf_log" | head -1)
  
  if [ -z "$CLOUDFLARE_URL" ]; then
    log "Warning: Could not extract Cloudflare tunnel URL from logs yet, will retry"
    return 0
  fi
  
  log "Cloudflare tunnel URL: $CLOUDFLARE_URL"
}

# ============================================================================
# Xray Startup
# ============================================================================

start_xray() {
  log "Starting Xray..."
  
  if [ ! -f "$XRAY_BIN" ]; then
    download_xray
  fi
  
  if [ ! -f "$XRAY_CONFIG" ]; then
    generate_xray_config
  fi
  
  local xray_log="${LOG_DIR}/xray.log"
  
  # Use ionice and nice for resource optimization
  if command -v ionice >/dev/null 2>&1; then
    ionice -c 3 nice -n 15 "$XRAY_BIN" run -c "$XRAY_CONFIG" >"$xray_log" 2>&1 &
  else
    nice -n 15 "$XRAY_BIN" run -c "$XRAY_CONFIG" >"$xray_log" 2>&1 &
  fi
  
  PID_XRAY=$!
  log "Xray started with PID: $PID_XRAY"
  
  # Wait a moment for Xray to initialize
  sleep 2
  
  if ! kill -0 "$PID_XRAY" 2>/dev/null; then
    log_error "Xray failed to start"
    cat "$xray_log" >&2
    return 1
  fi
}

# ============================================================================
# Node.js HTTP Server Startup
# ============================================================================

start_node_server() {
  log "Starting Node.js HTTP server..."
  
  local node_log="${LOG_DIR}/node.log"
  
  cd "$SCRIPT_DIR"
  nice -n 10 node index.js >"$node_log" 2>&1 &
  PID_NODE=$!
  
  log "Node server started with PID: $PID_NODE"
  
  sleep 1
  
  if ! kill -0 "$PID_NODE" 2>/dev/null; then
    log_error "Node server failed to start"
    cat "$node_log" >&2
    return 1
  fi
}

# ============================================================================
# Subscription Generation
# ============================================================================

generate_subscription() {
  log "Generating VMess subscription..."
  
  local host=""
  local port=""
  
  # Determine the best host/port based on active mode
  if [ -n "$CLOUDFLARE_URL" ]; then
    # Extract hostname from CloudFlare URL
    host=$(echo "$CLOUDFLARE_URL" | sed 's|https://||' | sed 's|/.*||')
    port=443
    log "Using Cloudflare tunnel: $host:$port"
  elif [ -n "$ARGO_DOMAIN" ]; then
    host="$ARGO_DOMAIN"
    port=443
    log "Using fixed Argo domain: $host:$port"
  elif [ -n "$CFIP" ]; then
    host="$CFIP"
    port="$CFPORT"
    log "Using CF IP: $host:$port"
  else
    # Fallback to localhost for testing
    host="127.0.0.1"
    port=10000
    log "Using localhost (development mode): $host:$port"
  fi
  
  # Build VMess object
  local vmess_json=$(cat <<EOF
{
  "v": "2",
  "ps": "Xray-VMess",
  "add": "${host}",
  "port": "${port}",
  "id": "${UUID}",
  "aid": 0,
  "net": "ws",
  "type": "none",
  "host": "${host}",
  "path": "/ws",
  "tls": "tls",
  "sni": "${host}"
}
EOF
  )
  
  # Base64 encode the VMess link
  local vmess_link=$(echo -n "vmess://$(echo -n "$vmess_json" | base64 -w 0)" | tr -d '\n')
  
  # Write subscription file
  mkdir -p "$NPM_DIR"
  echo "$vmess_link" > "${NPM_DIR}/sub.txt"
  
  log "Subscription generated at: ${NPM_DIR}/sub.txt"
  log "Subscription link: $vmess_link"
}

# ============================================================================
# Process Management and Watchdog
# ============================================================================

cleanup() {
  log "Cleaning up processes..."
  
  for pid in "$PID_NODE" "$PID_CLOUDFLARED" "$PID_XRAY"; do
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      log "Terminating process $pid..."
      kill "$pid" 2>/dev/null || true
      sleep 1
      kill -9 "$pid" 2>/dev/null || true
    fi
  done
  
  log "Cleanup complete"
}

watchdog_loop() {
  log "Starting watchdog loop (${WATCHDOG_INTERVAL}s cadence)..."
  
  while true; do
    sleep "$WATCHDOG_INTERVAL"
    
    # Check Xray
    if [ -n "$PID_XRAY" ] && ! kill -0 "$PID_XRAY" 2>/dev/null; then
      log_error "Xray process died, restarting..."
      start_xray || log_error "Failed to restart Xray"
      PID_XRAY=$!
    fi
    
    # Check Cloudflared (if enabled and using ephemeral tunnel)
    if [ "$DISABLE_ARGO" != "1" ] && [ -z "$ARGO_DOMAIN" ]; then
      if [ -n "$PID_CLOUDFLARED" ] && ! kill -0 "$PID_CLOUDFLARED" 2>/dev/null; then
        log_error "Cloudflared process died, restarting..."
        start_cloudflared || log_error "Failed to restart Cloudflared"
        PID_CLOUDFLARED=$!
      fi
    fi
    
    # Check Node server
    if [ -n "$PID_NODE" ] && ! kill -0 "$PID_NODE" 2>/dev/null; then
      log_error "Node server died, restarting..."
      start_node_server || log_error "Failed to restart Node server"
      PID_NODE=$!
    fi
  done
}

# ============================================================================
# Signal Handlers
# ============================================================================

handle_sigterm() {
  log "Received SIGTERM"
  cleanup
  exit 0
}

handle_sigint() {
  log "Received SIGINT"
  cleanup
  exit 0
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
  log "=========================================="
  log "Initializing sin-box Xray runner"
  log "=========================================="
  
  # Set up signal handlers
  trap handle_sigterm SIGTERM
  trap handle_sigint SIGINT
  trap cleanup EXIT
  
  # Initialize
  setup_directories
  validate_environment
  
  # Setup and start services
  download_xray
  generate_xray_config
  start_xray
  
  download_cloudflared
  start_cloudflared
  
  start_node_server
  
  # Generate subscription
  generate_subscription
  
  log "=========================================="
  log "All services started successfully"
  log "=========================================="
  
  # Start watchdog
  watchdog_loop &
  local pid_watchdog=$!
  
  # Keep the script alive
  wait
}

# Execute main
main "$@"
