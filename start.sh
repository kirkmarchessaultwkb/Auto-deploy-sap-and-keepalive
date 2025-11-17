#!/bin/bash

# =============================================================================
# Zampto Startup Script (Simplified)
# Description: Load config, start Nezha, and call wispbyte deploy script
# =============================================================================

CONFIG_FILE="/home/container/config.json"

# Simple log function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

# =============================================================================
# Simple JSON Configuration Loading
# =============================================================================

load_config() {
    log "Loading config.json..."
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log "ERROR: Config file not found: $CONFIG_FILE"
        return 1
    fi
    
    # Simple JSON extraction using grep/sed (like wispbyte script)
    NEZHA_SERVER=$(grep -o '"nezha_server"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/' || echo "")
    NEZHA_PORT=$(grep -o '"nezha_port"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/' || echo "5555")
    NEZHA_KEY=$(grep -o '"nezha_key"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/' || echo "")
    
    # Export for other scripts
    export NEZHA_SERVER NEZHA_PORT NEZHA_KEY
    
    log "Config loaded: NEZHA_SERVER=${NEZHA_SERVER:-'not set'}, NEZHA_PORT=${NEZHA_PORT}"
    
    return 0
}

# =============================================================================
# Nezha Agent Management
# =============================================================================

start_nezha_agent() {
    log "Starting Nezha agent..."
    
    # Check if Nezha is configured
    if [[ -z "$NEZHA_KEY" || -z "$NEZHA_SERVER" ]]; then
        log "Nezha disabled (missing NEZHA_KEY or NEZHA_SERVER)"
        return 0
    fi
    
    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64|amd64)
            NEZHA_ARCH="amd64"
            ;;
        aarch64|arm64)
            NEZHA_ARCH="arm64"
            ;;
        armv7l|armhf)
            NEZHA_ARCH="armv7"
            ;;
        *)
            log "ERROR: Unsupported architecture: $ARCH"
            return 1
            ;;
    esac
    
    NEZHA_URL="https://github.com/naiba/nezha/releases/latest/download/nezha-agent-linux_${NEZHA_ARCH}.tar.gz"
    NEZHA_DIR="/tmp/nezha"
    NEZHA_BIN="$NEZHA_DIR/nezha-agent"
    
    # Create directory
    mkdir -p "$NEZHA_DIR"
    
    # Download nezha-agent if not exists
    if [[ ! -f "$NEZHA_BIN" ]]; then
        log "Downloading nezha-agent..."
        if command -v wget >/dev/null 2>&1; then
            wget -q -O "$NEZHA_DIR/nezha-agent.tar.gz" "$NEZHA_URL"
        elif command -v curl >/dev/null 2>&1; then
            curl -s -L -o "$NEZHA_DIR/nezha-agent.tar.gz" "$NEZHA_URL"
        else
            log "ERROR: Neither wget nor curl available"
            return 1
        fi
        
        # Extract and setup
        tar -xzf "$NEZHA_DIR/nezha-agent.tar.gz" -C "$NEZHA_DIR"
        chmod +x "$NEZHA_BIN"
    fi
    
    # Parse server address and port
    SERVER_HOST=$(echo "$NEZHA_SERVER" | cut -d':' -f1)
    SERVER_PORT=$(echo "$NEZHA_SERVER" | cut -d':' -f2)
    if [[ -z "$SERVER_PORT" ]]; then
        SERVER_PORT="$NEZHA_PORT"
    fi
    
    # Start nezha-agent in background
    nohup "$NEZHA_BIN" -s "$SERVER_HOST:$SERVER_PORT" -p "$NEZHA_KEY" >/dev/null 2>&1 &
    NEZHA_PID=$!
    
    # Verify startup
    sleep 2
    if kill -0 "$NEZHA_PID" 2>/dev/null; then
        log "Nezha agent started (PID: $NEZHA_PID)"
        echo "$NEZHA_PID" > /tmp/nezha.pid
    else
        log "ERROR: Failed to start Nezha agent"
        return 1
    fi
    
    return 0
}

# =============================================================================
# Call Wispbyte Deploy Script
# =============================================================================

call_wispbyte_deploy() {
    log "Calling wispbyte-argo-singbox-deploy.sh..."
    
    if [[ -f "/home/container/wispbyte-argo-singbox-deploy.sh" ]]; then
        bash /home/container/wispbyte-argo-singbox-deploy.sh
    else
        log "ERROR: wispbyte-argo-singbox-deploy.sh not found"
        return 1
    fi
    
    return 0
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    log "=== Zampto Startup Script (Simplified) ==="
    
    # 1. Load config.json
    if ! load_config; then
        log "ERROR: Failed to load configuration, exiting..."
        exit 1
    fi
    
    # 2. Start Nezha agent
    start_nezha_agent
    
    # 3. Call wispbyte deploy script
    call_wispbyte_deploy
    
    log "All services started"
    log "=== Startup Script Completed ==="
}

# Execute main function
main "$@"