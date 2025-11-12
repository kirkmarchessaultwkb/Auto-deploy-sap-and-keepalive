#!/bin/bash

# ===========================================
# Vmess-Argo + Nezha + Telegram Integration
# For sin-box framework (zampto server)
# Node.js 14+ runtime, 2GB RAM, 8GB disk
# ===========================================

# Color output functions
red() { echo -e "\033[31m\033[01m[ERROR] $1\033[0m"; }
green() { echo -e "\033[32m\033[01m[INFO] $1\033[0m"; }
yellow() { echo -e "\033[33m\033[01m[WARNING] $1\033[0m"; }
blue() { echo -e "\033[36m\033[01m[INFO] $1\033[0m"; }

# Environment variables with defaults
UUID="${UUID:-de04add9-5c68-8bab-950c-08cd5320df18}"
ARGO_DOMAIN="${ARGO_DOMAIN:-}"
ARGO_AUTH="${ARGO_AUTH:-}"
ARGO_PORT="${ARGO_PORT:-8001}"
NEZHA_SERVER="${NEZHA_SERVER:-}"
NEZHA_PORT="${NEZHA_PORT:-}"
NEZHA_KEY="${NEZHA_KEY:-}"
CFIP="${CFIP:-cf.877774.xyz}"
CFPORT="${CFPORT:-443}"
CHAT_ID="${CHAT_ID:-}"
BOT_TOKEN="${BOT_TOKEN:-}"
UPLOAD_URL="${UPLOAD_URL:-}"
DISABLE_ARGO="${DISABLE_ARGO:-}"
SUB_PATH="${SUB_PATH:-sub}"
NAME="${NAME:-SAP}"

# Paths
WORKDIR="${HOME}/.npm"
NEZHA_AGENT="${WORKDIR}/nezha-agent"
XRAY_BIN="${WORKDIR}/xray"
ARGO_BIN="${WORKDIR}/cloudflared"
XRAY_CONFIG="${WORKDIR}/config.json"
SUB_FILE="${WORKDIR}/sub.txt"
LOG_DIR="${WORKDIR}/logs"
PID_DIR="${WORKDIR}/pids"

# Create necessary directories
mkdir -p "${WORKDIR}" "${LOG_DIR}" "${PID_DIR}"

# ===========================================
# Telegram Notification Functions
# ===========================================

send_telegram() {
    local message="$1"
    if [ -z "${CHAT_ID}" ]; then
        return 0
    fi
    
    # Try custom bot first
    if [ -n "${BOT_TOKEN}" ]; then
        curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
            -d "chat_id=${CHAT_ID}" \
            -d "text=${message}" \
            -d "parse_mode=HTML" >/dev/null 2>&1
    else
        # Use public bot (pushplus or similar service)
        curl -s -X POST "https://api.day.app/${CHAT_ID}/${message}" >/dev/null 2>&1
    fi
}

# ===========================================
# Download Functions
# ===========================================

download_and_extract() {
    local url="$1"
    local output="$2"
    local temp_file="${output}.tmp"
    
    green "Downloading from: ${url}"
    if curl -sL "${url}" -o "${temp_file}"; then
        if [ "${url##*.}" = "gz" ] || [[ "${url}" == *".tar.gz"* ]]; then
            tar -xzf "${temp_file}" -C "${WORKDIR}" 2>/dev/null || gunzip -c "${temp_file}" > "${output}"
        else
            mv "${temp_file}" "${output}"
        fi
        chmod +x "${output}" 2>/dev/null
        rm -f "${temp_file}"
        return 0
    else
        red "Download failed: ${url}"
        rm -f "${temp_file}"
        return 1
    fi
}

# ===========================================
# Install Xray
# ===========================================

install_xray() {
    if [ -f "${XRAY_BIN}" ] && [ -x "${XRAY_BIN}" ]; then
        green "Xray already installed"
        return 0
    fi
    
    green "Installing Xray..."
    local arch=$(uname -m)
    local download_url=""
    
    case "${arch}" in
        x86_64|amd64)
            download_url="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip"
            ;;
        aarch64|arm64)
            download_url="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-arm64-v8a.zip"
            ;;
        *)
            red "Unsupported architecture: ${arch}"
            return 1
            ;;
    esac
    
    local temp_zip="${WORKDIR}/xray.zip"
    if curl -sL "${download_url}" -o "${temp_zip}"; then
        unzip -oq "${temp_zip}" -d "${WORKDIR}" 2>/dev/null
        chmod +x "${XRAY_BIN}"
        rm -f "${temp_zip}"
        green "Xray installed successfully"
        return 0
    else
        red "Xray installation failed"
        return 1
    fi
}

# ===========================================
# Install Cloudflared
# ===========================================

install_cloudflared() {
    if [ -n "${DISABLE_ARGO}" ]; then
        green "Argo tunnel disabled"
        return 0
    fi
    
    if [ -f "${ARGO_BIN}" ] && [ -x "${ARGO_BIN}" ]; then
        green "Cloudflared already installed"
        return 0
    fi
    
    green "Installing Cloudflared..."
    local arch=$(uname -m)
    local download_url=""
    
    case "${arch}" in
        x86_64|amd64)
            download_url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
            ;;
        aarch64|arm64)
            download_url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64"
            ;;
        *)
            red "Unsupported architecture: ${arch}"
            return 1
            ;;
    esac
    
    if download_and_extract "${download_url}" "${ARGO_BIN}"; then
        green "Cloudflared installed successfully"
        return 0
    else
        red "Cloudflared installation failed"
        return 1
    fi
}

# ===========================================
# Install Nezha Agent
# ===========================================

install_nezha() {
    if [ -z "${NEZHA_SERVER}" ] || [ -z "${NEZHA_KEY}" ]; then
        yellow "Nezha monitoring not configured (NEZHA_SERVER or NEZHA_KEY missing)"
        return 0
    fi
    
    if [ -f "${NEZHA_AGENT}" ] && [ -x "${NEZHA_AGENT}" ]; then
        green "Nezha agent already installed"
        return 0
    fi
    
    green "Installing Nezha agent..."
    local arch=$(uname -m)
    local download_url=""
    
    # Determine Nezha version (v0 has NEZHA_PORT, v1 has port in NEZHA_SERVER)
    if [ -n "${NEZHA_PORT}" ]; then
        # Nezha v0
        case "${arch}" in
            x86_64|amd64)
                download_url="https://github.com/nezhahq/agent/releases/latest/download/nezha-agent_linux_amd64.zip"
                ;;
            aarch64|arm64)
                download_url="https://github.com/nezhahq/agent/releases/latest/download/nezha-agent_linux_arm64.zip"
                ;;
            *)
                red "Unsupported architecture: ${arch}"
                return 1
                ;;
        esac
    else
        # Nezha v1
        case "${arch}" in
            x86_64|amd64)
                download_url="https://github.com/nezhahq/agent/releases/latest/download/nezha-agent_linux_amd64.zip"
                ;;
            aarch64|arm64)
                download_url="https://github.com/nezhahq/agent/releases/latest/download/nezha-agent_linux_arm64.zip"
                ;;
            *)
                red "Unsupported architecture: ${arch}"
                return 1
                ;;
        esac
    fi
    
    local temp_zip="${WORKDIR}/nezha.zip"
    if curl -sL "${download_url}" -o "${temp_zip}"; then
        unzip -oq "${temp_zip}" -d "${WORKDIR}" 2>/dev/null
        chmod +x "${NEZHA_AGENT}"
        rm -f "${temp_zip}"
        green "Nezha agent installed successfully"
        return 0
    else
        red "Nezha agent installation failed"
        return 1
    fi
}

# ===========================================
# Generate Xray Configuration
# ===========================================

generate_xray_config() {
    green "Generating Xray configuration..."
    
    cat > "${XRAY_CONFIG}" <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": ${ARGO_PORT},
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
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
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF
    
    green "Xray configuration generated at ${XRAY_CONFIG}"
}

# ===========================================
# Generate Vmess Subscription Link
# ===========================================

generate_vmess_link() {
    local domain="${1}"
    local port="${2:-443}"
    
    green "Generating Vmess subscription link..."
    
    # Vmess JSON structure
    local vmess_json=$(cat <<EOF
{
  "v": "2",
  "ps": "${NAME}",
  "add": "${CFIP}",
  "port": "${port}",
  "id": "${UUID}",
  "aid": "0",
  "net": "ws",
  "type": "none",
  "host": "${domain}",
  "path": "/vmess",
  "tls": "tls",
  "sni": "${domain}"
}
EOF
)
    
    # Base64 encode the JSON
    local vmess_link="vmess://$(echo -n "${vmess_json}" | base64 -w 0)"
    
    # Save to subscription file
    echo "${vmess_link}" > "${SUB_FILE}"
    
    green "Subscription saved to ${SUB_FILE}"
    echo "${vmess_link}"
}

# ===========================================
# Start Xray
# ===========================================

start_xray() {
    green "Starting Xray..."
    
    # Use nice/ionice for resource optimization
    if command -v nice >/dev/null 2>&1 && command -v ionice >/dev/null 2>&1; then
        nice -n 10 ionice -c2 -n7 "${XRAY_BIN}" -config "${XRAY_CONFIG}" > "${LOG_DIR}/xray.log" 2>&1 &
    else
        "${XRAY_BIN}" -config "${XRAY_CONFIG}" > "${LOG_DIR}/xray.log" 2>&1 &
    fi
    
    local xray_pid=$!
    echo "${xray_pid}" > "${PID_DIR}/xray.pid"
    
    sleep 3
    
    if kill -0 "${xray_pid}" 2>/dev/null; then
        green "Xray started successfully (PID: ${xray_pid})"
        return 0
    else
        red "Xray failed to start"
        return 1
    fi
}

# ===========================================
# Start Cloudflared
# ===========================================

start_cloudflared() {
    if [ -n "${DISABLE_ARGO}" ]; then
        return 0
    fi
    
    green "Starting Cloudflared tunnel..."
    
    local argo_log="${LOG_DIR}/argo.log"
    
    if [ -n "${ARGO_AUTH}" ] && [ -n "${ARGO_DOMAIN}" ]; then
        # Fixed tunnel with token or JSON
        green "Using fixed Argo tunnel: ${ARGO_DOMAIN}"
        
        if [[ "${ARGO_AUTH}" =~ TunnelSecret ]]; then
            # JSON format
            echo "${ARGO_AUTH}" > "${WORKDIR}/tunnel.json"
            "${ARGO_BIN}" tunnel --config "${WORKDIR}/tunnel.json" run > "${argo_log}" 2>&1 &
        else
            # Token format
            "${ARGO_BIN}" tunnel --url "http://localhost:${ARGO_PORT}" --no-autoupdate --edge-ip-version auto --protocol http2 run --token "${ARGO_AUTH}" > "${argo_log}" 2>&1 &
        fi
    else
        # Temporary tunnel
        green "Using temporary Argo tunnel"
        "${ARGO_BIN}" tunnel --url "http://localhost:${ARGO_PORT}" --no-autoupdate --edge-ip-version auto --protocol http2 > "${argo_log}" 2>&1 &
    fi
    
    local argo_pid=$!
    echo "${argo_pid}" > "${PID_DIR}/argo.pid"
    
    sleep 5
    
    if kill -0 "${argo_pid}" 2>/dev/null; then
        green "Cloudflared started successfully (PID: ${argo_pid})"
        
        # Extract tunnel domain if temporary
        if [ -z "${ARGO_DOMAIN}" ]; then
            sleep 3
            ARGO_DOMAIN=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "${argo_log}" | head -1 | sed 's/https:\/\///')
            if [ -n "${ARGO_DOMAIN}" ]; then
                green "Temporary tunnel domain: ${ARGO_DOMAIN}"
            fi
        fi
        
        return 0
    else
        red "Cloudflared failed to start"
        return 1
    fi
}

# ===========================================
# Start Nezha Agent
# ===========================================

start_nezha() {
    if [ -z "${NEZHA_SERVER}" ] || [ -z "${NEZHA_KEY}" ]; then
        return 0
    fi
    
    green "Starting Nezha agent..."
    
    local nezha_cmd=""
    
    if [ -n "${NEZHA_PORT}" ]; then
        # Nezha v0
        nezha_cmd="${NEZHA_AGENT} -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY}"
    else
        # Nezha v1 (server includes port or uses default)
        nezha_cmd="${NEZHA_AGENT} -s ${NEZHA_SERVER} -p ${NEZHA_KEY}"
    fi
    
    # Add custom name if set
    if [ -n "${NAME}" ]; then
        nezha_cmd="${nezha_cmd} --report-delay 4 --skip-conn --skip-procs"
    fi
    
    ${nezha_cmd} > "${LOG_DIR}/nezha.log" 2>&1 &
    
    local nezha_pid=$!
    echo "${nezha_pid}" > "${PID_DIR}/nezha.pid"
    
    sleep 2
    
    if kill -0 "${nezha_pid}" 2>/dev/null; then
        green "Nezha agent started successfully (PID: ${nezha_pid})"
        return 0
    else
        red "Nezha agent failed to start"
        return 1
    fi
}

# ===========================================
# Process Monitoring and Auto-Healing
# ===========================================

check_process() {
    local name="$1"
    local pid_file="${PID_DIR}/${name}.pid"
    
    if [ ! -f "${pid_file}" ]; then
        return 1
    fi
    
    local pid=$(cat "${pid_file}")
    if kill -0 "${pid}" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

restart_process() {
    local name="$1"
    yellow "Restarting ${name}..."
    
    case "${name}" in
        xray)
            start_xray
            ;;
        argo)
            start_cloudflared
            ;;
        nezha)
            start_nezha
            ;;
    esac
    
    send_telegram "🔄 <b>${NAME}</b> - ${name} service restarted (auto-recovery)"
}

monitor_loop() {
    green "Starting monitoring loop (30s interval)..."
    
    while true; do
        sleep 30
        
        # Check Xray
        if ! check_process "xray"; then
            red "Xray process died, restarting..."
            restart_process "xray"
        fi
        
        # Check Cloudflared
        if [ -z "${DISABLE_ARGO}" ]; then
            if ! check_process "argo"; then
                red "Cloudflared process died, restarting..."
                restart_process "argo"
            fi
        fi
        
        # Check Nezha
        if [ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_KEY}" ]; then
            if ! check_process "nezha"; then
                red "Nezha agent died, restarting..."
                restart_process "nezha"
            fi
        fi
    done
}

# ===========================================
# Cleanup Function
# ===========================================

cleanup() {
    yellow "Cleaning up old processes..."
    
    for pid_file in "${PID_DIR}"/*.pid; do
        if [ -f "${pid_file}" ]; then
            local pid=$(cat "${pid_file}")
            if kill -0 "${pid}" 2>/dev/null; then
                kill -9 "${pid}" 2>/dev/null
            fi
            rm -f "${pid_file}"
        fi
    done
}

# ===========================================
# Upload Subscription (Optional)
# ===========================================

upload_subscription() {
    if [ -z "${UPLOAD_URL}" ] || [ ! -f "${SUB_FILE}" ]; then
        return 0
    fi
    
    green "Uploading subscription to ${UPLOAD_URL}..."
    
    local sub_content=$(cat "${SUB_FILE}")
    curl -s -X POST "${UPLOAD_URL}" -d "sub=${sub_content}" >/dev/null 2>&1
}

# ===========================================
# Main Startup Function
# ===========================================

main() {
    blue "=========================================="
    blue "  Vmess-Argo + Nezha + Telegram"
    blue "  sin-box framework for zampto server"
    blue "=========================================="
    
    # Cleanup old processes
    cleanup
    
    # Install components
    install_xray || exit 1
    install_cloudflared
    install_nezha
    
    # Generate configuration
    generate_xray_config
    
    # Start services
    start_xray || exit 1
    start_cloudflared
    start_nezha
    
    # Wait for Argo domain if temporary tunnel
    if [ -z "${ARGO_DOMAIN}" ] && [ -z "${DISABLE_ARGO}" ]; then
        sleep 5
        ARGO_DOMAIN=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "${LOG_DIR}/argo.log" | head -1 | sed 's/https:\/\///')
    fi
    
    # Generate subscription link
    if [ -n "${ARGO_DOMAIN}" ]; then
        local vmess_link=$(generate_vmess_link "${ARGO_DOMAIN}" "${CFPORT}")
        
        # Upload subscription if configured
        upload_subscription
        
        # Send Telegram notification with subscription
        local message="✅ <b>${NAME}</b> - Services started successfully

🔗 <b>Subscription Link:</b>
<code>${vmess_link}</code>

🌐 <b>Domain:</b> ${ARGO_DOMAIN}
🆔 <b>UUID:</b> ${UUID}
📡 <b>Port:</b> ${CFPORT}

📊 <b>Monitoring:</b> Active
🔄 <b>Auto-recovery:</b> Enabled"
        
        send_telegram "${message}"
        
        green "Subscription link: ${vmess_link}"
    else
        yellow "No Argo domain available, subscription not generated"
    fi
    
    # Display service status
    blue "=========================================="
    green "Service Status:"
    check_process "xray" && green "✅ Xray: Running" || red "❌ Xray: Stopped"
    [ -z "${DISABLE_ARGO}" ] && check_process "argo" && green "✅ Cloudflared: Running" || yellow "⚠️  Cloudflared: Not configured"
    [ -n "${NEZHA_SERVER}" ] && check_process "nezha" && green "✅ Nezha: Running" || yellow "⚠️  Nezha: Not configured"
    blue "=========================================="
    
    # Start monitoring loop in background
    monitor_loop &
    echo $! > "${PID_DIR}/monitor.pid"
    
    green "All services started successfully!"
    green "Logs directory: ${LOG_DIR}"
    green "Subscription file: ${SUB_FILE}"
    
    # Keep script running
    wait
}

# Handle signals
trap cleanup EXIT INT TERM

# Run main function
main
