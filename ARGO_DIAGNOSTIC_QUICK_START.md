# Argo Diagnostic Script - Quick Start Guide

## English

### Setup (5 minutes)

1. **Create config file** at `/home/container/config.json`:
```json
{
  "ARGO_PORT": "27039"
}
```

2. **Run the script**:
```bash
./argo-diagnostic.sh
```

### What You'll See

Every step will print with timestamps and status:
```
[2025-11-16 15:30:45] [INFO] Starting Argo Tunnel Setup for Zampto
[2025-11-16 15:30:46] [INFO] Loading configuration...
[2025-11-16 15:30:47] [✅ SUCCESS] Keepalive server started (PID: 12345)
[2025-11-16 15:30:55] [✅ SUCCESS] Cloudflared downloaded
[2025-11-16 15:31:00] [✅ SUCCESS] Tunnel URL: https://xxxx.trycloudflare.com
```

### Verify It Works

```bash
# Check services are running
ps aux | grep -E "(cloudflared|python3.*http)"

# Test the tunnel
curl -v https://your-tunnel-url.trycloudflare.com/
```

### Use Fixed Domain (Optional)

If you have a Cloudflare domain and token, update config:
```json
{
  "CF_DOMAIN": "zampto.example.com",
  "CF_TOKEN": "account_id:tunnel_secret:tunnel_id",
  "ARGO_PORT": "27039"
}
```

---

## 中文 (Chinese)

### 设置 (5分钟)

1. **创建配置文件** `/home/container/config.json`:
```json
{
  "ARGO_PORT": "27039"
}
```

2. **运行脚本**:
```bash
./argo-diagnostic.sh
```

### 会看到什么

每个步骤都会打印时间戳和状态:
```
[2025-11-16 15:30:45] [INFO] 启动 Zampto Argo 隧道设置
[2025-11-16 15:30:46] [INFO] 加载配置...
[2025-11-16 15:30:47] [✅ SUCCESS] Keepalive 服务器已启动 (PID: 12345)
[2025-11-16 15:30:55] [✅ SUCCESS] Cloudflared 已下载
[2025-11-16 15:31:00] [✅ SUCCESS] 隧道 URL: https://xxxx.trycloudflare.com
```

### 验证是否工作

```bash
# 检查服务是否运行
ps aux | grep -E "(cloudflared|python3.*http)"

# 测试隧道
curl -v https://your-tunnel-url.trycloudflare.com/
```

### 使用固定域名 (可选)

如果你有 Cloudflare 域名和令牌，更新配置:
```json
{
  "CF_DOMAIN": "zampto.example.com",
  "CF_TOKEN": "account_id:tunnel_secret:tunnel_id",
  "ARGO_PORT": "27039"
}
```

---

## Common Issues & Solutions

### Python3 not found?
**Solution**: Install it with `apt-get install python3` or `apk add python3`

### Port 27039 already in use?
**Solution**: Change ARGO_PORT in config.json or stop the other service

### Cloudflared download fails?
**Solution**: Check network: `curl -I https://github.com`

### Services stop unexpectedly?
**Solution**: The script logs warnings every 60 seconds. Check `/home/container/argo-tuic/logs/cloudflared.log`

---

## Files Created

- `/home/container/argo-tuic/` - Work directory
- `/home/container/argo-tuic/bin/cloudflared` - Binary
- `/home/container/argo-tuic/logs/` - Log files
- `/home/container/argo-tuic/keepalive.pid` - Service PID
- `/home/container/argo-tuic/tunnel.url` - Tunnel address

---

## Running in Background

```bash
# With nohup
nohup ./argo-diagnostic.sh > /tmp/argo.log 2>&1 &

# Check logs
tail -f /tmp/argo.log

# Stop
pkill -f argo-diagnostic
```

---

## Debug Mode

For more detailed output:
```bash
DEBUG=1 ./argo-diagnostic.sh
```

---

## Key Differences from v1.0.0

- ✅ Better logging (timestamps on every line)
- ✅ Simpler scope (core services only)
- ✅ More diagnostic output
- ✅ Better error messages
- ✅ Debug mode support

---

**Still have questions?** Check ARGO_DIAGNOSTIC_GUIDE.md for complete documentation.
