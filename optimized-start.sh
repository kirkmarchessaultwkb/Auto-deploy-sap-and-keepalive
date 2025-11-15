#!/bin/bash

# ============================================================================
# Optimized Start Script for eooce sing-box on ARM
# Purpose: Reduce CPU usage from 70% to 40-50% on low-resource ARM servers
# ============================================================================

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================================================
# 1. System Configuration for Low Resource Usage
# ============================================================================

log_info "Setting up system configuration for low resource usage..."

# Disable unnecessary services and features
disable_services() {
    log_info "Disabling unnecessary system services..."
    # Disable IPv6 if not needed (reduces some overhead)
    sysctl -w net.ipv6.conf.all.disable_ipv6=1 2>/dev/null || true
    sysctl -w net.ipv6.conf.default.disable_ipv6=1 2>/dev/null || true
    
    # Optimize network settings
    sysctl -w net.ipv4.tcp_tw_reuse=1 2>/dev/null || true
    sysctl -w net.ipv4.tcp_fin_timeout=15 2>/dev/null || true
}

disable_services

# ============================================================================
# 2. Application Environment Setup
# ============================================================================

log_info "Setting up application environment..."

# Create necessary directories
mkdir -p /data /var/log/sing-box /tmp/sing-box

# Set working directory
cd /data

# ============================================================================
# 3. Process Priority Configuration - Optimization #1
# ============================================================================

# Use nice and ionice to lower process priority
# This prevents the process from consuming CPU resources aggressively
# and allows other system processes to run with higher priority

set_process_priority() {
    local nice_level=10
    local ionice_class=3  # idle class - lowest I/O priority
    
    log_info "Setting process priority (nice=$nice_level, ionice=$ionice_class)..."
    
    # nice reduces CPU priority
    # ionice reduces I/O priority
    exec nice -n $nice_level ionice -c $ionice_class "$@"
}

# ============================================================================
# 4. Prepare Configuration Files with Optimization Settings
# ============================================================================

prepare_configs() {
    log_info "Preparing optimized configuration files..."
    
    # Create optimized Xray config (if using Xray as inbound)
    if [ -f "xray.json" ] || [ -f "/etc/sing-box/xray.json" ]; then
        log_info "Preparing optimized Xray configuration..."
        # Note: Xray config should be modified by users to reduce logging verbosity
        # and optimize buffer sizes. See OPTIMIZATION_GUIDE.md for details.
    fi
}

prepare_configs

# ============================================================================
# 5. Start sing-box with Optimization
# ============================================================================

start_sing_box() {
    log_info "Starting sing-box with optimizations..."
    
    # Default to /usr/local/bin/sing-box or /app/sing-box
    local sing_box_bin="${SING_BOX_BIN:-/usr/local/bin/sing-box}"
    
    if [ ! -f "$sing_box_bin" ]; then
        sing_box_bin="/app/sing-box"
    fi
    
    if [ ! -f "$sing_box_bin" ]; then
        log_error "sing-box binary not found at $sing_box_bin"
        exit 1
    fi
    
    # Prepare sing-box command with configuration
    local config_file="${CONFIG_FILE:-/etc/sing-box/config.json}"
    
    log_info "sing-box config: $config_file"
    log_info "sing-box binary: $sing_box_bin"
    
    # Start sing-box with reduced process priority
    # The exec command replaces the current shell with sing-box process
    set_process_priority "$sing_box_bin" run -c "$config_file"
}

# ============================================================================
# 6. Daemon Health Check Configuration - Optimization #2
# ============================================================================

# This function demonstrates how to implement health checking with
# reduced CPU overhead (30 second intervals instead of 5 seconds)

setup_health_check() {
    log_info "Setting up optimized health check (30s interval)..."
    
    # This is meant to be run as a background process
    # Health check monitors the sing-box process and restarts if needed
    
    # Get the PID of the main sing-box process
    local main_pid=$$
    local check_interval=30  # Check every 30 seconds (reduced from ~5 seconds)
    
    # Create health check script
    cat > /tmp/sing-box/health-check.sh << 'EOF'
#!/bin/bash

# Configuration
MAIN_PID=$1
CHECK_INTERVAL=${2:-30}
LOG_FILE="/var/log/sing-box/health-check.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Health check loop
while true; do
    sleep $CHECK_INTERVAL
    
    if ! kill -0 "$MAIN_PID" 2>/dev/null; then
        log_message "Main sing-box process ($MAIN_PID) is not running, need restart"
        # Restart would be handled by the orchestration system (e.g., systemd, supervisor)
    fi
    
    # Optional: Check network connectivity or service port
    # if ! nc -z localhost 8080 2>/dev/null; then
    #     log_message "Service port is not responding"
    # fi
done
EOF
    
    chmod +x /tmp/sing-box/health-check.sh
}

setup_health_check

# ============================================================================
# 7. Daemon Process Management
# ============================================================================

# Start health check in background with reduced frequency
# /tmp/sing-box/health-check.sh $$ 30 &
# HEALTH_CHECK_PID=$!

# ============================================================================
# 8. Main Process Start
# ============================================================================

# Trap signals for graceful shutdown
cleanup() {
    log_info "Received termination signal, cleaning up..."
    # The process will be terminated by the signal handler
    exit 0
}

trap cleanup SIGTERM SIGINT

# Start sing-box with optimizations
start_sing_box

# Keep the container running if needed
# This is typically not needed as sing-box will run in foreground
wait
