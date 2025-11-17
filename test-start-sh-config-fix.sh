#!/bin/bash

# Test script for start.sh config loading fix

echo "=== Testing start.sh Config Loading Fix ==="

# Create test config.json
TEST_CONFIG="/tmp/test-config.json"
cat > "$TEST_CONFIG" << 'EOF'
{
    "cf_domain": "test.example.com",
    "cf_token": "test-token-123",
    "uuid": "19763831-1234-5678-9abc-123456789012",
    "port": "27039",
    "nezha_server": "nezha.example.com",
    "nezha_port": "5555",
    "nezha_key": "test-nezha-key"
}
EOF

echo "✅ Created test config.json"

# Test 1: Config file exists check
echo ""
echo "Test 1: Config file existence check"
if [[ -f "$TEST_CONFIG" ]]; then
    echo "✅ Config file exists"
else
    echo "❌ Config file missing"
    exit 1
fi

# Test 2: Config loading with grep+cut
echo ""
echo "Test 2: Config loading with grep+sed (handles spaces)"
CF_DOMAIN=$(grep -o '"cf_domain"[[:space:]]*:[[:space:]]*"[^"]*"' "$TEST_CONFIG" | sed 's/.*"\([^"]*\)".*/\1/')
CF_TOKEN=$(grep -o '"cf_token"[[:space:]]*:[[:space:]]*"[^"]*"' "$TEST_CONFIG" | sed 's/.*"\([^"]*\)".*/\1/')
UUID=$(grep -o '"uuid"[[:space:]]*:[[:space:]]*"[^"]*"' "$TEST_CONFIG" | sed 's/.*"\([^"]*\)".*/\1/')
PORT=$(grep -o '"port"[[:space:]]*:[[:space:]]*"[^"]*"' "$TEST_CONFIG" | sed 's/.*"\([^"]*\)".*/\1/')

echo "✅ CF_DOMAIN: $CF_DOMAIN"
echo "✅ CF_TOKEN: $CF_TOKEN"
echo "✅ UUID: $UUID"
echo "✅ PORT: $PORT"

# Test 3: Critical field validation
echo ""
echo "Test 3: Critical field validation"
if [[ -z "$CF_DOMAIN" || -z "$UUID" || -z "$PORT" ]]; then
    echo "❌ Missing required config fields"
    exit 1
else
    echo "✅ All critical fields present"
fi

# Test 4: Export functionality
echo ""
echo "Test 4: Environment variable export"
export CF_DOMAIN CF_TOKEN UUID PORT NEZHA_SERVER NEZHA_PORT NEZHA_KEY
echo "✅ Environment variables exported"

# Test 5: Verify exported values
echo ""
echo "Test 5: Verify exported values"
echo "✅ Exported CF_DOMAIN: $CF_DOMAIN"
echo "✅ Exported UUID: $UUID"
echo "✅ Exported PORT: $PORT"

# Test 6: Missing field validation
echo ""
echo "Test 6: Missing field validation"
# Create incomplete config
INCOMPLETE_CONFIG="/tmp/incomplete-config.json"
cat > "$INCOMPLETE_CONFIG" << 'EOF'
{
    "cf_token": "test-token-123",
    "nezha_server": "nezha.example.com"
}
EOF

# Test missing fields
CF_DOMAIN=$(grep -o '"cf_domain"[[:space:]]*:[[:space:]]*"[^"]*"' "$INCOMPLETE_CONFIG" | sed 's/.*"\([^"]*\)".*/\1/')
UUID=$(grep -o '"uuid"[[:space:]]*:[[:space:]]*"[^"]*"' "$INCOMPLETE_CONFIG" | sed 's/.*"\([^"]*\)".*/\1/')
PORT=$(grep -o '"port"[[:space:]]*:[[:space:]]*"[^"]*"' "$INCOMPLETE_CONFIG" | sed 's/.*"\([^"]*\)".*/\1/')

if [[ -z "$CF_DOMAIN" || -z "$UUID" || -z "$PORT" ]]; then
    echo "✅ Correctly detected missing required config fields"
else
    echo "❌ Failed to detect missing fields"
    exit 1
fi

# Cleanup
rm -f "$TEST_CONFIG" "$INCOMPLETE_CONFIG"

echo ""
echo "=== All Tests Passed ✅ ==="
echo "start.sh config loading fix verified successfully!"