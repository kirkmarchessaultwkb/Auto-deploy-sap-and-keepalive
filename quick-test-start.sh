#!/bin/bash

# Quick verification test for start.sh

echo "=========================================="
echo "Quick Test: start.sh Config Export"
echo "=========================================="
echo ""

SUCCESS=0
TOTAL=0

test_check() {
    ((TOTAL++))
    if [ $1 -eq 0 ]; then
        echo "✅ PASS: $2"
        ((SUCCESS++))
    else
        echo "❌ FAIL: $2"
    fi
}

# Test 1: Syntax check
bash -n start.sh
test_check $? "Syntax validation"

# Test 2: Check export statement
grep -q "export CF_DOMAIN CF_TOKEN UUID PORT NEZHA_SERVER NEZHA_PORT NEZHA_KEY" start.sh
test_check $? "Environment variables exported"

# Test 3: Check config reading
grep -q 'CF_DOMAIN=.*grep.*"cf_domain"' start.sh
test_check $? "CF_DOMAIN reading present"

grep -q 'UUID=.*grep.*"uuid"' start.sh
test_check $? "UUID reading present"

# Test 4: Check validation
grep -q 'if \[\[ -z "$CF_DOMAIN" || -z "$UUID" \]\]' start.sh
test_check $? "Required fields validation"

# Test 5: Check defaults
grep -q 'PORT=\${PORT:-27039}' start.sh
test_check $? "PORT default value"

# Test 6: Check wispbyte call
grep -q "bash /home/container/wispbyte-argo-singbox-deploy.sh" start.sh
test_check $? "Wispbyte script call"

# Test 7: Check non-blocking Nezha
grep -q "non-blocking, continuing" start.sh
test_check $? "Nezha non-blocking on failure"

# Test 8: Line count
LINE_COUNT=$(wc -l < start.sh)
if [ "$LINE_COUNT" -lt 150 ]; then
    test_check 0 "Line count: $LINE_COUNT (< 150)"
else
    test_check 1 "Line count: $LINE_COUNT (< 150)"
fi

# Test 9: LF line endings
CRLF=$(grep -c $'\r' start.sh 2>/dev/null || echo 0)
test_check $CRLF "No CRLF (found: $CRLF)"

# Test 10: Critical keywords present
grep -q "set -euo pipefail" start.sh
test_check $? "Strict mode enabled"

echo ""
echo "=========================================="
echo "Results: $SUCCESS / $TOTAL tests passed"
echo "=========================================="

if [ $SUCCESS -eq $TOTAL ]; then
    echo "✅ ALL TESTS PASSED!"
    exit 0
else
    echo "❌ SOME TESTS FAILED!"
    exit 1
fi
