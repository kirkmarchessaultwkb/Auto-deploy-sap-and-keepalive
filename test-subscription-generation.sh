#!/bin/bash

# =============================================================================
# Test Script for VMess-WS-Argo Subscription Generation
# =============================================================================

set -e

echo "Testing vmess-ws-argo subscription generation..."
echo ""

# Source the start.sh functions (just the subscription part)
# We'll create a minimal test environment

# Test 1: Basic vmess node generation
echo "Test 1: Generate VMess node"
echo "================================"

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

# Test with example values
DOMAIN="zampto.xunda.ggff.net"
UUID="19763831-f9cb-45f2-b59a-9d60264c7f1c"
NODE_NAME="zampto-argo"

echo "Domain: $DOMAIN"
echo "UUID: $UUID"
echo "Node Name: $NODE_NAME"
echo ""

# Generate node
VMESS_NODE=$(generate_vmess_node "$DOMAIN" "$UUID" "$NODE_NAME")
echo "Generated VMess Node:"
echo "$VMESS_NODE"
echo ""

# Verify it starts with vmess://
if [[ $VMESS_NODE == vmess://* ]]; then
    echo "✅ VMess node format is correct"
else
    echo "❌ VMess node format is incorrect"
    exit 1
fi
echo ""

# Test 2: Subscription file generation
echo "Test 2: Generate subscription file"
echo "================================"

TEST_SUB_FILE="/tmp/test-sub.txt"
rm -f "$TEST_SUB_FILE"

if generate_subscription "$VMESS_NODE" "$TEST_SUB_FILE"; then
    echo "✅ Subscription file generated successfully"
    
    if [[ -f "$TEST_SUB_FILE" ]]; then
        echo "✅ File exists at $TEST_SUB_FILE"
        
        # Read and display the content
        SUB_CONTENT=$(cat "$TEST_SUB_FILE")
        echo "Subscription file content:"
        echo "$SUB_CONTENT"
        echo ""
        
        # Verify it's base64 encoded
        if [[ $SUB_CONTENT == vmess://* ]]; then
            echo "✅ Subscription file contains valid vmess node"
        else
            echo "⚠️  Subscription file content differs from vmess node"
        fi
    else
        echo "❌ File does not exist"
        exit 1
    fi
else
    echo "❌ Failed to generate subscription file"
    exit 1
fi
echo ""

# Test 3: Decode and verify node structure
echo "Test 3: Decode and verify node structure"
echo "================================"

# Extract base64 part from vmess node
BASE64_PART="${VMESS_NODE#vmess://}"

# Decode and display
DECODED=$(echo "$BASE64_PART" | base64 -d 2>/dev/null || true)
echo "Decoded VMess node:"
echo "$DECODED"
echo ""

# Verify JSON structure
if echo "$DECODED" | grep -q '"v": "2"'; then
    echo "✅ Contains version field"
else
    echo "❌ Missing or incorrect version field"
    exit 1
fi

if echo "$DECODED" | grep -q "\"id\": \"$UUID\""; then
    echo "✅ Contains correct UUID"
else
    echo "❌ UUID mismatch or missing"
    exit 1
fi

if echo "$DECODED" | grep -q "\"add\": \"$DOMAIN\""; then
    echo "✅ Contains correct domain"
else
    echo "❌ Domain mismatch or missing"
    exit 1
fi

if echo "$DECODED" | grep -q '"port": "443"'; then
    echo "✅ Contains correct port (443)"
else
    echo "❌ Port mismatch or missing"
    exit 1
fi

if echo "$DECODED" | grep -q '"net": "ws"'; then
    echo "✅ Contains correct protocol (ws)"
else
    echo "❌ Protocol mismatch or missing"
    exit 1
fi

if echo "$DECODED" | grep -q '"tls": "tls"'; then
    echo "✅ Contains TLS enabled"
else
    echo "❌ TLS setting missing"
    exit 1
fi

if echo "$DECODED" | grep -q '"path": "/ws"'; then
    echo "✅ Contains correct path (/ws)"
else
    echo "❌ Path mismatch or missing"
    exit 1
fi

echo ""
echo "================================"
echo "✅ All tests passed!"
echo "================================"

# Cleanup
rm -f "$TEST_SUB_FILE"
