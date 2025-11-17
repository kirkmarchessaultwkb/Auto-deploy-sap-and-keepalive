# start.sh v2.2 - Execution Flow Fix

## 问题分析

### 原始问题 (v1.2)
当前日志显示：
```
[2025-11-17 14:02:43] [INFO] === Zampto Startup Script ===
[2025-11-17 14:02:43] [INFO] Loading config.json...
```
然后就停了，没有继续。

### 根本原因
第2行的 `set -euo pipefail` 导致任何命令失败都会立即退出脚本：
```bash
#!/bin/bash
set -euo pipefail  # ❌ 这是问题所在！

# 之后的 grep 命令如果没有匹配到，会返回非零，脚本立即退出
CF_DOMAIN=$(grep -o '"cf_domain":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
# 如果没有匹配，grep返回1，脚本停止
```

## 修复方案 (v2.2)

### 1. 移除 `set -e` ❌→✅
```bash
#!/bin/bash
# ✅ 不要 set -e，手动处理错误
```

### 2. grep 命令添加 fallback
```bash
# ❌ 旧方式 - 失败时脚本停止
CF_DOMAIN=$(grep -o '"cf_domain":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)

# ✅ 新方式 - 失败时返回空字符串
CF_DOMAIN=$(grep -o '"cf_domain":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4 || echo "")
```

### 3. 添加 log_warn() 用于非阻塞错误
```bash
log_warn() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [WARN] $1" >&2
}
```

哪吒失败现在使用 log_warn 而不是 log_error：
```bash
if curl -fsSL -o /tmp/nezha/nezha-agent.tar.gz "$NEZHA_URL" 2>/dev/null; then
    # ...
else
    log_warn "Nezha agent download failed (non-blocking, continuing...)"
    # ✅ 继续执行，不中断
fi
```

### 4. 改进的目录创建
```bash
mkdir -p /tmp/nezha || {
    log_warn "Failed to create /tmp/nezha directory (non-blocking)"
}
```

## 执行流程 (v2.2)

```
start.sh v2.2
│
├─ 1️⃣ 显示启动信息
│   └─ [INFO] === Zampto Startup Script v2.2 ===
│   └─ [INFO] Loading config.json...
│
├─ 2️⃣ 验证 config.json 存在 (❌如果失败 → exit 1)
│
├─ 3️⃣ 读取配置 (所有 grep 都有 || echo "" 防止失败)
│   ├─ CF_DOMAIN
│   ├─ CF_TOKEN
│   ├─ UUID
│   ├─ PORT (默认: 27039)
│   ├─ NEZHA_SERVER
│   ├─ NEZHA_PORT (默认: 5555)
│   └─ NEZHA_KEY
│
├─ 4️⃣ 验证必填字段 (CF_DOMAIN 和 UUID)
│   └─ ❌如果失败 → exit 1
│
├─ 5️⃣ 显示加载的配置
│   └─ [INFO] Config loaded successfully:
│
├─ 6️⃣ 导出环境变量 ⭐重要！
│   └─ export CF_DOMAIN CF_TOKEN UUID PORT ...
│
├─ 7️⃣ 启动哪吒 (非阻塞式 - 失败继续)
│   ├─ [INFO] Starting Nezha agent...
│   ├─ 下载、提取、启动
│   └─ ⚠️ 失败时: [WARN] ... (non-blocking, continuing...)
│
├─ 8️⃣ 调用部署脚本 (❌如果不存在 → exit 1)
│   └─ [INFO] Calling wispbyte-argo-singbox-deploy.sh...
│
└─ 9️⃣ 完成
    └─ [INFO] === Startup Completed ===
```

## 关键改进点

| 方面 | v1.2 (旧) | v2.2 (新) |
|------|----------|----------|
| set -e | ✅ 有 (问题!) | ❌ 无 (修复!) |
| grep fallback | 缺少 | ✅ 全部有 `\|\| echo ""` |
| 日志函数 | log_info, log_error | log_info, **log_warn**, log_error |
| 哪吒失败处理 | log_error (可能中断) | log_warn (继续执行) |
| 目录创建失败 | 可能中断 | 非阻塞处理 |
| 执行流程 | 容易中断 | ✅ 健壮不中断 |

## 验收标准 ✅

- ✅ 日志显示 "=== Zampto Startup Script v2.2 ==="
- ✅ 日志显示 "Config loaded successfully"
- ✅ 日志显示 "Starting Nezha agent..."
- ✅ 日志显示 "Calling wispbyte-argo-singbox-deploy.sh..."
- ✅ 脚本不中途停止 (除非config错误)
- ✅ 即使哪吒失败也继续执行

## 文件统计

- **行数**: 116 行 (相比 v1.2 的 94 行，增加了必要的容错机制)
- **行尾**: LF only (✅ 无 CRLF)
- **语法**: ✅ 验证通过 (`bash -n start.sh`)
- **Exit 点**: 3 个 (都是关键的)
  - Line 31: config.json not found
  - Line 50: Missing required config
  - Line 110: wispbyte script not found

## 部署说明

1. **config.json 要求** (必填):
   - `cf_domain`: Cloudflare 隧道域名
   - `uuid`: VMess UUID

2. **可选字段**:
   - `cf_token`: Cloudflare 令牌
   - `port`: 监听端口 (默认: 27039)
   - `nezha_server`: 哪吒服务器
   - `nezha_port`: 哪吒端口 (默认: 5555)
   - `nezha_key`: 哪吒密钥

3. **执行流程**:
   ```bash
   ./start.sh
   # 自动加载配置 → 启动哪吒 → 调用部署脚本
   ```

## 总结

v2.2 解决了v1.2中最严重的问题：`set -e` 导致脚本在任何命令失败时立即停止。

通过移除 `set -e` 并添加适当的错误处理和日志记录，script现在可以：
- ✅ 优雅地处理配置读取
- ✅ 非阻塞式启动可选服务（哪吒）
- ✅ 清晰地输出执行状态
- ✅ 继续执行后续步骤即使中间出现非关键错误
