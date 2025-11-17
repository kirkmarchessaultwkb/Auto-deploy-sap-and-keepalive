# Config.json 快速参考

## 📍 文件位置

- **运行时**: `/home/container/config.json`
- **模板**: `/home/engine/project/config.json`
- **示例**: `/home/engine/project/config.example.json`

---

## ✅ 快速验证

```bash
# 验证配置文件
./verify-config.sh /home/container/config.json

# 或验证本地文件
./verify-config.sh ./config.json
```

---

## 📋 必填字段 (7个)

| 字段 | 说明 | 示例 |
|------|------|------|
| `cf_domain` | Cloudflare 固定域名 | `zampto.xunda.ggff.net` |
| `cf_token` | Cloudflare API Token | `eyJhIjoiOTh...` |
| `uuid` | VMESS 节点 UUID | `19763831-f9cb-45f2-...` |
| `nezha_server` | 哪吒服务器地址 | `nezha.xunda.nyc.mn:8008` |
| `nezha_port` | 哪吒服务端口 | `5555` |
| `nezha_key` | 哪吒认证 Key | `4yXdY4lxFmqkiz...` |
| `port` | 本地监听端口 | `27039` |

---

## 📝 配置模板

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

---

## 🔧 快速生成 UUID

```bash
# Linux/Mac
uuidgen

# 在线生成
# https://www.uuidgenerator.net/
```

---

## 🚀 部署流程

### 1. 复制模板
```bash
cp config.json my-config.json
```

### 2. 编辑配置
用文本编辑器打开 `my-config.json`，填入您的配置值

### 3. 验证配置
```bash
./verify-config.sh my-config.json
```

### 4. 上传到平台
将 `my-config.json` 重命名为 `config.json` 并上传到 `/home/container/` 目录

### 5. 启动服务
```bash
bash /home/container/start.sh
```

---

## 🛠️ 使用此配置的脚本

- ✅ **start.sh** - 启动脚本 (读取 nezha 配置)
- ✅ **wispbyte-argo-singbox-deploy.sh** - 部署脚本 (读取 cf/uuid/port)

---

## ⚠️ 重要提示

1. **所有7个字段都是必填的**，不能省略
2. **字段名必须小写** (`cf_domain`, 不是 `CF_DOMAIN`)
3. **使用 UTF-8 编码保存文件**
4. **不要提交真实密钥到 Git 仓库**
5. **验证 JSON 格式** 使用 `jq` 或在线工具

---

## 📚 完整文档

详细说明请参考: [CONFIG_JSON_GUIDE.md](CONFIG_JSON_GUIDE.md)

---

## 🐛 常见错误

### 错误: Config file not found
```bash
# 检查文件是否存在
ls -lh /home/container/config.json
```

### 错误: Invalid JSON
```bash
# 验证 JSON 格式
cat config.json | jq .
```

### 错误: Field missing or empty
```bash
# 运行验证脚本
./verify-config.sh config.json
```

---

**更新日期**: 2025-01-17
