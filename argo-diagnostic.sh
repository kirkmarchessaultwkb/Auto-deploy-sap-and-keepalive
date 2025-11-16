#!/bin/bash

# =============================================================================
# Zampto Diagnostic-Friendly Argo Tunnel Script
# Version: 2.0.0
# Description: Enhanced logging and diagnostics for Argo tunnel in zampto env
# =============================================================================

set -o pipefail

# Log levels with timestamps and colors
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
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [✅ SUCCESS] $1"
}

log_debug() {
    if [[ "${DEBUG}" == "1" ]]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] [DEBUG] $1" >&2
    fi
}

format_secret_value() {
    local value="$1"

    if [[ -z "$value" ]]; then
        printf "%s" "(not set)"
        return
    fi

    local length=${#value}
    if (( length <= 10 )); then
        printf "%s" "$value"
    else
        printf "%s... (loaded)" "${value:0:6}"
    fi
}

# =============================================================================
# Configuration
# =============================================================================

CONFIG_FILE="/home/container/config.json"
WORK_DIR="/home/container/argo-tuic"
BIN_DIR="$WORK_DIR/bin"
LOG_DIR="$WORK_DIR/logs"
KEEPALIVE_PORT="27039"
PID_FILE_KEEPALIVE="$WORK_DIR/keepalive.pid"
PID_FILE_CLOUDFLARED="$WORK_DIR/cloudflared.pid"
TUNNEL_URL_FILE="$WORK_DIR/tunnel.url"
LOG_CLOUDFLARED="$LOG_DIR/cloudflared.log"

# Global variables
CF_DOMAIN=""
CF_TOKEN=""
UUID=""
ARGO_PORT="27039"

# =============================================================================
# Print header
# =============================================================================

print_header() {
    log_info "======================================"
    log_info "Starting Argo Tunnel Setup for Zampto"
    log_info "======================================"
}

print_footer() {
    log_info "======================================"
    log_info "Service Status Summary"
    log_info "======================================"
}

# =============================================================================
# Configuration Loading
# =============================================================================

load_config() {
    log_info "Loading configuration from $CONFIG_FILE..."

    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_warn "Config file not found: $CONFIG_FILE"
        log_info "Using default values"
        return 1
    fi

    log_info "Config file found, parsing..."

    if command -v jq >/dev/null 2>&1; then
        log_debug "Using jq for JSON parsing"
        CF_DOMAIN=$(jq -r '.CF_DOMAIN // .cf_domain // empty' "$CONFIG_FILE" 2>/dev/null)
        CF_TOKEN=$(jq -r '.CF_TOKEN // .cf_token // empty' "$CONFIG_FILE" 2>/dev/null)
        UUID=$(jq -r '.UUID // .uuid // empty' "$CONFIG_FILE" 2>/dev/null)
        ARGO_PORT=$(jq -r '.ARGO_PORT // .argo_port // "27039"' "$CONFIG_FILE" 2>/dev/null)
    else
        log_debug "jq not available, using fallback parser"
        CF_DOMAIN=$(grep -oE '"(CF_DOMAIN|cf_domain)"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" 2>/dev/null | head -1 | sed -E 's/.*"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')
        CF_TOKEN=$(grep -oE '"(CF_TOKEN|cf_token)"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" 2>/dev/null | head -1 | sed -E 's/.*"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')
        UUID=$(grep -oE '"(UUID|uuid)"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" 2>/dev/null | head -1 | sed -E 's/.*"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')
        ARGO_PORT=$(grep -oE '"(ARGO_PORT|argo_port)"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" 2>/dev/null | head -1 | sed -E 's/.*"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')
        if [[ -z "$ARGO_PORT" ]]; then
            ARGO_PORT=$(grep -oE '"(ARGO_PORT|argo_port)"[[:space:]]*:[[:space:]]*[^,}[:space:]]+' "$CONFIG_FILE" 2>/dev/null | head -1 | sed -E 's/.*:[[:space:]]*//' | sed -E 's/[",]*$//')
        fi
    fi

    ARGO_PORT=${ARGO_PORT:-27039}

    if [[ -n "$ARGO_PORT" ]]; then
        KEEPALIVE_PORT=$ARGO_PORT
    fi

    log_info "Configuration loaded:"
    log_info "  CF_DOMAIN: ${CF_DOMAIN:-'(not set)'}"
    log_info "  CF_TOKEN: $(format_secret_value "$CF_TOKEN")"
    log_info "  UUID: ${UUID:-'(not set)'}"
    log_info "  ARGO_PORT: $ARGO_PORT"

    return 0
}

# =============================================================================
# Environment Setup
# =============================================================================

setup_directories() {
    log_info "Setting up working directory: $WORK_DIR"
    
    mkdir -p "$WORK_DIR" "$BIN_DIR" "$LOG_DIR" 2>/dev/null
    
    if [[ ! -d "$WORK_DIR" ]]; then
        log_error "Failed to create work directory: $WORK_DIR"
        return 1
    fi
    
    log_success "Working directory created"
    return 0
}

detect_arch() {
    ARCH=$(uname -m)
    log_info "Detecting system architecture: $ARCH"
    
    case "$ARCH" in
        x86_64|amd64)
            ARCH_CLOUDFLARED="amd64"
            ;;
        aarch64|arm64)
            ARCH_CLOUDFLARED="arm64"
            ;;
        armv7l|armhf)
            ARCH_CLOUDFLARED="arm"
            ;;
        *)
            log_error "Unsupported architecture: $ARCH"
            return 1
            ;;
    esac
    
    log_success "Architecture: $ARCH (cloudflared: $ARCH_CLOUDFLARED)"
    return 0
}

# =============================================================================
# Keepalive Server
# =============================================================================

start_keepalive_server() {
    log_info "====== Starting Keepalive HTTP Server ======"
    log_info "Target: 127.0.0.1:$KEEPALIVE_PORT"
    
    # Create HTML content
    cat > "$WORK_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Zampto Keepalive</title>
    <meta charset="utf-8">
</head>
<body>
    <h1>Zampto Keepalive Server</h1>
    <p>Status: OK</p>
    <p>Timestamp: <span id="time"></span></p>
    <script>
        document.getElementById('time').textContent = new Date().toLocaleString();
    </script>
</body>
</html>
EOF
    
    log_debug "HTML content created at $WORK_DIR/index.html"
    
    # Try Python3
    if command -v python3 >/dev/null 2>&1; then
        log_info "Attempting to start with Python3..."
        
        cd "$WORK_DIR" || {
            log_error "Cannot cd to $WORK_DIR"
            return 1
        }
        
        # Start in background
        python3 -m http.server "$KEEPALIVE_PORT" --bind 127.0.0.1 > "$LOG_DIR/keepalive.log" 2>&1 &
        KEEPALIVE_PID=$!
        
        sleep 2
        
        if kill -0 "$KEEPALIVE_PID" 2>/dev/null; then
            log_success "Keepalive server started (PID: $KEEPALIVE_PID)"
            echo "$KEEPALIVE_PID" > "$PID_FILE_KEEPALIVE"
            
            # Test connectivity
            if curl -s http://127.0.0.1:$KEEPALIVE_PORT/ >/dev/null 2>&1; then
                log_success "Keepalive server is responding to HTTP requests"
            else
                log_warn "Keepalive server started but not responding yet"
            fi
            
            return 0
        else
            log_error "Python3 HTTP server failed to start"
            cat "$LOG_DIR/keepalive.log"
        fi
    fi
    
    # Fallback to netcat
    if command -v nc >/dev/null 2>&1; then
        log_warn "Python3 unavailable, trying netcat fallback"
        
        # Create a simple HTTP server using netcat
        {
            while true; do
                {
                    echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n"
                    cat "$WORK_DIR/index.html"
                } | nc -l -p "$KEEPALIVE_PORT" 2>/dev/null || break
                sleep 0.1
            done
        } > "$LOG_DIR/keepalive.log" 2>&1 &
        
        KEEPALIVE_PID=$!
        sleep 2
        
        if kill -0 "$KEEPALIVE_PID" 2>/dev/null; then
            log_success "Netcat HTTP server started (PID: $KEEPALIVE_PID)"
            echo "$KEEPALIVE_PID" > "$PID_FILE_KEEPALIVE"
            return 0
        else
            log_error "Netcat HTTP server failed"
        fi
    fi
    
    log_error "Cannot start HTTP server (need python3 or nc)"
    return 1
}

# =============================================================================
# Cloudflared Tunnel
# =============================================================================

download_cloudflared() {
    log_info "====== Downloading Cloudflared ======"
    
    CLOUDFLARED_BIN="$BIN_DIR/cloudflared"
    
    if [[ -f "$CLOUDFLARED_BIN" ]]; then
        log_info "Cloudflared binary already exists at $CLOUDFLARED_BIN"
        VERSION=$("$CLOUDFLARED_BIN" --version 2>/dev/null | head -1)
        log_info "Version: $VERSION"
        return 0
    fi
    
    log_info "Fetching latest cloudflared version..."
    LATEST_VERSION=$(curl -s https://api.github.com/repos/cloudflare/cloudflared/releases/latest | grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/' | sed 's/^v//')
    
    if [[ -z "$LATEST_VERSION" ]]; then
        log_warn "Could not determine latest version, using default"
        LATEST_VERSION="2024.1.1"
    fi
    
    log_info "Latest version: $LATEST_VERSION"
    
    DOWNLOAD_URL="https://github.com/cloudflare/cloudflared/releases/download/v${LATEST_VERSION}/cloudflared-linux-${ARCH_CLOUDFLARED}"
    log_info "Download URL: $DOWNLOAD_URL"
    
    # Try wget first
    if command -v wget >/dev/null 2>&1; then
        log_info "Downloading with wget..."
        if wget -O "$CLOUDFLARED_BIN" "$DOWNLOAD_URL" 2>/tmp/wget.log; then
            log_success "Download completed with wget"
            chmod +x "$CLOUDFLARED_BIN"
            log_success "Cloudflared is executable"
            return 0
        else
            log_warn "wget download failed"
            cat /tmp/wget.log
        fi
    fi
    
    # Fallback to curl
    if command -v curl >/dev/null 2>&1; then
        log_info "Downloading with curl..."
        if curl -L -o "$CLOUDFLARED_BIN" "$DOWNLOAD_URL" 2>/tmp/curl.log; then
            log_success "Download completed with curl"
            chmod +x "$CLOUDFLARED_BIN"
            log_success "Cloudflared is executable"
            return 0
        else
            log_warn "curl download failed"
            cat /tmp/curl.log
        fi
    fi
    
    log_error "Failed to download cloudflared"
    return 1
}

start_cloudflared_tunnel() {
    log_info "====== Starting Cloudflared Tunnel ======"
    
    CLOUDFLARED_BIN="$BIN_DIR/cloudflared"
    
    if [[ ! -f "$CLOUDFLARED_BIN" ]]; then
        log_error "Cloudflared binary not found at $CLOUDFLARED_BIN"
        return 1
    fi
    
    # Check if we have CF_DOMAIN and CF_TOKEN for fixed tunnel
    if [[ -n "$CF_DOMAIN" && -n "$CF_TOKEN" ]]; then
        log_info "Starting fixed domain tunnel: $CF_DOMAIN"
        start_fixed_tunnel
    else
        log_info "No fixed domain config, starting temporary tunnel"
        start_temporary_tunnel
    fi
}

start_fixed_tunnel() {
    log_info "Creating fixed tunnel configuration..."
    
    cat > "$WORK_DIR/tunnel.yml" << EOF
tunnel: $CF_DOMAIN
credentials-file: $WORK_DIR/credentials.json

ingress:
  - hostname: $CF_DOMAIN
    service: http://127.0.0.1:$KEEPALIVE_PORT
  - service: http_status:404
EOF
    
    log_debug "Tunnel config created"
    
    # Create credentials file (simplified)
    cat > "$WORK_DIR/credentials.json" << EOF
{
  "AccountTag": "$(echo "$CF_TOKEN" | cut -d: -f1)",
  "TunnelSecret": "$(echo "$CF_TOKEN" | cut -d: -f2-)",
  "TunnelID": "$(echo "$CF_TOKEN" | cut -d: -f3)"
}
EOF
    
    log_debug "Credentials file created"
    
    CLOUDFLARED_BIN="$BIN_DIR/cloudflared"
    
    log_info "Starting cloudflared with tunnel config..."
    "$CLOUDFLARED_BIN" tunnel --config "$WORK_DIR/tunnel.yml" run > "$LOG_CLOUDFLARED" 2>&1 &
    CLOUDFLARED_PID=$!
    
    sleep 3
    
    if kill -0 "$CLOUDFLARED_PID" 2>/dev/null; then
        log_success "Cloudflared tunnel started (PID: $CLOUDFLARED_PID)"
        echo "$CLOUDFLARED_PID" > "$PID_FILE_CLOUDFLARED"
        echo "https://$CF_DOMAIN" > "$TUNNEL_URL_FILE"
        log_success "Tunnel URL: https://$CF_DOMAIN"
        return 0
    else
        log_error "Cloudflared tunnel failed to start"
        log_error "Last log lines:"
        tail -20 "$LOG_CLOUDFLARED"
        return 1
    fi
}

start_temporary_tunnel() {
    log_info "Starting temporary trycloudflare tunnel..."
    
    CLOUDFLARED_BIN="$BIN_DIR/cloudflared"
    
    log_info "Command: $CLOUDFLARED_BIN tunnel --url http://127.0.0.1:$KEEPALIVE_PORT"
    
    "$CLOUDFLARED_BIN" tunnel --url "http://127.0.0.1:$KEEPALIVE_PORT" > "$LOG_CLOUDFLARED" 2>&1 &
    CLOUDFLARED_PID=$!
    
    log_info "Cloudflared PID: $CLOUDFLARED_PID"
    
    sleep 5
    
    if kill -0 "$CLOUDFLARED_PID" 2>/dev/null; then
        log_success "Cloudflared process is running"
        echo "$CLOUDFLARED_PID" > "$PID_FILE_CLOUDFLARED"
        
        # Extract tunnel URL
        TUNNEL_URL=$(grep -o 'https://[a-zA-Z0-9-]*\.trycloudflare\.com' "$LOG_CLOUDFLARED" | head -1)
        
        if [[ -n "$TUNNEL_URL" ]]; then
            log_success "Tunnel URL obtained: $TUNNEL_URL"
            echo "$TUNNEL_URL" > "$TUNNEL_URL_FILE"
        else
            log_warn "Cloudflared started but URL not yet available"
            log_info "Checking cloudflared logs..."
            tail -30 "$LOG_CLOUDFLARED"
        fi
        
        return 0
    else
        log_error "Cloudflared failed to start"
        log_error "Last log lines:"
        tail -20 "$LOG_CLOUDFLARED"
        return 1
    fi
}

# =============================================================================
# Service Status
# =============================================================================

check_service_status() {
    log_info "====== Service Status Check ======"
    
    # Check keepalive
    if [[ -f "$PID_FILE_KEEPALIVE" ]]; then
        KEEPALIVE_PID=$(cat "$PID_FILE_KEEPALIVE")
        if kill -0 "$KEEPALIVE_PID" 2>/dev/null; then
            log_success "Keepalive server is running (PID: $KEEPALIVE_PID)"
        else
            log_error "Keepalive server is NOT running"
        fi
    else
        log_error "Keepalive PID file not found"
    fi
    
    # Check cloudflared
    if [[ -f "$PID_FILE_CLOUDFLARED" ]]; then
        CLOUDFLARED_PID=$(cat "$PID_FILE_CLOUDFLARED")
        if kill -0 "$CLOUDFLARED_PID" 2>/dev/null; then
            log_success "Cloudflared tunnel is running (PID: $CLOUDFLARED_PID)"
        else
            log_error "Cloudflared tunnel is NOT running"
        fi
    else
        log_error "Cloudflared PID file not found"
    fi
    
    # Check tunnel URL
    if [[ -f "$TUNNEL_URL_FILE" ]]; then
        TUNNEL_URL=$(cat "$TUNNEL_URL_FILE")
        log_info "Tunnel URL: $TUNNEL_URL"
    fi
}

print_final_summary() {
    print_footer
    
    log_info "Keepalive Server:"
    if [[ -f "$PID_FILE_KEEPALIVE" ]]; then
        KEEPALIVE_PID=$(cat "$PID_FILE_KEEPALIVE")
        if kill -0 "$KEEPALIVE_PID" 2>/dev/null; then
            log_info "  Status: ✅ Running (PID: $KEEPALIVE_PID)"
        else
            log_info "  Status: ❌ Not Running"
        fi
    fi
    
    log_info ""
    log_info "Cloudflared Tunnel:"
    if [[ -f "$PID_FILE_CLOUDFLARED" ]]; then
        CLOUDFLARED_PID=$(cat "$PID_FILE_CLOUDFLARED")
        if kill -0 "$CLOUDFLARED_PID" 2>/dev/null; then
            log_info "  Status: ✅ Running (PID: $CLOUDFLARED_PID)"
        else
            log_info "  Status: ❌ Not Running"
        fi
    fi
    
    if [[ -f "$TUNNEL_URL_FILE" ]]; then
        TUNNEL_URL=$(cat "$TUNNEL_URL_FILE")
        log_info "  Tunnel URL: $TUNNEL_URL"
    fi
    
    log_info ""
    log_info "Work Directory: $WORK_DIR"
    log_info "Cloudflared Log: $LOG_CLOUDFLARED"
    log_info "======================================"
}

# =============================================================================
# Main
# =============================================================================

main() {
    print_header
    
    # Step 1: Load config
    log_info ""
    load_config
    
    # Step 2: Setup directories
    log_info ""
    setup_directories || exit 1
    
    # Step 3: Detect architecture
    log_info ""
    detect_arch || exit 1
    
    # Step 4: Start keepalive server
    log_info ""
    start_keepalive_server || exit 1
    
    # Step 5: Download cloudflared
    log_info ""
    download_cloudflared || exit 1
    
    # Step 6: Start cloudflared tunnel
    log_info ""
    start_cloudflared_tunnel || exit 1
    
    # Step 7: Check status
    log_info ""
    sleep 3
    check_service_status
    
    # Step 8: Print summary
    log_info ""
    print_final_summary
    
    log_info ""
    log_success "All setup complete! Services should be running."
    log_info "Press Ctrl+C to stop."
    
    # Keep script running and monitor services
    while true; do
        sleep 60
        log_debug "Performing health check..."
        
        # Check if services are still running
        if [[ -f "$PID_FILE_KEEPALIVE" ]]; then
            KEEPALIVE_PID=$(cat "$PID_FILE_KEEPALIVE")
            if ! kill -0 "$KEEPALIVE_PID" 2>/dev/null; then
                log_warn "Keepalive server stopped unexpectedly (PID: $KEEPALIVE_PID)"
            fi
        fi
        
        if [[ -f "$PID_FILE_CLOUDFLARED" ]]; then
            CLOUDFLARED_PID=$(cat "$PID_FILE_CLOUDFLARED")
            if ! kill -0 "$CLOUDFLARED_PID" 2>/dev/null; then
                log_warn "Cloudflared tunnel stopped unexpectedly (PID: $CLOUDFLARED_PID)"
            fi
        fi
    done
}

# =============================================================================
# Entry Point
# =============================================================================

# Set up trap for cleanup
trap 'log_info "Received interrupt, exiting"; exit 0' INT TERM

# Run main function
main "$@"
