# Config.json 配置指南

## 概述

`config.json` 是 Zampto 部署平台的核心配置文件，包含所有服务所需的关键参数。

## 文件位置

**运行时位置**: `/home/container/config.json`

**开发模板**: `/home/engine/project/config.json`

## 配置模板

```json
{
  "cf_domain": "zampto.xunda.ggff.net",
  "cf_token": "eyJhIjoiOThhZmI1Zjg4YzQ5ZWNkMDYxZmI5ZTBhNDY0OTYyOGYiLCJ0IjoiYmUyNzEzMDgtYWJiZi00NzJlLWIwZjItNDUyMzQxZmVlODYyIiwicyI6Ik9ERXdNV0psTVdVdFpqZGhPUzAwTnpobUxUaGpZMkV0TVdFeE1HSmxPREZoT1RVNCJ9",
  "uuid": "19763831-f9cb-45f2-b59a-9d60264c7f1c",
  "nezha_server": "nezha.xunda.nyc.mn:8008",
  "nezha_port": "5555",
  "nezha_key": "4yXdY4lxFmqkiz50QcICzbBb6y1zjzTJ",
  "port": "27039"
}
```

## 字段说明

### 必填字段 (7个)

| 字段 | 类型 | 说明 | 示例 | 格式要求 |
|------|------|------|------|----------|
| `cf_domain` | string | Cloudflare 固定域名 | `zampto.xunda.ggff.net` | 有效的域名格式 |
| `cf_token` | string | Cloudflare API Token | `eyJh...` | Base64编码的token |
| `uuid` | string | VMESS 节点 UUID | `19763831-f9cb-45f2-b59a-9d60264c7f1c` | UUID格式 (8-4-4-4-12) |
| `nezha_server` | string | 哪吒服务器地址 | `nezha.xunda.nyc.mn:8008` | `host:port` 格式 |
| `nezha_port` | string | 哪吒服务端口 | `5555` | 1-65535 |
| `nezha_key` | string | 哪吒认证 Key | `4yXdY4lxFmqkiz50QcICzbBb6y1zjzTJ` | 字符串 |
| `port` | string | 本地监听端口 | `27039` | 1-65535 |

### 字段详细说明

#### 1. cf_domain (Cloudflare 固定域名)

**用途**: 用于 Cloudflare Argo Tunnel 的固定域名

**获取方法**:
1. 登录 Cloudflare Dashboard
2. 选择域名
3. 创建 Tunnel
4. 获取分配的域名

**示例**: `zampto.xunda.ggff.net`

---

#### 2. cf_token (Cloudflare API Token)

**用途**: Cloudflare Tunnel 认证令牌

**获取方法**:
1. Cloudflare Dashboard → Zero Trust → Access → Tunnels
2. 创建或编辑 Tunnel
3. 复制 Token (Base64 编码的 JSON)

**格式**: Base64 编码的 JSON 字符串

**示例**: `eyJhIjoiOThhZmI1Zjg4YzQ5ZWNkMDYxZmI5ZTBhNDY0OTYyOGYi...`

---

#### 3. uuid (VMESS UUID)

**用途**: VMESS 协议的用户标识符

**生成方法**:
```bash
# Linux/Mac
uuidgen

# 或使用在线工具
# https://www.uuidgenerator.net/
```

**格式**: 标准 UUID v4 格式 `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

**示例**: `19763831-f9cb-45f2-b59a-9d60264c7f1c`

---

#### 4. nezha_server (哪吒服务器地址)

**用途**: 哪吒监控服务器地址

**格式**: `hostname:port` 或 `ip:port`

**示例**: 
- `nezha.xunda.nyc.mn:8008`
- `192.168.1.100:8008`

---

#### 5. nezha_port (哪吒服务端口)

**用途**: 哪吒 Agent 连接端口

**默认值**: `5555`

**说明**: 通常与 `nezha_server` 中的端口一致，如果 `nezha_server` 未包含端口，则使用此字段

---

#### 6. nezha_key (哪吒认证密钥)

**用途**: 哪吒 Agent 认证密钥

**获取方法**:
1. 登录哪吒监控面板
2. 添加服务器
3. 复制生成的密钥

**示例**: `4yXdY4lxFmqkiz50QcICzbBb6y1zjzTJ`

---

#### 7. port (本地监听端口)

**用途**: sing-box VMESS 服务监听端口

**默认值**: `27039`

**范围**: 1-65535

**说明**: 用于内部服务通信，Cloudflared 会将外部流量转发到此端口

---

## 使用者

### 读取此配置的脚本

1. **start.sh** (启动脚本)
   - 读取字段: `nezha_server`, `nezha_port`, `nezha_key`
   - 用途: 启动哪吒监控 Agent

2. **wispbyte-argo-singbox-deploy.sh** (部署脚本)
   - 读取字段: `cf_domain`, `cf_token`, `uuid`, `port`
   - 用途: 部署 sing-box + Cloudflared tunnel

---

## 文件验证

### 自动验证脚本

运行验证脚本检查配置文件:

```bash
# 验证默认位置 (/home/container/config.json)
./verify-config.sh

# 验证指定文件
./verify-config.sh /path/to/config.json
```

### 验证项目

- ✅ 文件存在
- ✅ JSON 格式正确
- ✅ 所有7个字段都存在
- ✅ 所有字段都有值（不为空）
- ✅ UUID 格式正确
- ✅ 端口号有效 (1-65535)
- ✅ 域名格式正确

### 手动验证

```bash
# 检查文件是否存在
ls -lh /home/container/config.json

# 验证 JSON 格式
cat /home/container/config.json | jq .

# 提取某个字段
grep -o '"uuid"[[:space:]]*:[[:space:]]*"[^"]*"' /home/container/config.json
```

---

## 部署流程

### 1. 创建配置文件

在本地创建 `config.json` 文件，填入您的配置:

```json
{
  "cf_domain": "your-domain.example.com",
  "cf_token": "your-cloudflare-token",
  "uuid": "your-uuid-here",
  "nezha_server": "your-nezha-server:8008",
  "nezha_port": "5555",
  "nezha_key": "your-nezha-key",
  "port": "27039"
}
```

### 2. 验证配置文件

```bash
./verify-config.sh ./config.json
```

### 3. 上传到平台

将 `config.json` 上传到 Zampto 平台的 `/home/container/` 目录

### 4. 启动服务

```bash
bash /home/container/start.sh
```

---

## 错误处理

### 错误1: 配置文件未找到

**错误信息**:
```
[ERROR] Config file not found: /home/container/config.json
```

**解决方法**:
- 确认文件已上传到 `/home/container/config.json`
- 检查文件路径是否正确

---

### 错误2: JSON 格式错误

**错误信息**:
```
[ERROR] Invalid JSON syntax
```

**解决方法**:
- 使用 `jq` 验证: `cat config.json | jq .`
- 检查是否有多余的逗号
- 检查引号是否匹配
- 使用在线 JSON 验证工具

---

### 错误3: 字段缺失或为空

**错误信息**:
```
[ERROR] Field 'uuid' is missing or empty
```

**解决方法**:
- 确认所有7个字段都存在
- 确认字段值不为空字符串
- 运行 `verify-config.sh` 检查

---

### 错误4: UUID 格式错误

**错误信息**:
```
[ERROR] UUID format is invalid
```

**解决方法**:
- 使用标准 UUID v4 格式: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
- 使用 `uuidgen` 生成新的 UUID
- 在线生成: https://www.uuidgenerator.net/

---

## 安全建议

### 1. 保护敏感信息

⚠️ **不要将包含真实密钥的 config.json 提交到 Git 仓库**

```bash
# 确保 config.json 在 .gitignore 中
echo "config.json" >> .gitignore
```

### 2. 使用环境变量 (可选)

如果平台支持，可以使用环境变量覆盖配置:

```bash
export CF_DOMAIN="your-domain.example.com"
export CF_TOKEN="your-token"
export UUID="your-uuid"
export NEZHA_SERVER="your-server:8008"
export NEZHA_PORT="5555"
export NEZHA_KEY="your-key"
export PORT="27039"
```

### 3. 定期更换密钥

- 定期更换 `cf_token`
- 定期更换 `nezha_key`
- 定期更换 `uuid`

---

## 常见问题

### Q1: 是否可以省略某些字段?

**A**: 不可以。所有7个字段都是必填的。如果某个服务不使用（如哪吒监控），仍需提供占位值。

---

### Q2: 端口号可以修改吗?

**A**: 可以。`port` 字段可以修改为任何有效端口 (1-65535)。但需要确保：
- 端口未被占用
- 与 sing-box 配置一致
- 与 Cloudflared 配置一致

---

### Q3: 如何生成 Cloudflare Token?

**A**: 
1. 登录 Cloudflare Dashboard
2. Zero Trust → Access → Tunnels
3. 创建或编辑 Tunnel
4. 在配置页面复制 Token

---

### Q4: 配置文件可以放在其他位置吗?

**A**: 默认位置是 `/home/container/config.json`。如需修改，需要更新脚本中的 `CONFIG_FILE` 变量。

---

## 示例配置

### 示例 1: 完整配置

```json
{
  "cf_domain": "zampto.xunda.ggff.net",
  "cf_token": "eyJhIjoiOThhZmI1Zjg4YzQ5ZWNkMDYxZmI5ZTBhNDY0OTYyOGYiLCJ0IjoiYmUyNzEzMDgtYWJiZi00NzJlLWIwZjItNDUyMzQxZmVlODYyIiwicyI6Ik9ERXdNV0psTVdVdFpqZGhPUzAwTnpobUxUaGpZMkV0TVdFeE1HSmxPREZoT1RVNCJ9",
  "uuid": "19763831-f9cb-45f2-b59a-9d60264c7f1c",
  "nezha_server": "nezha.xunda.nyc.mn:8008",
  "nezha_port": "5555",
  "nezha_key": "4yXdY4lxFmqkiz50QcICzbBb6y1zjzTJ",
  "port": "27039"
}
```

### 示例 2: 自定义端口

```json
{
  "cf_domain": "my-proxy.example.com",
  "cf_token": "your-cloudflare-token-here",
  "uuid": "12345678-1234-1234-1234-123456789abc",
  "nezha_server": "monitor.example.com:8008",
  "nezha_port": "5555",
  "nezha_key": "your-nezha-key-here",
  "port": "8080"
}
```

---

## 相关文件

- `config.json` - 主配置文件模板
- `config.example.json` - 旧版示例 (使用大写字段名)
- `verify-config.sh` - 配置验证脚本
- `start.sh` - 启动脚本 (读取配置)
- `wispbyte-argo-singbox-deploy.sh` - 部署脚本 (读取配置)

---

## 版本历史

- **v1.0.0** (2025-01-17): 初始版本，定义7个必填字段
- 字段名统一使用小写 + 下划线格式 (`cf_domain`, `nezha_server`)
- 兼容 start.sh 和 wispbyte-argo-singbox-deploy.sh

---

## 技术支持

如有问题，请检查:

1. 运行 `./verify-config.sh` 验证配置
2. 查看启动日志: `/tmp/wispbyte-singbox/deploy.log`
3. 查看服务日志: `/tmp/wispbyte-singbox/singbox.log`
4. 查看 Cloudflared 日志: `/tmp/wispbyte-singbox/cloudflared.log`

---

**文档更新日期**: 2025-01-17
