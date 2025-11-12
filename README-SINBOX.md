# Vmess-Argo + Nezha + Telegram Integration for sin-box Framework

## Overview

This integration provides a complete Vmess-Argo deployment with Nezha monitoring and Telegram notifications for zampto servers running the sin-box framework in Node.js environments.

## Features

- ✅ **Vmess Protocol**: WebSocket-based Vmess proxy on port 8001 (configurable)
- ✅ **Cloudflare Argo Tunnel**: Secure tunnel with fixed or temporary domains
- ✅ **Nezha Monitoring**: Support for both v0 and v1 Nezha formats
- ✅ **Telegram Notifications**: Real-time alerts for startup, crashes, and recovery
- ✅ **Auto-Healing**: Process monitoring and auto-restart every 30 seconds
- ✅ **Resource Optimization**: Uses `nice` and `ionice` for CPU/IO priority management
- ✅ **Subscription Management**: Auto-generated Vmess links accessible via HTTP

## Architecture

```
Node.js HTTP Server (port 8080)
    ├── GET / (Health check)
    ├── GET /sub (Subscription endpoint)
    ├── GET /status (Service status)
    └── GET /logs (Debug logs)

Background Services (via start.sh)
    ├── Xray (Vmess server on port 8001)
    ├── Cloudflared (Argo tunnel)
    ├── Nezha Agent (Monitoring)
    └── Monitor Loop (Auto-healing every 30s)
```

## Files

- **start.sh**: Main bash script that manages Vmess, Argo, and Nezha services
- **index.js**: Node.js HTTP server for subscription delivery and health checks
- **package.json**: Node.js project configuration

## Environment Variables

### Required

- **UUID**: Vmess UUID (default: auto-generated)

### Vmess/Argo Configuration

- **ARGO_DOMAIN**: Fixed Argo tunnel domain (leave empty for temporary)
- **ARGO_AUTH**: Argo tunnel token or JSON credentials
- **ARGO_PORT**: Vmess port (default: 8001)
- **CFIP**: Cloudflare IP or domain for client connection (default: cf.877774.xyz)
- **CFPORT**: Port for client connection (default: 443)
- **DISABLE_ARGO**: Set to any value to disable Argo tunnel

### Nezha Monitoring

- **NEZHA_SERVER**: Nezha server address
  - v0: `nezha.example.com` (port specified separately)
  - v1: `nezha.example.com:8008` (port included)
- **NEZHA_PORT**: Port for Nezha v0 (not used in v1)
- **NEZHA_KEY**: Nezha agent secret key (NZ_CLIENT_SECRET for v1)

### Telegram Notifications

- **CHAT_ID**: Telegram chat ID for notifications
- **BOT_TOKEN**: Telegram bot token (optional, uses public bot if not set)

### Optional

- **SUB_PATH**: Subscription endpoint path (default: sub)
- **NAME**: Service name for identification (default: SAP)
- **UPLOAD_URL**: External URL to upload subscription (optional)

## Deployment

### Local Testing

```bash
# Set environment variables
export UUID="your-uuid-here"
export ARGO_DOMAIN="your-domain.example.com"
export ARGO_AUTH="your-argo-token"
export NEZHA_SERVER="nezha.example.com:8008"
export NEZHA_KEY="your-nezha-key"
export CHAT_ID="your-telegram-chat-id"
export BOT_TOKEN="your-telegram-bot-token"

# Install dependencies (none required for Node.js server)
npm install

# Start the application
npm start
```

### SAP Cloud Foundry Deployment

```bash
# Push application with environment variables
cf push your-app-name --docker-image ghcr.io/eooce/nodejs:main -m 256M -k 256M

# Set environment variables
cf set-env your-app-name UUID "your-uuid"
cf set-env your-app-name ARGO_DOMAIN "your-domain"
cf set-env your-app-name ARGO_AUTH "your-token"
cf set-env your-app-name NEZHA_SERVER "nezha.example.com:8008"
cf set-env your-app-name NEZHA_KEY "your-key"
cf set-env your-app-name CHAT_ID "your-chat-id"
cf set-env your-app-name BOT_TOKEN "your-bot-token"

# Restage application
cf restage your-app-name
```

### Docker Deployment

```bash
docker run -d \
  -p 8080:8080 \
  -e UUID="your-uuid" \
  -e ARGO_DOMAIN="your-domain" \
  -e ARGO_AUTH="your-token" \
  -e NEZHA_SERVER="nezha.example.com:8008" \
  -e NEZHA_KEY="your-key" \
  -e CHAT_ID="your-chat-id" \
  -e BOT_TOKEN="your-bot-token" \
  ghcr.io/eooce/nodejs:main
```

## Usage

### Access Subscription

After deployment, access your Vmess subscription at:

```
https://your-app-domain/sub
```

Import this URL into your Vmess client (v2rayN, Clash, etc.)

### Check Service Status

```
https://your-app-domain/status
```

Returns JSON with service status, uptime, and memory usage.

### View Logs

```
https://your-app-domain/logs
```

Displays logs from Xray, Cloudflared, and Nezha services.

## Nezha Monitoring Support

### Nezha v0 (Legacy)

```bash
export NEZHA_SERVER="nezha.example.com"
export NEZHA_PORT="5555"
export NEZHA_KEY="your-agent-key"
```

### Nezha v1 (Current)

```bash
export NEZHA_SERVER="nezha.example.com:8008"
export NEZHA_KEY="your-client-secret"
# No NEZHA_PORT needed
```

## Telegram Notifications

The script sends notifications for:

1. **Startup**: Service successfully started with subscription link
2. **Crash Detection**: When any service (Xray/Cloudflared/Nezha) dies
3. **Auto-Recovery**: When services are automatically restarted

### Using Custom Bot

```bash
export BOT_TOKEN="your-telegram-bot-token"
export CHAT_ID="your-chat-id"
```

### Using Public Bot

```bash
export CHAT_ID="your-chat-id"
# BOT_TOKEN not required
```

## Auto-Healing Mechanism

The monitoring loop runs every 30 seconds and checks:

- Xray process status
- Cloudflared tunnel status
- Nezha agent status

If any process is not running, it will be automatically restarted and a Telegram notification will be sent.

## Resource Optimization

The script uses:

- **nice -n 10**: Lower CPU priority for Xray
- **ionice -c2 -n7**: Lower I/O priority for disk operations

This ensures the proxy services don't interfere with the main Node.js application or other system processes.

## Troubleshooting

### Subscription Not Available

Wait 10-15 seconds after startup for services to initialize. Check logs at `/logs` endpoint.

### Argo Tunnel Not Working

1. Verify ARGO_AUTH and ARGO_DOMAIN are correct
2. Check Cloudflared logs at `~/.npm/logs/argo.log`
3. For temporary tunnels, leave ARGO_DOMAIN and ARGO_AUTH empty

### Nezha Agent Not Connecting

1. Verify NEZHA_SERVER format matches your Nezha version
2. Check NEZHA_KEY is correct
3. Review Nezha logs at `~/.npm/logs/nezha.log`

### Services Keep Crashing

1. Check available memory: `free -h`
2. Verify all required binaries downloaded correctly
3. Check system architecture matches (amd64 vs arm64)

## Directory Structure

```
~/.npm/
├── xray                    # Xray binary
├── cloudflared             # Cloudflared binary
├── nezha-agent             # Nezha agent binary
├── config.json             # Xray configuration
├── sub.txt                 # Vmess subscription
├── logs/
│   ├── xray.log           # Xray logs
│   ├── argo.log           # Cloudflared logs
│   └── nezha.log          # Nezha logs
└── pids/
    ├── xray.pid           # Xray process ID
    ├── argo.pid           # Cloudflared process ID
    ├── nezha.pid          # Nezha process ID
    └── monitor.pid        # Monitor loop process ID
```

## Security Notes

1. **UUID**: Always use a unique UUID for each deployment
2. **SUB_PATH**: Set a custom path to prevent subscription leaks
3. **Argo Token**: Keep ARGO_AUTH secret, never commit to version control
4. **Nezha Key**: Protect NEZHA_KEY as it grants monitoring access

## System Requirements

- **Platform**: Linux (x86_64 or aarch64)
- **Runtime**: Node.js 14+ 
- **Memory**: 2GB RAM (256MB minimum for SAP CF)
- **Disk**: 8GB (actual usage ~200MB)
- **Network**: Outbound HTTPS access required

## License

MIT License - See LICENSE file for details

## Support

For issues and questions:
- GitHub Issues: https://github.com/eooce/Auto-deploy-sap-and-keepalive/issues
- Telegram Group: https://t.me/eooceu

## Credits

Built for the sin-box framework and zampto server deployments.
