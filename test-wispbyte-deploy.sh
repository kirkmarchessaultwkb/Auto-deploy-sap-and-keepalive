#!/bin/bash

# =============================================================================
# Test Script for wispbyte-argo-singbox-deploy.sh
# =============================================================================

SCRIPT="/home/engine/project/wispbyte-argo-singbox-deploy.sh"
PASS=0
FAIL=0

pass() { echo "✅ PASS: $1"; ((PASS++)); }
fail() { echo "❌ FAIL: $1"; ((FAIL++)); }
info() { echo "ℹ️  INFO: $1"; }

echo "========================================"
echo "Testing wispbyte-argo-singbox-deploy.sh"
echo "========================================"

# Test 1: Script exists
if [[ -f "$SCRIPT" ]]; then
    pass "Script file exists"
else
    fail "Script file not found"
    exit 1
fi

# Test 2: Script is executable
if [[ -x "$SCRIPT" ]]; then
    pass "Script is executable"
else
    fail "Script is not executable"
fi

# Test 3: Syntax validation
if bash -n "$SCRIPT" 2>/dev/null; then
    pass "Syntax validation passed"
else
    fail "Syntax validation failed"
fi

# Test 4: Line count < 200
LINE_COUNT=$(wc -l < "$SCRIPT")
if (( LINE_COUNT < 200 )); then
    pass "Line count is $LINE_COUNT (< 200 requirement)"
else
    fail "Line count is $LINE_COUNT (>= 200)"
fi

# Test 5: Shebang present
if head -1 "$SCRIPT" | grep -q "^#!/bin/bash"; then
    pass "Shebang present"
else
    fail "Shebang missing"
fi

# Test 6: Required functions present
REQUIRED_FUNCTIONS=(
    "load_config"
    "detect_arch"
    "download_singbox"
    "download_cloudflared"
    "generate_singbox_config"
    "start_singbox"
    "start_cloudflared"
    "generate_subscription"
    "main"
)

for func in "${REQUIRED_FUNCTIONS[@]}"; do
    if grep -q "^${func}()" "$SCRIPT"; then
        pass "Function '$func' present"
    else
        fail "Function '$func' missing"
    fi
done

# Test 7: Required variables defined
REQUIRED_VARS=(
    "CONFIG_FILE"
    "WORK_DIR"
    "BIN_DIR"
    "SINGBOX_BIN"
    "CLOUDFLARED_BIN"
    "SUBSCRIPTION_FILE"
)

for var in "${REQUIRED_VARS[@]}"; do
    if grep -q "^${var}=" "$SCRIPT"; then
        pass "Variable '$var' defined"
    else
        fail "Variable '$var' not defined"
    fi
done

# Test 8: No TUIC references (requirement: no TUIC)
if ! grep -qi "tuic" "$SCRIPT"; then
    pass "No TUIC references (as required)"
else
    fail "TUIC references found (should not include)"
fi

# Test 9: No nodejs-argo references (requirement: no nodejs-argo)
if ! grep -qi "nodejs.*argo\|argo.*nodejs" "$SCRIPT"; then
    pass "No nodejs-argo references (as required)"
else
    fail "nodejs-argo references found (should not include)"
fi

# Test 10: Architecture support
if grep -q "arm64" "$SCRIPT" && grep -q "amd64" "$SCRIPT"; then
    pass "ARM64 and AMD64 support present"
else
    fail "Architecture support incomplete"
fi

# Test 11: VMESS subscription generation
if grep -q "vmess://" "$SCRIPT"; then
    pass "VMESS subscription generation present"
else
    fail "VMESS subscription generation missing"
fi

# Test 12: Cloudflared tunnel support
if grep -q "cloudflared.*tunnel" "$SCRIPT"; then
    pass "Cloudflared tunnel support present"
else
    fail "Cloudflared tunnel support missing"
fi

# Test 13: Sing-box WebSocket path
if grep -q '"/ws"' "$SCRIPT"; then
    pass "WebSocket path '/ws' configured"
else
    fail "WebSocket path not configured"
fi

# Test 14: Config file path
if grep -q "/home/container/config.json" "$SCRIPT"; then
    pass "Config file path correct"
else
    fail "Config file path incorrect"
fi

# Test 15: Subscription file path
if grep -q "/home/container/.npm/sub.txt" "$SCRIPT"; then
    pass "Subscription file path correct"
else
    fail "Subscription file path incorrect"
fi

echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo "✅ Passed: $PASS"
echo "❌ Failed: $FAIL"
echo "========================================"

if (( FAIL == 0 )); then
    echo "🎉 All tests passed!"
    exit 0
else
    echo "⚠️  Some tests failed"
    exit 1
fi
