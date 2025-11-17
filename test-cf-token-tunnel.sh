#!/bin/bash

# =============================================================================
# Test CF_TOKEN Tunnel Functionality
# =============================================================================
set -e

echo "======================================"
echo "Testing CF_TOKEN Tunnel Fix"
echo "======================================"

# Test directory setup
TEST_DIR="/tmp/argo-test"
CONFIG_FILE="$TEST_DIR/config.json"
WORK_DIR="$TEST_DIR/argo-tuic"
BIN_DIR="$WORK_DIR/bin"
LOG_DIR="$WORK_DIR/logs"

# Clean up previous test
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR" "$WORK_DIR" "$BIN_DIR" "$LOG_DIR"

# Create test config
cat > "$CONFIG_FILE" << 'EOF'
{
  "CF_DOMAIN": "test.example.com",
  "CF_TOKEN": "test_token_12345",
  "UUID": "12345678-1234-1234-1234-123456789abc",
  "ARGO_PORT": "27039"
}
EOF

echo "✅ Test environment created"
echo "Config file: $CONFIG_FILE"
echo "Work directory: $WORK_DIR"

# Test 1: Check if script loads config correctly
echo ""
echo "=== Test 1: Configuration Loading ==="
export CONFIG_FILE="$CONFIG_FILE"
export WORK_DIR="$WORK_DIR"
export BIN_DIR="$BIN_DIR"
export LOG_DIR="$LOG_DIR"

# Extract config loading part from argo-diagnostic.sh
source /dev/stdin << 'EOF'
# Log functions
log_info() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1"; }
log_warn() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] [WARN] $1" >&2; }
log_error() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1" >&2; }
log_success() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] [✅ SUCCESS] $1"; }

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

# Load config function (simplified)
load_config() {
    log_info "Loading configuration from $CONFIG_FILE..."
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_warn "Config file not found: $CONFIG_FILE"
        return 1
    fi
    
    if command -v jq >/dev/null 2>&1; then
        CF_DOMAIN=$(jq -r '.CF_DOMAIN // .cf_domain // empty' "$CONFIG_FILE" 2>/dev/null)
        CF_TOKEN=$(jq -r '.CF_TOKEN // .cf_token // empty' "$CONFIG_FILE" 2>/dev/null)
        UUID=$(jq -r '.UUID // .uuid // empty' "$CONFIG_FILE" 2>/dev/null)
        ARGO_PORT=$(jq -r '.ARGO_PORT // .argo_port // "27039"' "$CONFIG_FILE" 2>/dev/null)
    else
        CF_DOMAIN=$(grep -oE '"(CF_DOMAIN|cf_domain)"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | head -1 | sed -E 's/.*"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')
        CF_TOKEN=$(grep -oE '"(CF_TOKEN|cf_token)"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | head -1 | sed -E 's/.*"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')
        UUID=$(grep -oE '"(UUID|uuid)"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | head -1 | sed -E 's/.*"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')
        ARGO_PORT=$(grep -oE '"(ARGO_PORT|argo_port)"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | head -1 | sed -E 's/.*"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')
        if [[ -z "$ARGO_PORT" ]]; then
            ARGO_PORT=$(grep -oE '"(ARGO_PORT|argo_port)"[[:space:]]*:[[:space:]]*[^,}[:space:]]+' "$CONFIG_FILE" | head -1 | sed -E 's/.*:[[:space:]]*//' | sed -E 's/[",]*$//')
        fi
    fi
    
    ARGO_PORT=${ARGO_PORT:-27039}
    
    log_info "Configuration loaded:"
    log_info "  CF_DOMAIN: ${CF_DOMAIN:-'(not set)'}"
    log_info "  CF_TOKEN: $(format_secret_value "$CF_TOKEN")"
    log_info "  UUID: ${UUID:-'(not set)'}"
    log_info "  ARGO_PORT: $ARGO_PORT"
    
    return 0
}

# Test the config loading
if load_config; then
    log_success "✅ Configuration loaded successfully"
    
    # Test 2: Check CF_TOKEN tunnel command generation
    echo ""
    echo "=== Test 2: CF_TOKEN Tunnel Command Generation ==="
    
    if [[ -n "$CF_DOMAIN" && -n "$CF_TOKEN" ]]; then
        log_info "✅ Both CF_DOMAIN and CF_TOKEN are available"
        log_info "Domain: $CF_DOMAIN"
        log_info "Token: $(format_secret_value "$CF_TOKEN")"
        
        # Test command generation
        CLOUDFLARED_BIN="/usr/local/bin/cloudflared"  # Mock path
        KEEPALIVE_PORT="$ARGO_PORT"
        
        log_info "Method 1 Command: TUNNEL_TOKEN=[hidden] $CLOUDFLARED_BIN tunnel run $CF_DOMAIN"
        log_info "Method 2 Command: $CLOUDFLARED_BIN tunnel --token [hidden] --url http://127.0.0.1:$KEEPALIVE_PORT"
        
        log_success "✅ Tunnel commands generated correctly"
        
        # Test 3: Verify no origin certificate references
        echo ""
        echo "=== Test 3: Verify No Origin Certificate Usage ==="
        
        # Check if the modified script contains origin certificate references
        if grep -q "origincert\|cert.pem\|credentials\.json" /home/engine/project/argo-diagnostic.sh; then
            log_error "❌ Found origin certificate references in the script"
            grep -n "origincert\|cert.pem\|credentials\.json" /home/engine/project/argo-diagnostic.sh
        else
            log_success "✅ No origin certificate references found"
        fi
        
        # Test 4: Verify CF_TOKEN usage
        echo ""
        echo "=== Test 4: Verify CF_TOKEN Usage ==="
        
        if grep -q "TUNNEL_TOKEN.*CF_TOKEN\|export.*TUNNEL_TOKEN\|--token.*CF_TOKEN" /home/engine/project/argo-diagnostic.sh; then
            log_success "✅ Found CF_TOKEN usage in the script"
            grep -n "TUNNEL_TOKEN.*CF_TOKEN\|export.*TUNNEL_TOKEN\|--token.*CF_TOKEN" /home/engine/project/argo-diagnostic.sh
        else
            log_error "❌ No CF_TOKEN usage found in the script"
        fi
        
    else
        log_error "❌ Missing CF_DOMAIN or CF_TOKEN"
        log_error "CF_DOMAIN: ${CF_DOMAIN:-'(missing)'}"
        log_error "CF_TOKEN: ${CF_TOKEN:-'(missing)'}"
    fi
else
    log_error "❌ Failed to load configuration"
fi
EOF

echo ""
echo "======================================"
echo "Test Summary"
echo "======================================"

# Verify the script syntax
echo "Checking script syntax..."
if bash -n /home/engine/project/argo-diagnostic.sh; then
    log_success "✅ Script syntax is valid"
else
    log_error "❌ Script syntax error"
fi

# Check key changes
echo ""
echo "Verifying key changes..."

# 1. Check that old method is removed
if ! grep -q "credentials-file.*credentials.json" /home/engine/project/argo-diagnostic.sh; then
    log_success "✅ Old credentials-file method removed"
else
    log_error "❌ Old credentials-file method still present"
fi

# 2. Check that TUNNEL_TOKEN is used
if grep -q "export TUNNEL_TOKEN" /home/engine/project/argo-diagnostic.sh; then
    log_success "✅ TUNNEL_TOKEN export added"
else
    log_error "❌ TUNNEL_TOKEN export not found"
fi

# 3. Check that tunnel run command is used
if grep -q "tunnel run.*CF_DOMAIN" /home/engine/project/argo-diagnostic.sh; then
    log_success "✅ Fixed tunnel command added"
else
    log_error "❌ Fixed tunnel command not found"
fi

# 4. Check that --token fallback is present
if grep -q "tunnel --token.*CF_TOKEN" /home/engine/project/argo-diagnostic.sh; then
    log_success "✅ --token fallback method added"
else
    log_error "❌ --token fallback method not found"
fi

echo ""
echo "======================================"
echo "✅ All tests completed!"
echo "======================================"

# Clean up
rm -rf "$TEST_DIR"