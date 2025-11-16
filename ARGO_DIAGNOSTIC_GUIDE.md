# Zampto Diagnostic-Friendly Argo Script (v2.0.0)

## Overview

`argo-diagnostic.sh` is an enhanced version of the Argo tunnel script specifically designed for **troubleshooting and diagnostics**. It provides detailed logging output at every step, making it easy to identify where issues occur during deployment.

**Key difference from v1.0.0**: This version logs EVERYTHING to stdout/stderr, making it suitable for direct execution and immediate visibility of all operations.

## Features

### ✅ Enhanced Logging
- **Timestamp on every log line** - `[YYYY-MM-DD HH:MM:SS]`
- **Clear log levels** - `[INFO]`, `[WARN]`, `[ERROR]`, `[✅ SUCCESS]`
- **Full visibility** - All output goes to stdout/stderr (no suppression)
- **Debug mode** - Set `DEBUG=1` for extra logging
- **Structured output** - Easy to parse and understand

### ✅ Simplified Scope (Focused)
- ✅ Keepalive HTTP server (port 27039)
- ✅ Cloudflared tunnel (fixed or temporary)
- ❌ TUIC installation (removed, optional)
- ❌ Node.js git clone (removed, optional)
- ❌ Nezha monitoring (removed, can be added separately)

### ✅ Better Error Handling
- Continues on non-critical failures
- Shows specific error messages with context
- Displays relevant log file contents on failure
- Clear indication of what succeeded vs. failed

### ✅ Process Management
- Records PID for all services
- Monitors service health during runtime
- Detects unexpected process termination
- Logs warnings for dead processes

### ✅ Service Status Summary
- Final status report showing all running services
- Tunnel URL display
- Work directory location
- Log file locations

## Installation

1. Copy the script to your system:
```bash
cp argo-diagnostic.sh /opt/zampto/argo-diagnostic.sh
chmod +x /opt/zampto/argo-diagnostic.sh
```

2. Or download directly:
```bash
curl -O https://path.to/argo-diagnostic.sh
chmod +x argo-diagnostic.sh
```

## Configuration

### Configuration File
Create `/home/container/config.json` with the following structure:

```json
{
  "CF_DOMAIN": "your-domain.example.com",
  "CF_TOKEN": "your_cloudflare_token",
  "UUID": "12345678-1234-1234-1234-123456789abc",
  "ARGO_PORT": "27039"
}
```

### Required Parameters
- `ARGO_PORT` (default: 27039) - Port for keepalive server

### Optional Parameters
- `CF_DOMAIN` - Fixed domain name for tunnel
- `CF_TOKEN` - Cloudflare credentials
- `UUID` - Service UUID (informational)

### Example Configurations

**Minimal Configuration (Temporary Tunnel)**
```json
{
  "ARGO_PORT": "27039"
}
```

**Fixed Domain Configuration**
```json
{
  "CF_DOMAIN": "zampto.example.com",
  "CF_TOKEN": "accountid:tunnelsecret:tunnelid",
  "ARGO_PORT": "27039"
}
```

## Usage

### Basic Usage

```bash
# Run the diagnostic script
./argo-diagnostic.sh

# Expected output format:
# [2025-11-16 15:30:45] [INFO] Starting Argo Tunnel Setup for Zampto
# [2025-11-16 15:30:45] [INFO] Loading configuration from /home/container/config.json
# ...
```

### Background Execution

```bash
# Run in background with logging
nohup ./argo-diagnostic.sh > /tmp/argo-diagnostic.log 2>&1 &

# Monitor logs in real-time
tail -f /tmp/argo-diagnostic.log
```

### Using Screen Session

```bash
# Create a new screen session
screen -S argo

# Run the script
./argo-diagnostic.sh

# Detach: Ctrl+A then D
# Re-attach: screen -r argo
```

### Debug Mode

```bash
# Enable verbose debugging
DEBUG=1 ./argo-diagnostic.sh

# Shows additional debug-level messages
```

## Output Examples

### Successful Startup

```
[2025-11-16 15:30:45] [INFO] ======================================
[2025-11-16 15:30:45] [INFO] Starting Argo Tunnel Setup for Zampto
[2025-11-16 15:30:45] [INFO] ======================================
[2025-11-16 15:30:45] [INFO]
[2025-11-16 15:30:45] [INFO] Loading configuration from /home/container/config.json...
[2025-11-16 15:30:45] [INFO] Config file found, parsing...
[2025-11-16 15:30:46] [INFO] Configuration loaded:
[2025-11-16 15:30:46] [INFO]   CF_DOMAIN: (not set)
[2025-11-16 15:30:46] [INFO]   CF_TOKEN: (not set)
[2025-11-16 15:30:46] [INFO]   UUID: (not set)
[2025-11-16 15:30:46] [INFO]   ARGO_PORT: 27039

[2025-11-16 15:30:46] [INFO] Setting up working directory: /home/container/argo-tuic
[2025-11-16 15:30:46] [✅ SUCCESS] Working directory created

[2025-11-16 15:30:46] [INFO] Detecting system architecture: x86_64
[2025-11-16 15:30:46] [✅ SUCCESS] Architecture: x86_64 (cloudflared: amd64)

[2025-11-16 15:30:47] [INFO] ====== Starting Keepalive HTTP Server ======
[2025-11-16 15:30:47] [INFO] Target: 127.0.0.1:27039
[2025-11-16 15:30:47] [INFO] Attempting to start with Python3...
[2025-11-16 15:30:49] [✅ SUCCESS] Keepalive server started (PID: 12345)
[2025-11-16 15:30:49] [✅ SUCCESS] Keepalive server is responding to HTTP requests

[2025-11-16 15:30:49] [INFO] ====== Downloading Cloudflared ======
[2025-11-16 15:30:50] [INFO] Fetching latest cloudflared version...
[2025-11-16 15:30:51] [INFO] Latest version: 2024.1.1
[2025-11-16 15:30:51] [INFO] Download URL: https://github.com/cloudflare/...
[2025-11-16 15:30:51] [INFO] Downloading with wget...
[2025-11-16 15:30:55] [✅ SUCCESS] Download completed with wget
[2025-11-16 15:30:55] [✅ SUCCESS] Cloudflared is executable

[2025-11-16 15:30:55] [INFO] ====== Starting Cloudflared Tunnel ======
[2025-11-16 15:30:55] [INFO] No fixed domain config, starting temporary tunnel
[2025-11-16 15:30:55] [INFO] Starting temporary trycloudflare tunnel...
[2025-11-16 15:30:55] [INFO] Command: /home/container/argo-tuic/bin/cloudflared tunnel --url http://127.0.0.1:27039
[2025-11-16 15:30:55] [INFO] Cloudflared PID: 12346
[2025-11-16 15:31:00] [✅ SUCCESS] Cloudflared process is running
[2025-11-16 15:31:00] [✅ SUCCESS] Tunnel URL obtained: https://abc123-xyz789-def456.trycloudflare.com

[2025-11-16 15:31:02] [INFO] ====== Service Status Check ======
[2025-11-16 15:31:02] [✅ SUCCESS] Keepalive server is running (PID: 12345)
[2025-11-16 15:31:02] [✅ SUCCESS] Cloudflared tunnel is running (PID: 12346)
[2025-11-16 15:31:02] [INFO] Tunnel URL: https://abc123-xyz789-def456.trycloudflare.com

[2025-11-16 15:31:02] [INFO] ======================================
[2025-11-16 15:31:02] [INFO] Service Status Summary
[2025-11-16 15:31:02] [INFO] ======================================
[2025-11-16 15:31:02] [INFO] Keepalive Server:
[2025-11-16 15:31:02] [INFO]   Status: ✅ Running (PID: 12345)
[2025-11-16 15:31:02] [INFO]
[2025-11-16 15:31:02] [INFO] Cloudflared Tunnel:
[2025-11-16 15:31:02] [INFO]   Status: ✅ Running (PID: 12346)
[2025-11-16 15:31:02] [INFO]   Tunnel URL: https://abc123-xyz789-def456.trycloudflare.com
[2025-11-16 15:31:02] [INFO]
[2025-11-16 15:31:02] [INFO] Work Directory: /home/container/argo-tuic
[2025-11-16 15:31:02] [INFO] Cloudflared Log: /home/container/argo-tuic/logs/cloudflared.log
[2025-11-16 15:31:02] [INFO] ======================================
[2025-11-16 15:31:02] [✅ SUCCESS] All setup complete! Services should be running.
[2025-11-16 15:31:02] [INFO] Press Ctrl+C to stop.
```

### Error Example

```
[2025-11-16 15:30:47] [INFO] ====== Starting Keepalive HTTP Server ======
[2025-11-16 15:30:47] [INFO] Target: 127.0.0.1:27039
[2025-11-16 15:30:47] [WARN] Python3 unavailable, trying netcat fallback
[2025-11-16 15:30:49] [ERROR] Netcat HTTP server failed
[2025-11-16 15:30:49] [ERROR] Cannot start HTTP server (need python3 or nc)
```

## File Structure

After running `argo-diagnostic.sh`, the following files are created:

```
/home/container/argo-tuic/
├── bin/
│   └── cloudflared              # Cloudflared binary
├── logs/
│   ├── keepalive.log            # Keepalive server log
│   └── cloudflared.log          # Cloudflared tunnel log
├── index.html                   # HTTP server content
├── tunnel.yml                   # Tunnel configuration (if fixed)
├── credentials.json             # Credentials (if fixed)
├── keepalive.pid                # Keepalive PID
├── cloudflared.pid              # Cloudflared PID
└── tunnel.url                   # Tunnel URL
```

## Diagnostics

### Checking Service Status

```bash
# Check if services are running
ps aux | grep -E "(cloudflared|python3.*http)" | grep -v grep

# Check keepalive PID
cat /home/container/argo-tuic/keepalive.pid

# Check cloudflared PID
cat /home/container/argo-tuic/cloudflared.pid

# Check tunnel URL
cat /home/container/argo-tuic/tunnel.url
```

### Viewing Logs

```bash
# Keepalive server log
tail -f /home/container/argo-tuic/logs/keepalive.log

# Cloudflared tunnel log
tail -f /home/container/argo-tuic/logs/cloudflared.log

# Script execution log (if redirected)
tail -f /tmp/argo-diagnostic.log
```

### Testing Connectivity

```bash
# Test keepalive HTTP server
curl -v http://127.0.0.1:27039/

# Test tunnel (if available)
curl -v https://your-tunnel-url.trycloudflare.com/
```

## Troubleshooting

### Issue: "No keepalive server output"
**Solution**: The script now logs everything. Check for:
- Missing `/home/container/config.json` (will warn but continue)
- Port 27039 already in use (check with `netstat -tlnp | grep 27039`)
- Neither python3 nor nc available (install one)

### Issue: "Cloudflared not downloading"
**Solution**:
- Check internet connectivity: `curl -I https://github.com`
- Check GitHub API rate limit
- Manually download and place at `/home/container/argo-tuic/bin/cloudflared`

### Issue: "Tunnel URL not showing"
**Solution**:
- Give cloudflared more time to establish connection (wait 10+ seconds)
- Check cloudflared log: `tail -50 /home/container/argo-tuic/logs/cloudflared.log`
- Verify network connectivity to Cloudflare

### Issue: "Services stopped unexpectedly"
**Solution**:
- Script monitors and logs this every 60 seconds
- Check logs for error messages
- Manually restart: `./argo-diagnostic.sh`

## Comparison: v1.0.0 vs v2.0.0

| Feature | v1.0.0 | v2.0.0 |
|---------|--------|--------|
| **Logging** | Colored logs | Enhanced with timestamps |
| **Output Visibility** | May be suppressed | Always visible |
| **Scope** | Full (TUIC, Node.js) | Simplified (core only) |
| **Error Handling** | Basic | Detailed with context |
| **Debug Mode** | No | Yes (DEBUG=1) |
| **Health Monitoring** | Every 60s | Every 60s |
| **Documentation** | Good | Excellent |
| **Diagnostics** | Good | Excellent |

## Performance

- **Memory**: ~50MB (keepalive + cloudflared)
- **CPU**: <2% idle
- **Startup time**: 10-15 seconds
- **Network**: Minimal overhead

## Security Notes

- Config file should have restricted permissions: `chmod 600 /home/container/config.json`
- Sensitive values (tokens) are masked in log output when possible
- Tunnel uses HTTPS encryption
- Keepalive server only listens on 127.0.0.1 (localhost)

## Integration with Zampto

The script is designed to run as part of zampto's startup process:

```bash
# In your zampto start script:
./argo-diagnostic.sh &
ARGO_PID=$!

# Later, to stop:
kill $ARGO_PID
```

## FAQ

**Q: Can I use this with the original argo.sh?**
A: No, they serve different purposes. Use v2.0.0 for diagnostics.

**Q: Does it support fixed domains?**
A: Yes, if `CF_DOMAIN` and `CF_TOKEN` are set in config.json.

**Q: Can I customize the log directory?**
A: Yes, modify the `LOG_DIR` variable at the top of the script.

**Q: What if Python3 is not available?**
A: It automatically falls back to netcat (nc). One of them must be available.

**Q: How do I stop the script?**
A: Press Ctrl+C or `kill <PID>`

## Support

For issues or questions:
1. Run with `DEBUG=1` for extra logging
2. Check the cloudflared log for tunnel issues
3. Verify config.json is valid JSON
4. Check network connectivity

## Version History

### v2.0.0 (Current)
- ✅ Complete rewrite for diagnostics
- ✅ Enhanced logging with timestamps
- ✅ Simplified to core functionality
- ✅ Better error messages
- ✅ Debug mode support

### v1.0.0
- Original version with full features

---

**Note**: This script is optimized for troubleshooting and diagnostics. For production use with additional features, consider v1.0.0.
