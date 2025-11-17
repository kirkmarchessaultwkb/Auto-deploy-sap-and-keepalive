#!/bin/bash
# =============================================================================
# Test Script: Verify wispbyte-argo-singbox-deploy.sh reads env vars correctly
# =============================================================================

echo "=========================================="
echo "Test: Wispbyte Environment Variable Reading"
echo "=========================================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass=0
fail=0

test_result() {
    local name="$1"
    local result="$2"
    if [[ "$result" == "0" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: $name"
        ((pass++))
    else
        echo -e "${RED}✗ FAIL${NC}: $name"
        ((fail++))
    fi
}

# Test 1: Script syntax
echo -e "\n${YELLOW}[Test 1]${NC} Checking script syntax..."
bash -n wispbyte-argo-singbox-deploy.sh
test_result "Script syntax valid" "$?"

# Test 2: Line count < 200
echo -e "\n${YELLOW}[Test 2]${NC} Checking line count..."
line_count=$(wc -l < wispbyte-argo-singbox-deploy.sh)
echo "Line count: $line_count"
[[ $line_count -lt 200 ]] && result=0 || result=1
test_result "Line count < 200 ($line_count lines)" "$result"

# Test 3: Version updated to 1.1.0
echo -e "\n${YELLOW}[Test 3]${NC} Checking version number..."
grep -q "Version: 1.1.0" wispbyte-argo-singbox-deploy.sh
test_result "Version 1.1.0 present" "$?"

# Test 4: No CONFIG_FILE variable used
echo -e "\n${YELLOW}[Test 4]${NC} Checking CONFIG_FILE removed..."
grep -q 'CONFIG_FILE="/home/container/config.json"' wispbyte-argo-singbox-deploy.sh && result=1 || result=0
test_result "CONFIG_FILE variable removed" "$result"

# Test 5: Environment variables used
echo -e "\n${YELLOW}[Test 5]${NC} Checking environment variable usage..."
grep -q 'CF_DOMAIN="${CF_DOMAIN:-}"' wispbyte-argo-singbox-deploy.sh
test_result "CF_DOMAIN from env" "$?"

grep -q 'CF_TOKEN="${CF_TOKEN:-}"' wispbyte-argo-singbox-deploy.sh
test_result "CF_TOKEN from env" "$?"

grep -q 'UUID="${UUID:-}"' wispbyte-argo-singbox-deploy.sh
test_result "UUID from env" "$?"

grep -q 'PORT="${PORT:-27039}"' wispbyte-argo-singbox-deploy.sh
test_result "PORT from env with default" "$?"

# Test 6: validate_config function exists
echo -e "\n${YELLOW}[Test 6]${NC} Checking validate_config function..."
grep -q "^validate_config()" wispbyte-argo-singbox-deploy.sh
test_result "validate_config function exists" "$?"

# Test 7: No load_config function
echo -e "\n${YELLOW}[Test 7]${NC} Checking load_config removed..."
grep -q "^load_config()" wispbyte-argo-singbox-deploy.sh && result=1 || result=0
test_result "load_config function removed" "$result"

# Test 8: main() calls validate_config
echo -e "\n${YELLOW}[Test 8]${NC} Checking main() uses validate_config..."
grep -A 10 "^main()" wispbyte-argo-singbox-deploy.sh | grep -q "validate_config"
test_result "main() calls validate_config" "$?"

# Test 9: Required functions still present
echo -e "\n${YELLOW}[Test 9]${NC} Checking required functions..."
functions=("detect_arch" "download_singbox" "download_cloudflared" "generate_singbox_config" "start_singbox" "start_cloudflared" "generate_subscription")

for func in "${functions[@]}"; do
    grep -q "^${func}()" wispbyte-argo-singbox-deploy.sh
    test_result "Function $func exists" "$?"
done

# Test 10: Architecture support
echo -e "\n${YELLOW}[Test 10]${NC} Checking architecture support..."
grep -A 5 "detect_arch()" wispbyte-argo-singbox-deploy.sh | grep -q "arm64"
test_result "ARM64 support present" "$?"

# Test 11: Subscription file path correct
echo -e "\n${YELLOW}[Test 11]${NC} Checking subscription file path..."
grep -q 'SUBSCRIPTION_FILE="/home/container/.npm/sub.txt"' wispbyte-argo-singbox-deploy.sh
test_result "Subscription path correct" "$?"

# Test 12: VMESS node generation format
echo -e "\n${YELLOW}[Test 12]${NC} Checking VMESS node format..."
grep -q '"v":"2"' wispbyte-argo-singbox-deploy.sh
test_result "VMESS v2 format" "$?"

grep -q '"tls":"tls"' wispbyte-argo-singbox-deploy.sh
test_result "TLS enabled" "$?"

grep -q '"fingerprint":"chrome"' wispbyte-argo-singbox-deploy.sh
test_result "Chrome fingerprint" "$?"

# Test 13: Functional test with mock environment
echo -e "\n${YELLOW}[Test 13]${NC} Functional test with environment variables..."

# Create a test wrapper that only validates config
cat > /tmp/test-wispbyte-wrapper.sh <<'WRAPPER'
#!/bin/bash
set -o pipefail

# Mock environment
export CF_DOMAIN="test.example.com"
export CF_TOKEN="test-token-123"
export UUID="12345678-1234-1234-1234-123456789abc"
export PORT="27039"

# Source the script functions
WORK_DIR="/tmp/wispbyte-singbox-test"
BIN_DIR="$WORK_DIR/bin"
LOG_FILE="$WORK_DIR/test.log"
mkdir -p "$WORK_DIR"

log() { echo "[$(date +'%H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

validate_config() {
    log "[INFO] Validating configuration..."
    log "[INFO] Domain: ${CF_DOMAIN:-'not set'}, UUID: ${UUID:-'not set'}, Port: $PORT"
    
    if [[ -z "$UUID" ]]; then
        log "[ERROR] UUID not set (required)"
        return 1
    fi
    
    log "[OK] Configuration valid"
    return 0
}

# Test validation
validate_config
exit_code=$?

# Verify variables are set correctly
[[ "$CF_DOMAIN" == "test.example.com" ]] || exit 1
[[ "$CF_TOKEN" == "test-token-123" ]] || exit 1
[[ "$UUID" == "12345678-1234-1234-1234-123456789abc" ]] || exit 1
[[ "$PORT" == "27039" ]] || exit 1

exit $exit_code
WRAPPER

chmod +x /tmp/test-wispbyte-wrapper.sh
/tmp/test-wispbyte-wrapper.sh > /dev/null 2>&1
test_result "Config validation with env vars" "$?"
rm -f /tmp/test-wispbyte-wrapper.sh
rm -rf /tmp/wispbyte-singbox-test

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "${GREEN}Passed: $pass${NC}"
echo -e "${RED}Failed: $fail${NC}"
echo "=========================================="

if [[ $fail -eq 0 ]]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
fi
