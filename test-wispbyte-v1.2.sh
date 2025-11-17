#!/bin/bash
# Test script for Wispbyte v1.2.0
# Validates all key features without actually running the services

set -e

SCRIPT="/home/engine/project/wispbyte-argo-singbox-deploy.sh"
TEST_DIR="/tmp/wispbyte-tests"
PASS=0
FAIL=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_pass() { echo -e "${GREEN}✅ PASS${NC}: $1"; ((PASS++)); }
log_fail() { echo -e "${RED}❌ FAIL${NC}: $1"; ((FAIL++)); }
log_test() { echo -e "${YELLOW}[TEST]${NC} $1"; }

mkdir -p "$TEST_DIR"

echo "========================================"
echo "Wispbyte v1.2.0 Test Suite"
echo "========================================"
echo ""

# Test 1: Syntax validation
log_test "Bash syntax validation"
if bash -n "$SCRIPT"; then
    log_pass "Syntax validation"
else
    log_fail "Syntax validation"
fi

# Test 2: Line count
log_test "Line count check"
lines=$(wc -l < "$SCRIPT")
if [[ $lines -lt 250 ]]; then
    log_pass "Line count: $lines lines (target: <250)"
else
    log_fail "Line count: $lines lines (exceeds 250)"
fi

# Test 3: Line endings (LF only)
log_test "Line ending check (LF only)"
if grep -q $'\r' "$SCRIPT"; then
    log_fail "File contains CRLF (should be LF only)"
else
    log_pass "File has correct LF line endings"
fi

# Test 4: Required functions
log_test "Required functions check"
functions=("log_info" "log_error" "load_config" "detect_arch" "download_singbox" "download_cloudflared" "generate_singbox_config" "start_singbox" "start_cloudflared" "generate_subscription" "main")
all_present=true
for func in "${functions[@]}"; do
    if ! grep -q "^$func()" "$SCRIPT"; then
        echo "  Missing function: $func"
        all_present=false
    fi
done
if $all_present; then
    log_pass "All required functions present (${#functions[@]} functions)"
else
    log_fail "Some required functions missing"
fi

# Test 5: Dual-priority config loading
log_test "Dual-priority config loading pattern"
if grep -q "Priority 1.*Priority 2\|CF_DOMAIN.*CF_TOKEN.*UUID" "$SCRIPT" && \
   grep -q 'CF_DOMAIN="${CF_DOMAIN:-}"' "$SCRIPT" && \
   grep -q 'if \[\[ -z "$CF_DOMAIN" && -f "$CONFIG_FILE" \]\]' "$SCRIPT"; then
    log_pass "Dual-priority config loading implemented"
else
    log_fail "Dual-priority config loading not properly implemented"
fi

# Test 6: Architecture support
log_test "Architecture detection support"
arch_patterns=("amd64" "arm64" "arm")
all_archs=true
for arch in "${arch_patterns[@]}"; do
    if ! grep -q "echo \"$arch\"" "$SCRIPT"; then
        echo "  Missing arch: $arch"
        all_archs=false
    fi
done
if $all_archs; then
    log_pass "All required architectures supported"
else
    log_fail "Some architectures missing"
fi

# Test 7: GitHub API version detection
log_test "GitHub API version detection"
if grep -q "api.github.com" "$SCRIPT" && \
   grep -q '"tag_name"' "$SCRIPT"; then
    log_pass "GitHub API version detection implemented"
else
    log_fail "GitHub API version detection not found"
fi

# Test 8: Proper URL construction
log_test "Proper URL construction"
if grep -q 'releases/download/v\${version}' "$SCRIPT" && \
   grep -q 'releases/download/\${version}' "$SCRIPT"; then
    log_pass "Proper URL construction with version"
else
    log_fail "URL construction doesn't use version properly"
fi

# Test 9: VMESS config with WebSocket
log_test "VMESS-WS-TLS configuration"
if grep -q '"type": "vmess"' "$SCRIPT" && \
   grep -q '"type": "ws"' "$SCRIPT" && \
   grep -q '"path": "/ws"' "$SCRIPT" && \
   grep -q '"tls": "tls"' "$SCRIPT"; then
    log_pass "VMESS-WS-TLS config properly defined"
else
    log_fail "VMESS-WS-TLS config incomplete"
fi

# Test 10: Subscription generation with SNI and fingerprint
log_test "Subscription with SNI and fingerprint"
if grep -q '"sni"' "$SCRIPT" && \
   grep -q '"fingerprint"' "$SCRIPT" && \
   grep -q 'vmess://' "$SCRIPT"; then
    log_pass "Subscription includes SNI, fingerprint, and vmess protocol"
else
    log_fail "Subscription missing required fields"
fi

# Test 11: Base64 encoding for subscription
log_test "Double base64 encoding for subscription"
if grep -q 'base64 -w 0' "$SCRIPT" && \
   grep -c 'base64' "$SCRIPT" | grep -q '[2-9]'; then
    log_pass "Double base64 encoding for subscription file"
else
    log_fail "Base64 encoding not properly implemented"
fi

# Test 12: Service startup with PID tracking
log_test "Service startup with PID tracking"
if grep -q 'nohup.*&' "$SCRIPT" && \
   grep -q 'echo.*>.*/\.pid' "$SCRIPT" && \
   grep -q 'kill -0' "$SCRIPT"; then
    log_pass "Service startup with PID tracking and health checks"
else
    log_fail "Service startup incomplete"
fi

# Test 13: Sing-box configuration file generation
log_test "Sing-box configuration generation"
if grep -q 'cat > "$SINGBOX_CONFIG"' "$SCRIPT" && \
   grep -q 'listen_port\|listen_port' "$SCRIPT" && \
   grep -q 'alterId' "$SCRIPT"; then
    log_pass "Sing-box config generation with proper fields"
else
    log_fail "Sing-box config generation incomplete"
fi

# Test 14: Error handling and logging
log_test "Error handling and logging"
if grep -q 'log_error' "$SCRIPT" && \
   grep -q 'log_info' "$SCRIPT" && \
   grep -q 'set -euo pipefail' "$SCRIPT"; then
    log_pass "Error handling and logging properly implemented"
else
    log_fail "Error handling or logging incomplete"
fi

# Test 15: Working directory structure
log_test "Working directory structure"
if grep -q 'WORK_DIR="/home/container/argo-tuic"' "$SCRIPT" && \
   grep -q 'BIN_DIR="$WORK_DIR/bin"' "$SCRIPT" && \
   grep -q 'SUBSCRIPTION_FILE="/home/container/.npm/sub.txt"' "$SCRIPT"; then
    log_pass "Working directory structure properly defined"
else
    log_fail "Working directory structure incomplete"
fi

# Test 16: Configuration validation
log_test "Configuration validation"
if grep -q '\[\[ -z "$CF_DOMAIN" || -z "$UUID" \]\]' "$SCRIPT"; then
    log_pass "Configuration validation for required fields"
else
    log_fail "Configuration validation not implemented"
fi

# Test 17: Environment variable export pattern
log_test "Environment variable handling"
if grep -q 'CF_DOMAIN=.*CF_TOKEN=.*UUID=' "$SCRIPT"; then
    log_pass "Environment variable handling pattern"
else
    log_fail "Environment variable handling incomplete"
fi

# Test 18: Main function structure
log_test "Main function and trap handlers"
if grep -q '^main()' "$SCRIPT" && \
   grep -q 'trap.*SIGTERM' "$SCRIPT" && \
   grep -q 'main "$@"' "$SCRIPT"; then
    log_pass "Main function and signal handlers properly structured"
else
    log_fail "Main function or signal handlers missing"
fi

# Summary
echo ""
echo "========================================"
echo "Test Results"
echo "========================================"
echo -e "Passed: ${GREEN}$PASS${NC}"
echo -e "Failed: ${RED}$FAIL${NC}"
echo "Total:  $((PASS + FAIL))"
echo ""

if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
fi
