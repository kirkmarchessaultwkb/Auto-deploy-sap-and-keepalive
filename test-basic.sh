#!/bin/bash

# Basic test script for sin-box integration

echo "=== Testing sin-box Integration ==="
echo ""

# Test 1: Check files exist
echo "Test 1: Checking required files..."
files=("start.sh" "index.js" "package.json")
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "✓ $file exists"
    else
        echo "✗ $file missing"
        exit 1
    fi
done
echo ""

# Test 2: Check start.sh syntax
echo "Test 2: Checking start.sh syntax..."
if bash -n start.sh; then
    echo "✓ start.sh syntax OK"
else
    echo "✗ start.sh syntax error"
    exit 1
fi
echo ""

# Test 3: Check index.js syntax
echo "Test 3: Checking index.js syntax..."
if node -c index.js; then
    echo "✓ index.js syntax OK"
else
    echo "✗ index.js syntax error"
    exit 1
fi
echo ""

# Test 4: Check package.json validity
echo "Test 4: Checking package.json validity..."
if cat package.json | python3 -m json.tool > /dev/null 2>&1; then
    echo "✓ package.json valid JSON"
else
    echo "✗ package.json invalid JSON"
    exit 1
fi
echo ""

# Test 5: Check start.sh is executable
echo "Test 5: Checking start.sh permissions..."
if [ -x start.sh ]; then
    echo "✓ start.sh is executable"
else
    echo "✗ start.sh not executable"
    exit 1
fi
echo ""

# Test 6: Verify shebang lines
echo "Test 6: Checking shebang lines..."
if head -1 start.sh | grep -q "#!/bin/bash"; then
    echo "✓ start.sh has correct shebang"
else
    echo "✗ start.sh missing or incorrect shebang"
    exit 1
fi
echo ""

# Test 7: Check for required functions in start.sh
echo "Test 7: Checking required functions in start.sh..."
required_funcs=("install_xray" "install_cloudflared" "install_nezha" "generate_vmess_link" "send_telegram" "monitor_loop")
for func in "${required_funcs[@]}"; do
    if grep -q "^${func}()" start.sh; then
        echo "✓ Function $func found"
    else
        echo "✗ Function $func missing"
        exit 1
    fi
done
echo ""

# Test 8: Check Node.js server endpoints in index.js
echo "Test 8: Checking HTTP endpoints in index.js..."
endpoints=("/health" "SUB_PATH" "/status" "/logs")
for endpoint in "${endpoints[@]}"; do
    if grep -q "$endpoint" index.js; then
        echo "✓ Endpoint $endpoint configured"
    else
        echo "✗ Endpoint $endpoint missing"
        exit 1
    fi
done
echo ""

# Test 9: Check documentation files
echo "Test 9: Checking documentation..."
docs=("README-SINBOX.md" "QUICKSTART-SINBOX.md" ".env.example")
for doc in "${docs[@]}"; do
    if [ -f "$doc" ]; then
        echo "✓ $doc exists"
    else
        echo "✗ $doc missing"
        exit 1
    fi
done
echo ""

# Test 10: Check .gitignore exists
echo "Test 10: Checking .gitignore..."
if [ -f ".gitignore" ]; then
    echo "✓ .gitignore exists"
else
    echo "✗ .gitignore missing"
    exit 1
fi
echo ""

echo "==================================="
echo "✅ All tests passed successfully!"
echo "==================================="
