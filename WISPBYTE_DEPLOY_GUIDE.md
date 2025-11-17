# Wispbyte Argo Sing-box Deploy Guide

## Overview

`wispbyte-argo-singbox-deploy.sh` is a simplified deployment script for the zampto platform that sets up a complete VMESS-WS proxy chain using sing-box and cloudflared.

**Version**: 1.0.0  
**Lines**: 180 (< 200 requirement ✅)  
**License**: Simplified deployment for zampto platform

## Architecture

```
Client
  ↓ (TLS 443)
Cloudflare Tunnel
  ↓ (HTTPS)
Cloudflared Proxy
  ↓ (HTTP)
Sing-box (127.0.0.1:PORT)
  ↓ (VMESS-WS)
Target Server
```

## Features

✅ **Non-interactive**: Reads all config from `/home/container/config.json`  
✅ **ARM64 Support**: Auto-detects architecture (amd64, arm64, arm)  
✅ **Minimal**: Only 180 lines (no TUIC, no nodejs-argo)  
✅ **Auto-subscription**: Generates VMESS subscription to `/home/container/.npm/sub.txt`  
✅ **Simple logging**: Compact log format with timestamps  
✅ **Process management**: Runs sing-box and cloudflared in background

## Configuration

### Required Files

**`/home/container/config.json`** - Main configuration file:

```json
{
  "cf_domain": "zampto.xunda.ggff.net",
  "cf_token": "your_cloudflare_token_here",
  "uuid": "12345678-1234-1234-1234-123456789abc",
  "port": "27039"
}
```

### Configuration Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `cf_domain` | Optional | - | Cloudflare fixed domain for tunnel |
| `cf_token` | Optional | - | Cloudflare tunnel token |
| `uuid` | **Required** | - | VMess UUID for authentication |
| `port` | Optional | `27039` | Local port for sing-box to listen on |

**Note**: If `cf_domain` and `cf_token` are not provided, a temporary trycloudflare tunnel will be created.

## Usage

### Standalone Execution

```bash
./wispbyte-argo-singbox-deploy.sh
```

### Called from start.sh

The script is designed to be called from `start.sh`:

```bash
# In start.sh
log_info "Starting Wispbyte Argo Sing-box deployment..."
if [[ -f "/home/container/wispbyte-argo-singbox-deploy.sh" ]]; then
    bash /home/container/wispbyte-argo-singbox-deploy.sh
else
    log_error "wispbyte-argo-singbox-deploy.sh not found"
fi
```

## Script Functions

### Core Functions

1. **`load_config()`** - Loads configuration from config.json
2. **`detect_arch()`** - Detects system architecture (amd64/arm64/arm)
3. **`download_singbox()`** - Downloads sing-box binary from GitHub
4. **`download_cloudflared()`** - Downloads cloudflared binary from GitHub
5. **`generate_singbox_config()`** - Generates sing-box VMESS-WS configuration
6. **`start_singbox()`** - Starts sing-box process in background
7. **`start_cloudflared()`** - Starts cloudflared tunnel in background
8. **`generate_subscription()`** - Generates VMESS subscription file
9. **`main()`** - Main execution flow

### Utility Functions

- **`log()`** - Simple logging with timestamps to console and log file

## Generated Files

### Working Directory: `/tmp/wispbyte-singbox`

```
/tmp/wispbyte-singbox/
├── bin/
│   ├── sing-box          # Sing-box binary
│   └── cloudflared       # Cloudflared binary
├── config.json           # Sing-box configuration
├── deploy.log            # Deployment log
├── singbox.log           # Sing-box runtime log
├── cloudflared.log       # Cloudflared runtime log
├── singbox.pid           # Sing-box process ID
└── cloudflared.pid       # Cloudflared process ID
```

### Subscription File

**`/home/container/.npm/sub.txt`**

- Contains base64-encoded VMESS subscription
- Can be accessed via HTTP endpoint: `https://{domain}/sub`
- Format: Double base64-encoded VMess node

## VMESS Node Format

The generated VMess node has the following structure:

```json
{
  "v": "2",
  "ps": "zampto-argo",
  "add": "zampto.xunda.ggff.net",
  "port": "443",
  "id": "12345678-1234-1234-1234-123456789abc",
  "aid": "0",
  "net": "ws",
  "type": "none",
  "host": "zampto.xunda.ggff.net",
  "path": "/ws",
  "tls": "tls",
  "sni": "zampto.xunda.ggff.net",
  "fingerprint": "chrome"
}
```

### Encoding Process

1. JSON node → Base64 encode → `vmess://...`
2. VMess URL → Base64 encode again → Write to `sub.txt`

## Sing-box Configuration

The script generates a minimal sing-box config:

```json
{
  "log": {"level": "info"},
  "inbounds": [{
    "type": "vmess",
    "tag": "vmess-in",
    "listen": "127.0.0.1",
    "listen_port": 27039,
    "users": [{"uuid": "...", "alterId": 0}],
    "transport": {"type": "ws", "path": "/ws"}
  }],
  "outbounds": [{"type": "direct", "tag": "direct"}]
}
```

### Key Features

- **Protocol**: VMess
- **Transport**: WebSocket (path: `/ws`)
- **Listening**: 127.0.0.1 only (not exposed externally)
- **AlterID**: 0 (recommended for security)
- **Outbound**: Direct (no additional proxy)

## Cloudflared Tunnel

### Fixed Domain (Recommended)

When `cf_domain` and `cf_token` are provided:

```bash
cloudflared tunnel --no-autoupdate run --token "$CF_TOKEN"
```

### Temporary Domain (Fallback)

When `cf_domain` or `cf_token` are missing:

```bash
cloudflared tunnel --url "http://127.0.0.1:$PORT"
```

This generates a temporary `*.trycloudflare.com` domain.

## Process Management

### Start Processes

Both sing-box and cloudflared are started with `nohup` in background:

```bash
nohup sing-box run -c config.json > singbox.log 2>&1 &
nohup cloudflared tunnel ... > cloudflared.log 2>&1 &
```

### Check Status

```bash
# Check if processes are running
kill -0 $(cat /tmp/wispbyte-singbox/singbox.pid)
kill -0 $(cat /tmp/wispbyte-singbox/cloudflared.pid)

# View logs
tail -f /tmp/wispbyte-singbox/singbox.log
tail -f /tmp/wispbyte-singbox/cloudflared.log
```

### Stop Processes

```bash
# Stop sing-box
kill $(cat /tmp/wispbyte-singbox/singbox.pid)

# Stop cloudflared
kill $(cat /tmp/wispbyte-singbox/cloudflared.pid)
```

## Troubleshooting

### 1. Binary Download Fails

**Error**: `[ERROR] Sing-box download failed` or `[ERROR] Cloudflared download failed`

**Solutions**:
- Check internet connectivity
- Verify GitHub is not blocked by firewall
- Check architecture detection: `uname -m`
- Try manual download to test URL

### 2. Config File Not Found

**Error**: `[ERROR] Config not found`

**Solution**: Ensure `/home/container/config.json` exists with required fields.

### 3. Sing-box Won't Start

**Error**: `[ERROR] Sing-box failed to start`

**Debug**:
```bash
cat /tmp/wispbyte-singbox/singbox.log
/tmp/wispbyte-singbox/bin/sing-box run -c /tmp/wispbyte-singbox/config.json
```

**Common causes**:
- Port already in use
- Invalid UUID format
- Missing permissions

### 4. Cloudflared Won't Start

**Error**: `[ERROR] Cloudflared failed to start`

**Debug**:
```bash
cat /tmp/wispbyte-singbox/cloudflared.log
```

**Common causes**:
- Invalid CF_TOKEN format
- Network connectivity issues
- Port already in use

### 5. Subscription Not Generated

**Error**: `[ERROR] No domain found`

**Solutions**:
- Ensure cloudflared is running
- Check cloudflared.log for tunnel URL
- Wait longer (try `sleep 5` before subscription generation)

## Example Output

```
[10:30:45] ========================================
[10:30:45] Wispbyte Argo Sing-box Deploy
[10:30:45] ========================================
[10:30:45] [INFO] Loading config from /home/container/config.json
[10:30:45] [INFO] Domain: zampto.xunda.ggff.net, UUID: 12345678-1234-1234-1234-123456789abc, Port: 27039
[10:30:45] [INFO] Downloading sing-box...
[10:30:48] [OK] Sing-box ready
[10:30:48] [INFO] Downloading cloudflared...
[10:30:50] [OK] Cloudflared ready
[10:30:50] [INFO] Generating sing-box config...
[10:30:50] [OK] Config generated
[10:30:50] [INFO] Starting sing-box on 127.0.0.1:27039...
[10:30:52] [OK] Sing-box started (PID: 12345)
[10:30:52] [INFO] Starting cloudflared tunnel...
[10:30:52] [INFO] Fixed domain: zampto.xunda.ggff.net
[10:30:55] [OK] Cloudflared started (PID: 12346)
[10:30:55] [INFO] Generating VMESS subscription...
[10:30:55] [OK] Subscription generated
[10:30:55] [URL] https://zampto.xunda.ggff.net/sub
[10:30:55] [FILE] /home/container/.npm/sub.txt
[10:30:55] ========================================
[10:30:55] [SUCCESS] Deployment completed
[10:30:55] [SINGBOX] PID: 12345
[10:30:55] [CLOUDFLARED] PID: 12346
[10:30:55] [LOGS] /tmp/wispbyte-singbox
[10:30:55] ========================================
```

## Integration with Zampto Platform

### Called by start.sh

The main `start.sh` script should call this script after starting Nezha:

```bash
main() {
    log_info "=== Zampto Startup Script ==="
    
    # Load config
    load_config || exit 1
    
    # Start Nezha
    start_nezha_agent
    
    # Deploy wispbyte sing-box
    if [[ -f "/home/container/wispbyte-argo-singbox-deploy.sh" ]]; then
        bash /home/container/wispbyte-argo-singbox-deploy.sh
    fi
    
    log_info "=== Startup Script Completed ==="
}
```

### Environment Variables

The script does NOT use environment variables - all configuration comes from `config.json`.

## Comparison with Original Wispbyte

| Feature | Original Wispbyte | This Script |
|---------|-------------------|-------------|
| Lines | ~250-300 | 180 |
| TUIC Support | ✅ | ❌ (not needed) |
| nodejs-argo | ✅ | ❌ (not needed) |
| Interactive Input | ✅ | ❌ (config.json only) |
| ARM64 Support | ✅ | ✅ |
| VMESS-WS | ✅ | ✅ |
| Cloudflared | ✅ | ✅ |
| Subscription | ✅ | ✅ |
| Complexity | Medium-High | Low |

## Technical Details

### Binary Sources

- **Sing-box**: https://github.com/SagerNet/sing-box/releases/latest
- **Cloudflared**: https://github.com/cloudflare/cloudflared/releases/latest

### Architecture Detection

```bash
uname -m | case
  x86_64|amd64   → amd64
  aarch64|arm64  → arm64
  armv7l|armhf   → arm
  other          → ERROR
```

### Security Considerations

1. **Local Binding**: Sing-box binds to 127.0.0.1 only (not exposed externally)
2. **UUID Authentication**: VMess requires valid UUID
3. **TLS Encryption**: Cloudflare provides TLS termination
4. **No Root**: Script runs as non-root user

## Best Practices

1. **Always use fixed domain** (`cf_domain` + `cf_token`) for production
2. **Generate unique UUIDs** for each deployment
3. **Monitor logs** regularly for errors
4. **Check process health** periodically
5. **Back up config.json** before making changes

## License

This script is part of the zampto platform deployment toolkit.

## Version History

- **v1.0.0** (2025-01-XX) - Initial release
  - 180 lines (under 200 requirement)
  - ARM64 support
  - VMESS-WS support
  - Cloudflared tunnel integration
  - Subscription generation
  - Non-interactive configuration

## Support

For issues or questions:
- Check logs in `/tmp/wispbyte-singbox/`
- Review this documentation
- Verify config.json format
- Test binary downloads manually
