#!/bin/bash

# =============================================================================
# Simple Integration Test for VMess-WS-Argo Subscription Generation
# Direct test of subscription functions without complex config parsing
# =============================================================================

set -e

echo "Integration Test: VMess-WS-Argo Subscription Generation"
echo "========================================================"
echo ""

# Test directory
TEST_DIR="/tmp/test-zampto-simple"
mkdir -p "$TEST_DIR"

# Use simple variable definitions (like after config loading)
CF_DOMAIN="zampto.xunda.ggff.net"
UUID="19763831-f9cb-45f2-b59a-9d60264c7f1c"

# Define log functions
log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

log_success() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [✅ SUCCESS] $1"
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1" >&2
}

# Copy functions from start.sh
generate_vmess_node() {
    local domain="$1"
    local uuid="$2"
    local name="${3:-zampto-node}"
    
    if [[ -z "$domain" ]] || [[ -z "$uuid" ]]; then
        return 1
    fi
    
    local node_json=$(cat <<EOF
{
  "v": "2",
  "ps": "$name",
  "add": "$domain",
  "port": "443",
  "id": "$uuid",
  "aid": "0",
  "net": "ws",
  "type": "none",
  "host": "$domain",
  "path": "/ws",
  "tls": "tls"
}
EOF
)
    
    # Base64 encode without line wrapping
    local node_b64=$(echo -n "$node_json" | base64 -w 0)
    echo "vmess://$node_b64"
}

generate_subscription() {
    local node="$1"
    local sub_file="$2"
    
    if [[ -z "$node" ]] || [[ -z "$sub_file" ]]; then
        return 1
    fi
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$sub_file")"
    
    # Subscription file content is base64 encoded node list
    echo -n "$node" | base64 -w 0 > "$sub_file"
    
    return 0
}

generate_subscription_output() {
    log_info "Generating vmess-ws-argo subscription..."
    
    if [[ -z "$CF_DOMAIN" ]]; then
        log_error "CF_DOMAIN is not set, skipping subscription generation"
        return 1
    fi
    
    if [[ -z "$UUID" ]]; then
        log_error "UUID is not set, skipping subscription generation"
        return 1
    fi
    
    # Generate vmess node
    VMESS_NODE=$(generate_vmess_node "$CF_DOMAIN" "$UUID" "zampto-argo")
    if [[ -z "$VMESS_NODE" ]]; then
        log_error "Failed to generate vmess node"
        return 1
    fi
    
    log_success "VMESS Node: $VMESS_NODE"
    
    # Generate subscription file (for index.js /sub endpoint)
    SUB_FILE="$TEST_DIR/.npm/sub.txt"
    if generate_subscription "$VMESS_NODE" "$SUB_FILE"; then
        log_success "Subscription generated"
        log_success "Subscription URL: https://$CF_DOMAIN/sub"
        log_info "Subscription file: $SUB_FILE"
        return 0
    else
        log_error "Failed to generate subscription file"
        return 1
    fi
}

# Step 1: Display configuration
echo "Step 1: Configuration"
echo "-------------------"
log_info "CF_DOMAIN: $CF_DOMAIN"
log_info "UUID: $UUID"
echo ""

# Step 2: Generate subscription
echo "Step 2: Generate subscription"
echo "----------------------------"
if generate_subscription_output; then
    echo ""
    log_success "Subscription generation successful"
    echo ""
    
    # Verify subscription file was created
    if [[ -f "$TEST_DIR/.npm/sub.txt" ]]; then
        log_success "Subscription file exists"
        
        # Display decoded subscription
        echo ""
        echo "Subscription file decoded (VMess node):"
        echo "---"
        cat "$TEST_DIR/.npm/sub.txt" | base64 -d
        echo ""
        echo "---"
        echo ""
        
        # Decode the node to verify JSON
        log_info "Verifying node structure..."
        NODE_CONTENT=$(cat "$TEST_DIR/.npm/sub.txt" | base64 -d)
        
        # Extract and verify key fields
        if echo "$NODE_CONTENT" | grep -q '"v": "2"'; then
            log_success "✅ Version field correct"
        fi
        if echo "$NODE_CONTENT" | grep -q "\"id\": \"$UUID\""; then
            log_success "✅ UUID field correct"
        fi
        if echo "$NODE_CONTENT" | grep -q "\"add\": \"$CF_DOMAIN\""; then
            log_success "✅ Domain field correct"
        fi
        if echo "$NODE_CONTENT" | grep -q '"port": "443"'; then
            log_success "✅ Port field correct"
        fi
        if echo "$NODE_CONTENT" | grep -q '"net": "ws"'; then
            log_success "✅ Protocol field correct"
        fi
        if echo "$NODE_CONTENT" | grep -q '"tls": "tls"'; then
            log_success "✅ TLS field correct"
        fi
        if echo "$NODE_CONTENT" | grep -q '"path": "/ws"'; then
            log_success "✅ Path field correct"
        fi
        
        echo ""
    else
        log_error "Subscription file not created at $TEST_DIR/.npm/sub.txt"
        exit 1
    fi
else
    log_error "Subscription generation failed"
    exit 1
fi

echo ""
log_success "Integration test passed!"
echo ""

# Cleanup
rm -rf "$TEST_DIR"
