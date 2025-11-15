# Zampto Configuration Reference

Complete environment variable reference for sing-box deployment on zampto Node10 (ARM).

---

## Quick Reference Table

| Variable | Required | Default | Type | Example |
|----------|----------|---------|------|---------|
| `UUID` | ✅ | - | UUID | `de305d54-75b4-431b-adb2-eb6b9e546014` |
| `NAME` | ❌ | `zampto-node` | string | `my-proxy-node` |
| `SERVER_PORT` | ❌ | `3000` | int | `3000` |
| `FILE_PATH` | ❌ | `./.npm` | path | `./.npm` |
| `SUB_PATH` | ❌ | `sub` | string | `sub` |
| `ARGO_DOMAIN` | ❌ | - | string | `tunnel.example.com` |
| `ARGO_AUTH` | ❌ | - | string | token or JSON |
| `CFIP` | ❌ | - | string | `1.2.3.4` or `cf.example.com` |
| `CFPORT` | ❌ | `443` | int | `443` |
| `NEZHA_SERVER` | ❌ | - | string | `monitoring.com:8008` |
| `NEZHA_PORT` | ❌ | - | int | `5555` |
| `NEZHA_KEY` | ❌ | - | string | `agent-key-here` |
| `BOT_TOKEN` | ❌ | - | string | `123456:ABC...` |
| `CHAT_ID` | ❌ | - | string | `987654321` |
| `UPLOAD_URL` | ❌ | - | URL | `https://example.com/upload` |

---

## Essential Configuration

### 1. VMess UUID (Required)

The UUID is the authentication token for VMess connections.

**What it is**: A Universally Unique Identifier (UUID v4)

**How to generate**:
```bash
# Using uuidgen (Linux)
uuidgen

# Using online tool
# https://www.uuidgenerator.net/version4

# Example output
# de305d54-75b4-431b-adb2-eb6b9e546014
```

**Set in environment**:
```bash
export UUID="de305d54-75b4-431b-adb2-eb6b9e546014"
```

**Important notes**:
- Must be unique per node (don't reuse)
- Used as authentication token
- Clients must have matching UUID
- Store securely

---

## Server Configuration

### SERVER_PORT
HTTP server listen port for subscription and info endpoints.

**Default**: `3000`

**Set in environment**:
```bash
export SERVER_PORT="3000"
```

**Considerations**:
- Must be unique per instance (if running multiple)
- Should be > 1024 (non-root)
- Typical range: 3000-9000

**Multiple instances**:
```bash
# Instance 1
SERVER_PORT=3000 npm start

# Instance 2 (different terminal)
SERVER_PORT=3001 npm start
```

### FILE_PATH
Directory for caching subscription content.

**Default**: `./.npm`

**Set in environment**:
```bash
export FILE_PATH="./.npm"
```

**Directory structure**:
```
sing-box-service/
├── .npm/              (subscription cache)
├── config/            (configurations)
├── logs/              (service logs)
├── index.js           (Node.js server)
├── start.sh           (startup script)
└── package.json       (npm config)
```

### SUB_PATH
Subscription endpoint path (without leading slash).

**Default**: `sub`

**Set in environment**:
```bash
export SUB_PATH="sub"  # Access at http://localhost:3000/sub
export SUB_PATH="api"  # Access at http://localhost:3000/api
```

### NODE NAME
Display name for this node.

**Default**: `zampto-node`

**Set in environment**:
```bash
export NAME="my-sing-box-node"
export NAME="sg-node-1"
export NAME="us-node-2"
```

---

## Argo Tunnel Configuration

Connect to Cloudflare Argo Tunnel for optimized routing.

### ARGO_DOMAIN
Your Argo tunnel domain.

**Format**: `tunnel-name.example.com`

**Set in environment**:
```bash
export ARGO_DOMAIN="my-tunnel.example.com"
```

**Where to find**:
1. Log in to Cloudflare Dashboard
2. Select domain
3. Go to Argo Tunnel section
4. Copy public domain

### ARGO_AUTH
Tunnel authentication (token or JSON).

**Token format**:
```bash
export ARGO_AUTH="eyJhIjoiYjU5YzI0YjIxOTc0YTAzMGZiNDY2YjdhYTg5YjI4OTIiLCJ0Ijo..."
```

**JSON format**:
```bash
export ARGO_AUTH='{"AccountTag":"abc123","TunnelID":"tunnel-id-here","TunnelSecret":"secret-base64-string"}'
```

**Where to find**:
1. Cloudflare Dashboard → Argo Tunnels
2. Create tunnel or select existing
3. Copy token or credentials

### CFIP (Optional)
Cloudflare optimized IP for direct connection.

**Set in environment**:
```bash
export CFIP="1.2.3.4"              # Direct IP
export CFIP="cf.example.com"       # Domain
```

**Finding optimized IPs**:
- Test different Cloudflare IPs
- Use tools like CF speed test
- Common options:
  - `162.159.200.1` - Hong Kong
  - `162.159.201.1` - Singapore
  - `1.1.1.2` - Anywhere

### CFPORT (Optional)
Port for Argo tunnel connection.

**Default**: `443`

**Set in environment**:
```bash
export CFPORT="443"    # HTTPS (default)
export CFPORT="8443"   # Alternative
```

---

## Nezha Monitoring Integration

Monitor your node with Nezha monitoring dashboard.

### NEZHA_SERVER
Nezha server address.

**Nezha v1 format** (recommended):
```bash
export NEZHA_SERVER="monitoring.example.com:8008"
```

**Nezha v0 format**:
```bash
export NEZHA_SERVER="monitoring.example.com"
export NEZHA_PORT="5555"
```

**Where to find**:
1. Log in to Nezha dashboard
2. Go to Settings
3. Copy server address and port

### NEZHA_KEY
Nezha agent authentication key.

**Set in environment**:
```bash
export NEZHA_KEY="your-agent-key-here"
```

**Where to find**:
1. Nezha dashboard → Settings → Agent section
2. Copy your agent secret key

**v0 specific**:
- Key format: Usually alphanumeric string
- Used for agent registration

**v1 specific**:
- Key: Usually prefixed with `NZ_CLIENT_SECRET=`
- Copy from dashboard

### NEZHA_PORT (v0 only)
Nezha server port (only for v0, v1 doesn't need this).

**Set in environment**:
```bash
export NEZHA_PORT="5555"
```

**Configuration example**:
```bash
# For Nezha v0
export NEZHA_SERVER="monitoring.example.com"
export NEZHA_PORT="5555"
export NEZHA_KEY="your-agent-key"

# For Nezha v1
export NEZHA_SERVER="monitoring.example.com:8008"
export NEZHA_KEY="your-agent-key"
```

---

## Telegram Notifications

Receive service alerts via Telegram.

### BOT_TOKEN
Telegram bot token.

**Format**: `123456:ABCDEfghIjklmnopqrstUVwxyz`

**How to get**:
1. Message `@BotFather` on Telegram
2. Create new bot: `/newbot`
3. Follow instructions
4. Copy token

**Set in environment**:
```bash
export BOT_TOKEN="123456:ABC..."
```

### CHAT_ID
Your Telegram chat ID.

**Format**: Numeric string (e.g., `987654321`)

**How to find**:
1. Add your bot to a chat/group
2. Send any message
3. Visit: `https://api.telegram.org/bot<BOT_TOKEN>/getUpdates`
4. Look for `"chat":{"id":123456789}`

**Set in environment**:
```bash
export CHAT_ID="987654321"
```

**Testing notifications**:
```bash
# The service will send notifications on:
# - Service start
# - Health check failures
# - Process restart
# - Critical errors
```

---

## Advanced Configuration

### UPLOAD_URL
Custom subscription upload endpoint.

**Set in environment**:
```bash
export UPLOAD_URL="https://api.example.com/upload"
```

**When to use**:
- Syncing subscriptions to external service
- Custom dashboard integration
- Analytics collection

---

## Configuration Examples

### Minimal Setup (Standalone)

```bash
export UUID="de305d54-75b4-431b-adb2-eb6b9e546014"
export NAME="stand-alone-node"
export SERVER_PORT="3000"

npm start
```

### With Argo Tunnel

```bash
export UUID="de305d54-75b4-431b-adb2-eb6b9e546014"
export NAME="argo-node"
export SERVER_PORT="3000"

export ARGO_DOMAIN="my-tunnel.example.com"
export ARGO_AUTH="eyJhIjoiYjU5YzI0YjIx..."
export CFIP="1.2.3.4"
export CFPORT="443"

npm start
```

### With Nezha v1 Monitoring

```bash
export UUID="de305d54-75b4-431b-adb2-eb6b9e546014"
export NAME="monitored-node"
export SERVER_PORT="3000"

export NEZHA_SERVER="monitoring.example.com:8008"
export NEZHA_KEY="your-agent-key-here"

npm start
```

### Full Production Setup

```bash
# Identifiers
export UUID="de305d54-75b4-431b-adb2-eb6b9e546014"
export NAME="prod-node-sg-1"

# Server
export SERVER_PORT="3000"
export FILE_PATH="./.npm"
export SUB_PATH="subscribe"

# Argo tunnel
export ARGO_DOMAIN="tunnel-sg.example.com"
export ARGO_AUTH='{"AccountTag":"abc","TunnelID":"xyz","TunnelSecret":"..."}'
export CFIP="1.2.3.4"
export CFPORT="443"

# Monitoring
export NEZHA_SERVER="monitoring.example.com:8008"
export NEZHA_KEY="your-agent-key"

# Notifications
export BOT_TOKEN="123456:ABC..."
export CHAT_ID="987654321"

# Optional
export UPLOAD_URL="https://api.example.com/upload"

npm start
```

---

## Environment File (.env)

Instead of exporting each variable, create a `.env` file:

```bash
# Create .env file
cat > .env << 'EOF'
UUID=de305d54-75b4-431b-adb2-eb6b9e546014
NAME=my-zampto-node
SERVER_PORT=3000
FILE_PATH=./.npm
SUB_PATH=sub

ARGO_DOMAIN=my-tunnel.example.com
ARGO_AUTH=eyJhIjoiYjU5YzI0YjIx...
CFIP=1.2.3.4
CFPORT=443

NEZHA_SERVER=monitoring.example.com:8008
NEZHA_KEY=your-agent-key

BOT_TOKEN=123456:ABC...
CHAT_ID=987654321
EOF

# Load variables
source .env

# Or use with Node directly
npm start
```

**Security note**: Add `.env` to `.gitignore`!

```bash
echo ".env" >> .gitignore
chmod 600 .env
```

---

## Verification

### Check Configuration Is Loaded

```bash
# Display all relevant env vars
echo "=== Configuration ===" && \
echo "UUID: $UUID" && \
echo "NAME: $NAME" && \
echo "SERVER_PORT: $SERVER_PORT" && \
echo "ARGO_DOMAIN: $ARGO_DOMAIN" && \
echo "NEZHA_SERVER: $NEZHA_SERVER" && \
echo "BOT_TOKEN: $BOT_TOKEN" && \
echo "CHAT_ID: $CHAT_ID"
```

### Test Endpoints with Configuration

```bash
# Test info endpoint (shows config)
curl http://localhost:3000/info

# Should output something like:
# {
#   "status": "running",
#   "uuid": "de305d54-75b4-431b-adb2-eb6b9e546014",
#   "nodeName": "my-zampto-node",
#   "port": 3000,
#   "features": {
#     "argoTunnel": true,
#     "nezhaMonitoring": true,
#     "telegramNotification": true
#   }
# }
```

---

## Troubleshooting

### UUID Not Working
- Verify UUID format: `de305d54-75b4-431b-adb2-eb6b9e546014`
- Should be v4 UUID (36 characters with dashes)
- Check env var: `echo $UUID`

### Argo Tunnel Not Connecting
- Verify domain format: `tunnel.example.com` (no https://)
- Check token format: Should start with `eyJ` (base64)
- Test connection: `curl $ARGO_DOMAIN`

### Nezha Not Showing Data
- Verify server format: `host:port` for v1
- Check key: Should be non-empty string
- Verify DNS resolution: `nslookup $NEZHA_SERVER`

### Telegram Messages Not Received
- Verify bot token: `curl https://api.telegram.org/bot{BOT_TOKEN}/getMe`
- Verify chat ID: Must be valid user or group ID
- Check network: `curl -I https://api.telegram.org`

---

## Performance Impact of Configuration

| Setting | Impact | Notes |
|---------|--------|-------|
| Argo Tunnel | -5% CPU | Adds small overhead |
| Nezha Monitoring | -2% CPU | Minimal impact |
| Telegram Notifications | <1% CPU | Only at events |
| All Combined | -7% CPU | Still leaves 33-43% |

---

## Security Best Practices

1. **Never commit `.env` to git**
   ```bash
   echo ".env" >> .gitignore
   ```

2. **Restrict file permissions**
   ```bash
   chmod 600 .env
   chmod 600 config/cloudflared/token
   ```

3. **Use environment-specific configs**
   ```bash
   # Different files for dev/prod
   .env.dev
   .env.prod
   source .env.${NODE_ENV}
   ```

4. **Rotate sensitive keys regularly**
   - Change UUID every 3-6 months
   - Regenerate Telegram bot if compromised
   - Update Argo tunnel credentials

---

## See Also

- [ZAMPTO_DEPLOYMENT_GUIDE.md](ZAMPTO_DEPLOYMENT_GUIDE.md) - Full deployment guide
- [ZAMPTO_QUICK_START.md](ZAMPTO_QUICK_START.md) - Quick start (5 minutes)
- [OPTIMIZATION_GUIDE.md](OPTIMIZATION_GUIDE.md) - CPU optimization details
- [CONFIGURATION_EXAMPLES.md](CONFIGURATION_EXAMPLES.md) - Advanced configs

---

**Last Updated**: 2024-01-15  
**Platform**: zampto Node10 (ARM)
