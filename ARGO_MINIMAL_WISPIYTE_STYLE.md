# Minimal Argo.sh for Zampto (wispbyte style)

## Overview

This is a minimal, wispbyte-style `argo.sh` script for zampto that focuses on simplicity and reliability. It only does two things:
1. **Keepalive HTTP Server** - Runs on port 27039 (or configured port)
2. **Cloudflared Tunnel** - Tunnels the HTTP server to Cloudflare

## Key Features

### ✅ Design Principles
- **Simple**: 144 lines of code, easy to read and maintain
- **Clear**: Straightforward logic with minimal complexity
- **Reliable**: Based on wispbyte's proven approach
- **LF Line Endings**: 0 CRLF characters, pure LF line endings

### ✅ Core Functionality
1. **Configuration Loading**: Reads from `/home/container/config.json`
   - Supports: `CF_DOMAIN`, `CF_TOKEN`, `ARGO_PORT`
   - Simple JSON parsing without jq dependency
   - Graceful fallback to defaults if config missing

2. **Keepalive HTTP Server**:
   - Port: 27039 (or `ARGO_PORT` from config)
   - Uses `python3 -m http.server`
   - Binds to `127.0.0.1` for security
   - Simple HTML page with server status

3. **Cloudflared Tunnel**:
   - Auto-detects architecture (amd64, arm64, arm)
   - Downloads latest cloudflared binary
   - Supports both fixed domain and temporary tunnels
   - Fixed domain: `https://your-domain.com`
   - Temporary: `https://random.trycloudflare.com`

## Usage

### Basic Usage
```bash
chmod +x argo.sh
./argo.sh
```

### Configuration
Create `/home/container/config.json`:
```json
{
  "CF_DOMAIN": "your-domain.com",
  "CF_TOKEN": "AccountTag:TunnelSecret:TunnelID",
  "ARGO_PORT": "27039"
}
```

### Output Example
```
[INFO] Starting minimal Argo tunnel setup...
[INFO] WORKDIR: /tmp/argo-zampto
[INFO] PORT: 27039
[INFO] Loading configuration from /home/container/config.json
[INFO] CF_DOMAIN: your-domain.com
[INFO] Downloading cloudflared...
[INFO] Architecture: x86_64 (cloudflared: amd64)
[INFO] Cloudflared downloaded successfully
[INFO] Starting keepalive on port 27039...
[INFO] Keepalive PID: 12345
[INFO] Starting cloudflared tunnel...
[INFO] Starting fixed domain tunnel: your-domain.com
[INFO] Fixed domain tunnel started (PID: 12346)
[INFO] Tunnel URL: https://your-domain.com
[INFO] =======================================
[INFO] Setup completed successfully
[INFO] Keepalive server: PID 12345 (port 27039)
[INFO] Cloudflared tunnel: PID 12346
[INFO] =======================================
[INFO] Services are running. Press Ctrl+C to stop.
```

## File Structure

```
/tmp/argo-zampto/
├── cloudflared          # Downloaded binary
├── index.html          # Simple keepalive page
├── tunnel.yml           # Fixed domain config (if applicable)
├── credentials.json     # Cloudflare credentials (if applicable)
└── pids.txt            # Process IDs for cleanup
```

## Process Management

### PIDs Stored
- `KEEP_PID`: HTTP server process
- `CF_PID`: Cloudflared process

### Cleanup
Script automatically cleans up on:
- `Ctrl+C` (SIGINT)
- `kill` command (SIGTERM)
- Script exit

### Manual Cleanup
```bash
cd /tmp/argo-zampto
if [[ -f "pids.txt" ]]; then
    while IFS= read -r line; do
        PID=$(echo "$line" | cut -d'=' -f2)
        kill "$PID" 2>/dev/null
    done < pids.txt
fi
```

## Architecture Support

| Architecture | Cloudflared Binary |
|--------------|-------------------|
| x86_64/amd64 | cloudflared-linux-amd64 |
| aarch64/arm64 | cloudflared-linux-arm64 |
| armv7l/armhf | cloudflared-linux-arm |

## Tunnel Types

### Fixed Domain Tunnel
- **Requirements**: `CF_DOMAIN` and `CF_TOKEN` in config
- **URL**: `https://your-domain.com`
- **Config**: Creates `tunnel.yml` and `credentials.json`

### Temporary Tunnel
- **Requirements**: None (fallback)
- **URL**: `https://random.trycloudflare.com`
- **Log**: `/tmp/cloudflared.log`

## Validation

### Line Endings
```bash
grep -c $'\r' argo.sh  # Should output: 0
```

### Syntax Check
```bash
bash -n argo.sh  # Should exit with no errors
```

### Line Count
```bash
wc -l argo.sh  # Should be ~144 lines
```

## Comparison with Previous Version

| Feature | Previous (582 lines) | Current (144 lines) |
|---------|---------------------|-------------------|
| Line Count | 582 | 144 (-75%) |
| Complexity | High | Low |
| Dependencies | jq, multiple tools | python3 only |
| Features | Full-featured | Keepalive + Cloudflared only |
| Maintenance | Complex | Simple |
| Reliability | Good | Excellent |

## Troubleshooting

### python3 not found
```bash
# Install python3
apt update && apt install -y python3
# or
yum install -y python3
```

### cloudflared download failed
```bash
# Check internet connection
curl -I https://github.com

# Manual download
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    armv7l) ARCH="arm" ;;
esac
wget "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}"
```

### Tunnel not accessible
```bash
# Check if processes are running
ps aux | grep cloudflared
ps aux | grep "python3 -m http.server"

# Check logs
tail -f /tmp/cloudflared.log

# Test local HTTP server
curl http://127.0.0.1:27039
```

## Integration with Zampto

This script is designed to work seamlessly with zampto:
1. **Port**: Uses zampto's standard port 27039
2. **Config**: Reads from zampto's config.json location
3. **Workdir**: Uses `/tmp` to avoid conflicts
4. **Cleanup**: Proper process management for zampto environment

## Security Considerations

- HTTP server binds to `127.0.0.1` only (localhost)
- No external dependencies except python3
- Minimal attack surface
- Secure process isolation

## Summary

This minimal argo.sh provides:
- ✅ Simplicity (144 lines vs 582)
- ✅ Reliability (wispbyte proven approach)
- ✅ LF line endings (0 CRLF)
- ✅ zampto compatibility
- ✅ Production ready
- ✅ Easy maintenance

The script focuses on doing one thing well: providing a reliable keepalive HTTP server with Cloudflare tunneling for zampto deployments.