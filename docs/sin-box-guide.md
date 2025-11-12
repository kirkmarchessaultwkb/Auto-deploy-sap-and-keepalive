# Sin-Box 部署指南（中文）

## 概述

本指南详细介绍如何在 zampto Node（14+ 版本）服务器上部署和运行 `sin-box` 包。sin-box 是一个轻量级代理工具，支持 Argo 隧道、Cloudflare Workers 和直连方式，可用于订阅管理、哪吒监控对接和 Telegram 通知。

**系统要求：**
- Node.js 14+ 
- 至少 2GB RAM
- 稳定网络连接

---

## 前置要求与凭证准备

在开始部署前，请按照以下步骤准备所需的凭证和配置参数。

### 1. UUID（节点唯一标识）

UUID 用于标识节点，建议为每个部署实例生成不同的 UUID，尤其是在使用哪吒 v1 监控时。

**生成 UUID 的方法：**

方法一 - 在线工具（需翻墙）：
- 访问 [UUID Generator](https://www.uuidgenerator.net/)
- 复制生成的 UUID v4

方法二 - 本地生成：

```bash
# Linux/Mac
python3 -c "import uuid; print(str(uuid.uuid4()))"

# 或
node -e "console.log(require('crypto').randomUUID())"
```

**示例：** `550e8400-e29b-41d4-a716-446655440000`

> **重要：** 如果同时运行多个 sin-box 实例，每个实例必须使用不同的 UUID，否则在使用哪吒 v1 时会导致节点被覆盖。

---

### 2. Cloudflare Argo 隧道凭证

#### 2.1 注册和配置 Cloudflare 账户

1. 注册 Cloudflare 账户：[Cloudflare Sign-Up](https://dash.cloudflare.com/sign-up)
2. 添加你的域名到 Cloudflare（需要修改域名 DNS 指向）
3. 完成域名验证

#### 2.2 创建 Argo 隧道（固定隧道）

使用固定隧道的优势是可以获得稳定的域名，不会像临时隧道那样经常更换。

**步骤：**

1. 登录 Cloudflare Dashboard
2. 选择你的域名
3. 进入左侧菜单 **Networks** > **Tunnels**（或搜索 "Tunnel"）
4. 点击 **Create a tunnel** 按钮
5. 选择连接器类型，建议选择 **Cloudflared**
6. 为隧道命名（如 `sin-box-tunnel`）
7. 点击 **Save tunnel**
8. 在下一步，你会获得隧道 Token：

   ```
   ARGO_AUTH=eyJhIjoic2M2N2ZmZGY...（很长的 Base64 编码）
   ```

   **保存此 Token，后续需要配置为 `ARGO_AUTH` 环境变量**

#### 2.3 配置隧道路由

配置隧道将流量转发到本地服务：

1. 在 Tunnel 页面找到你创建的隧道
2. 点击 **Configure** 按钮
3. 在 **Public Hostname** 标签下，点击 **Add a public hostname**
4. 填写以下信息：
   - **Subdomain**：输入子域名（如 `sin-box`），完整域名将为 `sin-box.yourdomain.com`
   - **Domain**：选择你的域名
   - **Service Type**：选择 `HTTP`
   - **URL**：输入 `localhost:8001`（sin-box 默认端口）
5. 点击 **Save** 按钮

**获得的 `ARGO_DOMAIN` 示例：** `sin-box.yourdomain.com`

#### 2.4 获取隧道 Token 的其他方式

如果没有看到 Token，可以：

1. 在 Tunnel 列表中找到你的隧道
2. 点击隧道名称进入详情页
3. 在 **Connectors** 标签下可以看到连接命令，包含完整的 Token

---

### 3. CF IP/CF PORT（优选 IP 和端口）

优选 IP 和端口用于提升 Cloudflare 访问速度。

**如何获取优选 IP：**

1. **测试获最低延迟 IP：**
   ```bash
   # 下载测试工具
   wget https://github.com/XIU2/CloudflareSpeedTest/releases/download/v2.2.5/CloudflareSpeedTest_linux_amd64.zip
   unzip CloudflareSpeedTest_linux_amd64.zip
   ./CloudflareST -l 20  # 测试前 20 个 IP
   ```
   
   或访问 [Cloudflare Speed Test](https://github.com/XIU2/CloudflareSpeedTest) 获取最新版本

2. **从测试结果中选择延迟最低的 IP**（通常以 `104.16.x.x`, `104.17.x.x` 等开头）

3. **常见优选 IP 列表（仅供参考）：**
   ```
   104.16.132.229
   104.17.180.52
   104.21.88.22
   ```

**CF PORT 说明：**

- 如果使用 Argo 隧道，推荐设置 `CFPORT=8001`（与隧道配置一致）
- 如果使用直连模式，常见端口包括 `80`, `8080`, `8081`, `2052`, `2082`, `2086`, `2095`, `8880` 等

---

### 4. 哪吒监控凭证（Nezha v0/v1）

哪吒用于实时监控服务器运行状态。

#### 4.1 部署哪吒面板（如果还没有部署）

哪吒面板部署较为复杂，建议：
- 使用现有的公共哪吒面板服务
- 或在 VPS 上自行部署（参考：[Nezha 官方文档](https://nezha.app)）

#### 4.2 获取哪吒 v1 凭证

1. 登录你的哪吒面板
2. 进入 **设置** > **API 接口**
3. 在 **OAuth 2 应用** 或 **API Token** 部分，创建新的应用或获取 API Token
4. 记录以下信息：

   **NEZHA_SERVER**：面板地址和端口，格式为 `nezha.yourdomain.com:8008`（示例）
   
   **NEZHA_KEY**：
   - v1 版本：使用 `NZ_CLIENT_SECRET`（也可能是 OAuth Token）
   - v0 版本：使用 Agent 密钥或通用密钥

#### 4.3 获取哪吒 v0 凭证

哪吒 v0 的配置方式：

1. 从哪吒面板获取 Agent 通信地址和端口
2. 获取 Agent 密钥（部分配置可能在哪吒面板的 Agent 管理页面）

**环境变量配置示例：**

```bash
# v1 版本
NEZHA_SERVER="nezha.example.com:8008"
NEZHA_KEY="your-v1-token"

# v0 版本
NEZHA_SERVER="nezha.example.com"
NEZHA_PORT="5555"
NEZHA_KEY="your-v0-agent-key"
```

---

### 5. Telegram 机器人配置（可选）

Telegram 可用于接收部署状态通知和错误告警。

#### 5.1 创建 Telegram 机器人

1. 在 Telegram 中搜索 [@BotFather](https://t.me/BotFather)
2. 发送命令 `/start` 开始交互
3. 发送命令 `/newbot` 创建新机器人
4. 按照提示输入机器人名称（如 `sin_box_bot`）
5. 获取 **BOT_TOKEN**，格式如：`123456789:ABCdefGHIjklMNOpqrsTUVwxyz`

#### 5.2 获取 Telegram 频道/群组 ID

1. 将机器人添加到你的私人频道或群组
2. 使用以下方法获取 CHAT_ID：

   **方法一 - 使用 Telegram Bot API：**
   - 向机器人发送任何消息
   - 在浏览器中访问：`https://api.telegram.org/bot<BOT_TOKEN>/getUpdates`
   - 查看返回的 JSON，找到 `"id"` 字段的数值

   **方法二 - 使用 IDBot 工具：**
   - 在 Telegram 中搜索 [@userinfobot](https://t.me/userinfobot)
   - 将该机器人添加到你的频道或群组
   - 它会返回频道/群组的 ID 信息

**注意：** 私人 CHAT_ID 通常是负数，如 `-123456789`

---

### 6. 订阅链接上传（可选）

使用 `UPLOAD_URL` 可以自动上传订阅链接到外部存储，供客户端导入。

**配置方式：**

```bash
UPLOAD_URL="https://your-storage-service.com/upload"
```

支持的上传方式：
- HTTP POST 方式
- 云存储服务（如阿里云 OSS, 腾讯云 COS 等）

详细配置参考下文"可选功能配置"。

---

## 逐步安装指南

### 步骤 1：准备服务器环境

```bash
# 更新系统包
sudo apt update && sudo apt upgrade -y

# 安装 Node.js 14+（如果还未安装）
curl -sL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# 验证 Node.js 版本
node --version  # 应为 v14 或以上
npm --version
```

### 步骤 2：获取 sin-box 包

```bash
# 方式一：从 npm 包管理器安装
npm install -g sin-box

# 方式二：从 GitHub 克隆源码
git clone https://github.com/yourusername/sin-box.git
cd sin-box
npm install
```

### 步骤 3：创建配置文件

在项目目录创建 `.env` 文件来配置环境变量：

```bash
cd ~/sin-box  # 进入 sin-box 项目目录
touch .env
```

### 步骤 4：配置环境变量

编辑 `.env` 文件并填入之前准备的凭证。以下是完整的环境变量说明：

**必须配置的变量：**

```bash
# 节点 UUID（每个实例应不同）
UUID="550e8400-e29b-41d4-a716-446655440000"

# 订阅路径（用于客户端导入订阅）
SUB_PATH="sub"
```

**Argo 隧道配置（二选一）：**

```bash
# 方式一：使用固定隧道
ARGO_DOMAIN="sin-box.yourdomain.com"
ARGO_AUTH="eyJhIjoic2M2N2ZmZGY..."

# 方式二：使用临时隧道（不需要 ARGO_DOMAIN 和 ARGO_AUTH）
# 系统会自动生成临时隧道 URL
```

**哪吒监控配置（可选）：**

```bash
# v1 版本
NEZHA_SERVER="nezha.example.com:8008"
NEZHA_KEY="your-v1-api-token"

# v0 版本（如果使用 v0）
NEZHA_PORT="5555"
```

**直连模式配置（如果使用直连而不是 Argo）：**

```bash
# 优选 CF IP
CFIP="104.16.132.229"

# 对应的优选端口
CFPORT="443"

# 禁用 Argo 隧道
DISABLE_ARGO="true"
```

**Telegram 通知配置（可选）：**

```bash
TELEGRAM_BOT_TOKEN="123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
TELEGRAM_CHAT_ID="-123456789"
```

**订阅上传配置（可选）：**

```bash
UPLOAD_URL="https://your-storage-service.com/upload"
UPLOAD_TOKEN="your-upload-api-token"
```

### 步骤 5：启动服务

```bash
# 使用 npm 直接运行
npm start

# 或使用 PM2 进程管理器（推荐用于生产环境）
npm install -g pm2
pm2 start npm --name "sin-box" -- start
pm2 save
pm2 startup
```

**验证启动成功：**

```bash
# 检查是否监听 8001 端口
netstat -tulpn | grep 8001
# 或
curl http://localhost:8001
```

---

## 功能验证和测试

### 验证 1：HTTP 服务验证

```bash
# 测试本地访问
curl http://localhost:8001

# 测试订阅链接
curl http://localhost:8001/sub

# 检查返回的订阅内容（应包含代理配置）
```

### 验证 2：Argo 隧道连接

如果配置了 Argo 隧道：

1. 在 Cloudflare 面板中检查隧道状态：
   - Dashboard > Networks > Tunnels
   - 隧道状态应显示 **Connected**

2. 从外网访问你的隧道域名：
   ```bash
   curl https://sin-box.yourdomain.com
   ```

3. 检查延迟和连接质量

### 验证 3：订阅链接导入

在代理客户端中测试导入订阅：

1. 打开代理客户端（如 Clash, V2rayN, Surge 等）
2. 使用订阅 URL：`http://your-server-ip:8001/sub` 或 `https://sin-box.yourdomain.com/sub`
3. 导入订阅链接
4. 测试连接是否成功

### 验证 4：哪吒监控集成

如果配置了哪吒监控：

1. 登录哪吒面板
2. 检查 sin-box 节点是否出现在在线节点列表中
3. 查看节点的 CPU、内存、网络等实时数据

### 验证 5：Telegram 通知测试

手动触发测试消息：

```bash
# 在 sin-box 的源码中手动调用通知函数（需要修改源码）
# 或等待部署完成后自动发送通知
```

### 验证 6：日志检查

```bash
# 查看实时日志
tail -f logs/sin-box.log

# 或使用 PM2 查看日志
pm2 logs sin-box

# 查看错误日志
tail -f logs/error.log
```

---

## 常见问题和故障排除

### 问题 1：Argo 隧道认证失败

**症状：** 启动时显示 "Tunnel authentication failed" 或 "Invalid ARGO_AUTH"

**排查步骤：**

```bash
# 检查 ARGO_AUTH 和 ARGO_DOMAIN 是否正确
echo $ARGO_AUTH
echo $ARGO_DOMAIN

# 检查 .env 文件的编码和格式
file .env

# 确保没有多余的引号或空格
cat .env | grep ARGO

# 验证 Cloudflare 隧道在面板中是否仍然存在且处于启用状态
```

**解决方案：**

1. 重新从 Cloudflare 面板复制 Token，确保完整无误
2. 删除旧的隧道，创建新隧道并获取新的 Token
3. 检查 Cloudflare 账户是否还有效（是否过期）

### 问题 2：哪吒握手错误

**症状：** 日志显示 "Nezha handshake failed" 或 "Connection refused"

**排查步骤：**

```bash
# 测试哪吒服务器连接
telnet nezha.example.com 8008

# 或使用 curl 测试 API
curl -v http://nezha.example.com:8008/api/...

# 检查哪吒凭证
echo $NEZHA_SERVER
echo $NEZHA_KEY

# 查看详细错误日志
tail -f logs/sin-box.log | grep -i nezha
```

**解决方案：**

1. 确认哪吒面板服务器地址和端口正确
2. 验证 API Token/密钥是否有效和未过期
3. 检查防火墙是否允许与哪吒服务器通信
4. 确保 v0/v1 版本配置匹配（不要混用 v0 和 v1 的参数）

### 问题 3：Telegram 消息发送失败

**症状：** 没有收到 Telegram 通知，日志显示 "Telegram API error"

**排查步骤：**

```bash
# 验证 BOT_TOKEN 和 CHAT_ID
echo $TELEGRAM_BOT_TOKEN
echo $TELEGRAM_CHAT_ID

# 测试 Telegram API 连接
curl -X POST https://api.telegram.org/bot<BOT_TOKEN>/sendMessage \
  -d "chat_id=<CHAT_ID>&text=test"

# 检查网络连接是否能访问 Telegram
curl -v https://api.telegram.org/
```

**解决方案：**

1. 确保 BOT_TOKEN 和 CHAT_ID 都正确无误
2. 检查是否触发了 Telegram API 频率限制（rate limit）
   - 这种情况下等待一段时间再尝试
   - 可以配置消息队列以避免过快发送
3. 确保网络能访问 Telegram API（某些地区可能需要代理）
4. 验证机器人是否仍有效（BotFather 是否禁用了它）

### 问题 4：高内存占用

**症状：** 运行一段时间后内存持续增长，可能导致 OOM 错误

**排查步骤：**

```bash
# 监控内存使用
pm2 monit

# 或查看详细进程信息
ps aux | grep node

# 使用 top 命令实时监控
top -p <pid>

# 检查是否有内存泄漏的日志
tail -f logs/sin-box.log | grep -i "memory\|leak"
```

**解决方案：**

1. **增加服务器内存：** 升级服务器配置（RAM）
2. **启用内存回收机制：** 
   ```bash
   # PM2 自动重启配置
   pm2 restart sin-box --cron "0 */12 * * *"  # 每12小时重启一次
   ```
3. **优化连接数限制：** 减少并发连接数
4. **更新 sin-box 版本：** 检查是否有新版本修复了内存泄漏问题

### 问题 5：订阅链接导入失败

**症状：** 客户端导入订阅时显示"无效的订阅链接"或"连接超时"

**排查步骤：**

```bash
# 测试订阅链接是否可访问
curl -v http://localhost:8001/sub

# 检查响应头和内容格式
curl -i http://localhost:8001/sub

# 检查订阅内容格式是否符合标准
curl http://localhost:8001/sub | head -c 200

# 验证 SUB_PATH 配置
echo $SUB_PATH
```

**解决方案：**

1. 确保 sin-box 服务正常运行且监听正确的端口
2. 检查防火墙和端口转发是否正确配置
3. 确保订阅链接格式正确（应为有效的 Base64 编码）
4. 在客户端端调整 URL 格式，某些客户端需要完整的 HTTPS 链接
5. 检查是否超过了订阅链接大小限制

### 问题 6：Port 已被占用

**症状：** 启动时显示 "EADDRINUSE: address already in use :::8001"

**解决方案：**

```bash
# 查看占用 8001 端口的进程
lsof -i :8001

# 或
netstat -tulpn | grep 8001

# 获取进程 PID 后杀死进程
kill -9 <PID>

# 或修改 sin-box 监听端口
ARGO_PORT=8002 npm start
```

---

## 可选功能配置

### 启用/禁用 Argo 隧道

默认情况下，sin-box 会使用 Argo 隧道。如果希望使用直连模式：

```bash
# 禁用 Argo 隧道
DISABLE_ARGO="true"

# 同时配置优选 IP 和端口
CFIP="104.16.132.229"
CFPORT="443"
```

**何时禁用 Argo：**
- 追求最大速度和最低延迟
- 有稳定的优选 IP 和端口
- 不需要通过 Cloudflare 的 DDoS 防护

### 配置订阅上传功能

将生成的订阅链接自动上传到外部存储：

```bash
# 启用上传功能
UPLOAD_URL="https://api.example.com/upload/sub"
UPLOAD_TOKEN="your-api-token-here"

# 其他可选参数
UPLOAD_METHOD="POST"  # 上传方法，默认 POST
UPLOAD_TIMEOUT="30"   # 上传超时时间（秒）
```

**使用示例（与阿里云 OSS 集成）：**

```bash
UPLOAD_URL="https://your-oss-bucket.oss-cn-hangzhou.aliyuncs.com/sub"
UPLOAD_TOKEN="your-oss-access-key:your-oss-secret-key"
```

### 配置多区域部署

可以在多台服务器上部署多个 sin-box 实例，使用不同的 UUID：

```bash
# 实例 1 - 新加坡
UUID="550e8400-e29b-41d4-a716-446655440000"
NEZHA_SERVER="nezha.example.com:8008"
NEZHA_KEY="token-1"

# 实例 2 - 美国
UUID="660f9511-f30c-52e5-b827-557766551111"
NEZHA_SERVER="nezha.example.com:8008"
NEZHA_KEY="token-1"
```

在哪吒面板中会看到两个独立的节点，可分别监控不同地区的实例。

---

## 日志和监控

### 日志位置

log 文件位置取决于配置，默认情况下：

```bash
# 标准输出/PM2 日志
~/.pm2/logs/sin-box-out.log
~/.pm2/logs/sin-box-error.log

# 或应用目录
./logs/sin-box.log
./logs/error.log
```

### 查看日志的常用命令

```bash
# 实时查看日志（最后 50 行）
tail -f logs/sin-box.log

# 查看过去 100 行日志
tail -n 100 logs/sin-box.log

# 搜索特定关键词
grep -i "error\|warning" logs/sin-box.log

# 查看特定时间段的日志
grep "2024-01-15" logs/sin-box.log

# 如果使用 PM2
pm2 logs sin-box
pm2 logs sin-box --lines 100
pm2 logs sin-box --err
```

### 监控和看门狗行为

sin-box 包含内置的看门狗机制，可自动恢复失败的连接和服务：

```bash
# 启用看门狗（监听进程健康状态）
WATCHDOG_ENABLED="true"
WATCHDOG_INTERVAL="60"  # 每 60 秒检查一次

# 看门狗自动重启机制
MAX_RESTART_ATTEMPTS="5"  # 最多重启 5 次
RESTART_COOLDOWN="300"    # 重启冷却时间（秒）
```

如果看门狗检测到服务异常，会自动：
1. 重新连接 Argo 隧道
2. 重新连接哪吒服务器
3. 如果无法恢复，会发送 Telegram 告警（如已配置）

---

## 启动和停止服务

### 使用 npm 直接运行

```bash
# 启动服务
npm start

# 停止服务（Ctrl+C）
# 或在另一个终端执行
kill $(lsof -t -i :8001)
```

### 使用 PM2 进程管理器（推荐）

```bash
# 启动服务
pm2 start npm --name "sin-box" -- start

# 查看服务状态
pm2 list
pm2 status

# 查看实时日志
pm2 logs sin-box

# 重启服务
pm2 restart sin-box

# 停止服务
pm2 stop sin-box

# 删除服务
pm2 delete sin-box

# 开机自启
pm2 startup
pm2 save

# 取消开机自启
pm2 unstartup
```

### 优雅关闭服务

```bash
# 使用信号优雅关闭（允许进行中的请求完成）
kill -SIGTERM $(lsof -t -i :8001)

# 或使用 PM2
pm2 gracefulShutdown
pm2 stop sin-box
```

### 重启和更新

```bash
# 更新 sin-box 包
npm update sin-box

# 或从 GitHub 拉取最新代码
git pull origin main
npm install

# 重启服务
pm2 restart sin-box

# 验证新版本已生效
pm2 logs sin-box
```

---

## 生产环境最佳实践

1. **使用 PM2 或 systemd 进程管理：** 确保服务在崩溃时自动重启
2. **配置监控告警：** 启用 Telegram 或其他通知方式
3. **定期备份配置：** 保存 `.env` 和重要的配置文件
4. **监控资源使用：** 定期检查 CPU、内存和网络带宽
5. **定期更新：** 及时更新 sin-box 和依赖包以获取安全补丁
6. **使用强密码：** 确保所有凭证都足够复杂
7. **配置日志轮转：** 防止日志文件过大
   ```bash
   # 使用 logrotate
   sudo tee /etc/logrotate.d/sin-box > /dev/null <<EOF
   /path/to/logs/*.log {
       daily
       rotate 7
       compress
       delaycompress
       notifempty
   }
   EOF
   ```

---

## 获取帮助和反馈

- **问题报告：** [GitHub Issues](https://github.com/yourproject/sin-box/issues)
- **讨论区：** [GitHub Discussions](https://github.com/yourproject/sin-box/discussions)
- **Telegram 交流群：** [Telegram Group](https://t.me/yourgroup)
- **文档更新：** 如发现文档错误或有改进建议，欢迎提交 Pull Request

---

## 许可证

本项目采用 MIT 许可证。详见 LICENSE 文件。

---

**文档最后更新：2024 年 1 月**
