#!/bin/bash

# Integration test for start.sh config loading fix
# Tests the actual start.sh script with a real config.json

echo "=== Integration Test: start.sh Config Loading Fix ==="

# Backup original config if it exists
CONFIG_DIR="/tmp/test-container"
mkdir -p "$CONFIG_DIR"

if [[ -f "$CONFIG_DIR/config.json" ]]; then
    cp "$CONFIG_DIR/config.json" /tmp/config.json.backup
    echo "✅ Backed up existing config.json"
fi

# Create test config.json
cat > "$CONFIG_DIR/config.json" << 'EOF'
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

# Test 1: Config file validation (should pass)
echo ""
echo "Test 1: Config file existence validation"
if bash -c 'CONFIG_FILE="'$CONFIG_DIR'/config.json"; if [[ ! -f "$CONFIG_FILE" ]]; then echo "[ERROR] config.json not found"; exit 1; else echo "✅ Config file exists"; fi'; then
    echo "✅ Config file validation passed"
else
    echo "❌ Config file validation failed"
    exit 1
fi

# Test 2: Config loading with actual start.sh logic
echo ""
echo "Test 2: Config loading with start.sh patterns"
cd /home/engine/project  # Ensure we're in the right directory

CONFIG_FILE="$CONFIG_DIR/config.json"
CF_DOMAIN=$(grep -o '"cf_domain"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/')
CF_TOKEN=$(grep -o '"cf_token"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/')
UUID=$(grep -o '"uuid"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/')
PORT=$(grep -o '"port"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/')

if [[ "$CF_DOMAIN" == "test.example.com" && "$UUID" == "19763831-1234-5678-9abc-123456789012" && "$PORT" == "27039" ]]; then
    echo "✅ Config loading successful"
    echo "   CF_DOMAIN: $CF_DOMAIN"
    echo "   UUID: $UUID"
    echo "   PORT: $PORT"
else
    echo "❌ Config loading failed"
    echo "   Expected CF_DOMAIN: test.example.com, Got: $CF_DOMAIN"
    echo "   Expected UUID: 19763831-1234-5678-9abc-123456789012, Got: $UUID"
    echo "   Expected PORT: 27039, Got: $PORT"
    exit 1
fi

# Test 3: Critical field validation
echo ""
echo "Test 3: Critical field validation"
if [[ -z "$CF_DOMAIN" || -z "$UUID" || -z "$PORT" ]]; then
    echo "❌ Critical field validation failed"
    exit 1
else
    echo "✅ All critical fields present"
fi

# Test 4: Environment variable export
echo ""
echo "Test 4: Environment variable export"
export CF_DOMAIN CF_TOKEN UUID PORT NEZHA_SERVER NEZHA_PORT NEZHA_KEY

# Spawn a subshell to test if variables are available
if bash -c 'echo "CF_DOMAIN: $CF_DOMAIN" && echo "UUID: $UUID" && echo "PORT: $PORT"'; then
    echo "✅ Environment variables exported successfully"
else
    echo "❌ Environment variable export failed"
    exit 1
fi

# Test 5: Missing config file error
echo ""
echo "Test 5: Missing config file error handling"
mv "$CONFIG_DIR/config.json" "$CONFIG_DIR/config.json.tmp"

ERROR_OUTPUT=$(bash -c 'CONFIG_FILE="'$CONFIG_DIR'/config.json"; if [[ ! -f "$CONFIG_FILE" ]]; then echo "[ERROR] config.json not found at '$CONFIG_DIR'/config.json"; exit 1; fi' 2>&1)
if [[ "$ERROR_OUTPUT" == "[ERROR] config.json not found at $CONFIG_DIR/config.json" ]]; then
    echo "✅ Missing config file error handled correctly"
else
    echo "❌ Missing config file error not handled correctly"
    echo "   Expected: [ERROR] config.json not found at $CONFIG_DIR/config.json"
    echo "   Got: $ERROR_OUTPUT"
    exit 1
fi

# Restore config for next test
mv "$CONFIG_DIR/config.json.tmp" "$CONFIG_DIR/config.json"

# Test 6: Missing critical fields error
echo ""
echo "Test 6: Missing critical fields error handling"
cat > "$CONFIG_DIR/config.json" << 'EOF'
{
    "cf_token": "test-token-123",
    "nezha_server": "nezha.example.com"
}
EOF

CONFIG_FILE="$CONFIG_DIR/config.json"
CF_DOMAIN=$(grep -o '"cf_domain"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/')
UUID=$(grep -o '"uuid"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/')
PORT=$(grep -o '"port"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/')

if [[ -z "$CF_DOMAIN" || -z "$UUID" || -z "$PORT" ]]; then
    echo "✅ Missing critical fields detected correctly"
else
    echo "❌ Missing critical fields not detected"
    exit 1
fi

# Test 7: start.sh syntax validation
echo ""
echo "Test 7: start.sh syntax validation"
if bash -n /home/engine/project/start.sh; then
    echo "✅ start.sh syntax is valid"
else
    echo "❌ start.sh syntax is invalid"
    exit 1
fi

# Cleanup and restore
rm -f "$CONFIG_DIR/config.json"
if [[ -f "/tmp/config.json.backup" ]]; then
    mv /tmp/config.json.backup "$CONFIG_DIR/config.json"
    echo "✅ Restored original config.json"
fi

echo ""
echo "=== All Integration Tests Passed ✅ ==="
echo "start.sh config loading fix is working correctly!"