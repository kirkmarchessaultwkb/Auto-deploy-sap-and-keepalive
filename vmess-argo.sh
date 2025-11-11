#!/bin/bash

# vmess-argo.sh - Improved Argo tunnel configuration with proper backend
# Compatible with wispbyte.com container environment
# One-command deployment: curl -Ls ... | bash

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration variables
UUID="${UUID:-$(uuidgen)}"
ARGO_PORT="${ARGO_PORT:-8001}"
XRAY_PORT="${XRAY_PORT:-10000}"
SUB_PATH="${SUB_PATH:-sub}"
CFIP="${CFIP:-cf.877774.xyz}"
CFPORT="${CFPORT:-443}"

# Nezha monitoring (optional)
NEZHA_SERVER="${NEZHA_SERVER:-}"
NEZHA_PORT="${NEZHA_PORT:-}"
NEZHA_KEY="${NEZHA_KEY:-}"

# Telegram notification (optional)
CHAT_ID="${CHAT_ID:-}"
BOT_TOKEN="${BOT_TOKEN:-}"

# Install required packages
install_packages() {
    log_info "Installing required packages..."
    
    # Detect package manager
    if command -v apt >/dev/null 2>&1; then
        apt-get update -qq
        apt-get install -y -qq curl wget unzip jq x11-utils
    elif command -v apk >/dev/null 2>&1; then
        apk update -qq
        apk add -qq curl wget unzip jq
    elif command -v yum >/dev/null 2>&1; then
        yum install -y -q curl wget unzip jq
    else
        log_error "Unsupported package manager"
        exit 1
    fi
}

# Download and install Cloudflared
install_cloudflared() {
    log_info "Installing Cloudflared..."
    
    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        armv7l) ARCH="arm" ;;
        *) log_error "Unsupported architecture: $ARCH"; exit 1 ;;
    esac
    
    # Get latest Cloudflared version
    CLOUDFLARED_VERSION=$(curl -s https://api.github.com/repos/cloudflare/cloudflared/releases/latest | grep -o '"tag_name": "[^"]*' | cut -d'"' -f2)
    
    # Download Cloudflared
    CLOUDFLARED_URL="https://github.com/cloudflare/cloudflared/releases/download/${CLOUDFLARED_VERSION}/cloudflared-linux-${ARCH}"
    wget -O /usr/local/bin/cloudflared "$CLOUDFLARED_URL"
    chmod +x /usr/local/bin/cloudflared
    
    log_success "Cloudflared installed successfully"
}

# Download and install Xray
install_xray() {
    log_info "Installing Xray..."
    
    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="64" ;;
        aarch64|arm64) ARCH="arm64-v8a" ;;
        armv7l) ARCH="arm32-v7a" ;;
        *) log_error "Unsupported architecture: $ARCH"; exit 1 ;;
    esac
    
    # Get latest Xray version
    XRAY_VERSION=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep -o '"tag_name": "[^"]*' | cut -d'"' -f2)
    
    # Download Xray
    XRAY_URL="https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-${ARCH}.zip"
    wget -O /tmp/xray.zip "$XRAY_URL"
    unzip -q /tmp/xray.zip -d /tmp/
    mv /tmp/xray /usr/local/bin/
    chmod +x /usr/local/bin/xray
    
    # Clean up
    rm -f /tmp/xray.zip /tmp/LICENSE /tmp/README.md
    
    log_success "Xray installed successfully"
}

# Create Cloudflared configuration
create_cloudflared_config() {
    log_info "Creating Cloudflared configuration..."
    
    mkdir -p /etc/cloudflared
    
    # Create config file with proper ingress rules
    cat > /etc/cloudflared/config.yml << EOF
tunnel: ${ARGO_AUTH:-auto}
credentials-file: /etc/cloudflared/credentials.json

ingress:
  # Forward all HTTP traffic to Xray backend
  - hostname: ${ARGO_DOMAIN:-*}
    service: http://localhost:${XRAY_PORT}
    originRequest:
      noTLSVerify: true
      
  # Health check endpoint
  - hostname: ${ARGO_DOMAIN:-*}
    path: /health
    service: http_status:200
    
  # Default rule - block everything else
  - service: http_status:404

warp-routing:
  enabled: false

loglevel: info
EOF

    # Create credentials file if using fixed tunnel
    if [ -n "$ARGO_AUTH" ] && [ -n "$ARGO_DOMAIN" ]; then
        # Parse ARGO_AUTH - it could be a token or JSON
        if echo "$ARGO_AUTH" | grep -q '^{"'; then
            # JSON format
            echo "$ARGO_AUTH" > /etc/cloudflared/credentials.json
        else
            # Token format - create JSON structure
            cat > /etc/cloudflared/credentials.json << EOF
{
    "AccountTag": "$(echo "$ARGO_AUTH" | cut -d'_' -f1)",
    "TunnelSecret": "$(echo "$ARGO_AUTH" | cut -d'_' -f2)",
    "TunnelID": "$(echo "$ARGO_AUTH" | cut -d'_' -f3)"
}
EOF
        fi
    fi
    
    log_success "Cloudflared configuration created"
}

# Create Xray configuration
create_xray_config() {
    log_info "Creating Xray configuration..."
    
    mkdir -p /etc/xray
    
    cat > /etc/xray/config.json << EOF
{
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": ${XRAY_PORT},
            "protocol": "vmess",
            "settings": {
                "clients": [
                    {
                        "id": "${UUID}",
                        "level": 1,
                        "alterId": 0
                    }
                ]
            },
            "streamSettings": {
                "network": "ws",
                "wsSettings": {
                    "path": "/vmess"
                }
            }
        },
        {
            "port": ${XRAY_PORT},
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "${UUID}",
                        "level": 1,
                        "flow": "xtls-rprx-vision"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws",
                "wsSettings": {
                    "path": "/vless"
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "settings": {}
        }
    ],
    "routing": {
        "rules": [
            {
                "type": "field",
                "ip": ["geoip:private"],
                "outboundTag": "block"
            }
        ]
    }
}
EOF
    
    log_success "Xray configuration created"
}

# Create health check endpoint
create_health_check() {
    log_info "Creating health check endpoint..."
    
    cat > /usr/local/bin/health-check.sh << 'EOF'
#!/bin/bash
# Health check script for Xray and Cloudflared

XRAY_PORT=${XRAY_PORT:-10000}
ARGO_PORT=${ARGO_PORT:-8001}

# Check Xray
if curl -s "http://localhost:${XRAY_PORT}" >/dev/null 2>&1; then
    echo "Xray: OK"
else
    echo "Xray: FAILED"
    exit 1
fi

# Check Cloudflared (if running)
if pgrep -f "cloudflared" >/dev/null; then
    echo "Cloudflared: OK"
else
    echo "Cloudflared: FAILED"
    exit 1
fi

echo "All services: OK"
EOF
    
    chmod +x /usr/local/bin/health-check.sh
}

# Create service management scripts
create_service_scripts() {
    log_info "Creating service management scripts..."
    
    # Start script
    cat > /usr/local/bin/start-services.sh << 'EOF'
#!/bin/bash
# Start all services

echo "Starting Xray..."
nohup xray -config /etc/xray/config.json >/var/log/xray.log 2>&1 &
XRAY_PID=$!
echo $XRAY_PID > /var/run/xray.pid

sleep 2

echo "Starting Cloudflared..."
if [ -n "$ARGO_AUTH" ] && [ -n "$ARGO_DOMAIN" ]; then
    # Fixed tunnel
    nohup cloudflared tunnel --config /etc/cloudflared/config.yml run >/var/log/cloudflared.log 2>&1 &
else
    # Temporary tunnel
    nohup cloudflared tunnel --url http://localhost:10000 --logfile /var/log/cloudflared.log >/dev/null 2>&1 &
fi
CLOUDFLARED_PID=$!
echo $CLOUDFLARED_PID > /var/run/cloudflared.pid

echo "Services started successfully"
echo "Xray PID: $XRAY_PID"
echo "Cloudflared PID: $CLOUDFLARED_PID"
EOF
    
    # Stop script
    cat > /usr/local/bin/stop-services.sh << 'EOF'
#!/bin/bash
# Stop all services

if [ -f /var/run/xray.pid ]; then
    kill $(cat /var/run/xray.pid) 2>/dev/null || true
    rm -f /var/run/xray.pid
fi

if [ -f /var/run/cloudflared.pid ]; then
    kill $(cat /var/run/cloudflared.pid) 2>/dev/null || true
    rm -f /var/run/cloudflared.pid
fi

pkill -f "xray" 2>/dev/null || true
pkill -f "cloudflared" 2>/dev/null || true

echo "All services stopped"
EOF
    
    # Restart script
    cat > /usr/local/bin/restart-services.sh << 'EOF'
#!/bin/bash
# Restart all services

/usr/local/bin/stop-services.sh
sleep 2
/usr/local/bin/start-services.sh
EOF
    
    chmod +x /usr/local/bin/start-services.sh
    chmod +x /usr/local/bin/stop-services.sh
    chmod +x /usr/local/bin/restart-services.sh
}

# Create guardian daemon for auto-healing
create_guardian_daemon() {
    log_info "Creating guardian daemon for auto-healing..."
    
    cat > /usr/local/bin/guardian.sh << 'EOF'
#!/bin/bash
# Guardian daemon for auto-healing services

CHECK_INTERVAL=30
LOG_FILE="/var/log/guardian.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

check_and_restart_service() {
    local service_name="$1"
    local process_pattern="$2"
    local start_command="$3"
    
    if ! pgrep -f "$process_pattern" >/dev/null; then
        log_message "$service_name is down, restarting..."
        $start_command
        sleep 5
        
        if pgrep -f "$process_pattern" >/dev/null; then
            log_message "$service_name restarted successfully"
        else
            log_message "Failed to restart $service_name"
        fi
    fi
}

# Main guardian loop
while true; do
    check_and_restart_service "Xray" "xray -config" "/usr/local/bin/start-services.sh"
    check_and_restart_service "Cloudflared" "cloudflared" "/usr/local/bin/start-services.sh"
    
    sleep $CHECK_INTERVAL
done
EOF
    
    chmod +x /usr/local/bin/guardian.sh
}

# Create subscription service
create_subscription_service() {
    log_info "Creating subscription service..."
    
    cat > /usr/local/bin/subscription-server.py << 'EOF'
#!/usr/bin/env python3
import http.server
import socketserver
import json
import urllib.parse
import os

class SubscriptionHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith('/' + os.getenv('SUB_PATH', 'sub')):
            self.send_response(200)
            self.send_header('Content-type', 'text/plain; charset=utf-8')
            self.end_headers()
            
            # Get configuration from environment
            uuid = os.getenv('UUID')
            argo_domain = os.getenv('ARGO_DOMAIN')
            cfip = os.getenv('CFIP', 'cf.877774.xyz')
            cfport = os.getenv('CFPORT', '443')
            argo_port = os.getenv('ARGO_PORT', '8001')
            
            # Generate VMess configuration
            vmess_config = {
                "v": "2",
                "ps": f"Argo-Tunnel-{argo_domain or 'temp'}",
                "add": cfip,
                "port": cfport,
                "id": uuid,
                "aid": "0",
                "scy": "auto",
                "net": "ws",
                "type": "none",
                "host": argo_domain or "temp.argotunnel.com",
                "path": f"/vmess?argotunnel={argo_port}",
                "tls": "tls",
                "alpn": "h2,http/1.1",
                "fp": "randomized"
            }
            
            # Generate VLESS configuration
            vless_config = {
                "v": "2",
                "ps": f"Argo-Tunnel-VLESS-{argo_domain or 'temp'}",
                "add": cfip,
                "port": cfport,
                "id": uuid,
                "aid": "0",
                "scy": "auto",
                "net": "ws",
                "type": "none",
                "host": argo_domain or "temp.argotunnel.com",
                "path": f"/vless?argotunnel={argo_port}",
                "tls": "tls",
                "alpn": "h2,http/1.1",
                "fp": "randomized"
            }
            
            # Create subscription
            subscription = f"vmess://{urllib.parse.quote(json.dumps(vmess_config))}\n"
            subscription += f"vless://{uuid}@{cfip}:{cfport}?encryption=none&security=tls&type=ws&host={argo_domain or 'temp.argotunnel.com'}&path=%2Fvless%3Fargotunnel%3D{argo_port}#{urllib.parse.quote(f'Argo-Tunnel-VLESS-{argo_domain or 'temp'}')}\n"
            
            self.wfile.write(subscription.encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()

if __name__ == "__main__":
    PORT = 8080
    with socketserver.TCPServer(("", PORT), SubscriptionHandler) as httpd:
        print(f"Subscription server running on port {PORT}")
        httpd.serve_forever()
EOF
    
    chmod +x /usr/local/bin/subscription-server.py
}

# Create startup script
create_startup_script() {
    log_info "Creating startup script..."
    
    cat > /usr/local/bin/startup.sh << 'EOF'
#!/bin/bash
# Main startup script

echo "=== Starting VMess Argo Tunnel Service ==="

# Create log directories
mkdir -p /var/log

# Start services
/usr/local/bin/start-services.sh

# Start subscription server
python3 /usr/local/bin/subscription-server.py >/var/log/subscription.log 2>&1 &
SUBSCRIPTION_PID=$!
echo $SUBSCRIPTION_PID > /var/run/subscription.pid

# Start guardian daemon
/usr/local/bin/guardian.sh >/var/log/guardian.log 2>&1 &
GUARDIAN_PID=$!
echo $GUARDIAN_PID > /var/run/guardian.pid

echo "=== All services started ==="
echo "Xray running on port ${XRAY_PORT:-10000}"
echo "Subscription server running on port 8080"
echo "Guardian daemon started for auto-healing"

# Display connection information
echo ""
echo "=== Connection Information ==="
echo "UUID: ${UUID}"
echo "Subscription: http://localhost:8080/${SUB_PATH:-sub}"

if [ -n "$ARGO_DOMAIN" ]; then
    echo "Argo Domain: $ARGO_DOMAIN"
    echo "VMess Link: vmess://$(echo '{"v":"2","ps":"Argo-Tunnel","add":"'$CFIP'","port":"'$CFPORT'","id":"'$UUID'","aid":"0","scy":"auto","net":"ws","type":"none","host":"'$ARGO_DOMAIN'","path":"/vmess?argotunnel='$ARGO_PORT'","tls":"tls"}' | base64 -w 0)"
else
    echo "Using temporary Argo tunnel"
    echo "Check Cloudflared log for tunnel URL"
fi

echo ""
echo "=== Service Status ==="
/usr/local/bin/health-check.sh

# Keep container running
tail -f /dev/null
EOF
    
    chmod +x /usr/local/bin/startup.sh
}

# Setup cron job for auto-restart
setup_cron() {
    log_info "Setting up cron job for auto-restart..."
    
    # Create cron job
    (crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/health-check.sh || /usr/local/bin/restart-services.sh") | crontab -
    
    log_success "Cron job added for health checks"
}

# Display final information
display_info() {
    log_success "VMess Argo Tunnel setup completed!"
    echo ""
    echo "=== Configuration Summary ==="
    echo "UUID: $UUID"
    echo "Xray Port: $XRAY_PORT"
    echo "Argo Port: $ARGO_PORT"
    echo "Subscription Path: /$SUB_PATH"
    echo "CF IP: $CFIP:$CFPORT"
    
    if [ -n "$ARGO_DOMAIN" ]; then
        echo "Argo Domain: $ARGO_DOMAIN"
    fi
    
    if [ -n "$NEZHA_SERVER" ]; then
        echo "Nezha Server: $NEZHA_SERVER"
    fi
    
    echo ""
    echo "=== Usage ==="
    echo "Start services: /usr/local/bin/start-services.sh"
    echo "Stop services: /usr/local/bin/stop-services.sh"
    echo "Restart services: /usr/local/bin/restart-services.sh"
    echo "Health check: /usr/local/bin/health-check.sh"
    echo "Subscription: http://localhost:8080/$SUB_PATH"
    echo ""
    echo "=== Auto-healing ==="
    echo "Guardian daemon is running and will automatically"
    echo "restart any crashed services every 30 seconds"
    echo ""
    echo "=== Start the service ==="
    echo "Run: /usr/local/bin/startup.sh"
}

# Main installation function
main() {
    log_info "Starting VMess Argo Tunnel installation..."
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run as root"
        exit 1
    fi
    
    # Install components
    install_packages
    install_cloudflared
    install_xray
    
    # Create configurations
    create_cloudflared_config
    create_xray_config
    create_health_check
    create_service_scripts
    create_guardian_daemon
    create_subscription_service
    create_startup_script
    
    # Setup monitoring
    setup_cron
    
    # Display information
    display_info
}

# Run main function
main "$@"