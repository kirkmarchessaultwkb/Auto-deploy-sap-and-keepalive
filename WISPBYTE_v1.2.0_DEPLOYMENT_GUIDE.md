# Wispbyte v1.2.0 - Deployment Guide

## 📋 Quick Summary

**Version**: 1.2.0 (Released: 2025-01-15)  
**Status**: ✅ Production Ready  
**Key Improvements**: GitHub API version detection, corrected download URLs, reliable deployment  
**Line Count**: 233 lines (efficient, <250 target)  

---

## 🎯 What's New in v1.2.0

### 1. **Corrected Download URLs** ✅
Previous versions used `/releases/latest/download/` which could break. v1.2.0:
- Uses GitHub API to detect latest version
- Constructs explicit download URLs with version
- More reliable, no broken links
- Falls back to fallback version if API fails

**Example**:
```bash
# OLD (unreliable):
https://github.com/SagerNet/sing-box/releases/latest/download/sing-box-linux-amd64.tar.gz

# NEW (reliable):
https://github.com/SagerNet/sing-box/releases/download/v1.9.0/sing-box-1.9.0-linux-amd64.tar.gz
```

### 2. **Automatic Architecture Detection** ✅
- Detects: amd64, arm64, armv7
- Supported: x86_64, aarch64, armv7l, armhf
- Error handling for unsupported architectures

### 3. **Dual-Priority Configuration** ✅
```bash
Priority 1: Environment variables (from start.sh)
Priority 2: config.json file (if env vars empty)
```

### 4. **Robust Service Management** ✅
- Health checks with PID verification
- Non-blocking startup (continues even if optional services fail)
- Comprehensive logging with timestamps
- Signal handling (SIGTERM, SIGINT)

### 5. **Complete Subscription Support** ✅
- VMess protocol with WebSocket transport
- TLS encryption enabled
- SNI (Server Name Indication)
- Chrome fingerprint for better compatibility
- Double base64 encoding for subscription file

---

## 📦 Installation & Setup

### Prerequisites

```bash
# Required tools
- bash 4.0+
- curl (for downloads and GitHub API)
- tar (for extraction)
- grep, sed, cut (for text processing)

# OS Support
- Linux (any architecture: x86_64, ARM64, ARM32)
- Requires write access to /home/container/
```

### Step 1: Deploy the Script

```bash
# Copy the script to your deployment location
cp wispbyte-argo-singbox-deploy.sh /home/container/

# Or if using with start.sh v1.2:
# start.sh will call it automatically
```

### Step 2: Prepare Configuration

**Option A: Using start.sh v1.2** (Recommended)
```bash
# Create config.json
cat > /home/container/config.json <<EOF
{
  "cf_domain": "your-domain.tunnels.cloudflare.com",
  "cf_token": "your-tunnel-token",
  "uuid": "550e8400-e29b-41d4-a716-446655440000",
  "port": "27039"
}
EOF

# start.sh v1.2 will:
# 1. Load config.json
# 2. Export environment variables
# 3. Call wispbyte-argo-singbox-deploy.sh
bash /home/container/start.sh
```

**Option B: Direct Execution**
```bash
# Set environment variables
export CF_DOMAIN="your-domain.tunnels.cloudflare.com"
export CF_TOKEN="your-tunnel-token"
export UUID="550e8400-e29b-41d4-a716-446655440000"
export PORT="27039"

# Run the script
bash /home/container/wispbyte-argo-singbox-deploy.sh
```

**Option C: Using config.json Only**
```bash
# Create config.json (no env vars needed)
cat > /home/container/config.json <<EOF
{
  "cf_domain": "your-domain.tunnels.cloudflare.com",
  "cf_token": "your-tunnel-token",
  "uuid": "550e8400-e29b-41d4-a716-446655440000",
  "port": "27039"
}
EOF

# Run the script (will read from config.json)
bash /home/container/wispbyte-argo-singbox-deploy.sh
```

---

## ⚙️ Configuration Parameters

### Required Parameters

| Parameter | Type | Example | Description |
|-----------|------|---------|-------------|
| `CF_DOMAIN` | String | `tunnel.example.com` | Your Cloudflare tunnel domain |
| `UUID` | UUID | `550e8400-e29b-41d4-a716-446655440000` | VMess user UUID (36 chars with hyphens) |

### Optional Parameters

| Parameter | Default | Example | Description |
|-----------|---------|---------|-------------|
| `CF_TOKEN` | (empty) | `ey...` | Cloudflare tunnel token (for fixed domain) |
| `PORT` | `27039` | `27039` | Sing-box listening port |

### Configuration File Format (config.json)

```json
{
  "cf_domain": "tunnel.example.com",
  "cf_token": "tunnel_token_here",
  "uuid": "550e8400-e29b-41d4-a716-446655440000",
  "port": "27039"
}
```

---

## 🚀 Usage Examples

### Example 1: Full Deployment with start.sh v1.2

```bash
# 1. Create configuration
mkdir -p /home/container
cat > /home/container/config.json <<'EOF'
{
  "cf_domain": "my-proxy.tunnels.cloudflare.com",
  "cf_token": "eyJhbGc...",
  "uuid": "550e8400-e29b-41d4-a716-446655440000",
  "port": "27039"
}
EOF

# 2. Run start.sh (which calls wispbyte internally)
bash /home/container/start.sh

# 3. Verify deployment
ps aux | grep -E "sing-box|cloudflared"
cat /home/container/.npm/sub.txt | base64 -d | base64 -d | head -c 100
```

### Example 2: Direct Deployment

```bash
# 1. Export configuration
export CF_DOMAIN="my-proxy.tunnels.cloudflare.com"
export CF_TOKEN="eyJhbGc..."
export UUID="550e8400-e29b-41d4-a716-446655440000"
export PORT="27039"

# 2. Run wispbyte
bash /home/container/wispbyte-argo-singbox-deploy.sh

# 3. Watch deployment logs
tail -f /home/container/argo-tuic/deploy.log
```

### Example 3: Temporary Tunnel (No Fixed Domain)

```bash
# 1. Create minimal config
cat > /home/container/config.json <<'EOF'
{
  "cf_domain": "",
  "cf_token": "",
  "uuid": "550e8400-e29b-41d4-a716-446655440000",
  "port": "27039"
}
EOF

# 2. Run (will use temporary trycloudflare.com domain)
bash /home/container/wispbyte-argo-singbox-deploy.sh

# 3. Extract temporary domain from logs
grep "trycloudflare.com" /home/container/argo-tuic/cloudflared.log
```

---

## 📊 Deployment Output

### Successful Deployment Log

```
========================================
Wispbyte Argo Sing-box Deploy v1.2.0
========================================
[14:30:45] [INFO] Loading configuration...
[14:30:45] [INFO] Configuration: Domain=my-proxy.tunnels.cloudflare.com, UUID=550e8400-e29b-41d4-a716-446655440000, Port=27039
[14:30:46] [INFO] Downloading sing-box...
[14:30:46] [INFO] Sing-box URL: https://github.com/SagerNet/sing-box/releases/download/v1.9.0/sing-box-1.9.0-linux-amd64.tar.gz
[14:30:48] [INFO] [OK] Sing-box ready
[14:30:48] [INFO] Downloading cloudflared...
[14:30:48] [INFO] Cloudflared URL: https://github.com/cloudflare/cloudflared/releases/download/2024.6.1/cloudflared-linux-amd64
[14:30:50] [INFO] [OK] Cloudflared ready
[14:30:50] [INFO] Generating sing-box config...
[14:30:50] [INFO] [OK] Config generated
[14:30:50] [INFO] Starting sing-box on 127.0.0.1:27039...
[14:30:52] [INFO] [OK] Sing-box started (PID: 12345)
[14:30:52] [INFO] Starting cloudflared tunnel...
[14:30:52] [INFO] Fixed domain: my-proxy.tunnels.cloudflare.com
[14:30:55] [INFO] [OK] Cloudflared started (PID: 12346)
[14:30:55] [INFO] Generating VMESS subscription...
[14:30:55] [INFO] [OK] Subscription generated: https://my-proxy.tunnels.cloudflare.com/sub
========================================
[14:30:55] [INFO] [SUCCESS] Deployment completed
[14:30:55] [INFO] [SINGBOX] PID: 12345
[14:30:55] [INFO] [CLOUDFLARED] PID: 12346
[14:30:55] [INFO] [LOGS] /home/container/argo-tuic
========================================
```

---

## 🔍 Verification & Troubleshooting

### Verification Checklist

```bash
# 1. Check service status
ps aux | grep "sing-box\|cloudflared" | grep -v grep
# Expected: 2 processes running

# 2. Check binaries
ls -la /home/container/argo-tuic/bin/
# Expected: sing-box and cloudflared files with execute permission

# 3. Check configuration
cat /home/container/argo-tuic/config.json
# Expected: Valid JSON with your UUID and port

# 4. Check subscription file
cat /home/container/.npm/sub.txt | base64 -d | base64 -d
# Expected: JSON with your configuration

# 5. Check logs
tail -50 /home/container/argo-tuic/deploy.log
# Expected: [SUCCESS] messages, no [ERROR] messages
```

### Troubleshooting

#### Issue: "Sing-box download failed"
```bash
# Check network connectivity
curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | head -20

# Check architecture support
uname -m  # Should be: x86_64, aarch64, or armv7l

# Check disk space
df -h /home/container
```

#### Issue: "Cloudflared download failed"
```bash
# Check network connectivity
curl -s https://api.github.com/repos/cloudflare/cloudflared/releases/latest | head -20

# Check if binary can be executed
/home/container/argo-tuic/bin/cloudflared --version

# Check binary format
file /home/container/argo-tuic/bin/cloudflared
# Expected: ELF 64-bit binary
```

#### Issue: "Sing-box failed to start"
```bash
# Check configuration
cat /home/container/argo-tuic/config.json | jq .

# Check if port is already in use
netstat -tlnp | grep :27039

# Check startup logs
cat /home/container/argo-tuic/singbox.log

# Try running manually (for debugging)
/home/container/argo-tuic/bin/sing-box run -c /home/container/argo-tuic/config.json
```

#### Issue: "No domain found for subscription"
```bash
# Check if CF_DOMAIN is set
echo $CF_DOMAIN

# Check if using temporary tunnel
tail -20 /home/container/argo-tuic/cloudflared.log | grep -E "https://.*cloudflare"

# Wait a bit for tunnel to establish
sleep 5
grep "https://" /home/container/argo-tuic/cloudflared.log | tail -1
```

---

## 📁 File Structure

```
/home/container/
├── config.json                      # Configuration file
├── wispbyte-argo-singbox-deploy.sh # Main deployment script
├── .npm/
│   └── sub.txt                     # Subscription file (double base64 encoded)
└── argo-tuic/                      # Working directory
    ├── bin/
    │   ├── sing-box               # Sing-box binary
    │   └── cloudflared            # Cloudflared binary
    ├── config.json                # Sing-box configuration
    ├── singbox.log                # Sing-box logs
    ├── cloudflared.log            # Cloudflared tunnel logs
    ├── deploy.log                 # Deployment logs
    ├── singbox.pid                # Sing-box process ID
    └── cloudflared.pid            # Cloudflared process ID
```

---

## 🔐 Security Considerations

1. **UUID Management**
   - Generate secure UUID: `python3 -c "import uuid; print(uuid.uuid4())"`
   - Keep UUID secret, don't share with untrusted users
   - One UUID per user is recommended

2. **Token Security**
   - CF_TOKEN should be stored securely
   - Use environment variables or secure configuration
   - Never commit tokens to version control

3. **TLS/Encryption**
   - All connections use TLS encryption
   - SNI enabled for domain blocking bypass
   - Chrome fingerprint for better compatibility

4. **Port Management**
   - Default port 27039 is internal (127.0.0.1 only)
   - Cloudflared handles external exposure
   - Firewall rules not needed (localhost only)

---

## 📊 Performance

### Resource Usage

| Component | Memory | CPU | Disk |
|-----------|--------|-----|------|
| Sing-box | ~20-50 MB | 2-5% | ~50 MB (binary) |
| Cloudflared | ~10-30 MB | 1-3% | ~30 MB (binary) |
| Total | ~30-80 MB | 3-8% | ~80 MB |

### Network Usage

- ~100 KB/s per connected client
- Bandwidth depends on usage pattern
- No bandwidth overhead from Argo tunnel

### Optimization Tips

```bash
# Increase health check interval (reduce CPU)
# Edit cloudflared command in start_cloudflared function

# Reduce log level (reduce CPU/disk)
# Change "level": "info" to "level": "warning" in config.json

# Limit connections
# Add -c flag to cloudflared command
```

---

## 🔄 Integration with Other Services

### Integration with start.sh v1.2

```bash
# start.sh v1.2 workflow:
# 1. Load config.json
# 2. Read 7 parameters (CF_DOMAIN, CF_TOKEN, UUID, PORT, NEZHA_*, etc)
# 3. Export all variables
# 4. Call wispbyte-argo-singbox-deploy.sh
# 5. Wispbyte receives all exported vars as Priority 1
# 6. Falls back to config.json if needed (Priority 2)

# Result: Flexible deployment that works standalone or integrated
```

### Integration with Nezha Monitoring

```bash
# start.sh v1.2 can also start Nezha agent
# Both services run in parallel:
# - Nezha agent: Monitors system resources
# - Sing-box + Cloudflared: Handles traffic

# Nezha integration is optional and non-blocking
```

---

## 📚 Related Documentation

- **start.sh v1.2**: Configuration loading and startup orchestration
- **argo-diagnostic.sh**: Diagnostic tool for Argo tunnel troubleshooting
- **VMess Protocol**: https://v2fly.org/en_US/guide/protocols.html#vmess
- **Sing-box Documentation**: https://sing-box.sagernet.org/
- **Cloudflare Tunnel**: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/

---

## ✅ Production Checklist

Before deploying to production:

- [ ] Configuration file is valid JSON
- [ ] UUID is in correct format (36 characters with hyphens)
- [ ] CF_DOMAIN is set (or will use temporary tunnel)
- [ ] Port 27039 is not blocked by firewall
- [ ] /home/container has write access
- [ ] Network connectivity to api.github.com is available
- [ ] Architecture is supported (amd64, arm64, armv7)
- [ ] Cloudflare tunnel is properly configured
- [ ] Test with local client before production use

---

## 📞 Support

### Getting Logs for Debugging

```bash
# Collect all relevant logs
mkdir -p /tmp/wispbyte-debug
cp /home/container/argo-tuic/{deploy.log,singbox.log,cloudflared.log} /tmp/wispbyte-debug/

# Check configuration
cp /home/container/config.json /tmp/wispbyte-debug/

# System information
uname -a > /tmp/wispbyte-debug/system.txt
echo "=== Processes ===" >> /tmp/wispbyte-debug/system.txt
ps aux | grep -E "sing-box|cloudflared" >> /tmp/wispbyte-debug/system.txt

# Compress for sharing
tar -czf /tmp/wispbyte-debug.tar.gz /tmp/wispbyte-debug/
```

### Common Questions

**Q: Can I use this without Cloudflare Tunnel?**  
A: No, Cloudflared tunnel is required to expose the sing-box service.

**Q: Can I use multiple UUIDs?**  
A: Not in current implementation. One UUID per instance.

**Q: Is it compatible with existing VMess clients?**  
A: Yes, any VMess client supporting WebSocket+TLS can connect.

**Q: Can I change the port?**  
A: Yes, modify `PORT` in config.json or environment variable.

**Q: How often does it check for new versions?**  
A: Only during startup. Binaries are not auto-updated.

---

## 📝 Version History

- **v1.2.0** (2025-01-15): Corrected downloads with GitHub API version detection
- **v1.1.0** (2025-01-14): Robust config loading with dual-priority mechanism
- **v1.0.0** (2025-01-10): Initial simplified version

---

## 📄 License

This project uses open-source components:
- [Sing-box](https://github.com/SagerNet/sing-box) - GPLv3
- [Cloudflared](https://github.com/cloudflare/cloudflared) - Apache 2.0

Deployment scripts are provided as-is for integration with Zampto platform.

