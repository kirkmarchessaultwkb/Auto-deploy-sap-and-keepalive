# Wispbyte Argo Sing-box Deploy - Robust Config Loading

## Version 1.1.0 Update

**Release Date**: 2024  
**File**: `wispbyte-argo-singbox-deploy.sh`  
**Line Count**: 194 lines (under 200-line requirement ✅)

## Overview

This update implements **dual-priority configuration loading** for the wispbyte deploy script:

1. **Priority 1**: Read from environment variables (exported by `start.sh`)
2. **Priority 2**: Fallback to reading from `/home/container/config.json`

This flexibility allows the script to work in multiple deployment scenarios:
- When called by `start.sh` (env vars available)
- When called directly (reads config.json)
- When both are available (env vars take precedence)

---

## Key Improvements

### 1. Dual-Priority Configuration Loading

#### Environment Variables (Priority 1)
```bash
# Priority 1: Environment variables (exported by start.sh)
CF_DOMAIN="${CF_DOMAIN:-}"
CF_TOKEN="${CF_TOKEN:-}"
UUID="${UUID:-}"
PORT="${PORT:-27039}"
```

These variables are exported by `start.sh` after loading from `config.json`:
```bash
# In start.sh (line 42)
export CF_DOMAIN CF_TOKEN UUID PORT NEZHA_SERVER NEZHA_PORT NEZHA_KEY
```

#### Fallback to Config File (Priority 2)
```bash
# Priority 2: Fallback to config.json if env vars are empty
if [[ -z "$CF_DOMAIN" && -f "$CONFIG_FILE" ]]; then
    CF_DOMAIN=$(grep -o '"cf_domain"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/' || echo "")
fi

# ... same pattern for CF_TOKEN, UUID, PORT
```

### 2. Working Directory Change

**Previous**: `/tmp/wispbyte-singbox` (temporary, not persistent)  
**Updated**: `/home/container/argo-tuic` (persistent, matches other tools)

This allows logs, PIDs, and configs to persist for debugging.

### 3. Architecture Detection with ARM64 Support

```bash
detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64) echo "amd64" ;;        # Standard x86-64
        aarch64|arm64) echo "arm64" ;;       # 64-bit ARM
        armv7l|armhf) echo "arm" ;;          # 32-bit ARM
        *) log "[ERROR] Unsupported arch: $(uname -m)"; exit 1 ;;
    esac
}
```

**Supported Architectures**:
- ✅ AMD64 (x86_64)
- ✅ ARM64 (aarch64)
- ✅ ARMv7 (armv7l)

### 4. Configuration Loading Flow

```
1. Script starts
   ↓
2. load_config() executes
   ├─ Check env vars (Priority 1)
   ├─ If empty, check config.json (Priority 2)
   └─ Validate critical fields
   ↓
3. Binaries downloaded
   ├─ Sing-box (for VMESS inbound)
   └─ Cloudflared (for Argo tunnel)
   ↓
4. Services started
   ├─ Sing-box: 127.0.0.1:PORT
   └─ Cloudflared: tunnel proxy
   ↓
5. Subscription generated
   └─ VMESS-WS-TLS URL to /home/container/.npm/sub.txt
   ↓
✅ Deployment complete
```

---

## Configuration File Format

**Location**: `/home/container/config.json`

```json
{
  "cf_domain": "your-domain.example.com",
  "cf_token": "eyJhIjoiYTAxZDMwY2Q1ZD... (Cloudflare Tunnel Token)",
  "uuid": "550e8400-e29b-41d4-a716-446655440000",
  "port": "27039",
  "nezha_server": "nezha.example.com",
  "nezha_port": "5555",
  "nezha_key": "your-nezha-key"
}
```

### Required Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `cf_domain` | string | none | Cloudflare domain (required for fixed tunnel) |
| `cf_token` | string | none | Cloudflare Tunnel token (required for fixed tunnel) |
| `uuid` | string | required | VMess UUID for sing-box |
| `port` | string | 27039 | Sing-box listening port |

### Optional Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `nezha_server` | string | none | Nezha monitoring server |
| `nezha_port` | string | 5555 | Nezha port |
| `nezha_key` | string | none | Nezha agent key |

---

## Environment Variables

When called by `start.sh`, these environment variables are already exported:

```bash
export CF_DOMAIN CF_TOKEN UUID PORT NEZHA_SERVER NEZHA_PORT NEZHA_KEY
```

**Variable Priority**:
1. ✅ Environment variable (if set by parent script)
2. ✅ Config file (if env var not set)
3. ✅ Default value (hardcoded for PORT: 27039)

---

## Deployment Scenarios

### Scenario 1: Called by start.sh (Normal)

```bash
# In start.sh
load_config           # Loads from config.json
export VARIABLES      # Exports to environment
bash wispbyte-...sh   # Calls this script with env vars

# In wispbyte script
# Uses environment variables (Priority 1) ✅
```

### Scenario 2: Called Directly (Standalone)

```bash
bash /home/container/wispbyte-argo-singbox-deploy.sh

# In wispbyte script
# Uses config.json fallback (Priority 2) ✅
```

### Scenario 3: Both Available (Backward Compatible)

```bash
# Environment variables take precedence
CF_DOMAIN=custom.example.com bash /home/container/wispbyte-argo-singbox-deploy.sh

# Uses environment variable ✅
```

---

## Sing-box Configuration

The script generates VMESS configuration for sing-box:

```json
{
  "log": {"level": "info"},
  "inbounds": [{
    "type": "vmess",
    "tag": "vmess-in",
    "listen": "127.0.0.1",
    "listen_port": PORT,
    "users": [{"uuid": "UUID", "alterId": 0}],
    "transport": {"type": "ws", "path": "/ws"}
  }],
  "outbounds": [{"type": "direct", "tag": "direct"}]
}
```

**Key Details**:
- ✅ Listens on `127.0.0.1:PORT` (loopback only)
- ✅ VMESS protocol with VMess UUID
- ✅ WebSocket transport with `/ws` path
- ✅ No alterId (modern VMess)

---

## Cloudflared Tunnel

### Fixed Domain Mode

If `CF_DOMAIN` and `CF_TOKEN` are available:

```bash
nohup "$CLOUDFLARED_BIN" tunnel --no-autoupdate run --token "$CF_TOKEN" \
    > "$WORK_DIR/cloudflared.log" 2>&1 &
```

**Benefits**:
- ✅ Consistent domain across restarts
- ✅ Better for production
- ✅ Requires Cloudflare account setup

### Temporary Tunnel Mode

If `CF_DOMAIN` or `CF_TOKEN` are missing:

```bash
nohup "$CLOUDFLARED_BIN" tunnel --url "http://127.0.0.1:$PORT" \
    > "$WORK_DIR/cloudflared.log" 2>&1 &
```

**Benefits**:
- ✅ No setup required
- ✅ Instant deployment
- ✅ URL changes on restart (temporary)

---

## Subscription Generation

### VMess Node Format

```json
{
  "v": "2",
  "ps": "zampto-argo",
  "add": "DOMAIN",
  "port": "443",
  "id": "UUID",
  "aid": "0",
  "net": "ws",
  "type": "none",
  "host": "DOMAIN",
  "path": "/ws",
  "tls": "tls",
  "sni": "DOMAIN",
  "fingerprint": "chrome"
}
```

### Encoding Process

1. Create JSON node (as above)
2. Base64 encode: `base64 -w 0`
3. Create VMess URL: `vmess://[base64]`
4. Base64 encode again
5. Save to `/home/container/.npm/sub.txt`

### Subscription URL

```
https://DOMAIN/sub
```

This URL serves the encoded subscription file for client configuration.

---

## Output Example

```
[12:34:56] ========================================
[12:34:56] Wispbyte Argo Sing-box Deploy
[12:34:56] ========================================
[12:34:56] [INFO] Loading configuration...
[12:34:56] [INFO] Configuration: Domain=zampto.example.com, UUID=550e8400-..., Port=27039
[12:34:56] [INFO] Downloading sing-box...
[12:34:57] [OK] Sing-box ready
[12:34:58] [INFO] Downloading cloudflared...
[12:34:59] [OK] Cloudflared ready
[12:34:59] [INFO] Generating sing-box config...
[12:34:59] [OK] Config generated
[12:35:00] [INFO] Starting sing-box on 127.0.0.1:27039...
[12:35:02] [OK] Sing-box started (PID: 1234)
[12:35:02] [INFO] Starting cloudflared tunnel...
[12:35:02] [INFO] Fixed domain: zampto.example.com
[12:35:05] [OK] Cloudflared started (PID: 1235)
[12:35:05] [INFO] Generating VMESS subscription...
[12:35:05] [OK] Subscription generated
[12:35:05] [URL] https://zampto.example.com/sub
[12:35:05] [FILE] /home/container/.npm/sub.txt
[12:35:05] ========================================
[12:35:05] [SUCCESS] Deployment completed
[12:35:05] [SINGBOX] PID: 1234
[12:35:05] [CLOUDFLARED] PID: 1235
[12:35:05] [LOGS] /home/container/argo-tuic
[12:35:05] ========================================
```

---

## File Structure

```
/home/container/
├── config.json                        # Configuration file
├── argo-tuic/                         # Working directory
│   ├── bin/                          # Binaries
│   │   ├── sing-box
│   │   └── cloudflared
│   ├── config.json                   # Sing-box config
│   ├── singbox.log                   # Sing-box logs
│   ├── singbox.pid                   # Sing-box PID
│   ├── cloudflared.log               # Cloudflared logs
│   ├── cloudflared.pid               # Cloudflared PID
│   └── deploy.log                    # Deployment log
├── .npm/
│   └── sub.txt                       # Subscription file
└── wispbyte-argo-singbox-deploy.sh   # This script
```

---

## Integration with start.sh

The deployment script is called by `start.sh` after loading configuration:

```bash
# In start.sh (lines 121-127)
# 1. Load config.json (all parameters)
if ! load_config; then
    log "ERROR: Failed to load configuration, exiting..."
    exit 1
fi

# 2. Start Nezha monitoring
start_nezha_agent

# 3. Call wispbyte deploy script
echo "[INFO] Calling wispbyte-argo-singbox-deploy.sh..."
if [[ -f "/home/container/wispbyte-argo-singbox-deploy.sh" ]]; then
    bash /home/container/wispbyte-argo-singbox-deploy.sh
fi
```

**Flow**:
1. `start.sh` loads config from `/home/container/config.json`
2. `start.sh` exports all variables to environment
3. `start.sh` calls `wispbyte-argo-singbox-deploy.sh`
4. Script receives env vars as Priority 1 (from start.sh export)

---

## Troubleshooting

### Issue: "Configuration: Domain=not set"

**Causes**:
1. Environment variables not exported (not called by start.sh)
2. config.json file missing
3. config.json missing `cf_domain` field

**Solution**:
```bash
# Either export env vars before calling
export CF_DOMAIN="your-domain.com"
export CF_TOKEN="your-token"
export UUID="your-uuid"
bash wispbyte-argo-singbox-deploy.sh

# Or ensure config.json exists with all fields
cat /home/container/config.json
```

### Issue: "ERROR Sing-box download failed"

**Causes**:
1. Network connectivity issue
2. GitHub API rate limit
3. Unsupported architecture

**Solution**:
```bash
# Check architecture
uname -m

# Check network
curl -fsSL https://github.com/SagerNet/sing-box/releases/latest/download/

# Check logs
tail -f /home/container/argo-tuic/deploy.log
```

### Issue: "ERROR Cloudflared failed to start"

**Causes**:
1. Invalid CF_TOKEN format
2. Port already in use
3. Cloudflared binary corrupted

**Solution**:
```bash
# Check if port is in use
lsof -i :443

# Verify CF_TOKEN
echo "$CF_TOKEN" | head -c 20

# Check cloudflared binary
file /home/container/argo-tuic/bin/cloudflared
/home/container/argo-tuic/bin/cloudflared --version
```

### Issue: "ERROR No domain found"

**Causes**:
1. Temporary tunnel mode (cloudflared.log not yet available)
2. Script running too fast (domain extraction timing)

**Solution**:
```bash
# Check cloudflared log
tail /home/container/argo-tuic/cloudflared.log

# Wait for domain to appear
sleep 5
grep "trycloudflare" /home/container/argo-tuic/cloudflared.log
```

---

## Advantages of Dual-Priority Loading

| Scenario | Env Var Priority | Config File Fallback | Result |
|----------|-----------------|----------------------|--------|
| Called by start.sh | ✅ Available | ✅ (not used) | Fast, consistent |
| Called directly | ❌ Not set | ✅ Available | Flexible, standalone |
| Override values | ✅ Set custom | ⚠️ Ignored | Custom deployment |
| Environment test | ✅ For testing | ✅ Safe fallback | Non-destructive |
| Legacy support | ⚠️ Not exported | ✅ Still works | Backward compatible |

---

## Line Count Verification

```bash
wc -l wispbyte-argo-singbox-deploy.sh
# Output: 194 lines (< 200 requirement ✅)
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | Previous | Initial simplified version |
| 1.1.0 | Current | ✅ Dual-priority config loading, ARM64 support, persistent workdir |

---

## Testing Checklist

- ✅ Syntax validation: `bash -n wispbyte-argo-singbox-deploy.sh`
- ✅ Line count: 194 lines (< 200)
- ✅ Environment variable priority (from start.sh export)
- ✅ Config file fallback (standalone execution)
- ✅ Architecture detection (amd64, arm64, arm)
- ✅ Sing-box download and startup
- ✅ Cloudflared tunnel setup
- ✅ VMESS subscription generation
- ✅ Persistent working directory (/home/container/argo-tuic)
- ✅ Clear log output with timestamps
- ✅ LF line endings (no CRLF)

---

## Conclusion

Version 1.1.0 provides robust configuration loading with maximum flexibility:
- **Priority 1**: Environment variables from parent script (start.sh)
- **Priority 2**: Config file fallback for standalone execution
- **Result**: Works in all deployment scenarios while maintaining backward compatibility

This update ensures the script works seamlessly whether called by `start.sh` or executed directly, while maintaining clean separation of concerns and supporting multiple deployment architectures.
