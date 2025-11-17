#!/bin/bash

# =============================================================================
# Test Script for start.sh Config Export
# Tests: Config loading, environment variable export, and script execution
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
START_SH="$SCRIPT_DIR/start.sh"
TEST_CONFIG="/tmp/test-config.json"
TEST_WISPBYTE="/tmp/test-wispbyte-argo-singbox-deploy.sh"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

# Test result tracking
test_result() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ PASSED${NC}: $1"
        ((PASSED++))
    else
        echo -e "${RED}❌ FAILED${NC}: $1"
        ((FAILED++))
    fi
}

# =============================================================================
# Test 1: Verify start.sh exists and has correct syntax
# =============================================================================
test_syntax() {
    echo "----------------------------------------"
    echo "Test 1: Syntax validation"
    echo "----------------------------------------"
    
    bash -n "$START_SH"
    test_result "Bash syntax check"
}

# =============================================================================
# Test 2: Verify script structure
# =============================================================================
test_structure() {
    echo "----------------------------------------"
    echo "Test 2: Script structure"
    echo "----------------------------------------"
    
    # Check shebang
    grep -q "^#!/bin/bash" "$START_SH"
    test_result "Shebang present"
    
    # Check set -euo pipefail
    grep -q "set -euo pipefail" "$START_SH"
    test_result "Strict error handling enabled"
    
    # Check log functions
    grep -q "log_info()" "$START_SH"
    test_result "log_info function present"
    
    grep -q "log_error()" "$START_SH"
    test_result "log_error function present"
}

# =============================================================================
# Test 3: Verify config loading
# =============================================================================
test_config_loading() {
    echo "----------------------------------------"
    echo "Test 3: Config loading verification"
    echo "----------------------------------------"
    
    # Check all config fields are read
    grep -q 'CF_DOMAIN=.*grep.*"cf_domain"' "$START_SH"
    test_result "CF_DOMAIN reading present"
    
    grep -q 'CF_TOKEN=.*grep.*"cf_token"' "$START_SH"
    test_result "CF_TOKEN reading present"
    
    grep -q 'UUID=.*grep.*"uuid"' "$START_SH"
    test_result "UUID reading present"
    
    grep -q 'PORT=.*grep.*"port"' "$START_SH"
    test_result "PORT reading present"
    
    grep -q 'NEZHA_SERVER=.*grep.*"nezha_server"' "$START_SH"
    test_result "NEZHA_SERVER reading present"
    
    grep -q 'NEZHA_PORT=.*grep.*"nezha_port"' "$START_SH"
    test_result "NEZHA_PORT reading present"
    
    grep -q 'NEZHA_KEY=.*grep.*"nezha_key"' "$START_SH"
    test_result "NEZHA_KEY reading present"
}

# =============================================================================
# Test 4: Verify environment variable export
# =============================================================================
test_export() {
    echo "----------------------------------------"
    echo "Test 4: Environment variable export"
    echo "----------------------------------------"
    
    # Check export statement
    grep -q "export CF_DOMAIN CF_TOKEN UUID PORT NEZHA_SERVER NEZHA_PORT NEZHA_KEY" "$START_SH"
    test_result "All variables exported in one statement"
    
    # Verify export happens after config loading
    export_line=$(grep -n "export CF_DOMAIN CF_TOKEN UUID PORT" "$START_SH" | cut -d: -f1)
    config_line=$(grep -n "读取配置" "$START_SH" | head -1 | cut -d: -f1)
    
    if [ "$export_line" -gt "$config_line" ]; then
        test_result "Export happens after config loading"
    else
        false
        test_result "Export happens after config loading"
    fi
}

# =============================================================================
# Test 5: Verify validation logic
# =============================================================================
test_validation() {
    echo "----------------------------------------"
    echo "Test 5: Validation logic"
    echo "----------------------------------------"
    
    # Check config file existence check
    grep -q 'if \[\[ ! -f "$CONFIG_FILE" \]\]' "$START_SH"
    test_result "Config file existence check present"
    
    # Check required fields validation
    grep -q 'if \[\[ -z "$CF_DOMAIN" || -z "$UUID" \]\]' "$START_SH"
    test_result "Required fields validation present"
    
    # Check default values
    grep -q 'PORT=\${PORT:-27039}' "$START_SH"
    test_result "PORT default value set"
    
    grep -q 'NEZHA_PORT=\${NEZHA_PORT:-5555}' "$START_SH"
    test_result "NEZHA_PORT default value set"
}

# =============================================================================
# Test 6: Verify Nezha startup logic
# =============================================================================
test_nezha() {
    echo "----------------------------------------"
    echo "Test 6: Nezha startup logic"
    echo "----------------------------------------"
    
    # Check Nezha is non-blocking
    grep -q "Nezha startup failed (non-blocking, continuing...)" "$START_SH"
    test_result "Nezha failure is non-blocking"
    
    # Check architecture detection
    grep -q "ARCH=.*uname -m" "$START_SH"
    test_result "Architecture detection present"
    
    # Check Nezha download
    grep -q "nezha-agent-linux_" "$START_SH"
    test_result "Nezha download logic present"
}

# =============================================================================
# Test 7: Verify wispbyte script call
# =============================================================================
test_wispbyte_call() {
    echo "----------------------------------------"
    echo "Test 7: Wispbyte script call"
    echo "----------------------------------------"
    
    # Check wispbyte script is called
    grep -q "bash /home/container/wispbyte-argo-singbox-deploy.sh" "$START_SH"
    test_result "Wispbyte script call present"
    
    # Check file existence check
    grep -q 'if \[\[ -f "/home/container/wispbyte-argo-singbox-deploy.sh" \]\]' "$START_SH"
    test_result "Wispbyte file existence check present"
}

# =============================================================================
# Test 8: Integration test with mock config
# =============================================================================
test_integration() {
    echo "----------------------------------------"
    echo "Test 8: Integration test with mock config"
    echo "----------------------------------------"
    
    # Create mock config.json
    cat > "$TEST_CONFIG" << 'EOF'
{
  "cf_domain": "test.example.com",
  "cf_token": "test-token-12345",
  "uuid": "12345678-1234-1234-1234-123456789abc",
  "port": "27039",
  "nezha_server": "nezha.example.com",
  "nezha_port": "5555",
  "nezha_key": "test-nezha-key"
}
EOF
    
    # Create mock wispbyte script that prints received env vars
    cat > "$TEST_WISPBYTE" << 'EOF'
#!/bin/bash
echo "Mock wispbyte script received:"
echo "  CF_DOMAIN=$CF_DOMAIN"
echo "  CF_TOKEN=$CF_TOKEN"
echo "  UUID=$UUID"
echo "  PORT=$PORT"
echo "  NEZHA_SERVER=$NEZHA_SERVER"
echo "  NEZHA_PORT=$NEZHA_PORT"
echo "  NEZHA_KEY=$NEZHA_KEY"

# Verify all required vars are set
if [[ -n "$CF_DOMAIN" && -n "$UUID" && -n "$PORT" ]]; then
    echo "✅ All required environment variables received"
    exit 0
else
    echo "❌ Missing required environment variables"
    exit 1
fi
EOF
    chmod +x "$TEST_WISPBYTE"
    
    # Create modified start.sh for testing
    cat "$START_SH" | sed "s|/home/container/config.json|$TEST_CONFIG|g" | \
        sed "s|/home/container/wispbyte-argo-singbox-deploy.sh|$TEST_WISPBYTE|g" | \
        sed 's/curl -s -L.*nezha-agent.tar.gz/echo "Mock nezha download"/g' | \
        sed 's/tar -xzf.*nezha-agent.tar.gz/echo "Mock nezha extract"/g' | \
        sed 's/nohup.*nezha-agent.*&/echo "Mock nezha start"/g' > /tmp/test-start.sh
    
    chmod +x /tmp/test-start.sh
    
    # Run the test
    OUTPUT=$(bash /tmp/test-start.sh 2>&1)
    
    echo "$OUTPUT"
    
    # Verify config was loaded
    echo "$OUTPUT" | grep -q "Config loaded:"
    test_result "Config loaded message present"
    
    # Verify domain printed
    echo "$OUTPUT" | grep -q "Domain: test.example.com"
    test_result "Domain printed correctly"
    
    # Verify UUID printed
    echo "$OUTPUT" | grep -q "UUID: 12345678-1234-1234-1234-123456789abc"
    test_result "UUID printed correctly"
    
    # Verify port printed
    echo "$OUTPUT" | grep -q "Port: 27039"
    test_result "Port printed correctly"
    
    # Verify wispbyte received env vars
    echo "$OUTPUT" | grep -q "Mock wispbyte script received:"
    test_result "Wispbyte script executed"
    
    echo "$OUTPUT" | grep -q "CF_DOMAIN=test.example.com"
    test_result "CF_DOMAIN exported to wispbyte"
    
    echo "$OUTPUT" | grep -q "UUID=12345678-1234-1234-1234-123456789abc"
    test_result "UUID exported to wispbyte"
    
    echo "$OUTPUT" | grep -q "PORT=27039"
    test_result "PORT exported to wispbyte"
    
    echo "$OUTPUT" | grep -q "All required environment variables received"
    test_result "Wispbyte confirms all vars received"
    
    # Cleanup
    rm -f "$TEST_CONFIG" "$TEST_WISPBYTE" /tmp/test-start.sh
}

# =============================================================================
# Test 9: Line count verification
# =============================================================================
test_line_count() {
    echo "----------------------------------------"
    echo "Test 9: Line count verification"
    echo "----------------------------------------"
    
    LINE_COUNT=$(wc -l < "$START_SH")
    echo "Line count: $LINE_COUNT"
    
    # Should be under 150 lines (simplified)
    if [ "$LINE_COUNT" -lt 150 ]; then
        test_result "Line count under 150 (simplified script)"
    else
        false
        test_result "Line count under 150 (simplified script)"
    fi
}

# =============================================================================
# Test 10: Line endings verification
# =============================================================================
test_line_endings() {
    echo "----------------------------------------"
    echo "Test 10: Line endings verification"
    echo "----------------------------------------"
    
    CRLF_COUNT=$(grep -c $'\r' "$START_SH" 2>/dev/null || echo 0)
    
    if [ "$CRLF_COUNT" -eq 0 ]; then
        test_result "No CRLF line endings (LF only)"
    else
        false
        test_result "No CRLF line endings (LF only)"
    fi
}

# =============================================================================
# Run all tests
# =============================================================================
echo "============================================="
echo "  start.sh Config Export Test Suite"
echo "============================================="
echo ""

test_syntax
test_structure
test_config_loading
test_export
test_validation
test_nezha
test_wispbyte_call
test_integration
test_line_count
test_line_endings

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "============================================="
echo "  Test Results Summary"
echo "============================================="
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo "============================================="

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ ALL TESTS PASSED!${NC}"
    exit 0
else
    echo -e "${RED}❌ SOME TESTS FAILED!${NC}"
    exit 1
fi
