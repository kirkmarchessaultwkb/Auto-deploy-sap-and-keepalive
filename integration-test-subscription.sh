#!/bin/bash

# =============================================================================
# Integration Test for VMess-WS-Argo Subscription Generation
# Simulates the full workflow in start.sh
# =============================================================================

set -e

echo "Integration Test: VMess-WS-Argo Subscription Generation"
echo "========================================================"
echo ""

# Create temporary config file for testing
TEST_CONFIG="/tmp/test-config.json"
TEST_DIR="/tmp/test-zampto"
mkdir -p "$TEST_DIR"

cat > "$TEST_CONFIG" << 'EOF'
{
  "CF_DOMAIN": "zampto.xunda.ggff.net",
  "CF_TOKEN": "test_token_12345",
  "UUID": "19763831-f9cb-45f2-b59a-9d60264c7f1c",
  "NEZHA_SERVER": "nezha.example.com:443",
  "NEZHA_PORT": "5555",
  "NEZHA_KEY": "test_key",
  "ARGO_PORT": "27039"
}
EOF

echo "✅ Test config created at: $TEST_CONFIG"
echo ""

# Source the functions from start.sh
extract_json_value() {
    local file=$1
    local key=$2
    local default_value=${3:-""}

    if [[ ! -f "$file" ]]; then
        printf '%s\n' "$default_value"
        return 1
    fi

    local candidates=("$key")
    local uppercase_key="${key^^}"
    local lowercase_key="${key,,}"

    if [[ "$uppercase_key" != "$key" ]]; then
        candidates+=("$uppercase_key")
    fi
    if [[ "$lowercase_key" != "$key" && "$lowercase_key" != "$uppercase_key" ]]; then
        candidates+=("$lowercase_key")
    fi

    local value=""
    for candidate in "${candidates[@]}"; do
        value=$(awk -v key="$candidate" '
            match($0, "\"" key "\"[[:space:]]*:[[:space:]]*\"([^\"]*)\"", arr) {
                print arr[1]
                exit
            }
        ' "$file")
        if [[ -n "$value" ]]; then
            break
        fi

        value=$(awk -v key="$candidate" '
            match($0, "\"" key "\"[[:space:]]*:[[:space:]]*([^,} 	
]+)", arr) {
                print arr[1]
                exit
            }
        ' "$file")
        if [[ -n "$value" ]]; then
            value=${value//\"/}
            break
        fi
    done

    if [[ -z "$value" ]]; then
        printf '%s\n' "$default_value"
        return 1
    fi

    printf '%s\n' "$value"
    return 0
}

log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

log_success() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [✅ SUCCESS] $1"
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1" >&2
}

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

# Step 1: Load configuration
echo "Step 1: Loading configuration"
echo "----------------------------"
CF_DOMAIN=$(extract_json_value "$TEST_CONFIG" "cf_domain")
CF_TOKEN=$(extract_json_value "$TEST_CONFIG" "cf_token")
UUID=$(extract_json_value "$TEST_CONFIG" "uuid")

log_info "CF_DOMAIN: $CF_DOMAIN"
log_info "CF_TOKEN: ${CF_TOKEN:0:6}... (loaded)"
log_info "UUID: $UUID"
echo ""

# Step 2: Generate subscription
echo "Step 2: Generate subscription"
echo "----------------------------"
if generate_subscription_output; then
    echo ""
    echo "✅ Subscription generation successful"
    echo ""
    
    # Verify subscription file was created
    if [[ -f "$TEST_DIR/.npm/sub.txt" ]]; then
        echo "✅ Subscription file exists at: $TEST_DIR/.npm/sub.txt"
        
        # Display file content
        echo ""
        echo "File contents (base64):"
        echo "---"
        cat "$TEST_DIR/.npm/sub.txt"
        echo ""
        echo "---"
        echo ""
        
        # Decode subscription file to verify
        echo "Decoded subscription file:"
        echo "---"
        cat "$TEST_DIR/.npm/sub.txt" | base64 -d | base64 -d | jq . 2>/dev/null || \
        cat "$TEST_DIR/.npm/sub.txt" | base64 -d
        echo "---"
    else
        log_error "Subscription file not created"
        exit 1
    fi
else
    log_error "Subscription generation failed"
    exit 1
fi

echo ""
echo "✅ Integration test passed!"
echo ""

# Cleanup
rm -rf "$TEST_DIR" "$TEST_CONFIG"
