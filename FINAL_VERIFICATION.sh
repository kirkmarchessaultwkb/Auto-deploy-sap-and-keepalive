#!/bin/bash

echo "================================================"
echo "   FINAL VERIFICATION: start.sh v1.2"
echo "================================================"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASS=0
FAIL=0

check() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ PASS${NC}: $1"
        ((PASS++))
    else
        echo -e "${RED}❌ FAIL${NC}: $1"
        ((FAIL++))
    fi
}

echo "=== 1. Core Files ==="
[ -f "start.sh" ] && [ -x "start.sh" ]
check "start.sh exists and is executable"

[ -f "quick-test-start.sh" ] && [ -x "quick-test-start.sh" ]
check "quick-test-start.sh exists and is executable"

echo ""
echo "=== 2. Documentation Files ==="
[ -f "START_SH_EXPORT_GUIDE.md" ]
check "START_SH_EXPORT_GUIDE.md exists"

[ -f "IMPLEMENTATION_SUMMARY_START_SH_v1.2.md" ]
check "IMPLEMENTATION_SUMMARY_START_SH_v1.2.md exists"

[ -f "COMPARISON_START_SH.md" ]
check "COMPARISON_START_SH.md exists"

[ -f "TASK_COMPLETION_CHECKLIST.md" ]
check "TASK_COMPLETION_CHECKLIST.md exists"

[ -f "TICKET_RESOLUTION_SUMMARY.md" ]
check "TICKET_RESOLUTION_SUMMARY.md exists"

echo ""
echo "=== 3. Code Quality ==="
bash -n start.sh 2>/dev/null
check "start.sh syntax is valid"

grep -q "^#!/bin/bash" start.sh
check "start.sh has correct shebang"

grep -q "set -euo pipefail" start.sh
check "start.sh has strict mode"

grep -q "^export CF_DOMAIN CF_TOKEN UUID PORT" start.sh
check "start.sh exports environment variables"

echo ""
echo "=== 4. Line Count & Endings ==="
LINES=$(wc -l < start.sh)
[ "$LINES" -eq 93 ]
check "start.sh is exactly 93 lines"

[ "$LINES" -lt 150 ]
check "start.sh is under 150 lines"

! grep -q $'\r' start.sh 2>/dev/null
check "start.sh has LF line endings only"

echo ""
echo "=== 5. Required Functions ==="
grep -q "log_info()" start.sh
check "log_info() function exists"

grep -q "log_error()" start.sh
check "log_error() function exists"

echo ""
echo "=== 6. Core Logic ==="
grep -q 'CF_DOMAIN=.*grep.*"cf_domain"' start.sh
check "CF_DOMAIN reading exists"

grep -q 'UUID=.*grep.*"uuid"' start.sh
check "UUID reading exists"

grep -q 'if \[\[ -z "$CF_DOMAIN" || -z "$UUID" \]\]' start.sh
check "Required field validation exists"

grep -q "bash /home/container/wispbyte-argo-singbox-deploy.sh" start.sh
check "Wispbyte script call exists"

echo ""
echo "=== 7. Automated Tests ==="
timeout 10 bash quick-test-start.sh > /tmp/test-output.log 2>&1
TEST_EXIT=$?
[ $TEST_EXIT -eq 0 ]
check "quick-test-start.sh runs successfully"

grep -q "11 / 11 tests passed" /tmp/test-output.log 2>/dev/null
check "All 11 tests passed"

echo ""
echo "================================================"
echo "   VERIFICATION SUMMARY"
echo "================================================"
echo -e "${GREEN}Passed: $PASS${NC}"
echo -e "${RED}Failed: $FAIL${NC}"
echo "================================================"

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✅ ALL VERIFICATIONS PASSED!${NC}"
    echo ""
    echo "🎉 start.sh v1.2 is PRODUCTION READY!"
    echo ""
    echo "Next steps:"
    echo "  1. Review the code and documentation"
    echo "  2. Run: bash quick-test-start.sh"
    echo "  3. Merge to main branch"
    echo "  4. Deploy to production"
    exit 0
else
    echo -e "${RED}❌ SOME VERIFICATIONS FAILED!${NC}"
    exit 1
fi
