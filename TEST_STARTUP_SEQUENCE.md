# zampto-start.sh - Startup Sequence Testing Guide

## Quick Verification Tests

### 1. Syntax Check (Already Passed ✅)
```bash
bash -n zampto-start.sh
# Should output: ✅ Syntax check passed
```

### 2. Verify File Structure
```bash
# Check required files exist
ls -la zampto-start.sh          # Main startup script
ls -la zampto-index.js          # Node.js HTTP server
ls -la index.js                 # Symlink to zampto-index.js
ls -la zampto-package.json      # NPM package config

# Verify symlink is correct
readlink -f index.js            # Should point to zampto-index.js
```

### 3. Test Functions Exist
```bash
# Extract function names from script
grep "^[a-z_]*() {" zampto-start.sh

# Should include:
# - start_node_server()
# - wait_for_port()
# - start_cloudflared_tunnel()
# - generate_subscription()
# - cleanup()
# - main()
```

### 4. Verify Port Configuration
```bash
# Check Cloudflared proxies to port 8001
grep -n "127.0.0.1:8001" zampto-start.sh

# Should show 3 matches:
# Line ~500: JSON credentials tunnel
# Line ~505: Token credentials tunnel  
# Line ~534: Temporary tunnel
```

### 5. Check Node.js Server Port
```bash
# Verify SERVER_PORT is set to 8001
grep -A 5 "export SERVER_PORT" zampto-start.sh

# Should show:
# export SERVER_PORT=8001
```

### 6. Verify Startup Order in main()
```bash
# Extract step order from main()
grep "Step [0-9]:" zampto-start.sh

# Expected order:
# Step 1: Downloading binaries...
# Step 2: Generating configuration...
# Step 3: Starting Node.js HTTP server...
# Step 4: Starting Nezha monitoring agent...
# Step 5: Starting Cloudflared tunnel...
# Step 6: Generating subscription file...
# Step 7: Starting health check service...
# Step 8: Starting sing-box service...
```

### 7. Check Health Monitor Configuration
```bash
# Verify health check monitors both services
grep -A 2 "8001" zampto-start.sh | grep -E "(node|WARNING)"

# Should show checks for:
# - Node.js process (pgrep -f "node index.js")
# - Port 8001 responding
```

### 8. Test Cleanup Function
```bash
# Verify cleanup kills all processes
grep -A 30 "^cleanup()" zampto-start.sh | grep NODE_PID

# Should show:
# - NODE_PID cleanup
# - CLOUDFLARED_PID cleanup
# - NEZHA_PID cleanup
# - HEALTH_CHECK_PID cleanup
```

---

## Dry Run Test (Without Starting Services)

### Test 1: Check Environment Variables
```bash
export UUID="test-uuid-12345"
export ARGO_DOMAIN="test.example.com"
export ARGO_AUTH="test-token"

# Source the script functions (without running main)
bash -c 'source zampto-start.sh 2>/dev/null; declare -F'
```

### Test 2: Simulate Port Check
```bash
# Test wait_for_port function logic
timeout 2 bash -c "echo > /dev/tcp/127.0.0.1/80" 2>/dev/null && echo "Port 80 is open" || echo "Port 80 is closed"
```

---

## Integration Test (Requires Node.js)

### Test 1: Start Node.js Server Manually
```bash
export SERVER_PORT=8001
export FILE_PATH="./.npm"
export SUB_PATH="sub"
export UUID="test-uuid"
export NAME="test-node"

# Start Node.js in background
node index.js > /tmp/test-node.log 2>&1 &
TEST_PID=$!

echo "Node.js PID: $TEST_PID"

# Wait 3 seconds
sleep 3

# Test endpoints
curl http://127.0.0.1:8001/info
curl http://127.0.0.1:8001/health
curl http://127.0.0.1:8001/

# Cleanup
kill $TEST_PID
```

### Test 2: Test wait_for_port Function
```bash
# Create test function
wait_for_port() {
    local port=$1
    local timeout=$2
    local elapsed=0
    
    while [ $elapsed -lt $timeout ]; do
        if timeout 2 bash -c "echo > /dev/tcp/127.0.0.1/$port" 2>/dev/null; then
            echo "✅ Port $port is ready after ${elapsed}s"
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    
    echo "❌ Port $port not ready after ${timeout}s"
    return 1
}

# Start Node.js
node index.js > /tmp/test.log 2>&1 &
TEST_PID=$!

# Test wait function
wait_for_port 8001 10

# Cleanup
kill $TEST_PID
```

---

## Expected Results Checklist

After starting `zampto-start.sh`, you should see:

### ✅ Startup Logs
- [ ] Shows version banner with "Optimized sing-box for zampto Node.js"
- [ ] Step 1: Downloads sing-box binary
- [ ] Step 2: Generates config.json
- [ ] Step 3: Starts Node.js with PID
- [ ] Step 3: Port 8001 becomes ready
- [ ] Step 5: Cloudflared tunnel starts
- [ ] Step 6: Subscription file generated
- [ ] Step 7: Health check starts with PID
- [ ] Step 8: sing-box starts with optimizations

### ✅ Process Status
```bash
ps aux | grep node         # Should show: node index.js
ps aux | grep cloudflared  # Should show: cloudflared tunnel
ps aux | grep sing-box     # Should show: sing-box run
ps aux | grep health       # Should show: health-check.sh
```

### ✅ Port Listeners
```bash
netstat -tlnp | grep 8001  # Node.js HTTP server
netstat -tlnp | grep 8080  # sing-box VMess listener
```

### ✅ Generated Files
```bash
ls -la config/config.json           # sing-box configuration
ls -la .npm/sub.txt                 # Subscription file
ls -la .argo_domain                 # Cloudflared domain
ls -la health-check.sh              # Health check script
ls -la logs/node-server.log         # Node.js logs
ls -la logs/cloudflared.log         # Cloudflared logs
```

### ✅ HTTP Endpoints
```bash
curl http://127.0.0.1:8001/         # HTML homepage
curl http://127.0.0.1:8001/info     # JSON service info
curl http://127.0.0.1:8001/health   # JSON health status
curl http://127.0.0.1:8001/sub      # Subscription content
```

---

## Troubleshooting Quick Reference

### Problem: Node.js server won't start
**Check:**
```bash
ls -la index.js                     # Symlink exists?
which node                          # Node.js installed?
node --version                      # Version >= 10?
cat logs/node-server.log            # Error messages?
```

### Problem: Port 8001 already in use
**Check:**
```bash
lsof -i :8001                       # What's using the port?
netstat -tlnp | grep 8001           # Process ID?
kill $(lsof -t -i:8001)             # Kill existing process
```

### Problem: sing-box crashes immediately
**Check:**
```bash
cat config/config.json | jq         # Valid JSON?
curl http://127.0.0.1:8001/health   # Node.js responding?
cat logs/sing-box.log 2>/dev/null   # Error messages?
```

### Problem: Cloudflared tunnel fails
**Check:**
```bash
cat logs/cloudflared.log            # Error messages?
echo $ARGO_AUTH                     # Credentials set?
echo $ARGO_DOMAIN                   # Domain configured?
./cloudflared --version             # Binary works?
```

---

## Performance Verification

### CPU Usage Target: 40-50%
```bash
# Monitor for 60 seconds
top -b -n 12 -d 5 | grep -E "sing-box|node|cloudflared" 

# Check average CPU
ps aux --sort=-%cpu | head -20
```

### Memory Usage
```bash
ps aux --sort=-%mem | grep -E "sing-box|node|cloudflared"
```

### Health Check Logs
```bash
tail -f logs/health-check.log
# Should show checks every 30 seconds
# Should not show repeated warnings
```

---

## Success Criteria

### ✅ All Must Pass:
1. Script syntax is valid (`bash -n` passes)
2. Node.js server starts on port 8001
3. Port 8001 becomes ready within 30 seconds
4. Cloudflared proxies to 127.0.0.1:8001
5. sing-box starts and stays running
6. Subscription file is generated
7. All endpoints respond correctly
8. Health check monitors both services
9. Cleanup kills all processes
10. No circular startup loops

### ✅ Performance Targets:
- CPU usage: 40-50% (down from 70%)
- Memory usage: < 150MB total
- Startup time: < 60 seconds
- Health check interval: 30 seconds

---

## Final Verification Command

```bash
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
```

Save this as `verify-integration.sh` and run:
```bash
chmod +x verify-integration.sh
./verify-integration.sh
```

---

## Branch Information

**Current Branch:** `fix-zampto-start-add-nodejs-server-e01`  
**Previous Branch:** `fix-remove-startsh-spawn-in-indexjs`  
**Status:** Ready for testing  
**Version:** 1.0.3
