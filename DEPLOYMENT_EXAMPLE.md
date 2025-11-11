# Vmess-Argo Optimized Deployment Example

## Quick Start

### Option 1: Using the Optimized Script Directly

This example shows how to deploy the optimized `vmess-argo.sh` script directly in your Docker image for SAP Cloud Foundry.

#### Dockerfile

```dockerfile
FROM alpine:latest

# Install dependencies
RUN apk add --no-cache \
    bash \
    curl \
    wget \
    unzip \
    ca-certificates \
    python3 \
    busybox

# Create necessary directories
RUN mkdir -p /opt/xray /opt/cloudflared /opt/work /var/log/services

# Copy the optimized startup script
COPY vmess-argo.sh /opt/vmess-argo.sh
RUN chmod +x /opt/vmess-argo.sh

# Set environment variables (these should be set via Cloud Foundry)
ENV UUID=""
ENV ARGO_PORT="8001"
ENV SUB_PATH="sub"
ENV CPU_THRESHOLD="75"
ENV XRAY_LOG_LEVEL="info"
ENV GRACEFUL_PAUSE_DURATION="10"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8000/ || exit 1

# Use port 8000 for health check, 8001 for Argo tunnel
EXPOSE 8000 8001 8080

# Run the optimized script
CMD ["/opt/vmess-argo.sh"]
```

### Option 2: Integration with Cloud Foundry Deployment

Modify your GitHub Actions workflow to deploy with optimization settings:

#### SAP Cloud Foundry Deployment Workflow

```yaml
- name: Deploy Optimized Vmess-Argo
  run: |
    if cf push ${{ env.APP_NAME }} \
      --docker-image ${{ env.DOCKER_IMAGE }} \
      -m ${{ env.MEMORY }} \
      -k 256M \
      --health-check-type port \
      --health-check-http-endpoint /; then
      echo "Deployment successful"
    else
      cf delete ${{ env.APP_NAME }} -r -f
      echo "Deployment failed"
      exit 1
    fi

- name: Configure CPU Optimization
  run: |
    # Set environment variables for CPU optimization
    cf set-env ${{ env.APP_NAME }} CPU_THRESHOLD "75"
    cf set-env ${{ env.APP_NAME }} XRAY_LOG_LEVEL "info"
    cf set-env ${{ env.APP_NAME }} GRACEFUL_PAUSE_DURATION "10"
    cf set-env ${{ env.APP_NAME }} CPU_CHECK_INTERVAL "5"
    
    # Basic proxy settings
    cf set-env ${{ env.APP_NAME }} UUID "${{ secrets.UUID }}"
    cf set-env ${{ env.APP_NAME }} ARGO_PORT "8001"
    cf set-env ${{ env.APP_NAME }} SUB_PATH "${{ secrets.SUB_PATH || 'sub' }}"
    
    # Optional: Argo fixed tunnel
    cf set-env ${{ env.APP_NAME }} ARGO_DOMAIN "${{ secrets.ARGO_DOMAIN }}"
    cf set-env ${{ env.APP_NAME }} ARGO_AUTH "${{ secrets.ARGO_AUTH }}"
    
    # Monitoring integration (optional)
    cf set-env ${{ env.APP_NAME }} NEZHA_SERVER "${{ secrets.NEZHA_SERVER }}"
    cf set-env ${{ env.APP_NAME }} NEZHA_KEY "${{ secrets.NEZHA_KEY }}"

- name: Restage and Monitor
  run: |
    cf restage ${{ env.APP_NAME }}
    sleep 10
    
    # Check application status
    cf app ${{ env.APP_NAME }}
```

## Performance Configuration Profiles

### Profile 1: Free Trial (256MB, 1 CPU)

Recommended for minimal resource usage:

```bash
# Set for maximum optimization
CPU_THRESHOLD=65          # More aggressive CPU limiting
XRAY_LOG_LEVEL=error      # Minimal logging
GRACEFUL_PAUSE_DURATION=15  # Longer pause to cool down
CLOUDFLARED_RETRIES=2     # Fewer retries to save CPU
```

### Profile 2: Standard (512MB, 2 CPU)

Balanced performance and stability:

```bash
# Default optimizations
CPU_THRESHOLD=75
XRAY_LOG_LEVEL=info
GRACEFUL_PAUSE_DURATION=10
CLOUDFLARED_RETRIES=3
```

### Profile 3: High Traffic (1GB+, 4+ CPU)

For maximum throughput:

```bash
# Allow higher CPU usage
CPU_THRESHOLD=80
XRAY_LOG_LEVEL=info
GRACEFUL_PAUSE_DURATION=8
CLOUDFLARED_RETRIES=4
```

## Deployment Commands

### Deploy to SAP Cloud Foundry

```bash
# 1. Build and push Docker image
docker build -t your-registry/vmess-argo:latest .
docker push your-registry/vmess-argo:latest

# 2. Deploy to SAP Cloud
cf login -a https://api.cf.us10-001.hana.ondemand.com \
  -u your-email@example.com \
  -p your-password

# 3. Target organization and space
cf target -o your-org -s your-space

# 4. Deploy the application
cf push vmess-app \
  --docker-image your-registry/vmess-argo:latest \
  -m 256M \
  -k 256M \
  --health-check-type port

# 5. Set environment variables
cf set-env vmess-app UUID "your-uuid-here"
cf set-env vmess-app CPU_THRESHOLD "75"
cf set-env vmess-app XRAY_LOG_LEVEL "info"

# 6. Restage application
cf restage vmess-app
```

### Monitor Running Application

```bash
# View application status
cf app vmess-app

# View application logs
cf logs vmess-app --recent

# View realtime logs
cf logs vmess-app

# Check resource usage
cf stats vmess-app

# SSH into application (if enabled)
cf ssh vmess-app

# Inside the container:
ps aux | grep -E "(cloudflared|xray)"
top -b -n 1 | head -20
cat /var/log/services/cloudflared.log
```

## Environment Variables Reference

### Required Variables

| Variable | Example | Description |
|----------|---------|-------------|
| `UUID` | `550e8400-e29b-41d4-a716-446655440000` | VMess protocol UUID |

### Optional Tunnel Variables

| Variable | Example | Description |
|----------|---------|-------------|
| `ARGO_DOMAIN` | `tunnel.example.com` | Fixed Cloudflare tunnel domain |
| `ARGO_AUTH` | `{"tunnel_token":"..."}` | Cloudflare tunnel authentication |
| `ARGO_PORT` | `8001` | Port for Argo tunnel (default: 8001) |

### Proxy Configuration Variables

| Variable | Example | Description |
|----------|---------|-------------|
| `SUB_PATH` | `sub` | Subscription path for node sharing |
| `CFIP` | `cf.example.com` | Preferred CF IP/domain |
| `CFPORT` | `443` | Preferred CF port |

### Optimization Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CPU_THRESHOLD` | `75` | CPU usage percentage before throttling (50-85) |
| `CPU_CHECK_INTERVAL` | `5` | CPU check frequency in seconds (3-10) |
| `GRACEFUL_PAUSE_DURATION` | `10` | Pause duration in seconds when CPU threshold exceeded (5-30) |
| `XRAY_LOG_LEVEL` | `info` | Xray logging level: `error`, `info`, `warning` |
| `CLOUDFLARED_RETRIES` | `3` | Number of retries for Cloudflared (1-5) |

### Monitoring Integration (Optional)

| Variable | Example | Description |
|----------|---------|-------------|
| `NEZHA_SERVER` | `nezha.example.com:8008` | Nezha monitoring server |
| `NEZHA_KEY` | `your-client-secret` | Nezha authentication key |

## Health Check Configuration

### Endpoint: Health Check (Port 8000)

```bash
GET http://app-domain:8000/
Response: Hello World HTML page
Status: 200 OK
```

### Cloud Foundry Health Check Setup

```bash
# Port-based health check (recommended)
cf push vmess-app ... --health-check-type port

# HTTP endpoint health check
cf push vmess-app ... --health-check-type http --health-check-http-endpoint /

# Process health check
cf push vmess-app ... --health-check-type process
```

## Testing and Verification

### 1. Verify Services are Running

```bash
# SSH into the application
cf ssh vmess-app

# Check if services are running
ps aux | grep -E "cloudflared|xray"

# Output should show both cloudflared and xray processes
```

### 2. Test Connectivity

```bash
# Test web server (health check endpoint)
curl http://localhost:8000/

# Test Xray proxy
curl --socks5 localhost:8080 https://www.example.com

# Test Argo tunnel status
curl http://localhost:8001/
```

### 3. Monitor CPU Usage

```bash
# Real-time CPU monitoring
top -b -n 1 | head -20

# Per-process CPU usage
ps aux --sort=-%cpu | head -10

# Monitor specific services
watch -n 1 'ps aux | grep -E "cloudflared|xray" | grep -v grep'
```

### 4. Check Logs

```bash
# Cloudflared logs
tail -f /var/log/services/cloudflared.log

# Xray logs
tail -f /var/log/services/xray.log
tail -f /var/log/services/xray_access.log
tail -f /var/log/services/xray_error.log

# Watch for high CPU events
grep "High CPU" /var/log/services/*.log
```

### 5. YouTube Streaming Test

```bash
# On a client machine with access to the proxy
export SOCKS5_SERVER=app-domain:8001

# Test with curl
curl -x socks5://app-domain:8001 https://www.youtube.com -I

# Test with actual YouTube client
# Use the Xray config in a client like V2RayN, Clash, etc.
# Deploy the node subscription and test with YouTube app
```

## Troubleshooting

### Issue: High CPU Still Occurring

**Diagnosis:**
```bash
# Check which process is consuming CPU
top -b -n 1 | head -20

# Check CPU monitoring logs
grep "High CPU" /var/log/services/*.log

# Verify CPU threshold is set correctly
cf env vmess-app | grep CPU_THRESHOLD
```

**Solution:**
```bash
# Lower CPU threshold
cf set-env vmess-app CPU_THRESHOLD "65"

# Increase pause duration
cf set-env vmess-app GRACEFUL_PAUSE_DURATION "15"

# Reduce logging
cf set-env vmess-app XRAY_LOG_LEVEL "error"

# Restage
cf restage vmess-app
```

### Issue: Services Not Starting

**Diagnosis:**
```bash
# Check recent logs
cf logs vmess-app --recent

# SSH and check directly
cf ssh vmess-app
ps aux | grep -E "cloudflared|xray"

# Check if downloads succeeded
ls -la /opt/xray/
ls -la /opt/cloudflared/
```

**Solution:**
```bash
# Ensure UUID is set
cf set-env vmess-app UUID "your-uuid"

# Try manual restart
cf restart vmess-app

# Check network connectivity
curl -I https://github.com

# Review configuration files
cat /opt/xray/config.json
cat /opt/cloudflared/config.yaml
```

### Issue: Memory Usage Increasing

**Diagnosis:**
```bash
# Monitor memory over time
while true; do cf stats vmess-app; sleep 60; done

# Check for connection leaks
netstat -an | wc -l
```

**Solution:**
```bash
# Reduce idle connection timeout
# Edit /opt/xray/config.json and reduce "connIdle" from 30 to 20

# Restart services
cf restart vmess-app

# Schedule periodic restarts
cf update-app vmess-app --strategy rolling
```

## Advanced Optimization

### Custom Xray Config

If you need more control, modify the Xray config generation in the script:

```json
{
  "policy": {
    "levels": {
      "0": {
        "handshake": 3,
        "connIdle": 20,
        "uplinkOnly": 0,
        "downlinkOnly": 0
      }
    }
  }
}
```

### Custom Cloudflared Config

Edit the config generation in the script:

```yaml
grace-period: 20s
max-idle-connections: 5
retries: 2
retry-timeout: 20s
```

### System Tuning

The script automatically applies TCP tuning, but you can verify:

```bash
# Check current TCP settings
sysctl net.ipv4.tcp_max_syn_backlog
sysctl net.core.somaxconn
sysctl net.ipv4.tcp_tw_reuse
```

## Success Indicators

After successful deployment with optimization:

✅ Application shows "Hello World" on health check endpoint  
✅ Xray and Cloudflared processes running with `nice` priority  
✅ CPU usage stable below `CPU_THRESHOLD` (typically 65-75%)  
✅ Memory usage stable between 80-150MB  
✅ YouTube can be streamed by multiple users simultaneously  
✅ No "High CPU" platform termination errors  
✅ Service auto-recovers if individual process fails  
✅ Graceful pause occurs without user-visible impact  

## References

- [Optimization Guide](./OPTIMIZATION_GUIDE.md)
- [Cloudflared Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Xray Documentation](https://xtls.github.io/)
- [SAP Cloud Foundry CLI Reference](https://help.sap.com/docs/btp/sap-business-technology-platform/command-line-interface)
