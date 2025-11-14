# Debug Script Usage Guide

## 问题场景

当 `start.sh` 在 zampto 等控制台环境中运行时，可能遇到以下问题：
- 脚本没有任何输出
- 不知道在哪一步失败
- 无法判断是下载失败、配置失败还是启动失败

## 解决方案

使用 `start.sh.debug` 调试版本，它会在每个关键步骤前后输出详细日志。

## 使用方法

### 方法 1: 直接运行并保存日志

```bash
cd sin-box
bash start.sh.debug 2>&1 | tee debug_output.log
```

这会：
- 实时显示所有输出到终端
- 同时保存完整日志到 `debug_output.log` 文件
- 捕获所有错误信息（stderr + stdout）

### 方法 2: 后台运行

```bash
cd sin-box
nohup bash start.sh.debug > debug_output.log 2>&1 &
```

然后可以随时查看日志：
```bash
tail -f debug_output.log
```

## 输出示例

### 成功启动的输出

```
==========================================
  sin-box Xray Runner - DEBUG VERSION
==========================================
[2024-01-15 10:30:00] Initialization started at Mon Jan 15 10:30:00 UTC 2024
[2024-01-15 10:30:00] Script directory: /app/sin-box
[2024-01-15 10:30:00] System: Linux 5.15.0-91-generic x86_64
==========================================

==================================================
[STEP 1] Setting up directories...
==================================================
[2024-01-15 10:30:00] Creating directories:
[2024-01-15 10:30:00]   - BIN_DIR: /app/sin-box/bin
[2024-01-15 10:30:00]   - LOG_DIR: /app/sin-box/logs
[2024-01-15 10:30:00]   - NPM_DIR: /app/sin-box/.npm
[2024-01-15 10:30:00]   - ETC_DIR: /app/sin-box/etc
✓ Directories created successfully
[2024-01-15 10:30:00]   ✓ /app/sin-box/bin
[2024-01-15 10:30:00]   ✓ /app/sin-box/logs
[2024-01-15 10:30:00]   ✓ /app/sin-box/.npm
[2024-01-15 10:30:00]   ✓ /app/sin-box/etc

==================================================
[STEP 2] Validating environment...
==================================================
✓ Architecture detected: amd64
[2024-01-15 10:30:00] UUID not provided, generating new one...
✓ UUID generated: 8a3c4b5d-7e9f-4a1b-8c2d-3e4f5a6b7c8d

[2024-01-15 10:30:00] Environment configuration:
[2024-01-15 10:30:00]   UUID:         8a3c4b5d-7e9f-4a1b-8c2d-3e4f5a6b7c8d
[2024-01-15 10:30:00]   CFIP:         not set
[2024-01-15 10:30:00]   CFPORT:       443
[2024-01-15 10:30:00]   DISABLE_ARGO: 0
[2024-01-15 10:30:00]   ARGO_DOMAIN:  not set
[2024-01-15 10:30:00]   ARGO_AUTH:    
[2024-01-15 10:30:00]   SERVER_PORT:  3000
✓ Environment validated

==================================================
[STEP 3] Downloading Xray binary...
==================================================
[2024-01-15 10:30:01] Detected architecture: amd64
[2024-01-15 10:30:01] Fetching Xray release information from GitHub...
[2024-01-15 10:30:01]   Attempt 1/3...
✓ Release information fetched
[2024-01-15 10:30:02] Latest Xray version: v1.8.8
[2024-01-15 10:30:02] Download URL: https://github.com/XTLS/Xray-core/releases/download/v1.8.8/Xray-linux-64.zip
[2024-01-15 10:30:02] Using temporary directory: /tmp/tmp.xABcD123
[2024-01-15 10:30:02] Downloading Xray...
✓ Download complete
[2024-01-15 10:30:05] Extracting Xray...
✓ Extraction complete
[2024-01-15 10:30:05] Installing Xray binary to /app/sin-box/bin/xray...
[2024-01-15 10:30:05] Stripping binary to reduce size...
✓ Xray installed successfully at: /app/sin-box/bin/xray
[2024-01-15 10:30:05] Installed version: Xray 1.8.8 (Xray, Penetrates Everything.) Custom (go1.21.5 linux/amd64)

==================================================
[STEP 4] Generating Xray configuration...
==================================================
[2024-01-15 10:30:05] Creating config file at: /app/sin-box/etc/xray-config.json
[2024-01-15 10:30:05] UUID: 8a3c4b5d-7e9f-4a1b-8c2d-3e4f5a6b7c8d
[2024-01-15 10:30:05] Port: 10000
[2024-01-15 10:30:05] Protocol: vmess
[2024-01-15 10:30:05] Network: ws
[2024-01-15 10:30:05] Path: /ws
[2024-01-15 10:30:05] Injecting UUID into configuration...
✓ Configuration generated and UUID injected successfully

==================================================
[STEP 5] Starting Xray...
==================================================
[2024-01-15 10:30:05] Log file: /app/sin-box/logs/xray.log
[2024-01-15 10:30:05] Starting Xray process...
[2024-01-15 10:30:05] Using nice for process priority optimization
[2024-01-15 10:30:05] Xray started with PID: 12345
[2024-01-15 10:30:05] Waiting 2 seconds for Xray to initialize...
✓ Xray is running (PID: 12345)

...继续其他步骤...

==================================================
  ✓ ALL SERVICES STARTED SUCCESSFULLY
==================================================
[2024-01-15 10:30:20] Summary:
[2024-01-15 10:30:20]   - Xray:        PID 12345 (port 10000)
[2024-01-15 10:30:20]   - Cloudflared: PID 12346
[2024-01-15 10:30:20]   - Node server: PID 12347 (port 3000)
[2024-01-15 10:30:20] 
[2024-01-15 10:30:20] Logs are available in: /app/sin-box/logs
[2024-01-15 10:30:20]   - xray.log
[2024-01-15 10:30:20]   - cloudflared.log
[2024-01-15 10:30:20]   - node.log
==================================================
```

### 失败时的输出

```
==================================================
[STEP 3] Downloading Xray binary...
==================================================
[2024-01-15 10:30:01] Detected architecture: amd64
[2024-01-15 10:30:01] Fetching Xray release information from GitHub...
[2024-01-15 10:30:01]   Attempt 1/3...
[2024-01-15 10:30:03]   Failed, retrying in 2 seconds...
[2024-01-15 10:30:05]   Attempt 2/3...
[2024-01-15 10:30:07]   Failed, retrying in 2 seconds...
[2024-01-15 10:30:09]   Attempt 3/3...
✗ Failed to fetch Xray release information after 3 attempts
[2024-01-15 10:30:09] Network error or GitHub API unavailable
```

## 输出格式说明

### 步骤标记
- `[STEP N]` - 主要步骤编号（1-10）
- `==================================================` - 步骤分隔线

### 状态指示
- `✓` - 操作成功
- `✗` - 操作失败
- `[2024-01-15 10:30:00]` - 时间戳

### 重要信息
每个步骤会显示：
- 正在执行的操作
- 关键配置参数
- 执行结果（成功/失败）
- 错误日志内容（如果失败）
- 进程 PID 和版本信息

## 步骤说明

1. **STEP 1: Setup directories** - 创建 bin, logs, .npm, etc 目录
2. **STEP 2: Validate environment** - 检测架构、生成/验证 UUID
3. **STEP 3: Download Xray** - 从 GitHub 下载 Xray 二进制文件
4. **STEP 4: Generate Xray config** - 生成 Xray 配置文件并注入 UUID
5. **STEP 5: Start Xray** - 启动 Xray 并验证进程
6. **STEP 6: Setup Cloudflared** - 下载 Cloudflared（如果需要）
7. **STEP 7: Start Cloudflared** - 启动 Cloudflared 隧道（如果需要）
8. **STEP 8: Start Node server** - 启动 HTTP 订阅服务器
9. **STEP 9: Generate subscription** - 生成 VMess 订阅链接
10. **STEP 10: Start watchdog** - 启动进程监控守护程序

## 常见问题诊断

### 问题：脚本在 STEP 3 卡住或失败
**可能原因**：
- 网络无法访问 GitHub
- DNS 解析问题
- GitHub API 限流

**解决方法**：
- 检查网络连接：`curl -I https://api.github.com`
- 使用代理或镜像
- 等待几分钟后重试

### 问题：STEP 5 Xray 启动失败
**可能原因**：
- unzip 未安装
- 架构不支持
- 配置文件格式错误

**解决方法**：
- 查看日志中显示的 `xray.log` 内容
- 检查架构：`uname -m`
- 安装 unzip：`apt-get install unzip`

### 问题：STEP 7 Cloudflared 无法提取 URL
**可能原因**：
- Cloudflared 需要更长的初始化时间
- 隧道建立失败
- 日志格式变化

**解决方法**：
- 查看 `cloudflared.log` 详细内容
- 等待 10-15 秒后检查 `.npm/sub.txt` 是否更新
- 考虑使用固定 Argo 隧道（设置 ARGO_DOMAIN 和 ARGO_AUTH）

### 问题：STEP 8 Node 服务器启动失败
**可能原因**：
- Node.js 未安装或版本不兼容
- index.js 文件缺失或损坏
- 端口被占用

**解决方法**：
- 检查 Node 版本：`node --version`（需要 v14+）
- 确认 index.js 存在：`ls -l sin-box/index.js`
- 更改端口：`export SERVER_PORT=3001`

## 与原版 start.sh 的区别

| 特性 | start.sh | start.sh.debug |
|------|----------|----------------|
| 输出详细程度 | 基本日志 | 详细步骤日志 |
| 步骤标记 | 无 | [STEP N] |
| 成功/失败指示 | 无 | ✓/✗ |
| 进程验证 | 有 | 有 + 详细输出 |
| 错误日志显示 | 仅在失败时 | 立即显示 |
| 版本信息 | 无 | 显示所有版本 |
| 环境变量摘要 | 基本 | 完整详细 |
| 生产环境使用 | 推荐 | 不推荐（日志过多）|
| 故障排查 | 困难 | 简单 |

## 建议

1. **首次部署**：始终使用 `start.sh.debug` 确保一切正常
2. **生产环境**：确认无误后使用 `start.sh`（日志更少，性能更好）
3. **故障排查**：遇到问题立即切换到 `start.sh.debug`
4. **保存日志**：使用 `tee` 命令保存日志以便后续分析
5. **定期检查**：即使使用 `start.sh`，也要定期查看 `logs/` 目录中的日志文件

## 技术支持

如果使用 debug 脚本后仍然无法解决问题：
1. 保存完整的 `debug_output.log` 文件
2. 收集 `logs/` 目录中的所有日志文件
3. 提供环境信息（操作系统、内存、网络条件）
4. 提交 issue 时附上这些信息
