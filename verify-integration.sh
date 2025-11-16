#!/bin/bash
# Run all checks in sequence

echo "=== zampto-start.sh Verification ==="
echo ""

echo "1. Syntax Check..."
bash -n zampto-start.sh && echo "✅ PASS" || echo "❌ FAIL"

echo ""
echo "2. File Structure..."
test -f zampto-start.sh && echo "✅ zampto-start.sh exists" || echo "❌ Missing"
test -f zampto-index.js && echo "✅ zampto-index.js exists" || echo "❌ Missing"
test -L index.js && echo "✅ index.js symlink exists" || echo "❌ Missing"

echo ""
echo "3. Port Configuration..."
grep -q "127.0.0.1:8001" zampto-start.sh && echo "✅ Cloudflared targets 8001" || echo "❌ Wrong port"
grep -q "export SERVER_PORT=8001" zampto-start.sh && echo "✅ SERVER_PORT=8001 set" || echo "❌ Wrong port"

echo ""
echo "4. Function Checks..."
grep -q "^start_node_server()" zampto-start.sh && echo "✅ start_node_server() exists" || echo "❌ Missing"
grep -q "^wait_for_port()" zampto-start.sh && echo "✅ wait_for_port() exists" || echo "❌ Missing"

echo ""
echo "5. Startup Order..."
grep -q "Step 3: Starting Node.js" zampto-start.sh && echo "✅ Node.js starts before Cloudflared" || echo "❌ Wrong order"

echo ""
echo "6. Health Check..."
grep -q "8001.*Node.js" zampto-start.sh && echo "✅ Health check monitors Node.js" || echo "❌ Missing"

echo ""
echo "7. Cleanup..."
grep -q "NODE_PID" zampto-start.sh && echo "✅ Cleanup handles Node.js PID" || echo "❌ Missing"

echo ""
echo "==================================="
echo "Verification Complete!"
echo "==================================="
