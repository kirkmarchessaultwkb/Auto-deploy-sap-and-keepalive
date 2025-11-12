#!/bin/bash

# Nezha Agent Startup Script
# This script downloads and starts the Nezha monitoring agent with architecture detection
# and protocol version auto-detection

set -e

# Configuration
NEZHA_SERVER="${NEZHA_SERVER:-}"
NEZHA_PORT="${NEZHA_PORT:-}"
NEZHA_KEY="${NEZHA_KEY:-}"
BIN_DIR="/app/bin"
LOG_DIR="/app/logs"
NEZHA_BIN="$BIN_DIR/nezha"
NEZHA_LOG="$LOG_DIR/nezha.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$NEZHA_LOG"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$NEZHA_LOG"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$NEZHA_LOG"
}

# Check if Nezha configuration is present
check_nezha_config() {
    if [[ -z "$NEZHA_SERVER" || -z "$NEZHA_KEY" ]]; then
        log "Nezha configuration not found (NEZHA_SERVER or NEZHA_KEY not set), skipping Nezha agent startup"
        return 1
    fi
    return 0
}

# Create necessary directories
create_directories() {
    mkdir -p "$BIN_DIR" "$LOG_DIR"
}

# Detect system architecture
detect_architecture() {
    ARCH=$(uname -m)
    case $ARCH in
        x86_64|amd64)
            ARCH_TYPE="amd64"
            ;;
        aarch64|arm64)
            ARCH_TYPE="arm64"
            ;;
        armv7l|arm)
            ARCH_TYPE="armv7"
            ;;
        *)
            error "Unsupported architecture: $ARCH"
            return 1
            ;;
    esac
    log "Detected architecture: $ARCH_TYPE"
    echo "$ARCH_TYPE"
}

# Get latest Nezha release version
get_latest_version() {
    local api_url="https://api.github.com/repos/naiba/nezha/releases/latest"
    local version=$(curl -s "$api_url" | grep '"tag_name":' | sed -E 's/.*"tag_name": ?"v?([^"]+).*/\1/')
    if [[ -z "$version" ]]; then
        error "Failed to fetch latest Nezha version"
        return 1
    fi
    echo "$version"
}

# Download Nezha agent binary
download_nezha() {
    local arch_type="$1"
    local version="$2"
    local download_url="https://github.com/naiba/nezha/releases/download/v${version}/nezha-agent-linux-${arch_type}"
    
    log "Downloading Nezha agent v${version} for ${arch_type}..."
    
    # Check if binary already exists and is the correct version
    if [[ -f "$NEZHA_BIN" ]]; then
        local current_version=$("$NEZHA_BIN" -version 2>/dev/null | grep -oP 'v\K[\d.]+' || echo "unknown")
        if [[ "$current_version" == "$version" ]]; then
            log "Nezha agent v${version} already exists, skipping download"
            return 0
        fi
        log "Existing Nezha agent version ${current_version} differs from latest ${version}, updating..."
    fi
    
    # Download with retry logic
    local max_attempts=3
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -L -o "$NEZHA_BIN" "$download_url"; then
            chmod +x "$NEZHA_BIN"
            log "Successfully downloaded Nezha agent to $NEZHA_BIN"
            return 0
        else
            warn "Download attempt $attempt failed, retrying..."
            ((attempt++))
            sleep 2
        fi
    done
    
    error "Failed to download Nezha agent after $max_attempts attempts"
    return 1
}

# Detect Nezha protocol version
detect_protocol_version() {
    local server="$NEZHA_SERVER"
    local port="$NEZHA_PORT"
    
    # If NEZHA_PORT is explicitly set, assume v0 (legacy)
    if [[ -n "$port" ]]; then
        log "NEZHA_PORT is set, using legacy v0 protocol"
        echo "v0"
        return
    fi
    
    # If server already contains a port, assume v1
    if [[ "$server" == *":"* ]]; then
        log "NEZHA_SERVER contains port, using v1 protocol"
        echo "v1"
        return
    fi
    
    # If server has no port and NEZHA_PORT is not set, assume v0 with default port
    log "NEZHA_SERVER has no port and NEZHA_PORT not set, using legacy v0 protocol with default port"
    echo "v0"
}

# Build Nezha agent command based on protocol version
build_nezha_command() {
    local protocol_version="$1"
    local server="$NEZHA_SERVER"
    local port="$NEZHA_PORT"
    local key="$NEZHA_KEY"
    
    case "$protocol_version" in
        "v0")
            # Legacy v0 protocol: -s host:port -p key
            local host_port="$server"
            if [[ -n "$port" ]]; then
                host_port="${server}:${port}"
            else
                host_port="${server}:5555"  # Default port for v0
            fi
            
            # Check if TLS should be enabled (port 443 or 8443)
            if [[ "$port" == "443" || "$port" == "8443" ]]; then
                echo "$NEZHA_BIN -s $host_port -p $key --tls"
            else
                echo "$NEZHA_BIN -s $host_port -p $key"
            fi
            ;;
        "v1")
            # v1 protocol: service --report
            local cmd="$NEZHA_BIN service --report"
            
            # Add server and key
            cmd="$cmd -s $server -p $key"
            
            # Enable TLS for common TLS ports or if not specified
            if [[ "$server" == *":443" || "$server" == *":8443" ]]; then
                cmd="$cmd --tls"
            fi
            
            echo "$cmd"
            ;;
        *)
            error "Unknown protocol version: $protocol_version"
            return 1
            ;;
    esac
}

# Start Nezha agent with watchdog
start_nezha_agent() {
    local protocol_version=$(detect_protocol_version)
    local nezha_cmd=$(build_nezha_command "$protocol_version")
    
    log "Starting Nezha agent with command: $nezha_cmd"
    
    # Create status file for external monitoring
    echo "{
  \"status\": \"starting\",
  \"protocol_version\": \"$protocol_version\",
  \"server\": \"$NEZHA_SERVER\",
  \"port\": \"$NEZHA_PORT\",
  \"architecture\": \"$(detect_architecture)\",
  \"pid\": null,
  \"start_time\": \"$(date -Iseconds)\",
  \"last_restart\": \"$(date -Iseconds)\"
}" > "$LOG_DIR/nezha_status.json"
    
    # Start with nice/ionice for resource management
    nohup bash -c "
        while true; do
            log 'Starting Nezha agent ($protocol_version)...'
            
            # Update status to starting
            echo \"{
  \"status\": \"starting\",
  \"protocol_version\": \"$protocol_version\",
  \"server\": \"$NEZHA_SERVER\",
  \"port\": \"$NEZHA_PORT\",
  \"architecture\": \"$(detect_architecture)\",
  \"pid\": \$,
  \"start_time\": \"$(date -Iseconds)\",
  \"last_restart\": \"$(date -Iseconds)\"
}\" > '$LOG_DIR/nezha_status.json'
            
            if $nezha_cmd 2>&1 | tee -a '$NEZHA_LOG'; then
                warn 'Nezha agent exited normally, restarting in 30 seconds...'
                echo '{
  \"status\": \"restarting\",
  \"protocol_version\": \"$protocol_version\",
  \"server\": \"$NEZHA_SERVER\",
  \"port\": \"$NEZHA_PORT\",
  \"architecture\": \"$(detect_architecture)\",
  \"pid\": null,
  \"start_time\": \"$(date -Iseconds)\",
  \"last_restart\": \"$(date -Iseconds)\",
  \"exit_reason\": \"normal\"
}' > '$LOG_DIR/nezha_status.json'
            else
                error 'Nezha agent crashed, restarting in 30 seconds...'
                echo '{
  \"status\": \"crashed\",
  \"protocol_version\": \"$protocol_version\",
  \"server\": \"$NEZHA_SERVER\",
  \"port\": \"$NEZHA_PORT\",
  \"architecture\": \"$(detect_architecture)\",
  \"pid\": null,
  \"start_time\": \"$(date -Iseconds)\",
  \"last_restart\": \"$(date -Iseconds)\",
  \"exit_reason\": \"crashed\"
}' > '$LOG_DIR/nezha_status.json'
            fi
            sleep 30
        done
   " > /dev/null 2>&1 &
    
    local nezha_pid=$!
    echo $nezha_pid > "$LOG_DIR/nezha.pid"
    
    # Update status with PID
    echo "{
  \"status\": \"running\",
  \"protocol_version\": \"$protocol_version\",
  \"server\": \"$NEZHA_SERVER\",
  \"port\": \"$NEZHA_PORT\",
  \"architecture\": \"$(detect_architecture)\",
  \"pid\": $nezha_pid,
  \"start_time\": \"$(date -Iseconds)\",
  \"last_restart\": \"$(date -Iseconds)\"
}" > "$LOG_DIR/nezha_status.json"
    
    log "Nezha agent started with PID: $nezha_pid"
    
    # Export status for potential external consumption
    export NEZHA_STATUS="running"
    export NEZHA_PROTOCOL_VERSION="$protocol_version"
    export NEZHA_PID="$nezha_pid"
}

# Cleanup function for graceful shutdown
cleanup_nezha_agent() {
    log "Cleaning up Nezha agent..."
    
    if [[ -f "$LOG_DIR/nezha.pid" ]]; then
        local pid=$(cat "$LOG_DIR/nezha.pid")
        if kill -0 "$pid" 2>/dev/null; then
            log "Stopping Nezha agent PID: $pid"
            kill -TERM "$pid" 2>/dev/null
            sleep 5
            if kill -0 "$pid" 2>/dev/null; then
                warn "Nezha agent did not stop gracefully, forcing..."
                kill -KILL "$pid" 2>/dev/null
            fi
        fi
        rm -f "$LOG_DIR/nezha.pid"
    fi
    
    # Update status to stopped
    echo "{
  \"status\": \"stopped\",
  \"protocol_version\": \"$protocol_version\",
  \"server\": \"$NEZHA_SERVER\",
  \"port\": \"$NEZHA_PORT\",
  \"architecture\": \"$(detect_architecture)\",
  \"pid\": null,
  \"start_time\": \"$(date -Iseconds)\",
  \"last_restart\": \"$(date -Iseconds)\",
  \"exit_reason\": \"shutdown\"
}" > "$LOG_DIR/nezha_status.json"
    
    log "Nezha agent cleanup completed"
}

# Main function
main() {
    # Set up signal handlers for graceful shutdown
    trap cleanup_nezha_agent EXIT TERM INT
    
    # Check if Nezha should be started
    if ! check_nezha_config; then
        exit 0
    fi
    
    log "Initializing Nezha agent setup..."
    
    # Create directories
    create_directories
    
    # Detect architecture
    local arch_type=$(detect_architecture)
    if [[ $? -ne 0 ]]; then
        exit 1
    fi
    
    # Get latest version
    local version=$(get_latest_version)
    if [[ $? -ne 0 ]]; then
        exit 1
    fi
    
    log "Latest Nezha version: $version"
    
    # Download Nezha agent
    if ! download_nezha "$arch_type" "$version"; then
        exit 1
    fi
    
    # Start Nezha agent with watchdog
    start_nezha_agent
    
    log "Nezha agent setup completed successfully"
    
    # Keep the script running to handle signals
    wait
}

# Execute main function
main "$@"