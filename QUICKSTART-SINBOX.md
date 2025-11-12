# Quick Start Guide: sin-box Framework Deployment

## 🚀 5-Minute Setup

### Step 1: Prepare Environment Variables

Create a `.env` file or export the following variables:

```bash
# Required
export UUID="$(cat /proc/sys/kernel/random/uuid)"  # Generate random UUID

# Argo Tunnel (Optional - leave empty for temporary tunnel)
export ARGO_DOMAIN="your-tunnel.example.com"
export ARGO_AUTH="your-cloudflare-tunnel-token"

# Nezha Monitoring (Optional but recommended)
export NEZHA_SERVER="nezha.example.com:8008"  # v1 format
export NEZHA_KEY="your-client-secret"

# Telegram Notifications (Optional)
export CHAT_ID="your-telegram-chat-id"
export BOT_TOKEN="your-bot-token"
```

### Step 2: Deploy to SAP Cloud Foundry

```bash
# Login to Cloud Foundry
cf login -a https://api.cf.us10-001.hana.ondemand.com -u "your-email" -p "your-password"

# Push application
cf push my-vmess-app --docker-image ghcr.io/eooce/nodejs:main -m 256M -k 256M

# Set environment variables
cf set-env my-vmess-app UUID "${UUID}"
cf set-env my-vmess-app NEZHA_SERVER "${NEZHA_SERVER}"
cf set-env my-vmess-app NEZHA_KEY "${NEZHA_KEY}"
cf set-env my-vmess-app CHAT_ID "${CHAT_ID}"
cf set-env my-vmess-app BOT_TOKEN "${BOT_TOKEN}"

# Restage to apply changes
cf restage my-vmess-app
```

### Step 3: Get Your Subscription Link

```bash
# Get app route
APP_URL=$(cf app my-vmess-app | grep "routes:" | awk '{print $2}')

# Your subscription link
echo "Subscription: https://${APP_URL}/sub"
```

## 📱 Telegram Bot Setup (Optional)

### Method 1: Custom Bot

1. Talk to [@BotFather](https://t.me/BotFather) on Telegram
2. Create a new bot with `/newbot`
3. Copy the bot token
4. Get your chat ID from [@userinfobot](https://t.me/userinfobot)
5. Set `BOT_TOKEN` and `CHAT_ID` in your environment

### Method 2: Public Bot (No Token Needed)

1. Just set your `CHAT_ID`
2. Leave `BOT_TOKEN` empty
3. Notifications will use a public notification service

## 🔍 Nezha Monitoring Setup

### Nezha v1 (Recommended)

```bash
export NEZHA_SERVER="nezha.example.com:8008"
export NEZHA_KEY="your-nz-client-secret"
# No NEZHA_PORT needed
```

### Nezha v0 (Legacy)

```bash
export NEZHA_SERVER="nezha.example.com"
export NEZHA_PORT="5555"
export NEZHA_KEY="your-agent-key"
```

## 🌐 Cloudflare Argo Tunnel Setup

### Option 1: Fixed Tunnel (Recommended)

1. Go to [Cloudflare Zero Trust](https://one.dash.cloudflare.com/)
2. Navigate to Networks → Tunnels
3. Create a new tunnel
4. Get the tunnel token
5. Set environment variables:

```bash
export ARGO_DOMAIN="your-tunnel.example.com"
export ARGO_AUTH="your-tunnel-token"
```

### Option 2: Temporary Tunnel (Quick Testing)

Leave `ARGO_DOMAIN` and `ARGO_AUTH` empty. The script will create a temporary `*.trycloudflare.com` domain automatically.

## 🧪 Local Testing

```bash
# Clone repository
git clone https://github.com/yourusername/your-repo.git
cd your-repo

# Set environment variables
export UUID="test-uuid-12345"
export NEZHA_SERVER="nezha.example.com:8008"
export NEZHA_KEY="test-key"

# Start application
npm start
```

Access:
- Health: http://localhost:8080/
- Subscription: http://localhost:8080/sub
- Status: http://localhost:8080/status

## 🐳 Docker Deployment

```bash
# Build image
docker build -t vmess-sinbox .

# Run container
docker run -d \
  --name vmess-sinbox \
  -p 8080:8080 \
  -e UUID="your-uuid" \
  -e ARGO_DOMAIN="your-domain" \
  -e ARGO_AUTH="your-token" \
  -e NEZHA_SERVER="nezha.example.com:8008" \
  -e NEZHA_KEY="your-key" \
  -e CHAT_ID="your-chat-id" \
  vmess-sinbox

# Check logs
docker logs -f vmess-sinbox
```

## 📊 Verify Deployment

### 1. Check HTTP Endpoint

```bash
curl https://your-app.cfapps.example.com/
# Should return: Hello World
```

### 2. Get Subscription

```bash
curl https://your-app.cfapps.example.com/sub
# Should return: vmess://base64encodedstring
```

### 3. Check Service Status

```bash
curl https://your-app.cfapps.example.com/status
# Should return JSON with service status
```

### 4. Verify Telegram Notification

You should receive a Telegram message with:
- ✅ Service started successfully
- 🔗 Subscription link
- 🌐 Domain information
- 🆔 UUID
- 📡 Port

## 🔧 Troubleshooting

### Issue: Subscription Not Available

**Solution**: Wait 10-15 seconds after startup for services to initialize.

```bash
# Check logs
cf logs my-vmess-app --recent
```

### Issue: Nezha Agent Not Connecting

**Check:**
1. NEZHA_SERVER format matches your version (v0 or v1)
2. NEZHA_KEY is correct
3. Network connectivity to Nezha server

```bash
# View Nezha logs
curl https://your-app.cfapps.example.com/logs
```

### Issue: Argo Tunnel Not Working

**Check:**
1. ARGO_AUTH token is valid
2. ARGO_DOMAIN is correctly configured in Cloudflare
3. Port in Cloudflare matches ARGO_PORT (default: 8001)

### Issue: No Telegram Notifications

**Check:**
1. CHAT_ID is correct
2. BOT_TOKEN is valid (if using custom bot)
3. Bot has permission to send messages

## 📝 Configuration Reference

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| UUID | Yes | auto-generated | Vmess UUID |
| ARGO_DOMAIN | No | (temporary) | Fixed tunnel domain |
| ARGO_AUTH | No | (temporary) | Tunnel token |
| ARGO_PORT | No | 8001 | Vmess service port |
| NEZHA_SERVER | No | - | Nezha server address |
| NEZHA_PORT | No | - | Nezha port (v0 only) |
| NEZHA_KEY | No | - | Nezha secret key |
| CHAT_ID | No | - | Telegram chat ID |
| BOT_TOKEN | No | - | Telegram bot token |
| CFIP | No | cf.877774.xyz | Cloudflare IP/domain |
| CFPORT | No | 443 | Client connection port |
| SUB_PATH | No | sub | Subscription endpoint path |
| NAME | No | SAP | Service name |

## 🎯 Next Steps

1. **Import Subscription**: Copy the subscription link to your Vmess client
2. **Monitor Services**: Check Nezha dashboard for metrics
3. **Set Up Auto-Restart**: Use keep.sh for automatic monitoring
4. **Optimize Performance**: Adjust ARGO_PORT and CFIP based on your needs

## 📚 Additional Resources

- [Full Documentation](README-SINBOX.md)
- [Main README](README.md)
- [Telegram Group](https://t.me/eooceu)

## ⚠️ Important Notes

1. **UUID Security**: Use a unique UUID for each deployment
2. **Subscription Privacy**: Set a custom SUB_PATH to prevent leaks
3. **Resource Limits**: SAP free tier has 256MB memory limit
4. **Auto-Healing**: Services restart automatically every 30s if crashed

---

**Need Help?** Join our [Telegram Group](https://t.me/eooceu) or open an issue on GitHub.
