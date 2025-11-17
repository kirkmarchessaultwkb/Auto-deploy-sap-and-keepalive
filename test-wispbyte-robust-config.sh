#!/bin/bash
# Test script for Wispbyte Robust Config Loading (v1.1.0)

SCRIPT="/home/engine/project/wispbyte-argo-singbox-deploy.sh"
PASS=0
FAIL=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_test() { echo -e "${YELLOW}[TEST]${NC} $1"; }
log_pass() { ((PASS++)); echo -e "${GREEN}[✅ PASS]${NC} $1"; }
log_fail() { ((FAIL++)); echo -e "${RED}[❌ FAIL]${NC} $1"; }

# Test 1: File exists
log_test "1. Script file exists"
[[ -f "$SCRIPT" ]] && log_pass "Script exists" || log_fail "Script not found"

# Test 2: Syntax validation
log_test "2. Bash syntax validation"
bash -n "$SCRIPT" 2>/dev/null && log_pass "Syntax valid" || log_fail "Syntax error"

# Test 3: Line count
log_test "3. Line count (<200)"
lines=$(wc -l < "$SCRIPT")
[[ $lines -lt 200 ]] && log_pass "Line count: $lines" || log_fail "Line count: $lines"

# Test 4: LF line endings only
log_test "4. Line ending verification (LF only)"
if ! grep -q $'\r' "$SCRIPT" 2>/dev/null; then
    log_pass "No CRLF found"
else
    log_fail "CRLF found"
fi

# Test 5: Required functions
log_test "5. Required functions present"
functions=("load_config" "detect_arch" "download_singbox" "download_cloudflared" "generate_singbox_config" "start_singbox" "start_cloudflared" "generate_subscription" "main")
all_found=true
for func in "${functions[@]}"; do
    grep -q "^$func()" "$SCRIPT" || all_found=false
done
$all_found && log_pass "All functions found" || log_fail "Some functions missing"

# Test 6: Environment variable support
log_test "6. Environment variable support (Priority 1)"
grep -q 'CF_DOMAIN="\${CF_DOMAIN:-}"' "$SCRIPT" && \
grep -q 'CF_TOKEN="\${CF_TOKEN:-}"' "$SCRIPT" && \
grep -q 'UUID="\${UUID:-}"' "$SCRIPT" && \
grep -q 'PORT="\${PORT:-27039}"' "$SCRIPT" && \
log_pass "Env vars supported" || log_fail "Env var support incomplete"

# Test 7: Config file fallback
log_test "7. Config file fallback support (Priority 2)"
grep -q 'if \[\[ -z "\$CF_DOMAIN" && -f "\$CONFIG_FILE" \]\]' "$SCRIPT" && \
log_pass "Fallback implemented" || log_fail "Fallback missing"

# Test 8: ARM64 support
log_test "8. Architecture detection (ARM64)"
grep -q 'aarch64|arm64' "$SCRIPT" && log_pass "ARM64 supported" || log_fail "ARM64 missing"

# Test 9: Working directory
log_test "9. Working directory (/home/container/argo-tuic)"
grep -q 'WORK_DIR="/home/container/argo-tuic"' "$SCRIPT" && \
log_pass "Persistent workdir set" || log_fail "Wrong workdir"

# Test 10: Sing-box config
log_test "10. Sing-box listens on 127.0.0.1"
grep -q '"listen": "127.0.0.1"' "$SCRIPT" && \
log_pass "Loopback configured" || log_fail "Listen address wrong"

# Test 11: VMESS-WS protocol
log_test "11. VMESS-WS-TLS protocol"
grep -q '"type": "ws"' "$SCRIPT" && \
grep -q '"path": "/ws"' "$SCRIPT" && \
grep -q '"type": "vmess"' "$SCRIPT" && \
log_pass "Protocol configured" || log_fail "Protocol incomplete"

# Test 12: Subscription generation
log_test "12. Subscription generation"
grep -q 'generate_subscription()' "$SCRIPT" && \
grep -q '/home/container/.npm/sub.txt' "$SCRIPT" && \
log_pass "Subscription implemented" || log_fail "Subscription missing"

# Test 13: Tunnel modes
log_test "13. Fixed + temporary tunnel modes"
grep -q 'Fixed domain:' "$SCRIPT" && \
grep -q 'Temporary tunnel (trycloudflare)' "$SCRIPT" && \
log_pass "Both modes supported" || log_fail "Tunnel modes incomplete"

# Test 14: PID management
log_test "14. PID file management"
grep -q 'echo "\$pid" > "\$WORK_DIR/singbox.pid"' "$SCRIPT" && \
log_pass "PID management implemented" || log_fail "PID management missing"

# Test 15: Logging function
log_test "15. Unified logging function"
grep -q '^log()' "$SCRIPT" && log_pass "Logging present" || log_fail "Logging missing"

# Test 16: Error handling
log_test "16. Error handling"
errors=$(grep -c '|| exit 1' "$SCRIPT" || echo "0")
[[ $errors -gt 3 ]] && log_pass "Error handling present ($errors)" || log_fail "Error handling weak"

# Test 17: Signal handling
log_test "17. Signal handling (SIGTERM/SIGINT)"
grep -q 'trap.*SIGTERM.*SIGINT' "$SCRIPT" && \
log_pass "Signal handlers set" || log_fail "Signal handling missing"

# Test 18: All architectures
log_test "18. Full architecture support (amd64, arm64, arm)"
grep -q 'x86_64|amd64' "$SCRIPT" && \
grep -q 'aarch64|arm64' "$SCRIPT" && \
grep -q 'armv7l|armhf' "$SCRIPT" && \
log_pass "All architectures supported" || log_fail "Some architectures missing"

# Summary
echo ""
echo "=========================================="
echo "Test Results"
echo "=========================================="
echo -e "Passed: ${GREEN}$PASS${NC}"
echo -e "Failed: ${RED}$FAIL${NC}"
echo "Total:  $((PASS + FAIL))"
echo "=========================================="

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
