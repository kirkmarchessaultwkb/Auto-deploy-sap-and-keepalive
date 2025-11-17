#!/bin/bash

# =============================================================================
# Zampto Startup Script (Simplified)
# Description: Load config, start Nezha, and call wispbyte deploy script
# Version: 1.1 - Simplified with full config loading
# =============================================================================

CONFIG_FILE="/home/container/config.json"

# Simple log function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

# =============================================================================
# Configuration Loading (All Parameters)
# =============================================================================

load_config() {
    log "Loading config.json..."
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log "ERROR: Config file not found: $CONFIG_FILE"
        return 1
    fi
    
    # Load ALL parameters from config.json
    CF_DOMAIN=$(grep -o '"cf_domain":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
    CF_TOKEN=$(grep -o '"cf_token":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
    UUID=$(grep -o '"uuid":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
    PORT=$(grep -o '"port":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
    NEZHA_SERVER=$(grep -o '"nezha_server":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
    NEZHA_PORT=$(grep -o '"nezha_port":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
    NEZHA_KEY=$(grep -o '"nezha_key":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
    
    # Set defaults
    PORT=${PORT:-27039}
    NEZHA_PORT=${NEZHA_PORT:-5555}
    
    # Export for wispbyte script
    export CF_DOMAIN CF_TOKEN UUID PORT NEZHA_SERVER NEZHA_PORT NEZHA_KEY
    
    log "Config loaded:"
    log "  - Domain: ${CF_DOMAIN:-'not set'}"
    log "  - UUID: ${UUID:-'not set'}"
    log "  - Port: $PORT"
    log "  - Nezha: ${NEZHA_SERVER:-'not set'}"
    
    return 0
}

# =============================================================================
# Nezha Agent Startup
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
        x86_64|amd64) NEZHA_ARCH="amd64" ;;
        aarch64|arm64) NEZHA_ARCH="arm64" ;;
        armv7l|armhf) NEZHA_ARCH="armv7" ;;
        *) NEZHA_ARCH="amd64" ;;
    esac
    
    NEZHA_URL="https://github.com/naiba/nezha/releases/latest/download/nezha-agent-linux_${NEZHA_ARCH}.tar.gz"
    NEZHA_DIR="/tmp/nezha"
    NEZHA_BIN="$NEZHA_DIR/nezha-agent"
    
    # Download if not exists
    if [[ ! -f "$NEZHA_BIN" ]]; then
        log "Downloading nezha-agent..."
        mkdir -p "$NEZHA_DIR"
        curl -s -L -o "$NEZHA_DIR/nezha-agent.tar.gz" "$NEZHA_URL"
        tar -xzf "$NEZHA_DIR/nezha-agent.tar.gz" -C "$NEZHA_DIR"
        chmod +x "$NEZHA_BIN"
    fi
    
    # Start nezha-agent
    nohup "$NEZHA_BIN" -s "$NEZHA_SERVER" -p "$NEZHA_KEY" >/dev/null 2>&1 &
    NEZHA_PID=$!
    
    sleep 1
    if kill -0 "$NEZHA_PID" 2>/dev/null; then
        log "Nezha agent started (PID: $NEZHA_PID)"
    else
        log "WARNING: Nezha agent may have failed to start"
    fi
    
    return 0
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    log "=== Zampto Startup Script ==="
    
    # 1. Load config.json (all parameters)
    if ! load_config; then
        log "ERROR: Failed to load configuration, exiting..."
        exit 1
    fi
    
    # 2. Start Nezha monitoring
    start_nezha_agent
    
    # 3. Call wispbyte deploy script
    log "Calling wispbyte-argo-singbox-deploy.sh..."
    if [[ -f "/home/container/wispbyte-argo-singbox-deploy.sh" ]]; then
        bash /home/container/wispbyte-argo-singbox-deploy.sh
    else
        log "ERROR: wispbyte-argo-singbox-deploy.sh not found"
        exit 1
    fi
    
    log "=== Startup Completed ==="
}

# Execute main function
main "$@"
